import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nokhba_traders/config.dart';
import 'package:nokhba_traders/models/filters.dart';
import 'package:nokhba_traders/services/binance_service.dart';

import 'helpers.dart';

const listFixture = 'list_30D_ROI_page1_size30.json';
const highLeverageId = '5240448882690502145'; // real detail says HIGH_LEVERAGE
const pnlOnlyId = '9999000000000000001';
const hiddenId = '5237550357789132545'; // its real detail hides positions

http.Response _json(Object body) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), 200);

/// Answers like Binance did, from saved real responses:
/// - query-list: page 1 of ROI = the saved list; page 1 of PNL = one extra
///   trader with a PNL curve (so its ROI curve is fetched); later pages empty.
/// - performance: the saved 30D numbers of [historyId] for every portfolio and
///   period (its 57 trades match the saved history).
/// - detail, positions, history: the saved ones of [historyId], except
///   [hiddenId] (real detail with hidden positions) and [highLeverageId].
MockClient fakeBinance({
  List<Uri>? calls,
  String? copierPnlTotal = '250.5',
  bool emptyHistory = false,
}) {
  final items = fixtureList(listFixture);
  final pnlOnly = {
    ...items.firstWhere((x) => x['leadPortfolioId'] == highLeverageId),
    'leadPortfolioId': pnlOnlyId,
    'copierPnl': 1000,
    'chartItems': [
      for (final c in items.first['chartItems'] as List)
        {...c as Map, 'dataType': 'PNL'},
    ],
  };
  return MockClient((req) async {
    calls?.add(req.url);
    final path = req.url.path;
    final q = req.url.queryParameters;
    final id = q['portfolioId'];
    if (path.endsWith('/home-page/query-list')) {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      if (body['pageNumber'] != 1) {
        return _json({
          'code': '000000',
          'data': {'total': 0, 'list': []},
        });
      }
      if (body['dataType'] == 'PNL') {
        return _json({
          'code': '000000',
          'data': {
            'total': 1,
            'list': [pnlOnly],
          },
        });
      }
      return _json(fixture(listFixture));
    }
    if (path.endsWith('/lead-portfolio/performance')) {
      final p = fixture('perf_${historyId}_30D.json');
      return _json({
        ...p,
        'data': {...p['data'] as Map, 'timeRange': q['timeRange']},
      });
    }
    if (path.endsWith('/lead-portfolio/chart-data')) {
      return _json(fixture('chart_${highLeverageId}_30D.json'));
    }
    if (path.endsWith('/lead-portfolio/detail')) {
      if (id == hiddenId) return _json(fixture('detail.json'));
      final base = fixture(
        id == highLeverageId
            ? 'detail_high_leverage.json'
            : 'detail_$historyId.json',
      );
      return _json({
        ...base,
        'data': {
          ...base['data'] as Map,
          'positionShow': true,
          'copierPnl': copierPnlTotal,
        },
      });
    }
    if (path.endsWith('/lead-data/positions')) {
      return _json(fixture('positions_$historyId.json'));
    }
    if (path.endsWith('/lead-portfolio/position-history')) {
      if (emptyHistory) {
        return _json({
          'code': '000000',
          'data': {'total': 0, 'list': []},
        });
      }
      return _json(fixture('history_$historyId.json'));
    }
    return http.Response('not found', 404);
  });
}

