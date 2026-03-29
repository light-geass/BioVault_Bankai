import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthProvider extends ChangeNotifier {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  String? _userId;
  String? _walletAddress;
  String? _jwtToken;
  bool _isLoggedIn = false;

  String? get userId => _userId;
  String? get walletAddress => _walletAddress;
  String? get jwtToken => _jwtToken;
  bool get isLoggedIn => _isLoggedIn;

  Future<void> login(String userId, String wallet, String token) async {
    await _storage.write(key: 'jwt_token', value: token);
    await _storage.write(key: 'user_id', value: userId);
    await _storage.write(key: 'wallet_address', value: wallet);

    _userId = userId;
    _walletAddress = wallet;
    _jwtToken = token;
    _isLoggedIn = true;

    notifyListeners();
  }

  Future<void> logout() async {
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'user_id');
    await _storage.delete(key: 'wallet_address');

    _userId = null;
    _walletAddress = null;
    _jwtToken = null;
    _isLoggedIn = false;

    notifyListeners();
  }

  Future<bool> tryAutoLogin() async {
    final token = await _storage.read(key: 'jwt_token');
    if (token == null) {
      return false;
    }

    _jwtToken = token;
    _userId = await _storage.read(key: 'user_id');
    _walletAddress = await _storage.read(key: 'wallet_address');
    _isLoggedIn = true;

    notifyListeners();
    return true;
  }
}
