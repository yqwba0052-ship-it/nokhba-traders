/// Profit-against-loss and risk numbers from Binance's daily ROI curve
/// (`chartItems` of query-list, or lead-portfolio/chart-data).
///
/// equity of day t = 100 + ROI_t ; daily change % = equity_t / equity_{t-1} - 1.
class CurveStats {
  const CurveStats({
    required this.days,
    required this.gains,
    required this.losses,
    required this.worstDay,
    required this.losingDays,
  });

  factory CurveStats.fromRoi(List<double> roi) {
    var gains = 0.0, losses = 0.0, worst = 0.0;
    var days = 0, losing = 0;
    for (var i = 1; i < roi.length; i++) {
      final before = 100 + roi[i - 1], after = 100 + roi[i];
      if (before <= 0) continue;
      final change = (after / before - 1) * 100;
      days++;
      if (change > 0) gains += change;
      if (change < 0) {
        losses -= change;
        losing++;
        if (-change > worst) worst = -change;
      }
    }
    return CurveStats(
      days: days,
      gains: gains,
      losses: losses,
      worstDay: worst,
      losingDays: losing,
    );
  }

  /// Day-to-day changes measured.
  final int days;

  /// Sum of the rises of winning days (% points).
  final double gains;

  /// Sum of the drops of losing days (% points, positive).
  final double losses;

  /// Largest single-day drop (% of equity).
  final double worstDay;
  final int losingDays;

  /// gains ÷ losses; null when there was no losing day at all.
  double? get gainLossRatio => losses > 0 ? gains / losses : null;
}
