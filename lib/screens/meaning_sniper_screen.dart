import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/audio_service.dart';
import '../services/tts_service.dart';
import '../widgets/exit_confirmation_dialog.dart';
import '../widgets/game_tutorial_popup.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../widgets/category_selection_dialog.dart';
import '../data/meaning_sniper_data.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/arcade/arcade_widgets.dart';
import '../services/level_service.dart';
import '../widgets/level_selection_dialog.dart';
import '../widgets/marquee_title.dart';
import '../services/mistake_service.dart';
import '../services/score_service.dart';
import '../models/game_review_item.dart';

class MeaningSniperScreen extends StatefulWidget {
  final Map<String, String>? customDict;
  const MeaningSniperScreen({super.key, this.customDict});

  @override
  State<MeaningSniperScreen> createState() => _MeaningSniperScreenState();
}

class _MeaningSniperScreenState extends State<MeaningSniperScreen>
    with TickerProviderStateMixin {
  late final FocusNode _keyboardFocusNode;
  late Map<String, String> _activeDict;
  String _currentCategoryId = 'all';
  String _currentCategoryTitleTr = 'Tüm Kelimeler';
  IconData _currentCategoryIcon = FontAwesomeIcons.layerGroup;

  // --- State Variables ---
  late String _targetEnglish;
  late String _targetTurkish;
  List<String> _options = [];
  int _score = 0;
  int _lives = 3;
  int _streak = 0;
  bool _isGameOver = false;
  bool _isAnswering = false;
  String? _selectedOption;

  final List<GameReviewItem> _sessionReviewItems = [];
  int _highScore = 0;
  bool _isNewHighScore = false;


  late AnimationController _timerController;
  late AnimationController _heartAnimController;
  // Visual-only controllers
  late AnimationController _shakeController;
  late AnimationController _swayController;
  int _bestStreak = 0;
  double _timeLeftPercent = 1.0;
  GameDifficulty _difficulty = LevelService.instance.currentDifficulty;

  Map<String, String> _getRawCategoryDict(String catId) {
    if (widget.customDict != null) return widget.customDict!;
    if (catId == 'all') return meaningSniperFullDict;
    final cat = meaningSniperCategoriesList.firstWhere(
      (c) => c.id == catId,
      orElse: () => meaningSniperCategoriesList.first,
    );
    return cat.dictionary;
  }

  void _applyActiveDict() {
    final raw = _getRawCategoryDict(_currentCategoryId);
    _activeDict = LevelService.instance.filterDictionary(raw, _difficulty);
  }

  void _updateDifficulty(GameDifficulty newDiff) {
    setState(() {
      _difficulty = newDiff;
      LevelService.instance.setDifficulty(newDiff);
      _applyActiveDict();
      _resetAndStartRound();
    });
  }

  @override
  void initState() {
    super.initState();
    _highScore = ScoreService.instance.getHighScore('meaning_sniper');
    _applyActiveDict();
    _timerController =
        AnimationController(vsync: this, duration: const Duration(seconds: 8))
          ..addListener(() {
            setState(() => _timeLeftPercent = 1.0 - _timerController.value);
          })
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              _handleAnswer(null); // Time's up!
            }
          });

    _heartAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _swayController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();

    _generateQuestion();
    _timerController.stop(); // Don't start timer until tutorial is gone
    _keyboardFocusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _keyboardFocusNode.requestFocus();
      final bool hasSetup = widget.customDict == null;
      final result = await GameTutorialPopup.show(
        context,
        tutorialKey: 'meaning_sniper_tutorial',
        title: "Meaning Sniper",
        icon: FontAwesomeIcons.crosshairs,
        color: const Color(0xFF10B981),
        tutorialTextTr:
            'Meaning Sniper oyununda hedefe kilitlenin ve doğru anlamı vurun!\n\n'
            '• Ekranda hedef olarak gösterilen Türkçe kelimenin doğru İngilizce karşılığını 4 seçenek arasından seçin.\n'
            '• Seçeneğe dokunarak ya da klavyeden [1-4] tuşlarına basarak hızlıca nişan alın.\n'
            '• Nefes/süre çubuğu tükenmeden doğru hedefi vurun; her doğru atış serinizi yükseltir ve kombo puanı kazandırır.\n'
            '• Yanlış atış yapmak veya sürenin bitmesi 1 canınıza mal olur. Toplam 3 canınız vardır!',
        tutorialTextEn: "In Meaning Sniper, find the correct English translation of the Turkish word shown on screen from the 4 options below! Pick the right answer before time runs out. Build streaks for bonus points, but be careful: wrong answers cost you a life!",
        includeLevelSelection: hasSetup,
        initialDifficulty: _difficulty,
        categories: hasSetup ? getMeaningSniperCategoryOptions() : null,
        initialCategoryId: _currentCategoryId,
      );
      if (mounted && hasSetup) {
        if (result.difficulty != null) {
          _difficulty = result.difficulty!;
          LevelService.instance.setDifficulty(_difficulty);
        }
        final chosenCat = result.categoryId ?? _currentCategoryId;
        _currentCategoryId = chosenCat;
        if (chosenCat == 'all') {
          _currentCategoryTitleTr = 'Tüm Kelimeler';
          _currentCategoryIcon = FontAwesomeIcons.layerGroup;
        } else {
          final cat = meaningSniperCategoriesList.firstWhere(
            (c) => c.id == chosenCat,
            orElse: () => meaningSniperCategoriesList.first,
          );
          _currentCategoryTitleTr = cat.titleTr;
          _currentCategoryIcon = cat.icon;
        }
        _applyActiveDict();
        _resetAndStartRound();
      } else if (mounted) {
        _timerController.forward();
      }
    });
  }

  Future<void> _showCategoryPickerAndStart({bool canDismiss = true}) async {
    final chosen = await CategorySelectionDialog.show(
      context,
      title: 'Meaning Sniper: Kategori Seçin',
      subtitle: 'Hedef kelimelerin ait olacağı konuyu belirleyin',
      accentColor: const Color(0xFF10B981),
      headerIcon: FontAwesomeIcons.crosshairs,
      categories: getMeaningSniperCategoryOptions(),
      initialSelectedId: _currentCategoryId,
      canDismiss: canDismiss,
    );
    if (!mounted) return;
    if (chosen != null) {
      _currentCategoryId = chosen;
      if (chosen == 'all') {
        _currentCategoryTitleTr = 'Tüm Kelimeler';
        _currentCategoryIcon = FontAwesomeIcons.layerGroup;
      } else {
        final cat = meaningSniperCategoriesList.firstWhere(
          (c) => c.id == chosen,
          orElse: () => meaningSniperCategoriesList.first,
        );
        _currentCategoryTitleTr = cat.titleTr;
        _currentCategoryIcon = cat.icon;
      }
      _applyActiveDict();
      _resetAndStartRound();
    } else {
      if (mounted) _timerController.forward();
    }
  }

  void _resetAndStartRound() {
    setState(() {
      _score = 0;
      _lives = 3;
      _streak = 0;
      _bestStreak = 0;
      _isGameOver = false;
      _isNewHighScore = false;
      _sessionReviewItems.clear();
      _generateQuestion();
    });
    _timerController.forward();
  }

  void _generateQuestion() {
    final random = Random();
    final keys = _activeDict.keys.toList();

    _targetEnglish = keys[random.nextInt(keys.length)];
    _targetTurkish = _activeDict[_targetEnglish]!;

    // Generate distractors
    Set<String> optionSet = {_targetEnglish};
    while (optionSet.length < 4) {
      optionSet.add(keys[random.nextInt(keys.length)]);
    }

    _options = optionSet.toList()..shuffle();
    _isAnswering = false;
    _selectedOption = null;

    // Reset and start timer
    _timerController.stop();
    _timerController.reset();

    // speed up based on score
    double baseSeconds = 8.0 - (_score / 15.0);
    _timerController.duration = Duration(
      milliseconds: (max(3.0, baseSeconds) * 1000).toInt(),
    );
    _timerController.forward();
  }

  void _handleAnswer(String? selected) {
    if (_isAnswering || _isGameOver) return;

    _timerController.stop();
    final toSpeak =
        (selected != null && selected.isNotEmpty) ? selected : _targetEnglish;
    TtsService.instance.speak(toSpeak);
    setState(() {
      _isAnswering = true;
      _selectedOption = selected;
    });

    if (selected == _targetEnglish) {
      _score += 10 + (_streak * 2); // bonus for streak
      _streak++;
      if (_streak > _bestStreak) _bestStreak = _streak;

      _sessionReviewItems.add(GameReviewItem(
        id: '${_targetEnglish}_${DateTime.now().millisecondsSinceEpoch}',
        word: _targetEnglish,
        meaning: _targetTurkish,
        question: 'Hedef Türkçe: "$_targetTurkish"',
        userAnswer: selected,
        correctAnswer: _targetEnglish,
        isCorrect: true,
      ));

      // Regen life logic
      if (_lives < 3) {
        _lives++;
        _heartAnimController.forward(from: 0);
      }

      AudioService.playCorrect();
      HapticFeedback.lightImpact();

      Timer(const Duration(milliseconds: 600), () {
        if (mounted) {
          setState(() => _generateQuestion());
        }
      });
    } else {
      _lives--;
      _streak = 0;
      AudioService.playIncorrect();
      HapticFeedback.heavyImpact();
      _shakeController.forward(from: 0);

      _sessionReviewItems.add(GameReviewItem(
        id: '${_targetEnglish}_${DateTime.now().millisecondsSinceEpoch}',
        word: _targetEnglish,
        meaning: _targetTurkish,
        question: 'Hedef Türkçe: "$_targetTurkish"',
        userAnswer: selected ?? 'Süre Doldu',
        correctAnswer: _targetEnglish,
        isCorrect: false,
      ));

      MistakeService.instance.recordMistake(
        word: _targetEnglish,
        meaning: _targetTurkish,
        sourceGame: 'Meaning Sniper',
        wrongAnswer: selected ?? 'Süre Doldu',
      );

      if (_lives <= 0) {
        _endGame();
      } else {
        Timer(const Duration(milliseconds: 1000), () {
          if (mounted) {
            setState(() => _generateQuestion());
          }
        });
      }
    }
  }

  void _endGame() {
    setState(() => _isGameOver = true);
    AudioService.playFailure();
    ScoreService.instance.recordScore(
      gameId: 'meaning_sniper',
      score: _score,
      streak: _bestStreak,
    ).then((res) {
      if (mounted) {
        setState(() {
          _highScore = res.highScore;
          _isNewHighScore = res.isNewHighScore;
        });
      }
    });
    _showResultDialog(isWon: false);
  }

  @override
  void dispose() {
    TtsService.instance.stop();
    _timerController.dispose();
    _heartAnimController.dispose();
    _shakeController.dispose();
    _swayController.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (_isAnswering || _isGameOver) return KeyEventResult.ignored;

    final key = event.logicalKey;
    int? index;
    if (key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.numpad1) index = 0;
    if (key == LogicalKeyboardKey.digit2 || key == LogicalKeyboardKey.numpad2) index = 1;
    if (key == LogicalKeyboardKey.digit3 || key == LogicalKeyboardKey.numpad3) index = 2;
    if (key == LogicalKeyboardKey.digit4 || key == LogicalKeyboardKey.numpad4) index = 3;

    if (index != null && index < _options.length) {
      _handleAnswer(_options[index]);
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
    const bgDark = Color(0xFF07110E);
    const surfaceDark = Color(0xFF0D1B16);
    const accentGreen = Color(0xFF10B981);

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
          appBar: _buildAppBar(accentGreen),
          body: SafeArea(
          child: Stack(
            children: [
              // Tactical scope background painter
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _swayController,
                  builder: (context, _) => CustomPaint(
                    painter: _SniperScopePainter(
                      sway: _swayController.value,
                      accent: accentGreen,
                    ),
                  ),
                ),
              ),

              // Main game area with shake effect on miss
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
                            accent: accentGreen,
                            surface: surfaceDark,
                            score: _score,
                            streak: _streak,
                            lives: _lives,
                            livesScale: Tween<double>(begin: 1.0, end: 1.25)
                                .animate(
                              CurvedAnimation(
                                parent: _heartAnimController,
                                curve: Curves.elasticOut,
                              ),
                            ),
                            badge: ArcadeBadge(
                              icon: _currentCategoryIcon,
                              text: _currentCategoryTitleTr,
                              color: accentGreen,
                              trailing: widget.customDict == null
                                  ? Icons.swap_horiz_rounded
                                  : null,
                              onTap: widget.customDict == null
                                  ? () => _showCategoryPickerAndStart(
                                      canDismiss: true)
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Breath Hold / Lock Time indicator
                          GlowTimerBar(
                            percent: _timeLeftPercent,
                            height: 6,
                            label: 'LOCK TIME',
                            labelColor: accentGreen,
                          ),
                          const Spacer(),

                          // Target scope card (Turkish word)
                          _buildTargetScopeCard(surfaceDark, accentGreen),
                          const Spacer(),

                          // Tactical target option buttons (1-4)
                          _buildOptionsGrid(surfaceDark, accentGreen),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Game Over Modal
              if (_isGameOver) _buildGameOverOverlay(surfaceDark, accentGreen),
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
        title: 'Meaning Sniper',
        leadingIcon: Icon(FontAwesomeIcons.crosshairs, color: accent, size: 18),
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
              title: 'Meaning Sniper: Seviye Değiştir',
            );
            if (chosen != null && mounted) {
              _updateDifficulty(chosen);
            } else if (wasAnimating && mounted && !_isGameOver) {
              _timerController.forward();
            }
          },
        ),
        if (widget.customDict == null)
          IconButton(
            icon: Icon(FontAwesomeIcons.layerGroup, color: accent, size: 17),
            tooltip: 'Kategori Seç',
            onPressed: () => _showCategoryPickerAndStart(canDismiss: true),
          ),
        IconButton(
          tooltip: 'Nasıl Oynanır?',
          icon: const Icon(Icons.help_outline_rounded, color: Colors.white70),
          onPressed: () {
            GameTutorialPopup.show(
              context,
              tutorialKey: 'meaning_sniper_tutorial',
              title: 'Meaning Sniper',
              icon: FontAwesomeIcons.crosshairs,
              color: accent,
              tutorialTextTr:
                  'Meaning Sniper oyununda hedefe kilitlenin ve doğru anlamı vurun!\n\n'
                  '• Ekranda hedef olarak gösterilen Türkçe kelimenin doğru İngilizce karşılığını 4 seçenek arasından seçin.\n'
                  '• Seçeneğe dokunarak ya da klavyeden [1-4] tuşlarına basarak hızlıca nişan alın.\n'
                  '• Nefes/süre çubuğu tükenmeden doğru hedefi vurun; her doğru atış serinizi yükseltir ve kombo puanı kazandırır.\n'
                  '• Yanlış atış yapmak veya sürenin bitmesi 1 canınıza mal olur. Toplam 3 canınız vardır!',
              tutorialTextEn:
                  'In Meaning Sniper, find the correct English translation of the Turkish target from the 4 target options!\n\n'
                  '• Tap or press [1-4] keys on keyboard to fire.\n'
                  '• Hit the correct target before breath runs out.\n'
                  '• Build streaks for bonus score, wrong shots cost a life!',
            );
          },
        ),
      ],
    );
  }

  Widget _buildTargetScopeCard(Color surface, Color accent) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Target header
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'TARGET LOCKED',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.0,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Turkish word target
          Text(
            _targetTurkish,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 38,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),

          // Subtitle hint
          Text(
            'İngilizce karşılığını vur [1-4]',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsGrid(Color surface, Color accent) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: _buildOptionItem(0, surface, accent)),
            const SizedBox(width: 14),
            Expanded(child: _buildOptionItem(1, surface, accent)),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _buildOptionItem(2, surface, accent)),
            const SizedBox(width: 14),
            Expanded(child: _buildOptionItem(3, surface, accent)),
          ],
        ),
      ],
    );
  }

  Widget _buildOptionItem(int index, Color surface, Color accent) {
    if (index >= _options.length) return const SizedBox();
    final opt = _options[index];
    return SizedBox(
      height: 74,
      child: _SniperOptionTile(
        keyNumber: index + 1,
        option: opt,
        isSelected: _selectedOption == opt,
        isCorrectSolution: opt == _targetEnglish,
        isAnswering: _isAnswering,
        surfaceColor: surface,
        accentColor: accent,
        onTap: () => _handleAnswer(opt),
      ),
    );
  }

  void _showResultDialog({required bool isWon}) {
    setState(() {});
  }

  Widget _buildGameOverOverlay(Color surface, Color accent) {
    return ArcadeGameOverCard(
      title: 'MISSION FAILED',
      subtitle: 'Hedef kilitlendi ancak canın tükendi!',
      icon: FontAwesomeIcons.crosshairs,
      accent: accent,
      surface: surface,
      score: _score,
      bestStreak: _bestStreak,
      highScore: _highScore,
      isNewHighScore: _isNewHighScore,
      reviewItems: _sessionReviewItems,
      actions: [
        ArcadeGameOverAction(
          label: 'Yeniden Oyna',
          icon: Icons.replay_rounded,
          primary: true,
          onTap: () {
            setState(() {
              _score = 0;
              _lives = 3;
              _streak = 0;
              _bestStreak = 0;
              _isGameOver = false;
              _isNewHighScore = false;
              _sessionReviewItems.clear();
              _generateQuestion();
            });
          },
        ),
        if (widget.customDict == null)
          ArcadeGameOverAction(
            label: 'Kategori Değiştir',
            icon: FontAwesomeIcons.layerGroup,
            onTap: () {
              setState(() => _isGameOver = false);
              _showCategoryPickerAndStart(canDismiss: false);
            },
          ),
        ArcadeGameOverAction(
          label: 'Ana Menü',
          icon: Icons.arrow_back_rounded,
          onTap: () => Navigator.pop(context),
        ),
      ],
    );
  }
}

