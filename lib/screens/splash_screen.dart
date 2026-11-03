import 'package:flutter/material.dart';
import 'package:playengground/screens/games_screen.dart';
import '../services/audio_manager.dart';
import '../widgets/onboarding_dialog.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static bool _hasPlayedInSession = false;

  late final AnimationController _controller;
  late final AnimationController _exitController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _exitFadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.65,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
      ),
    );

    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _exitFadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _exitController, curve: Curves.easeOut));

    if (_hasPlayedInSession) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _navigateToNext());
      return;
    }
    _hasPlayedInSession = true;

    AudioManager.instance.playOpeningSound();
    _controller.forward();

    // Start exit animation, then navigate to next screen
    Future.delayed(const Duration(milliseconds: 950), () async {
      if (!mounted) return;
      await _exitController.forward();
      if (!mounted) return;
      await _navigateToNext();
    });
  }

  Future<void> _navigateToNext() async {
    bool shouldShowOnboarding = false;
    try {
      shouldShowOnboarding = await OnboardingDialog.shouldShow();
    } catch (_) {
      shouldShowOnboarding = false;
    }
    if (!mounted) return;
    final Widget nextScreen = shouldShowOnboarding
        ? const OnboardingDialog(isInitialRoute: true)
        : const GamesScreen();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([_controller, _exitController]),
          builder: (context, child) {
            final isExiting =
                _exitController.isAnimating || _exitController.isCompleted;
            return FadeTransition(
              opacity: isExiting ? _exitFadeAnimation : _fadeAnimation,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: child,
              ),
            );
          },
          child: Image.asset(
            'assets/logo/playengground logo.png',
            width: 600,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}
