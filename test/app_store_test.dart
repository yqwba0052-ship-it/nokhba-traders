import 'package:flutter_test/flutter_test.dart';
import 'package:nokhba_traders/config.dart';
import 'package:nokhba_traders/services/app_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

void main() {
  final traders = fixtureTraders('list_30D_ROI_page1_size30.json', '30D');

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'success rate = success / (success + fail); testing not counted',
    () async {
      final store = AppStore();
      await store.load();
      expect(store.successRate, isNull);
      await store.setTest(traders[0], TestStatus.success);
      await store.setTest(traders[1], TestStatus.fail);
      await store.setTest(traders[2], TestStatus.fail);
      await store.setTest(traders[3], TestStatus.testing);
      expect(store.successRate, closeTo(100 / 3, 1e-9));
      expect(store.count(TestStatus.testing), 1);
    },
  );

  test(
    'results and copy amount survive a restart (saved on the phone)',
    () async {
      final store = AppStore();
      await store.load();
      await store.setTest(traders[0], TestStatus.testing);
      await store.setTest(traders[0], TestStatus.success); // changed later
      await store.setCopyAmount(250);

      final again = AppStore();
      await again.load();
      expect(again.copyAmount, 250);
      expect(again.tests, hasLength(1));
      expect(again.testOf(traders[0].id)?.status, TestStatus.success);
    },
  );

  test('two portfolios with the same name stay separate (by id)', () async {
    final store = AppStore();
    await store.load();
    final a = traders[0];
    final b = fixtureTraders('list_30D_ROI_page1_size30.json', '30D')[1];
    await store.setTest(a, TestStatus.success);
    await store.setTest(b, TestStatus.fail);
    expect(store.tests, hasLength(2));
    await store.setTest(a, null); // removed
    expect(store.tests.single.id, b.id);
  });

  test('default copy amount', () async {
    final store = AppStore();
    await store.load();
    expect(store.copyAmount, DEFAULT_COPY_AMOUNT);
  });
}
