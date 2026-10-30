import 'dart:math' as math;

import '../config.dart';

double _d(Object? v) =>
    v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

/// One closed (or partially closed) position of lead-portfolio/position-history.
class ClosedTrade {
  const ClosedTrade({
    required this.time,
    required this.pnl,
    required this.notional,
  });

  /// When it was (last) closed: `closed`, or `updateTime` for a partial close.
  final DateTime time;

  /// Realized result in USDT (`closingPnl`).
  final double pnl;

  /// Largest size in USDT (`maxOpenInterest` × `avgCost`).
  final double notional;

  static ClosedTrade? fromJson(Map<String, dynamic> j) {
    final ms = j['closed'] ?? j['updateTime'];
    if (ms is! num) return null;
    return ClosedTrade(
      time: DateTime.fromMillisecondsSinceEpoch(ms.toInt(), isUtc: true),
      pnl: _d(j['closingPnl']),
      notional: (_d(j['maxOpenInterest']) * _d(j['avgCost'])).abs(),
    );
  }
}

/// Realized profit and loss of the period, from the trader's actual closed
/// trades. Binance's own count (performance.totalOrder / winOrders) is used to
/// check that the public history is complete enough to be trusted.
class TradeStats {
  TradeStats._(this.trades, this.officialCount, this.officialWins);

  /// [rows] = position-history list; trades closed at or after [start] count.
  factory TradeStats.fromHistory(
    List<Map<String, dynamic>> rows,
    DateTime start, {
    required int? officialCount,
    required int? officialWins,
  }) {
    final trades = [
      for (final r in rows)
        if (ClosedTrade.fromJson(r) case final t? when !t.time.isBefore(start))
          t,
    ];
    return TradeStats._(trades, officialCount, officialWins);
  }

  final List<ClosedTrade> trades;
  final int? officialCount;
  final int? officialWins;

  int get count => trades.length;
  int get wins => trades.where((t) => t.pnl > 0).length;
  double get grossProfit =>
      trades.where((t) => t.pnl > 0).fold(0.0, (s, t) => s + t.pnl);
  double get grossLoss =>
      trades.where((t) => t.pnl < 0).fold(0.0, (s, t) => s - t.pnl);

  /// Trades found ÷ Binance's count (1.0 = every trade Binance counts).
  double? get coverage =>
      (officialCount ?? 0) > 0 ? count / officialCount! : null;

  /// The history matches Binance's trade AND win counts within tolerance.
  bool get verified {
    final c = coverage, ow = officialWins;
    if (c == null || ow == null || count < MIN_TOTAL_TRADES) return false;
    if (c < MIN_HISTORY_COVERAGE || c > MAX_HISTORY_COVERAGE) return false;
    final winRatio = ow == 0 ? (wins == 0 ? 1.0 : 0.0) : wins / ow;
    return winRatio >= MIN_HISTORY_COVERAGE && winRatio <= MAX_HISTORY_COVERAGE;
  }

  /// Gross profit ÷ (gross loss + floating loss of open trades).
  /// null when there is no loss at all (then the profit decides).
  double? profitFactor(double floatingLoss) {
    final losses = grossLoss + floatingLoss;
    return losses > 0 ? grossProfit / losses : null;
  }

  double? get averageWin => wins == 0 ? null : grossProfit / wins;
  double? get averageLoss {
    final n = trades.where((t) => t.pnl < 0).length;
    return n == 0 ? null : grossLoss / n;
  }

  /// Share (%) of the gross profit made by the 3 best trades.
  double? get top3ProfitShare {
    if (grossProfit <= 0) return null;
    final best = trades.where((t) => t.pnl > 0).map((t) => t.pnl).toList()
      ..sort((a, b) => b.compareTo(a));
    return best.take(3).fold(0.0, (s, v) => s + v) / grossProfit * 100;
  }

  /// Distinct UTC days with at least one closed trade.
  int get tradingDays =>
      {for (final t in trades) '${t.time.year}-${t.time.month}-${t.time.day}'}
          .length;

  /// Share (%) of the trades that a copy of [amount] USDT could still place,
  /// when the trader's balance is [balance] and Binance's smallest order is
  /// [BINANCE_MIN_ORDER_NOTIONAL] USDT (proportional copying). Estimate.
  double? copyableShare(double amount, double? balance) {
    if (balance == null || balance <= 0 || trades.isEmpty) return null;
    final scale = math.min(1.0, amount / balance);
    final ok = trades
        .where((t) => t.notional * scale >= BINANCE_MIN_ORDER_NOTIONAL)
        .length;
    return ok / trades.length * 100;
  }
}

/// Open positions of lead-data/positions (only when the trader shows them).
class OpenPositions {
  const OpenPositions({
    required this.count,
    required this.unrealized,
    required this.floatingLoss,
    required this.notional,
  });

  factory OpenPositions.fromJson(List<dynamic> rows) {
    var count = 0;
    var unrealized = 0.0, loss = 0.0, notional = 0.0;
    for (final r in rows.cast<Map<String, dynamic>>()) {
      if (_d(r['positionAmount']) == 0) continue;
      final u = _d(r['unrealizedProfit']);
      count++;
      unrealized += u;
      if (u < 0) loss -= u; // losing positions are not netted with winners
      notional += _d(r['notionalValue']).abs();
    }
    return OpenPositions(
      count: count,
      unrealized: unrealized,
      floatingLoss: loss,
      notional: notional,
    );
  }

  final int count;

  /// Net unrealized PnL (USDT).
  final double unrealized;

  /// Sum of the losses of losing open positions (USDT, positive).
  final double floatingLoss;

  /// Size of everything open (USDT).
  final double notional;
}
