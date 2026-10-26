import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nokhba_traders/models/trader.dart';
import 'package:nokhba_traders/screens/trader_details_screen.dart';

import 'helpers.dart';

void main() {
  testWidgets('details screen shows real numbers, Sharpe "غير متوفر"', (
    tester,
  ) async {
    final t = fixtureTraders('list_30D_ROI_hideFullFalse.json', '30D').first
        .withPerformance(
          const Performance(timeRange: '30D', totalOrder: 266, winOrders: 200),
        );
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: TraderDetailsScreen(trader: t, now: fixtureNow),
      ),
    );
    await tester.pump();

    expect(
      Directionality.of(tester.element(find.text('迪亚马特'))),
      TextDirection.rtl,
    );
    expect(find.text('迪亚马特'), findsOneWidget);
    expect(find.text('غير متوفر'), findsOneWidget); // Sharpe is null
    expect(find.text('733 من 800'), findsOneWidget);
    expect(find.text('المخاطرة: منخفضة'), findsOneWidget);
    expect(find.text('266'), findsOneWidget);
    expect(find.text('200'), findsOneWidget);
    expect(find.text('افتح صفحة المتداول في Binance'), findsOneWidget);
    expect(
      find.textContaining('الأداء السابق لا يضمن الأرباح القادمة'),
      findsOneWidget,
    );
  });
}
