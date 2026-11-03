import 'package:flutter_test/flutter_test.dart';
import 'package:playengground/services/streak_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StreakService.instance.init();
  });

  test('StreakService is safely inactive', () async {
    final data = StreakService.instance.streakNotifier.value;
    expect(data.currentStreak, 0);
    expect(data.isCompletedToday, false);
    final result = await StreakService.instance.recordPractice();
    expect(result.isNewDayPractice, false);
    expect(result.currentStreak, 0);
  });
}