void main() {
  test(
    'loadPage keeps only traders passing every rule, ranked, at most 30',
    () async {
      final calls = <Uri>[];
      final service = BinanceService(
        client: fakeBinance(calls: calls),
        clock: () => historyNow,
      );
      final rules = PageRules.pros('30D');
      final result = await service.loadPage(rules);

      expect(result.traders, isNotEmpty);
      expect(result.traders.length, lessThanOrEqualTo(MAX_TRADERS_PER_SECTION));
      final ids = result.traders.map((t) => t.id).toList();
      expect(ids.toSet(), hasLength(ids.length)); // unique portfolio ids
      expect(ids, isNot(contains(hiddenId))); // hidden open positions
      for (final t in result.traders) {
        expect(t.official, isTrue);
        expect(passesListRules(t, rules, historyNow), isTrue);
        expect(passesCurveRules(t), isTrue);
        expect(passesDetailRules(t), isTrue);
        expect(passesOpenRules(t), isTrue);
        expect(passesTradeRules(t, rules, historyNow), isTrue);
        expect(passesHistoryRules(t), isTrue);
        expect(t.copierPnlTotal, 250.5);
        expect(t.totalOrder, 57);
        expect(t.trades!.verified, isTrue);
        expect(t.profitFactor, greaterThanOrEqualTo(MIN_PROFIT_FACTOR));
        // the official 30D numbers replaced the list ones
        expect(t.roi, closeTo(403.50131307, 1e-6));
        expect(t.performance.keys, containsAll(['30D', '90D']));
      }
      for (var i = 1; i < result.traders.length; i++) {
        expect(
          result.traders[i - 1].scoreAt(historyNow),
          greaterThanOrEqualTo(result.traders[i].scoreAt(historyNow)),
        );
      }
      final perf = calls.where((u) => u.path.endsWith('/performance'));
      expect(
        perf.first.toString(),
        startsWith('$BINANCE_PUBLIC_API/lead-portfolio/performance'),
      );
    },
  );

  test('high leverage alone does not remove a trader any more', () async {
    final service = BinanceService(
      client: fakeBinance(),
      clock: () => historyNow,
    );
    final result = await service.loadPage(PageRules.pros('30D'));
    final high = result.traders.where((t) => t.id == highLeverageId);
    if (high.isNotEmpty) expect(high.single.leverageTag, 'HIGH_LEVERAGE');
    expect(EXCLUDE_HIGH_LEVERAGE, isFalse);
  });

  test(
    'a trader known only from the PNL list gets its ROI curve fetched',
    () async {
      final calls = <Uri>[];
      final service = BinanceService(
        client: fakeBinance(calls: calls),
        clock: () => historyNow,
      );
      await service.loadPage(PageRules.pros('7D'));
      final charts = calls
          .where((u) => u.path.endsWith('/chart-data'))
          .toList();
      expect(charts, hasLength(1));
      expect(charts.single.queryParameters['portfolioId'], pnlOnlyId);
      expect(charts.single.queryParameters['dataType'], 'ROI');
    },
  );

  test('history hidden by Binance: nobody is shown ("لا يوجد")', () async {
    final service = BinanceService(
      client: fakeBinance(emptyHistory: true),
      clock: () => historyNow,
    );
    final result = await service.loadPage(PageRules.pros('30D'));
    expect(result.traders, isEmpty);
  });

  test('copiers losing since the start: nobody is shown', () async {
    final service = BinanceService(
      client: fakeBinance(copierPnlTotal: '-1'),
      clock: () => historyNow,
    );
    final result = await service.loadPage(PageRules.pros('30D'));
    expect(result.traders, isEmpty);
  });

  test('fetchRoiCurve reads the real chart-data response', () async {
    final service = BinanceService(client: fakeBinance());
    final curve = await service.fetchRoiCurve(pnlOnlyId, '30D');
    final listCurve =
        fixtureList(listFixture).firstWhere(
              (x) => x['leadPortfolioId'] == highLeverageId,
            )['chartItems']
            as List;
    expect(curve, hasLength(listCurve.length));
    expect(curve.last, closeTo((listCurve.last as Map)['value'] as num, 1e-6));
  });

  test('a 403 stops with a "blocked" error and is not bypassed', () async {
    final service = BinanceService(
      client: MockClient((_) async => http.Response('Forbidden', 403)),
    );
    expect(
      service.loadPage(PageRules.today),
      throwsA(
        isA<BinanceException>().having((e) => e.blocked, 'blocked', isTrue),
      ),
    );
  });

  test('an AWS WAF challenge counts as blocked', () async {
    final service = BinanceService(
      client: MockClient(
        (_) async =>
            http.Response('', 202, headers: {'x-amzn-waf-action': 'challenge'}),
      ),
    );
    expect(
      service.fetchPerformance('1', '30D'),
      throwsA(
        isA<BinanceException>().having((e) => e.blocked, 'blocked', isTrue),
      ),
    );
  });
}
