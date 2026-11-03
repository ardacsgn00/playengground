import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playengground/main.dart';
import 'package:playengground/screens/hangman_screen.dart';
import 'package:playengground/screens/splash_screen.dart';
import 'package:playengground/screens/word_hunt_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('PlayEngGround Dashboard smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    // Build our app and trigger a frame.
    await tester.pumpWidget(const PlayEngGroundApp());

    // Verify that SplashScreen is displayed
    expect(find.byType(SplashScreen), findsOneWidget);

    // Complete splash screen delay and exit animation
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });

  testWidgets('Unified GameTutorialPopup renders even when old tutorialKey is false in SharedPreferences', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'hangman_tutorial': false,
      'word_hunt_tutorial': false,
      'collocation_magnet_tutorial': false,
    });
    await tester.pumpWidget(const MaterialApp(home: HangmanGameScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('OYUNA BAŞLA'), findsOneWidget);
    expect(find.text('A1–A2'), findsOneWidget);
    expect(find.text('Nasıl Oynanır?'), findsOneWidget);

    await tester.tap(find.text('OYUNA BAŞLA'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const MaterialApp(home: WordHuntScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('OYUNA BAŞLA'), findsOneWidget);
    expect(find.text('KATEGORİ SEÇİMİ'), findsOneWidget);
  });
}
