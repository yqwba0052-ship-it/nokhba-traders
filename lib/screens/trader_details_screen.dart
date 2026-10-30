import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/trader.dart';
import '../services/app_store.dart';
import '../widgets/copy.dart';
import '../widgets/format.dart';
import '../widgets/trader_avatar.dart';
import 'pros_screen.dart' show ProsColors;
import 'test_log_screen.dart';

/// Shown when a number cannot be computed exactly.
const _na = 'بيانات غير كافية';
const _green = Color(0xFF22C55E);
const _red = Color(0xFFF87171);

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

  Future<void> _editAmount(BuildContext context) async {
    final controller = TextEditingController(
      text: appStore.copyAmount.toStringAsFixed(0),
    );
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مبلغ النسخ (USDT)'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, double.tryParse(controller.text.trim())),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (value != null && value > 0) await appStore.setCopyAmount(value);
  }

  Color get _riskColor => switch (trader.riskLabel) {
    'منخفضة' => _green,
    'متوسطة' => ProsColors.gold,
    _ => _red,
  };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appStore,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final t = trader;
    final period = periodLabel(t.timeRange);
    final c = t.curve;
    final s = t.trades;
    final pf = t.profitFactor;
    final amount = appStore.copyAmount;
    final minCopy = t.minCopyFixedAmount;
    final copyable = s?.copyableShare(amount, t.marginBalance);
    String perfRoi(String range) {
      final p = t.performance[range];
      return p == null
          ? _na
          : '${formatSignedPercent(p.roi)}  (${formatUsd(p.pnl)})';
    }

    final stats = <(String, String, Color?)>[
      (
        'معامل الربحية',
        s == null || !s.verified
            ? _na
            : pf == null
            ? 'بلا خسائر'
            : '${formatDecimal(pf)} ضعف',
        _green,
      ),
      (
        'سجل الصفقات المعتمد',
        s == null || s.coverage == null
            ? _na
            : '${s.count} من ${formatInt(s.officialCount)} '
                  '(${formatPercent(s.coverage! * 100)})',
        null,
      ),
      (
        'متوسط الربح / الخسارة',
        s == null || s.averageWin == null
            ? _na
            : '${formatUsd(s.averageWin)} / '
                  '${s.averageLoss == null ? 'بلا خسائر' : formatUsd(s.averageLoss)}',
        null,
      ),
      (
        'من الأرباح: أفضل 3 صفقات',
        s?.top3ProfitShare == null ? _na : formatPercent(s!.top3ProfitShare),
        null,
      ),
      (
        'أيام فيها صفقات',
        t.tradingDaysShare(now) == null
            ? _na
            : '${s!.tradingDays} يوماً (${formatPercent(t.tradingDaysShare(now))})',
        ProsColors.sky,
      ),
      (
        'الخسارة العائمة الآن',
        t.floatingLossPct == null
            ? (t.positionShow == false ? 'الصفقات مخفية' : _na)
            : '${formatUsd(t.open!.floatingLoss)} '
                  '(${formatPercent(t.floatingLossPct)})',
        (t.floatingLossPct ?? 0) > 0 ? _red : null,
      ),
      (
        'الصفقات المفتوحة',
        t.open == null
            ? _na
            : '${t.open!.count} · الحجم ${formatDecimal(t.exposure, decimals: 1)}× الرصيد',
        null,
      ),
      ('ROI آخر 30 يوماً', perfRoi('30D'), null),
      ('ROI آخر 90 يوماً', perfRoi('90D'), null),
      ('أسوأ يوم', formatPercent(c?.worstDay), null),
      (
        'الأيام الخاسرة',
        c == null ? 'غير متوفر' : '${c.losingDays} من ${c.days}',
        null,
      ),
      ('الرافعة', t.leverageLabel, null),
      ('ربح المتداول نفسه', formatUsd(t.pnl), (t.pnl ?? 0) > 0 ? _green : null),
      (
        'ربح كل الناسخين (الفترة)',
        formatUsd(t.copierPnl),
        (t.copierPnl ?? 0) > 0 ? _green : null,
      ),
      (
        'ربح كل الناسخين (منذ البداية)',
        formatUsd(t.copierPnlTotal),
        (t.copierPnlTotal ?? 0) > 0 ? _green : null,
      ),
      ('العائد ROI', formatSignedPercent(t.roi), _green),
      ('الربح PNL', formatUsd(t.pnl), _green),
      ('أقصى تراجع', formatPercent(t.mdd), null),
      ('نسبة الفوز', formatPercent(t.winRate), null),
      ('Sharpe', formatDecimal(t.sharpRatio), null),
      ('الأموال المُدارة', formatUsd(t.aum), null),
      (
        'الناسخون',
        '${formatInt(t.currentCopyCount)} من ${formatInt(t.maxCopyCount)}',
        t.isCopyAvailable ? ProsColors.sky : _red,
      ),
      ('الصفقات اليومية', formatDecimal(t.dailyTrades(now)), ProsColors.sky),
      ('إجمالي الصفقات', formatInt(t.totalOrder), null),
      ('الصفقات الرابحة', formatInt(t.winOrders), null),
      (
        'الحد الأدنى للنسخ',
        minCopy == null
            ? _na
            : 'مبلغ ثابت ${formatUsd(minCopy)} · نسبة ${formatUsd(t.minCopyFixedRatio)}',
        null,
      ),
    ];
    final amountOk = minCopy != null && amount >= minCopy;
    final test = appStore.testOf(t.id);
    return Scaffold(
      backgroundColor: ProsColors.background,
      appBar: AppBar(
        backgroundColor: ProsColors.background,
        foregroundColor: Colors.white,
        title: const Text('تفاصيل المتداول'),
        actions: [
          IconButton(
            tooltip: 'سجل اختباراتي',
            icon: const Icon(Icons.fact_check_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const TestLogScreen()),
            ),
          ),
        ],
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
          SelectableText(
            t.nickname,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          SelectableText(
            'معرّف المحفظة: ${t.id}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: ProsColors.muted, fontSize: 12),
          ),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 4,
            children: [
              TextButton.icon(
                onPressed: () => copyText(context, t.nickname, 'الاسم'),
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('نسخ الاسم'),
              ),
              TextButton.icon(
                onPressed: () => copyText(
                  context,
                  '${t.nickname}\n${t.id}\n${t.binanceUrl}',
                  'الاسم والمعرّف والرابط',
                ),
                icon: const Icon(Icons.copy_all_rounded, size: 18),
                label: const Text('نسخ الكل'),
              ),
            ],
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
            t.official
                ? 'كل الأرقام لآخر $period، من Binance مباشرة (أرقام المحفظة الرسمية)'
                : 'كل الأرقام لآخر $period، من قائمة Binance (لم تُطابَق بعد)',
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
            childAspectRatio: 1.9,
            children: [
              for (final (label, value, color) in stats)
                _StatTile(label: label, value: value, color: color),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'ربح الناسخين هو مجموعهم كلهم. Binance لا تنشر نتيجة كل ناسخ، '
            'فقد يكون بعضهم خاسراً حتى لو كان المجموع رابحاً.',
            style: TextStyle(color: ProsColors.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 16),
          _Box(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'مبلغ نسخك: ${formatUsd(amount)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _editAmount(context),
                    child: const Text('تغيير'),
                  ),
                ],
              ),
              Text(
                minCopy == null
                    ? 'الحد الأدنى: $_na'
                    : amountOk
                    ? '✓ يكفي للحد الأدنى (${formatUsd(minCopy)})'
                    : '✗ أقل من الحد الأدنى (${formatUsd(minCopy)})',
                style: TextStyle(
                  color: minCopy == null
                      ? ProsColors.muted
                      : amountOk
                      ? _green
                      : _red,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                copyable == null
                    ? 'صفقات يمكن نسخها بمبلغك: $_na'
                    : 'صفقات يمكن نسخها بمبلغك بالنسبة: ${formatPercent(copyable)} '
                          '(تقدير: رصيده ${formatUsd(t.marginBalance)}، وأصغر أمر '
                          'في Binance 5 USDT لأغلب العقود)',
                style: const TextStyle(color: ProsColors.muted, fontSize: 12.5),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Box(
            children: [
              const Text(
                'نتيجتي مع هذا المتداول',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final status in TestStatus.values)
                    ChoiceChip(
                      label: Text(status.label),
                      selected: test?.status == status,
                      selectedColor: TestLogScreen.statusColor(status)
                          .withValues(alpha: 0.35),
                      onSelected: (on) =>
                          appStore.setTest(t, on ? status : null),
                    ),
                ],
              ),
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

class _Box extends StatelessWidget {
  const _Box({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: ProsColors.card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: ProsColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
