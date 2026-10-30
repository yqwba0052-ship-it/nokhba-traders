import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nokhba_traders/models/trade_stats.dart';
import 'package:nokhba_traders/models/trader.dart';
import 'package:nokhba_traders/screens/trader_details_screen.dart';
import 'package:nokhba_traders/services/app_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

Future<void> _show(WidgetTester tester, Trader t, DateTime now) async {
  await tester.binding.setSurfaceSize(const Size(420, 4200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: TraderDetailsScreen(trader: t, now: now),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await appStore.load();
  });

  testWidgets('details screen shows real numbers, Sharpe "غير متوفر"', (
    tester,
  ) async {
    final t = fixtureTraders('list_30D_ROI_hideFullFalse.json', '30D').first
        .withPerformance(
          const Performance(timeRange: '30D', totalOrder: 266, winOrders: 200),
        )
        .withDetail(fixture('detail.json')['data'] as Map<String, dynamic>);
    await _show(tester, t, fixtureNow);

    expect(
      Directionality.of(tester.element(find.text('迪亚马特'))),
      TextDirection.rtl,
    );
    expect(find.text('迪亚马特'), findsOneWidget);
    expect(find.text('معرّف المحفظة: ${t.id}'), findsOneWidget);
    expect(find.text('غير متوفر'), findsOneWidget); // Sharpe is null
    expect(find.text('733 من 800'), findsOneWidget);
    expect(find.text('المخاطرة: منخفضة'), findsOneWidget);
    expect(find.text('266'), findsOneWidget);
    expect(find.text('200'), findsOneWidget);
    final c = t.curve!;
    expect(find.text('${c.losingDays} من ${c.days}'), findsOneWidget);
    expect(find.text('متوسطة (10x–20x)'), findsOneWidget);
    expect(find.text('ربح المتداول نفسه'), findsOneWidget);
    expect(find.text('ربح كل الناسخين (الفترة)'), findsOneWidget);
    expect(find.text('ربح كل الناسخين (منذ البداية)'), findsOneWidget);
    expect(find.textContaining('لا تنشر نتيجة كل ناسخ'), findsOneWidget);
    // no trade history loaded: never a made-up profit factor
    expect(find.text('بيانات غير كافية'), findsWidgets);
    // detail.json hides open positions
    expect(find.text('الصفقات مخفية'), findsOneWidget);
    expect(find.text('افتح صفحة المتداول في Binance'), findsOneWidget);
    expect(
      find.textContaining('الأداء السابق لا يضمن الأرباح القادمة'),
      findsOneWidget,
    );
  });

  testWidgets('real trades: profit factor, coverage, floating loss, copy', (
    tester,
  ) async {
    final perf = Performance.fromJson(
      fixture('perf_${historyId}_30D.json')['data'] as Map<String, dynamic>,
    );
    final t = fixtureTraders('list_30D_ROI_page1_size30.json', '30D').first
        .withPerformance(perf)
        .withDetail(
          fixture('detail_$historyId.json')['data'] as Map<String, dynamic>,
        )
        .withOpenPositions(
          OpenPositions.fromJson(
            fixture('positions_$historyId.json')['data'] as List,
          ),
        )
        .withTrades(
          TradeStats.fromHistory(
            historyRows(),
            historyNow.subtract(const Duration(days: 30)).toUtc(),
            officialCount: perf.totalOrder,
            officialWins: perf.winOrders,
          ),
        );
    await _show(tester, t, historyNow);

    // 54696 / (3080 + 1625)
    expect(find.textContaining('11.63 ضعف'), findsOneWidget);
    expect(find.textContaining('57 من 57'), findsOneWidget);
    expect(find.textContaining('38.44%'), findsOneWidget); // best 3 trades
    expect(find.textContaining('2.59%'), findsOneWidget); // floating loss
    expect(find.textContaining('أرقام المحفظة الرسمية'), findsOneWidget);
    // min copy 200 USDT, default amount 100 USDT
    expect(find.textContaining('أقل من الحد الأدنى'), findsOneWidget);

    // the owner's test result is saved apart from Binance's numbers
    await tester.tap(find.text('ناجح'));
    await tester.pump();
    expect(appStore.testOf(t.id)?.status, TestStatus.success);
    expect(appStore.testOf(t.id)?.profitFactor, closeTo(11.626057, 1e-5));
    expect(appStore.successRate, 100);
  });
}
