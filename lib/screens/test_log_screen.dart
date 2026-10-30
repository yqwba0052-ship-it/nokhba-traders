import 'package:flutter/material.dart';

import '../services/app_store.dart';
import '../widgets/format.dart';
import 'pros_screen.dart' show ProsColors;

/// The owner's own results with recommended traders (separate from Binance's
/// historical numbers).
class TestLogScreen extends StatelessWidget {
  const TestLogScreen({super.key});

  static Color statusColor(TestStatus s) => switch (s) {
    TestStatus.success => ProsColors.green,
    TestStatus.fail => const Color(0xFFF87171),
    TestStatus.testing => ProsColors.gold,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ProsColors.background,
      appBar: AppBar(
        backgroundColor: ProsColors.background,
        foregroundColor: Colors.white,
        title: const Text('سجل اختباراتي'),
      ),
      body: ListenableBuilder(
        listenable: appStore,
        builder: (context, _) {
          final tests = appStore.tests;
          final rate = appStore.successRate;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: ProsColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: ProsColors.border),
                ),
                child: Column(
                  children: [
                    const Text(
                      'نسبة نجاح ترشيحات البرنامج',
                      style: TextStyle(color: ProsColors.muted, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      rate == null ? 'لا يوجد بعد' : formatPercent(rate),
                      style: const TextStyle(
                        color: ProsColors.sky,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ناجح ${appStore.count(TestStatus.success)}  ·  '
                      'فاشل ${appStore.count(TestStatus.fail)}  ·  '
                      'تحت الاختبار ${appStore.count(TestStatus.testing)}',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'النسبة = الناجحون ÷ (الناجحون + الفاشلون)، من نتائجك أنت فقط، '
                      'ولا تدخل في أرقام Binance.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: ProsColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (tests.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'لا يوجد. افتح متداولاً واختر نتيجتك معه في صفحة التفاصيل.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: ProsColors.muted, fontSize: 14),
                  ),
                ),
              for (final e in tests)
                Card(
                  color: ProsColors.card,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(
                      '${e.nickname}  #${e.id.substring(e.id.length - 4)}',
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      'سُجّل ${e.recordedAt.year}-${e.recordedAt.month}-${e.recordedAt.day}'
                      '  ·  الفترة ${e.timeRange}'
                      '  ·  معامل الربحية وقتها ${formatDecimal(e.profitFactor)}',
                      style: const TextStyle(
                        color: ProsColors.muted,
                        fontSize: 12,
                      ),
                    ),
                    trailing: Text(
                      e.status.label,
                      style: TextStyle(
                        color: statusColor(e.status),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
