import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityService with ChangeNotifier {
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  ConnectivityService() {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      // If the list contains any result other than 'none', we're online
      final hasConnection = results.any((result) => result != ConnectivityResult.none);
      _isOnline = hasConnection;
      notifyListeners();
    });
  }

  Future<void> checkInitialConnection() async {
    final results = await Connectivity().checkConnectivity();
    _isOnline = results.any((result) => result != ConnectivityResult.none);
    notifyListeners();
  }
}
