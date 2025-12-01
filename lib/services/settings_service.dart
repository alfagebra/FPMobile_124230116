import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/hive_database.dart';

class SettingsService {
  static const _kAllowLocation = 'allow_location';
  static const _kAllowNotifications = 'allow_notifications';

  static final ValueNotifier<bool> allowLocation = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> allowNotifications = ValueNotifier<bool>(
    true,
  );

  static const _kTimeZone = 'time_zone';
  static final ValueNotifier<String> timeZone = ValueNotifier<String>('WIB');
  static const _kUseRemoteMateri = 'use_remote_materi';
  static final ValueNotifier<bool> useRemoteMateri = ValueNotifier<bool>(false);

  /// Initialize settings from SharedPreferences. Call once at app startup
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    allowLocation.value = prefs.getBool(_kAllowLocation) ?? false;
    allowNotifications.value = prefs.getBool(_kAllowNotifications) ?? true;
    // Load global/default timezone from SharedPreferences first
    var tz = prefs.getString(_kTimeZone) ?? 'WIB';

    // If a user is currently logged in, prefer per-user timezone stored in Hive
    try {
      final hive = HiveDatabase();
      final current = await hive.getCurrentUserEmail();
      if (current != null) {
        final userTz = await hive.getUserTimeZone(current);
        if (userTz != null && userTz.isNotEmpty) tz = userTz;
      }
    } catch (_) {
      // ignore and keep global tz
    }

    timeZone.value = tz;
    // remote materi toggle
    try {
      useRemoteMateri.value = prefs.getBool(_kUseRemoteMateri) ?? false;
    } catch (_) {
      useRemoteMateri.value = false;
    }
  }

  static Future<void> setAllowLocation(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAllowLocation, v);
    allowLocation.value = v;
  }

  static Future<void> setAllowNotifications(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAllowNotifications, v);
    allowNotifications.value = v;
  }

  static Future<void> setTimeZone(String zone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTimeZone, zone);
    // Update per-user timezone if logged in, otherwise just global
    try {
      final hive = HiveDatabase();
      final current = await hive.getCurrentUserEmail();
      if (current != null) {
        await hive.setUserTimeZone(current, zone);
      }
    } catch (_) {}

    timeZone.value = zone;
  }

  static Future<void> setUseRemoteMateri(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kUseRemoteMateri, v);
    useRemoteMateri.value = v;
  }
}
