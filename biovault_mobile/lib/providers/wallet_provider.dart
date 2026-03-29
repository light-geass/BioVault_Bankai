import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class WalletProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  double _balance = 0.0;
  String? _walletAddress;
  List<dynamic> _transactions = [];

  double get balance => _balance;
  String? get walletAddress => _walletAddress;
  List<dynamic> get transactions => _transactions;

  Future<void> fetchWallet(String userId) async {
    try {
      final data = await _apiService.getWallet(userId);
      _balance = (data['balance'] ?? 0.0).toDouble();
      _walletAddress = data['wallet_address'];
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print("Error fetching wallet: $e");
      }
      rethrow;
    }
  }

  Future<void> fetchHistory(String userId) async {
    try {
      final data = await _apiService.getHistory(userId);
      _transactions = data['transactions'] ?? [];
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print("Error fetching history: $e");
      }
      rethrow;
    }
  }
}
