import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

class NearbyService {
  static final List<Map<String, dynamic>> _pois = [
    {'name': 'Kampus Utama', 'lat': -6.200000, 'lng': 106.816666},
    {'name': 'Perpustakaan Pusat', 'lat': -6.201200, 'lng': 106.815000},
    {'name': 'Kantin Teknik', 'lat': -6.198500, 'lng': 106.818000},
  ];

  static Future<List<Map<String, dynamic>>> _loadPoisFromAssets() async {
    try {
      final raw = await rootBundle.loadString('assets/data/pois.json');
      final List<dynamic> arr = json.decode(raw);
      return arr
          .whereType<Map<String, dynamic>>()
          .where((m) => m.containsKey('lat') && m.containsKey('lng'))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static final Map<String, Map<String, dynamic>> _overpassCache = {};

  static Future<List<Map<String, dynamic>>> _queryOverpass(
    double lat,
    double lng,
    double radiusMeters,
  ) async {
    final key =
        '${lat.toStringAsFixed(5)}_${lng.toStringAsFixed(5)}_${radiusMeters.toInt()}';
    final now = DateTime.now();

    if (_overpassCache.containsKey(key)) {
      final entry = _overpassCache[key]!;
      final ts = entry['ts'] as DateTime;
      if (now.difference(ts).inMinutes < 5) {
        return List<Map<String, dynamic>>.from(entry['data'] as List);
      }
    }

    final q =
        '''
[out:json][timeout:25];
(
  node(around:${radiusMeters.toInt()},$lat,$lng)[amenity=university];
  node(around:${radiusMeters.toInt()},$lat,$lng)[amenity=college];
  node(around:${radiusMeters.toInt()},$lat,$lng)[amenity=school];
  node(around:${radiusMeters.toInt()},$lat,$lng)[amenity=library];
  node(around:${radiusMeters.toInt()},$lat,$lng)[amenity=place_of_worship];
  node(around:${radiusMeters.toInt()},$lat,$lng)[tourism=museum];
  node(around:${radiusMeters.toInt()},$lat,$lng)[leisure=park];
  way(around:${radiusMeters.toInt()},$lat,$lng)[amenity=university];
  way(around:${radiusMeters.toInt()},$lat,$lng)[amenity=college];
  way(around:${radiusMeters.toInt()},$lat,$lng)[amenity=school];
  way(around:${radiusMeters.toInt()},$lat,$lng)[amenity=library];
  way(around:${radiusMeters.toInt()},$lat,$lng)[amenity=place_of_worship];
  way(around:${radiusMeters.toInt()},$lat,$lng)[tourism=museum];
);
out center;
''';

    try {
      final uri = Uri.parse('https://overpass-api.de/api/interpreter');
      final res = await http.post(uri, body: {'data': q});
      if (res.statusCode != 200) return [];

      final Map<String, dynamic> jsonRes = json.decode(res.body);
      final List elems = jsonRes['elements'] ?? [];
      final List<Map<String, dynamic>> pois = [];

      for (final e in elems) {
        double? plat;
        double? plng;

        if (e['type'] == 'node') {
          plat = (e['lat'] as num?)?.toDouble();
          plng = (e['lon'] as num?)?.toDouble();
        } else if (e['type'] == 'way' || e['type'] == 'relation') {
          if (e['center'] != null) {
            plat = (e['center']['lat'] as num?)?.toDouble();
            plng = (e['center']['lon'] as num?)?.toDouble();
          }
        }

        final name = (e['tags'] != null && e['tags']['name'] != null)
            ? e['tags']['name']
            : (e['tags'] != null && e['tags']['ref'] != null)
            ? e['tags']['ref']
            : 'POI';

        if (plat != null && plng != null) {
          pois.add({'name': name, 'lat': plat, 'lng': plng});
        }
      }

      _overpassCache[key] = {'ts': now, 'data': pois};
      return pois;
    } catch (_) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getNearby(
    Position pos,
    double radiusMeters,
  ) async {
    final List<Map<String, dynamic>> found = [];
    final List<Map<String, dynamic>> pool = List.from(_pois);
    final fromAssets = await _loadPoisFromAssets();

    if (fromAssets.isNotEmpty) pool.addAll(fromAssets);

    try {
      final overpass = await _queryOverpass(
        pos.latitude,
        pos.longitude,
        radiusMeters,
      );

      if (overpass.isNotEmpty) {
        final existingKeys = pool
            .map(
              (p) =>
                  '${(p['lat'] as double).toStringAsFixed(6)}_${(p['lng'] as double).toStringAsFixed(6)}',
            )
            .toSet();

        for (final p in overpass) {
          final key =
              '${(p['lat'] as double).toStringAsFixed(6)}_${(p['lng'] as double).toStringAsFixed(6)}';
          if (!existingKeys.contains(key)) {
            pool.add(p);
            existingKeys.add(key);
          }
        }
      }
    } catch (_) {}

    for (final poi in pool) {
      final d = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        poi['lat'] as double,
        poi['lng'] as double,
      );

      if (d <= radiusMeters) {
        found.add({
          'name': poi['name'],
          'lat': poi['lat'],
          'lng': poi['lng'],
          'distance': d,
        });
      }
    }

    found.sort(
      (a, b) => (a['distance'] as double).compareTo(b['distance'] as double),
    );

    return found;
  }
}
