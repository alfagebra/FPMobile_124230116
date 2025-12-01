import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/hive_database.dart';

class ProgressService {
  static const String _keyPrefix = 'progress_';
  static final _db = HiveDatabase(); // ambil email user dari Hive

  /// Build key prefix either from provided email or from Hive
  static Future<String> _buildPrefix({String? userEmail}) async {
    final email = userEmail ?? await _db.getCurrentUserEmail() ?? 'guest';
    return '$_keyPrefix${email.toString().trim().toLowerCase()}-';
  }

  /// Simpan progress dari suatu topik
  /// Optional: provide `userEmail` to avoid timing issues with Hive
  static Future<void> saveProgress(
    String topikId,
    int index,
    bool completed, {
    String? userEmail,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = await _buildPrefix(userEmail: userEmail);
    final key = '$prefix$topikId-$index';
    if (kDebugMode) debugPrint('ProgressService.save -> $key = $completed');
    await prefs.setBool(key, completed);
  }

  /// Ambil status progress dari topik tertentu
  static Future<bool> getProgress(String topikId, int index, {String? userEmail}) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = await _buildPrefix(userEmail: userEmail);
    final key = '$prefix$topikId-$index';
    final val = prefs.getBool(key) ?? false;
    if (kDebugMode) debugPrint('ProgressService.get -> $key = $val');
    return val;
  }

  /// Hapus semua progress dari satu topik
  static Future<void> clearProgress(String topikId, {String? userEmail}) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = await _buildPrefix(userEmail: userEmail);
    final keys = prefs.getKeys().where((k) => k.startsWith('$prefix$topikId'));
    for (final k in keys) {
      if (kDebugMode) debugPrint('ProgressService.remove -> $k');
      await prefs.remove(k);
    }
  }

  /// Ambil total progress keseluruhan
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

    // Sinkronkan dengan Hive (update progress total user)
    final email = userEmail ?? await _db.getCurrentUserEmail();
    if (email != null) {
      await _db.saveUserProgress(email, progress);
    }

    if (kDebugMode) debugPrint('ProgressService.overall -> $prefix progress=$progress');
    return progress;
  }

  /// Ambil progress untuk 1 topik tertentu
  static Future<double> getTopicProgress(String topikId, {String? userEmail}) async {
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
    if (kDebugMode) debugPrint('ProgressService.topic($topikId) -> $prefix value=$val');
    return val;
  }

  /// Hapus semua progress user saat ini (dipanggil saat logout)
  static Future<void> clearAllUserProgress({String? userEmail}) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = await _buildPrefix(userEmail: userEmail);
    final keys = prefs.getKeys().where((k) => k.startsWith(prefix));
    for (final key in keys) {
      if (kDebugMode) debugPrint('ProgressService.clearAll -> $key');
      await prefs.remove(key);
    }
  }
}
