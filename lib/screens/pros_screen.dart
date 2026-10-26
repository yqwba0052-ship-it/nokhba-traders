import 'package:flutter/material.dart';

import '../config.dart';
import '../models/filters.dart';
import '../models/trader.dart';
import '../services/binance_service.dart';
import '../services/page_loader.dart';
import '../widgets/format.dart';
import '../widgets/state_views.dart';
import '../widgets/trader_avatar.dart';
import 'trader_details_screen.dart';

abstract final class ProsColors {
  static const background = Color(0xFF0B1220);
  static const card = Color(0xFF111B2E);
  static const border = Color(0xFF1E2A44);
  static const sky = Color(0xFF38BDF8);
  static const gold = Color(0xFFFACC15);
  static const muted = Color(0xFF94A3B8);
  static const green = Color(0xFF22C55E);
}

/// المحترفون: high profit, low risk, with a 7/30/90-day choice.
class ProsScreen extends StatefulWidget {
  const ProsScreen({super.key, required this.service});

  final BinanceService service;

  @override
  State<ProsScreen> createState() => _ProsScreenState();
}

class _ProsScreenState extends State<ProsScreen>
    with AutomaticKeepAliveClientMixin {
  final Map<String, PageLoader> _loaders = {};
  String _range = PROS_DEFAULT_TIME_RANGE;

  @override
  bool get wantKeepAlive => true;

  PageLoader get _loader => _loaders.putIfAbsent(_range, () {
    final loader = PageLoader(widget.service, PageRules.pros(_range))
      ..addListener(_changed);
    loader.load();
    return loader;
  });

  void _changed() => setState(() {});

  @override
  void dispose() {
    for (final l in _loaders.values) {
      l.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final loader = _loader;
    return ColoredBox(
      color: ProsColors.background,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 2),
              child: Text(
                'المحترفون ⭐',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'ربح عالٍ ومخاطرة منخفضة، مرتبون حسب الربح مقابل المخاطرة',
                style: TextStyle(color: ProsColors.muted, fontSize: 13.5),
              ),
            ),
            const SizedBox(height: 12),
            _rangePicker(loader),
            const SizedBox(height: 6),
            _status(loader),
            const SizedBox(height: 6),
            Expanded(child: _body(loader)),
          ],
        ),
      ),
    );
  }

  Widget _rangePicker(PageLoader loader) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final r in PROS_TIME_RANGES) ...[
            Expanded(
              child: ChoiceChip(
                showCheckmark: false,
                label: SizedBox(
                  width: double.infinity,
                  child: Text(periodLabel(r), textAlign: TextAlign.center),
                ),
                selected: r == _range,
                onSelected: (_) => setState(() => _range = r),
                backgroundColor: ProsColors.card,
                selectedColor: ProsColors.sky,
                side: BorderSide(
                  color: r == _range ? ProsColors.sky : ProsColors.border,
                ),
                labelStyle: TextStyle(
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.w700,
                  color: r == _range ? ProsColors.background : Colors.white,
                ),
              ),
            ),
            if (r != PROS_TIME_RANGES.last) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _status(PageLoader loader) {
    final r = loader.result;
    String text;
    if (loader.loading) {
      text = loader.total > 0
          ? 'فحص ${loader.stage} ${loader.done} من ${loader.total}…'
          : 'جلب المتداولين من Binance…';
    } else if (r != null) {
      text =
          '${r.traders.length} متداول  ·  تحديث ${formatTime(r.loadedAt)}'
          '${r.skipped > 0 ? '  ·  تعذّر فحص ${r.skipped}' : ''}';
    } else {
      text = '';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        text,
        style: const TextStyle(color: ProsColors.muted, fontSize: 12.5),
      ),
    );
  }

  Widget _body(PageLoader loader) {
    final result = loader.result;
    if (loader.loading && result == null) return const _ProsSkeleton();
    Widget fill(Widget child) => LayoutBuilder(
      builder: (context, box) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [SizedBox(height: box.maxHeight, child: child)],
      ),
    );
    final traders = result?.traders ?? const <Trader>[];
    return RefreshIndicator(
      color: ProsColors.sky,
      backgroundColor: ProsColors.card,
      onRefresh: loader.load,
      child: loader.error != null && traders.isEmpty
          ? fill(
              ErrorView(
                message: loader.error!,
                onRetry: loader.load,
                color: Colors.white,
                buttonColor: ProsColors.sky,
                buttonTextColor: ProsColors.background,
              ),
            )
          : traders.isEmpty
          ? fill(const EmptyView(color: Colors.white))
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              itemCount: traders.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _ProCard(
                rank: i + 1,
                trader: traders[i],
                now: result!.loadedAt,
              ),
            ),
    );
  }
}

class _ProCard extends StatelessWidget {
  const _ProCard({required this.rank, required this.trader, required this.now});

  final int rank;
  final Trader trader;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final t = trader;
    return Material(
      color: ProsColors.card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TraderDetailsScreen(trader: t, now: now),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: rank <= 3
                  ? ProsColors.gold.withValues(alpha: 0.6)
                  : ProsColors.border,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 26,
                child: Text(
                  '$rank',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: rank <= 3 ? ProsColors.gold : ProsColors.muted,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              TraderAvatar(
                url: t.avatarUrl,
                size: 48,
                colors: const [ProsColors.sky, ProsColors.gold],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.nickname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'تراجع ${formatPercent(t.mdd)}  ·  فوز ${formatPercent(t.winRate)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ProsColors.muted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatSignedPercent(t.roi),
                    style: const TextStyle(
                      color: ProsColors.green,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ربح ${formatUsd(t.pnl)}',
                    style: const TextStyle(color: ProsColors.sky, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProsSkeleton extends StatelessWidget {
  const _ProsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: 7,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, _) => Container(
        height: 74,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ProsColors.card,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Row(
          children: [
            Skeleton(
              width: 48,
              height: 48,
              radius: 24,
              color: ProsColors.border,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(width: 130, color: ProsColors.border),
                  SizedBox(height: 8),
                  Skeleton(width: 200, height: 10, color: ProsColors.border),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
