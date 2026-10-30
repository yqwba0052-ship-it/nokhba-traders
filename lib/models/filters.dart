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

/// No very bad day (daily ROI curve of the period: capital not drained).
bool passesCurveRules(Trader t) {
  final c = t.curve;
  if (c == null || c.days == 0) return false;
  return c.worstDay <= MAX_WORST_DAY_LOSS;
}

/// From lead-portfolio/detail: open positions must be visible (hidden = their
/// floating losses cannot be checked), copiers' result since the start.
bool passesDetailRules(Trader t) {
  if (!t.detailLoaded || t.positionShow != true) return false;
  if (EXCLUDE_HIGH_LEVERAGE && t.leverageTag == 'HIGH_LEVERAGE') return false;
  if (REQUIRE_COPIERS_PROFIT && !((t.copierPnlTotal ?? 0) > 0)) return false;
  return true;
}

/// Floating losses of open positions (lead-data/positions).
bool passesOpenRules(Trader t) {
  final f = t.floatingLossPct;
  return f != null && f <= MAX_FLOATING_LOSS_PCT;
}

/// Official numbers (performance) of the period, re-checked with the list
/// rules, plus the trade count and profit in both the last 30 and 90 days.
bool passesTradeRules(Trader t, PageRules r, DateTime now) {
  if (!t.official || !passesListRules(t, r, now)) return false;
  final total = t.totalOrder;
  if (total == null || total < MIN_TOTAL_TRADES) return false;
  final minDaily = r.minTradesPerDay;
  if (minDaily != null) {
    final daily = t.dailyTrades(now);
    if (daily == null || daily < minDaily) return false;
  }
  if (REQUIRE_PROFIT_30D_AND_90D) {
    for (final range in const ['30D', '90D']) {
      final pnl = t.performance[range]?.pnl;
      if (pnl == null || pnl <= 0) return false;
    }
  }
  return true;
}

/// Realized profit far above realized + floating losses, from actual trades
/// whose history matches Binance's own count; not made by a few lucky trades.
bool passesHistoryRules(Trader t) {
  final s = t.trades;
  if (s == null || !s.verified || s.grossProfit <= 0) return false;
  final pf = t.profitFactor;
  if (pf != null && pf < MIN_PROFIT_FACTOR) return false;
  final top3 = s.top3ProfitShare;
  if (top3 == null || top3 > MAX_TOP3_PROFIT_SHARE) return false;
  return true;
}

/// Best profit against losses and risk first.
List<Trader> rankByScore(Iterable<Trader> traders, DateTime now) =>
    traders.toList()..sort((a, b) => b.scoreAt(now).compareTo(a.scoreAt(now)));
