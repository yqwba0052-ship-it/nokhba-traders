import 'package:flutter_test/flutter_test.dart';
import 'package:nokhba_traders/models/trader.dart';

import 'helpers.dart';

void main() {
  group('Trader.fromListJson (real query-list response)', () {
    final traders = fixtureTraders('list_30D_ROI_hideFullFalse.json', '30D');

    test('reads every field of the first trader', () {
      final t = traders.first;
      expect(t.id, '5240448882690502145');
      expect(t.nickname, '迪亚马特');
      expect(t.avatarUrl, startsWith('https://public.bnbstatic.com/'));
      expect(t.roi, closeTo(5879.34917381, 1e-6));
      expect(t.pnl, closeTo(29396.74586909, 1e-6));
      expect(t.mdd, closeTo(9.7570642, 1e-6));
      expect(t.winRate, closeTo(90.6015, 1e-6));
      expect(t.sharpRatio, isNull);
      expect(t.aum, closeTo(301766.49981164, 1e-6));
      expect(t.currentCopyCount, 733);
      expect(t.maxCopyCount, 800);
      expect(t.startTime!.millisecondsSinceEpoch, 1790313494250);
      expect(t.timeRange, '30D');
      expect(
        t.binanceUrl,
        'https://www.binance.com/en/copy-trading/lead-details/5240448882690502145',
      );
    });

    test('parses all 18 traders; win rate is a percent (0..100)', () {
      expect(traders, hasLength(18));
      for (final t in traders) {
        expect(t.id, isNotEmpty);
        expect(t.winRate, inInclusiveRange(0, 100));
      }
      expect(traders.any((t) => t.winRate! > 1), isTrue);
    });

    test('a trader with 200/200 copiers is full', () {
      final full = traders.firstWhere(
        (t) => t.currentCopyCount == t.maxCopyCount,
      );
      expect(full.isCopyAvailable, isFalse);
      expect(traders.first.isCopyAvailable, isTrue);
    });

    test(
      'the portfolio id is the identity; shortId tells same names apart',
      () {
        final t = traders.first;
        expect(t.shortId, '2145');
        expect(traders.map((x) => x.id).toSet(), hasLength(traders.length));
      },
    );

    test('risk label follows max drawdown', () {
      expect(traders.first.riskLabel, 'منخفضة'); // 9.76%
      expect(traders.firstWhere((t) => t.nickname == '温田').riskLabel, 'مرتفعة');
    });
  });

  group('Performance (real lead-portfolio/performance response)', () {
    test('reads totalOrder and winOrders', () {
      final p = Performance.fromJson(
        fixture('perf_5237550357789132545_30D.json')['data']
            as Map<String, dynamic>,
      );
      expect(p.timeRange, '30D');
      expect(p.totalOrder, 30);
      expect(p.winOrders, 22);
      expect(p.sharpRatio, isNull);
    });

    test('sharpRatio sent as a string is parsed', () {
      final p = Performance.fromJson(
        fixture('perf_5075281354358777856_30D.json')['data']
            as Map<String, dynamic>,
      );
      expect(p.totalOrder, 9);
      expect(p.sharpRatio, closeTo(2.68904957, 1e-9));
    });
  });

  group('daily trades', () {
    final first = fixtureTraders(
      'list_30D_ROI_hideFullFalse.json',
      '30D',
    ).first;

    test('an older trader divides by the whole period (30 days)', () {
      final t = first.withPerformance(
        const Performance(timeRange: '30D', totalOrder: 266, winOrders: 200),
      );
      expect(t.ageDays(fixtureNow), greaterThan(30));
      expect(t.activeDays(fixtureNow), 30);
      expect(t.dailyTrades(fixtureNow), closeTo(266 / 30, 1e-9));
      expect(t.winOrders, 200);
    });

    test('a newer trader divides by the days it actually traded', () {
      final now = first.startTime!.add(const Duration(days: 12));
      final t = first.withPerformance(
        const Performance(timeRange: '30D', totalOrder: 60, winOrders: 40),
      );
      expect(t.activeDays(now), closeTo(12, 1e-9));
      expect(t.dailyTrades(now), closeTo(5, 1e-9));
    });

    test('unknown trade count gives no daily value', () {
      expect(first.dailyTrades(fixtureNow), isNull);
    });
  });
}
