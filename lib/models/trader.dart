import 'dart:math' as math;

import '../config.dart';
import 'curve.dart';
import 'trade_stats.dart';

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

/// ROI points of `chartItems` / chart-data; null when the items are not ROI
/// (a PNL-sorted list sends a PNL curve in USDT).
List<double>? roiCurveFromJson(Object? items) {
  if (items is! List || items.isEmpty) return null;
  final out = <double>[];
  for (final item in items) {
    if (item is! Map || item['dataType'] != 'ROI') return null;
    final v = _toDouble(item['value']);
    if (v == null) return null;
    out.add(v);
  }
  return out;
}

/// Leverage class Binance puts on a trader (detail → tagItemVos), e.g. "HIGH_LEVERAGE".
String? leverageTagFromDetail(Map<String, dynamic> detail) {
  for (final tag in detail['tagItemVos'] as List? ?? const []) {
    final name = (tag as Map)['tagName'] as String?;
    if (name != null && name.endsWith('_LEVERAGE')) return name;
  }
  return null;
}

/// `data` of GET lead-portfolio/performance (v1/public): Binance's official
/// numbers of one portfolio for one period (what its page shows).
class Performance {
  const Performance({
    required this.timeRange,
    required this.totalOrder,
    required this.winOrders,
    this.sharpRatio,
    this.roi,
    this.pnl,
    this.mdd,
    this.winRate,
    this.copierPnl,
  });

  factory Performance.fromJson(Map<String, dynamic> json) => Performance(
    timeRange: json['timeRange'] as String? ?? '',
    totalOrder: _toInt(json['totalOrder']),
    winOrders: _toInt(json['winOrders']),
    sharpRatio: _toDouble(json['sharpRatio']),
    roi: _toDouble(json['roi']),
    pnl: _toDouble(json['pnl']),
    mdd: _toDouble(json['mdd']),
    winRate: _toDouble(json['winRate']),
    copierPnl: _toDouble(json['copierPnl']),
  );

  final String timeRange;
  final int? totalOrder;
  final int? winOrders;
  final double? sharpRatio;
  final double? roi;
  final double? pnl;
  final double? mdd;
  final double? winRate;
  final double? copierPnl;
}

