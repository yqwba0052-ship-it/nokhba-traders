import 'dart:convert';
import 'dart:io';

import 'package:nokhba_traders/models/trader.dart';

/// Real Binance responses saved during step 1 (tests only, never in the app).
Map<String, dynamic> fixture(String name) =>
    jsonDecode(File('test/fixtures/$name').readAsStringSync())
        as Map<String, dynamic>;

List<Map<String, dynamic>> fixtureList(String name) => [
  for (final item in (fixture(name)['data'] as Map)['list'] as List)
    item as Map<String, dynamic>,
];

List<Trader> fixtureTraders(String name, String timeRange) => [
  for (final item in fixtureList(name)) Trader.fromListJson(item, timeRange),
];

/// The moment the fixtures were recorded (timestamp in a saved response).
final fixtureNow = DateTime.fromMillisecondsSinceEpoch(1793049534414);
