import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider with ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  AuthStatus _status = AuthStatus.unknown;
  String? _token;

  AuthStatus get status => _status;
  String? get token => _token;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  AuthProvider() {
    checkLoginStatus();
  }

  Future<void> checkLoginStatus() async {
    _token = await _storage.read(key: 'jwt_token');
    if (_token != null) {
      _status = AuthStatus.authenticated;
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<void> login(Future<void> Function() loginFunction) async {
    await loginFunction();
    await checkLoginStatus();
  }

  Future<void> logout() async {
    await _storage.deleteAll();
    _status = AuthStatus.unauthenticated;
    _token = null;
    notifyListeners();
  }

  void setGuestMode() {
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}