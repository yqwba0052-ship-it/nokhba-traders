import '../models/trader.dart';

/// Left-to-right mark: keeps "-5.2%" and "$1,200" readable inside Arabic text.
const _ltr = '‎';

String _group(String digits) {
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

String formatNumber(double v, {int decimals = 2}) {
  final s = v.abs().toStringAsFixed(decimals);
  final parts = s.split('.');
  final grouped = _group(parts[0]);
  final body = parts.length > 1 ? '$grouped.${parts[1]}' : grouped;
  return v < 0 ? '-$body' : body;
}

String formatPercent(double? v) =>
    v == null ? 'غير متوفر' : '$_ltr${formatNumber(v)}%';

String formatSignedPercent(double? v) {
  if (v == null) return 'غير متوفر';
  return '$_ltr${v > 0 ? '+' : ''}${formatNumber(v)}%';
}

String formatUsd(double? v) {
  if (v == null) return 'غير متوفر';
  final abs = formatNumber(v.abs(), decimals: v.abs() >= 1000 ? 0 : 2);
  return '$_ltr${v < 0 ? '-' : ''}\$$abs';
}

String formatDecimal(double? v, {int decimals = 2}) =>
    v == null ? 'غير متوفر' : '$_ltr${formatNumber(v, decimals: decimals)}';

String formatInt(int? v) => v == null ? 'غير متوفر' : _group('$v');

/// "7 أيام" / "30 يوماً" / "365 يوماً".
String periodLabel(String timeRange) {
  final n = periodDays(timeRange);
  if (n >= 3 && n <= 10) return '$n أيام';
  return '$n يوماً';
}

String formatTime(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
