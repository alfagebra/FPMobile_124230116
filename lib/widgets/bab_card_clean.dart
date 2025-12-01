import 'package:flutter/material.dart';
import '../utils/palette.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/docs_model.dart';
import '../screens/detail_materi_screen.dart';
import '../screens/ujian_screen.dart';
import '../services/progress_service.dart';
import '../database/hive_database.dart';

class BabCardClean extends StatefulWidget {
  final Topik topik;
  final int index;
  final bool isPremium;
  final bool isPremiumUnlocked;
  final String? prevTopikId;
  final VoidCallback? onTapLocked;
  final void Function(int score, int total, int topikIndex)? onExamCompleted;

  const BabCardClean({
    Key? key,
    required this.topik,
    required this.index,
    this.isPremium = false,
    this.isPremiumUnlocked = false,
    this.prevTopikId,
    this.onTapLocked,
    this.onExamCompleted,
  }) : super(key: key);

  @override
  State<BabCardClean> createState() => _BabCardCleanState();
}

class _BabCardCleanState extends State<BabCardClean> {
  Future<Map<String, dynamic>?> _getExamResult() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('exam_result${widget.topik.topikId}');
    if (data == null) return null;

    final parts = data.split('/');
    if (parts.length < 3) return null;

    return {
      'score': int.tryParse(parts[0]) ?? 0,
      'total': int.tryParse(parts[1]) ?? 0,
      'time': parts[2],
    };
  }

  Future<bool> _prevExamDone() async {
    if (widget.prevTopikId == null) return true;
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('exam_result${widget.prevTopikId}');
    return data != null;
  }

  int _getTotalSub() {
    if (widget.topik.konten is List)
      return (widget.topik.konten as List).length;
    if (widget.topik.konten is Map) return 1;
    return 0;
  }

  Map<String, dynamic> _getKontenItem(int index) {
    if (widget.topik.konten is List) {
      return (widget.topik.konten as List)[index] as Map<String, dynamic>;
    } else if (widget.topik.konten is Map) {
      return Map<String, dynamic>.from(widget.topik.konten as Map);
    }
    return {};
  }

  bool get _isPremiumLocked => widget.isPremium && !widget.isPremiumUnlocked;

  @override
  Widget build(BuildContext context) {
    final totalSub = _getTotalSub();

    final combinedFuture = HiveDatabase()
        .getCurrentUserEmail()
        .then((email) => Future.wait([
              _prevExamDone(),
              Future.wait(
                List.generate(
                  totalSub,
                  (i) => ProgressService.getProgress(widget.topik.topikId, i, userEmail: email),
                ),
              ),
              _getExamResult(),
            ]));

    return FutureBuilder<List<dynamic>>(
      future: combinedFuture,
      builder: (context, snap) {
        final data = snap.data;
        final prevDone = data != null && data.isNotEmpty
            ? (data[0] as bool)
            : true;
        final doneList = (data != null && data.length > 1 && data[1] is List)
            ? List<bool>.from(data[1])
            : List.filled(totalSub, false);
        final doneCount = doneList.where((e) => e).length;

        final prereqLocked = (widget.prevTopikId != null) && !prevDone;
        final lockedEffective = _isPremiumLocked || prereqLocked;
        final examResult = (data != null && data.length > 2)
            ? data[2] as Map<String, dynamic>?
            : null;

        final bannerBase = (widget.index % 2 == 0)
          ? Palette.primary
          : Palette.primaryDark;
        final bannerColor = lockedEffective ? Colors.grey.shade600 : bannerBase;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: bannerColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.index + 1}. ${widget.topik.judulTopik}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Builder(
                          builder: (_) {
                            String? subtitle;
                            if (widget.topik.konten is List &&
                                (widget.topik.konten as List).isNotEmpty) {
                              final first = (widget.topik.konten as List)[0];
                              if (first is Map) {
                                subtitle =
                                    first['deskripsi'] as String? ??
                                    first['ringkasan'] as String? ??
                                    first['sub_judul'] as String?;
                              }
                            } else if (widget.topik.konten is Map) {
                              final m = widget.topik.konten as Map;
                              subtitle =
                                  m['deskripsi'] as String? ??
                                  m['ringkasan'] as String? ??
                                  m['sub_judul'] as String?;
                            }
                            if (subtitle != null && subtitle.isNotEmpty) {
                              return Text(
                                subtitle,
                                style: const TextStyle(
                                  color: Colors.white70,
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Colors.white24,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            Column(
              children: List.generate(totalSub, (i) {
                final k = _getKontenItem(i);
                // Topic-specific title selection rules.
                // This covers several special cases requested by the user.
                final sj = (() {
                  final titleLowerAll = widget.topik.judulTopik.toLowerCase();
                  // Imbuhan 'ber'/'be': part 1 should literally show 'Aturan'
                  if (titleLowerAll.contains('imbuhan') && i == 0) {
                    return 'Aturan';
                  }

                  // Preposisi 'di' dan 'pada': part 1 -> 'Aturan Utama' or prefer konten 'aturan'
                  if (titleLowerAll.contains('preposisi') && i == 0) {
                    return (k['aturan'] ?? 'Aturan Utama')?.toString();
                  }

                  // Kata Baku / Tidak Baku: first part -> 'Daftar Kata'
                  if ((titleLowerAll.contains('baku') || titleLowerAll.contains('tidak baku')) && i == 0) {
                    return 'Daftar Kata';
                  }

                  // Nama Diri: first item labeled 'Definisi'
                  if (widget.topik.judulTopik.contains('Nama Diri') && i == 0) {
                    return 'Definisi';
                  }

                  // Kata Berpasangan: first item -> 'Definisi'
                  if (widget.topik.judulTopik.toLowerCase().contains('berpasangan') && i == 0) {
                    return 'Definisi';
                  }

                  // Kata Ulang: first item 'Definisi', other items use 'nama'
                  if (widget.topik.judulTopik.toLowerCase().contains('kata ulang')) {
                    if (i == 0) return 'Definisi';
                    return (k['nama'] ?? k['sub_judul'] ?? k['jenis'])?.toString() ?? 'Bagian ${i + 1}';
                  }

                  // Makna Konjungsi Antarkalimat: call 'makna' for parts
                  if (widget.topik.judulTopik.toLowerCase().contains('konjungsi') && widget.topik.judulTopik.toLowerCase().contains('antarkalimat')) {
                    return (k['makna'] ?? k['sub_judul'] ?? k['nama'])?.toString() ?? 'Bagian ${i + 1}';
                  }

                  // Kata dengan makna bertingkat: first item -> 'Definisi'
                  if (widget.topik.judulTopik.toLowerCase().contains('makna bertingkat') && i == 0) {
                    return 'Definisi';
                  }

                  // Kata Bentuk Terikat: first item should be 'Daftar Bentuk Terikat'
                  if (widget.topik.judulTopik.contains('Bentuk Terikat') && i == 0) {
                    return 'Daftar Bentuk Terikat';
                  }

                  // Akronim: first item -> 'Definisi'
                  if (widget.topik.judulTopik.toLowerCase().contains('akronim') && i == 0) {
                    return 'Definisi';
                  }

                  // Kapitalisasi Hari: parts 1 and 2 use 'kasus' field if present
                  if (widget.topik.judulTopik.contains('Kapitalisasi') && (i == 0 || i == 1)) {
                    return (k['kasus'] ?? k['sub_judul'] ?? k['nama'])?.toString() ?? 'Bagian ${i + 1}';
                  }

                  // Penulisan Nama Latin: first part uses 'aturan'
                  if (widget.topik.judulTopik.toLowerCase().contains('nama latin') && i == 0) {
                    return (k['aturan'] ?? k['sub_judul'] ?? k['nama'])?.toString() ?? 'Bagian ${i + 1}';
                  }

                  // Penulisan Simbol: first part labeled 'Penulisan Simbol'
                  if (widget.topik.judulTopik.toLowerCase().contains('simbol') && i == 0) {
                    return 'Penulisan Simbol';
                  }

                  // Tanda Hubung / Tanda Baca / Partikel and Penggunaan Huruf Miring
                  if (widget.topik.judulTopik.contains('Tanda Hubung')) {
                    return (k['judul_penggunaan'] ?? k['sub_judul'] ?? k['jenis'] ?? k['nama'])?.toString() ?? 'Bagian ${i + 1}';
                  }
                  if (widget.topik.judulTopik.contains('Tanda Baca')) {
                    return (k['tanda_baca'] ?? k['sub_judul'] ?? k['jenis'] ?? k['nama'])?.toString() ?? 'Bagian ${i + 1}';
                  }
                  if (widget.topik.judulTopik.contains('Partikel')) {
                    return (k['partikel'] ?? k['sub_judul'] ?? k['jenis'] ?? k['nama'])?.toString() ?? 'Bagian ${i + 1}';
                  }
                  if (widget.topik.judulTopik == 'Penggunaan Huruf Miring') {
                    return (k['judul_penggunaan'] ?? k['sub_judul'] ?? k['jenis'] ?? k['nama'])?.toString() ?? 'Bagian ${i + 1}';
                  }

                  // Default fallback
                  return (k['aturan_id'] ?? k['sub_judul'] ?? k['jenis'] ?? k['nama'])?.toString() ?? 'Bagian ${i + 1}';
                })();

                // Prevent double numbering: if the source title already starts
                // with a number like '1.' or '1.1', strip that prefix so list
                // shows only the outer index (e.g. '1. ...', not '1. 1. ...').
                String _cleanSj(String s) {
                  final regex = RegExp(r'^\s*\d+(?:[\.\d]*)\s*\.\s*');
                  return s.replaceFirst(regex, '').trim();
                }

                final displayTitle = '${i + 1}. ${_cleanSj(sj ?? 'Bagian ${i + 1}') }';
                final progress = (i < doneCount)
                    ? 1.0
                    : (doneCount > 0 ? (doneCount / totalSub) : 0.0);

                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () async {
                    if (prereqLocked) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Selesaikan ujian bab sebelumnya dulu.',
                          ),
                        ),
                      );
                      return;
                    }
                    if (_isPremiumLocked) {
                      widget.onTapLocked?.call();
                      return;
                    }

                    final subItem = _getKontenItem(i);

                    // Persist last-opened topik/sub per-user so each account
                    // resumes independently.
                    try {
                      final hive = HiveDatabase();
                      final current = await hive.getCurrentUserEmail();
                      if (current != null && current.isNotEmpty) {
                        await hive.updateUser(current, {
                          'last_opened_topik': widget.topik.topikId,
                          'last_opened_sub': i,
                        });
                      }
                    } catch (_) {}

                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DetailMateriScreen(
                          topik: widget.topik,
                          subIndex: i,
                          kontenItem: subItem,
                        ),
                      ),
                    );
                    try {
                      final hive = HiveDatabase();
                      final current = await hive.getCurrentUserEmail();
                      await ProgressService.saveProgress(
                        widget.topik.topikId,
                        i,
                        true,
                        userEmail: current,
                      );
                    } catch (_) {
                      await ProgressService.saveProgress(
                        widget.topik.topikId,
                        i,
                        true,
                      );
                    }
                    setState(() {});
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: bannerColor.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: bannerColor.withOpacity(0.9),
                          child: const Icon(Icons.flag, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayTitle,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox.shrink(),
                              const SizedBox(height: 6),
                              LinearProgressIndicator(
                                value: progress,
                                color: Palette.accent,
                                backgroundColor: Colors.white12,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          children: [
                            Text(
                              '${(progress * 100).toInt()}%',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 8),
                            const CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.white12,
                              child: Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),

            const SizedBox.shrink(),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.orange.shade700,
                borderRadius: BorderRadius.circular(10),
              ),
              child: InkWell(
                onTap: () async {
                  if (prereqLocked) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Selesaikan ujian bab sebelumnya dulu.'),
                      ),
                    );
                    return;
                  }
                  if (_isPremiumLocked) {
                    widget.onTapLocked?.call();
                    return;
                  }
                  if (doneCount < totalSub) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Baca semua submateri sebelum mengikuti ujian.',
                        ),
                      ),
                    );
                    return;
                  }

                  final resultData = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UjianScreen(topik: widget.topik),
                    ),
                  );
                  if (resultData != null && resultData['completed'] == true) {
                    // UjianScreen now persists the result and triggers the notification itself.
                    widget.onExamCompleted?.call(
                      resultData['score'] ?? 0,
                      resultData['total'] ?? 0,
                      widget.index,
                    );
                    setState(() {});
                  }
                },
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.orangeAccent,
                      child: const Icon(
                        Icons.emoji_events,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ujian Bab',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Kamu perlu lulus ujian bab untuk lanjut ke bab berikutnya',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.95),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              if (examResult != null)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: Text(
                                    '${examResult['score']}/${examResult['total']}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.white12,
                      child: Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),
          ],
        );
      },
    );
  }
}
