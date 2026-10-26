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

http.Response _json(Object body) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), 200);

/// Answers like Binance did: page 1 of ROI = the saved list; page 1 of PNL =
/// one extra trader that comes with a PNL curve (so its ROI curve is fetched);
/// later pages empty. performance/detail/chart-data use real saved responses.
MockClient fakeBinance({
  required int Function(String id) totalOrder,
  List<Uri>? calls,
}) {
  final list = fixture(listFixture);
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
      return _json(list);
    }
    if (path.endsWith('/lead-portfolio/performance')) {
      final n = totalOrder(q['portfolioId']!);
      return _json({
        'code': '000000',
        'data': {
          'timeRange': q['timeRange'],
          'totalOrder': n,
          'winOrders': n ~/ 2,
          'sharpRatio': null,
        },
      });
    }
    if (path.endsWith('/lead-portfolio/chart-data')) {
      return _json(fixture('chart_${highLeverageId}_30D.json'));
    }
    if (path.endsWith('/lead-portfolio/detail')) {
      if (q['portfolioId'] == highLeverageId) {
        return _json(fixture('detail_high_leverage.json'));
      }
      // real MEDIUM_LEVERAGE detail; its copiers lost money since the start,
      // so give them a profit here (the rule itself is tested in curve_test).
      final detail = fixture('detail.json');
      return _json({
        ...detail,
        'data': {...detail['data'] as Map, 'copierPnl': '250.5'},
      });
    }
    return http.Response('not found', 404);
  });
}

void main() {
  test(
    'loadPage keeps only traders passing every rule, ranked by score',
    () async {
      final calls = <Uri>[];
      final service = BinanceService(
        client: fakeBinance(totalOrder: (_) => 120, calls: calls),
        clock: () => fixtureNow,
      );
      final result = await service.loadPage(PageRules.pros('7D'));

      expect(result.traders, isNotEmpty);
      final ids = result.traders.map((t) => t.id).toList();
      expect(ids.toSet(), hasLength(ids.length)); // no duplicates
      for (final t in result.traders) {
        expect(passesListRules(t, PageRules.pros('7D'), fixtureNow), isTrue);
        expect(passesCurveRules(t), isTrue);
        expect(passesTradeRules(t, PageRules.pros('7D'), fixtureNow), isTrue);
        expect(passesDetailRules(t), isTrue);
        expect(t.copierPnl, greaterThan(0));
        expect(t.copierPnlTotal, 250.5);
        expect(t.leverageTag, 'MEDIUM_LEVERAGE');
        expect(t.totalOrder, 120);
      }
      for (var i = 1; i < result.traders.length; i++) {
        expect(
          result.traders[i - 1].score,
          greaterThanOrEqualTo(result.traders[i].score),
        );
      }
      // trade counts come from the public v1 performance path
      final perf = calls.where((u) => u.path.endsWith('/performance'));
      expect(
        perf.first.toString(),
        startsWith('$BINANCE_PUBLIC_API/lead-portfolio/performance'),
      );
    },
  );

  test(
    'a trader known only from the PNL list gets its ROI curve fetched',
    () async {
      final calls = <Uri>[];
      final service = BinanceService(
        client: fakeBinance(totalOrder: (_) => 120, calls: calls),
        clock: () => fixtureNow,
      );
      await service.loadPage(PageRules.pros('7D'));
      // Traders of the ROI list already have their ROI curve: one request only.
      final charts = calls
          .where((u) => u.path.endsWith('/chart-data'))
          .toList();
      expect(charts, hasLength(1));
      expect(charts.single.queryParameters['portfolioId'], pnlOnlyId);
      expect(charts.single.queryParameters['dataType'], 'ROI');
    },
  );

  test('fetchRoiCurve reads the real chart-data response', () async {
    final service = BinanceService(client: fakeBinance(totalOrder: (_) => 0));
    final curve = await service.fetchRoiCurve(pnlOnlyId, '30D');
    final listCurve =
        fixtureList(listFixture).firstWhere(
              (x) => x['leadPortfolioId'] == highLeverageId,
            )['chartItems']
            as List;
    expect(curve, hasLength(listCurve.length));
    expect(curve.last, closeTo((listCurve.last as Map)['value'] as num, 1e-6));
  });

  test('high leverage (real detail) is never shown', () async {
    final service = BinanceService(
      client: fakeBinance(totalOrder: (_) => 500),
      clock: () => fixtureNow,
    );
    for (final rules in [PageRules.pros('7D'), PageRules.pros('30D')]) {
      final result = await service.loadPage(rules);
      expect(result.traders.map((t) => t.id), isNot(contains(highLeverageId)));
    }
  });

  test('too few trades removes a trader', () async {
    final service = BinanceService(
      client: fakeBinance(totalOrder: (_) => MIN_TOTAL_TRADES - 1),
      clock: () => fixtureNow,
    );
    final result = await service.loadPage(PageRules.pros('7D'));
    expect(result.traders, isEmpty);
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
