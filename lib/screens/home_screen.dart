import 'package:flutter/material.dart';
import '../services/user_status_service.dart';
import '../database/hive_database.dart';
import 'home_tab.dart';
import 'payment_offer_screen.dart';
import 'kuis_screen.dart';
import 'premium_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final String username;
  const HomeScreen({Key? key, required this.username}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _isChecking = true;
  bool _navigated = false; // 🔹 Cegah double navigation async
  late final List<Widget?> _pages;

  @override
  void initState() {
    super.initState();
    _checkPremiumStatus();
    // Lazily create KuisScreen only when selected so the question-count
    // prompt can be shown each time the user opens the Kuis tab.
    _pages = [
      HomeTab(username: widget.username), // Beranda
      const PaymentOfferScreen(), // Pembayaran
      null, // KuisScreen will be created on demand in _onItemTapped
      const ProfileScreen(), // Profil
    ];
  }

  /// 🔹 Cek status premium dari Hive (melalui UserStatusService)
  Future<void> _checkPremiumStatus() async {
    try {
      final isPremium = await UserStatusService.isPremium();

      if (!mounted || _navigated) return;

      if (isPremium) {
        _navigated = true;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PremiumScreen(username: widget.username),
          ),
        );
      } else {
        setState(() => _isChecking = false);
      }
    } catch (e) {
      debugPrint("❌ Error checking premium status: $e");
      if (mounted) setState(() => _isChecking = false);
    }
  }

  void _onItemTapped(int index) {
    // Recreate KuisScreen each time the Kuis tab is selected so the
    // question-count prompt appears again when the user returns.
    if (index == 2) {
      debugPrint('▶️ HomeScreen: creating/recreating KuisScreen for selection');
      _pages[2] = const KuisScreen();
    }
    setState(() => _selectedIndex = index);

    // Persist per-user last_tab so premium sessions and restarts can restore
    // the last-used tab regardless of which screen class saved it previously.
    try {
      HiveDatabase().getCurrentUserEmail().then((current) async {
        if (current != null) {
          final hive = HiveDatabase();
          await hive.updateUser(current, {'last_tab': index});
        }
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        backgroundColor: Color(0xFF001F3F),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.orangeAccent),
              SizedBox(height: 12),
              Text(
                "Memeriksa status akun kamu...",
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF001F3F),
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: _pages.map((w) => w ?? const SizedBox()).toList(),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: const Color(0xFF012D5A),
        selectedItemColor: Colors.orangeAccent,
        unselectedItemColor: Colors.white70,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: "Beranda",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.payment_outlined),
            label: "Pembayaran",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.quiz_outlined),
            label: "Kuis",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: "Profil",
          ),
        ],
      ),
    );
  }
}
