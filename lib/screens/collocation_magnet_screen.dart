import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/collocation_data.dart';
import '../services/audio_service.dart';
import '../services/tts_service.dart';
import '../widgets/game_tutorial_popup.dart';
import '../widgets/exit_confirmation_dialog.dart';
import '../widgets/marquee_title.dart';
import '../services/mistake_service.dart';
import '../services/score_service.dart';
import '../models/game_review_item.dart';
import '../widgets/game_review_accordion.dart';

class CollocationMagnetScreen extends StatefulWidget {
  const CollocationMagnetScreen({super.key});

  @override
  State<CollocationMagnetScreen> createState() =>
      _CollocationMagnetScreenState();
}

class _CollocationMagnetScreenState extends State<CollocationMagnetScreen>
    with TickerProviderStateMixin {
  final FocusNode _focusNode = FocusNode();

  // --- Game State ---
  int _currentLevelIndex = 0;
  int _score = 0;
  int _streak = 0;
  int _maxStreak = 0;
  int _lives = 3;
  int _correctCount = 0;
  final int _levelTargetCount = 10;
  bool _isGameOver = false;
  bool _isPaused = false;
  bool _isAttracting = false;
  bool _isLevelUpBanner = false;

  final List<GameReviewItem> _sessionReviewItems = [];
  int _highScore = 0;
  bool _isNewHighScore = false;

  bool _hasSwipedOnce = false;
  int _answeredCount = 0;
  bool get _showSwipeHint => !_hasSwipedOnce && _answeredCount < 6;

  late CollocationPair _currentPair;
  CollocationItem? _currentItem;
  final List<CollocationItem> _missedItems = [];

  double _dragOffset = 0.0;
  double _dragPercent = 0.0;

  String? _feedbackText;
  Color _feedbackColor = const Color(0xFF10B981);
  double _feedbackOpacity = 0.0;

  late AnimationController _timerController;
  late AnimationController _pulseController;
  late AnimationController _hintController;
  late AnimationController _attractController;
  late AnimationController _streakAnimController;
  late Animation<double> _attractSlideAnim;
  late Animation<double> _attractScaleAnim;

  // Solid Tactile Level Palettes (no neon glow)
  final List<List<Color>> _levelPalette = const [
    [Color(0xFF0284C7), Color(0xFFE11D48)], // Sky / Rose (Make vs Do)
    [Color(0xFF059669), Color(0xFFD97706)], // Emerald / Amber (Say vs Tell)
    [Color(0xFF2563EB), Color(0xFFDB2777)], // Blue / Pink (Take vs Have)
    [Color(0xFF7C3AED), Color(0xFFCA8A04)], // Violet / Gold (Give vs Get)
    [Color(0xFF0D9488), Color(0xFFEA580C)], // Teal / Orange (Pay vs Keep)
  ];

  Color get _leftColor =>
      _levelPalette[_currentLevelIndex % _levelPalette.length][0];
  Color get _rightColor =>
      _levelPalette[_currentLevelIndex % _levelPalette.length][1];

  static Color _darken(Color c, [double amount = 0.18]) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }

  @override
  void initState() {
    super.initState();
    _highScore = ScoreService.instance.getHighScore('collocation_magnet');

    _timerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _handleTimeout();
        }
      });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _hintController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _streakAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      lowerBound: 0.85,
      upperBound: 1.2,
    );

    _attractController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );

    _attractSlideAnim = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(parent: _attractController, curve: Curves.easeInQuad),
    );
    _attractScaleAnim = Tween<double>(begin: 1.0, end: 0.2).animate(
      CurvedAnimation(parent: _attractController, curve: Curves.easeInQuad),
    );

    _initGameState(startTimer: false);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _focusNode.requestFocus();
      await GameTutorialPopup.show(
        context,
        tutorialKey: 'collocation_magnet_tutorial',
        title: 'Collocation Magnet',
        icon: FontAwesomeIcons.magnet,
        color: const Color(0xFF0284C7),
        tutorialTextTr:
            'Collocation Magnet oyununda ortadaki kartta verilen boşluğu ("___ a decision") doğru fiil ile tamamlayın!\n\n'
            '• 👈 Kartı sola kaydırarak soldaki fiili, 👉 sağa kaydırarak sağdaki fiili seçin.\n'
            '• Kartı sürüklerken seçtiğiniz fiil boşluğa yerleşerek önizleme sağlar.\n'
            '• Dilerseniz yan/alt renkli kutulara dokunabilir ya da klavyeden A / D (Sol / Sağ Ok) tuşlarını kullanabilirsiniz.\n'
            '• Süre dolmadan doğru cevap vererek kombo yapın, serinizi yükseltin ve seviyeleri geçin!',
        tutorialTextEn:
            'The card has a blank: "___ a decision".\n'
            'Which verb fits? MAKE or DO?\n\n'
            '👉 SWIPE the card towards the correct verb:\n'
            '   ⬅ left = left verb,  right ➡ = right verb.\n'
            '   The verb previews in the blank while you drag.\n'
            '• Or tap the colored verb buttons.\n'
            '• Keyboard: A / ← left, D / → right.\n\n'
            'Answer before time runs out to build combos and level up!',
      );
      if (mounted && !_isGameOver) {
        _timerController.forward(from: 0.0);
      }
    });
  }

  @override
  void dispose() {
    TtsService.instance.stop();
    _timerController.dispose();
    _pulseController.dispose();
    _hintController.dispose();
    _attractController.dispose();
    _streakAnimController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _initGameState({bool startTimer = true}) {
    _currentLevelIndex = 0;
    _score = 0;
    _streak = 0;
    _maxStreak = 0;
    _lives = 3;
    _correctCount = 0;
    _isGameOver = false;
    _isNewHighScore = false;
    _sessionReviewItems.clear();
    _isPaused = false;
    _isAttracting = false;
    _dragOffset = 0.0;
    _dragPercent = 0.0;
    _missedItems.clear();
    _currentPair = CollocationData.pairs[_currentLevelIndex];
    _pickNextItem(startTimer: startTimer);
  }

  void _startNewGame() {
    setState(() {
      _initGameState(startTimer: true);
    });
  }

  void _pickNextItem({bool startTimer = true}) {
    final random = Random();
    final items = _currentPair.items;
    CollocationItem next = items[random.nextInt(items.length)];
    final prev = _currentItem;
    if (prev != null && items.length > 1 && prev == next) {
      final int currIdx = items.indexOf(next);
      next = items[(currIdx + 1) % items.length];
    }
    _currentItem = next;
    _dragOffset = 0.0;
    _dragPercent = 0.0;
    _isAttracting = false;

    final int baseMillis = max(
      3800,
      6200 - (_currentLevelIndex * 240) - min(700, _streak * 30),
    );
    _timerController.duration = Duration(milliseconds: baseMillis);
    if (startTimer) {
      _timerController.forward(from: 0.0);
    }
  }

  void _handleChoice(bool chosenLeft) {
    final current = _currentItem;
    if (current == null || _isAttracting || _isGameOver || _isPaused) return;

    _timerController.stop();
    _answeredCount += 1;
    final bool isCorrect = (chosenLeft == current.isLeft);

    final double targetSlide = chosenLeft ? -320.0 : 320.0;
    _attractSlideAnim =
        Tween<double>(begin: _dragOffset, end: targetSlide).animate(
      CurvedAnimation(parent: _attractController, curve: Curves.easeInCubic),
    );

    setState(() {
      _isAttracting = true;
    });

    _attractController.forward(from: 0.0).then((_) {
      if (!mounted) return;
      if (isCorrect) {
        _onCorrectAnswer();
      } else {
        _onWrongAnswer(chosenLeft: chosenLeft, isTimeout: false);
      }
    });
  }

  void _handleTimeout() {
    if (_isAttracting || _isGameOver || _isPaused) return;
    _timerController.stop();
    _onWrongAnswer(chosenLeft: null, isTimeout: true);
  }

  void _onCorrectAnswer() {
    AudioService.playCorrect();

    final current = _currentItem;
    if (current != null) {
      final String correctVerb =
          current.isLeft ? _currentPair.leftVerb : _currentPair.rightVerb;
      TtsService.instance.speak('$correctVerb ${current.phrase}');
    }

    final double timeLeftFraction = 1.0 - _timerController.value;
    final int speedBonus = (timeLeftFraction * 60).round();
    final double multiplier = _streak >= 12
        ? 3.0
        : _streak >= 7
            ? 2.0
            : _streak >= 3
                ? 1.5
                : 1.0;
    final int pointsEarned = ((100 + speedBonus) * multiplier).round();

    _streakAnimController.forward(from: 0.85).then((_) {
      if (mounted) _streakAnimController.reverse();
    });

    setState(() {
      _score += pointsEarned;
      _streak += 1;
      if (_streak > _maxStreak) _maxStreak = _streak;
      _correctCount += 1;
      _showFeedback(
        multiplier > 1.0
            ? '+$pointsEarned (x$multiplier)!'
            : '+$pointsEarned!',
        const Color(0xFF10B981),
      );
    });

    if (current != null) {
      final String correctVerb =
          current.isLeft ? _currentPair.leftVerb : _currentPair.rightVerb;
      _sessionReviewItems.add(
        GameReviewItem(
          id: '${correctVerb}_${current.phrase}_${DateTime.now().millisecondsSinceEpoch}',
          word: '$correctVerb ${current.phrase}',
          meaning: current.turkishMeaning,
          question: '___ ${current.phrase}',
          userAnswer: correctVerb,
          correctAnswer: correctVerb,
          isCorrect: true,
        ),
      );
    }

    if (_correctCount >= _levelTargetCount &&
        _currentLevelIndex < CollocationData.pairs.length - 1) {
      _advanceLevel();
    } else {
      Future.delayed(const Duration(milliseconds: 80), () {
        if (mounted && !_isGameOver) {
          setState(() {
            _pickNextItem();
          });
        }
      });
    }
  }

  void _advanceLevel() {
    AudioService.playSuccess();
    setState(() {
      _currentLevelIndex += 1;
      _correctCount = 0;
      _currentPair = CollocationData.pairs[_currentLevelIndex];
      _isLevelUpBanner = true;
    });

    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() {
          _isLevelUpBanner = false;
          _pickNextItem();
        });
      }
    });
  }

  void _onWrongAnswer({bool? chosenLeft, required bool isTimeout}) {
    final current = _currentItem;
    if (current == null) return;

    AudioService.playIncorrect();

    if (!_missedItems.contains(current)) {
      _missedItems.add(current);
    }

    final String correctVerb =
        current.isLeft ? _currentPair.leftVerb : _currentPair.rightVerb;
    final String wrongVerb =
        current.isLeft ? _currentPair.rightVerb : _currentPair.leftVerb;
    TtsService.instance.speak('$correctVerb ${current.phrase}');

    _sessionReviewItems.add(
      GameReviewItem(
        id: '${correctVerb}_${current.phrase}_${DateTime.now().millisecondsSinceEpoch}',
        word: '$correctVerb ${current.phrase}',
        meaning: current.turkishMeaning,
        question: '___ ${current.phrase}',
        userAnswer: isTimeout ? 'Süre Bitti' : '$wrongVerb ${current.phrase}',
        correctAnswer: '$correctVerb ${current.phrase}',
        isCorrect: false,
      ),
    );

    MistakeService.instance.recordMistake(
      word: '$correctVerb ${current.phrase}',
      meaning: current.turkishMeaning,
      sourceGame: 'Collocation Magnet',
      wrongAnswer: isTimeout ? 'Süre Bitti' : '$wrongVerb ${current.phrase}',
    );

    setState(() {
      _lives -= 1;
      _streak = 0;
      _showFeedback(
        isTimeout
            ? 'SÜRE BİTTİ! ➜ $correctVerb ${current.phrase}'
            : 'YANLIŞ! ➜ $correctVerb ${current.phrase}',
        const Color(0xFFEF4444),
      );
    });

    if (_lives <= 0) {
      _triggerGameOver();
    } else {
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted && !_isGameOver) {
          setState(() {
            _pickNextItem();
          });
        }
      });
    }
  }

  void _triggerGameOver() {
    AudioService.playFailure();
    setState(() {
      _isGameOver = true;
    });
    ScoreService.instance
        .recordScore(
      gameId: 'collocation_magnet',
      score: _score,
      streak: _maxStreak,
    )
        .then((res) {
      if (mounted) {
        setState(() {
          _highScore = res.highScore;
          _isNewHighScore = res.isNewHighScore;
        });
      }
    });
  }

  void _showFeedback(String text, Color color) {
    setState(() {
      _feedbackText = text;
      _feedbackColor = color;
      _feedbackOpacity = 1.0;
    });

    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) {
        setState(() {
          _feedbackOpacity = 0.0;
        });
      }
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (_isGameOver) {
      if (event.logicalKey == LogicalKeyboardKey.space ||
          event.logicalKey == LogicalKeyboardKey.enter) {
        _startNewGame();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.keyA) {
      _handleChoice(true);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        event.logicalKey == LogicalKeyboardKey.keyD) {
      _handleChoice(false);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.space) {
      setState(() {
        _isPaused = !_isPaused;
        if (_isPaused) {
          _timerController.stop();
        } else {
          _timerController.forward();
        }
      });
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  Future<void> _handleExit() async {
    final wasAnimating = _timerController.isAnimating;
    _timerController.stop();
    final shouldPop = await showExitConfirmationDialog(context);
    if (shouldPop && mounted) {
      Navigator.of(context).pop();
    } else if (wasAnimating && mounted && !_isGameOver && !_isPaused) {
      _timerController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 840;
    final isCompact = screenWidth < 380;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleExit();
      },
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: Scaffold(
          backgroundColor:
              isDark ? const Color(0xFF0D0D14) : const Color(0xFFF1F5F9),
          appBar: _buildAppBar(isDark),
          body: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isDesktop ? 1040 : 640,
                    ),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompact ? 12 : (isDesktop ? 28 : 18),
                        vertical: isDesktop ? 16 : 8,
                      ),
                      child: isDesktop
                          ? _buildDesktopLayout(isDark)
                          : _buildMobileLayout(isDark, isCompact),
                    ),
                  ),
                ),

                if (_isGameOver) _buildGameOverOverlay(isDark),
                if (_isPaused && !_isGameOver) _buildPauseOverlay(isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(isDark, isDesktop: true),
        const SizedBox(height: 12),
        _buildTimerBar(isDark),
        const SizedBox(height: 20),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Desktop Magnet Pole Panel
              SizedBox(
                width: 230,
                child: _buildDesktopSidePole(
                  verb: _currentPair.leftVerb,
                  poleName: 'SOL KUTUP',
                  keyHint: 'A / ←',
                  color: _leftColor,
                  isLeft: true,
                  isDark: isDark,
                  isAttracted: _dragPercent < -0.15,
                  onTap: () => _handleChoice(true),
                ),
              ),
              const SizedBox(width: 20),

              // Center Arena
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF151520)
                        : const Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF28283E)
                          : const Color(0xFFE2E8F0),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isLevelUpBanner)
                        _buildLevelUpBanner(isDark)
                      else ...[
                        _buildInteractiveCard(isDark),
                        const SizedBox(height: 16),
                        _buildFeedbackBanner(),
                        const SizedBox(height: 12),
                        _buildSwipeHint(isDark),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),

              // Right Desktop Magnet Pole Panel
              SizedBox(
                width: 230,
                child: _buildDesktopSidePole(
                  verb: _currentPair.rightVerb,
                  poleName: 'SAĞ KUTUP',
                  keyHint: 'D / →',
                  color: _rightColor,
                  isLeft: false,
                  isDark: isDark,
                  isAttracted: _dragPercent > 0.15,
                  onTap: () => _handleChoice(false),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildLevelProgressStrip(isDark),
      ],
    );
  }

  Widget _buildMobileLayout(bool isDark, bool isCompact) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(isDark, isDesktop: false),
        const SizedBox(height: 10),
        _buildTimerBar(isDark),
        const SizedBox(height: 14),
        _buildMagneticPoles(isDark),
        const SizedBox(height: 16),
        if (_isLevelUpBanner)
          _buildLevelUpBanner(isDark)
        else ...[
          _buildInteractiveCard(isDark),
          const SizedBox(height: 12),
          _buildFeedbackBanner(),
          if (_showSwipeHint) ...[
            const SizedBox(height: 8),
            _buildSwipeHint(isDark),
          ],
        ],
        const SizedBox(height: 14),
        _buildBottomControls(isDark),
        const SizedBox(height: 12),
        _buildLevelProgressStrip(isDark),
      ],
    );
  }

  Widget _buildDesktopSidePole({
    required String verb,
    required String poleName,
    required String keyHint,
    required Color color,
    required bool isLeft,
    required bool isDark,
    required bool isAttracted,
    required VoidCallback onTap,
  }) {
    final lipColor = _darken(color, 0.22);
    final recentForSide = _sessionReviewItems
        .where((item) => item.isCorrect && item.correctAnswer == verb)
        .toList()
        .reversed
        .take(4)
        .toList();

    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isAttracted
                ? color.withValues(alpha: isDark ? 0.22 : 0.12)
                : (isDark ? const Color(0xFF161622) : Colors.white),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isAttracted ? color : color.withValues(alpha: 0.55),
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isAttracted
                    ? lipColor
                    : (isDark
                        ? const Color(0xFF07070B)
                        : Colors.black.withValues(alpha: 0.08)),
                offset: const Offset(0, 5),
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isLeft) ...[
                          Icon(
                            Icons.arrow_back_rounded,
                            color: color,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          poleName,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            color: color,
                          ),
                        ),
                        if (!isLeft) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: color,
                            size: 14,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: lipColor,
                          offset: const Offset(0, 4),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      FontAwesomeIcons.magnet,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    verb,
                    style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF222234)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Tuş: $keyHint',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (recentForSide.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Divider(
                      color: isDark ? Colors.white12 : Colors.black12,
                      height: 16,
                    ),
                    Text(
                      'EŞLEŞENLER',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: isDark ? Colors.white38 : Colors.black45,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (final item in recentForSide)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item.word,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: lipColor,
                      offset: const Offset(0, 4),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Text(
                  '$verb SEÇ',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLevelProgressStrip(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161622) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF28283E) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.flag_rounded, size: 16, color: _leftColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Seviye İlerlemesi (${_currentPair.leftVerb} vs ${_currentPair.rightVerb})',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
          Text(
            '$_correctCount / $_levelTargetCount',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: _leftColor,
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          color: isDark ? Colors.white : Colors.black87,
        ),
        onPressed: _handleExit,
      ),
      title: MarqueeTitle(
        title: 'Collocation Magnet',
        leadingIcon: Icon(FontAwesomeIcons.magnet, color: _leftColor, size: 20),
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.bold,
          fontSize: 20,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Nasıl Oynanır?',
          icon: Icon(
            Icons.help_outline_rounded,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
          onPressed: () {
            GameTutorialPopup.show(
              context,
              tutorialKey: 'collocation_magnet_tutorial',
              title: 'Collocation Magnet',
              icon: FontAwesomeIcons.magnet,
              color: _leftColor,
              tutorialTextTr:
                  'Collocation Magnet oyununda ortadaki kartta verilen boşluğu ("___ a decision") doğru fiil ile tamamlayın!\n\n'
                  '• 👈 Kartı sola kaydırarak soldaki fiili, 👉 sağa kaydırarak sağdaki fiili seçin.\n'
                  '• Kartı sürüklerken seçtiğiniz fiil boşluğa yerleşerek önizleme sağlar.\n'
                  '• Dilerseniz yan/alt renkli butonlara dokunabilir ya da klavyeden A / D (Sol / Sağ Ok) tuşlarını kullanabilirsiniz.\n'
                  '• Süre dolmadan doğru cevap vererek kombo yapın, serinizi yükseltin ve seviyeleri geçin!',
              tutorialTextEn:
                  'The card has a blank: "___ the dishes".\n'
                  'Find the verb that fits and SWIPE the card towards that side (left or right).\n'
                  'The verb previews in the blank while dragging. You can also tap the verb buttons.',
            );
          },
        ),
      ],
    );
  }

  Widget _buildHeader(bool isDark, {required bool isDesktop}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161622) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF28283E) : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _leftColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt_rounded, color: Colors.white, size: 16),
                const SizedBox(width: 4),
                Text(
                  'LVL ${_currentLevelIndex + 1}',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'SKOR',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                    Text(
                      '$_score',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                if (isDesktop) ...[
                  const SizedBox(width: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF222234)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_currentPair.leftVerb} vs ${_currentPair.rightVerb} • ${_currentPair.themeName}',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_streak >= 2)
            ScaleTransition(
              scale: _streakAnimController,
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF97316),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '🔥 ${_streak}x',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (index) {
              final bool isAlive = index < _lives;
              return Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(
                  isAlive
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isAlive
                      ? const Color(0xFFEF4444)
                      : Colors.grey.withValues(alpha: 0.4),
                  size: 22,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerBar(bool isDark) {
    return AnimatedBuilder(
      animation: _timerController,
      builder: (context, child) {
        final double percent = (1.0 - _timerController.value).clamp(0.0, 1.0);
        final Color barColor = percent < 0.25
            ? const Color(0xFFEF4444)
            : percent < 0.55
                ? const Color(0xFFF59E0B)
                : const Color(0xFF10B981);

        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 8,
            color: isDark ? const Color(0xFF1E1E2E) : const Color(0xFFE2E8F0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: percent,
                child: Container(color: barColor),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMagneticPoles(bool isDark) {
    final double leftWeight = (0.5 - (_dragPercent * 0.25)).clamp(0.25, 0.75);
    final double rightWeight = 1.0 - leftWeight;

    return Row(
      children: [
        Expanded(
          flex: (leftWeight * 100).toInt(),
          child: _buildSinglePole(
            verb: _currentPair.leftVerb,
            poleName: 'SOLA KAYDIR',
            color: _leftColor,
            isLeft: true,
            isDark: isDark,
            isAttracted: _dragPercent < -0.15,
            onTap: () => _handleChoice(true),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: (rightWeight * 100).toInt(),
          child: _buildSinglePole(
            verb: _currentPair.rightVerb,
            poleName: 'SAĞA KAYDIR',
            color: _rightColor,
            isLeft: false,
            isDark: isDark,
            isAttracted: _dragPercent > 0.15,
            onTap: () => _handleChoice(false),
          ),
        ),
      ],
    );
  }

  Widget _buildSinglePole({
    required String verb,
    required String poleName,
    required Color color,
    required bool isLeft,
    required bool isDark,
    required bool isAttracted,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: isAttracted
              ? color.withValues(alpha: isDark ? 0.2 : 0.1)
              : (isDark ? const Color(0xFF161622) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isAttracted ? color : color.withValues(alpha: 0.45),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLeft) ...[
                  Icon(
                    Icons.keyboard_double_arrow_left_rounded,
                    color: color,
                    size: 15,
                  ),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    poleName,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: color,
                    ),
                  ),
                ),
                if (!isLeft) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_double_arrow_right_rounded,
                    color: color,
                    size: 15,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Text(
              verb,
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractiveCard(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxDrag = (constraints.maxWidth * 0.42).clamp(90.0, 220.0);

        return AnimatedBuilder(
          animation: Listenable.merge([_attractController, _hintController]),
          builder: (context, child) {
            double currentX = _dragOffset;
            double scale = 1.0;

            if (_isAttracting) {
              currentX = _attractSlideAnim.value;
              scale = _attractScaleAnim.value;
            } else if (_showSwipeHint &&
                _dragOffset == 0.0 &&
                !_isPaused &&
                !_isGameOver) {
              currentX = sin(_hintController.value * 2 * pi) * 14;
            }

            final double rotation = (currentX / maxDrag) * 0.1;

            return Transform.translate(
              offset: Offset(currentX, 0),
              child: Transform.rotate(
                angle: rotation,
                child: Transform.scale(
                  scale: scale,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      if (_isAttracting || _isGameOver || _isPaused) return;
                      setState(() {
                        _dragOffset += details.primaryDelta!;
                        _dragOffset = _dragOffset.clamp(-maxDrag, maxDrag);
                        _dragPercent = (_dragOffset / maxDrag).clamp(-1.0, 1.0);
                      });
                    },
                    onHorizontalDragEnd: (details) {
                      if (_isAttracting || _isGameOver || _isPaused) return;

                      final double velocity = details.primaryVelocity ?? 0.0;
                      if (_dragPercent < -0.35 || velocity < -500) {
                        _hasSwipedOnce = true;
                        _handleChoice(true);
                      } else if (_dragPercent > 0.35 || velocity > 500) {
                        _hasSwipedOnce = true;
                        _handleChoice(false);
                      } else {
                        setState(() {
                          _dragOffset = 0.0;
                          _dragPercent = 0.0;
                        });
                      }
                    },
                    child: _buildCardContent(isDark),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCardContent(bool isDark) {
    Color activeBorder =
        isDark ? const Color(0xFF2D2D44) : const Color(0xFFCBD5E1);
    if (_dragPercent < -0.15) {
      activeBorder = _leftColor;
    } else if (_dragPercent > 0.15) {
      activeBorder = _rightColor;
    }

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 460, minHeight: 190),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C2B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: activeBorder, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? const Color(0xFF09090F)
                : Colors.black.withValues(alpha: 0.08),
            offset: const Offset(0, 6),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.arrow_back_ios_rounded,
                    size: 13,
                    color: _leftColor,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    _currentPair.leftVerb,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: _leftColor,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF26263A)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'BOŞLUĞU TAMAMLA',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _currentPair.rightVerb,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: _rightColor,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: _rightColor,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 22),
          _buildBlankPhrase(isDark),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF141420)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _currentItem != null ? '🇹🇷 ${_currentItem!.turkishMeaning}' : '',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlankPhrase(bool isDark) {
    final double p = _isAttracting
        ? (_attractSlideAnim.value < 0 ? -1 : 1)
        : _dragPercent;
    final bool previewLeft = p < -0.15;
    final bool previewRight = p > 0.15;
    final String? previewVerb = previewLeft
        ? _currentPair.leftVerb.toLowerCase()
        : previewRight
            ? _currentPair.rightVerb.toLowerCase()
            : null;
    final Color previewColor = previewLeft ? _leftColor : _rightColor;
    final Color baseColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 6,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minWidth: 74),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: previewVerb != null
                ? previewColor
                : (isDark
                    ? const Color(0xFF26263A)
                    : const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            previewVerb ?? '___',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: previewVerb != null
                  ? Colors.white
                  : baseColor.withValues(alpha: 0.5),
              height: 1.2,
            ),
          ),
        ),
        Text(
          _currentItem?.phrase ?? '',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: baseColor,
            height: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildSwipeHint(bool isDark) {
    final Color textColor = isDark ? Colors.white60 : Colors.black54;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.swipe_rounded, color: textColor, size: 18),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            'Kartı doğru fiile kaydırın veya kutulara dokunun',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLevelUpBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C2B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _leftColor, width: 2.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.stars_rounded, color: Color(0xFFF59E0B), size: 48),
          const SizedBox(height: 12),
          Text(
            'SEVİYE ATLADIN!',
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_currentPair.leftVerb} vs ${_currentPair.rightVerb}',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _leftColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _currentPair.themeName,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackBanner() {
    if (_feedbackOpacity == 0.0 || (_feedbackText ?? '').isEmpty) {
      return const SizedBox(height: 36);
    }
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _feedbackOpacity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: _feedbackColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _feedbackColor, width: 1.5),
        ),
        child: Text(
          _feedbackText ?? '',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: _feedbackColor,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildMagnetActionButton(
            verb: _currentPair.leftVerb,
            color: _leftColor,
            isLeft: true,
            keyHint: 'A / ←',
            onTap: () => _handleChoice(true),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _buildMagnetActionButton(
            verb: _currentPair.rightVerb,
            color: _rightColor,
            isLeft: false,
            keyHint: 'D / →',
            onTap: () => _handleChoice(false),
          ),
        ),
      ],
    );
  }

  Widget _buildMagnetActionButton({
    required String verb,
    required Color color,
    required bool isLeft,
    required String keyHint,
    required VoidCallback onTap,
  }) {
    final lip = _darken(color, 0.22);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: lip,
              offset: const Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLeft) ...[
              const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    verb,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '[$keyHint]',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            if (!isLeft) ...[
              const SizedBox(width: 6),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 20,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGameOverOverlay(bool isDark) {
    return Container(
      color: Colors.black.withValues(alpha: 0.75),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Container(
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161622) : Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: const Color(0xFFEF4444).withValues(alpha: 0.6),
              width: 2,
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.battery_alert_rounded,
                    color: Color(0xFFEF4444),
                    size: 44,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'MANYETİK YÜK TÜKENDİ!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                if (_isNewHighScore) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.emoji_events_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'YENİ EN YÜKSEK SKOR!',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E1E2E)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatTile('SCORE', '$_score', Colors.amber),
                      _buildStatTile('BEST', '$_highScore', Colors.orange),
                      _buildStatTile('STREAK', '$_maxStreak', _leftColor),
                      _buildStatTile(
                        'LEVEL',
                        '${_currentLevelIndex + 1}',
                        const Color(0xFF8B5CF6),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_sessionReviewItems.isNotEmpty) ...[
                  GameReviewAccordion(
                    items: _sessionReviewItems,
                    accentColor: _leftColor,
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Ana Menü',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _startNewGame,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _leftColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          'Yeniden Oyna',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatTile(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildPauseOverlay(bool isDark) {
    return Container(
      color: Colors.black.withValues(alpha: 0.65),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161622) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark ? const Color(0xFF28283E) : const Color(0xFFE2E8F0),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.pause_circle_filled_rounded,
              size: 54,
              color: Color(0xFFF59E0B),
            ),
            const SizedBox(height: 12),
            Text(
              'OYUN DURAKLATILDI',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isPaused = false;
                  _timerController.forward();
                });
              },
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Devam Et'),
            ),
          ],
        ),
      ),
    );
  }
}
