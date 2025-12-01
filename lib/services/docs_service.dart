import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/docs_model.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'settings_service.dart';

class DocsService {
  static PBMMateri? _cachedMateri;

  /// Load PBM materi from bundled JSON. Uses an in-memory cache to avoid
  /// re-parsing the asset repeatedly which can cause UI jank when called
  /// multiple times during navigation or state changes.
  /// Load PBM materi. If [useRemote] is true, attempt to fetch from the
  /// running Node dev server at [baseUrl] (defaults to emulator-local).
  /// On any failure it falls back to the bundled asset JSON.
  static Future<PBMMateri> loadPBMMateri({
    bool forceReload = false,
    bool? useRemote,
    String? baseUrl,
  }) async {
    if (!forceReload && _cachedMateri != null) {
      debugPrint(
        '♻️ Returning cached PBMMateri (${_cachedMateri!.rangkumanTopik.length} topics)',
      );
      return _cachedMateri!;
    }
    // Determine whether to use remote: explicit param > SettingsService > default false
    final finalUseRemote = useRemote ?? SettingsService.useRemoteMateri.value;

    // If requested, try remote fetch first
    if (finalUseRemote) {
      try {
        final api = ApiService(baseUrl: baseUrl);
        final remote = await api.getMateri();
        if (remote is Map<String, dynamic>) {
          debugPrint('🌐 Loaded materi from remote API');
          final materi = PBMMateri.fromJson(remote);
          _cachedMateri = materi;
          return materi;
        }
      } catch (e, stack) {
        debugPrint('⚠️ Failed to load remote materi: $e');
        debugPrint(stack.toString());
        // fallthrough to bundled asset
      }
    }

    try {
      // Pastikan file ada dan bisa dimuat
      final jsonString = await rootBundle.loadString(
        'assets/data/pbm_materi.json',
      );

      // Decode JSON
      final dynamic parsed = jsonDecode(jsonString);
      final Map<String, dynamic> jsonData = Map<String, dynamic>.from(parsed);


      debugPrint("✅ JSON berhasil dimuat: ${jsonData['judul_materi']}");
      if (jsonData['rangkuman_topik'] is List) {
        final topikList = jsonData['rangkuman_topik'] as List;
        debugPrint("📚 Jumlah topik: ${topikList.length}");
        if (topikList.isNotEmpty) {
          debugPrint(
            "🧩 Contoh topik pertama: ${topikList.first['judul_topik']}",
          );
        }
      } else {
        debugPrint("⚠️ 'rangkuman_topik' bukan List di JSON!");
      }


      final materi = PBMMateri.fromJson(jsonData);
      debugPrint("✅ Model PBMMateri berhasil dibuat: ${materi.judulMateri}");
      _cachedMateri = materi;
      return materi;
    } catch (e, stack) {
      debugPrint("❌ Gagal memuat JSON: $e");
      debugPrint(stack.toString());
      throw Exception("Gagal memuat JSON: $e");
    }
  }

  static void clearCache() {
    _cachedMateri = null;
  }
}
