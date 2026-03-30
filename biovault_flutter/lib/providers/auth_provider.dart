import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthProvider with ChangeNotifier {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  String? userId;
  String? walletAddress;
  String? jwtToken;
  String? biometricHash;
  bool isLoggedIn = false;

  Future<void> register(String name, String email, String password, String deviceId, ApiService apiService) async {
    try {
      final res = await apiService.register(name, email, password, deviceId);
      userId = res['user_id'];
      walletAddress = res['wallet_address'];
      biometricHash = res['biometric_hash'];

      // Store biometric hash for future logins
      await _storage.write(key: 'user_id', value: userId);
      await _storage.write(key: 'wallet_address', value: walletAddress);
      await _storage.write(key: 'biometric_hash', value: biometricHash);
      await _storage.write(key: 'device_id', value: deviceId);

      // After registration, we still need to login to get a JWT
      await biometricLogin(deviceId, apiService);
    } catch (e) {
      debugPrint('Registration error: $e');
      rethrow;
    }
  }

  Future<void> biometricLogin(String deviceId, ApiService apiService) async {
    try {
      final storedHash = await _storage.read(key: 'biometric_hash');
      if (storedHash == null) throw Exception("No biometric data found. Please register.");

      final res = await apiService.biometricLogin(deviceId, storedHash);
      
      jwtToken = res['access_token'];
      userId = res['user_id'];
      walletAddress = res['wallet_address'];
      isLoggedIn = true;

      await _storage.write(key: 'jwt_token', value: jwtToken);
      notifyListeners();
    } catch (e) {
      debugPrint('Login error: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    userId = null;
    walletAddress = null;
    jwtToken = null;
    isLoggedIn = false;

    await _storage.delete(key: 'jwt_token');
    // We keep biometric_hash and user_id for future easy logins
    notifyListeners();
  }

  Future<bool> tryAutoLogin() async {
    final token = await _storage.read(key: 'jwt_token');
    if (token == null) return false;

    jwtToken = token;
    userId = await _storage.read(key: 'user_id');
    walletAddress = await _storage.read(key: 'wallet_address');
    biometricHash = await _storage.read(key: 'biometric_hash');
    isLoggedIn = true;
    
    notifyListeners();
    return true;
  }
}
