import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/hive_database.dart';
import '../services/in_app_notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await InAppNotificationService.init();
    if (!mounted) return;
    setState(() {
      _loading = false;
    });
    // mark all read when viewing (will update notifier)
    await InAppNotificationService.markAllRead();
    // Debug: print persisted keys and counts so we can diagnose missing items
    try {
      final prefs = await SharedPreferences.getInstance();
      final hive = HiveDatabase();
      final email = await hive.getCurrentUserEmail();
      final userKey = email != null && email.isNotEmpty
          ? 'in_app_notifications_${email.trim().toLowerCase()}'
          : null;
      final guestKey = 'in_app_notifications';
      final rawUser = userKey != null ? prefs.getStringList(userKey) ?? [] : <String>[];
      final rawGuest = prefs.getStringList(guestKey) ?? [];
      debugPrint('NotificationsScreen._load -> userKey=$userKey guestKey=$guestKey rawUser=${rawUser.length} rawGuest=${rawGuest.length}');
    } catch (e) {
      debugPrint('NotificationsScreen._load debug error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001F3F),
      appBar: AppBar(
        title: const Text('Notifikasi', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF012D5A),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'Hapus semua',
            icon: const Icon(Icons.delete_forever, color: Colors.white),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF00345B),
                  title: const Text(
                    'Hapus semua notifikasi?',
                    style: TextStyle(color: Colors.white),
                  ),
                  content: const Text(
                    'Semua notifikasi akan dihapus.',
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orangeAccent,
                      ),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Hapus'),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                await InAppNotificationService.clearAll();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Semua notifikasi dihapus')),
                );
              }
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.orangeAccent),
            )
          : ValueListenableBuilder<List<InAppNotification>>(
              valueListenable: InAppNotificationService.notifications,
              builder: (context, items, _) {
                if (items.isEmpty) {
                  return const Center(
                    child: Text(
                      'Belum ada notifikasi',
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  itemBuilder: (ctx, i) {
                    final it = items[i];
                    return Dismissible(
                      key: ValueKey(it.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        alignment: Alignment.centerRight,
                        decoration: BoxDecoration(
                          color: Colors.red.shade700,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (dir) async {
                        // optional confirmation
                        final res = await showDialog<bool>(
                          context: context,
                          builder: (dctx) => AlertDialog(
                            backgroundColor: const Color(0xFF00345B),
                            title: const Text(
                              'Hapus notifikasi',
                              style: TextStyle(color: Colors.white),
                            ),
                            content: const Text(
                              'Hapus notifikasi ini?',
                              style: TextStyle(color: Colors.white70),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(dctx).pop(false),
                                child: const Text(
                                  'Batal',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orangeAccent,
                                ),
                                onPressed: () => Navigator.of(dctx).pop(true),
                                child: const Text('Hapus'),
                              ),
                            ],
                          ),
                        );
                        return res == true;
                      },
                      onDismissed: (dir) async {
                        await InAppNotificationService.remove(it.id);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Notifikasi dihapus')),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: it.read
                                ? const Color(0xFF012D5A)
                                : const Color(0xFF00345B),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            title: Text(
                              it.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                it.body,
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ),
                            trailing: Text(
                              TimeOfDay.fromDateTime(it.time).format(context),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
