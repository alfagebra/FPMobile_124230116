import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/hive_database.dart';

class ProgressService {
  static const String _keyPrefix = 'progress_';
  static final _db = HiveDatabase();

  static Future<String> _buildPrefix({String? userEmail}) async {
    final email = userEmail ?? await _db.getCurrentUserEmail() ?? 'guest';
    return '$_keyPrefix${email.toString().trim().toLowerCase()}-';
  }

  static Future<Map<String, bool>> getAllProgressForUser({
    String? userEmail,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = await _buildPrefix(userEmail: userEmail);
    final keys = prefs.getKeys().where((k) => k.startsWith(prefix));
    final Map<String, bool> out = {};
    for (final k in keys) {
      out[k] = prefs.getBool(k) ?? false;
    }
    if (kDebugMode) {
      debugPrint(
        'ProgressService.debugDump -> prefix=$prefix keys=${out.keys.length}',
      );
    }
    return out;
  }

  static Future<void> saveProgress(
    String topikId,
    int index,
    bool completed, {
    String? userEmail,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = await _buildPrefix(userEmail: userEmail);
    final key = '$prefix$topikId-$index';
    if (kDebugMode) {
      debugPrint(
        'ProgressService.save -> $key = $completed (userEmail=$userEmail)',
      );
    }
    try {
      final ok = await prefs.setBool(key, completed);
      if (!ok && kDebugMode) {
        debugPrint(
          'ProgressService.save -> setBool returned false, retrying: $key',
        );
        final ok2 = await prefs.setBool(key, completed);
        if (!ok2) debugPrint('ProgressService.save -> RETRY FAILED: $key');
      }
    } catch (e) {
      if (kDebugMode)
        debugPrint('ProgressService.save -> exception saving $key: $e');
      rethrow;
    }
  }

  static Future<bool> getProgress(
    String topikId,
    int index, {
    String? userEmail,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = await _buildPrefix(userEmail: userEmail);
    final key = '$prefix$topikId-$index';
    final val = prefs.getBool(key) ?? false;
    if (kDebugMode) {
      debugPrint('ProgressService.get -> $key = $val (userEmail=$userEmail)');
    }
    return val;
  }

  static Future<void> clearProgress(String topikId, {String? userEmail}) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = await _buildPrefix(userEmail: userEmail);
    final keys = prefs.getKeys().where((k) => k.startsWith('$prefix$topikId'));
    for (final k in keys) {
      if (kDebugMode) debugPrint('ProgressService.remove -> $k');
      await prefs.remove(k);
    }
  }

  static Future<double> getOverallProgress({String? userEmail}) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = await _buildPrefix(userEmail: userEmail);
    final keys = prefs.getKeys().where((k) => k.startsWith(prefix)).toList();

    if (keys.isEmpty) return 0.0;

    int completedCount = 0;
    for (final key in keys) {
      final isDone = prefs.getBool(key) ?? false;
      if (isDone) completedCount++;
    }

    final progress = completedCount / keys.length;

    final email = userEmail ?? await _db.getCurrentUserEmail();
    if (email != null) {
      await _db.saveUserProgress(email, progress);
    }

    if (kDebugMode) {
      debugPrint('ProgressService.overall -> $prefix progress=$progress');
    }
    return progress;
  }

  static Future<double> getTopicProgress(
    String topikId, {
    String? userEmail,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = await _buildPrefix(userEmail: userEmail);
    final keys = prefs
        .getKeys()
        .where((k) => k.startsWith('$prefix$topikId'))
        .toList();

    if (keys.isEmpty) return 0.0;

    int completedCount = 0;
    for (final key in keys) {
      final isDone = prefs.getBool(key) ?? false;
      if (isDone) completedCount++;
    }

    final val = completedCount / keys.length;
    if (kDebugMode) {
      debugPrint('ProgressService.topic($topikId) -> $prefix value=$val');
    }
    return val;
  }

  static Future<void> clearAllUserProgress({String? userEmail}) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = await _buildPrefix(userEmail: userEmail);
    final keys = prefs.getKeys().where((k) => k.startsWith(prefix));
    for (final key in keys) {
      if (kDebugMode) debugPrint('ProgressService.clearAll -> $key');
      await prefs.remove(key);
    }
  }

  static Future<void> migrateGuestProgress(String targetEmail) async {
    final prefs = await SharedPreferences.getInstance();
    final guestPrefix = '$_keyPrefix' + 'guest-';
    final targetPrefix = await _buildPrefix(userEmail: targetEmail);

    final keys = prefs
        .getKeys()
        .where((k) => k.startsWith(guestPrefix))
        .toList();
    if (keys.isEmpty) return;

    for (final oldKey in keys) {
      final val = prefs.getBool(oldKey);
      if (val == null) continue;
      final newKey = oldKey.replaceFirst(guestPrefix, targetPrefix);
      if (kDebugMode) {
        debugPrint('ProgressService.migrate: $oldKey -> $newKey ($val)');
      }
      await prefs.setBool(newKey, val);
      await prefs.remove(oldKey);
    }

    final overall = await getOverallProgress(userEmail: targetEmail);
    try {
      final email = targetEmail;
      await _db.saveUserProgress(email, overall);
    } catch (_) {}
  }
}
