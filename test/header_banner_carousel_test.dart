import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playengground/screens/games_screen.dart';
import 'package:playengground/services/mistake_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Header Banner HUD renders without overflow on 320x568 small mobile screen',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: GamesScreen(),
      ),
    );

    // Initial pump
    await tester.pump(const Duration(milliseconds: 100));

    // Verify game carousel PageView and HUD pills are visible
    expect(find.byType(PageView), findsWidgets);
    expect(find.textContaining('Rastgele'), findsOneWidget);

    // Swipe horizontally on carousel to test interaction
    await tester.drag(find.byType(PageView).first, const Offset(-200, 0));
    await tester.pump(const Duration(milliseconds: 500));

    // Ensure no overflow errors occurred
    expect(tester.takeException(), isNull);

    // Dispose widget and clear any pending delayed timers
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Header Banner on Desktop (1200x800): Rastgele Oyun button shows when 0 mistakes',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Ensure mistake bank is empty
    MistakeService.instance.mistakesNotifier.value = [];

    await tester.pumpWidget(
      const MaterialApp(
        home: GamesScreen(),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));

    // Should find Rastgele button
    expect(find.textContaining('Rastgele'), findsOneWidget);

    // Should NOT find Mistake card CTA or mistake count on desktop when 0 mistakes
    expect(find.text('Çalış'), findsNothing);

    // Dispose widget and clear any pending delayed timers
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Header Banner on Desktop (1200x800): side-by-side cards show when mistakes exist',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // Add a mistake
    final now = DateTime.now();
    MistakeService.instance.mistakesNotifier.value = [
      MistakeItem(
        id: 'test_1',
        word: 'apple',
        meaning: 'elma',
        sourceGame: 'Hangman',
        createdAt: now,
        lastMistakenAt: now,
      ),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: GamesScreen(),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));

    // Both Rastgele button and Mistake card should be visible
    expect(find.textContaining('Rastgele'), findsOneWidget);
    expect(find.text('1 Hata'), findsOneWidget);
    expect(find.text('Çalış'), findsOneWidget);

    // Dispose widget and clear any pending delayed timers
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Mobile HUD shows Rastgele tactile pill without overflow',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: GamesScreen(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Rastgele'), findsOneWidget);
    expect(find.text('OYNA'), findsWidgets);

    // Dispose widget and clear any pending delayed timers
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });
}
