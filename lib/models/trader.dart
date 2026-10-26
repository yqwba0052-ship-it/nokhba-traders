import 'dart:math' as math;

import '../config.dart';

/// Binance sends some numbers as JSON numbers and others as strings.
double? _toDouble(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

int? _toInt(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

/// Number of days in a Binance time range such as "30D".
int periodDays(String timeRange) =>
    int.parse(timeRange.substring(0, timeRange.length - 1));

/// `data` of GET lead-portfolio/performance (v1/public).
class Performance {
  const Performance({
    required this.timeRange,
    required this.totalOrder,
    required this.winOrders,
    this.sharpRatio,
  });

  factory Performance.fromJson(Map<String, dynamic> json) => Performance(
    timeRange: json['timeRange'] as String? ?? '',
    totalOrder: _toInt(json['totalOrder']),
    winOrders: _toInt(json['winOrders']),
    sharpRatio: _toDouble(json['sharpRatio']),
  );

  final String timeRange;
  final int? totalOrder;
  final int? winOrders;
  final double? sharpRatio;
}

/// One lead trader from home-page/query-list, plus its trade counts once loaded.
class Trader {
  const Trader({
    required this.id,
    required this.nickname,
    required this.avatarUrl,
    required this.roi,
    required this.pnl,
    required this.mdd,
    required this.winRate,
    required this.sharpRatio,
    required this.aum,
    required this.currentCopyCount,
    required this.maxCopyCount,
    required this.startTime,
    required this.timeRange,
    this.totalOrder,
    this.winOrders,
  });

  factory Trader.fromListJson(Map<String, dynamic> json, String timeRange) {
    final avatar = json['avatarUrl'] as String?;
    return Trader(
      id: json['leadPortfolioId'].toString(),
      nickname: (json['nickname'] as String?)?.trim() ?? '',
      // Binance's generic picture for users without a photo counts as "no photo".
      avatarUrl:
          (avatar == null ||
              avatar.isEmpty ||
              avatar.contains('default-avatar'))
          ? null
          : avatar,
      roi: _toDouble(json['roi']),
      pnl: _toDouble(json['pnl']),
      mdd: _toDouble(json['mdd']),
      winRate: _toDouble(json['winRate']),
      sharpRatio: _toDouble(json['sharpRatio']),
      aum: _toDouble(json['aum']),
      currentCopyCount: _toInt(json['currentCopyCount']),
      maxCopyCount: _toInt(json['maxCopyCount']),
      startTime: _toInt(json['startTime']) == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(_toInt(json['startTime'])!),
      timeRange: timeRange,
    );
  }

  final String id;
  final String nickname;
  final String? avatarUrl;

  /// Percent (5879.3 means 5879.3%).
  final double? roi;

  /// USDT.
  final double? pnl;

  /// Percent.
  final double? mdd;

  /// Percent (73.33, not 0.7333).
  final double? winRate;

  /// Often null on Binance: shown as "غير متوفر".
  final double? sharpRatio;

  /// USDT.
  final double? aum;
  final int? currentCopyCount;
  final int? maxCopyCount;
  final DateTime? startTime;

  /// The period all the numbers above belong to, e.g. "30D".
  final String timeRange;

  /// Closed trades in [timeRange] (performance.totalOrder); null until loaded.
  final int? totalOrder;
  final int? winOrders;

  Trader withPerformance(Performance p) => Trader(
    id: id,
    nickname: nickname,
    avatarUrl: avatarUrl,
    roi: roi,
    pnl: pnl,
    mdd: mdd,
    winRate: winRate,
    sharpRatio: sharpRatio ?? p.sharpRatio,
    aum: aum,
    currentCopyCount: currentCopyCount,
    maxCopyCount: maxCopyCount,
    startTime: startTime,
    timeRange: timeRange,
    totalOrder: p.totalOrder,
    winOrders: p.winOrders,
  );

  String get binanceUrl => '$BINANCE_TRADER_URL$id';

  double? ageDays(DateTime now) => startTime == null
      ? null
      : now.difference(startTime!).inMinutes / Duration.minutesPerDay;

  /// Days the trader actually traded inside the period (at most the period).
  double? activeDays(DateTime now) {
    final age = ageDays(now);
    if (age == null) return null;
    return math.min(age, periodDays(timeRange).toDouble());
  }

  double? dailyTrades(DateTime now) {
    final days = activeDays(now);
    if (totalOrder == null || days == null || days <= 0) return null;
    return totalOrder! / days;
  }

  bool get isCopyAvailable =>
      currentCopyCount != null &&
      maxCopyCount != null &&
      currentCopyCount! < maxCopyCount!;

  double get score => (roi ?? 0) / ((mdd ?? 0) + SCORE_MDD_OFFSET);

  /// منخفضة / متوسطة / مرتفعة حسب أقصى تراجع.
  String get riskLabel {
    final m = mdd;
    if (m == null) return 'غير متوفر';
    if (m <= RISK_LOW_MAX_MDD) return 'منخفضة';
    if (m <= RISK_MEDIUM_MAX_MDD) return 'متوسطة';
    return 'مرتفعة';
  }
}
