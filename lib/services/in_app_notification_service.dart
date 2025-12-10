import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/hive_database.dart';

class InAppNotification {
  final String id;
  final String title;
  final String body;
  final DateTime time;
  bool read;

  InAppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.time,
    this.read = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'time': time.toIso8601String(),
    'read': read,
  };

  static InAppNotification fromJson(Map<String, dynamic> j) =>
      InAppNotification(
        id: j['id'].toString(),
        title: j['title'] ?? '',
        body: j['body'] ?? '',
        time: DateTime.parse(j['time']),
        read: j['read'] ?? false,
      );
}

class InAppNotificationService {
  static const _kKey = 'in_app_notifications';
  static final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);
  // Expose the current notifications list so UI can listen for updates
  static final ValueNotifier<List<InAppNotification>> notifications =
      ValueNotifier<List<InAppNotification>>([]);

  static Future<List<InAppNotification>> _readAll() async {
    final prefs = await SharedPreferences.getInstance();
    final hive = HiveDatabase();
    final email = await hive.getCurrentUserEmail();
    // Build keys: user-specific key and guest key.
    final userKey = email != null && email.isNotEmpty
        ? '${_kKey}_${email.trim().toLowerCase()}'
        : null;
    final guestKey = _kKey;

    // Read both user and guest lists so notifications created while
    // unauthenticated are still visible after login until migrated.
    final rawUser = userKey != null
        ? prefs.getStringList(userKey) ?? []
        : <String>[];
    final rawGuest = prefs.getStringList(guestKey) ?? [];

    debugPrint(
      'InAppNotificationService._readAll -> userKey=$userKey guestKey=$guestKey rawUser=${rawUser.length} rawGuest=${rawGuest.length}',
    );

    // Merge, with user items first (most recent ordering handled later)
    final merged = <String>[];
    merged.addAll(rawUser);
    // append guest items that are not duplicates by id
    final existingIds = merged
        .map((s) {
          try {
            final j = jsonDecode(s) as Map<String, dynamic>;
            return j['id']?.toString();
          } catch (_) {
            return null;
          }
        })
        .whereType<String>()
        .toSet();
    for (final s in rawGuest) {
      try {
        final j = jsonDecode(s) as Map<String, dynamic>;
        final id = j['id']?.toString();
        if (id == null || existingIds.contains(id)) continue;
      } catch (_) {}
      merged.add(s);
    }

    return merged
        .map(
          (s) =>
              InAppNotification.fromJson(jsonDecode(s) as Map<String, dynamic>),
        )
        .toList();
  }

  static Future<void> _writeAll(List<InAppNotification> items) async {
    final prefs = await SharedPreferences.getInstance();
    final hive = HiveDatabase();
    final email = await hive.getCurrentUserEmail();
    final key = email != null && email.isNotEmpty
        ? '${_kKey}_${email.trim().toLowerCase()}'
        : _kKey;
    final raw = items.map((i) => jsonEncode(i.toJson())).toList();
    debugPrint(
      'InAppNotificationService._writeAll -> key=$key count=${raw.length}',
    );
    await prefs.setStringList(key, raw);
    // newest first for UI convenience
    notifications.value = items.reversed.toList();
    unreadCount.value = items.where((i) => !i.read).length;
  }

  static Future<void> add(String title, String body) async {
    final list = await _readAll();
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    list.add(
      InAppNotification(id: id, title: title, body: body, time: DateTime.now()),
    );
    debugPrint('InAppNotificationService.add -> adding id=$id title=$title');
    await _writeAll(list);
  }

  static Future<List<InAppNotification>> all() async =>
      (await _readAll()).reversed.toList();

  static Future<void> markAllRead() async {
    final list = await _readAll();
    for (var i in list) {
      i.read = true;
    }
    await _writeAll(list);
  }

  static Future<void> markRead(String id) async {
    final list = await _readAll();
    final item = list.firstWhere(
      (e) => e.id == id,
      orElse: () =>
          InAppNotification(id: id, title: '', body: '', time: DateTime.now()),
    );
    item.read = true;
    await _writeAll(list);
  }

  /// Remove a single notification by id.
  static Future<void> remove(String id) async {
    final list = await _readAll();
    list.removeWhere((e) => e.id == id);
    await _writeAll(list);
  }

  /// Clear all notifications for the current user.
  static Future<void> clearAll() async {
    await _writeAll([]);
  }

  static Future<void> init() async {
    // initialize unread count
    final list = await _readAll();
    debugPrint('InAppNotificationService.init -> loaded ${list.length} items');
    // store newest-first for listeners
    notifications.value = list.reversed.toList();
    unreadCount.value = list.where((i) => !i.read).length;
  }

  /// Move notifications stored under the `guest` key into the target
  /// user's key and remove the guest key. Avoids duplicates by id.
  static Future<void> migrateGuestNotifications(String targetEmail) async {
    final prefs = await SharedPreferences.getInstance();
    final guestKey = _kKey;
    final targetKey = '${_kKey}_${targetEmail.trim().toLowerCase()}';

    final rawGuest = prefs.getStringList(guestKey) ?? [];
    debugPrint(
      'InAppNotificationService.migrateGuestNotifications -> guest=${rawGuest.length}',
    );
    if (rawGuest.isEmpty) return;

    final rawTarget = prefs.getStringList(targetKey) ?? [];
    final existingIds = rawTarget
        .map((s) {
          try {
            final j = jsonDecode(s) as Map<String, dynamic>;
            return j['id']?.toString();
          } catch (_) {
            return null;
          }
        })
        .whereType<String>()
        .toSet();

    final merged = <String>[];
    merged.addAll(rawTarget);
    for (final s in rawGuest) {
      try {
        final j = jsonDecode(s) as Map<String, dynamic>;
        final id = j['id']?.toString();
        if (id == null || existingIds.contains(id)) continue;
      } catch (_) {}
      merged.add(s);
    }

    debugPrint(
      'InAppNotificationService.migrateGuestNotifications -> writing target=$targetKey merged=${merged.length}',
    );
    await prefs.setStringList(targetKey, merged);
    await prefs.remove(guestKey);
    // refresh in-memory notifiers
    final list = merged
        .map(
          (s) =>
              InAppNotification.fromJson(jsonDecode(s) as Map<String, dynamic>),
        )
        .toList();
    notifications.value = list.reversed.toList();
    unreadCount.value = list.where((i) => !i.read).length;
  }
}
