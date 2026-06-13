import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/printer_service.dart';
import 'database/settings_repository.dart';
import 'database/auth_repository.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();

    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    // Initialize Printer Service
    await PrinterService().init();

    // Ensure legacy settings accounts exist (admin/kasir username-password)
    final settingsRepo = SettingsRepository();
    await settingsRepo.ensureAccountsExist();

    // Ensure new users table exists
    final authRepo = AuthRepository();
    await authRepo.ensureUsersTable();

    // Async camera initialization
    if (!kIsWeb &&
        (Platform.isAndroid || Platform.isIOS || Platform.isWindows)) {
      availableCameras().then((val) {
        cameras = val;
      }).catchError((e) {
        debugPrint('Error initializing cameras: $e');
      });
    }
  } catch (e) {
    debugPrint('Critical startup error: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'POS App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF0F4FF),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoggedIn = false;
  String _role = 'admin';
  bool _isCheckingAuth = true;

  final AuthRepository _authRepo = AuthRepository();

  @override
  void initState() {
    super.initState();
    _checkInitialState();
  }

  Future<void> _checkInitialState() async {
    try {
      await _authRepo.hasAnyUser();
      if (mounted) {
        setState(() {
          _isCheckingAuth = false;
        });
      }
    } catch (e) {
      debugPrint('Auth check error: $e');
      if (mounted) {
        setState(() {
          _isCheckingAuth = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tampilkan loading sementara cek status
    if (_isCheckingAuth) {
      return const _SplashScreen();
    }

    if (!_isLoggedIn) {
      return LoginScreen(
        onLoginSuccess: (role) {
          setState(() {
            _isLoggedIn = true;
            _role = role;
          });
        },
      );
    }

    return HomeScreen(
      role: _role,
      onLogout: () {
        setState(() {
          _isLoggedIn = false;
        });
        // Re-check if users still exist after logout
        _checkInitialState();
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF8C00), Color(0xFFFF5722)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withValues(alpha: 0.35),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: const Icon(
                Icons.storefront_rounded,
                size: 48,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'POS Mini',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Memuat aplikasi...',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF8C00)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
