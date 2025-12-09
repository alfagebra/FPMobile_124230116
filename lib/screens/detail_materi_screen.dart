import 'package:flutter/material.dart';
import '../widgets/custom_app_bar.dart';
import '../models/docs_model.dart';
import '../services/progress_service.dart';
import '../database/hive_database.dart';
import 'detail_materi/konten_builders.dart';
import 'detail_materi/konten_sections.dart';

class DetailMateriScreen extends StatefulWidget {
  final Topik topik;
  final int subIndex;
  final Map<String, dynamic> kontenItem;

  const DetailMateriScreen({
    Key? key,
    required this.topik,
    required this.subIndex,
    required this.kontenItem,
  }) : super(key: key);

  @override
  State<DetailMateriScreen> createState() => _DetailMateriScreenState();
}

class _DetailMateriScreenState extends State<DetailMateriScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _saveProgress();
  }

  /// ✅ Simpan progres saat submateri dibuka
  Future<void> _saveProgress() async {
    try {
      final hive = HiveDatabase();
      final email = await hive.getCurrentUserEmail();
      await ProgressService.saveProgress(
        widget.topik.topikId,
        widget.subIndex,
        true,
        userEmail: email,
      );
    } catch (_) {
      await ProgressService.saveProgress(
        widget.topik.topikId,
        widget.subIndex,
        true,
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Persist progress when the app is backgrounded/paused to avoid losing
    // progress if the user quits while viewing content.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _saveProgress();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // ensure last progress is saved
    _saveProgress();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kontenItem = widget.kontenItem;
    final subJudul =
        (kontenItem['sub_judul'] ?? kontenItem['jenis'] ?? kontenItem['nama'])
            ?.toString() ??
        widget.topik.judulTopik;
    final totalSub = widget.topik.konten is List
        ? (widget.topik.konten as List).length
        : 1;

    return Scaffold(
      backgroundColor: const Color(0xFF001F3F),
      appBar: CustomAppBar(
        title: subJudul,
        backgroundColor: const Color(0xFF012D5A),
        centerTitle: true,
      ),
      body: kontenItem.isEmpty
          ? const EmptyState()
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFF012D5A),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.topik.judulTopik,
                              style: const TextStyle(
                                color: Colors.orangeAccent,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              subJudul,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "${widget.subIndex + 1}/$totalSub",
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: KontenBody(
                    topik: widget.topik,
                    subIndex: widget.subIndex,
                    kontenItem: kontenItem,
                  ),
                ),
              ],
            ),
    );
  }
}
