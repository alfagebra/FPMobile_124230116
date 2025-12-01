import 'package:flutter/material.dart';
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
                    return Padding(
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
                    );
                  },
                );
              },
            ),
    );
  }
}