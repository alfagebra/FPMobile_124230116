import 'package:flutter/material.dart';
import '../widgets/custom_app_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/docs_model.dart';
import '../services/notification_service.dart';
import '../services/api_service.dart';
import '../services/settings_service.dart';

class UjianScreen extends StatefulWidget {
  final Topik topik;
  const UjianScreen({Key? key, required this.topik}) : super(key: key);

  @override
  State<UjianScreen> createState() => _UjianScreenState();
}

class _UjianScreenState extends State<UjianScreen> {
  int _currentQuestionIndex = 0;
  int _score = 0;
  int? _selectedIndex;
  bool _isAnswered = false;
  Topik? _currentTopik;

  @override
  void initState() {
    super.initState();
    _currentTopik = widget.topik;
    // If remote materi is enabled, attempt to load latest topic from API
    if (SettingsService.useRemoteMateri.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadRemoteTopik());
    }
  }

  @override
  Widget build(BuildContext context) {
    final topik = _currentTopik ?? widget.topik;
    final kuisList = topik.kuis;
    final total = kuisList.length;

    return Scaffold(
      backgroundColor: const Color(0xFF001F3F),
      appBar: CustomAppBar(
        title: widget.topik.judulTopik,
        backgroundColor: const Color(0xFF012D5A),
      ),
      body: total == 0
          ? const Center(
              child: Text(
                "Belum ada ujian untuk bab ini.",
                style: TextStyle(color: Colors.white70),
              ),
            )
          : _buildQuestionPage(kuisList[_currentQuestionIndex], total),
    );
  }

  Future<void> _loadRemoteTopik() async {
    try {
      final api = ApiService();
      final data = await api.getTopicById(widget.topik.topikId);
      if (data is Map<String, dynamic>) {
        final remoteTopik = Topik.fromJson(data);
        if (!mounted) return;
        setState(() {
          _currentTopik = remoteTopik;
        });
      }
    } catch (e) {
      debugPrint('⚠️ UjianScreen: gagal memuat topic remote: $e');
      // keep local topic as fallback
    }
  }

  // UjianScreen no longer asks for question count; it uses the topic's kuis list.

  Widget _buildQuestionPage(Kuis kuis, int total) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Soal ${_currentQuestionIndex + 1} dari $total",
            style: const TextStyle(color: Colors.orangeAccent, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Text(
            kuis.pertanyaan,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          ...List.generate(kuis.pilihan.length, (index) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: _isAnswered
                    ? null
                    : () {
                        setState(() {
                          _selectedIndex = index;
                          _isAnswered = true;
                          if (index == kuis.jawabanBenarIndex) _score++;
                        });
                      },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _getOptionColor(index, kuis),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    kuis.pilihan[index],
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 20),
          if (_isAnswered) _buildPembahasanCard(kuis),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.bottomRight,
            child: ElevatedButton(
              onPressed: _isAnswered ? _nextQuestion : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isAnswered
                    ? Colors.orangeAccent
                    : Colors.grey,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _currentQuestionIndex == total - 1 ? "Selesai" : "Lanjut",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPembahasanCard(Kuis kuis) {
    final benar = _selectedIndex == kuis.jawabanBenarIndex;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF00344E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            benar
                ? "✅ Jawaban kamu benar!"
                : "❌ Salah, jawabannya: ${kuis.pilihan[kuis.jawabanBenarIndex]}",
            style: TextStyle(
              color: benar ? Colors.greenAccent : Colors.redAccent,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Pembahasan:",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            kuis.pembahasan,
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
        ],
      ),
    );
  }

  Color _getOptionColor(int index, Kuis kuis) {
    if (!_isAnswered) return const Color(0xFF012D5A);
    if (index == kuis.jawabanBenarIndex) {
      return Colors.green.withOpacity(0.4);
    } else if (index == _selectedIndex) {
      return Colors.red.withOpacity(0.4);
    }
    return const Color(0xFF012D5A);
  }

  void _nextQuestion() {
    final total = widget.topik.kuis.length;
    if (_currentQuestionIndex < total - 1) {
      setState(() {
        _currentQuestionIndex++;
        _isAnswered = false;
        _selectedIndex = null;
      });
    } else {
      _showResultDialog(total);
    }
  }

  void _showResultDialog(int total) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: const Color(0xFF00344E),
        title: const Text(
          "Ujian Selesai",
          style: TextStyle(color: Colors.orangeAccent),
        ),
        content: Text(
          "Skor kamu: $_score / $total",
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // tutup dialog

              // Persist exam result to SharedPreferences so it's available
              // regardless of the caller (e.g., started from NextButton or BabCard).
              try {
                final prefs = await SharedPreferences.getInstance();
                final now = DateTime.now().toIso8601String();
                await prefs.setString(
                  'exam_result${widget.topik.topikId}',
                  '$_score/$total/$now',
                );
                // history for quizzes is recorded by the KuisScreen flow
              } catch (e) {
                // ignore persistence errors but keep flow
                debugPrint('⚠️ Failed to persist exam result: $e');
              }

              // Send a local notification to notify the user that the exam finished.
              try {
                await NotificationService.show(
                  'Ujian Selesai!',
                  'Kamu telah menyelesaikan ${widget.topik.judulTopik} ($_score/$total) 🎉',
                  payload: 'exam_result',
                );
              } catch (e) {
                debugPrint('⚠️ Failed to show notification: $e');
              }

              // Return to caller with result
              Navigator.pop(context, {
                'completed': true,
                'score': _score,
                'total': total,
              }); // balik ke HomeScreen
            },
            child: const Text(
              "Selesai",
              style: TextStyle(color: Colors.orangeAccent),
            ),
          ),
        ],
      ),
    );
  }
}
