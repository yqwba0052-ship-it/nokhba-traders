import 'package:flutter/material.dart';

import '../models/filters.dart';
import '../services/binance_service.dart';
import '../widgets/glass.dart';
import 'glass_list_screen.dart';
import 'pros_screen.dart';

/// Bottom bar with the three screens.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.service});

  final BinanceService service;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  // Built lazily: a screen loads from Binance only when first opened.
  final _built = <int>{0};

  Widget _screen(int i) => switch (i) {
    0 => ProsScreen(service: widget.service),
    1 => GlassListScreen(
      service: widget.service,
      title: 'متداولين اليوم',
      rules: PageRules.today,
    ),
    _ => GlassListScreen(
      service: widget.service,
      title: 'متداولين السنة',
      rules: PageRules.year,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final dark = _index == 0;
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          for (var i = 0; i < 3; i++)
            _built.contains(i) ? _screen(i) : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() {
          _index = i;
          _built.add(i);
        }),
        backgroundColor: dark ? ProsColors.card : const Color(0xFFEDE8FB),
        indicatorColor: dark
            ? ProsColors.sky.withValues(alpha: 0.25)
            : GlassColors.glowPurple.withValues(alpha: 0.35),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontFamily: 'Tajawal',
            fontWeight: FontWeight.w700,
            color: dark ? Colors.white : GlassColors.ink,
          ),
        ),
        destinations: [
          NavigationDestination(
            icon: Icon(
              Icons.star_rounded,
              color: dark ? ProsColors.gold : GlassColors.inkSoft,
            ),
            label: 'المحترفون',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.bolt_rounded,
              color: dark ? ProsColors.muted : GlassColors.ink,
            ),
            label: 'متداولين اليوم',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.emoji_events_rounded,
              color: dark ? ProsColors.muted : GlassColors.ink,
            ),
            label: 'متداولين السنة',
          ),
        ],
      ),
    );
  }
}
