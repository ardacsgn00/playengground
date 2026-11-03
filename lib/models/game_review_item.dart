class GameReviewItem {
  final String id;
  final String word;
  final String meaning;
  final String? question;
  final String? userAnswer;
  final String? correctAnswer;
  final bool isCorrect;
  final String? note;

  const GameReviewItem({
    this.id = '',
    required this.word,
    required this.meaning,
    this.question,
    this.userAnswer,
    this.correctAnswer,
    required this.isCorrect,
    this.note,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'word': word,
        'meaning': meaning,
        'question': question,
        'userAnswer': userAnswer,
        'correctAnswer': correctAnswer,
        'isCorrect': isCorrect,
        'note': note,
      };

  factory GameReviewItem.fromJson(Map<String, dynamic> json) {
    return GameReviewItem(
      id: json['id']?.toString() ?? '',
      word: json['word']?.toString() ?? '',
      meaning: json['meaning']?.toString() ?? '',
      question: json['question']?.toString(),
      userAnswer: json['userAnswer']?.toString(),
      correctAnswer: json['correctAnswer']?.toString(),
      isCorrect: json['isCorrect'] == true,
      note: json['note']?.toString(),
    );
  }
}
