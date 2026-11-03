import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsData {
  final bool showHighScores;
  final bool showTopicBadges;

  const SettingsData({
    required this.showHighScores,
    required this.showTopicBadges,
  });

  SettingsData copyWith({
    bool? showHighScores,
    bool? showTopicBadges,
  }) {
    return SettingsData(
      showHighScores: showHighScores ?? this.showHighScores,
      showTopicBadges: showTopicBadges ?? this.showTopicBadges,
    );
  }
}

class SettingsService {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  static const String _keyShowHighScores = 'playengground_show_high_scores';
  static const String _keyShowTopicBadges = 'playengground_show_topic_badges';

  final ValueNotifier<SettingsData> settingsNotifier = ValueNotifier<SettingsData>(
    const SettingsData(showHighScores: true, showTopicBadges: true),
  );

  bool _initialized = false;

  bool get showHighScores => settingsNotifier.value.showHighScores;
  bool get showTopicBadges => settingsNotifier.value.showTopicBadges;

  Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final highScores = prefs.getBool(_keyShowHighScores) ?? true;
      final topicBadges = prefs.getBool(_keyShowTopicBadges) ?? true;

      settingsNotifier.value = SettingsData(
        showHighScores: highScores,
        showTopicBadges: topicBadges,
      );
      _initialized = true;
    } catch (e) {
      debugPrint('SettingsService init error: $e');
    }
  }

  Future<void> setShowHighScores(bool value) async {
    settingsNotifier.value = settingsNotifier.value.copyWith(showHighScores: value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyShowHighScores, value);
    } catch (e) {
      debugPrint('SettingsService save showHighScores error: $e');
    }
  }

  Future<void> setShowTopicBadges(bool value) async {
    settingsNotifier.value = settingsNotifier.value.copyWith(showTopicBadges: value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyShowTopicBadges, value);
    } catch (e) {
      debugPrint('SettingsService save showTopicBadges error: $e');
    }
  }
}
