import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthProvider with ChangeNotifier {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  String? userId;
  String? walletAddress;
  String? jwtToken;
  bool isLoggedIn = false;

  Future<void> login(String id, String wallet, String token) async {
    userId = id;
    walletAddress = wallet;
    jwtToken = token;
    isLoggedIn = true;

    await _storage.write(key: 'jwt_token', value: token);
    await _storage.write(key: 'user_id', value: id);
    await _storage.write(key: 'wallet_address', value: wallet);

    notifyListeners();
  }

  Future<void> logout() async {
    userId = null;
    walletAddress = null;
    jwtToken = null;
    isLoggedIn = false;

    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'user_id');
    await _storage.delete(key: 'wallet_address');

    notifyListeners();
  }

  Future<bool> tryAutoLogin() async {
    final token = await _storage.read(key: 'jwt_token');
    if (token == null) return false;

    jwtToken = token;
    userId = await _storage.read(key: 'user_id');
    walletAddress = await _storage.read(key: 'wallet_address');
    isLoggedIn = true;
    
    notifyListeners();
    return true;
  }
}
