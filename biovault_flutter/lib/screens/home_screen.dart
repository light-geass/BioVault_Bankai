import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../providers/auth_provider.dart';
import '../providers/wallet_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  int _currentIndex = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData();
    });
  }

  Future<void> _fetchData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final wallet = Provider.of<WalletProvider>(context, listen: false);

    if (auth.userId != null) {
      setState(() => _isLoading = true);
      try {
        await Future.wait([
          wallet.fetchWallet(auth.userId!),
          wallet.fetchHistory(auth.userId!),
        ]);
      } catch (e) {
        debugPrint('Error loading data: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: _isLoading ? _buildShimmerLoading() : _buildContent(),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildContent() {
    return Consumer2<AuthProvider, WalletProvider>(
      builder: (context, auth, wallet, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(auth),
              const SizedBox(height: 24),
              _buildBalanceCard(wallet),
              const SizedBox(height: 24),
              _buildChart(),
              const SizedBox(height: 24),
              _buildQuickActions(),
              const SizedBox(height: 24),
              Text(
                'Recent Transactions',
                style: GoogleFonts.syne(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 16),
              _buildTransactionsList(wallet),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(AuthProvider auth) {
    final initials = auth.userId != null ? 'User'.substring(0, 1).toUpperCase() : 'U';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        CircleAvatar(
          backgroundColor: const Color(0xFF3B82F6),
          radius: 20,
          child: Text(
            initials,
            style: GoogleFonts.dmSans(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Text(
          'BioVault',
          style: GoogleFonts.syne(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: Color(0xFF0F172A)),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildBalanceCard(WalletProvider wallet) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF3B82F6).withOpacity(0.1),
            const Color(0xFF06B6D4).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color.fromRGBO(99, 179, 237, 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Balance',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: const Color(0xFF64748B), // secondary text
            ),
          ),
          const SizedBox(height: 8),
          Text(
            currencyFormat.format(wallet.balance),
            style: GoogleFonts.syne(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            wallet.walletAddress ?? '---',
            style: GoogleFonts.spaceMono(
              fontSize: 12,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            spacing: 8,
            children: [
              _buildChip('SECURED', const Color(0xFFE6F4EA), const Color(0xFF10B981)),
              _buildChip('GEO-LOCKED', const Color(0xFFE3F2FD), const Color(0xFF3B82F6)),
              _buildChip('FACE ID', const Color(0xFFF1F5F9), const Color(0xFF64748B)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label == 'SECURED') ...[
            Icon(Icons.check_circle, size: 10, color: textColor),
            const SizedBox(width: 4),
          ],
          if (label == 'GEO-LOCKED') ...[
            Icon(Icons.location_on, size: 10, color: textColor),
            const SizedBox(width: 4),
          ],
          if (label == 'FACE ID') ...[
            Icon(Icons.lock, size: 10, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FB),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (value, meta) {
                  const style = TextStyle(color: Color(0xFF64748B), fontSize: 10);
                  Widget text;
                  switch (value.toInt()) {
                    case 0: text = const Text('Mon', style: style); break;
                    case 2: text = const Text('Wed', style: style); break;
                    case 4: text = const Text('Fri', style: style); break;
                    case 6: text = const Text('Sun', style: style); break;
                    default: text = const Text(''); break;
                  }
                  return SideTitleWidget(axisSide: meta.axisSide, child: text);
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: const [
                FlSpot(0, 1),
                FlSpot(1, 1.5),
                FlSpot(2, 1.4),
                FlSpot(3, 3.4),
                FlSpot(4, 2),
                FlSpot(5, 2.2),
                FlSpot(6, 1.8),
              ],
              isCurved: true,
              color: const Color(0xFF3B82F6),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF3B82F6).withOpacity(0.2),
                    const Color(0xFF3B82F6).withOpacity(0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildActionCard(Icons.arrow_upward, 'Send', () {}),
        _buildActionCard(Icons.qr_code, 'Receive', () {}),
        _buildActionCard(Icons.history, 'History', () {}),
        _buildActionCard(Icons.timer, 'Time-lock', () {}),
      ],
    );
  }

  Widget _buildActionCard(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 75,
        height: 75,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color.fromRGBO(99, 179, 237, 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF3B82F6), size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsList(WalletProvider wallet) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
    final transactions = wallet.transactions.take(5).toList();

    if (transactions.isEmpty) {
      return Center(
        child: Text(
          'No recent transactions',
          style: GoogleFonts.dmSans(color: const Color(0xFF64748B)),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: transactions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final tx = transactions[index];
        final isSent = tx['direction'] == 'sent';
        final amount = (tx['amount'] as num).toDouble();
        final displayAmount = '${isSent ? '-' : '+'}${currencyFormat.format(amount)}';
        
        DateTime date;
        try {
          date = DateTime.parse(tx['timestamp']);
        } catch (_) {
          date = DateTime.now();
        }
        final dateStr = DateFormat('MMM d, h:mm a').format(date);

        final displayAddress = isSent ? tx['receiver_wallet'] : tx['sender_wallet'];
        final addrPreview = displayAddress != null && displayAddress.length > 12 
            ? '${displayAddress.substring(0, 6)}...${displayAddress.substring(displayAddress.length - 4)}'
            : displayAddress ?? 'Unknown';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSent ? const Color(0xFFFEE2E2) : const Color(0xFFE6F4EA),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSent ? Icons.arrow_outward : Icons.south_west,
                  color: isSent ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      addrPreview,
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateStr,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                displayAmount,
                style: GoogleFonts.syne(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isSent ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShimmerLoading() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        final opacity = 0.5 + (_shimmerController.value * 0.5); // Pulse between 0.5 and 1.0
        return Opacity(
          opacity: opacity,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildShimmerBox(height: 40, width: double.infinity),
                const SizedBox(height: 24),
                _buildShimmerBox(height: 180, width: double.infinity),
                const SizedBox(height: 24),
                _buildShimmerBox(height: 200, width: double.infinity),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(4, (_) => _buildShimmerBox(height: 75, width: 75)),
                ),
                const SizedBox(height: 24),
                _buildShimmerBox(height: 24, width: 150),
                const SizedBox(height: 16),
                ...List.generate(3, (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildShimmerBox(height: 70, width: double.infinity),
                )),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildShimmerBox({required double height, required double width}) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: Colors.white,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF3B82F6),
        unselectedItemColor: const Color(0xFF64748B),
        selectedLabelStyle: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold),
        unselectedLabelStyle: GoogleFonts.dmSans(fontSize: 12),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.arrow_upward), label: 'Send'),
          BottomNavigationBarItem(icon: Icon(Icons.qr_code), label: 'Receive'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
