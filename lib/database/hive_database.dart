import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:bcrypt/bcrypt.dart';
import '../services/progress_service.dart';

class HiveDatabase {
  static const String _boxName = 'userBox';

  Future<Box> _openBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
    return Hive.box(_boxName);
  }

  String _normalize(String value) => value.trim().toLowerCase();

  Future<void> addUser({
    required String username,
    required String email,
    required String password,
  }) async {
    final box = await _openBox();
    final normalizedEmail = _normalize(email);

    if (box.containsKey(normalizedEmail)) {
      throw Exception('Email sudah terdaftar');
    }

    final hashed = BCrypt.hashpw(password.trim(), BCrypt.gensalt());
    final userMap = {
      'username': username.trim(),
      'email': normalizedEmail,
      'password': hashed,
      'isPremium': false,
      'progress': 0.0,
      'createdAt': DateTime.now().toIso8601String(),
    };

    await box.put(normalizedEmail, userMap);
  }

  Future<Map<String, dynamic>?> loginUser(
    String identifier,
    String password,
  ) async {
    final box = await _openBox();
    identifier = _normalize(identifier);

    var data = box.get(identifier);

    if (data == null) {
      for (var key in box.keys) {
        if (key == 'currentUser' || key == 'current_email') continue;

        final userData = box.get(key);
        if (userData is Map) {
          final map = Map<String, dynamic>.from(userData);
          final username = _normalize(map['username'] ?? '');

          if (username == identifier) {
            data = map;
            identifier = map['email'];
            break;
          }
        }
      }
    }

    if (data == null) return null;

    final userMap = Map<String, dynamic>.from(data);
    final storedPassword = userMap['password'].toString();

    bool match;
    try {
      match = BCrypt.checkpw(password.trim(), storedPassword);
    } catch (_) {
      match = storedPassword == password.trim();
    }

    if (!match) return null;

    await box.put('currentUser', identifier);
    await box.put('current_email', identifier);
    await box.put('isLoggedIn', true);

    try {
      await ProgressService.migrateGuestProgress(identifier);
    } catch (_) {}

    return userMap;
  }

  Future<void> logout() async {
    final box = await _openBox();
    final email = box.get('current_email') ?? box.get('currentUser');

    if (email != null) {
      try {
        final existing = box.get(email);
        if (existing is Map) {
          final updated = {...Map<String, dynamic>.from(existing)};
          updated.remove('last_tab');
          await box.put(email, updated);
        }
      } catch (_) {}

      await box.delete('currentUser');
      await box.delete('current_email');
      await box.put('isLoggedIn', false);
    }
  }

  Future<String?> getCurrentUserEmail() async {
    final box = await _openBox();
    return box.get('current_email') ?? box.get('currentUser');
  }

  Future<bool> checkEmailExists(String email) async {
    final box = await _openBox();
    return box.containsKey(_normalize(email));
  }

  Future<String?> getUsername(String email) async {
    final box = await _openBox();
    final data = box.get(_normalize(email));
    if (data == null) return null;
    return Map<String, dynamic>.from(data)['username'];
  }

  Future<void> updateUser(String email, Map<String, dynamic> updates) async {
    final box = await _openBox();
    final key = _normalize(email);
    final existing = box.get(key);
    if (existing == null) return;

    final updated = {...Map<String, dynamic>.from(existing), ...updates};
    await box.put(key, updated);
  }

  Future<void> setPremium(String email, bool status) async {
    await updateUser(email, {'isPremium': status});
  }

  Future<bool> isPremium(String email) async {
    final box = await _openBox();
    final user = box.get(_normalize(email));
    if (user == null) return false;

    final map = Map<String, dynamic>.from(user);
    return map['isPremium'] == true;
  }

  Future<void> saveUserProgress(String email, double progress) async {
    final box = await _openBox();
    final key = _normalize(email);

    final user = box.get(key);
    if (user == null) return;

    final map = Map<String, dynamic>.from(user)..['progress'] = progress;
    await box.put(key, map);
  }

  Future<double> getUserProgress(String email) async {
    final box = await _openBox();
    final user = box.get(_normalize(email));
    if (user == null) return 0.0;

    final map = Map<String, dynamic>.from(user);
    return (map['progress'] ?? 0.0) * 1.0;
  }

  Future<Box> getUserBox() async {
    return await _openBox();
  }

  Future<String?> getUserProfileImage(String email) async {
    final box = await _openBox();
    final user = box.get(_normalize(email));
    if (user == null) return null;

    return Map<String, dynamic>.from(user)['profile_image'];
  }

  Future<String?> getCurrentUserProfileImage() async {
    final email = await getCurrentUserEmail();
    if (email == null) return null;
    return getUserProfileImage(email);
  }

  Future<void> setUserProfileImage(String email, String? path) async {
    await updateUser(email, {'profile_image': path});
  }

  Future<String?> getUserTimeZone(String email) async {
    final box = await _openBox();
    final user = box.get(_normalize(email));
    if (user == null) return null;

    return Map<String, dynamic>.from(user)['time_zone'];
  }

  Future<void> setUserTimeZone(String email, String zone) async {
    await updateUser(email, {'time_zone': zone});
  }

  Future<void> printAllUsers() async {
    final box = await _openBox();

    debugPrint("===== Hive UserBox =====");
    if (box.isEmpty) {
      debugPrint("Box kosong");
      return;
    }

    for (var key in box.keys) {
      final value = box.get(key);
      debugPrint("Key: $key → $value");
    }

    debugPrint("========================");
  }
}
