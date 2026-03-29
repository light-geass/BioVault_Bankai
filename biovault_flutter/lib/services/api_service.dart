import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static const String baseUrl = 'http://10.0.2.2:8000'; // For Android emulator, use localhost for iOS
  final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  ApiService()
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        )) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: 'jwt_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
      ),
    );
  }

  // --- Auth ---
  Future<Map<String, dynamic>> register(
      String name, String email, String password, String deviceId) async {
    final response = await _dio.post('/auth/register', data: {
      'name': name,
      'email': email,
      'password': password,
      'device_id': deviceId,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> biometricLogin(
      String deviceId, String biometricHash) async {
    final response = await _dio.post('/auth/login/biometric', data: {
      'device_id': deviceId,
      'biometric_hash': biometricHash,
    });
    return response.data;
  }

  // --- Wallet ---
  Future<Map<String, dynamic>> getWallet(String userId) async {
    final response = await _dio.get('/wallet/$userId');
    return response.data;
  }

  Future<Map<String, dynamic>> sendTransaction(Map<String, dynamic> body) async {
    final response = await _dio.post('/wallet/transaction', data: body);
    return response.data;
  }

  Future<List<dynamic>> getHistory(String userId) async {
    final response = await _dio.get('/wallet/history/$userId');
    return response.data;
  }

  // --- Geolock ---
  Future<Map<String, dynamic>> toggleGeolock(bool enabled) async {
    final response = await _dio.post('/geolock/toggle', data: {
      'enabled': enabled,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> addZone(
      double lat, double lng, int radius, String label) async {
    final response = await _dio.post('/geolock/add-zone', data: {
      'lat': lat,
      'lng': lng,
      'radius_meters': radius,
      'label': label,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> verifyGeo(double lat, double lng) async {
    final response = await _dio.post('/geolock/verify', data: {
      'lat': lat,
      'lng': lng,
    });
    return response.data;
  }

  // --- Timelock ---
  Future<Map<String, dynamic>> createTimelock(Map<String, dynamic> body) async {
    final response = await _dio.post('/timelock/create', data: body);
    return response.data;
  }

  Future<List<dynamic>> getTimelocks(String userId) async {
    final response = await _dio.get('/timelock/$userId');
    return response.data;
  }

  Future<Map<String, dynamic>> confirmTimelock(String id) async {
    final response = await _dio.post('/timelock/confirm', data: {
      'transfer_id': id,
      'biometric_confirmed': true,
    });
    return response.data;
  }

  // --- Recovery ---
  Future<Map<String, dynamic>> enableRecovery(
      List<String> contacts, int approvals) async {
    final response = await _dio.post('/recovery/enable', data: {
      'trusted_contacts': contacts,
      'approvals_needed': approvals,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> requestRecovery(String newDeviceId) async {
    final response = await _dio.post('/recovery/request', data: {
      'new_device_id': newDeviceId,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> approveRecovery(String recoveryId) async {
    final response = await _dio.post('/recovery/approve', data: {
      'recovery_id': recoveryId,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> getRecoveryStatus(String id) async {
    final response = await _dio.get('/recovery/status/$id');
    return response.data;
  }
}
