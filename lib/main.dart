import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/attendance_provider.dart';
import 'providers/leave_provider.dart';
import 'providers/admin_provider.dart';
import 'services/connectivity_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/background_location_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  BackgroundLocationService.init();
  
  final authProvider = AuthProvider();
  await authProvider.checkAuth();

  final connectivityService = ConnectivityService();
  await connectivityService.checkInitialConnection();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: connectivityService),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
        ChangeNotifierProvider(create: (_) => LeaveProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DabIndia Attendance',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      builder: (context, child) {
        final isOnline = context.watch<ConnectivityService>().isOnline;
        return Stack(
          children: [
            child!,
            if (!isOnline)
              Positioned(
                top: MediaQuery.of(context).padding.top,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  alignment: Alignment.center,
                  child: const Text('Offline - Check your connection', 
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        );
      },
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return auth.isAuthenticated ? const HomeScreen() : const LoginScreen();
        },
      ),
    );
  }
}
