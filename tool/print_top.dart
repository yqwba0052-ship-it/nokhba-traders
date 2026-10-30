// Prints the first 5 traders of every screen, using the app's own code.
// Run: dart run tool/print_top.dart
import 'dart:io';

import 'package:nokhba_traders/config.dart';
import 'package:nokhba_traders/models/filters.dart';
import 'package:nokhba_traders/services/binance_service.dart';

Future<void> main() async {
  final service = BinanceService();
  final pages = <String, PageRules>{
    for (final r in PROS_TIME_RANGES) 'المحترفون ($r)': PageRules.pros(r),
    'متداولين اليوم ($TODAY_TIME_RANGE)': PageRules.today,
    'متداولين السنة ($YEAR_TIME_RANGE)': PageRules.year,
  };
  for (final entry in pages.entries) {
    final result = await service.loadPage(entry.value);
    final now = result.loadedAt;
    stdout.writeln(
      '\n=== ${entry.key}: ${result.traders.length} متداول '
      '(فُحصت صفقات ${result.candidates}، تعذّر ${result.skipped}) ===',
    );
    for (final t in result.traders.take(5)) {
      stdout.writeln(
        '${t.nickname} | ROI ${t.roi!.toStringAsFixed(2)}% '
        '| MDD ${t.mdd!.toStringAsFixed(2)}% '
        '| صفقات يومية ${t.dailyTrades(now)!.toStringAsFixed(2)} '
        '(${t.totalOrder} خلال ${t.activeDays(now)!.toStringAsFixed(1)} يوم) '
        '| ناسخون ${t.currentCopyCount}/${t.maxCopyCount} '
        '| معامل الربحية ${t.profitFactor?.toStringAsFixed(2) ?? 'بلا خسائر'} '
        '| عائمة ${t.floatingLossPct!.toStringAsFixed(2)}% '
        '| score ${t.scoreAt(now).toStringAsFixed(2)}\n  ${t.binanceUrl}',
      );
    }
  }
  exit(0);
}
