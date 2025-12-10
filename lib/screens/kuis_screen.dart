import 'package:flutter/material.dart';
import '../widgets/custom_app_bar.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../main.dart';
import '../models/quiz_history.dart';
import '../services/quiz_history_service.dart';
import '../database/hive_database.dart';
import '../widgets/quiz_history_badge.dart';
import '../models/docs_model.dart';
import '../services/docs_service.dart';
import '../utils/debouncer.dart';

class KuisScreen extends StatefulWidget {
  const KuisScreen({Key? key}) : super(key: key);

  @override
  State<KuisScreen> createState() => _KuisScreenState();
}

class _KuisScreenState extends State<KuisScreen> with RouteAware {
  List<Kuis> _allQuestions = [];
  List<Kuis> _lastSessionQuestions = [];
  bool _isLoading = true;
  bool _isFinished = false;
  int _currentIndex = 0;
  int _score = 0;
  int? _selectedIndex;
  bool _isAnswered = false;
  int _maxQuestions = 0; // 0 = all
  bool _promptShown = false;
  bool _isPromptShowing = false;

  final FlutterLocalNotificationsPlugin _notif =
      FlutterLocalNotificationsPlugin();
  final Debouncer _debouncer = Debouncer(
    delay: const Duration(milliseconds: 300),
  );

  /// Render a simple inline-markup string where *word* becomes italic.
  /// This is a minimal parser that converts text segments wrapped with
  /// single asterisks into italic TextSpan. It does not implement full
  /// Markdown, but is sufficient for the simple `*italic*` strings
  /// used in the materi JSON.
  InlineSpan _parseInlineItalic(String input, TextStyle style) {
    final pattern = RegExp(r'(\*[^*]+\*)');
    final matches = pattern.allMatches(input);
    if (matches.isEmpty) return TextSpan(text: input, style: style);

    final children = <TextSpan>[];
    int lastIndex = 0;

    for (final m in matches) {
      if (m.start > lastIndex) {
        children.add(
          TextSpan(text: input.substring(lastIndex, m.start), style: style),
        );
      }
      final token = input.substring(m.start + 1, m.end - 1); // strip *
      children.add(
        TextSpan(
          text: token,
          style: style.merge(const TextStyle(fontStyle: FontStyle.italic)),
        ),
      );
      lastIndex = m.end;
    }

    if (lastIndex < input.length) {
      children.add(TextSpan(text: input.substring(lastIndex), style: style));
    }

    return TextSpan(children: children, style: style);
  }

  @override
  void initState() {
    super.initState();
    debugPrint('▶️ KuisScreen.initState called');
    _initNotif();
    // Debounce initial load so rapid UI rebuilds don't trigger multiple
    // heavy parsing operations.
    _debouncer.run(() => _loadAllQuestions());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    try {
      routeObserver.unsubscribe(this);
    } catch (_) {}
    super.dispose();
  }

  @override
  void didPopNext() {
    // Called when the top route has been popped and this route shows up again.
    // Only reload & re-prompt if the previous session was finished.
    // If user already selected a question count and is mid-quiz, do nothing
    // so we don't repeatedly prompt them.
    debugPrint(
      '▶️ KuisScreen.didPopNext - visible again, finished=$_isFinished',
    );
    if (_isFinished) {
      _debouncer.run(() => _loadAllQuestions());
    }
    // When coming back to this route, reset prompt flag and try to show
    // the prompt if questions are ready and the user is not mid-quiz.
    _promptShown = false;
    WidgetsBinding.instance.addPostFrameCallback((_) => _promptIfNeeded());
  }

  @override
  void didPush() {
    // Reset prompt flag when this route is pushed so the prompt appears
    // on every fresh navigation to the screen (unless mid-quiz).
    _promptShown = false;
    WidgetsBinding.instance.addPostFrameCallback((_) => _promptIfNeeded());
  }

  Future<void> _initNotif() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _notif.initialize(initSettings);

    await _notif
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  Future<void> _showKuisFinishedNotif(int score, int total) async {
    const androidDetails = AndroidNotificationDetails(
      'kuis_channel',
      'Kuis Notifications',
      channelDescription: 'Notifikasi ketika kuis selesai',
      importance: Importance.high,
      priority: Priority.high,
      color: Colors.orangeAccent,
    );
    const notifDetails = NotificationDetails(android: androidDetails);

    await _notif.show(
      0,
      'Kuis Selesai 🎉',
      'Skor kamu: $score dari $total soal!',
      notifDetails,
    );
  }

  Future<void> _recordQuizHistory(int score, int total) async {
    try {
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      // attach current user's email if available
      String? email;
      String? username;
      try {
        final hive = HiveDatabase();
        email = await hive.getCurrentUserEmail();
        if (email != null) username = await hive.getUsername(email);
      } catch (_) {
        email = null;
      }

      final q = QuizHistory(
        id: id,
        time: DateTime.now(),
        correct: score,
        total: total,
        email: email,
        username: username,
      );
      await QuizHistoryService.add(q);
    } catch (e) {
      debugPrint('❌ Gagal menyimpan riwayat kuis: $e');
    }
  }

