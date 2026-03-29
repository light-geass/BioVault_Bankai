import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:8000';
  final Dio _dio = Dio(BaseOptions(baseUrl: baseUrl));
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  ApiService() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: "jwt_token");
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
    ));
  }

  Future<Map<String, dynamic>> register(String name, String email, String password, String deviceId) async {
    try {
      final response = await _dio.post('/auth/register', data: {
        'name': name,
        'email': email,
        'password': password,
        'device_id': deviceId,
      });
      return response.data as Map<String, dynamic>;
    } on DioException {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> biometricLogin(String deviceId, String biometricHash) async {
    try {
      final response = await _dio.post('/auth/biometric_login', data: {
        'device_id': deviceId,
        'biometric_hash': biometricHash,
      });
      return response.data as Map<String, dynamic>;
    } on DioException {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getWallet(String userId) async {
    try {
      final response = await _dio.get('/wallet/$userId');
      return response.data as Map<String, dynamic>;
    } on DioException {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> sendTransaction(Map<String, dynamic> body) async {
    try {
      final response = await _dio.post('/wallet/transaction', data: body);
      return response.data as Map<String, dynamic>;
    } on DioException {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getHistory(String userId) async {
    try {
      final response = await _dio.get('/wallet/$userId/history');
      return response.data as Map<String, dynamic>;
    } on DioException {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> toggleGeolock(bool enabled) async {
    try {
      final response = await _dio.post('/geolock/toggle', data: {'enabled': enabled});
      return response.data as Map<String, dynamic>;
    } on DioException {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> addZone(double lat, double lng, double radius, String label) async {
    try {
      final response = await _dio.post('/geolock/zone', data: {
        'lat': lat,
        'lng': lng,
        'radius': radius,
        'label': label,
      });
      return response.data as Map<String, dynamic>;
    } on DioException {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> verifyGeo(double lat, double lng) async {
    try {
      final response = await _dio.post('/geolock/verify', data: {
        'lat': lat,
        'lng': lng,
      });
      return response.data as Map<String, dynamic>;
    } on DioException {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createTimelock(Map<String, dynamic> body) async {
    try {
      final response = await _dio.post('/timelock/create', data: body);
      return response.data as Map<String, dynamic>;
    } on DioException {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getTimelocks(String userId) async {
    try {
      final response = await _dio.get('/timelock/$userId');
      return response.data as Map<String, dynamic>;
    } on DioException {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> confirmTimelock(String id) async {
    try {
      final response = await _dio.post('/timelock/$id/confirm');
      return response.data as Map<String, dynamic>;
    } on DioException {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> enableRecovery(List<String> contacts, int approvals) async {
    try {
      final response = await _dio.post('/recovery/enable', data: {
        'contacts': contacts,
        'approvals_required': approvals,
      });
      return response.data as Map<String, dynamic>;
    } on DioException {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> requestRecovery(String newDeviceId) async {
    try {
      final response = await _dio.post('/recovery/request', data: {
        'new_device_id': newDeviceId,
      });
      return response.data as Map<String, dynamic>;
    } on DioException {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> approveRecovery(String recoveryId) async {
    try {
      final response = await _dio.post('/recovery/$recoveryId/approve');
      return response.data as Map<String, dynamic>;
    } on DioException {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getRecoveryStatus(String id) async {
    try {
      final response = await _dio.get('/recovery/$id');
      return response.data as Map<String, dynamic>;
    } on DioException {
      rethrow;
    }
  }
}
