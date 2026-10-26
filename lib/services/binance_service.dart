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

  /// Traders that passed the list conditions and were checked further.
  final int candidates;

  /// Candidates whose extra data could not be loaded (left out, not guessed).
  final int skipped;
  final DateTime loadedAt;
}

/// [stage] is shown to the user, e.g. "الصفقات".
typedef Progress = void Function(String stage, int done, int total);

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

  /// Daily ROI curve of one trader (lead-portfolio/chart-data, v1/public).
  Future<List<double>> fetchRoiCurve(String id, String timeRange) async {
    final json = await _send(
      _client.get(
        Uri.parse(
          '$BINANCE_PUBLIC_API/lead-portfolio/chart-data'
          '?portfolioId=$id&timeRange=$timeRange&dataType=ROI',
        ),
        headers: _headers,
      ),
    );
    final curve = roiCurveFromJson(json['data']);
    if (curve == null) {
      throw const BinanceException('منحنى الأداء من Binance غير مفهوم.');
    }
    return curve;
  }

  /// lead-portfolio/detail (leverage tag, ...).
  Future<Map<String, dynamic>> fetchDetail(String id) async {
    final json = await _send(
      _client.get(
        Uri.parse('$BINANCE_API/lead-portfolio/detail?portfolioId=$id'),
        headers: _headers,
      ),
    );
    return json['data'] as Map<String, dynamic>;
  }

  /// Runs [load] for every trader, [PERFORMANCE_BATCH_SIZE] at a time.
  /// A trader whose request fails is left out (null); a block stops everything.
  Future<List<Trader?>> _inBatches(
    List<Trader> traders,
    String stage,
    Future<Trader> Function(Trader) load,
    Progress? onProgress,
  ) async {
    final out = <Trader?>[];
    onProgress?.call(stage, 0, traders.length);
    for (var i = 0; i < traders.length; i += PERFORMANCE_BATCH_SIZE) {
      final batch = traders.skip(i).take(PERFORMANCE_BATCH_SIZE);
      out.addAll(
        await Future.wait(
          batch.map((t) async {
            try {
              return await load(t);
            } on BinanceException catch (e) {
              if (e.blocked) rethrow;
              return null;
            }
          }),
        ),
      );
      onProgress?.call(stage, out.length, traders.length);
      if (out.length < traders.length) {
        await Future<void>.delayed(REQUEST_PAUSE);
      }
    }
    return out;
  }

  /// Everything one screen needs. Cheapest checks first, so later (one request
  /// per trader) steps only run for traders still in the list:
  /// list → daily curve → trade counts → detail (leverage, copiers) → rank.
  Future<PageResult> loadPage(PageRules rules, {Progress? onProgress}) async {
    final now = _clock();
    final range = rules.timeRange;
    final all = await collect(range, hideFull: rules.requireCopyAvailable);
    final candidates = all
        .where((t) => passesListRules(t, rules, now))
        .toList();
    var skipped = 0;
    List<Trader> kept(List<Trader?> results, bool Function(Trader) rule) {
      skipped += results.where((t) => t == null).length;
      return [
        for (final t in results)
          if (t != null && rule(t)) t,
      ];
    }

    // Traders found only in the PNL-sorted list come without an ROI curve.
    final withCurve = kept(
      await _inBatches(
        candidates,
        'منحنى الأداء',
        (t) async => t.roiCurve != null
            ? t
            : t.withRoiCurve(await fetchRoiCurve(t.id, range)),
        onProgress,
      ),
      passesCurveRules,
    );
    final withTrades = kept(
      await _inBatches(
        withCurve,
        'الصفقات',
        (t) async => t.withPerformance(await fetchPerformance(t.id, range)),
        onProgress,
      ),
      (t) => passesTradeRules(t, rules, now),
    );
    final withLeverage = kept(
      await _inBatches(
        withTrades,
        'الرافعة',
        (t) async => t.withDetail(await fetchDetail(t.id)),
        onProgress,
      ),
      passesDetailRules,
    );
    return PageResult(
      traders: rankByScore(withLeverage),
      timeRange: range,
      candidates: candidates.length,
      skipped: skipped,
      loadedAt: now,
    );
  }
}