  /// 🔹 Gabung kuis dari semua topik (termasuk Kamus)
  Future<void> _loadAllQuestions({bool showPrompt = true}) async {
    debugPrint('▶️ KuisScreen._loadAllQuestions start');
    try {
      final materi = await DocsService.loadPBMMateri();
      final List<Kuis> all = [];

      for (var topik in materi.rangkumanTopik) {
        all.addAll(topik.kuis);

        if (topik.topikId.toLowerCase() == "kamus") {
          final konten = topik.konten;
          if (konten is Map && konten["daftar_kata"] is List) {
            final daftarKata = List<Map<String, dynamic>>.from(
              konten["daftar_kata"],
            );

            daftarKata.shuffle();
            final sample = daftarKata.take(30).toList();

            for (var i = 0; i < sample.length; i++) {
              final data = sample[i];
              final baku = data["baku"] ?? "";
              final tidakBaku = data["tidak_baku"] ?? "";
              final opsi = <String>[baku.toString(), tidakBaku.toString()]
                ..shuffle();

              if (baku.isEmpty || tidakBaku.isEmpty) continue;

              all.add(
                Kuis(
                  idPertanyaan: i % 2 == 0 ? "baku_$i" : "tidakbaku_$i",
                  pertanyaan: i % 2 == 0
                      ? "Manakah kata baku dari pilihan berikut?"
                      : "Manakah kata tidak baku dari pilihan berikut?",
                  pilihan: opsi,
                  jawabanBenarIndex: i % 2 == 0
                      ? opsi.indexOf(baku)
                      : opsi.indexOf(tidakBaku),
                  pembahasan: i % 2 == 0
                      ? "Kata baku adalah '$baku'."
                      : "Kata tidak baku adalah '$tidakBaku'.",
                ),
              );
            }
          }
        }
      }

      all.shuffle();

      // apply max questions option if set
      if (_maxQuestions > 0 && _maxQuestions < all.length) {
        all.removeRange(_maxQuestions, all.length);
      }

      debugPrint(
        '✅ KuisScreen._loadAllQuestions loaded ${all.length} questions',
      );
      // Save a copy as the current session sequence so "Ulangi Kuis" can reuse it
      _lastSessionQuestions = List<Kuis>.from(all);
      setState(() {
        _allQuestions = List<Kuis>.from(all);
        _isLoading = false;
        // Reset prompt flag so we can show it when the user actually visits
        _promptShown = false;
      });
      // After the frame renders, attempt to show the question-count prompt
      if (showPrompt)
        WidgetsBinding.instance.addPostFrameCallback((_) => _promptIfNeeded());
    } catch (e) {
      debugPrint("❌ Error load kuis: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _nextQuestion() async {
    if (_currentIndex < _allQuestions.length - 1) {
      setState(() {
        _currentIndex++;
        _isAnswered = false;
        _selectedIndex = null;
      });
    } else {
      _showKuisFinishedNotif(_score, _allQuestions.length);
      await _recordQuizHistory(_score, _allQuestions.length);
      setState(() => _isFinished = true);
    }
  }

  Future<void> _promptIfNeeded() async {
    if (!mounted) return;
    // Don't prompt if already shown, still loading, no questions, or
    // not the active route. Also avoid prompting if the user is mid-quiz
    // (i.e. already answered/advanced questions) so we don't interrupt.
    if (_promptShown) return;
    if (_isLoading) return;
    if (_allQuestions.isEmpty) return;
    final isCurrent = ModalRoute.of(context)?.isCurrent ?? false;
    if (!isCurrent) return;
    if (_currentIndex > 0 && !_isFinished) return;

    debugPrint('▶️ KuisScreen._promptIfNeeded - showing prompt');
    await _promptQuestionCount();
    _promptShown = true;
  }

  Future<void> _promptQuestionCount() async {
    debugPrint('▶️ KuisScreen._promptQuestionCount showing bottom sheet');
    if (!mounted) return;
    if (_isPromptShowing) {
      debugPrint('▶️ KuisScreen._promptQuestionCount - already showing, skip');
      return;
    }

    _isPromptShowing = true;
    int? max;
    try {
      max = await showModalBottomSheet<int>(
        context: context,
        backgroundColor: const Color(0xFF012D5A),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Pilih jumlah soal',
                  style: TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, 10),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                  ),
                  child: const Text('10 Soal'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, 20),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                  ),
                  child: const Text('20 Soal'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, 0),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                  ),
                  child: const Text('Semua Soal'),
                ),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      );
    } finally {
      _isPromptShowing = false;
    }

    if (!mounted) return;
    if (max == null) return;
    final int chosen = max; // promote to non-null local variable

    // Prepare and apply the chosen question count consistently.
    await _prepareQuestionsForSession(chosen);
  }

  /// Prepare the question list for a new session using the provided
  /// `max` count. This uses the current `_lastSessionQuestions` as the
  /// base ordered pool (which is set when questions are first loaded or
  /// when "Soal Baru" is requested). It also resets quiz state.
  Future<void> _prepareQuestionsForSession(int max) async {
    if (!mounted) return;
    // Use the last session pool if available; otherwise use the current
    // _allQuestions as a fallback.
    final base = _lastSessionQuestions.isNotEmpty
        ? _lastSessionQuestions
        : _allQuestions;

    List<Kuis> next;
    if (max > 0 && max < base.length) {
      next = base.sublist(0, max);
    } else {
      next = List<Kuis>.from(base);
    }

    setState(() {
      _maxQuestions = max;
      _allQuestions = List<Kuis>.from(next);
      _lastSessionQuestions = List<Kuis>.from(next);
      _isFinished = false;
      _score = 0;
      _currentIndex = 0;
      _isAnswered = false;
      _selectedIndex = null;
    });
  }

  Color _getOptionColor(int index, Kuis kuis) {
    if (!_isAnswered) return const Color(0xFF012D5A);
    if (index == kuis.jawabanBenarIndex) return Colors.green.withOpacity(0.4);
    if (index == _selectedIndex) return Colors.red.withOpacity(0.4);
    return const Color(0xFF012D5A);
  }

  Widget _buildResultPage() {
    final total = _allQuestions.length;
    final percent = (_score / total * 100).round();
    final now = DateFormat("d MMM yyyy, HH:mm", "id_ID").format(DateTime.now());

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.emoji_events,
              color: Colors.orangeAccent,
              size: 80,
            ),
            const SizedBox(height: 20),
            const Text(
              "Kuis Selesai!",
              style: TextStyle(
                color: Colors.orangeAccent,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Skor kamu: $_score / $total",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "$percent%",
              style: const TextStyle(
                color: Colors.greenAccent,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Dikerjakan pada:\n$now",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    // Start a fresh shuffled quiz without showing the prompt
                    setState(() {
                      _isFinished = false;
                      _score = 0;
                      _currentIndex = 0;
                      _isAnswered = false;
                      _selectedIndex = null;
                    });
                    // regenerate & shuffle questions; this also updates _lastSessionQuestions
                    await _loadAllQuestions(showPrompt: false);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Soal baru disiapkan'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.shuffle),
                  label: const Text('Soal Baru'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    setState(() {
                      _isFinished = false;
                      _score = 0;
                      _currentIndex = 0;
                      _isAnswered = false;
                      _selectedIndex = null;
                    });
                    // Reuse the previous session's question order. If not available,
                    // fall back to loading a fresh shuffled set.
                    if (_lastSessionQuestions.isNotEmpty) {
                      setState(() {
                        _allQuestions = List<Kuis>.from(_lastSessionQuestions);
                      });
                    } else {
                      await _loadAllQuestions(showPrompt: false);
                    }
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Kuis diulang'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.replay),
                  label: const Text("Ulangi Kuis"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // History moved to app bar action for better visibility.
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionPage(Kuis kuis) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Soal ${_currentIndex + 1} dari ${_allQuestions.length}",
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
            return GestureDetector(
              onTap: _isAnswered
                  ? null
                  : () {
                      setState(() {
                        _selectedIndex = index;
                        _isAnswered = true;
                        if (index == kuis.jawabanBenarIndex) _score++;
                      });
                    },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: _getOptionColor(index, kuis),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: RichText(
                  text: _parseInlineItalic(
                    kuis.pilihan[index],
                    const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 20),
          if (_isAnswered)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF00344E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedIndex == kuis.jawabanBenarIndex
                        ? "✅ Jawaban kamu benar!"
                        : "❌ Salah, jawabannya: ${kuis.pilihan[kuis.jawabanBenarIndex]}",
                    style: TextStyle(
                      color: _selectedIndex == kuis.jawabanBenarIndex
                          ? Colors.greenAccent
                          : Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // allow simple *italic* markup in pembahasan as well
                  RichText(
                    text: _parseInlineItalic(
                      "Pembahasan: ${kuis.pembahasan}",
                      const TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
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
                _currentIndex == _allQuestions.length - 1
                    ? "Selesai"
                    : "Lanjut",
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001F3F),
      appBar: CustomAppBar(
        title: 'Kuis',
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF012D5A),
        centerTitle: true,
        actions: [
          // Show a history icon with badge count
          SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: SizedBox(width: 48, child: QuizHistoryBadge()),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.orangeAccent),
            )
          : _allQuestions.isEmpty
          ? const Center(
              child: Text(
                "Belum ada soal kuis.",
                style: TextStyle(color: Colors.white70),
              ),
            )
          : _isFinished
          ? _buildResultPage()
          : _buildQuestionPage(_allQuestions[_currentIndex]),
    );
  }
}
