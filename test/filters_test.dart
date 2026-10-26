import 'package:flutter_test/flutter_test.dart';
import 'package:nokhba_traders/config.dart';
import 'package:nokhba_traders/models/filters.dart';
import 'package:nokhba_traders/models/trader.dart';

import 'helpers.dart';

void main() {
  final traders = fixtureTraders('list_30D_ROI_hideFullFalse.json', '30D');
  Trader byName(String n) => traders.firstWhere((t) => t.nickname == n);
  Trader withTrades(Trader t, int total) => t.withPerformance(
    Performance(timeRange: t.timeRange, totalOrder: total, winOrders: 0),
  );

  group('rules of each screen', () {
    test('pros: minimum age equals the chosen period', () {
      expect(PageRules.pros('7D').minAgeDays, 7);
      expect(PageRules.pros('30D').minAgeDays, 30);
      expect(PageRules.pros('90D').minAgeDays, 90);
      expect(PageRules.pros('30D').requireCopyAvailable, isFalse);
    });

    test('today: 30D, copy available, daily trades >= 3, age >= 7', () {
      expect(PageRules.today.timeRange, '30D');
      expect(PageRules.today.requireCopyAvailable, isTrue);
      expect(PageRules.today.minTradesPerDay, MIN_TRADES_PER_DAY);
      expect(PageRules.today.minAgeDays, 7);
    });

    test('year: 365D, started at least 365 days ago, copy available', () {
      expect(PageRules.year.timeRange, '365D');
      expect(PageRules.year.minAgeDays, 365);
      expect(PageRules.year.requireCopyAvailable, isTrue);
    });
  });

  group('passesListRules (real traders)', () {
    test('every accepted trader meets every list condition', () {
      final accepted = traders.where(
        (t) => passesListRules(t, PageRules.today, fixtureNow),
      );
      expect(accepted, isNotEmpty);
      for (final t in accepted) {
        expect(t.mdd, lessThanOrEqualTo(MAX_MDD));
        expect(t.winRate, greaterThanOrEqualTo(MIN_WIN_RATE));
        expect(t.roi, greaterThan(0));
        expect(t.pnl, greaterThan(0));
        expect(t.aum, greaterThanOrEqualTo(MIN_AUM));
        expect(t.ageDays(fixtureNow), greaterThanOrEqualTo(MIN_AGE_DAYS));
        expect(t.isCopyAvailable, isTrue);
      }
    });

    test('drawdown above MAX_MDD is rejected (温田, 66%)', () {
      expect(
        passesListRules(byName('温田'), PageRules.today, fixtureNow),
        isFalse,
      );
    });

    test('a full trader is rejected only where copying must be available', () {
      final full = traders.firstWhere(
        (t) =>
            !t.isCopyAvailable &&
            passesListRules(t, PageRules.pros('7D'), fixtureNow),
        orElse: () => throw StateError('fixture has no full, passing trader'),
      );
      expect(passesListRules(full, PageRules.today, fixtureNow), isFalse);
    });

    test('a trader younger than the period is rejected', () {
      // ~31.7 days old; its copiers lost money, so give them a profit here to
      // test the age rule alone.
      final t = Trader.fromListJson({
        ...fixtureList('list_30D_ROI_hideFullFalse.json').first,
        'copierPnl': 100,
      }, '30D');
      expect(passesListRules(t, PageRules.pros('30D'), fixtureNow), isTrue);
      expect(passesListRules(t, PageRules.pros('90D'), fixtureNow), isFalse);
      expect(passesListRules(t, PageRules.year, fixtureNow), isFalse);
      final young = t.startTime!.add(const Duration(days: 6));
      expect(passesListRules(t, PageRules.today, young), isFalse);
    });

    test('nobody in the 365D page is old enough for the year screen', () {
      // Real data: the top-ROI traders of 365D all started < 365 days ago.
      final year = fixtureTraders('list_365D_ROI_hideFullFalse.json', '365D');
      expect(
        year.where((t) => passesListRules(t, PageRules.year, fixtureNow)),
        isEmpty,
      );
    });
  });

  group('passesTradeRules', () {
    final t = traders.first; // 30D, older than 30 days

    test('needs at least MIN_TOTAL_TRADES', () {
      final rules = PageRules.pros('30D');
      expect(passesTradeRules(withTrades(t, 9), rules, fixtureNow), isFalse);
      expect(passesTradeRules(withTrades(t, 10), rules, fixtureNow), isTrue);
      expect(passesTradeRules(t, rules, fixtureNow), isFalse); // not loaded
    });

    test('today needs >= 3 trades per day over 30 days', () {
      expect(
        passesTradeRules(withTrades(t, 89), PageRules.today, fixtureNow),
        isFalse,
      );
      expect(
        passesTradeRules(withTrades(t, 90), PageRules.today, fixtureNow),
        isTrue,
      );
    });
  });

  test('rankByScore puts the best profit-against-risk first', () {
    final ranked = rankByScore(traders);
    for (var i = 1; i < ranked.length; i++) {
      expect(ranked[i - 1].score, greaterThanOrEqualTo(ranked[i].score));
    }
  });
}
