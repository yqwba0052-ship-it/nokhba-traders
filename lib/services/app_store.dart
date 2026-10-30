import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../models/trader.dart';

/// What the owner found when really copying a recommended trader.
enum TestStatus {
  success('ناجح'),
  fail('فاشل'),
  testing('تحت الاختبار');

  const TestStatus(this.label);
  final String label;
}

/// One trader the owner tested. Kept apart from Binance's history: it records
/// the owner's own result plus what the app showed when it was recorded.
class TestEntry {
  const TestEntry({
    required this.id,
    required this.nickname,
    required this.status,
    required this.recordedAt,
    required this.timeRange,
    this.profitFactor,
    this.roi,
  });

  factory TestEntry.fromJson(Map<String, dynamic> j) => TestEntry(
    id: j['id'] as String,
    nickname: j['nickname'] as String? ?? '',
    status: TestStatus.values.byName(j['status'] as String),
    recordedAt: DateTime.parse(j['recordedAt'] as String),
    timeRange: j['timeRange'] as String? ?? '',
    profitFactor: (j['profitFactor'] as num?)?.toDouble(),
    roi: (j['roi'] as num?)?.toDouble(),
  );

  /// Portfolio id (unique).
  final String id;
  final String nickname;
  final TestStatus status;
  final DateTime recordedAt;

  /// Period of the section the trader was recommended in.
  final String timeRange;

  /// What the app showed when the result was first recorded.
  final double? profitFactor;
  final double? roi;

  Map<String, dynamic> toJson() => {
    'id': id,
    'nickname': nickname,
    'status': status.name,
    'recordedAt': recordedAt.toIso8601String(),
    'timeRange': timeRange,
    'profitFactor': profitFactor,
    'roi': roi,
  };
}

/// The owner's own data on this phone: test results and copy amount.
class AppStore extends ChangeNotifier {
  static const _testsKey = 'test_log_v1';
  static const _amountKey = 'copy_amount_v1';

  final Map<String, TestEntry> _tests = {};
  double copyAmount = DEFAULT_COPY_AMOUNT;
  SharedPreferences? _prefs;

  Future<void> load() async {
    try {
      final prefs = _prefs = await SharedPreferences.getInstance();
      copyAmount = prefs.getDouble(_amountKey) ?? DEFAULT_COPY_AMOUNT;
      final raw = prefs.getString(_testsKey);
      if (raw != null) {
        for (final e
            in (jsonDecode(raw) as List).cast<Map<String, dynamic>>()) {
          final entry = TestEntry.fromJson(e);
          _tests[entry.id] = entry;
        }
      }
    } catch (_) {
      // Unreadable storage: start empty rather than crash.
    }
    notifyListeners();
  }

  List<TestEntry> get tests =>
      _tests.values.toList()
        ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

  TestEntry? testOf(String id) => _tests[id];

  /// Successful ÷ (successful + failed), in %; null when nothing finished yet.
  double? get successRate {
    final done = _tests.values.where((e) => e.status != TestStatus.testing);
    if (done.isEmpty) return null;
    return done.where((e) => e.status == TestStatus.success).length /
        done.length *
        100;
  }

  int count(TestStatus s) => _tests.values.where((e) => e.status == s).length;

  /// Records (or changes) the owner's result for [t]; null removes it.
  Future<void> setTest(Trader t, TestStatus? status) async {
    if (status == null) {
      _tests.remove(t.id);
    } else {
      final old = _tests[t.id];
      _tests[t.id] = TestEntry(
        id: t.id,
        nickname: t.nickname,
        status: status,
        // keep the first recording's date and numbers
        recordedAt: old?.recordedAt ?? DateTime.now(),
        timeRange: old?.timeRange ?? t.timeRange,
        profitFactor: old?.profitFactor ?? t.profitFactor,
        roi: old?.roi ?? t.roi,
      );
    }
    notifyListeners();
    await _prefs?.setString(
      _testsKey,
      jsonEncode([for (final e in _tests.values) e.toJson()]),
    );
  }

  Future<void> setCopyAmount(double amount) async {
    copyAmount = amount;
    notifyListeners();
    await _prefs?.setDouble(_amountKey, amount);
  }
}

/// One store for the whole app.
final appStore = AppStore();
