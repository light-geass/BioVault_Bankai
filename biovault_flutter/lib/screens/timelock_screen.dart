// c:/Hackathons/BioVault_Bankai/biovault_flutter/lib/screens/timelock_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';

import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import '../providers/wallet_provider.dart';

class TimelockScreen extends StatefulWidget {
  const TimelockScreen({Key? key}) : super(key: key);

  @override
  State<TimelockScreen> createState() => _TimelockScreenState();
}

class _TimelockScreenState extends State<TimelockScreen> {
  final ApiService _apiService = ApiService();
  final LocalAuthentication _localAuth = LocalAuthentication();
  
  List<dynamic> _timelocks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTimelocks();
  }

  Future<void> _fetchTimelocks() async {
    final userId = context.read<AuthProvider>().userId;
    if (userId == null) return;
    
    setState(() => _isLoading = true);
    try {
      final data = await _apiService.getTimelocks(userId);
      setState(() => _timelocks = data);
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createTimelock(String receiver, double amount, DateTime date, String note) async {
    try {
      await _apiService.createTimelock({
        'receiver_wallet': receiver,
        'amount': amount,
        'scheduled_at': date.toUtc().toIso8601String(),
        'note': note,
      });
      _fetchTimelocks();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Time-lock scheduled')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _confirmTimelock(String id) async {
    try {
      final didAuth = await _localAuth.authenticate(
        localizedReason: 'Confirm time-locked transfer',
        options: const AuthenticationOptions(biometricOnly: true),
      );

      if (!didAuth) return;

      await _apiService.confirmTimelock(id);
      
      // Update wallet balance
      final auth = context.read<AuthProvider>();
      if (auth.userId != null) {
        await context.read<WalletProvider>().fetchWallet(auth.userId!);
      }
      
      _fetchTimelocks();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transfer completed successfully')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _deleteTimelock(String id) async {
    // Basic DELETE api simulation via Dio since api_service lacks deleteTimelock method directly.
    // Assuming backend endpoint: DELETE /timelock/{id}
    try {
      final dio = Dio(BaseOptions(baseUrl: ApiService.baseUrl));
      final token = context.read<AuthProvider>().jwtToken;
      if (token != null) {
        dio.options.headers['Authorization'] = 'Bearer $token';
      }
      await dio.delete('/timelock/$id');
      _fetchTimelocks();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
    }
  }

  void _showCreateBottomSheet() {
    final receiverCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    DateTime? selectedDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 24, right: 24, top: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('New Time-Lock', style: GoogleFonts.syne(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: receiverCtrl,
                  decoration: InputDecoration(hintText: 'Receiver Wallet', filled: true, fillColor: const Color(0xFFF5F7FB), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(hintText: 'Amount', prefixText: '₹ ', filled: true, fillColor: const Color(0xFFF5F7FB), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  decoration: InputDecoration(hintText: 'Note (Optional)', filled: true, fillColor: const Color(0xFFF5F7FB), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(selectedDate == null ? 'Select Date & Time' : DateFormat('MMM d, y h:mm a').format(selectedDate!)),
                  trailing: const Icon(Icons.calendar_today, color: Color(0xFF3B82F6)),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now().add(const Duration(days: 1)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      final time = await showTimePicker(context: ctx, initialTime: TimeOfDay.now());
                      if (time != null) {
                        setModalState(() {
                          selectedDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                        });
                      }
                    }
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      final amount = double.tryParse(amountCtrl.text) ?? 0;
                      if (receiverCtrl.text.isEmpty || amount <= 0 || selectedDate == null) return;
                      Navigator.pop(ctx);
                      _createTimelock(receiverCtrl.text, amount, selectedDate!, noteCtrl.text);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: Text('Schedule', style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        title: Text('Time-Locked Transfers', style: GoogleFonts.syne(color: const Color(0xFF0F172A), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF3B82F6),
        onPressed: _showCreateBottomSheet,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _timelocks.isEmpty
          ? Center(child: Text('No pending time-locks', style: GoogleFonts.dmSans(color: const Color(0xFF64748B))))
          : RefreshIndicator(
              onRefresh: _fetchTimelocks,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _timelocks.length,
                itemBuilder: (context, index) {
                  final t = _timelocks[index];
                  final isNotified = t['notified'] == true;
                  final date = DateTime.parse(t['scheduled_at']).toLocal();
                  final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2).format(t['amount']);
                  
                  return Dismissible(
                    key: Key(t['id'].toString()),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      color: const Color(0xFFEF4444),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) => _deleteTimelock(t['id']),
                    child: Card(
                      color: const Color(0xFFF5F7FB),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color.fromRGBO(99,179,237,0.18))),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(currency, style: GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: isNotified ? const Color(0xFFFEF3C7) : const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(8)),
                                  child: Text(isNotified ? 'DUE' : 'PENDING', style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.bold, color: isNotified ? const Color(0xFFD97706) : const Color(0xFF64748B))),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('To: ${t['receiver_wallet']}', style: GoogleFonts.spaceMono(fontSize: 12, color: const Color(0xFF64748B))),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.timer, size: 14, color: Color(0xFF3B82F6)),
                                const SizedBox(width: 4),
                                Text(DateFormat('MMM d, y h:mm a').format(date), style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF3B82F6))),
                              ],
                            ),
                            if (isNotified) ...[
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () => _confirmTimelock(t['id']),
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                  child: Text('Confirm Now', style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              )
                            ]
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
