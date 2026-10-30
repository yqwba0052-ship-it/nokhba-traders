import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/home_screen.dart';
import 'screens/pros_screen.dart';
import 'services/app_store.dart';
import 'services/binance_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await appStore.load(); // the owner's test results and copy amount
  runApp(NokhbaApp(service: BinanceService()));
}

class NokhbaApp extends StatelessWidget {
  const NokhbaApp({super.key, required this.service});

  final BinanceService service;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'نخبة المتداولين',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        fontFamily: 'Tajawal',
        colorScheme: ColorScheme.fromSeed(
          seedColor: ProsColors.sky,
          brightness: Brightness.dark,
        ),
      ),
      home: HomeScreen(service: service),
    );
  }
}
