import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/arcade/arcade_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/audio_service.dart';
import '../services/tts_service.dart';
import '../widgets/game_tutorial_popup.dart';
import '../widgets/exit_confirmation_dialog.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../data/category_trap_data.dart';
import '../services/level_service.dart';
import '../widgets/level_selection_dialog.dart';
import '../widgets/marquee_title.dart';
import '../services/mistake_service.dart';
import '../services/score_service.dart';
import '../models/game_review_item.dart';
import '../widgets/game_review_accordion.dart';

class TrapMistake {
  final String word;
  final String displayedCategory;
  final String actualCategory;
  final bool wasInCategory;
  final bool isTimeout;

  const TrapMistake({
    required this.word,
    required this.displayedCategory,
    required this.actualCategory,
    required this.wasInCategory,
    required this.isTimeout,
  });
}

class CategoryTrapScreen extends StatefulWidget {
  const CategoryTrapScreen({super.key});

  @override
  State<CategoryTrapScreen> createState() => _CategoryTrapScreenState();
}

class _CategoryTrapScreenState extends State<CategoryTrapScreen>
    with TickerProviderStateMixin {
  late final FocusNode _keyboardFocusNode;
  // --- Data Structure ---
  final Map<String, List<String>> _categories = categoryTrapCategories;
  GameDifficulty _difficulty = LevelService.instance.currentDifficulty;

  Map<String, List<String>> get _filteredCategories {
    if (_difficulty == GameDifficulty.all) return _categories;
    final map = <String, List<String>>{};
    for (final entry in _categories.entries) {
      final list =
          LevelService.instance.filterWordList(entry.value, _difficulty);
      if (list.isNotEmpty) {
        map[entry.key] = list;
      }
    }
    return map.isNotEmpty ? map : _categories;
  }

  void _updateDifficulty(GameDifficulty newDiff) {
    setState(() {
      _difficulty = newDiff;
      LevelService.instance.setDifficulty(newDiff);
      _startGame();
    });
  }

  // --- Game State ---
  late String _currentCategory;
  late String _currentWord;
  bool _isWordInCategory = false;
  int _score = 0;
  int _highScore = 0;
  bool _isNewHighScore = false;
  int _lives = 3;
  final int _maxLives = 3;
  int _streak = 0;
  int _bestStreak = 0;
  bool _isGameOver = false;
  bool _isTransitioning = false;
  double _timeLeftPercent = 1.0;
  String? _lastWord;

  // Educational Feedback state
  bool _isShowingFeedback = false;
  String? _feedbackExplanation;
  final List<TrapMistake> _trappedMistakes = [];
  final List<GameReviewItem> _sessionReviewItems = [];

  late AnimationController _timerController;
  late AnimationController _feedbackController;
  late AnimationController _correctAnimController;
  late AnimationController _shakeController;
  late AnimationController _swayController;
  late Animation<Color?> _feedbackColorAnimation;
  late Animation<double> _correctScaleAnimation;
  late Animation<double> _correctOpacityAnimation;

  @override
  void initState() {
    super.initState();
    _highScore = ScoreService.instance.getHighScore('category_trap');
    _timerController =
        AnimationController(vsync: this, duration: const Duration(seconds: 4))
          ..addListener(() {
            setState(() => _timeLeftPercent = 1.0 - _timerController.value);
          })
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              _handleAnswer(null); // Time's up -> Treat as wrong/timeout
            }
          });

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    _swayController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    _feedbackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _feedbackColorAnimation = ColorTween(
      begin: Colors.transparent,
      end: Colors.transparent,
    ).animate(_feedbackController);

    _correctAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _correctScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.1,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.1,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_correctAnimController);

    _correctOpacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_correctAnimController);

    _startGame();
    _timerController.stop(); // Stop the initial timer until tutorial is gone
    _keyboardFocusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _keyboardFocusNode.requestFocus();
      final result = await GameTutorialPopup.show(
        context,
        tutorialKey: 'category_trap_tutorial',
        title: "Category Trap",
        icon: FontAwesomeIcons.layerGroup,
        color: const Color(0xFF3B82F6),
        tutorialTextTr:
            'Category Trap oyununda kapana yakalanmadan hızlıca karar verin!\n\n'
            '• Üst paneldeki kategoriye bakın ve ortadaki İngilizce kelimenin bu kategoriye ait olup olmadığını belirleyin.\n'
            '• Kelime kategoriye aitse YES (Sağ Ok / D), ait değilse NO (Sol Ok / A) butonuna basın.\n'
            '• Her soru için süreniz kısıtlıdır. Yanlış cevap verdiğinizde veya süreniz bittiğinde kelimenin gerçek kategorisi gösterilir.\n'
            '• Toplam 3 canınız vardır; doğru cevaplarla serinizi uzatarak yüksek skor elde edin!',
        tutorialTextEn: "In Category Trap, a category and an English word are shown. Decide if the word belongs to the category! You have 3 lives. When you answer wrongly or run out of time, you can see the actual category of the word.",
        includeLevelSelection: true,
        initialDifficulty: _difficulty,
      );
      if (mounted) {
        if (result.difficulty != null) {
          _updateDifficulty(result.difficulty!);
        } else {
          _timerController.forward();
          TtsService.instance.speak(_currentWord);
        }
      }
    });
  }

  void _startGame() {
    final random = Random();
    final pool = _filteredCategories;
    final catKeys = pool.keys.toList();
    _currentCategory = catKeys[random.nextInt(catKeys.length)];
    _score = 0;
    _lives = _maxLives;
    _streak = 0;
    _bestStreak = 0;
    _isGameOver = false;
    _isNewHighScore = false;
    _isTransitioning = false;
    _isShowingFeedback = false;
    _feedbackExplanation = null;
    _trappedMistakes.clear();
    _sessionReviewItems.clear();
    _generateNextWord();
  }

  String _findActualCategory(String word) {
    for (final entry in _categories.entries) {
      if (entry.value.contains(word)) return entry.key;
    }
    return 'Diğer';
  }

  void _generateNextWord() {
    final random = Random();
    final pool = _filteredCategories;

    // 50% chance for a correct word from current category
    // 50% chance for a distractor from other categories
    _isWordInCategory = random.nextBool();

    if (_isWordInCategory) {
      final list = pool[_currentCategory] ?? _categories[_currentCategory]!;
      String word = list[random.nextInt(list.length)];
      // Prevent immediate repetition
      int attempts = 0;
      while (word == _lastWord && attempts < 10) {
        word = list[random.nextInt(list.length)];
        attempts++;
      }
      _currentWord = word;
    } else {
      final otherCats = pool.keys
          .where((k) => k != _currentCategory)
          .toList();
      final randomCat = otherCats.isNotEmpty
          ? otherCats[random.nextInt(otherCats.length)]
          : _currentCategory;
      final list = pool[randomCat] ?? _categories[randomCat]!;
      String word = list[random.nextInt(list.length)];
      int attempts = 0;
      while (word == _lastWord && attempts < 10) {
        word = list[random.nextInt(list.length)];
        attempts++;
      }
      _currentWord = word;
    }

    _lastWord = _currentWord;
    _isTransitioning = false;
    _isShowingFeedback = false;
    _feedbackExplanation = null;

    // Speed up logic: start at 4.5s, minimum 2.8s for humane cognitive processing
    double baseSeconds = 4.5 - (_score / 35.0);
    _timerController.duration = Duration(
      milliseconds: (max(2.8, baseSeconds) * 1000).toInt(),
    );

    _timerController.stop();
    _timerController.reset();
    _timerController.forward();
    TtsService.instance.speak(_currentWord);
  }

  void _handleAnswer(bool? userGuess) {
    if (_isGameOver || _isTransitioning || _isShowingFeedback) return;

    _timerController.stop();
    _isTransitioning = true;

    final bool isCorrect = (userGuess == _isWordInCategory);

    if (isCorrect) {
      AudioService.playCorrect();
      HapticFeedback.lightImpact();

      final actualCategory = _findActualCategory(_currentWord);
      _sessionReviewItems.add(GameReviewItem(
        word: _currentWord,
        meaning: 'Kategori: $actualCategory',
        question: '$_currentWord ∈ $_currentCategory (${_isWordInCategory ? "Bu Kategoride" : "Farklı Kategori"})',
        userAnswer: userGuess == true ? 'Bu Kategoride' : 'Farklı Kategori',
        correctAnswer: _isWordInCategory ? 'Bu Kategoride' : 'Farklı Kategori',
        isCorrect: true,
      ));

      setState(() {
        _score++;
        _streak++;
        if (_streak > _bestStreak) _bestStreak = _streak;

        // Trigger floating text animation
        _correctAnimController.forward(from: 0);

        // Change category every 5 points
        if (_score > 0 && _score % 5 == 0) {
          final random = Random();
          final otherCats = _categories.keys
              .where((k) => k != _currentCategory)
              .toList();
          _currentCategory = otherCats[random.nextInt(otherCats.length)];
        }
      });
      Timer(const Duration(milliseconds: 200), () {
        if (mounted) setState(() => _generateNextWord());
      });
    } else {
      AudioService.playIncorrect();
      HapticFeedback.heavyImpact();
      _shakeController.forward(from: 0);
      _triggerFeedback(Colors.redAccent.withValues(alpha: 0.3));

      final actualCategory = _findActualCategory(_currentWord);
      final mistake = TrapMistake(
        word: _currentWord,
        displayedCategory: _currentCategory,
        actualCategory: actualCategory,
        wasInCategory: _isWordInCategory,
        isTimeout: userGuess == null,
      );
      if (!_trappedMistakes.any((m) => m.word == _currentWord)) {
        _trappedMistakes.add(mistake);
      }

      MistakeService.instance.recordMistake(
        word: _currentWord,
        meaning: 'Kategori: $actualCategory',
        sourceGame: 'Category Trap',
        wrongAnswer: userGuess == null
            ? 'Süre Bitti'
            : (userGuess ? 'Tuzak: $_currentCategory' : 'Reddedildi'),
      );

      _sessionReviewItems.add(GameReviewItem(
        word: _currentWord,
        meaning: 'Doğru Kategori: $actualCategory',
        question: '$_currentWord ∈ $_currentCategory (${_isWordInCategory ? "Bu Kategoride" : "Farklı Kategori"})',
        userAnswer: userGuess == null
            ? 'Süre Bitti'
            : (userGuess ? 'Bu Kategoride' : 'Farklı Kategori'),
        correctAnswer: _isWordInCategory ? 'Bu Kategoride' : 'Farklı Kategori',
        isCorrect: false,
        note: 'Doğru Kategori: $actualCategory',
      ));

      String explanation;
      if (userGuess == null) {
        explanation = '⏳ SÜRE BİTTİ!\n"$_currentWord" kelimesi [$actualCategory] kategorisine aittir.';
      } else if (userGuess == true) {
        explanation = '🪤 KAPANA YAKALANDIN!\n"$_currentWord" [$_currentCategory] değil, [$actualCategory] kategorisindedir!';
      } else {
        explanation = '❌ YANLIŞ!\n"$_currentWord" zaten [$_currentCategory] kategorisine aittir!';
      }

      setState(() {
        _lives--;
        _streak = 0;
        _isShowingFeedback = true;
        _feedbackExplanation = explanation;
      });

      // Show educational feedback card for 1.8 seconds before continuing or game over
      Future.delayed(const Duration(milliseconds: 1800), () {
        if (!mounted) return;
        if (_lives <= 0) {
          _endGame();
        } else {
          setState(() {
            _generateNextWord();
          });
        }
      });
    }
  }

  void _triggerFeedback(Color color) {
    _feedbackColorAnimation = ColorTween(begin: color, end: Colors.transparent)
        .animate(
          CurvedAnimation(parent: _feedbackController, curve: Curves.easeOut),
        );
    _feedbackController.forward(from: 0);
  }

  void _endGame() async {
    final res = await ScoreService.instance.recordScore(
      gameId: 'category_trap',
      score: _score,
      streak: _bestStreak,
    );
    if (mounted) {
      setState(() {
        _highScore = res.highScore;
        _isNewHighScore = res.isNewHighScore;
        _isGameOver = true;
      });
    }
  }

  @override
  void dispose() {
    TtsService.instance.stop();
    _timerController.dispose();
    _feedbackController.dispose();
    _correctAnimController.dispose();
    _shakeController.dispose();
    _swayController.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (_isGameOver || _isTransitioning) return KeyEventResult.ignored;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyN) {
      _handleAnswer(false);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.keyY) {
      _handleAnswer(true);
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
    } else if (wasAnimating && mounted && !_isGameOver) {
      _timerController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgDark = Color(0xFF07120B);
    const surfaceDark = Color(0xFF0F1E14);
    const hazardAmber = Color(0xFFF59E0B);
    const yesGreen = Color(0xFF10B981);
    const noRed = Color(0xFFEF4444);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleExit();
      },
      child: Focus(
        focusNode: _keyboardFocusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: Scaffold(
          backgroundColor: bgDark,
          appBar: _buildAppBar(hazardAmber),
        body: SafeArea(
          child: Stack(
            children: [
              // Cage bars & hazard background painter
              Positioned.fill(
                child: CustomPaint(
                  painter: _CageTrapPainter(
                    accent: hazardAmber,
                  ),
                ),
              ),

              // Feedback flash layer
              AnimatedBuilder(
                animation: _feedbackColorAnimation,
                builder: (context, child) => Container(
                  color: _feedbackColorAnimation.value,
                ),
              ),

              // Main game area with shake effect
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 580),
                  child: AnimatedBuilder(
                    animation: _shakeController,
                    builder: (context, child) {
                      final double dx = _shakeController.value > 0
                          ? sin(_shakeController.value * 4 * pi) *
                              8 *
                              (1.0 - _shakeController.value)
                          : 0.0;
                      return Transform.translate(
                        offset: Offset(dx, 0),
                        child: child,
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20.0,
                        vertical: 10.0,
                      ),
                      child: Column(
                        children: [
                          // Top Arcade HUD
                          ArcadeHud(
                            accent: hazardAmber,
                            surface: surfaceDark,
                            score: _score,
                            streak: _streak,
                            lives: _isGameOver ? 0 : _lives,
                            maxLives: _maxLives,
                            badge: ArcadeBadge(
                              icon: FontAwesomeIcons.layerGroup,
                              text: _currentCategory.toUpperCase(),
                              color: hazardAmber,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Trap timer bar
                          GlowTimerBar(
                            percent: _timeLeftPercent,
                            height: 6,
                            label: 'TRAP TIMER',
                            labelColor: hazardAmber,
                          ),
                          const Spacer(),

                          // Suspended Category Sign (Cage zone)
                          _buildCategoryZoneHeader(surfaceDark, hazardAmber),
                          const SizedBox(height: 18),

                          // Word Bait Card
                          _buildBaitCard(surfaceDark, hazardAmber),
                          const Spacer(),

                          // Decision Controls (NO vs YES)
                          _buildControls(noRed, yesGreen),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Floating feedback text ("CORRECT!")
              _buildFloatingFeedback(),

              // Game Over Modal
              if (_isGameOver) _buildGameOverOverlay(surfaceDark, hazardAmber),
            ],
          ),
        ),
      ),
    ),
  );
  }

  PreferredSizeWidget _buildAppBar(Color accent) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Colors.white70,
          size: 20,
        ),
        onPressed: _handleExit,
      ),
      title: MarqueeTitle(
        title: 'Category Trap',
        leadingIcon: Icon(FontAwesomeIcons.skullCrossbones, color: accent, size: 18),
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.bold,
          fontSize: 20,
          color: Colors.white,
        ),
      ),
      actions: [
        LevelBadgeButton(
          difficulty: _difficulty,
          accentColor: accent,
          onTap: () async {
            final wasAnimating = _timerController.isAnimating;
            _timerController.stop();
            final chosen = await LevelSelectionDialog.show(
              context,
              initialDifficulty: _difficulty,
              accentColor: accent,
              title: 'Category Trap: Seviye Değiştir',
            );
            if (chosen != null && mounted) {
              _updateDifficulty(chosen);
            } else if (wasAnimating && mounted && !_isGameOver) {
              _timerController.forward();
            }
          },
        ),
        IconButton(
          tooltip: 'Nasıl Oynanır?',
          icon: const Icon(Icons.help_outline_rounded, color: Colors.white70),
          onPressed: () {
            GameTutorialPopup.show(
              context,
              tutorialKey: 'category_trap_tutorial',
              title: 'Category Trap',
              icon: FontAwesomeIcons.skullCrossbones,
              color: accent,
              tutorialTextTr:
                  'Category Trap oyununda kapana yakalanmadan hızlıca karar verin!\n\n'
                  '• Üst paneldeki kategoriye bakın ve ortadaki İngilizce kelimenin bu kategoriye ait olup olmadığını belirleyin.\n'
                  '• Kelime kategoriye aitse YES (Sağ Ok / D), ait değilse NO (Sol Ok / A) butonuna basın.\n'
                  '• Her soru için süreniz kısıtlıdır. Yanlış cevap verdiğinizde veya süreniz bittiğinde kelimenin gerçek kategorisi gösterilir.\n'
                  '• Toplam 3 canınız vardır; doğru cevaplarla serinizi uzatarak yüksek skor elde edin!',
              tutorialTextEn:
                  'In Category Trap, check if the word belongs to the cage category above!\n\n'
                  '• If it belongs: press YES (Right / D key)\n'
                  '• If it doesn\'t: press NO (Left / A key)\n'
                  '• Decide quickly before time runs out. One mistake and trap snaps!',
            );
          },
        ),
      ],
    );
  }

  Widget _buildCategoryZoneHeader(Color surface, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(FontAwesomeIcons.triangleExclamation, color: accent, size: 14),
          const SizedBox(width: 8),
          Text(
            'CATEGORY: ',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: Colors.white54,
            ),
          ),
          Text(
            _currentCategory.toUpperCase(),
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBaitCard(Color surface, Color accent) {
    return AnimatedBuilder(
      animation: _swayController,
      builder: (context, child) {
        final double angle = sin(_swayController.value * 2 * pi) * 0.015;
        return Transform.rotate(
          angle: angle,
          child: child,
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: accent.withValues(alpha: 0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: accent.withValues(alpha: 0.06),
              blurRadius: 16,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Question prompt badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Text(
                'DOES IT BELONG TO THE CATEGORY?',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: Colors.white60,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Target word in huge text
            Text(
              _currentWord,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 44,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                color: _isShowingFeedback ? Colors.redAccent : Colors.white,
                height: 1.2,
              ),
            ),

            if (_isShowingFeedback && _feedbackExplanation != null) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                ),
                child: Text(
                  _feedbackExplanation!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFFF9B9B),
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildControls(Color noRed, Color yesGreen) {
    return Row(
      children: [
        // NO Button
        Expanded(
          child: _buildDecisionButton(
            label: 'NO',
            hint: 'A / ←',
            icon: Icons.close_rounded,
            color: noRed,
            onTap: () => _handleAnswer(false),
          ),
        ),
        const SizedBox(width: 16),

        // YES Button
        Expanded(
          child: _buildDecisionButton(
            label: 'YES',
            hint: 'D / →',
            icon: Icons.check_rounded,
            color: yesGreen,
            onTap: () => _handleAnswer(true),
          ),
        ),
      ],
    );
  }

  Widget _buildDecisionButton({
    required String label,
    required String hint,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final Color lipColor = label == 'NO'
        ? const Color(0xFF991B1B)
        : const Color(0xFF065F46);
    return Container(
      padding: const EdgeInsets.only(bottom: 4.5),
      decoration: BoxDecoration(
        color: lipColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: Colors.white, size: 22),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '[$hint]',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingFeedback() {
    return Center(
      child: AnimatedBuilder(
        animation: _correctAnimController,
        builder: (context, child) {
          return Opacity(
            opacity: _correctOpacityAnimation.value,
            child: Transform.scale(
              scale: _correctScaleAnimation.value,
              child: Transform.translate(
                offset: const Offset(0, 160),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.4),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'CORRECT!',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGameOverOverlay(Color surface, Color accent) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Container(
        color: Colors.black.withValues(alpha: 0.65),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.85, end: 1.0),
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutBack,
          builder: (context, s, child) => Transform.scale(scale: s, child: child),
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: accent.withValues(alpha: 0.5), width: 1.5),
                boxShadow: [
                  BoxShadow(color: accent.withValues(alpha: 0.2), blurRadius: 30),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isNewHighScore) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF59E0B)
                                  .withValues(alpha: 0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.emoji_events_rounded,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'YENİ EN YÜKSEK SKOR!',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(color: accent.withValues(alpha: 0.5)),
                      ),
                      child: Icon(FontAwesomeIcons.skull, size: 36, color: accent),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'TRAP TRIGGERED!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Canların tükendi! Kategori ilişkilerini pekiştirmelisin.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(fontSize: 13, color: Colors.white60),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Text('SCORE', style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey)),
                                const SizedBox(height: 2),
                                Text('$_score',
                                    style: GoogleFonts.outfit(
                                        fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Text('BEST', style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFFFBBF24))),
                                const SizedBox(height: 2),
                                Text('$_highScore',
                                    style: GoogleFonts.outfit(
                                        fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFFFBBF24))),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Text('STREAK', style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey)),
                                const SizedBox(height: 2),
                                Text('🔥 $_bestStreak',
                                    style: GoogleFonts.outfit(
                                        fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_sessionReviewItems.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      GameReviewAccordion(
                        items: _sessionReviewItems,
                        accentColor: accent,
                      ),
                    ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => setState(() => _startGame()),
                      icon: const Icon(Icons.replay_rounded, size: 18),
                      label: Text('Yeniden Oyna',
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded, size: 16),
                      label: Text('Ana Menü',
                          style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
}

/// Custom painter for cage bars and subtle hazard corner stripes.
class _CageTrapPainter extends CustomPainter {
  final Color accent;

  _CageTrapPainter({required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final barPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..strokeWidth = 2.0;

    // Subtle vertical cage bars
    const double barStep = 36;
    for (double x = 18; x < size.width; x += barStep) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), barPaint);
    }

    // Top and bottom horizontal metallic rails
    final railPaint = Paint()
      ..color = accent.withValues(alpha: 0.12)
      ..strokeWidth = 2.0;

    canvas.drawLine(const Offset(0, 10), Offset(size.width, 10), railPaint);
    canvas.drawLine(
        Offset(0, size.height - 10), Offset(size.width, size.height - 10), railPaint);

    // Hazard corner stripes (top right and top left)
    final hazardPaint = Paint()
      ..color = accent.withValues(alpha: 0.05)
      ..strokeWidth = 8.0;

    for (int i = 0; i < 5; i++) {
      final double offset = i * 16.0;
      canvas.drawLine(
        Offset(offset, 0),
        Offset(0, offset),
        hazardPaint,
      );
      canvas.drawLine(
        Offset(size.width - offset, 0),
        Offset(size.width, offset),
        hazardPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CageTrapPainter oldDelegate) => false;
}
