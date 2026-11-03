import 'package:flutter_test/flutter_test.dart';
import 'package:playengground/services/mistake_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await MistakeService.instance.init();
    await MistakeService.instance.clearAll();
  });

  test('MistakeService records new mistake and persists', () async {
    expect(MistakeService.instance.hasMistakes, false);
    expect(MistakeService.instance.count, 0);

    await MistakeService.instance.recordMistake(
      word: 'reluctant',
      meaning: 'isteksiz',
      sourceGame: 'Word Marathon',
      wrongAnswer: 'istekli',
    );

    expect(MistakeService.instance.hasMistakes, true);
    expect(MistakeService.instance.count, 1);
    expect(MistakeService.instance.mistakes.first.word, 'reluctant');
    expect(MistakeService.instance.mistakes.first.mistakeCount, 1);
  });

  test('MistakeService increments count on repeated mistake', () async {
    await MistakeService.instance.recordMistake(
      word: 'abandon',
      meaning: 'terk etmek',
      sourceGame: 'Word Marathon',
    );
    await MistakeService.instance.recordMistake(
      word: 'abandon',
      meaning: 'terk etmek',
      sourceGame: 'Meaning Sniper',
      wrongAnswer: 'vazgeçmek',
    );

    expect(MistakeService.instance.count, 1);
    final item = MistakeService.instance.mistakes.first;
    expect(item.word, 'abandon');
    expect(item.mistakeCount, 2);
    expect(item.sourceGame, 'Meaning Sniper');
  });

  test('MistakeService removes mistake by id', () async {
    await MistakeService.instance.recordMistake(
      word: 'ubiquitous',
      meaning: 'her yerde bulunan',
      sourceGame: 'Hangman',
    );
    expect(MistakeService.instance.count, 1);

    final id = MistakeService.instance.mistakes.first.id;
    final removed = await MistakeService.instance.removeMistake(id);
    expect(removed, true);
    expect(MistakeService.instance.count, 0);
  });

  test('MistakeService generates custom dictionary for games', () async {
    await MistakeService.instance.recordMistake(
      word: 'Diligent',
      meaning: 'Çalışkan',
      sourceGame: 'Word Marathon',
    );
    await MistakeService.instance.recordMistake(
      word: 'Brisk',
      meaning: 'Canlı, hızlı',
      sourceGame: 'Memory Match',
    );

    final dict = MistakeService.instance.getAsCustomDict();
    expect(dict.length, 2);
    expect(dict['Diligent'], 'Çalışkan');
    expect(dict['Brisk'], 'Canlı, hızlı');
  });

  test('MistakeService reloads persisted mistakes across restarts/refreshes', () async {
    await MistakeService.instance.recordMistake(
      word: 'Persistent',
      meaning: 'Kalıcı',
      sourceGame: 'Word Defuser',
    );
    expect(MistakeService.instance.count, 1);

    // Simulate page refresh by re-initializing with force
    await MistakeService.instance.init(force: true);
    expect(MistakeService.instance.count, 1);
    expect(MistakeService.instance.mistakes.first.word, 'Persistent');
  });
}
