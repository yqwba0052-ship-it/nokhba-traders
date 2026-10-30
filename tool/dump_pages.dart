// Saves every trader each screen shows, as JSON, for an independent audit.
// Run: dart run tool/dump_pages.dart <output.json>
import 'dart:convert';
import 'dart:io';

import 'package:nokhba_traders/config.dart';
import 'package:nokhba_traders/models/filters.dart';
import 'package:nokhba_traders/services/binance_service.dart';

Future<void> main(List<String> args) async {
  final service = BinanceService();
  final pages = <String, PageRules>{
    for (final r in PROS_TIME_RANGES) 'pros_$r': PageRules.pros(r),
    'today': PageRules.today,
    'year': PageRules.year,
  };
  final out = <String, Object?>{};
  for (final MapEntry(key: name, value: rules) in pages.entries) {
    final result = await service.loadPage(rules);
    final now = result.loadedAt;
    out[name] = {
      'timeRange': rules.timeRange,
      'minAgeDays': rules.minAgeDays,
      'requireCopyAvailable': rules.requireCopyAvailable,
      'minTradesPerDay': rules.minTradesPerDay,
      'loadedAt': now.millisecondsSinceEpoch,
      'candidates': result.candidates,
      'skipped': result.skipped,
      'traders': [
        for (final t in result.traders)
          {
            'id': t.id,
            'nickname': t.nickname,
            'roi': t.roi,
            'pnl': t.pnl,
            'mdd': t.mdd,
            'winRate': t.winRate,
            'aum': t.aum,
            'currentCopyCount': t.currentCopyCount,
            'maxCopyCount': t.maxCopyCount,
            'startTime': t.startTime?.millisecondsSinceEpoch,
            'totalOrder': t.totalOrder,
            'winOrders': t.winOrders,
            'dailyTrades': t.dailyTrades(now),
            'sharpRatio': t.sharpRatio,
            'score': t.scoreAt(now),
            'profitFactor': t.profitFactor,
            'historyCount': t.trades?.count,
            'grossProfit': t.trades?.grossProfit,
            'grossLoss': t.trades?.grossLoss,
            'top3Share': t.trades?.top3ProfitShare,
            'floatingLoss': t.open?.floatingLoss,
            'floatingLossPct': t.floatingLossPct,
            'marginBalance': t.marginBalance,
            'tradingDaysShare': t.tradingDaysShare(now),
            'pnl30': t.performance['30D']?.pnl,
            'pnl90': t.performance['90D']?.pnl,
          },
      ],
    };
    stdout.writeln('$name: ${result.traders.length} traders');
  }
  File(args.single).writeAsStringSync(jsonEncode(out));
  exit(0);
}
