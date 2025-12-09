import 'package:flutter/material.dart';
import '../utils/palette.dart';

class InformasiScreen extends StatelessWidget {
  const InformasiScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Single author: Eva
    final author = {
      'name': 'Eva Luthfia Ramadhani',
      'nim': '124230116',
      'contact': 'evaluthfia23101187@gmail.com',
    };

    const courseTitle = 'Pemrograman Aplikasi Mobile';
    const kesanPesanBegut = '''Kesan:
Menurutku pemrograman aplikasi mobile itu gak susah tapi juga gak gampang. Konsep dasarnya mirip kayak web, cuma bahasanya beda. Aku tipe yang harus dijelasin dulu baru bisa paham, jadi beberapa materi—apalagi soal struktur dan alur aplikasi—cukup bikin mikir. Tapi makin sering dicoba dan latihan, pelan-pelan mulai kebayang alurnya.

Pesan:
Buat pengumpulan tugas akhir, sebaiknya kalau bisa dikasih info lewat grup WhatsApp atau media lain juga. Soalnya kemarin, kalau gak sering buka SPADA, kita gak bakal tahu ada tugas, dan akhirnya baru tau dari teman-teman. Jadi pemberitahuan tambahan bakal sangat membantu biar semua mahasiswa bisa lebih siap dan nggak ketinggalan.''';

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(color: Colors.white),
        title: const Text(
          'Informasi Pembuat',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF012D5A),
      ),
      backgroundColor: Palette.premiumBackground,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF00345B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Centered avatar + name + NIM + email
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Palette.accent.withOpacity(0.35),
                        width: 3,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/eva.JPG',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Palette.accent.withOpacity(0.12),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.person,
                              color: Colors.white70,
                              size: 64,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    author['name'] as String,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'NIM: ${author['nim']}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    author['contact'] as String,
                    style: const TextStyle(color: Colors.white70),
                  ),

                  const SizedBox(height: 20),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 12),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Kesan & Pesan Mata Kuliah',
                      style: TextStyle(
                        color: Palette.accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Mata Kuliah: $courseTitle',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    kesanPesanBegut,
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