/// One lead trader (portfolio) from home-page/query-list, plus what is loaded
/// later. Identity is the portfolio id, never the nickname or picture.
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
    this.copierPnl,
    this.roiCurve,
    this.totalOrder,
    this.winOrders,
    this.leverageTag,
    this.copierPnlTotal,
    this.detailLoaded = false,
    this.official = false,
    this.performance = const {},
    this.positionShow,
    this.marginBalance,
    this.minCopyFixedAmount,
    this.minCopyFixedRatio,
    this.open,
    this.trades,
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
      copierPnl: _toDouble(json['copierPnl']),
      roiCurve: roiCurveFromJson(json['chartItems']),
    );
  }

  /// Portfolio id (unique; two portfolios may share a nickname).
  final String id;
  final String nickname;
  final String? avatarUrl;

  /// Percent (5879.3 means 5879.3%). Official (performance) once [official].
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

  /// What the copiers made or lost inside [timeRange] (USDT; query-list and
  /// performance agree on it).
  final double? copierPnl;

  /// What the copiers made or lost since the trader started (detail, USDT).
  final double? copierPnlTotal;

  /// Daily ROI points of [timeRange]; null until loaded for PNL-list traders.
  final List<double>? roiCurve;

  /// Closed trades in [timeRange] (performance.totalOrder); null until loaded.
  final int? totalOrder;
  final int? winOrders;

  /// "HIGH_LEVERAGE" / "MEDIUM_LEVERAGE" / "LOW_LEVERAGE" (detail), if any.
  final String? leverageTag;

  /// True once lead-portfolio/detail was read (so a null tag means "no tag").
  final bool detailLoaded;

  /// True once roi/pnl/mdd/winRate/sharpRatio were replaced by Binance's
  /// official numbers for this portfolio and [timeRange] (performance).
  final bool official;

  /// Official numbers per period ("7D", "30D", "90D", ...).
  final Map<String, Performance> performance;

  /// False when the trader hides open positions on Binance.
  final bool? positionShow;

  /// Trader's own balance (detail.marginBalance, USDT).
  final double? marginBalance;

  /// Smallest copy amount Binance accepts (detail, USDT): fixed amount / fixed ratio.
  final double? minCopyFixedAmount;
  final double? minCopyFixedRatio;

  /// Open positions right now (null until loaded, or when hidden).
  final OpenPositions? open;

  /// Closed trades of [timeRange] (null until loaded).
  final TradeStats? trades;

  Trader _copy({
    double? roi,
    double? pnl,
    double? mdd,
    double? winRate,
    double? sharpRatio,
    List<double>? roiCurve,
    int? totalOrder,
    int? winOrders,
    String? leverageTag,
    double? copierPnlTotal,
    bool? detailLoaded,
    bool? official,
    Map<String, Performance>? performance,
    bool? positionShow,
    double? marginBalance,
    double? minCopyFixedAmount,
    double? minCopyFixedRatio,
    OpenPositions? open,
    TradeStats? trades,
  }) => Trader(
    id: id,
    nickname: nickname,
    avatarUrl: avatarUrl,
    roi: roi ?? this.roi,
    pnl: pnl ?? this.pnl,
    mdd: mdd ?? this.mdd,
    winRate: winRate ?? this.winRate,
    sharpRatio: sharpRatio ?? this.sharpRatio,
    aum: aum,
    currentCopyCount: currentCopyCount,
    maxCopyCount: maxCopyCount,
    startTime: startTime,
    timeRange: timeRange,
    copierPnl: copierPnl,
    roiCurve: roiCurve ?? this.roiCurve,
    totalOrder: totalOrder ?? this.totalOrder,
    winOrders: winOrders ?? this.winOrders,
    leverageTag: leverageTag ?? this.leverageTag,
    copierPnlTotal: copierPnlTotal ?? this.copierPnlTotal,
    detailLoaded: detailLoaded ?? this.detailLoaded,
    official: official ?? this.official,
    performance: performance ?? this.performance,
    positionShow: positionShow ?? this.positionShow,
    marginBalance: marginBalance ?? this.marginBalance,
    minCopyFixedAmount: minCopyFixedAmount ?? this.minCopyFixedAmount,
    minCopyFixedRatio: minCopyFixedRatio ?? this.minCopyFixedRatio,
    open: open ?? this.open,
    trades: trades ?? this.trades,
  );

  /// Stores [p]; for this trader's own period it also replaces the list numbers
  /// with Binance's official ones (the list can lag behind the portfolio page).
  Trader withPerformance(Performance p) {
    final all = {...performance, p.timeRange: p};
    if (p.timeRange != timeRange) return _copy(performance: all);
    return _copy(
      performance: all,
      official: true,
      roi: p.roi,
      pnl: p.pnl,
      mdd: p.mdd,
      winRate: p.winRate,
      sharpRatio: p.sharpRatio,
      totalOrder: p.totalOrder,
      winOrders: p.winOrders,
    );
  }

  Trader withRoiCurve(List<double> curve) => _copy(roiCurve: curve);

  Trader withDetail(Map<String, dynamic> detail) => _copy(
    leverageTag: leverageTagFromDetail(detail),
    copierPnlTotal: _toDouble(detail['copierPnl']),
    detailLoaded: true,
    positionShow: detail['positionShow'] as bool?,
    marginBalance: _toDouble(detail['marginBalance']),
    minCopyFixedAmount: _toDouble(detail['fixedAmountMinCopyUsd']),
    minCopyFixedRatio: _toDouble(detail['fixedRadioMinCopyUsd']),
  );

  Trader withOpenPositions(OpenPositions o) => _copy(open: o);

  Trader withTrades(TradeStats s) => _copy(trades: s);

  CurveStats? get curve =>
      roiCurve == null ? null : CurveStats.fromRoi(roiCurve!);

  String get binanceUrl => '$BINANCE_TRADER_URL$id';

  /// Last 4 digits of the portfolio id, to tell same-name portfolios apart.
  String get shortId => id.length > 4 ? id.substring(id.length - 4) : id;

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

  /// Share (%) of the active days with at least one closed trade.
  double? tradingDaysShare(DateTime now) {
    final days = activeDays(now), s = trades;
    if (s == null || days == null || days <= 0) return null;
    return math.min(100, s.tradingDays / days.ceil() * 100);
  }

  /// Losses of open positions as % of the trader's balance.
  double? get floatingLossPct {
    final o = open, b = marginBalance;
    if (o == null || b == null || b <= 0) return null;
    return o.floatingLoss / b * 100;
  }

  /// Everything open ÷ balance (how many times the balance is at risk now).
  double? get exposure {
    final o = open, b = marginBalance;
    if (o == null || b == null || b <= 0) return null;
    return o.notional / b;
  }

  /// Realized profit ÷ (realized loss + floating loss), from actual trades.
  double? get profitFactor => trades?.profitFactor(open?.floatingLoss ?? 0);

  bool get isCopyAvailable =>
      currentCopyCount != null &&
      maxCopyCount != null &&
      currentCopyCount! < maxCopyCount!;

  /// Profit against losses and risk (see SCORE_MAX_PROFIT_FACTOR in config);
  /// 0 until the trade data is loaded.
  double scoreAt(DateTime now) {
    final s = trades;
    if (s == null || s.grossProfit <= 0) return 0;
    final pf = math.min(
      profitFactor ?? SCORE_MAX_PROFIT_FACTOR,
      SCORE_MAX_PROFIT_FACTOR,
    );
    final regular = (tradingDaysShare(now) ?? 0) / 100;
    final risk = (mdd ?? MAX_MDD) + (floatingLossPct ?? MAX_FLOATING_LOSS_PCT);
    return pf * (0.5 + 0.5 * regular) / (1 + risk / 10);
  }

  /// منخفضة / متوسطة / مرتفعة حسب أقصى تراجع.
  String get riskLabel {
    final m = mdd;
    if (m == null) return 'غير متوفر';
    if (m <= RISK_LOW_MAX_MDD) return 'منخفضة';
    if (m <= RISK_MEDIUM_MAX_MDD) return 'متوسطة';
    return 'مرتفعة';
  }

  /// Arabic name of Binance's leverage tag.
  String get leverageLabel => switch (leverageTag) {
    'HIGH_LEVERAGE' => 'عالية',
    'MEDIUM_LEVERAGE' => 'متوسطة (10x–20x)',
    'LOW_LEVERAGE' => 'منخفضة',
    null => detailLoaded ? 'بلا تصنيف' : 'غير متوفر',
    final other => other,
  };
}
