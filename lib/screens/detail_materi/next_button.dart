import 'package:flutter/material.dart';
import '../../models/docs_model.dart';
import '../ujian_screen.dart';
import '../detail_materi_screen.dart';
import '../../services/docs_service.dart';
import '../../services/progress_service.dart';
import '../../database/hive_database.dart';
import '../../services/notification_service.dart';
import '../payment_offer_screen.dart';

class NextButton extends StatefulWidget {
  final Topik topik;
  final int subIndex;

  const NextButton({super.key, required this.topik, required this.subIndex});

  @override
  State<NextButton> createState() => _NextButtonState();
}

class _NextButtonState extends State<NextButton> {
  @override
  Widget build(BuildContext context) {
    final bool isLastSub = widget.subIndex == widget.topik.konten.length - 1;

    return Center(
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orangeAccent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        icon: Icon(
          isLastSub ? Icons.school : Icons.arrow_forward,
          color: Colors.white,
        ),
        label: Text(
          isLastSub
              ? "Lanjut ke Ujian Bab Ini"
              : "Lanjut ke Materi Selanjutnya",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        onPressed: () async {
          if (isLastSub) {
            // Push the exam and wait for result so we can react (open next topik)
            final result = await Navigator.push<Map<String, dynamic>>(
              context,
              MaterialPageRoute(
                builder: (_) => UjianScreen(topik: widget.topik),
              ),
            );
            if (!mounted) return;
            if (result != null && result['completed'] == true) {
              // try to load materi list and open next topik's first sub
              try {
                final materi = await DocsService.loadPBMMateri();
                final idx = materi.rangkumanTopik.indexWhere(
                  (t) => t.topikId == widget.topik.topikId,
                );
                final nextIdx = idx + 1;
                if (nextIdx >= 0 && nextIdx < materi.rangkumanTopik.length) {
                  final nextTopik = materi.rangkumanTopik[nextIdx];
                  // Check premium gating: topics with index >= 2 are premium
                  bool allowed = true;
                  try {
                    final hive = HiveDatabase();
                    final email = await hive.getCurrentUserEmail();
                    final userPremium = email != null
                        ? await hive.isPremium(email)
                        : false;
                    final needsPremium = nextIdx >= 2;
                    if (needsPremium && !userPremium) {
                      allowed = false;
                      // show purchase prompt
                      await showModalBottomSheet(
                        context: context,
                        backgroundColor: const Color(0xFF012D5A),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                        ),
                        builder: (ctx) => Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 8),
                              const Icon(
                                Icons.lock_outline,
                                color: Colors.orangeAccent,
                                size: 48,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Materi Premium',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Untuk membuka "${nextTopik.judulTopik}" kamu perlu membuka Premium.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white70),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orangeAccent,
                                  minimumSize: const Size(double.infinity, 48),
                                ),
                                icon: const Icon(
                                  Icons.workspace_premium_outlined,
                                ),
                                label: const Text('Buka / Beli Premium'),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  // use original context to navigate to payment screen
                                  if (mounted)
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const PaymentOfferScreen(),
                                      ),
                                    );
                                },
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text(
                                  'Nanti saja',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                      try {
                        await NotificationService.show(
                          'Akses Premium Diperlukan',
                          'Untuk membuka "${nextTopik.judulTopik}" kamu perlu membuka Premium.',
                        );
                      } catch (_) {}
                    }
                  } catch (_) {}
                  if (!allowed) return;
                  Map<String, dynamic> firstContent = {};
                  if (nextTopik.konten is List &&
                      (nextTopik.konten as List).isNotEmpty) {
                    firstContent =
                        (nextTopik.konten as List)[0] as Map<String, dynamic>;
                  } else if (nextTopik.konten is Map) {
                    firstContent = Map<String, dynamic>.from(
                      nextTopik.konten as Map,
                    );
                  }

                  // Navigate to the next topik's first submateri
                  if (!mounted) return;
                  await Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DetailMateriScreen(
                        topik: nextTopik,
                        subIndex: 0,
                        kontenItem: firstContent,
                      ),
                    ),
                  );

                  // mark progress
                  try {
                    final hive = HiveDatabase();
                    final email = await hive.getCurrentUserEmail();
                    await ProgressService.saveProgress(
                      nextTopik.topikId,
                      0,
                      true,
                      userEmail: email,
                    );
                  } catch (_) {}
                } else {
                  // if no next topik, just pop back to previous
                }
              } catch (e) {
                debugPrint(
                  '⚠️ NextButton: gagal membuka materi berikutnya: $e',
                );
              }
            }
          } else {
            final nextSubIndex = widget.subIndex + 1;
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => DetailMateriScreen(
                  topik: widget.topik,
                  subIndex: nextSubIndex,
                  kontenItem: widget.topik.konten[nextSubIndex],
                ),
              ),
            );
          }
        },
      ),
    );
  }
}
