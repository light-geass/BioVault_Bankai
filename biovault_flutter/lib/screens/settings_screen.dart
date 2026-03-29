// c:/Hackathons/BioVault_Bankai/biovault_flutter/lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../providers/auth_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ApiService _apiService = ApiService();
  bool _geoLockEnabled = false;
  bool _recoveryEnabled = false;

  void _logout() async {
    await context.read<AuthProvider>().logout();
    // Assuming pushing to OnboardScreen logic is handled in main.dart wrapper for null auth.
  }

  void _showAddZoneDialog() {
    final latCtrl = TextEditingController();
    final lngCtrl = TextEditingController();
    final radCtrl = TextEditingController();
    final labelCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Safe Zone', style: GoogleFonts.syne(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: labelCtrl, decoration: const InputDecoration(labelText: 'Label (e.g. Home)')),
            TextField(controller: latCtrl, decoration: const InputDecoration(labelText: 'Latitude'), keyboardType: TextInputType.number),
            TextField(controller: lngCtrl, decoration: const InputDecoration(labelText: 'Longitude'), keyboardType: TextInputType.number),
            TextField(controller: radCtrl, decoration: const InputDecoration(labelText: 'Radius (meters)'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                await _apiService.addZone(
                  double.parse(latCtrl.text),
                  double.parse(lngCtrl.text),
                  int.parse(radCtrl.text),
                  labelCtrl.text,
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Safe zone added')));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showTrustedContactsDialog() {
    final contact1Ctrl = TextEditingController();
    final contact2Ctrl = TextEditingController();
    final approvalsCtrl = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Enable Recovery', style: GoogleFonts.syne(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: contact1Ctrl, decoration: const InputDecoration(labelText: 'Trusted Contact 1 (User ID)')),
            TextField(controller: contact2Ctrl, decoration: const InputDecoration(labelText: 'Trusted Contact 2 (User ID) (Optional)')),
            TextField(controller: approvalsCtrl, decoration: const InputDecoration(labelText: 'Approvals Needed'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                final contacts = [contact1Ctrl.text];
                if (contact2Ctrl.text.isNotEmpty) contacts.add(contact2Ctrl.text);
                
                await _apiService.enableRecovery(contacts, int.parse(approvalsCtrl.text));
                setState(() => _recoveryEnabled = true);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recovery enabled')));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }

  void _showInitiateRecoveryDialog() {
    final devIdCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Initiate Recovery', style: GoogleFonts.syne(fontWeight: FontWeight.bold)),
        content: TextField(controller: devIdCtrl, decoration: const InputDecoration(labelText: 'New Device ID')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                await _apiService.requestRecovery(devIdCtrl.text);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recovery initiated')));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Request'),
          ),
        ],
      ),
    );
  }

  void _showApproveRecoveryDialog() {
    final reqIdCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Approve Recovery', style: GoogleFonts.syne(fontWeight: FontWeight.bold)),
        content: TextField(controller: reqIdCtrl, decoration: const InputDecoration(labelText: 'Recovery Request ID')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                await _apiService.approveRecovery(reqIdCtrl.text);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recovery approved')));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8, top: 24),
      child: Text(
        title,
        style: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Card(
      color: const Color(0xFFF5F7FB),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(children: children),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        title: Text('Settings', style: GoogleFonts.syne(color: const Color(0xFF0F172A), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('GEO-LOCK'),
          _buildCard([
            SwitchListTile(
              title: Text('Enable Geo-Lock', style: GoogleFonts.dmSans(color: const Color(0xFF0F172A))),
              value: _geoLockEnabled,
              activeColor: const Color(0xFF3B82F6),
              onChanged: (val) async {
                try {
                  await _apiService.toggleGeolock(val);
                  setState(() => _geoLockEnabled = val);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
                }
              },
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              leading: const Icon(Icons.add_location, color: Color(0xFF3B82F6)),
              title: Text('Add Safe Zone', style: GoogleFonts.dmSans(color: const Color(0xFF0F172A))),
              trailing: const Icon(Icons.chevron_right, color: Color(0xFF64748B)),
              onTap: _showAddZoneDialog,
            ),
          ]),

          _buildSectionHeader('SOCIAL RECOVERY'),
          _buildCard([
            SwitchListTile(
              title: Text('Enable Recovery', style: GoogleFonts.dmSans(color: const Color(0xFF0F172A))),
              value: _recoveryEnabled,
              activeColor: const Color(0xFF3B82F6),
              onChanged: (val) {
                if (val) _showTrustedContactsDialog();
              },
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              leading: const Icon(Icons.phonelink_ring, color: Color(0xFF3B82F6)),
              title: Text('Initiate Recovery', style: GoogleFonts.dmSans(color: const Color(0xFF0F172A))),
              onTap: _showInitiateRecoveryDialog,
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              leading: const Icon(Icons.thumb_up, color: Color(0xFF10B981)),
              title: Text('Approve Recovery', style: GoogleFonts.dmSans(color: const Color(0xFF0F172A))),
              onTap: _showApproveRecoveryDialog,
            ),
          ]),

          _buildSectionHeader('ACCOUNT'),
          _buildCard([
            ListTile(
              leading: const Icon(Icons.person, color: Color(0xFF64748B)),
              title: Text('Wallet Address', style: GoogleFonts.dmSans(color: const Color(0xFF0F172A))),
              subtitle: Text(auth.walletAddress ?? 'Unknown', style: GoogleFonts.spaceMono(fontSize: 12)),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              leading: const Icon(Icons.fingerprint, color: Color(0xFF64748B)),
              title: Text('Biometric Enabled', style: GoogleFonts.dmSans(color: const Color(0xFF0F172A))),
              trailing: const Icon(Icons.check_circle, color: Color(0xFF10B981)),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              leading: const Icon(Icons.logout, color: Color(0xFFEF4444)),
              title: Text('Logout', style: GoogleFonts.dmSans(color: const Color(0xFFEF4444), fontWeight: FontWeight.bold)),
              onTap: _logout,
            ),
          ]),
        ],
      ),
    );
  }
}
