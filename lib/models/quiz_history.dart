class QuizHistory {
  final String id;
  final DateTime time;
  final int correct;
  final int total;
  final String? email;
  final String? username;

  QuizHistory({
    required this.id,
    required this.time,
    required this.correct,
    required this.total,
    this.email,
    this.username,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'time': time.toIso8601String(),
    'correct': correct,
    'total': total,
    'email': email,
    'username': username,
  };

  factory QuizHistory.fromJson(Map<String, dynamic> json) => QuizHistory(
    id: json['id'],
    time: DateTime.parse(json['time']),
    correct: json['correct'],
    total: json['total'],
    email: json['email'],
    username: json['username'],
  );
}
