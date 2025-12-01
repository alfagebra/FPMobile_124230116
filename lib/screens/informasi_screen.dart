import 'package:flutter/material.dart';
import '../utils/palette.dart';

class InformasiScreen extends StatelessWidget {
  const InformasiScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Define authors for this project (display both)
    final authors = [
      {
        'name': 'Lusiana Dwi Wahyuni',
        'nim': '124230019',
        'contact': 'lusiwhynn@gmail.com',
      },
      {
        'name': 'Eva Luthfia Ramadhani',
        'nim': '124230116',
        'contact': 'evaluthfia23101187@gmail.com',
      }
    ];

    const courseTitle = 'Praktikum Pemrograman Aplikasi Mobile';
    const kesanPesanBegut = 'Terima kasih kepada kakak asisten laboratorium dan teman-teman. Semoga aplikasi ini bermanfaat.';


    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(color: Colors.white),
        title: const Text('Informasi Pembuat', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: const Color(0xFF012D5A),
      ),
      // Use the same dark background used by profile/premium screens
      backgroundColor: Palette.premiumBackground,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
              child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFF00345B), borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Prominent header listing both authors' names
                  Center(
                    child: Column(
                      children: [
                        Text(
                          '${authors[0]['name']} & ${authors[1]['name']}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Pembuat Aplikasi',
                          style: TextStyle(color: Palette.accent.withOpacity(0.9)),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                  // Render each author as a small card
                  ...authors.map((a) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: Palette.accent.withOpacity(0.18),
                                child: const Icon(Icons.person, color: Colors.white),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(a['name'] as String, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text('NIM: ${a['nim']}', style: const TextStyle(color: Colors.white70)),
                                    const SizedBox(height: 2),
                                    Text(a['contact'] as String, style: const TextStyle(color: Colors.white70)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )).toList(),

                  const SizedBox(height: 8),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 12),

                  Text('Kesan & Pesan Mata Kuliah', style: TextStyle(color: Palette.accent, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Mata Kuliah: $courseTitle', style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 6),
                  Text(kesanPesanBegut, style: const TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
