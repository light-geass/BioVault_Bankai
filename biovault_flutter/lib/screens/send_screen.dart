// c:/Hackathons/BioVault_Bankai/biovault_flutter/lib/screens/send_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:local_auth/local_auth.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'dart:io';

import '../services/api_service.dart';
import '../providers/wallet_provider.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({Key? key}) : super(key: key);

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> with TickerProviderStateMixin {
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final LocalAuthentication _localAuth = LocalAuthentication();
  final ApiService _apiService = ApiService();

  bool _isProcessing = false;
  int _currentStep = 0; // 0: Idle, 1: Formatting/GPS, 2: Geo Verify, 3: Biometric, 4: APICall
  String _errorMessage = '';

  QRViewController? _qrController;
  final GlobalKey _qrKey = GlobalKey(debugLabel: 'QR');
  bool _isScanning = false;

  late AnimationController _successAnimController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _successAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _scaleAnimation =
        CurvedAnimation(parent: _successAnimController, curve: Curves.elasticOut);
  }

  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      _qrController?.pauseCamera();
    }
    _qrController?.resumeCamera();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _amountController.dispose();
    _qrController?.dispose();
    _successAnimController.dispose();
    super.dispose();
  }

  void _onQRViewCreated(QRViewController controller) {
    setState(() => _qrController = controller);
    controller.scannedDataStream.listen((scanData) {
      if (scanData.code != null && scanData.code!.isNotEmpty) {
        setState(() {
          _addressController.text = scanData.code!;
          _isScanning = false;
        });
        controller.pauseCamera();
      }
    });
  }

  Future<void> _verifyAndSend() async {
    final wallet = Provider.of<WalletProvider>(context, listen: false);
    final receiver = _addressController.text.trim();
    final amountText = _amountController.text.trim();

    if (receiver.isEmpty || amountText.isEmpty) return;
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) return;
    if (amount > wallet.balance) {
      setState(() => _errorMessage = 'Insufficient balance.');
      return;
    }

    setState(() {
      _errorMessage = '';
      _isProcessing = true;
      _currentStep = 1; // Getting Location
    });

    try {
      // Step 1: GPS Coords
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      // Step 2: Geo Verify API
      setState(() => _currentStep = 2);
      final geoRes = await _apiService.verifyGeo(position.latitude, position.longitude);
      
      if (geoRes['safe'] == false) {
         setState(() {
          _isProcessing = false;
          _errorMessage = geoRes['reason'] ?? 'Transaction blocked: Not in safe zone';
          _currentStep = 0;
        });
        return;
      }

      // Step 3: Biometric
      setState(() => _currentStep = 3);
      final isHighValue = amount >= 500;
      final reason = isHighValue
          ? 'Face ID required for high-value transfer'
          : 'Confirm transfer with fingerprint';
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(biometricOnly: true),
      );

      if (!didAuthenticate) {
        throw Exception('Biometric authentication failed');
      }

      // Step 4: POST /transaction
      setState(() => _currentStep = 4);
      final biometricUsed = isHighValue ? 'face_id' : 'fingerprint';
      final res = await _apiService.sendTransaction({
        'receiver_wallet': receiver,
        'amount': amount,
        'biometric_used': biometricUsed,
        'geo_verified': true,
      });

      // Update provider memory
      wallet.balance = (res['new_balance'] as num).toDouble();
      wallet.notifyListeners();

      // Step 5: Success Sheet
      setState(() {
        _isProcessing = false;
        _currentStep = 0;
      });
      _showSuccessSheet(res['transaction_id'].toString(), amountText);
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
        _currentStep = 0;
      });
    }
  }

  void _showSuccessSheet(String txId, String amount) {
    _successAnimController.forward(from: 0.0);
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 40),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Transfer Successful!',
                style: GoogleFonts.syne(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sent ₹$amount',
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'TX ID: $txId',
                  style: GoogleFonts.spaceMono(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context); // Go back home
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Done',
                    style: GoogleFonts.dmSans(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        title: Text(
          'Send BVC',
          style: GoogleFonts.syne(color: const Color(0xFF0F172A), fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: _isScanning ? _buildScanner() : _buildForm(),
    );
  }

  Widget _buildScanner() {
    return Stack(
      children: [
        QRView(
          key: _qrKey,
          onQRViewCreated: _onQRViewCreated,
          overlay: QrScannerOverlayShape(
            borderColor: const Color(0xFF3B82F6),
            borderRadius: 10,
            borderLength: 30,
            borderWidth: 10,
            cutOutSize: 250,
          ),
        ),
         Positioned(
          top: 40,
          right: 20,
           child: IconButton(
             icon: const Icon(Icons.close, color: Colors.white, size: 30),
             onPressed: () => setState(() {
               _isScanning = false;
               _qrController?.pauseCamera();
             }),
           ),
         ),
      ],
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_errorMessage.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Color(0xFFEF4444)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage,
                      style: GoogleFonts.dmSans(color: const Color(0xFFB91C1C)),
                    ),
                  ),
                ],
              ),
            ),

          Text(
            'Transfer To',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _addressController,
            decoration: InputDecoration(
              hintText: 'Enter Wallet Address',
              hintStyle: GoogleFonts.dmSans(color: const Color(0xFF94A3B8)),
              filled: true,
              fillColor: const Color(0xFFF5F7FB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF3B82F6)),
                onPressed: () => setState(() => _isScanning = true),
              ),
            ),
            style: GoogleFonts.spaceMono(color: const Color(0xFF0F172A)),
          ),
          
          const SizedBox(height: 24),
          
          Text(
            'Amount (₹)',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: '0.00',
              hintStyle: GoogleFonts.dmSans(color: const Color(0xFF94A3B8)),
              filled: true,
              fillColor: const Color(0xFFF5F7FB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Padding(
                padding: EdgeInsets.all(14.0),
                child: Text('₹', style: TextStyle(fontSize: 18, color: Color(0xFF0F172A))),
              ),
            ),
            style: GoogleFonts.syne(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
          ),

          const SizedBox(height: 48),

          if (_isProcessing)
            _buildProgressIndicator()
          else
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _verifyAndSend,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Verify & Send',
                  style: GoogleFonts.dmSans(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
            final active = index + 1 == _currentStep;
            final past = index + 1 < _currentStep;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              width: active ? 12 : 8,
              height: active ? 12 : 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: past 
                    ? const Color(0xFF10B981) 
                    : active 
                        ? const Color(0xFF3B82F6) 
                        : const Color(0xFFE2E8F0),
              ),
            );
          }),
        ),
        const SizedBox(height: 24),
        const CircularProgressIndicator(color: Color(0xFF3B82F6)),
        const SizedBox(height: 16),
        Text(
          _currentStep == 1 ? 'Getting secure location...' :
          _currentStep == 2 ? 'Verifying geo-zone...' :
          _currentStep == 3 ? 'Awaiting biometrics...' :
          'Processing transaction...',
          style: GoogleFonts.dmSans(color: const Color(0xFF64748B)),
        ),
      ],
    );
  }
}
