import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/trader.dart';
import '../widgets/format.dart';
import '../widgets/trader_avatar.dart';
import 'pros_screen.dart' show ProsColors;

class TraderDetailsScreen extends StatelessWidget {
  const TraderDetailsScreen({
    super.key,
    required this.trader,
    required this.now,
  });

  final Trader trader;

  /// When the numbers were loaded (daily trades are measured up to this time).
  final DateTime now;

  Future<void> _openBinance(BuildContext context) async {
    final ok = await launchUrl(
      Uri.parse(trader.binanceUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر فتح الرابط: ${trader.binanceUrl}')),
      );
    }
  }

  Color get _riskColor => switch (trader.riskLabel) {
    'منخفضة' => const Color(0xFF22C55E),
    'متوسطة' => ProsColors.gold,
    _ => const Color(0xFFF87171),
  };

  @override
  Widget build(BuildContext context) {
    final t = trader;
    final period = periodLabel(t.timeRange);
    final stats = <(String, String, Color?)>[
      ('العائد ROI', formatSignedPercent(t.roi), const Color(0xFF22C55E)),
      ('الربح PNL', formatUsd(t.pnl), const Color(0xFF22C55E)),
      ('أقصى تراجع', formatPercent(t.mdd), null),
      ('نسبة الفوز', formatPercent(t.winRate), null),
      ('Sharpe', formatDecimal(t.sharpRatio), null),
      ('الأموال المُدارة', formatUsd(t.aum), null),
      (
        'الناسخون',
        '${formatInt(t.currentCopyCount)} من ${formatInt(t.maxCopyCount)}',
        t.isCopyAvailable ? ProsColors.sky : const Color(0xFFF87171),
      ),
      ('الصفقات اليومية', formatDecimal(t.dailyTrades(now)), ProsColors.sky),
      ('إجمالي الصفقات', formatInt(t.totalOrder), null),
      ('الصفقات الرابحة', formatInt(t.winOrders), null),
    ];
    return Scaffold(
      backgroundColor: ProsColors.background,
      appBar: AppBar(
        backgroundColor: ProsColors.background,
        foregroundColor: Colors.white,
        title: const Text('تفاصيل المتداول'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Center(
            child: TraderAvatar(
              url: t.avatarUrl,
              size: 96,
              colors: const [ProsColors.sky, ProsColors.gold],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            t.nickname,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: _riskColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _riskColor),
              ),
              child: Text(
                'المخاطرة: ${t.riskLabel}',
                style: TextStyle(
                  color: _riskColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'كل الأرقام لآخر $period، من Binance مباشرة',
            textAlign: TextAlign.center,
            style: const TextStyle(color: ProsColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.1,
            children: [
              for (final (label, value, color) in stats)
                _StatTile(label: label, value: value, color: color),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: ProsColors.gold,
              foregroundColor: const Color(0xFF1A1300),
              minimumSize: const Size.fromHeight(54),
              textStyle: const TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () => _openBinance(context),
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('افتح صفحة المتداول في Binance'),
          ),
          const SizedBox(height: 14),
          const Text(
            '⚠️ الأداء السابق لا يضمن الأرباح القادمة',
            textAlign: TextAlign.center,
            style: TextStyle(color: ProsColors.muted, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ProsColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ProsColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: ProsColors.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              style: TextStyle(
                color: color ?? Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
