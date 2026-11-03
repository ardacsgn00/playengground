import 'package:flutter/foundation.dart';

class StreakData {
  final int currentStreak;
  final int bestStreak;
  final bool isCompletedToday;
  final String? lastDate;

  const StreakData({
    required this.currentStreak,
    required this.bestStreak,
    required this.isCompletedToday,
    this.lastDate,
  });
}

class StreakRecordResult {
  final bool isNewDayPractice;
  final int currentStreak;
  final int bestStreak;

  const StreakRecordResult({
    required this.isNewDayPractice,
    required this.currentStreak,
    required this.bestStreak,
  });
}

class StreakService {
  StreakService._();
  static final StreakService instance = StreakService._();

  final ValueNotifier<StreakData> streakNotifier = ValueNotifier<StreakData>(
    const StreakData(currentStreak: 0, bestStreak: 0, isCompletedToday: false),
  );

  Future<void> init() async {}

  int? consumePendingCelebration() => null;

  Future<StreakRecordResult> recordPractice() async {
    return const StreakRecordResult(
      isNewDayPractice: false,
      currentStreak: 0,
      bestStreak: 0,
    );
  }
}
