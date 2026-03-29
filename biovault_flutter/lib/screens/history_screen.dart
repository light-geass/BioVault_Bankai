// c:/Hackathons/BioVault_Bankai/biovault_flutter/lib/screens/history_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../providers/wallet_provider.dart';
import '../providers/auth_provider.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _searchQuery = '';
  String _filter = 'All'; // All, Sent, Received

  Future<void> _refresh() async {
    final auth = context.read<AuthProvider>();
    if (auth.userId != null) {
      await context.read<WalletProvider>().fetchHistory(auth.userId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        title: Text('History', style: GoogleFonts.syne(color: const Color(0xFF0F172A), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: Column(
        children: [
          // Search & Filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search by address or amount',
                hintStyle: GoogleFonts.dmSans(color: const Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
                filled: true,
                fillColor: const Color(0xFFF5F7FB),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('All'),
                const SizedBox(width: 8),
                _buildFilterChip('Sent'),
                const SizedBox(width: 8),
                _buildFilterChip('Received'),
              ],
            ),
          ),
          
          Expanded(
            child: Consumer<WalletProvider>(
              builder: (context, wallet, child) {
                var txs = wallet.transactions;

                // Filtering
                if (_filter == 'Sent') txs = txs.where((t) => t['direction'] == 'sent').toList();
                if (_filter == 'Received') txs = txs.where((t) => t['direction'] == 'received').toList();

                // Searching
                if (_searchQuery.isNotEmpty) {
                  txs = txs.where((t) {
                    final addr = t['sender_wallet'].toString().toLowerCase() + t['receiver_wallet'].toString().toLowerCase();
                    final amt = t['amount'].toString();
                    return addr.contains(_searchQuery) || amt.contains(_searchQuery);
                  }).toList();
                }

                if (txs.isEmpty) {
                  return Center(child: Text('No transactions found', style: GoogleFonts.dmSans(color: const Color(0xFF64748B))));
                }

                return RefreshIndicator(
                  onRefresh: _refresh,
                  color: const Color(0xFF3B82F6),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: txs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final tx = txs[index];
                      final isSent = tx['direction'] == 'sent';
                      final amount = (tx['amount'] as num).toDouble();
                      final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
                      final displayAmount = '${isSent ? '-' : '+'}${currencyFormat.format(amount)}';
                      
                      final date = DateTime.parse(tx['timestamp']).toLocal();
                      final dateStr = DateFormat('MMM d, y, h:mm a').format(date);
                      
                      final displayAddress = isSent ? tx['receiver_wallet'] : tx['sender_wallet'];
                      
                      return Card(
                        color: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Color.fromRGBO(99,179,237,0.18)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: isSent ? const Color(0xFFFEE2E2) : const Color(0xFFE6F4EA),
                                    radius: 20,
                                    child: Icon(
                                      isSent ? Icons.arrow_outward : Icons.south_west,
                                      color: isSent ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(isSent ? 'Sent To' : 'Received From', style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF64748B))),
                                        Text(displayAddress, style: GoogleFonts.spaceMono(fontSize: 12, color: const Color(0xFF0F172A), fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                                      ],
                                    ),
                                  ),
                                  Text(displayAmount, style: GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.bold, color: isSent ? const Color(0xFFEF4444) : const Color(0xFF10B981))),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(dateStr, style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF64748B))),
                                  Row(
                                    children: [
                                      if (tx['biometric_used'] != null)
                                        Container(
                                          margin: const EdgeInsets.only(right: 6),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4)),
                                          child: Text(tx['biometric_used'] == 'face_id' ? 'FACE ID' : 'FINGERPRINT', style: GoogleFonts.dmSans(fontSize: 10, color: const Color(0xFF64748B), fontWeight: FontWeight.bold)),
                                        ),
                                      if (tx['geo_verified'] == true)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(4)),
                                          child: Text('GEO-VERIFIED', style: GoogleFonts.dmSans(fontSize: 10, color: const Color(0xFF3B82F6), fontWeight: FontWeight.bold)),
                                        ),
                                    ],
                                  )
                                ],
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final active = _filter == label;
    return GestureDetector(
      onTap: () => setState(() => _filter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF3B82F6) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}
