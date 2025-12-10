import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import '../services/progress_service.dart';
import '../database/hive_database.dart';
import '../widgets/custom_app_bar.dart';
import 'edit_profile_screen.dart';
import 'settings_detail_screen.dart';
import '../services/history_service.dart';
import 'package:intl/intl.dart';
import '../services/quiz_history_service.dart';
import '../models/payment_history.dart';
import '../utils/currency_utils.dart';
import 'transaction_detail_screen.dart';
import 'quiz_history_screen.dart';
import 'informasi_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? username = 'User';
  String? email = '-';
  String? profileImagePath;
  bool isPremium = false;
  String? kesanPesan;
  List<PaymentHistory> transactions = [];
  List<dynamic> quizHistories = [];
  bool _loading = true;
  StreamSubscription? _quizSub;

  @override
  void initState() {
    super.initState();
    _load();
    // subscribe to live quiz history updates (prefer username key)
    _quizSub = QuizHistoryService.onChanged.listen((_) async {
      if (!mounted) return;
      try {
        final hive = HiveDatabase();
        final current = await hive.getCurrentUserEmail();
        String? u;
        if (current != null) u = await hive.getUsername(current);
        if (u != null && u.isNotEmpty) {
          final list = await QuizHistoryService.allForUser(u);
          setState(() => quizHistories = list);
        } else if (current != null) {
          final list = await QuizHistoryService.allFor(current);
          setState(() => quizHistories = list);
        }
      } catch (_) {}
    });
  }

  Future<void> _load() async {
    final hive = HiveDatabase();
    final current = await hive.getCurrentUserEmail();
    if (current != null) {
      final box = await hive.getUserBox();
      final data = box.get(current);
      if (data is Map) {
        username = (data['username'] ?? 'User').toString();
        email = (data['email'] ?? current).toString();
        profileImagePath = data['profile_image']?.toString();
        isPremium = (data['isPremium'] ?? false) as bool;
        kesanPesan = data['kesanPesan']?.toString();
        transactions = await HistoryService.getHistory(current);
        // prefer username-based history storage when available
        final u =
            (data['username'] != null && data['username'].toString().isNotEmpty)
            ? data['username'].toString()
            : await hive.getUsername(current);
        if (u != null && u.isNotEmpty) {
          quizHistories = await QuizHistoryService.allForUser(u);
        } else {
          quizHistories = await QuizHistoryService.allFor(current);
        }
      }
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _quizSub?.cancel();
    super.dispose();
  }

  String _formatShortAmount(double value, String currency) =>
      CurrencyUtils.short(value, currency);

  /// 🔹 Pilih gambar profil dari galeri atau kamera
  Future<void> _pickProfileImage() async {
    final ImagePicker picker = ImagePicker();
    // First ask for confirmation to change profile photo
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF00345B),
        title: const Text(
          'Ubah Foto Profil',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Anda akan mengubah foto profil. Aplikasi mungkin akan meminta izin akses kamera/galeri.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Lanjutkan'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Show source selection
    final source = await showModalBottomSheet<ImageSource?>(
      context: context,
      backgroundColor: const Color(0xFF00345B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.photo_library,
                  color: Colors.orangeAccent,
                ),
                title: const Text(
                  'Dari Galeri',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(
                  Icons.camera_alt,
                  color: Colors.orangeAccent,
                ),
                title: const Text(
                  'Ambil Foto',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (source == null) return;

    // Request necessary permission based on source
    bool granted = true;
    try {
      if (source == ImageSource.camera) {
        final status = await Permission.camera.request();
        granted = status.isGranted;
        if (!granted && status.isPermanentlyDenied) {
          // Ask user to open settings
          final goSettings = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF00345B),
              title: const Text(
                'Izin Kamera Diperlukan',
                style: TextStyle(color: Colors.white),
              ),
              content: const Text(
                'Silakan aktifkan izin kamera pada pengaturan aplikasi untuk menggunakan fitur ini.',
                style: TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text(
                    'Batal',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                  ),
                  child: const Text('Buka Pengaturan'),
                ),
              ],
            ),
          );
          if (goSettings == true) openAppSettings();
        }
      } else {
        // Gallery permission: platform-specific. On Android 13+ we should
        // request the photos/media permission (READ_MEDIA_IMAGES). The
        // permission_handler exposes `Permission.photos` which maps accordingly
        // on Android/iOS. Try `Permission.photos` first for broader coverage,
        // fallback to storage on older Android versions.
        if (Platform.isAndroid) {
          // Try requesting photos/media permission (Android 13+)
          var status = await Permission.photos.request();
          granted = status.isGranted;

          // If not available/granted, fallback to legacy storage permission
          if (!granted) {
            status = await Permission.storage.request();
            granted = status.isGranted;
          }

          if (!granted && status.isPermanentlyDenied) {
            final goSettings = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: const Color(0xFF00345B),
                title: const Text(
                  'Izin Penyimpanan Diperlukan',
                  style: TextStyle(color: Colors.white),
                ),
                content: const Text(
                  'Silakan aktifkan izin penyimpanan pada pengaturan aplikasi untuk memilih foto dari galeri.',
                  style: TextStyle(color: Colors.white70),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text(
                      'Batal',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                    ),
                    child: const Text('Buka Pengaturan'),
                  ),
                ],
              ),
            );
            if (goSettings == true) openAppSettings();
          }
        } else if (Platform.isIOS) {
          final status = await Permission.photos.request();
          granted = status.isGranted;
          if (!granted && status.isPermanentlyDenied) {
            final goSettings = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: const Color(0xFF00345B),
                title: const Text(
                  'Izin Foto Diperlukan',
                  style: TextStyle(color: Colors.white),
                ),
                content: const Text(
                  'Silakan aktifkan izin Foto pada pengaturan aplikasi untuk memilih gambar dari galeri.',
                  style: TextStyle(color: Colors.white70),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text(
                      'Batal',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                    ),
                    child: const Text('Buka Pengaturan'),
                  ),
                ],
              ),
            );
            if (goSettings == true) openAppSettings();
          }
        }
      }
    } catch (_) {
      granted = false;
    }

    if (!granted) return;

    // pick image
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile == null) return;

    // show preview and ask confirm before saving
    final confirmSave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF00345B),
        title: const Text(
          'Preview Foto',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.file(
              File(pickedFile.path),
              width: 180,
              height: 180,
              fit: BoxFit.cover,
            ),
            const SizedBox(height: 12),
            const Text(
              'Simpan foto ini sebagai foto profil?',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (confirmSave == true) {
      await _saveProfileImage(pickedFile.path);
    }
  }

  /// 🔹 Simpan gambar profil ke Hive
  Future<void> _saveProfileImage(String imagePath) async {
    final hiveDb = HiveDatabase();
    final currentEmail = await hiveDb.getCurrentUserEmail();

    if (currentEmail != null && currentEmail.isNotEmpty) {
      final userBox = await hiveDb.getUserBox();

      // Update user data dengan profile image
      if (userBox.containsKey(currentEmail)) {
        final userData = userBox.get(currentEmail);
        if (userData is Map) {
          final updated = {
            ...Map<String, dynamic>.from(userData),
            'profile_image': imagePath,
          };
          await userBox.put(currentEmail, updated);
        }
      }

      // Also save via HiveDatabase method
      await hiveDb.setUserProfileImage(currentEmail, imagePath);
    }

    // Update state
    setState(() {
      profileImagePath = imagePath;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto profil berhasil diperbarui!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Profil Saya',
        backgroundColor: Color(0xFF012D5A),
      ),
      backgroundColor: const Color(0xFF001F3F),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profile card
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 18,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00345B),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _pickProfileImage,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircleAvatar(
                              radius: 48,
                              backgroundColor: Colors.orangeAccent.withOpacity(
                                0.12,
                              ),
                              backgroundImage:
                                  (profileImagePath != null &&
                                      profileImagePath!.isNotEmpty)
                                  ? (File(profileImagePath!).existsSync()
                                            ? FileImage(File(profileImagePath!))
                                            : AssetImage(profileImagePath!))
                                        as ImageProvider
                                  : null,
                              child:
                                  (profileImagePath == null ||
                                      profileImagePath!.isEmpty)
                                  ? const Icon(
                                      Icons.person,
                                      color: Colors.orangeAccent,
                                      size: 48,
                                    )
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.orangeAccent,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        username ?? 'User',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        email ?? '-',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white24),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isPremium ? 'Akun Premium' : 'Akun Reguler',
                          style: TextStyle(
                            color: isPremium
                                ? Colors.orangeAccent
                                : Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Edit profile button (top-level action)
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EditProfileScreen(),
                    ),
                  ).then((_) => _load()),
                  icon: const Icon(Icons.edit, color: Colors.white),
                  label: const Text(
                    'Edit Profil',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
                const SizedBox(height: 12),

                // Settings card
                InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SettingsDetailScreen(),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00345B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Pengaturan',
                              style: TextStyle(
                                color: Colors.orangeAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Kelola izin Lokasi & Notifikasi',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                        const Icon(Icons.chevron_right, color: Colors.white54),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Transactions card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00345B),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Riwayat Transaksi',
                        style: TextStyle(
                          color: Colors.orangeAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (transactions.isEmpty)
                        const Text(
                          'Belum ada transaksi.',
                          style: TextStyle(color: Colors.white70),
                        )
                      else
                        Column(
                          children: transactions.reversed.take(3).map((t) {
                            return ListTile(
                              tileColor: const Color(0xFF012D5A),
                              title: Text(
                                t.planName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                _formatShortAmount(t.price, t.priceCurrency),
                                style: const TextStyle(color: Colors.white70),
                              ),
                              trailing: const Icon(
                                Icons.chevron_right,
                                color: Colors.white54,
                              ),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      TransactionDetailScreen(history: t),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Quiz history card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00345B),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Riwayat Kuis',
                        style: TextStyle(
                          color: Colors.orangeAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (quizHistories.isEmpty)
                        const Text(
                          'Belum ada riwayat kuis.',
                          style: TextStyle(color: Colors.white70),
                        )
                      else
                        Column(
                          children: quizHistories.reversed.take(3).map((q) {
                            // q is expected to be a QuizHistory object
                            final DateTime time = (q.time is DateTime)
                                ? q.time
                                : DateTime.parse(q.time.toString());
                            final timeLabel = DateFormat(
                              'd MMM yyyy, HH:mm',
                              'id_ID',
                            ).format(time);
                            final correct = q.correct ?? 0;
                            final total = q.total ?? 0;
                            final percent = (total > 0)
                                ? ((correct / total) * 100).round()
                                : 0;
                            final title = '$correct / $total benar';
                            final subtitle = '$timeLabel • $percent%';
                            return ListTile(
                              tileColor: const Color(0xFF012D5A),
                              title: Text(
                                title,
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                subtitle,
                                style: const TextStyle(color: Colors.white70),
                              ),
                              trailing: const Icon(
                                Icons.chevron_right,
                                color: Colors.white54,
                              ),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const QuizHistoryScreen(),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Informasi (navigates to full screen)
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const InformasiScreen()),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00345B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Informasi',
                                style: TextStyle(
                                  color: Colors.orangeAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Aplikasi: fix_eyd',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Versi: 0.1.0',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.info_outline,
                          color: Colors.orangeAccent,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Logout button
                ElevatedButton.icon(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFF00345B),
                        title: const Text(
                          'Konfirmasi',
                          style: TextStyle(color: Colors.white),
                        ),
                        content: const Text(
                          'Anda yakin ingin keluar?',
                          style: TextStyle(color: Colors.white70),
                        ),
                        actions: [
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Batal'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                            ),
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('Keluar'),
                          ),
                        ],
                      ),
                    );

                    if (confirmed != true) return;
                    final hive = HiveDatabase();
                    await hive.logout();
                    if (!mounted) return;
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                  icon: const Icon(Icons.logout, color: Colors.white),
                  label: const Text(
                    'Keluar',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
