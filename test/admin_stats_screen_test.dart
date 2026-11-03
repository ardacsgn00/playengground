import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playengground/screens/admin_stats_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AdminStatsScreen renders cleanly on 384x782 mobile viewport without overflow', (WidgetTester tester) async {
    // Exact phone viewport matching user screenshot (384x782, 2.8 dpr)
    tester.view.physicalSize = const Size(384 * 2.8, 782 * 2.8);
    tester.view.devicePixelRatio = 2.8;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: AdminStatsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify AppBar title
    expect(find.text('İstatistik & Ziyaretçi Paneli'), findsOneWidget);
  });
}
