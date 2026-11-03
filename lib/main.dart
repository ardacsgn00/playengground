import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_theme.dart';
import 'screens/splash_screen.dart';
import 'services/level_service.dart';
import 'services/mistake_service.dart';
import 'services/streak_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LevelService.instance.init();
  await StreakService.instance.init();
  await MistakeService.instance.init();
  // ESC ile geri çıkış: Odak hangi widget'ta olursa olsun (Flame oyunları,
  // odaksız canvas vb.) çalışması için global klavye dinleyicisi kullanılır.
  HardwareKeyboard.instance.addHandler(PlayEngGroundApp.handleGlobalKey);
  runApp(const PlayEngGroundApp());
}

class PlayEngGroundApp extends StatelessWidget {
  const PlayEngGroundApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static DateTime _lastEscape = DateTime.fromMillisecondsSinceEpoch(0);

  /// Global ESC handler. Pops the top route (dialog, onboarding or game).
  /// Routes with PopScope(canPop: false) still get their exit-confirm flow,
  /// since maybePop() triggers onPopInvoked.
  static bool handleGlobalKey(KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape) {
      return false;
    }
    final now = DateTime.now();
    if (now.difference(_lastEscape).inMilliseconds < 250) return true;
    _lastEscape = now;

    final nav = navigatorKey.currentState;
    if (nav == null) return false;
    nav.maybePop();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'PlayEngGround',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      // Varsayılan ESC → DismissIntent eşlemesini kapat; aksi halde diyaloglarda
      // global handler ile birlikte çift pop oluşur.
      shortcuts: <ShortcutActivator, Intent>{
        ...WidgetsApp.defaultShortcuts,
        const SingleActivator(LogicalKeyboardKey.escape):
            const DoNothingAndStopPropagationIntent(),
      },
      home: const SplashScreen(),
    );
  }
}
