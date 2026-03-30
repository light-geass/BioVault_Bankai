// c:/Hackathons/BioVault_Bankai/biovault_flutter/lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:workmanager/workmanager.dart';

import 'providers/auth_provider.dart';
import 'providers/wallet_provider.dart';
import 'services/api_service.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // In a real scenario, this background worker might pull from local DB or just fire an isolated API ping
    debugPrint("Native background task executing: $task");
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: true,
  );
  
  await Workmanager().registerPeriodicTask(
    "1",
    "biovaultTimelockCheck",
    frequency: const Duration(minutes: 15),
    constraints: Constraints(
      networkType: NetworkType.connected,
    ),
  );

  final authProvider = AuthProvider();
  await authProvider.tryAutoLogin();

  final apiService = ApiService();
  final walletProvider = WalletProvider(apiService);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: walletProvider),
      ],
      child: const BioVaultApp(),
    ),
  );
}

class BioVaultApp extends StatelessWidget {
  const BioVaultApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BioVault',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFFFFFFF),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3B82F6)),
      ),
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (auth.isLoggedIn) {
            return const HomeScreen(); // Or a custom Wrapper that holds the BottomNav
          } else {
            return const LoginScreen();
          }
        },
      ),
    );
  }
}
