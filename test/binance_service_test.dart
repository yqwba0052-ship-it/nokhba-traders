import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nokhba_traders/config.dart';
import 'package:nokhba_traders/models/filters.dart';
import 'package:nokhba_traders/services/binance_service.dart';

import 'helpers.dart';

/// Answers like Binance did in step 1: page 1 = the saved list, later pages empty.
MockClient fakeBinance({
  required String listFixture,
  required int Function(String id) totalOrder,
  List<Uri>? calls,
}) {
  return MockClient((req) async {
    calls?.add(req.url);
    final path = req.url.path;
    if (path.endsWith('/home-page/query-list')) {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      if (body['pageNumber'] == 1) {
        return http.Response.bytes(
          utf8.encode(jsonEncode(fixture(listFixture))),
          200,
        );
      }
      return http.Response(
        '{"code":"000000","data":{"total":0,"list":[]},"success":true}',
        200,
      );
    }
    if (path.endsWith('/lead-portfolio/performance')) {
      final id = req.url.queryParameters['portfolioId']!;
      final range = req.url.queryParameters['timeRange']!;
      final n = totalOrder(id);
      return http.Response(
        '{"code":"000000","data":{"timeRange":"$range","totalOrder":$n,'
        '"winOrders":${n ~/ 2},"sharpRatio":null},"success":true}',
        200,
      );
    }
    return http.Response('not found', 404);
  });
}

void main() {
  test('loadPage: ROI + PNL, duplicates removed, filtered, ranked', () async {
    final calls = <Uri>[];
    final service = BinanceService(
      client: fakeBinance(
        listFixture: 'list_30D_ROI_hideFullTrue.json',
        totalOrder: (_) => 120,
        calls: calls,
      ),
      clock: () => fixtureNow,
    );
    final result = await service.loadPage(PageRules.today);

    // The same saved page came back for ROI and PNL: no trader twice.
    final ids = result.traders.map((t) => t.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
    expect(result.traders, isNotEmpty);
    for (final t in result.traders) {
      expect(passesListRules(t, PageRules.today, fixtureNow), isTrue);
      expect(t.totalOrder, 120);
      expect(t.winOrders, 60);
    }
    for (var i = 1; i < result.traders.length; i++) {
      expect(
        result.traders[i - 1].score,
        greaterThanOrEqualTo(result.traders[i].score),
      );
    }
    // Performance asked once per candidate, from the public v1 path.
    final perf = calls.where((u) => u.path.endsWith('/performance')).toList();
    expect(perf, hasLength(result.candidates));
    expect(
      perf.first.toString(),
      startsWith('$BINANCE_PUBLIC_API/lead-portfolio/performance'),
    );
    expect(perf.first.queryParameters['timeRange'], '30D');
  });

  test('too few daily trades removes a trader', () async {
    final service = BinanceService(
      client: fakeBinance(
        listFixture: 'list_30D_ROI_hideFullTrue.json',
        totalOrder: (_) => 20, // < 3 per day over 30 days
      ),
      clock: () => fixtureNow,
    );
    final result = await service.loadPage(PageRules.today);
    expect(result.candidates, greaterThan(0));
    expect(
      result.traders.every(
        (t) => t.dailyTrades(fixtureNow)! >= MIN_TRADES_PER_DAY,
      ),
      isTrue,
    );
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
