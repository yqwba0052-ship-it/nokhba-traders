import 'package:flutter_test/flutter_test.dart';
import 'package:nokhba_traders/config.dart';
import 'package:nokhba_traders/models/curve.dart';
import 'package:nokhba_traders/models/filters.dart';
import 'package:nokhba_traders/models/trader.dart';

import 'helpers.dart';

void main() {
  group('CurveStats', () {
    test('daily changes are measured on equity = 100 + ROI', () {
      // equity 100 → 110 → 105 → 120: +10%, -4.545%, +14.286%
      final c = CurveStats.fromRoi([0, 10, 5, 20]);
      expect(c.days, 3);
      expect(c.losingDays, 1);
      expect(c.gains, closeTo(10 + 14.2857, 1e-3));
      expect(c.losses, closeTo(4.5455, 1e-3));
      expect(c.worstDay, closeTo(4.5455, 1e-3));
      expect(c.gainLossRatio, closeTo(24.2857 / 4.5455, 1e-3));
    });

    test('no losing day: ratio is null, worst day 0', () {
      final c = CurveStats.fromRoi([0, 0, 3, 8]);
      expect(c.gainLossRatio, isNull);
      expect(c.worstDay, 0);
      expect(c.losingDays, 0);
    });

    test('flat days before the start (ROI 0) count as no change', () {
      final c = CurveStats.fromRoi([0, 0, 0, 0]);
      expect(c.gains, 0);
      expect(c.losses, 0);
    });
  });

  group('real Binance curves', () {
    final traders = fixtureTraders('list_30D_ROI_page1_size30.json', '30D');

    test('every ROI-list trader brings a 30-point ROI curve', () {
      for (final t in traders) {
        expect(t.roiCurve, hasLength(30));
      }
    });

    test('a PNL curve is not taken as ROI', () {
      expect(
        roiCurveFromJson([
          {'value': 5, 'dataType': 'PNL', 'dateTime': 0},
        ]),
        isNull,
      );
    });

    test('chart-data response equals the list curve', () {
      final chart = roiCurveFromJson(
        fixture('chart_5240448882690502145_30D.json')['data'],
      );
      final listed = traders
          .firstWhere((t) => t.id == '5240448882690502145')
          .roiCurve!;
      expect(chart, hasLength(listed.length));
      for (var i = 0; i < listed.length; i++) {
        expect(chart![i], closeTo(listed[i], 1e-6));
      }
    });

    // The profit factor now comes from actual trades (trade_stats_test); the
    // ROI curve only guards against a very bad day.
    test('passesCurveRules follows MAX_WORST_DAY_LOSS only', () {
      for (final t in traders) {
        expect(
          passesCurveRules(t),
          t.curve!.worstDay <= MAX_WORST_DAY_LOSS,
          reason: t.nickname,
        );
      }
    });

    test('copiers losing money are rejected', () {
      final losing = traders.firstWhere((t) => t.copierPnl! < 0);
      expect(
        passesListRules(losing, PageRules.pros('7D'), fixtureNow),
        isFalse,
      );
    });
  });

  group(
    'detail: leverage tag and copiers since the start (real responses)',
    () {
      final t = fixtureTraders('list_30D_ROI_page1_size30.json', '30D').first;
      Map<String, dynamic> detail(String name, {String? copierPnl}) {
        final d = Map<String, dynamic>.of(
          fixture(name)['data'] as Map<String, dynamic>,
        );
        if (copierPnl != null) d['copierPnl'] = copierPnl;
        return d;
      }

      test('HIGH_LEVERAGE is rejected even when copiers profit', () {
        final high = t.withDetail(
          detail('detail_high_leverage.json', copierPnl: '1000'),
        );
        expect(high.leverageTag, 'HIGH_LEVERAGE');
        expect(high.leverageLabel, 'عالية');
        expect(passesDetailRules(high), isFalse);
      });

      test('copiers losing since the start are rejected (real: -5039.16)', () {
        final medium = t.withDetail(detail('detail.json'));
        expect(medium.leverageTag, 'MEDIUM_LEVERAGE');
        expect(medium.copierPnlTotal, closeTo(-5039.15752863, 1e-6));
        expect(passesDetailRules(medium), isFalse);
      });

      test('MEDIUM_LEVERAGE with copiers in profit passes', () {
        // the real detail.json hides open positions: rejected for that alone
        final hidden = t.withDetail(detail('detail.json', copierPnl: '12.5'));
        expect(passesDetailRules(hidden), isFalse);
        final shown = detail('detail.json', copierPnl: '12.5')
          ..['positionShow'] = true;
        expect(passesDetailRules(t.withDetail(shown)), isTrue);
      });

      test('detail not loaded = not verified = rejected', () {
        expect(passesDetailRules(t), isFalse);
      });
    },
  );
}
