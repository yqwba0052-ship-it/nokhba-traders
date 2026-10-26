import 'dart:math' as math;

import '../config.dart';
import 'trader.dart';

/// The conditions one screen applies.
class PageRules {
  const PageRules({
    required this.timeRange,
    required this.minAgeDays,
    required this.requireCopyAvailable,
    this.minTradesPerDay,
  });

  /// المحترفون: the trader must be at least as old as the chosen period.
  factory PageRules.pros(String timeRange) => PageRules(
    timeRange: timeRange,
    minAgeDays: math.max(MIN_AGE_DAYS, periodDays(timeRange)),
    requireCopyAvailable: false,
  );

  /// متداولين اليوم: copy available + daily trades over the last 30 days.
  static const today = PageRules(
    timeRange: TODAY_TIME_RANGE,
    minAgeDays: MIN_AGE_DAYS,
    requireCopyAvailable: true,
    minTradesPerDay: MIN_TRADES_PER_DAY,
  );

  /// متداولين السنة: 365D, started at least 365 days ago, copy available.
  static const year = PageRules(
    timeRange: YEAR_TIME_RANGE,
    minAgeDays: 365,
    requireCopyAvailable: true,
  );

  final String timeRange;
  final int minAgeDays;
  final bool requireCopyAvailable;
  final double? minTradesPerDay;

  String get key =>
      '$timeRange|$minAgeDays|$requireCopyAvailable|$minTradesPerDay';
}

/// Conditions that need only the list data (checked before fetching trades).
bool passesListRules(Trader t, PageRules r, DateTime now) {
  final roi = t.roi, pnl = t.pnl, mdd = t.mdd, win = t.winRate, aum = t.aum;
  final age = t.ageDays(now);
  if (roi == null || pnl == null || mdd == null || win == null) return false;
  if (aum == null || age == null) return false;
  if (roi <= 0 || pnl <= 0) return false;
  if (mdd > MAX_MDD) return false;
  if (win < MIN_WIN_RATE) return false;
  if (aum < MIN_AUM) return false;
  if (age < r.minAgeDays) return false;
  if (r.requireCopyAvailable && !t.isCopyAvailable) return false;
  if (REQUIRE_COPIERS_PROFIT && !((t.copierPnl ?? 0) > 0)) return false;
  return true;
}

/// Profits far bigger than losses, and no very bad day (daily ROI curve).
bool passesCurveRules(Trader t) {
  final c = t.curve;
  if (c == null || c.days == 0) return false;
  final ratio = c.gainLossRatio;
  if (ratio == null ? c.gains <= 0 : ratio < MIN_GAIN_LOSS_RATIO) return false;
  if (c.worstDay > MAX_WORST_DAY_LOSS) return false;
  return true;
}

/// From lead-portfolio/detail: leverage class and the copiers' result since
/// the start (not loaded = not verified = out).
bool passesDetailRules(Trader t) {
  if (!t.detailLoaded) return false;
  if (EXCLUDE_HIGH_LEVERAGE && t.leverageTag == 'HIGH_LEVERAGE') return false;
  if (REQUIRE_COPIERS_PROFIT && !((t.copierPnlTotal ?? 0) > 0)) return false;
  return true;
}

/// Conditions on the trade count (after performance was loaded).
bool passesTradeRules(Trader t, PageRules r, DateTime now) {
  final total = t.totalOrder;
  if (total == null || total < MIN_TOTAL_TRADES) return false;
  final minDaily = r.minTradesPerDay;
  if (minDaily != null) {
    final daily = t.dailyTrades(now);
    if (daily == null || daily < minDaily) return false;
  }
  return true;
}

/// Highest "profit against risk" first.
List<Trader> rankByScore(Iterable<Trader> traders) =>
    traders.toList()..sort((a, b) => b.score.compareTo(a.score));
