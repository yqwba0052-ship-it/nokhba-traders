import 'package:flutter_test/flutter_test.dart';
import 'package:nokhba_traders/config.dart';
import 'package:nokhba_traders/models/filters.dart';
import 'package:nokhba_traders/models/trade_stats.dart';
import 'package:nokhba_traders/models/trader.dart';

import 'helpers.dart';

/// Expected values were computed separately in Python from the same saved
/// Binance responses (history, positions, detail, performance of one portfolio).
void main() {
  final start = historyNow.subtract(const Duration(days: 30)).toUtc();
  final perf = Performance.fromJson(
    fixture('perf_${historyId}_30D.json')['data'] as Map<String, dynamic>,
  );
  final stats = TradeStats.fromHistory(
    historyRows(),
    start,
    officialCount: perf.totalOrder,
    officialWins: perf.winOrders,
  );
  final open = OpenPositions.fromJson(
    fixture('positions_$historyId.json')['data'] as List,
  );
  final detail =
      fixture('detail_$historyId.json')['data'] as Map<String, dynamic>;

  group('closed trades (real position-history)', () {
    test('matches Binance official count and wins exactly: verified', () {
      expect(perf.totalOrder, 57);
      expect(perf.winOrders, 50);
      expect(stats.count, 57);
      expect(stats.wins, 50);
      expect(stats.coverage, 1.0);
      expect(stats.verified, isTrue);
    });

    test('gross profit / loss and the profit factor come from the trades', () {
      expect(stats.grossProfit, closeTo(54695.998753, 1e-4));
      expect(stats.grossLoss, closeTo(3079.815197, 1e-4));
      expect(stats.profitFactor(0), closeTo(17.759507, 1e-5));
    });

    test('average win / loss, best 3 trades, trading days', () {
      expect(stats.averageWin, closeTo(1093.919975, 1e-5));
      expect(stats.averageLoss, closeTo(439.973600, 1e-5));
      expect(stats.top3ProfitShare, closeTo(38.435110, 1e-5));
      expect(stats.tradingDays, 17);
    });

    test('copyable share uses balance and the 5 USDT smallest order', () {
      final balance = double.parse(detail['marginBalance'] as String);
      expect(stats.copyableShare(100, balance), 100);
      expect(stats.copyableShare(100, null), isNull);
      // a tiny amount cannot place most of these trades
      expect(stats.copyableShare(0.01, balance), lessThan(100));
    });

    test('a history missing many trades is not verified', () {
      final half = TradeStats.fromHistory(
        historyRows().take(20).toList(),
        start,
        officialCount: 57,
        officialWins: 50,
      );
      expect(half.verified, isFalse);
    });

    test('an empty history (hidden by Binance) is not verified', () {
      final none = TradeStats.fromHistory(
        const [],
        start,
        officialCount: 17,
        officialWins: 14,
      );
      expect(none.coverage, 0);
      expect(none.verified, isFalse);
    });
  });

  group('open positions (real lead-data/positions)', () {
    test('only non-zero positions count; losses are not netted', () {
      expect(open.count, 1);
      expect(open.floatingLoss, closeTo(1624.789325, 1e-5));
      expect(open.notional, closeTo(257660.0036, 1e-3));
    });

    test('floating loss enters the profit factor and the risk', () {
      final t = fixtureTraders(
        'list_30D_ROI_page1_size30.json',
        '30D',
      ).first.withDetail(detail).withOpenPositions(open).withTrades(stats);
      expect(t.positionShow, isTrue);
      expect(t.floatingLossPct, closeTo(2.585142, 1e-5));
      expect(t.exposure, closeTo(4.099533, 1e-5));
      expect(t.profitFactor, closeTo(11.626057, 1e-5));
      expect(passesOpenRules(t), isTrue);
      expect(passesHistoryRules(t), isTrue);
    });

    test('hidden open positions: floating loss unknown, rejected', () {
      final hidden = fixtureTraders(
        'list_30D_ROI_page1_size30.json',
        '30D',
      ).first.withDetail({...detail, 'positionShow': false});
      expect(passesDetailRules(hidden), isFalse);
      expect(hidden.floatingLossPct, isNull);
      expect(passesOpenRules(hidden), isFalse);
    });
  });

  group('profit factor rule', () {
    Trader withPnls(List<double> pnls, {double floating = 0}) {
      final rows = [
        for (var i = 0; i < pnls.length; i++)
          {
            'closed': historyNow.millisecondsSinceEpoch - i * 60000,
            'closingPnl': pnls[i],
            'maxOpenInterest': 1,
            'avgCost': 100,
          },
      ];
      final wins = pnls.where((p) => p > 0).length;
      return fixtureTraders('list_30D_ROI_page1_size30.json', '30D').first
          .withDetail(detail)
          .withOpenPositions(
            OpenPositions(
              count: floating > 0 ? 1 : 0,
              unrealized: -floating,
              floatingLoss: floating,
              notional: 100,
            ),
          )
          .withTrades(
            TradeStats.fromHistory(
              rows,
              start,
              officialCount: pnls.length,
              officialWins: wins,
            ),
          );
    }

    // 8 wins of 10 each (no single trade dominates) and 2 losses.
    final pnls = <double>[10, 10, 10, 10, 10, 10, 10, 10, -15, -15];

    test('80 / 30 = 2.67 >= 2.5 passes', () {
      final t = withPnls(pnls);
      expect(t.profitFactor, closeTo(80 / 30, 1e-9));
      expect(passesHistoryRules(t), isTrue);
    });

    test('a floating loss can push it below 2.5 (hidden losses count)', () {
      final t = withPnls(pnls, floating: 5); // 80 / 35 = 2.29
      expect(t.profitFactor, closeTo(80 / 35, 1e-9));
      expect(t.profitFactor, lessThan(MIN_PROFIT_FACTOR));
      expect(passesHistoryRules(t), isFalse);
    });

    test('profits made by a few exceptional trades are rejected', () {
      final t = withPnls(<double>[500, 10, 10, 10, 10, 10, 10, 10, -15, -15]);
      expect(t.trades!.top3ProfitShare, greaterThan(MAX_TOP3_PROFIT_SHARE));
      expect(passesHistoryRules(t), isFalse);
    });
  });

  group('ranking: profit against losses and risk', () {
    test('score = min(PF,10) x (0.5 + 0.5 x trading days) / (1 + risk/10)', () {
      final t = fixtureTraders(
        'list_30D_ROI_page1_size30.json',
        '30D',
      ).first.withDetail(detail).withOpenPositions(open).withTrades(stats);
      final regular = t.tradingDaysShare(historyNow)! / 100;
      final expected =
          10 * (0.5 + 0.5 * regular) / (1 + (t.mdd! + t.floatingLossPct!) / 10);
      expect(t.scoreAt(historyNow), closeTo(expected, 1e-9));
    });

    test('no trade data = score 0 (never ranked above a checked trader)', () {
      final t = fixtureTraders('list_30D_ROI_page1_size30.json', '30D').first;
      expect(t.scoreAt(historyNow), 0);
    });
  });
}
