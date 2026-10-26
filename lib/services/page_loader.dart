import 'package:flutter/foundation.dart';

import '../models/filters.dart';
import 'binance_service.dart';

/// Loading state of one screen (or one period of the pros screen).
class PageLoader extends ChangeNotifier {
  PageLoader(this._service, this.rules);

  final BinanceService _service;
  final PageRules rules;

  PageResult? result;
  String? error;
  bool loading = false;
  String stage = '';
  int done = 0;
  int total = 0;
  bool _disposed = false;

  Future<void> load() async {
    if (loading) return;
    loading = true;
    error = null;
    done = total = 0;
    stage = '';
    _notify();
    try {
      result = await _service.loadPage(
        rules,
        onProgress: (s, d, t) {
          stage = s;
          done = d;
          total = t;
          _notify();
        },
      );
    } on BinanceException catch (e) {
      error = e.message;
    } catch (e) {
      error = 'حدث خطأ غير متوقع: $e';
    } finally {
      loading = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
