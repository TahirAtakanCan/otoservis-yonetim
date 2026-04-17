import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Ağ bağlantısı durumu (çevrimiçi / çevrimdışı).
class ConnectivityNotifier extends ChangeNotifier {
  ConnectivityNotifier({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity() {
    _init();
  }

  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  bool _online = true;
  bool get isOnline => _online;

  Future<void> _init() async {
    try {
      final first = await _connectivity.checkConnectivity();
      _setFromResults(first);
    } catch (_) {
      _online = true;
      notifyListeners();
    }

    _sub = _connectivity.onConnectivityChanged.listen(_setFromResults);
  }

  void _setFromResults(List<ConnectivityResult> results) {
    final next = _computeOnline(results);
    if (next != _online) {
      _online = next;
      notifyListeners();
    }
  }

  static bool _computeOnline(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((r) => r != ConnectivityResult.none);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
