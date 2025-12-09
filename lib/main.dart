import 'package:flutter/material.dart';
import 'utils/palette.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/splash_screen.dart';
import 'screens/premium_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'services/settings_service.dart';
import 'database/hive_database.dart';
import 'services/in_app_notification_service.dart';
import 'services/notification_service.dart';

// Global route observer used by screens that want to know when they become visible.
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔹 Inisialisasi Hive
  await Hive.initFlutter();

  // Pastikan box utama terbuka sebelum digunakan
  await Hive.openBox('userBox');

  // (Opsional) Debug print, kalau mau cek isi box saat startup
  final db = HiveDatabase();
  await db.printAllUsers();

  // 🔹 Inisialisasi format tanggal Indonesia
  await initializeDateFormatting('id_ID', null);

  // 🔹 SharedPreferences
  await SharedPreferences.getInstance();

  // 🔹 App settings
  // Initialize persisted settings (allow_location, allow_notifications)
  await SettingsService.init();

  // 🔹 In-app notifications store
  await InAppNotificationService.init();

  // 🔹 Initialize local/OS notifications (request permissions etc.)
  await NotificationService.init();

  // 🔹 Restore session: check if a user is currently logged in
  final hiveDb = HiveDatabase();
  final currentEmail = await hiveDb.getCurrentUserEmail();

  String? username;
  bool isPremium = false;
  bool hasSession = false;

  if (currentEmail != null) {
    hasSession = true;
    username = await hiveDb.getUsername(currentEmail) ?? 'Pengguna';
    isPremium = await hiveDb.isPremium(currentEmail);
  }

  runApp(
    EjaMateApp(
      hasSession: hasSession,
      isPremium: isPremium,
      username: username ?? 'Pengguna',
    ),
  );
}

class EjaMateApp extends StatelessWidget {
  final bool hasSession;
  final bool isPremium;
  final String username;

  const EjaMateApp({
    super.key,
    required this.hasSession,
    required this.isPremium,
    required this.username,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EjaMate',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // primary swatch kept default but use primary color for App theme
        primaryColor: Palette.primary,
        scaffoldBackgroundColor: Palette.background,
        appBarTheme: const AppBarTheme(backgroundColor: Palette.primaryDark),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Palette.primary,
          primary: Palette.primary,
          secondary: Palette.accent,
        ),
      ),
      navigatorObservers: [routeObserver],
      home: SplashScreenWrapper(
        hasSession: hasSession,
        isPremium: isPremium,
        username: username,
      ),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
      },
    );
  }
}

/// Splash screen wrapper that shows splash, then navigates to home or login
class SplashScreenWrapper extends StatefulWidget {
  final bool hasSession;
  final bool isPremium;
  final String username;

  const SplashScreenWrapper({
    super.key,
    required this.hasSession,
    required this.isPremium,
    required this.username,
  });

  @override
  State<SplashScreenWrapper> createState() => _SplashScreenWrapperState();
}

class _SplashScreenWrapperState extends State<SplashScreenWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        if (widget.hasSession) {
          // If the session exists, navigate to Premium or Home depending on premium flag
          if (widget.isPremium) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => PremiumScreen(username: widget.username),
              ),
            );
          } else {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => HomeScreen(username: widget.username),
              ),
            );
          }
        } else {
          // No session -> show login
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return const SplashScreen();
  }
}
