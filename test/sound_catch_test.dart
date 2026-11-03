import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playengground/screens/sound_catch_screen.dart';
import 'package:playengground/services/level_service.dart';
import 'package:playengground/services/mistake_service.dart';
import 'package:playengground/services/score_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ScoreService.instance.init();
    await MistakeService.instance.init();
    await LevelService.instance.init();
  });

  testWidgets(
    'SoundCatchScreen renders tutorial popup and starts on mobile viewport',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const MaterialApp(home: SoundCatchScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify tutorial popup opens
      expect(find.text('Sound Catch'), findsWidgets);
      expect(find.text('OYUNA BAŞLA'), findsOneWidget);
      expect(find.text('A1–A2'), findsOneWidget);

      // Tap start game
      await tester.tap(find.text('OYUNA BAŞLA'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Should find audio listen card and options
      expect(find.text('Tekrar Dinle'), findsOneWidget);

      // Dispose widget cleanly
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets(
    'SoundCatchScreen renders cleanly on desktop viewport (1920x945)',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 945);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const MaterialApp(home: SoundCatchScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Dismiss popup
      await tester.tap(find.text('OYUNA BAŞLA'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify desktop 2-column sidebar presence
      expect(find.text('Oturum İlerlemesi'), findsOneWidget);
      expect(find.text('Doğru Cevaplar'), findsOneWidget);

      // Dispose widget cleanly
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets('SoundCatchScreen on 9:16 mobile viewport (390x844) answers without jump or overflow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const MaterialApp(
        home: SoundCatchScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Tap start game
    await tester.tap(find.text('OYUNA BAŞLA'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Tap option 'A' button
    final optionAFinder = find.text('A');
    expect(optionAFinder, findsOneWidget);
    await tester.tap(optionAFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify no overflow happened and feedback was shown
    expect(tester.takeException(), isNull);

    // Dispose widget cleanly
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });
}
