import 'package:flutter/foundation.dart';

class ScoreRecordResult {
  final bool isNewHighScore;
  final bool isNewBestStreak;
  final int currentScore;
  final int highScore;
  final int currentStreak;
  final int bestStreak;

  const ScoreRecordResult({
    required this.isNewHighScore,
    required this.isNewBestStreak,
    required this.currentScore,
    required this.highScore,
    required this.currentStreak,
    required this.bestStreak,
  });
}

class ScoreService {
  ScoreService._();
  static final ScoreService instance = ScoreService._();

  final ValueNotifier<Map<String, int>> highScoresNotifier =
      ValueNotifier<Map<String, int>>(const {});
  final ValueNotifier<Map<String, int>> bestStreaksNotifier =
      ValueNotifier<Map<String, int>>(const {});

  Future<void> init() async {}

  int getHighScore(String gameId) => 0;

  int getBestStreak(String gameId) => 0;

  Future<ScoreRecordResult> recordScore({
    required String gameId,
    required int score,
    int streak = 0,
  }) async {
    return ScoreRecordResult(
      isNewHighScore: false,
      isNewBestStreak: false,
      currentScore: score,
      highScore: 0,
      currentStreak: streak,
      bestStreak: 0,
    );
  }
}
