import 'dart:async';
import 'package:flutter/material.dart';
import '../main.dart';
import '../models/docs_model.dart';
import '../services/docs_service.dart';
import '../utils/debouncer.dart';
import '../services/progress_service.dart';
import '../database/hive_database.dart';
import '../widgets/search_bar.dart';
import '../widgets/clock_zone.dart';
import '../services/user_status_service.dart';
import '../widgets/bab_card_clean.dart';
import '../services/location_service.dart';
import '../services/nearby_service.dart';
import '../utils/palette.dart';
import '../services/settings_service.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import 'payment_offer_screen.dart';
import 'profile_map_screen.dart';
import 'detail_materi_screen.dart';
import 'notifications_screen.dart';

class HomeTab extends StatefulWidget {
  final String username;
  final bool unlockPremium;

  const HomeTab({Key? key, required this.username, this.unlockPremium = false})
    : super(key: key);

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with RouteAware {
  PBMMateri? _materi;
  List<Topik> _filteredTopik = [];
  bool _isCurrentUserPremium = false;
  bool _isLoading = true;
  bool _hasError = false;
  bool _hasLoaded = false;
  double _overallProgress = 0.0;
  final TextEditingController _searchController = TextEditingController();
  final Debouncer _debouncer = Debouncer(
    delay: const Duration(milliseconds: 300),
  );
  List<Map<String, dynamic>> _nearbyPlaces = [];
  bool _loadingNearby = false;
  late VoidCallback _allowLocationListener;

  @override
  void initState() {
    super.initState();
    // Debounce initial load to avoid multiple rapid loads when the
    // surrounding navigation/state changes (e.g. premium toggle) occur.
    _debouncer.run(() => _loadMateri());
    // Route observer subscription happens in didChangeDependencies so we
    // can refresh premium state when returning to this screen.
    // load nearby places if user allowed
    if (SettingsService.allowLocation.value) {
      _loadNearby();
    }

    // react to changes in the setting
    _allowLocationListener = () {
      if (!mounted) return;
      if (SettingsService.allowLocation.value) {
        _loadNearby();
      } else {
        setState(() {
          _nearbyPlaces = [];
        });
      }
    };
    SettingsService.allowLocation.addListener(_allowLocationListener);
  }

  @override
  void dispose() {
    SettingsService.allowLocation.removeListener(_allowLocationListener);
    try {
      routeObserver.unsubscribe(this);
    } catch (_) {}
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) routeObserver.subscribe(this, route);
  }

  @override
  void didPopNext() {
    // When returning to this screen, refresh user premium flag and optionally reload materi
    _refreshUserPremium();
  }

