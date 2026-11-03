import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/sound_catch_data.dart';
import '../models/game_review_item.dart';
import '../services/audio_service.dart';
import '../services/level_service.dart';
import '../services/mistake_service.dart';
import '../services/score_service.dart';
import '../services/tts_service.dart';
import '../widgets/exit_confirmation_dialog.dart';
import '../widgets/game_review_accordion.dart';
import '../widgets/game_tutorial_popup.dart';
import '../widgets/marquee_title.dart';

class SoundCatchScreen extends StatefulWidget {
  final Map<String, String>? customDict;

  const SoundCatchScreen({super.key, this.customDict});

  @override
  State<SoundCatchScreen> createState() => _SoundCatchScreenState();
}

class _SoundCatchScreenState extends State<SoundCatchScreen>
    with TickerProviderStateMixin {
  // Tactile Theme Palette (amber / warm gold tone for listening & phonics)
  static const Color _primaryColor = Color(0xFFD97706); // Warm Amber
  static const Color _primaryDark = Color(0xFF92400E);
  static const Color _cardBgDark = Color(0xFF141422);
  static const Color _surfaceDark = Color(0xFF1C1C2E);
  static const Color _greenColor = Color(0xFF10B981);
  static const Color _greenDark = Color(0xFF047857);
  static const Color _redColor = Color(0xFFEF4444);
  static const Color _redDark = Color(0xFFB91C1C);

  final FocusNode _focusNode = FocusNode();
  final Random _random = Random();

  GameDifficulty _difficulty = GameDifficulty.all;
  late List<SoundCatchQuestion> _questionPool;
  List<SoundCatchQuestion> _remainingQuestions = [];
  SoundCatchQuestion? _currentQuestion;
  List<String> _currentOptions = [];

  // Game state
  int _score = 0;
  int _streak = 0;
  int _maxStreak = 0;
  int _lives = 3;
  int _correctCount = 0;
  bool _isGameOver = false;
  bool _isPaused = false;
  bool _isAnswerChecked = false;
  String? _selectedOption;

  final List<GameReviewItem> _sessionReviewItems = [];

  // Animation Controllers
  late AnimationController _timerController;
  late AnimationController _pulseController;
  late AnimationController _feedbackAnimController;
  String? _feedbackText;
  Color _feedbackColor = _greenColor;

  // Sound play state
  bool _isPlayingAudio = false;

  @override
  void initState() {
    super.initState();

    _timerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _handleTimeout();
        }
      });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _feedbackAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _prepareQuestionPool();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _focusNode.requestFocus();
      final result = await GameTutorialPopup.show(
        context,
        tutorialKey: 'sound_catch_tutorial',
        title: 'Sound Catch',
        icon: FontAwesomeIcons.headphones,
        color: _primaryColor,
        tutorialTextTr:
            'Sound Catch oyununda telaffuz edilen İngilizce kelimeyi dinleyin ve fonetik olarak birbirine çok benzeyen, kafiyeli 4 seçenek arasından doğru olanı yakalayın!\n\n'
            '• 🔊 Sesi tekrar dinlemek için ortadaki kulaklık/hoparlör düğmesine dokunun veya klavyeden BOŞLUK (Space) tuşuna basın.\n'
            '• 🎯 Seçeneklerden birine dokunun veya klavyeden 1 - 4 ya da A - D tuşlarını kullanın.\n'
            '• ⚡ Süre bitmeden doğru cevabı bularak kombo yapın, serinizi yükseltin ve puanları toplayın!\n'
            '• 💡 Yanlış yaptığınızda kelimenin Türkçe anlamını ve telaffuz ipucunu öğrenerek Hata Bankası\'na kaydedebilirsiniz.',
        tutorialTextEn:
            'Listen closely to the spoken English word and catch the correct one among 4 phonetically similar rhyming minimal pairs!\n\n'
            '• 🔊 Tap the big audio button or press SPACEBAR to replay the pronunciation.\n'
            '• 🎯 Tap an option or press keys 1 - 4 (or A - D) on your keyboard.\n'
            '• ⚡ Answer quickly before the timer runs out to gain combo multipliers and score points!\n'
            '• 💡 Learn from mistakes with instant Turkish translations and phonetic tips saved to your Mistake Bank.',
        includeLevelSelection: widget.customDict == null,
        initialDifficulty: _difficulty,
      );

      if (mounted) {
        if (result.difficulty != null) {
          _difficulty = result.difficulty!;
          _prepareQuestionPool();
        }
        _startNewGame();
      }
    });
  }

  @override
  void dispose() {
    TtsService.instance.stop();
    _timerController.dispose();
    _pulseController.dispose();
    _feedbackAnimController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _prepareQuestionPool() {
    if (widget.customDict != null && widget.customDict!.isNotEmpty) {
      // Build custom question items from customDict
      final entries = widget.customDict!.entries.toList();
      final List<SoundCatchQuestion> customList = [];

      for (var entry in entries) {
        final target = entry.key.trim();
        final meaning = entry.value.trim();

        // Check if there is an existing question in soundCatchQuestions for rich phonics distractors
        final existing = soundCatchQuestions.where(
          (q) => q.target.toLowerCase() == target.toLowerCase(),
        );

        if (existing.isNotEmpty) {
          customList.add(existing.first);
        } else {
          // Find 3 distractors from customDict or soundCatchQuestions
          final distractors = <String>{};
          for (var other in entries) {
            if (other.key.trim().toLowerCase() != target.toLowerCase()) {
              distractors.add(other.key.trim());
              if (distractors.length >= 3) break;
            }
          }
          if (distractors.length < 3) {
            for (var sq in soundCatchQuestions) {
              if (sq.target.toLowerCase() != target.toLowerCase()) {
                distractors.add(sq.target);
                if (distractors.length >= 3) break;
              }
            }
          }

          final opts = [target, ...distractors.take(3)]..shuffle(_random);
          customList.add(
            SoundCatchQuestion(
              target: target,
              meaning: meaning,
              options: opts,
            ),
          );
        }
      }
      _questionPool = customList..shuffle(_random);
    } else {
      List<SoundCatchQuestion> pool;
      switch (_difficulty) {
        case GameDifficulty.elementary:
          pool = soundCatchQuestions.where((q) => q.level == 'A1-A2').toList();
          break;
        case GameDifficulty.intermediate:
          pool = soundCatchQuestions.where((q) => q.level == 'B1-B2').toList();
          break;
        case GameDifficulty.all:
          pool = List<SoundCatchQuestion>.from(soundCatchQuestions);
          break;
      }
      _questionPool = pool..shuffle(_random);
    }
  }

  void _startNewGame() {
    setState(() {
      _score = 0;
      _streak = 0;
      _maxStreak = 0;
      _lives = 3;
      _correctCount = 0;
      _isGameOver = false;
      _isPaused = false;
      _isAnswerChecked = false;
      _selectedOption = null;
      _sessionReviewItems.clear();
      _remainingQuestions = List<SoundCatchQuestion>.from(_questionPool);
      if (_remainingQuestions.isEmpty) {
        _prepareQuestionPool();
        _remainingQuestions = List<SoundCatchQuestion>.from(_questionPool);
      }
    });

    _loadNextQuestion();
  }

  void _loadNextQuestion() {
    if (_remainingQuestions.isEmpty) {
      // Re-shuffle if exhausted
      _remainingQuestions = List<SoundCatchQuestion>.from(_questionPool)
        ..shuffle(_random);
    }

    final question = _remainingQuestions.removeAt(0);
    final options = List<String>.from(question.options)..shuffle(_random);

    setState(() {
      _currentQuestion = question;
      _currentOptions = options;
      _selectedOption = null;
      _isAnswerChecked = false;
    });

    // Dynamic timer duration based on streak (starts at 8s, gets slightly tighter with high streak down to 4.5s)
    final int timerMillis = max(4500, 8000 - (_streak * 180));
    _timerController.duration = Duration(milliseconds: timerMillis);
    _timerController.forward(from: 0.0);

    // Play target audio via TTS
    _playTargetAudio();
  }

  void _playTargetAudio() {
    final q = _currentQuestion;
    if (q == null) return;

    setState(() {
      _isPlayingAudio = true;
    });

    TtsService.instance.speak(q.target).then((_) {
      if (mounted) {
        setState(() {
          _isPlayingAudio = false;
        });
      }
    });
  }

  void _handleOptionSelect(String option) {
    if (_isAnswerChecked || _isGameOver || _isPaused) return;

    _timerController.stop();

    final q = _currentQuestion;
    if (q == null) return;

    final isCorrect = option.toLowerCase() == q.target.toLowerCase();

    setState(() {
      _selectedOption = option;
      _isAnswerChecked = true;
    });

    if (isCorrect) {
      _onCorrectAnswer();
    } else {
      _onWrongAnswer(chosenOption: option, isTimeout: false);
    }
  }

  void _handleTimeout() {
    if (_isAnswerChecked || _isGameOver || _isPaused) return;

    _timerController.stop();
    setState(() {
      _selectedOption = null;
      _isAnswerChecked = true;
    });
    _onWrongAnswer(chosenOption: null, isTimeout: true);
  }

  void _onCorrectAnswer() {
    AudioService.playCorrect();

    final q = _currentQuestion;
    if (q == null) return;

    final double timeLeftFraction = 1.0 - _timerController.value;
    final int speedBonus = (timeLeftFraction * 50).round();
    final double multiplier = _streak >= 10
        ? 3.0
        : _streak >= 6
            ? 2.0
            : _streak >= 3
                ? 1.5
                : 1.0;
    final int pointsEarned = ((100 + speedBonus) * multiplier).round();

    setState(() {
      _score += pointsEarned;
      _streak += 1;
      _correctCount += 1;
      if (_streak > _maxStreak) _maxStreak = _streak;
      _showFeedback(
        multiplier > 1.0
            ? '+$pointsEarned (x$multiplier)!'
            : '+$pointsEarned!',
        _greenColor,
      );
    });

    _sessionReviewItems.add(
      GameReviewItem(
        id: '${q.target}_${DateTime.now().millisecondsSinceEpoch}',
        word: q.target,
        meaning: q.meaning,
        question: 'Telaffuz edilen kelime',
        userAnswer: _selectedOption,
        correctAnswer: q.target,
        isCorrect: true,
        note: q.tip,
      ),
    );

    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted && !_isGameOver) {
        _loadNextQuestion();
      }
    });
  }

  void _onWrongAnswer({required String? chosenOption, required bool isTimeout}) {
    AudioService.playIncorrect();

    final q = _currentQuestion;
    if (q == null) return;

    MistakeService.instance.recordMistake(
      word: q.target,
      meaning: q.meaning,
      sourceGame: 'Sound Catch',
      wrongAnswer: isTimeout ? 'Süre Doldu' : chosenOption,
    );

    _sessionReviewItems.add(
      GameReviewItem(
        id: '${q.target}_${DateTime.now().millisecondsSinceEpoch}',
        word: q.target,
        meaning: q.meaning,
        question: 'Telaffuz edilen kelime',
        userAnswer: isTimeout ? 'Süre Doldu' : chosenOption,
        correctAnswer: q.target,
        isCorrect: false,
        note: q.tip,
      ),
    );

    setState(() {
      _lives -= 1;
      _streak = 0;
      _showFeedback(
        isTimeout ? 'SÜRE BİTTİ! ➜ ${q.target}' : 'YANLIŞ! ➜ ${q.target}',
        _redColor,
      );
    });

    if (_lives <= 0) {
      _triggerGameOver();
    } else {
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted && !_isGameOver) {
          _loadNextQuestion();
        }
      });
    }
  }

  void _triggerGameOver() {
    AudioService.playFailure();
    setState(() {
      _isGameOver = true;
    });

    ScoreService.instance.recordScore(
      gameId: 'sound_catch',
      score: _score,
      streak: _maxStreak,
    );
  }

  void _showFeedback(String text, Color color) {
    setState(() {
      _feedbackText = text;
      _feedbackColor = color;
    });
    _feedbackAnimController.forward(from: 0.0);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _handleExit();
      return KeyEventResult.handled;
    }

    if (_isGameOver) {
      if (event.logicalKey == LogicalKeyboardKey.space ||
          event.logicalKey == LogicalKeyboardKey.enter) {
        _startNewGame();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.space) {
      _playTargetAudio();
      return KeyEventResult.handled;
    }

    if (!_isAnswerChecked && _currentOptions.length == 4) {
      if (event.logicalKey == LogicalKeyboardKey.digit1 ||
          event.logicalKey == LogicalKeyboardKey.keyA) {
        _handleOptionSelect(_currentOptions[0]);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.digit2 ||
          event.logicalKey == LogicalKeyboardKey.keyB) {
        _handleOptionSelect(_currentOptions[1]);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.digit3 ||
          event.logicalKey == LogicalKeyboardKey.keyC) {
        _handleOptionSelect(_currentOptions[2]);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.digit4 ||
          event.logicalKey == LogicalKeyboardKey.keyD) {
        _handleOptionSelect(_currentOptions[3]);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  Future<void> _handleExit() async {
    final wasAnimating = _timerController.isAnimating;
    _timerController.stop();
    setState(() {
      _isPaused = true;
    });

    final shouldPop = await showExitConfirmationDialog(context);

    if (shouldPop && mounted) {
      Navigator.of(context).pop();
    } else if (mounted) {
      setState(() {
        _isPaused = false;
      });
      if (wasAnimating && !_isGameOver && !_isAnswerChecked) {
        _timerController.forward();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
          backgroundColor: const Color(0xFF0F0F1A),
          appBar: _buildAppBar(),
          body: SafeArea(
            child: _isGameOver
                ? _buildGameOverView(isDesktop)
                : Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isDesktop ? 1040 : 640,
                      ),
                      child: isDesktop
                          ? _buildDesktopLayout()
                          : _buildMobileLayout(isCompact),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF141424),
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        tooltip: 'Çıkış',
        onPressed: _handleExit,
      ),
      title: MarqueeTitle(
        title: 'Sound Catch',
        style: GoogleFonts.outfit(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        leadingIcon: const FaIcon(
          FontAwesomeIcons.headphones,
          size: 16,
          color: _primaryColor,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.help_outline_rounded, color: Colors.white70),
          tooltip: 'Nasıl Oynanır?',
          onPressed: () {
            final wasAnimating = _timerController.isAnimating;
            _timerController.stop();
            GameTutorialPopup.show(
              context,
              forceShow: true,
              title: 'Sound Catch',
              icon: FontAwesomeIcons.headphones,
              color: _primaryColor,
              tutorialTextTr:
                  'Sound Catch oyununda telaffuz edilen İngilizce kelimeyi dinleyin ve fonetik olarak birbirine çok benzeyen, kafiyeli 4 seçenek arasından doğru olanı yakalayın!\n\n'
                  '• 🔊 Sesi tekrar dinlemek için ortadaki kulaklık/hoparlör düğmesine dokunun veya klavyeden BOŞLUK (Space) tuşuna basın.\n'
                  '• 🎯 Seçeneklerden birine dokunun veya klavyeden 1 - 4 ya da A - D tuşlarını kullanın.\n'
                  '• ⚡ Süre bitmeden doğru cevabı bularak kombo yapın, serinizi yükseltin ve puanları toplayın!\n'
                  '• 💡 Yanlış yaptığınızda kelimenin Türkçe anlamını ve telaffuz ipucunu öğrenerek Hata Bankası\'na kaydedebilirsiniz.',
              tutorialTextEn:
                  'Listen closely to the spoken English word and catch the correct one among 4 phonetically similar rhyming minimal pairs!\n\n'
                  '• 🔊 Tap the big audio button or press SPACEBAR to replay the pronunciation.\n'
                  '• 🎯 Tap an option or press keys 1 - 4 (or A - D) on your keyboard.\n'
                  '• ⚡ Answer quickly before the timer runs out to gain combo multipliers and score points!\n'
                  '• 💡 Learn from mistakes with instant Turkish translations and phonetic tips saved to your Mistake Bank.',
              includeLevelSelection: false,
            ).then((_) {
              if (mounted && wasAnimating && !_isGameOver && !_isAnswerChecked) {
                _timerController.forward();
              }
            });
          },
        ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(4),
        child: AnimatedBuilder(
          animation: _timerController,
          builder: (context, child) {
            final value = 1.0 - _timerController.value;
            final color = value > 0.4
                ? _primaryColor
                : value > 0.2
                    ? const Color(0xFFF59E0B)
                    : _redColor;
            return LinearProgressIndicator(
              value: value,
              minHeight: 4,
              backgroundColor: const Color(0xFF1E1E34),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopStatBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _surfaceDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2C2C42), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF10101C),
            offset: Offset(0, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Lives
          Row(
            children: List.generate(3, (index) {
              final isAlive = index < _lives;
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  Icons.favorite_rounded,
                  size: 18,
                  color: isAlive ? _redColor : const Color(0xFF4A4A62),
                ),
              );
            }),
          ),

          // Streak
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _streak > 0
                  ? _primaryColor.withValues(alpha: 0.18)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _streak > 0
                    ? _primaryColor.withValues(alpha: 0.45)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                FaIcon(
                  FontAwesomeIcons.fire,
                  size: 13,
                  color: _streak > 0 ? _primaryColor : const Color(0xFF6B7280),
                ),
                const SizedBox(width: 4),
                Text(
                  'Seri: $_streak',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color:
                        _streak > 0 ? _primaryColor : const Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),

          // Score
          Row(
            children: [
              const Icon(Icons.star_rounded, size: 18, color: Color(0xFFFBBF24)),
              const SizedBox(width: 4),
              Text(
                '$_score',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAudioListenCard({required bool isDesktop}) {
    final q = _currentQuestion;
    if (q == null) return const SizedBox.shrink();

    final double buttonSize = isDesktop ? 88.0 : 68.0;
    final double iconSize = isDesktop ? 36.0 : 28.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 20 : 14,
        vertical: isDesktop ? 18 : 12,
      ),
      decoration: BoxDecoration(
        color: _cardBgDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2E2E48), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF0B0B14),
            offset: Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Row: Level + Status/Feedback (integrated to eliminate jump)
          _buildAudioCardHeader(q, isDesktop),
          SizedBox(height: isDesktop ? 14 : 10),

          // Big Tactile Speaker / Headphone Button
          ScaleTransition(
            scale: _isPlayingAudio
                ? Tween<double>(begin: 1.0, end: 1.06).animate(_pulseController)
                : const AlwaysStoppedAnimation(1.0),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _playTargetAudio,
                borderRadius: BorderRadius.circular(buttonSize / 2),
                child: Container(
                  width: buttonSize,
                  height: buttonSize,
                  decoration: BoxDecoration(
                    color: _primaryColor,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        color: _primaryDark,
                        offset: Offset(0, 4),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Center(
                    child: FaIcon(
                      _isPlayingAudio
                          ? FontAwesomeIcons.volumeHigh
                          : FontAwesomeIcons.headphones,
                      size: iconSize,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: isDesktop ? 10 : 8),

          // Replay Prompt & Shortcut Hint
          InkWell(
            onTap: _playTargetAudio,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.volume_up_rounded,
                    size: 15,
                    color: _primaryColor,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Tekrar Dinle',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _primaryColor,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF26263A),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'SPACE',
                      style: GoogleFonts.outfit(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFCBD5E1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: isDesktop ? 12 : 8),

          // Reserved Stable Result / Tip Strip (prevents jumping!)
          _buildResultTipStrip(q, isDesktop),
        ],
      ),
    );
  }

  Widget _buildAudioCardHeader(SoundCatchQuestion q, bool isDesktop) {
    if (_isAnswerChecked && _feedbackText != null) {
      return FadeTransition(
        opacity: _feedbackAnimController,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: _feedbackColor.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _feedbackColor, width: 1.2),
          ),
          child: Text(
            _feedbackText!,
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: _feedbackColor,
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _primaryColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            q.level,
            style: GoogleFonts.outfit(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: _primaryColor,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            'Telaffuzu dinle, doğru kelimeyi seç',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultTipStrip(SoundCatchQuestion q, bool isDesktop) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: isDesktop ? 46 : 40,
      width: double.infinity,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: _isAnswerChecked
            ? const Color(0xFF18182A)
            : const Color(0xFF12121E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _isAnswerChecked
              ? (_selectedOption?.toLowerCase() == q.target.toLowerCase()
                  ? _greenColor.withValues(alpha: 0.4)
                  : _redColor.withValues(alpha: 0.4))
              : const Color(0xFF222234),
        ),
      ),
      child: _isAnswerChecked
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  q.target,
                  style: GoogleFonts.outfit(
                    fontSize: isDesktop ? 16 : 14.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '➜  ${q.meaning}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: isDesktop ? 14.5 : 13.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF38BDF8),
                    ),
                  ),
                ),
                if (q.tip != null && q.tip!.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Tooltip(
                    message: q.tip!,
                    triggerMode: TooltipTriggerMode.tap,
                    child: const Icon(
                      Icons.lightbulb_rounded,
                      size: 15,
                      color: Color(0xFFFBBF24),
                    ),
                  ),
                ],
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.headphones_rounded,
                  size: 13,
                  color: Color(0xFF64748B),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    'Sesi dinleyip doğru kelimeye dokunun',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildOptionButton({
    required int index,
    required String text,
    required String shortcutLabel,
    bool isMobileGrid = false,
  }) {
    final q = _currentQuestion;
    final isTarget = q != null && text.toLowerCase() == q.target.toLowerCase();
    final isSelected = _selectedOption == text;

    Color bgColor = _cardBgDark;
    Color lipColor = const Color(0xFF0D0D17);
    Color borderColor = const Color(0xFF2E2E48);
    Color textColor = Colors.white;

    if (_isAnswerChecked) {
      if (isTarget) {
        bgColor = _greenColor;
        lipColor = _greenDark;
        borderColor = _greenDark;
        textColor = Colors.white;
      } else if (isSelected) {
        bgColor = _redColor;
        lipColor = _redDark;
        borderColor = _redDark;
        textColor = Colors.white;
      } else {
        textColor = const Color(0xFF64748B);
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isAnswerChecked ? null : () => _handleOptionSelect(text),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            horizontal: isMobileGrid ? 10 : 14,
            vertical: isMobileGrid ? 8 : 12,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 2),
            boxShadow: [
              BoxShadow(
                color: lipColor,
                offset: const Offset(0, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: Row(
            children: [
              // Keyboard shortcut chip
              Container(
                width: isMobileGrid ? 22 : 26,
                height: isMobileGrid ? 22 : 26,
                decoration: BoxDecoration(
                  color: _isAnswerChecked && (isTarget || isSelected)
                      ? Colors.black.withValues(alpha: 0.25)
                      : const Color(0xFF25253A),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    shortcutLabel,
                    style: GoogleFonts.outfit(
                      fontSize: isMobileGrid ? 11 : 12.5,
                      fontWeight: FontWeight.w800,
                      color: _isAnswerChecked && (isTarget || isSelected)
                          ? Colors.white
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ),
              SizedBox(width: isMobileGrid ? 8 : 12),

              // Option word with FittedBox to prevent any overflow on small screens
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    text,
                    style: GoogleFonts.outfit(
                      fontSize: isMobileGrid ? 16 : 18,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),

              // Icon indicator when answered
              if (_isAnswerChecked && isTarget)
                Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: isMobileGrid ? 18 : 22,
                )
              else if (_isAnswerChecked && isSelected)
                Icon(
                  Icons.cancel_rounded,
                  color: Colors.white,
                  size: isMobileGrid ? 18 : 22,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(bool isCompact) {
    final shortcuts = ['A', 'B', 'C', 'D'];

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 10 : 16,
        vertical: 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTopStatBar(),
          const SizedBox(height: 8),
          _buildAudioListenCard(isDesktop: false),
          const SizedBox(height: 12),

          // 2x2 Options Grid on Mobile - fits 9:16 portrait viewports cleanly without scrolling!
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: isCompact ? 2.5 : 2.7,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _currentOptions.length,
            itemBuilder: (context, index) {
              return _buildOptionButton(
                index: index,
                text: _currentOptions[index],
                shortcutLabel: shortcuts[index % shortcuts.length],
                isMobileGrid: true,
              );
            },
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    final shortcuts = ['1', '2', '3', '4'];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildTopStatBar(),
          const SizedBox(height: 14),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Listening Audio Card & Options
                Expanded(
                  flex: 6,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildAudioListenCard(isDesktop: true),
                        const SizedBox(height: 14),

                        // 2x2 Grid for Options on Desktop
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 3.2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: _currentOptions.length,
                          itemBuilder: (context, index) {
                            return _buildOptionButton(
                              index: index,
                              text: _currentOptions[index],
                              shortcutLabel:
                                  shortcuts[index % shortcuts.length],
                              isMobileGrid: false,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20),

                // Right Column: Live Session Stats & Phonetic Info
                Expanded(
                  flex: 4,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _cardBgDark,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF28283C),
                        width: 1.5,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0xFF0C0C16),
                          offset: Offset(0, 4),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const FaIcon(
                              FontAwesomeIcons.circleInfo,
                              size: 16,
                              color: _primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Oturum İlerlemesi',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _buildDesktopStatTile(
                          icon: Icons.check_circle_rounded,
                          iconColor: const Color(0xFF10B981),
                          label: 'Doğru Cevaplar',
                          value: '$_correctCount',
                        ),
                        const SizedBox(height: 10),
                        _buildDesktopStatTile(
                          icon: Icons.local_fire_department_rounded,
                          iconColor: _primaryColor,
                          label: 'En İyi Seri',
                          value: '$_maxStreak',
                        ),
                        const SizedBox(height: 10),
                        _buildDesktopStatTile(
                          icon: Icons.checklist_rounded,
                          iconColor: const Color(0xFF38BDF8),
                          label: 'Cevaplanan Kelimeler',
                          value: '${_sessionReviewItems.length}',
                        ),
                        const Divider(
                          color: Color(0xFF28283E),
                          height: 28,
                        ),
                        Text(
                          '💡 İpucu: İngilizce minimal çiftlerde (minimal pairs) sesler birbirine çok benzer (örn. sheep - ship, cat - cut, weather - whether). Telaffuzu dikkatle dinleyin, gerekirse Boşluk (Space) ile tekrar oynatın.',
                          style: GoogleFonts.outfit(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF94A3B8),
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopStatTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B2C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A40)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFCBD5E1),
                ),
              ),
            ],
          ),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameOverView(bool isDesktop) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isDesktop ? 680 : 440,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _cardBgDark,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF2E2E48), width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0xFF0C0C16),
                  offset: Offset(0, 5),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: _primaryColor.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: FaIcon(
                      FontAwesomeIcons.headphones,
                      size: 34,
                      color: _primaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Oyun Bitti',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sound Catch performans özeti',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 20),

                // Stats Cards
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B1B2C),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF2C2C42)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Skor',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$_score',
                              style: GoogleFonts.outfit(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: _primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B1B2C),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF2C2C42)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'En İyi Seri',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$_maxStreak',
                              style: GoogleFonts.outfit(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Review items accordion
                if (_sessionReviewItems.isNotEmpty) ...[
                  GameReviewAccordion(
                    items: _sessionReviewItems,
                    accentColor: _primaryColor,
                  ),
                  const SizedBox(height: 20),
                ],

                // Action Buttons (Tactile 3D style)
                Row(
                  children: [
                    // Back to Games
                    Expanded(
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF25253A),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0xFF141422),
                                offset: Offset(0, 4),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              'Ana Menü',
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFCBD5E1),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Play Again
                    Expanded(
                      child: InkWell(
                        onTap: _startNewGame,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _primaryColor,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: const [
                              BoxShadow(
                                color: _primaryDark,
                                offset: Offset(0, 4),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.replay_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Tekrar Oyna',
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
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
}