/// Tactical option tile with key badge [1-4] and hit/miss indicators.
class _SniperOptionTile extends StatefulWidget {
  final int keyNumber;
  final String option;
  final bool isSelected;
  final bool isCorrectSolution;
  final bool isAnswering;
  final Color surfaceColor;
  final Color accentColor;
  final VoidCallback onTap;

  const _SniperOptionTile({
    required this.keyNumber,
    required this.option,
    required this.isSelected,
    required this.isCorrectSolution,
    required this.isAnswering,
    required this.surfaceColor,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<_SniperOptionTile> createState() => _SniperOptionTileState();
}

class _SniperOptionTileState extends State<_SniperOptionTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    Color borderColor = widget.accentColor.withValues(alpha: 0.25);
    Color fillColor = widget.surfaceColor;
    Color textColor = Colors.white;
    Widget? statusBadge;

    if (widget.isAnswering) {
      if (widget.isCorrectSolution) {
        fillColor = const Color(0xFF10B981).withValues(alpha: 0.18);
        borderColor = const Color(0xFF10B981);
        textColor = const Color(0xFF10B981);
        statusBadge = Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'HIT',
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
        );
      } else if (widget.isSelected) {
        fillColor = const Color(0xFFEF4444).withValues(alpha: 0.18);
        borderColor = const Color(0xFFEF4444);
        textColor = const Color(0xFFEF4444);
        statusBadge = Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'MISS',
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        );
      }
    } else if (_isHovered) {
      borderColor = widget.accentColor.withValues(alpha: 0.65);
      fillColor = widget.surfaceColor.withValues(alpha: 0.95);
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderColor,
              width: (widget.isSelected ||
                      (widget.isCorrectSolution && widget.isAnswering))
                  ? 2.0
                  : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (widget.isAnswering && widget.isCorrectSolution)
                    ? const Color(0xFF047857)
                    : (widget.isAnswering && widget.isSelected)
                        ? const Color(0xFFB91C1C)
                        : const Color(0xFF090D16),
                offset: const Offset(0, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: Row(
            children: [
              // Key badge [1-4]
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                child: Text(
                  '${widget.keyNumber}',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white70,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Option text
              Expanded(
                child: Text(
                  widget.option,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
              ),

              // Status badge if answering
              if (statusBadge != null) ...[
                const SizedBox(width: 8),
                statusBadge,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom painter for tactical scope grid, crosshairs, and corner brackets.
class _SniperScopePainter extends CustomPainter {
  final double sway;
  final Color accent;

  _SniperScopePainter({required this.sway, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2 + cos(sway * 2 * pi) * 6;
    final cy = size.height * 0.45 + sin(sway * 2 * pi) * 4;

    final gridPaint = Paint()
      ..color = accent.withValues(alpha: 0.035)
      ..strokeWidth = 1.0;

    // Tactical background grid
    const double step = 44;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final reticlePaint = Paint()
      ..color = accent.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Outer reticle circle
    canvas.drawCircle(Offset(cx, cy), 130, reticlePaint);
    // Inner reticle circle
    canvas.drawCircle(
      Offset(cx, cy),
      70,
      reticlePaint..color = accent.withValues(alpha: 0.12),
    );

    // Crosshair ticks
    final tickPaint = Paint()
      ..color = accent.withValues(alpha: 0.25)
      ..strokeWidth = 1.2;

    // Horizontal crosshair with gap in center
    canvas.drawLine(Offset(cx - 150, cy), Offset(cx - 30, cy), tickPaint);
    canvas.drawLine(Offset(cx + 30, cy), Offset(cx + 150, cy), tickPaint);

    // Vertical crosshair with gap in center
    canvas.drawLine(Offset(cx, cy - 150), Offset(cx, cy - 30), tickPaint);
    canvas.drawLine(Offset(cx, cy + 30), Offset(cx, cy + 150), tickPaint);

    // Mil-dots
    final dotPaint = Paint()
      ..color = accent.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    for (int i = 1; i <= 3; i++) {
      final double d = i * 36.0;
      canvas.drawCircle(Offset(cx - d, cy), 1.8, dotPaint);
      canvas.drawCircle(Offset(cx + d, cy), 1.8, dotPaint);
      canvas.drawCircle(Offset(cx, cy - d), 1.8, dotPaint);
      canvas.drawCircle(Offset(cx, cy + d), 1.8, dotPaint);
    }

    // Corner HUD brackets
    final bracketPaint = Paint()
      ..color = accent.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    const double pad = 16;
    const double len = 20;

    // Top-left
    canvas.drawLine(const Offset(pad, pad + len), const Offset(pad, pad), bracketPaint);
    canvas.drawLine(const Offset(pad, pad), const Offset(pad + len, pad), bracketPaint);

    // Top-right
    canvas.drawLine(Offset(size.width - pad - len, pad), Offset(size.width - pad, pad), bracketPaint);
    canvas.drawLine(Offset(size.width - pad, pad), Offset(size.width - pad, pad + len), bracketPaint);

    // Bottom-left
    canvas.drawLine(Offset(pad, size.height - pad - len), Offset(pad, size.height - pad), bracketPaint);
    canvas.drawLine(Offset(pad, size.height - pad), Offset(pad + len, size.height - pad), bracketPaint);

    // Bottom-right
    canvas.drawLine(Offset(size.width - pad - len, size.height - pad), Offset(size.width - pad, size.height - pad), bracketPaint);
    canvas.drawLine(Offset(size.width - pad, size.height - pad - len), Offset(size.width - pad, size.height - pad), bracketPaint);
  }

  @override
  bool shouldRepaint(covariant _SniperScopePainter oldDelegate) =>
      oldDelegate.sway != sway;
}