  Future<void> _refreshUserPremium() async {
    try {
      final hive = HiveDatabase();
      final email = await hive.getCurrentUserEmail();
      if (email != null) {
        final premium = await hive.isPremium(email);
        if (!mounted) return;
        setState(() => _isCurrentUserPremium = premium);
      } else {
        if (!mounted) return;
        setState(() => _isCurrentUserPremium = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isCurrentUserPremium = false);
    }
  }

  Future<void> _loadNearby() async {
    setState(() => _loadingNearby = true);
    final granted = await LocationService.requestPermission();
    if (!granted) {
      if (!mounted) return;
      setState(() => _loadingNearby = false);
      return;
    }
    final pos = await LocationService.getCurrentPosition();
    if (pos == null) {
      if (!mounted) return;
      setState(() => _loadingNearby = false);
      return;
    }
    try {
      final found = await NearbyService.getNearby(pos, 1500); // 1.5 km
      if (!mounted) return;
      setState(() {
        _nearbyPlaces = found;
        _loadingNearby = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingNearby = false);
    }
  }

  Future<void> _loadMateri({bool forceReload = false}) async {
    if (_hasLoaded && !forceReload) {
      debugPrint('ℹ️ HomeTab._loadMateri skipped (already loaded)');
      return;
    }
    debugPrint('▶️ HomeTab._loadMateri start (forceReload=$forceReload)');
    try {
      final materi = await DocsService.loadPBMMateri(
        forceReload: forceReload,
      ).timeout(const Duration(seconds: 8));
      debugPrint('✅ HomeTab._loadMateri completed: ${materi.judulMateri}');
      if (!mounted) return;
      setState(() {
        _materi = materi;
        _filteredTopik = materi.rangkumanTopik;
        _isLoading = false;
        _hasLoaded = true;
      });
      // Ensure premium flag is refreshed for the current user
      await _refreshUserPremium();
      _calculateOverallProgress(materi);
    } catch (e) {
      debugPrint('❌ HomeTab._loadMateri error: $e');
      if (e is TimeoutException) debugPrint('⏱️ HomeTab._loadMateri timed out');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _calculateOverallProgress(PBMMateri materi) async {
    int totalSub = 0;
    int doneSub = 0;
    final hive = HiveDatabase();
    final email = await hive.getCurrentUserEmail();

    for (var topik in materi.rangkumanTopik) {
      if (topik.konten is List) {
        for (int i = 0; i < (topik.konten as List).length; i++) {
          totalSub++;
          bool progress = await ProgressService.getProgress(topik.topikId, i, userEmail: email);
          if (progress) doneSub++;
        }
      } else if (topik.konten is Map) {
        totalSub++;
        bool progress = await ProgressService.getProgress(topik.topikId, 0, userEmail: email);
        if (progress) doneSub++;
      }
    }

    if (!mounted) return;
    setState(() {
      _overallProgress = totalSub > 0 ? doneSub / totalSub : 0.0;
    });
  }

  void _onSearchChanged(String query) {
    if (_materi == null) return;
    final q = query.trim().toLowerCase();
    // Use remote search when enabled; otherwise use local filtering
    _debouncer.run(() async {
      if (!mounted) return;
      if (q.isEmpty) {
        setState(() => _filteredTopik = _materi!.rangkumanTopik);
        return;
      }

      if (SettingsService.useRemoteMateri.value) {
        try {
          final api = ApiService();
          final resp = await api.search(q);
          // resp expected { query, results: [ { topik_id, judul_topik, ... } ] }
          final results = resp['results'] as List? ?? [];
          final List<Topik> fetched = [];
          for (final r in results) {
            try {
              final id = r['topik_id']?.toString();
              if (id == null) continue;
              final topicJson = await api.getTopicById(id);
              if (topicJson is Map<String, dynamic>) {
                fetched.add(Topik.fromJson(topicJson));
              }
            } catch (_) {}
          }
          if (!mounted) return;
          setState(() => _filteredTopik = fetched);
          return;
        } catch (e) {
          debugPrint('⚠️ Remote search failed, falling back to local: $e');
          // fallback to local filtering below
        }
      }

      // Local in-memory filtering
      setState(() {
        bool matchesTopik(Topik t) {
          final titleLower = t.judulTopik.toLowerCase();
          if (titleLower.contains(q)) return true;
          final konten = t.konten;
          if (konten is List) {
            for (var item in konten) {
              if (item is Map) {
                final sub = ((item['sub_judul'] ?? item['jenis'] ?? item['nama']) ?? '').toString().toLowerCase();
                if (sub.contains(q)) return true;
                for (var v in item.values) {
                  if (v is String && v.toLowerCase().contains(q)) return true;
                  if (v is List) {
                    for (var s in v) {
                      if (s is String && s.toLowerCase().contains(q)) return true;
                    }
                  }
                }
              } else if (item is String) {
                if (item.toLowerCase().contains(q)) return true;
              }
            }
          } else if (konten is Map) {
            final sub = ((konten['sub_judul'] ?? konten['jenis'] ?? konten['nama']) ?? '').toString().toLowerCase();
            if (sub.contains(q)) return true;
            for (var v in konten.values) {
              if (v is String && v.toLowerCase().contains(q)) return true;
              if (v is List) {
                for (var s in v) {
                  if (s is String && s.toLowerCase().contains(q)) return true;
                }
              }
            }
          }
          return false;
        }

        _filteredTopik = _materi!.rangkumanTopik.where(matchesTopik).toList();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => _loadMateri(forceReload: true),
      color: Colors.orangeAccent,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 12),
            const ClockZone(),
            const SizedBox(height: 8),
            // Card: Tempat Terdekat (public spaces)
            _buildNearbyCard(),
            const SizedBox(height: 8),
            // Location row removed (replaced by Nearby card)
            const SizedBox(height: 16),
            CustomSearchBar(
              controller: _searchController,
              onChanged: _onSearchChanged,
            ),
            const SizedBox(height: 24),
            if (_materi != null) _buildOverallProgress(),
            const SizedBox(height: 16),
            _buildMateriList(),
          ],
        ),
      ),
    );
  }

  Widget _buildNearbyCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Palette.primaryDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tempat Terdekat',
                style: TextStyle(
                  color: Palette.accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(Icons.refresh, color: Palette.mutedOnDark),
                onPressed: _loadNearby,
                tooltip: 'Perbarui',
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            // increased height slightly to avoid bottom overflow on small screens
            height: 96,
            child: _loadingNearby
                ? Center(
                    child: CircularProgressIndicator(color: Palette.accent),
                  )
                : _nearbyPlaces.isEmpty
                ? Text(
                    'Tidak ada tempat terdekat',
                    style: TextStyle(color: Palette.mutedOnDark),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _nearbyPlaces.length > 6
                        ? 6
                        : _nearbyPlaces.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (ctx, i) {
                      final p = _nearbyPlaces[i];
                      final name = (p['name'] ?? 'Tempat') as String;
                      final dist = (p['distance'] as double? ?? 0.0);
                      final distStr = dist >= 1000
                          ? '${(dist / 1000).toStringAsFixed(2)} km'
                          : '${dist.round()} m';
                      final icon = _iconForName(name);
                      return GestureDetector(
                        onTap: () {
                          // open map view
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ProfileMapScreen(),
                            ),
                          );
                        },
                        child: Container(
                          width: 170,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Palette.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(icon, color: Palette.primary, size: 24),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      name,
                                      style: TextStyle(
                                        color: Palette.onPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      distStr,
                                      style: TextStyle(
                                        color: Palette.mutedOnDark,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  IconData _iconForName(String name) {
    final n = name.toLowerCase();
    if (n.contains('kampus') ||
        n.contains('universit') ||
        n.contains('fakultas') ||
        n.contains('sekolah'))
      return Icons.school;
    if (n.contains('masjid') ||
        n.contains('mushola') ||
        n.contains('mosque') ||
        n.contains('geraja') ||
        n.contains('gereja'))
      return Icons.location_city;
    if (n.contains('cafe') ||
        n.contains('kedai') ||
        n.contains('kantin') ||
        n.contains('warung') ||
        n.contains('kedai'))
      return Icons.local_cafe;
    if (n.contains('perpus') || n.contains('perpustakaan'))
      return Icons.local_library;
    if (n.contains('park') || n.contains('taman')) return Icons.park;
    return Icons.location_on;
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ValueListenableBuilder<String?>(
          valueListenable: UserStatusService.usernameNotifier,
          builder: (context, value, child) {
            final name = value ?? widget.username;
            return Text(
              "Halo, $name 👋",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.notifications_none, color: Colors.white),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildOverallProgress() {
    final percentage = (_overallProgress * 100).round();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF00345B),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 5,
            offset: const Offset(2, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Progress Belajar Kamu",
            style: TextStyle(
              color: Colors.orangeAccent,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: _overallProgress,
            backgroundColor: Colors.white12,
            color: Colors.orangeAccent,
            minHeight: 8,
          ),
          const SizedBox(height: 6),
          Text(
            "$percentage% dari materi telah dipelajari",
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildMateriList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.orangeAccent),
      );
    } else if (_hasError) {
      return const Center(
        child: Text(
          "Gagal memuat materi 😔",
          style: TextStyle(color: Colors.white70),
        ),
      );
    } else if (_filteredTopik.isEmpty) {
      return const Center(
        child: Text(
          "Materi tidak ditemukan 😔",
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _filteredTopik.map((topik) {
        // find original index in the full materi list so numbering stays correct
        final originalIndex = _materi!.rangkumanTopik.indexWhere(
          (t) => t.topikId == topik.topikId,
        );
        final prevTopikId = originalIndex > 0
            ? _materi!.rangkumanTopik[originalIndex - 1].topikId
            : null;

        return BabCardClean(
          topik: topik,
          index: originalIndex,
          isPremium: originalIndex >= 2, // mulai bab ke-3 ke atas premium
            isPremiumUnlocked: _isCurrentUserPremium,
          prevTopikId: prevTopikId,
          onTapLocked: () => _showPremiumDialog(topik.judulTopik),
          onExamCompleted: (score, total, topikIndex) async {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  "Kamu menyelesaikan ${topik.judulTopik} "
                  "(${score}/$total)! 🎉",
                ),
                backgroundColor: Colors.greenAccent.shade700,
              ),
            );

            // Setelah ujian selesai, coba buka materi berikutnya otomatis
            try {
              if (_materi != null) {
                final nextIndex = topikIndex + 1;
                if (nextIndex < _materi!.rangkumanTopik.length) {
                  final nextTopik = _materi!.rangkumanTopik[nextIndex];
                  // If next topic is premium and the current user is not premium,
                  // show the purchase dialog instead of navigating.
                  final isNextPremium = nextIndex >= 2;
                  if (isNextPremium && !_isCurrentUserPremium) {
                    // show prompt to buy premium
                    _showPremiumDialog(nextTopik.judulTopik);
                    try {
                      await NotificationService.show(
                        'Akses Premium Diperlukan',
                        'Untuk membuka "${nextTopik.judulTopik}" kamu perlu membuka Premium.',
                      );
                    } catch (_) {}
                    return;
                  }
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

                  // Navigate to the first submateri of the next topik
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DetailMateriScreen(
                        topik: nextTopik,
                        subIndex: 0,
                        kontenItem: firstContent,
                      ),
                    ),
                  );

                  // Mark progress as read for UX continuity
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
                  setState(() {});
                }
              }
            } catch (e) {
              debugPrint('⚠️ Gagal membuka materi berikutnya: $e');
            }
          },
        );
      }).toList(),
    );
  }

  /// 🔹 Bottom Sheet Premium Unlock
  void _showPremiumDialog(String judulTopik) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF012D5A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Icon(
              Icons.lock_outline,
              color: Colors.orangeAccent,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              "Materi Premium",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Untuk mengakses \"$judulTopik\", kamu perlu membuka Premium terlebih dahulu.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                minimumSize: const Size(double.infinity, 48),
              ),
              icon: const Icon(Icons.workspace_premium_outlined),
              label: const Text("Buka / Beli Premium"),
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PaymentOfferScreen()),
                );
              },
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Nanti saja",
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}