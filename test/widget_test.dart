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
        )
        .withDetail(fixture('detail.json')['data'] as Map<String, dynamic>);
    await tester.binding.setSurfaceSize(const Size(420, 2400));
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
    // profit against loss and risk, from the real 30-day ROI curve
    final c = t.curve!;
    expect(find.text('الأرباح ÷ الخسائر'), findsOneWidget);
    expect(find.text('${c.losingDays} من ${c.days}'), findsOneWidget);
    expect(find.text('متوسطة (10x–20x)'), findsOneWidget);
    expect(find.text('ربح الناسخين (الفترة)'), findsOneWidget);
    expect(find.text('ربح الناسخين (منذ البداية)'), findsOneWidget);
    expect(find.text('افتح صفحة المتداول في Binance'), findsOneWidget);
    expect(
      find.textContaining('الأداء السابق لا يضمن الأرباح القادمة'),
      findsOneWidget,
    );
  });
}
