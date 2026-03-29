import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class WalletProvider with ChangeNotifier {
  final ApiService _apiService;
  
  double balance = 0.0;
  String? walletAddress;
  List<dynamic> transactions = [];

  WalletProvider(this._apiService);

  Future<void> fetchWallet(String userId) async {
    try {
      final data = await _apiService.getWallet(userId);
      balance = (data['balance'] as num).toDouble();
      walletAddress = data['wallet_address'];
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching wallet: $e');
      rethrow;
    }
  }

  Future<void> fetchHistory(String userId) async {
    try {
      final history = await _apiService.getHistory(userId);
      transactions = history;
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching history: $e');
      rethrow;
    }
  }
}
