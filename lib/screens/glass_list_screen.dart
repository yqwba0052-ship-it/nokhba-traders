import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config.dart';
import '../models/filters.dart';
import '../models/trader.dart';
import '../services/binance_service.dart';
import '../services/page_loader.dart';
import '../widgets/format.dart';
import '../widgets/glass.dart';
import '../widgets/state_views.dart';
import '../widgets/trader_avatar.dart';
import 'trader_details_screen.dart';

/// متداولين اليوم / متداولين السنة: glass panel, 9 rows per page.
class GlassListScreen extends StatefulWidget {
  const GlassListScreen({
    super.key,
    required this.service,
    required this.title,
    required this.rules,
  });

  final BinanceService service;
  final String title;
  final PageRules rules;

  @override
  State<GlassListScreen> createState() => _GlassListScreenState();
}

class _GlassListScreenState extends State<GlassListScreen>
    with AutomaticKeepAliveClientMixin {
  late final PageLoader _loader = PageLoader(widget.service, widget.rules)
    ..addListener(_changed);
  int _page = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loader.load();
  }

  @override
  void dispose() {
    _loader.dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  Future<void> _refresh() async {
    _page = 0;
    await _loader.load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return GlassBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: GlassBox(
            radius: 34,
            fill: 0.22,
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
            child: Column(
              children: [
                _header(),
                const SizedBox(height: 6),
                _subtitle(),
                const SizedBox(height: 8),
                Expanded(child: _body()),
                const SizedBox(height: 8),
                _pager(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Expanded(
          child: GlassBox(
            radius: 30,
            fill: 0.38,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
            child: Text(
              widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: GlassColors.ink,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GlassCircleButton(
          size: 52,
          tooltip: 'تحديث',
          onPressed: _loader.loading ? null : _refresh,
          child: _SpinningRefresh(spinning: _loader.loading),
        ),
      ],
    );
  }

  Widget _subtitle() {
    final r = _loader.result;
    final parts = <String>[
      'الفترة: آخر ${periodLabel(widget.rules.timeRange)}',
    ];
    if (_loader.loading && _loader.total > 0) {
      parts.add('فحص ${_loader.stage} ${_loader.done} من ${_loader.total}');
    } else if (r != null) {
      parts.add('${r.traders.length} متداول');
      parts.add('تحديث ${formatTime(r.loadedAt)}');
      if (r.skipped > 0) parts.add('تعذّر فحص ${r.skipped}');
    }
    return Text(
      parts.join('  ·  '),
      textAlign: TextAlign.center,
      style: const TextStyle(color: GlassColors.inkSoft, fontSize: 12.5),
    );
  }

  Widget _body() {
    final result = _loader.result;
    if (_loader.loading && result == null) return const _GlassSkeleton();
    if (_loader.error != null && result == null) {
      return ErrorView(
        message: _loader.error!,
        onRetry: _refresh,
        color: GlassColors.ink,
        buttonColor: GlassColors.ink,
        buttonTextColor: Colors.white,
      );
    }
    final traders = result?.traders ?? const <Trader>[];
    final pages = _pageCount(traders.length);
    final page = math.min(_page, pages - 1);
    final visible = traders
        .skip(page * ROWS_PER_GLASS_PAGE)
        .take(ROWS_PER_GLASS_PAGE)
        .toList();
    return LayoutBuilder(
      builder: (context, box) {
        const gap = 7.0;
        final extent = math.max(
          58.0,
          (box.maxHeight - gap * (ROWS_PER_GLASS_PAGE - 1)) /
              ROWS_PER_GLASS_PAGE,
        );
        return RefreshIndicator(
          color: GlassColors.glowPurple,
          onRefresh: _refresh,
          child: traders.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: box.maxHeight,
                      child: _loader.error != null
                          ? ErrorView(
                              message: _loader.error!,
                              onRetry: _refresh,
                              color: GlassColors.ink,
                              buttonColor: GlassColors.ink,
                              buttonTextColor: Colors.white,
                            )
                          : const EmptyView(color: GlassColors.ink),
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => const SizedBox(height: gap),
                  itemBuilder: (context, i) => SizedBox(
                    height: extent,
                    child: _GlassRow(trader: visible[i], now: result!.loadedAt),
                  ),
                ),
        );
      },
    );
  }

  int _pageCount(int n) => math.max(1, (n / ROWS_PER_GLASS_PAGE).ceil());

  Widget _pager() {
    final pages = _pageCount(_loader.result?.traders.length ?? 0);
    final page = math.min(_page, pages - 1);
    // RTL row: first child sits on the right.
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GlassCircleButton(
          tooltip: 'الصفحة السابقة',
          onPressed: page > 0 ? () => setState(() => _page = page - 1) : null,
          child: const FixedIcon(Icons.arrow_forward_rounded),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Text(
            'صفحة ${page + 1} من $pages',
            style: const TextStyle(
              color: GlassColors.ink,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        GlassCircleButton(
          tooltip: 'الصفحة التالية',
          onPressed: page < pages - 1
              ? () => setState(() => _page = page + 1)
              : null,
          child: const FixedIcon(Icons.arrow_back_rounded),
        ),
      ],
    );
  }
}

class _SpinningRefresh extends StatefulWidget {
  const _SpinningRefresh({required this.spinning});

  final bool spinning;

  @override
  State<_SpinningRefresh> createState() => _SpinningRefreshState();
}

class _SpinningRefreshState extends State<_SpinningRefresh>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.spinning) _controller.repeat();
  }

  @override
  void didUpdateWidget(_SpinningRefresh old) {
    super.didUpdateWidget(old);
    if (widget.spinning && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.spinning && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(
    turns: _controller,
    child: const FixedIcon(Icons.sync_rounded, size: 26),
  );
}

class _GlassRow extends StatelessWidget {
  const _GlassRow({required this.trader, required this.now});

  final Trader trader;
  final DateTime now;

  void _open(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => TraderDetailsScreen(trader: trader, now: now),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return GlassBox(
      radius: 22,
      fill: 0.34,
      glow: false,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => _open(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                TraderAvatar(url: trader.avatarUrl, size: 42),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              trader.nickname,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: GlassColors.ink,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            formatSignedPercent(trader.roi),
                            style: const TextStyle(
                              color: GlassColors.green,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'صفقات يومية ${formatDecimal(trader.dailyTrades(now), decimals: 1)}'
                        '  ·  تراجع ${formatPercent(trader.mdd)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: GlassColors.inkSoft,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GlassCircleButton(
                  size: 32,
                  tooltip: 'التفاصيل',
                  onPressed: () => _open(context),
                  child: const FixedIcon(Icons.chevron_left_rounded, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassSkeleton extends StatelessWidget {
  const _GlassSkeleton();

  @override
  Widget build(BuildContext context) {
    final shade = Colors.white.withValues(alpha: 0.75);
    return Column(
      children: [
        for (var i = 0; i < ROWS_PER_GLASS_PAGE; i++) ...[
          if (i > 0) const SizedBox(height: 7),
          Expanded(
            child: GlassBox(
              radius: 22,
              fill: 0.3,
              glow: false,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Skeleton(width: 42, height: 42, radius: 21, color: shade),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Skeleton(width: 140, color: shade),
                        const SizedBox(height: 6),
                        Skeleton(width: 190, height: 10, color: shade),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
