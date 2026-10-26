import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/filters.dart';
import '../models/trader.dart';

class BinanceException implements Exception {
  const BinanceException(this.message, {this.blocked = false});

  /// Arabic text shown to the user.
  final String message;

  /// Binance refused us (403/451/429/WAF challenge): never bypassed.
  final bool blocked;

  @override
  String toString() => message;
}

/// What one screen shows, with how it was obtained.
class PageResult {
  const PageResult({
    required this.traders,
    required this.timeRange,
    required this.candidates,
    required this.skipped,
    required this.loadedAt,
  });

  final List<Trader> traders;
  final String timeRange;

  /// Traders that passed the list conditions and had their trades checked.
  final int candidates;

  /// Candidates whose trade count could not be loaded (left out, not guessed).
  final int skipped;
  final DateTime loadedAt;
}

typedef Progress = void Function(int done, int total);

class BinanceService {
  BinanceService({http.Client? client, DateTime Function()? clock})
    : _client = client ?? http.Client(),
      _clock = clock ?? DateTime.now;

  final http.Client _client;
  final DateTime Function() _clock;
  final Map<String, Performance> _performance = {};

  static const _headers = {
    'Content-Type': 'application/json',
    'clienttype': 'web',
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/129.0.0.0 Mobile Safari/537.36',
  };

  Future<Map<String, dynamic>> _send(Future<http.Response> request) async {
    final http.Response res;
    try {
      res = await request.timeout(REQUEST_TIMEOUT);
    } on TimeoutException {
      throw const BinanceException('انتهت مهلة الاتصال بـ Binance.');
    } catch (_) {
      throw const BinanceException(
        'تعذّر الاتصال بـ Binance. تأكد من الإنترنت.',
      );
    }
    final challenged =
        res.headers['x-amzn-waf-action'] != null ||
        res.body.toLowerCase().contains('captcha');
    if (const {403, 429, 451}.contains(res.statusCode) || challenged) {
      throw BinanceException(
        'رفضت Binance الطلب (رمز ${res.statusCode}). انتظر قليلاً ثم حاول مرة أخرى.',
        blocked: true,
      );
    }
    if (res.statusCode != 200) {
      throw BinanceException('ردّت Binance بخطأ (رمز ${res.statusCode}).');
    }
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(res.bodyBytes));
    } on FormatException {
      throw const BinanceException('ردّ Binance غير مفهوم.');
    }
    if (json is! Map<String, dynamic> || json['code'] != '000000') {
      final msg = json is Map ? json['message'] : null;
      throw BinanceException('ردّت Binance بخطأ: ${msg ?? 'غير معروف'}.');
    }
    return json;
  }

  /// One page of home-page/query-list.
  Future<List<Trader>> fetchListPage({
    required String timeRange,
    required String dataType,
    required int pageNumber,
    required bool hideFull,
  }) async {
    final json = await _send(
      _client.post(
        Uri.parse('$BINANCE_API/home-page/query-list'),
        headers: _headers,
        body: jsonEncode({
          'pageNumber': pageNumber,
          'pageSize': LIST_PAGE_SIZE,
          'timeRange': timeRange,
          'dataType': dataType,
          'favoriteOnly': false,
          'hideFull': hideFull,
          'nickname': '',
          'order': 'DESC',
          'userAsset': 0,
          'portfolioType': 'ALL',
        }),
      ),
    );
    final list = (json['data'] as Map<String, dynamic>?)?['list'] as List?;
    return [
      for (final item in list ?? const [])
        Trader.fromListJson(item as Map<String, dynamic>, timeRange),
    ];
  }

  /// Several pages sorted by ROI and by PNL, duplicates removed.
  Future<List<Trader>> collect(
    String timeRange, {
    required bool hideFull,
  }) async {
    final byId = <String, Trader>{};
    for (final dataType in const ['ROI', 'PNL']) {
      for (var page = 1; page <= LIST_PAGES_PER_SORT; page++) {
        final items = await fetchListPage(
          timeRange: timeRange,
          dataType: dataType,
          pageNumber: page,
          hideFull: hideFull,
        );
        for (final t in items) {
          byId.putIfAbsent(t.id, () => t);
        }
        if (items.length < LIST_PAGE_SIZE) break;
        await Future<void>.delayed(REQUEST_PAUSE);
      }
    }
    return byId.values.toList();
  }

  /// Trade counts for one trader in [timeRange] (cached for this session).
  Future<Performance> fetchPerformance(String id, String timeRange) async {
    final key = '$id|$timeRange';
    final cached = _performance[key];
    if (cached != null) return cached;
    final json = await _send(
      _client.get(
        Uri.parse(
          '$BINANCE_PUBLIC_API/lead-portfolio/performance'
          '?portfolioId=$id&timeRange=$timeRange',
        ),
        headers: _headers,
      ),
    );
    final p = Performance.fromJson(json['data'] as Map<String, dynamic>);
    return _performance[key] = p;
  }

  /// Everything one screen needs: collect, filter, fetch trades in batches, rank.
  Future<PageResult> loadPage(PageRules rules, {Progress? onProgress}) async {
    final now = _clock();
    final all = await collect(
      rules.timeRange,
      hideFull: rules.requireCopyAvailable,
    );
    final candidates = all
        .where((t) => passesListRules(t, rules, now))
        .toList();
    final withTrades = <Trader>[];
    var skipped = 0;
    onProgress?.call(0, candidates.length);
    for (var i = 0; i < candidates.length; i += PERFORMANCE_BATCH_SIZE) {
      final batch = candidates.skip(i).take(PERFORMANCE_BATCH_SIZE);
      final results = await Future.wait(
        batch.map((t) async {
          try {
            return t.withPerformance(
              await fetchPerformance(t.id, rules.timeRange),
            );
          } on BinanceException catch (e) {
            if (e.blocked) rethrow;
            return null;
          }
        }),
      );
      for (final t in results) {
        if (t == null) {
          skipped++;
        } else {
          withTrades.add(t);
        }
      }
      onProgress?.call(
        (i + PERFORMANCE_BATCH_SIZE).clamp(0, candidates.length),
        candidates.length,
      );
      if (i + PERFORMANCE_BATCH_SIZE < candidates.length) {
        await Future<void>.delayed(REQUEST_PAUSE);
      }
    }
    return PageResult(
      traders: rankByScore(
        withTrades.where((t) => passesTradeRules(t, rules, now)),
      ),
      timeRange: rules.timeRange,
      candidates: candidates.length,
      skipped: skipped,
      loadedAt: now,
    );
  }
}
