import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../services/location_service.dart';
import '../widgets/custom_app_bar.dart';

class SettingsDetailScreen extends StatefulWidget {
  const SettingsDetailScreen({Key? key}) : super(key: key);

  @override
  State<SettingsDetailScreen> createState() => _SettingsDetailScreenState();
}

class _SettingsDetailScreenState extends State<SettingsDetailScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001F3F),
      appBar: const CustomAppBar(
        title: 'Pengaturan',
        backgroundColor: Color(0xFF012D5A),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF00345B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Perizinan',
                    style: TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Location toggle
                  ValueListenableBuilder<bool>(
                    valueListenable: SettingsService.allowLocation,
                    builder: (context, allowed, _) => SwitchListTile(
                      title: const Text('Izinkan Lokasi', style: TextStyle(color: Colors.white)),
                      subtitle: Text(
                        allowed
                            ? 'Aplikasi dapat menampilkan peta dan lokasi Anda.'
                            : 'Lokasi dimatikan — beberapa fitur akan terbatas.',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      value: allowed,
                      activeColor: Colors.orangeAccent,
                      onChanged: (v) async {
                        if (v) {
                          final consent = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: const Color(0xFF00345B),
                              title: const Text('Izinkan Lokasi', style: TextStyle(color: Colors.white)),
                              content: const Text(
                                'Aplikasi akan menggunakan lokasi perangkat untuk menampilkan peta dan menandai tempat terdekat. Data lokasi tidak dibagikan ke pihak ketiga.',
                                style: TextStyle(color: Colors.white70),
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Batal')),
                                ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent), child: const Text('Setuju')),
                              ],
                            ),
                          );
                          if (consent != true) return;

                          final granted = await LocationService.requestPermission();
                          if (!granted) {
                            await showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: const Color(0xFF00345B),
                                title: const Text('Izin ditolak', style: TextStyle(color: Colors.white)),
                                content: const Text('Izin lokasi ditolak. Untuk mengaktifkan lokasi, buka pengaturan aplikasi dan berikan izin Lokasi.', style: TextStyle(color: Colors.white70)),
                                actions: [
                                  TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Tutup')),
                                ],
                              ),
                            );
                          }
                        }
                        await SettingsService.setAllowLocation(v);
                        setState(() {});
                      },
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Notification toggle
                  ValueListenableBuilder<bool>(
                    valueListenable: SettingsService.allowNotifications,
                    builder: (context, allowed, _) => SwitchListTile(
                      title: const Text('Izinkan Notifikasi', style: TextStyle(color: Colors.white)),
                      subtitle: Text(
                        allowed ? 'Notifikasi ujian dan pembelajaran akan muncul.' : 'Notifikasi dimatikan.',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      value: allowed,
                      activeColor: Colors.orangeAccent,
                      onChanged: (v) async {
                        await SettingsService.setAllowNotifications(v);
                        setState(() {});
                      },
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Remote materi toggle
                  ValueListenableBuilder<bool>(
                    valueListenable: SettingsService.useRemoteMateri,
                    builder: (context, enabled, _) => SwitchListTile(
                      title: const Text('Gunakan API Remote Materi', style: TextStyle(color: Colors.white)),
                      subtitle: Text(
                        enabled
                            ? 'Ambil materi dari server pengembangan (Node API).'
                            : 'Gunakan materi bawaan aplikasi (assets).',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      value: enabled,
                      activeColor: Colors.orangeAccent,
                      onChanged: (v) async {
                        await SettingsService.setUseRemoteMateri(v);
                        setState(() {});
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              'Catatan Privasi',
              style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Lokasi hanya digunakan untuk menampilkan peta dan fitur pencarian dekat. Data lokasi tidak dikirim ke pihak ketiga tanpa izin Anda.',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
