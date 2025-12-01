import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:bcrypt/bcrypt.dart';
import '../services/progress_service.dart';

class HiveDatabase {
  static const String _boxName = 'userBox';

  /// 🔹 Buka box Hive (otomatis kalau belum dibuka)
  Future<Box> _openBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
    return Hive.box(_boxName);
  }

  /// 🔹 Registrasi user baru
  Future<void> addUser({
    required String username,
    required String email,
    required String password,
  }) async {
    final box = await _openBox();
    final normalizedEmail = email.trim().toLowerCase();

    if (box.containsKey(normalizedEmail)) {
      throw Exception('Email sudah terdaftar');
    }

    // Hash password sebelum disimpan
    final hashedPassword = BCrypt.hashpw(password.trim(), BCrypt.gensalt());

    final userMap = {
      'username': username.trim(),
      'email': normalizedEmail,
      'password': hashedPassword,
      'isPremium': false,
      'progress': 0.0,
      'createdAt': DateTime.now().toIso8601String(),
    };

    await box.put(normalizedEmail, userMap);
  }

  /// 🔹 Login user (bisa pakai email atau username)
  Future<Map<String, dynamic>?> loginUser(
    String identifier,
    String password,
  ) async {
    final box = await _openBox();
    identifier = identifier.trim().toLowerCase();

    // Coba login pakai email
    var data = box.get(identifier);

    // Kalau gak ketemu, cari berdasarkan username
    if (data == null) {
      for (var key in box.keys) {
        if (key == 'currentUser') continue;
        final userData = box.get(key);
        if (userData is Map) {
          final userMap = Map<String, dynamic>.from(userData);
          final username = (userMap['username'] ?? '').toString().toLowerCase();
          if (username == identifier) {
            data = userMap;
            identifier = userMap['email'].toString().toLowerCase();
            break;
          }
        }
      }
    }

    if (data == null) return null;

    final userMap = Map<String, dynamic>.from(data);
    final storedPassword = (userMap['password'] ?? '').toString().trim();

    if (storedPassword == password.trim()) {
      await box.put('currentUser', identifier);
      await box.put('current_email', identifier);
      return userMap;
    } else {
      return null;
    }
  }

  /// 🔹 Logout (hapus progress + current user)
  Future<void> logout() async {
    final box = await _openBox();
    final email = box.get('currentUser');

    if (email != null) {
      // Hapus semua progress user sebelum hapus currentUser
      await ProgressService.clearAllUserProgress();
      // Hapus key login yang mungkin dipakai oleh kode lain
      await box.delete('currentUser');
      await box.delete('current_email');
    }
  }

  /// 🔹 Ambil email user yang sedang login
  Future<String?> getCurrentUserEmail() async {
    final box = await _openBox();
    // Dukung kedua key untuk kompatibilitas dengan kode lama
    return box.get('current_email') ?? box.get('currentUser');
  }

  /// 🔹 Cek apakah email sudah ada
  Future<bool> checkEmailExists(String email) async {
    final box = await _openBox();
    return box.containsKey(email.trim().toLowerCase());
  }

  /// 🔹 Ambil username berdasarkan email
  Future<String?> getUsername(String email) async {
    final box = await _openBox();
    final data = box.get(email.trim().toLowerCase());
    if (data == null) return null;
    return Map<String, dynamic>.from(data)['username']?.toString();
  }

  /// 🔹 Update data user
  Future<void> updateUser(String email, Map<String, dynamic> updates) async {
    final box = await _openBox();
    final existing = box.get(email.trim().toLowerCase());
    if (existing == null) return;

    final updated = {...Map<String, dynamic>.from(existing), ...updates};
    await box.put(email.trim().toLowerCase(), updated);
  }

  /// 🔹 Set status premium user
  Future<void> setPremium(String email, bool status) async {
    debugPrint('🔁 HiveDatabase.setPremium -> $email = $status');
    await updateUser(email, {'isPremium': status});
    debugPrint('✅ HiveDatabase.setPremium completed -> $email = $status');
  }

  /// 🔹 Cek apakah user premium
  Future<bool> isPremium(String email) async {
    final box = await _openBox();
    final user = box.get(email.trim().toLowerCase());
    if (user == null) return false;
    final userMap = Map<String, dynamic>.from(data);
    final storedPassword = (userMap['password'] ?? '').toString();
    final plainPassword = password.trim();

    // Deteksi apakah storedPassword sudah berupa bcrypt hash
    final isBcryptHash = RegExp(r'^\$2[aby]\$').hasMatch(storedPassword);

    if (isBcryptHash) {
      // Verifikasi hash
      final ok = BCrypt.checkpw(plainPassword, storedPassword);
      if (!ok) return null;
    } else {
      // Jika masih plaintext di DB (migrasi), bandingkan langsung dan re-hash
      if (storedPassword.trim() != plainPassword) return null;

      // Re-hash dan simpan agar ke depan aman
      try {
        final newHash = BCrypt.hashpw(plainPassword, BCrypt.gensalt());
        final updated = {...userMap, 'password': newHash};
        await box.put(identifier, updated);
      } catch (e) {
        // Jika gagal re-hash, jangan block login; hanya log
        debugPrint('⚠️ Gagal re-hash password saat login: $e');
      }
    }

    // Simpan kedua key untuk kompatibilitas: sebagian kode memakai
    // 'currentUser' dan sebagian lain 'current_email'
    await box.put('currentUser', identifier);
    await box.put('current_email', identifier);
    return userMap;
    await box.put(email.trim().toLowerCase(), userMap);
  }

  /// 🔹 Ambil progress user
  Future<double> getUserProgress(String email) async {
    final box = await _openBox();
    final user = box.get(email.trim().toLowerCase());
    if (user == null) return 0.0;
    final userMap = Map<String, dynamic>.from(user);
    return (userMap['progress'] ?? 0.0) as double;
  }

  /// 🔹 Dapatkan Box (kalau mau akses langsung)
  Future<Box> getUserBox() async {
    return await _openBox();
  }

  /// 🔹 Ambil path gambar profil untuk user
  Future<String?> getUserProfileImage(String email) async {
    final box = await _openBox();
    final user = box.get(email.trim().toLowerCase());
    if (user == null) return null;
    final userMap = Map<String, dynamic>.from(user);
    return userMap['profile_image']?.toString();
  }

  /// 🔹 Ambil profile image path untuk user yang sedang login (convenience)
  Future<String?> getCurrentUserProfileImage() async {
    final email = await getCurrentUserEmail();
    if (email == null) return null;
    return await getUserProfileImage(email);
  }

  /// 🔹 Set gambar profil untuk user
  Future<void> setUserProfileImage(String email, String? path) async {
    final box = await _openBox();
    final existing = box.get(email.trim().toLowerCase());
    if (existing == null) return;
    final updated = {...Map<String, dynamic>.from(existing)};
    updated['profile_image'] = path;
    await box.put(email.trim().toLowerCase(), updated);
  }

  /// 🔹 Ambil timezone yang disimpan pada record user
  Future<String?> getUserTimeZone(String email) async {
    final box = await _openBox();
    final user = box.get(email.trim().toLowerCase());
    if (user == null) return null;
    final userMap = Map<String, dynamic>.from(user);
    return userMap['time_zone']?.toString();
  }

  /// 🔹 Simpan timezone ke record user
  Future<void> setUserTimeZone(String email, String zone) async {
    final box = await _openBox();
    final existing = box.get(email.trim().toLowerCase());
    if (existing == null) return;
    final updated = {...Map<String, dynamic>.from(existing)};
    updated['time_zone'] = zone;
    await box.put(email.trim().toLowerCase(), updated);
  }

  /// 🔹 Debug: print semua isi userBox
  Future<void> printAllUsers() async {
    final box = await _openBox();
    debugPrint("===== [Hive UserBox Contents] =====");

    if (box.isEmpty) {
      debugPrint("⚠️ Box kosong, tidak ada data user.");
      return;
    }

    for (var key in box.keys) {
      final value = box.get(key);
      debugPrint("🔑 Key: $key");
      if (value is Map) {
        value.forEach((k, v) {
          debugPrint("   $k: $v");
        });
      } else {
        debugPrint("   Value: $value");
      }
    }

    debugPrint("===================================");
  }
}
