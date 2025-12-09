import 'dart:async';

import 'package:flutter/material.dart';
import '../services/quiz_history_service.dart';
import '../screens/quiz_history_screen.dart';

class QuizHistoryBadge extends StatefulWidget {
  const QuizHistoryBadge({Key? key}) : super(key: key);

  @override
  State<QuizHistoryBadge> createState() => _QuizHistoryBadgeState();
}

class _QuizHistoryBadgeState extends State<QuizHistoryBadge> {
  int _count = 0;
  late final StreamSubscription _sub;

  @override
  void initState() {
    super.initState();
    _loadCount();
    _sub = QuizHistoryService.onChanged.listen((_) => _loadCount());
  }

  Future<void> _loadCount() async {
    final all = await QuizHistoryService.all();
    if (!mounted) return;
    setState(() {
      _count = all.length;
    });
  }

  @override
  void dispose() {
    try {
      _sub.cancel();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QuizHistoryScreen()),
              );
            },
            child: const SizedBox(
              width: 48,
              height: 48,
              child: Center(child: Icon(Icons.history, color: Colors.white)),
            ),
          ),
        ),
        if (_count > 0)
          Positioned(
            right: 6,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Center(
                child: Text(
                  _count > 99 ? '99+' : _count.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
