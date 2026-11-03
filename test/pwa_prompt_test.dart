import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playengground/widgets/pwa_prompt_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PwaPromptDialog renders correctly and "Bir daha gösterme" works', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => PwaPromptDialog.show(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Verify key titles and texts
    expect(find.text('PlayEngGround\'ı Cihazına Yükle'), findsOneWidget);
    expect(find.text('Yükle'), findsOneWidget);
    expect(find.text('Daha Sonra'), findsOneWidget);
    expect(find.text('Bir daha gösterme'), findsOneWidget);

    // Tap "Bir daha gösterme"
    await tester.tap(find.text('Bir daha gösterme'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(PwaPromptDialog.prefDontShowAgainKey), isTrue);
  });
}
