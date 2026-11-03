import 'package:flutter_test/flutter_test.dart';
import 'package:playengground/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
  });

  test('SettingsService initializes with default true for both settings', () async {
    expect(SettingsService.instance.showHighScores, true);
    expect(SettingsService.instance.showTopicBadges, true);
  });

  test('SettingsService toggles showHighScores and persists', () async {
    await SettingsService.instance.setShowHighScores(false);
    expect(SettingsService.instance.showHighScores, false);
    expect(SettingsService.instance.settingsNotifier.value.showHighScores, false);

    await SettingsService.instance.setShowHighScores(true);
    expect(SettingsService.instance.showHighScores, true);
  });

  test('SettingsService toggles showTopicBadges and persists', () async {
    await SettingsService.instance.setShowTopicBadges(false);
    expect(SettingsService.instance.showTopicBadges, false);
    expect(SettingsService.instance.settingsNotifier.value.showTopicBadges, false);

    await SettingsService.instance.setShowTopicBadges(true);
    expect(SettingsService.instance.showTopicBadges, true);
  });
}
