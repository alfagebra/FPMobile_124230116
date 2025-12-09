import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';

class Kuis {
  final String idPertanyaan;
  final String pertanyaan;
  final List<String> pilihan;
  final int jawabanBenarIndex;
  final String pembahasan;

  Kuis({
    required this.idPertanyaan,
    required this.pertanyaan,
    required this.pilihan,
    required this.jawabanBenarIndex,
    required this.pembahasan,
  });

  factory Kuis.fromJson(Map<String, dynamic> json) {
    return Kuis(
      idPertanyaan: json['id_pertanyaan'] ?? '',
      pertanyaan: json['pertanyaan'] ?? 'Pertanyaan tidak ditemukan',
      pilihan: List<String>.from(json['pilihan'] ?? []),
      jawabanBenarIndex: json['jawaban_benar_index'] ?? 0,
      pembahasan: json['pembahasan'] ?? 'Tidak ada pembahasan.',
    );
  }
}

class Topik {
  final String topikId;
  final String judulTopik;
  final dynamic konten;
  final List<Kuis> kuis;

  Topik({
    required this.topikId,
    required this.judulTopik,
    required this.konten,
    required this.kuis,
  });

  factory Topik.fromJson(Map<String, dynamic> json) {
    var kuisListFromJson = json['kuis'] as List? ?? [];
    List<Kuis> kuisList = kuisListFromJson
        .map((k) => Kuis.fromJson(k))
        .toList();

    return Topik(
      topikId: json['topik_id'] ?? '',
      judulTopik: json['judul_topik'] ?? 'Tanpa Judul',
      konten: json['konten'],
      kuis: kuisList,
    );
  }
}

class PBMMateri {
  final String judulMateri;
  final List<Topik> rangkumanTopik;

  PBMMateri({required this.judulMateri, required this.rangkumanTopik});

  factory PBMMateri.fromJson(Map<String, dynamic> json) {
    var list = json['rangkuman_topik'] as List? ?? [];
    List<Topik> topikList = list.map((t) => Topik.fromJson(t)).toList();

    return PBMMateri(
      judulMateri: json['judul_materi'] ?? 'Materi',
      rangkumanTopik: topikList,
    );
  }
}

Future<PBMMateri> loadMateri() async {
  final String response = await rootBundle.loadString('assets/pbm_materi.json');
  final data = await json.decode(response);
  return PBMMateri.fromJson(data);
}
