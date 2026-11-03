import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/word_defuser_data.dart';
import '../services/audio_service.dart';
import '../services/tts_service.dart';
import '../widgets/game_tutorial_popup.dart';
import '../widgets/exit_confirmation_dialog.dart';
import '../services/level_service.dart';
import '../widgets/level_selection_dialog.dart';
import '../widgets/marquee_title.dart';
import '../services/mistake_service.dart';
import '../services/score_service.dart';
import '../models/game_review_item.dart';
import '../widgets/game_review_accordion.dart';

enum _RoundState { playing, defused, exploded }

class _Mistake {
  final String prompt;
  final String note;
  const _Mistake(this.prompt, this.note);
}

class WordDefuserScreen extends StatefulWidget {
  const WordDefuserScreen({super.key});

  @override
  State<WordDefuserScreen> createState() => _WordDefuserScreenState();
}

class _WordDefuserScreenState extends State<WordDefuserScreen>
    with TickerProviderStateMixin {
  static const List<Color> _wireColors = [
    Color(0xFFEF4444), // red
    Color(0xFF3B82F6), // blue
    Color(0xFFEAB308), // yellow
    Color(0xFF22C55E), // green
  ];
  static const Color _green = Color(0xFF10B981);
  static const Color _red = Color(0xFFEF4444);

  final FocusNode _focusNode = FocusNode();
  final Random _random = Random();

  late AnimationController _timerController;
  late AnimationController _shakeController;

  // --- Round state ---
  final List<DefuserQuestion> _deck = [];
  DefuserQuestion? _question;
  List<String> _options = const [];
  int _correctIndex = 0;
  int? _cutIndex;
  _RoundState _roundState = _RoundState.playing;

  // --- Game state ---
  int _score = 0;
  int _streak = 0;
  int _maxStreak = 0;
  int _lives = 3;
  int _defused = 0;
  int _lastPoints = 0;
  bool _isGameOver = false;
  bool _ready = false; // false until tutorial is dismissed
  bool _flash = false;
  final List<_Mistake> _mistakes = [];
  final List<GameReviewItem> _sessionReviewItems = [];
  GameDifficulty _difficulty = LevelService.instance.currentDifficulty;

  List<DefuserQuestion> _getFilteredQuestions() {
    if (_difficulty == GameDifficulty.all) return WordDefuserData.questions;
    final filtered = WordDefuserData.questions.where((q) {
      final key = q.target ?? q.correct;
      return LevelService.instance.getWordDifficulty(key) == _difficulty;
    }).toList();
    return filtered.length >= 8 ? filtered : WordDefuserData.questions;
  }

  void _updateDifficulty(GameDifficulty newDiff) {
    setState(() {
      _difficulty = newDiff;
      LevelService.instance.setDifficulty(newDiff);
      _score = 0;
      _streak = 0;
      _maxStreak = 0;
      _lives = 3;
      _defused = 0;
      _isGameOver = false;
      _ready = true;
      _mistakes.clear();
      _sessionReviewItems.clear();
      _deck.clear();
      _newQuestion(startTimer: true);
    });
  }

  /// Fuse gets shorter as more bombs are defused.
  double get _roundSeconds => max(4.5, 10.0 - _defused * 0.35);

  @override
  void initState() {
    super.initState();
    _timerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) _onTimeout();
      });

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _newQuestion(startTimer: false);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _focusNode.requestFocus();
      final result = await GameTutorialPopup.show(
        context,
        tutorialKey: 'word_defuser_tutorial',
        title: 'Word Defuser',
        icon: FontAwesomeIcons.bomb,
        color: _red,
        tutorialTextTr:
            'Word Defuser oyununda zamana karşı bomba imha uzmanısınız! Paneldeki göreve göre doğru kabloyu seçip kesin:\n\n'
            '• SPELLING: Yanlış yazılmış İngilizce kelimeye bağlı kabloyu kesin.\n'
            '• ANTONYM: Verilen kelimenin zıt anlamlısını kesin.\n'
            '• SYNONYM: Verilen kelimenin eş anlamlısını kesin.\n'
            '• MEANING: Türkçe karşılığı verilen kelimeyi kesin.\n\n'
            'Kabloya doğrudan dokunabilir veya klavyeden [1-4] tuşlarını kullanabilirsiniz. Yanlış kabloyu kesmek veya sürenin bitmesi bombayı patlatır! Toplam 3 patlama hakkınız vardır.',
        tutorialTextEn:
            'You are the bomb squad! Cut the right wire according to the task:\n\n'
            '• SPELLING: Cut the misspelled word.\n'
            '• ANTONYM: Cut the opposite.\n'
            '• SYNONYM: Cut the word with the same meaning.\n'
            '• MEANING: Cut the English word for the Turkish meaning.\n\n'
            'Tap a wire or press keys 1–4. Wrong wire or time out = BOOM! Three explosions and the game is over.',
        includeLevelSelection: true,
        initialDifficulty: _difficulty,
      );
      if (!mounted) return;
      if (result.difficulty != null) {
        _updateDifficulty(result.difficulty!);
      } else {
        setState(() => _ready = true);
        _timerController.forward(from: 0.0);
      }
    });
  }

  @override
  void dispose() {
    TtsService.instance.stop();
    _timerController.dispose();
    _shakeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ───────────────────────── Game logic ─────────────────────────

  void _newQuestion({bool startTimer = true}) {
    if (_deck.isEmpty) {
      _deck.addAll(_getFilteredQuestions());
      _deck.shuffle(_random);
    }
    final q = _deck.removeLast();
    final opts = [q.correct, ...q.wrong]..shuffle(_random);

    _question = q;
    _options = opts;
    _correctIndex = opts.indexOf(q.correct);
    _cutIndex = null;
    _roundState = _RoundState.playing;

    _timerController.duration =
        Duration(milliseconds: (_roundSeconds * 1000).round());
    if (startTimer) {
      _timerController.forward(from: 0.0);
    } else {
      _timerController.reset();
    }
  }

  void _cutWire(int index) {
    if (_isGameOver ||
        !_ready ||
        _roundState != _RoundState.playing ||
        index >= _options.length) {
      return;
    }
    _timerController.stop();
    HapticFeedback.mediumImpact();
    setState(() => _cutIndex = index);

    if (index == _correctIndex) {
      _onDefused();
    } else {
      _onExplode();
    }
  }

  void _onTimeout() {
    if (_roundState != _RoundState.playing || _isGameOver) return;
    _onExplode();
  }

  void _onDefused() {
    AudioService.playCorrect();
    final q = _question;
    if (q != null) {
      final toSpeak = (q.type == DefuserType.misspelled && q.note != null)
          ? q.note!
          : q.correct;
      TtsService.instance.speak(toSpeak);
      _sessionReviewItems.add(GameReviewItem(
        word: q.target ?? q.correct,
        meaning: _noteFor(q),
        question: '${_instructionTr(q.type)}: ${_promptLine(q)}',
        userAnswer: q.correct,
        correctAnswer: q.correct,
        isCorrect: true,
      ));
    }
    final double remaining = _timerController.duration!.inMilliseconds *
        (1 - _timerController.value) /
        1000;
    final double multiplier = _streak >= 10
        ? 3.0
        : _streak >= 6
            ? 2.0
            : _streak >= 3
                ? 1.5
                : 1.0;
    final int points = ((100 + remaining * 20) * multiplier).round();

    setState(() {
      _score += points;
      _lastPoints = points;
      _streak += 1;
      _maxStreak = max(_maxStreak, _streak);
      _defused += 1;
      _roundState = _RoundState.defused;
    });

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted && !_isGameOver) setState(() => _newQuestion());
    });
  }

  void _onExplode() {
    final q = _question;
    if (q == null) return;

    AudioService.playIncorrect();
    final toSpeak = (q.type == DefuserType.misspelled && q.note != null)
        ? q.note!
        : q.correct;
    TtsService.instance.speak(toSpeak);

    HapticFeedback.heavyImpact();
    _shakeController.forward(from: 0.0);

    setState(() {
      _lives -= 1;
      _streak = 0;
      _roundState = _RoundState.exploded;
      _flash = true;
      _mistakes.add(_Mistake(_promptLine(q), _noteFor(q)));
    });

    final String wrongWord = (_cutIndex != null && _cutIndex! < _options.length)
        ? _options[_cutIndex!]
        : 'Süre Doldu';
    final String targetWord =
        q.target != null ? '${q.target} (${q.correct})' : q.correct;
    MistakeService.instance.recordMistake(
      word: targetWord,
      meaning: _noteFor(q),
      sourceGame: 'Word Defuser',
      wrongAnswer: wrongWord,
    );

    _sessionReviewItems.add(GameReviewItem(
      word: q.target ?? q.correct,
      meaning: _noteFor(q),
      question: '${_instructionTr(q.type)}: ${_promptLine(q)}',
      userAnswer: wrongWord,
      correctAnswer: q.correct,
      isCorrect: false,
      note: _noteFor(q),
    ));

    Future.delayed(const Duration(milliseconds: 220), () {
      if (mounted) setState(() => _flash = false);
    });

    if (_lives <= 0) {
      Future.delayed(const Duration(milliseconds: 1400), () async {
        if (!mounted) return;
        AudioService.playFailure();
        await ScoreService.instance.recordScore(
          gameId: 'word_defuser',
          score: _score,
          streak: _maxStreak,
        );
        if (mounted) {
          setState(() {
            _isGameOver = true;
          });
        }
      });
    } else {
      Future.delayed(const Duration(milliseconds: 1900), () {
        if (mounted && !_isGameOver) setState(() => _newQuestion());
      });
    }
  }

  void _restart() {
    setState(() {
      _score = 0;
      _streak = 0;
      _maxStreak = 0;
      _lives = 3;
      _defused = 0;
      _lastPoints = 0;
      _isGameOver = false;
      _flash = false;
      _mistakes.clear();
      _sessionReviewItems.clear();
      _deck.clear();
      _newQuestion();
    });
  }

  // ───────────────────────── Text helpers ─────────────────────────

  String _typeLabel(DefuserType t) => switch (t) {
        DefuserType.misspelled => 'SPELLING',
        DefuserType.antonym => 'ANTONYM',
        DefuserType.synonym => 'SYNONYM',
        DefuserType.meaning => 'MEANING',
      };

  Color _typeAccentColor(DefuserType t) => switch (t) {
        DefuserType.misspelled => const Color(0xFFF43F5E), // Coral Rose
        DefuserType.antonym => const Color(0xFFFB923C),    // Vivid Orange
        DefuserType.synonym => const Color(0xFF34D399),    // Emerald Green
        DefuserType.meaning => const Color(0xFF38BDF8),    // Cyan / Sky Blue
      };

  Widget _buildInstructionPrompt(DefuserQuestion q) {
    final Color accent = _typeAccentColor(q.type);

    InlineSpan enSpan;
    InlineSpan trSpan;

    switch (q.type) {
      case DefuserType.misspelled:
        enSpan = TextSpan(
          children: [
            const TextSpan(text: 'Cut the '),
            TextSpan(
              text: 'MISSPELLED',
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
            const TextSpan(text: ' word'),
          ],
        );
        trSpan = TextSpan(
          children: [
            TextSpan(
              text: 'YANLIŞ YAZILMIŞ',
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w800,
              ),
            ),
            const TextSpan(text: ' kelimenin kablosunu kes'),
          ],
        );
        break;

      case DefuserType.antonym:
        enSpan = TextSpan(
          children: [
            const TextSpan(text: 'Cut the '),
            TextSpan(
              text: 'OPPOSITE',
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
            const TextSpan(text: ' of'),
          ],
        );
        trSpan = TextSpan(
          children: [
            TextSpan(
              text: 'ZIT ANLAMLISININ',
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w800,
              ),
            ),
            const TextSpan(text: ' kablosunu kes'),
          ],
        );
        break;

      case DefuserType.synonym:
        enSpan = TextSpan(
          children: [
            const TextSpan(text: 'Cut the '),
            TextSpan(
              text: 'SYNONYM',
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
            const TextSpan(text: ' of'),
          ],
        );
        trSpan = TextSpan(
          children: [
            TextSpan(
              text: 'EŞ ANLAMLISININ',
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w800,
              ),
            ),
            const TextSpan(text: ' kablosunu kes'),
          ],
        );
        break;

      case DefuserType.meaning:
        enSpan = TextSpan(
          children: [
            const TextSpan(text: 'Cut the word that '),
            TextSpan(
              text: 'MEANS',
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ],
        );
        trSpan = TextSpan(
          children: [
            const TextSpan(text: 'Bu '),
            TextSpan(
              text: 'ANLAMA GELEN',
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w800,
              ),
            ),
            const TextSpan(text: ' kelimenin kablosunu kes'),
          ],
        );
        break;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: Colors.white,
            ),
            children: [enSpan],
          ),
        ),
        const SizedBox(height: 3),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              color: Colors.white70,
            ),
            children: [trSpan],
          ),
        ),
        if (q.target != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: accent.withValues(alpha: 0.45),
                width: 1.5,
              ),
            ),
            child: Text(
              q.target!,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: q.type == DefuserType.meaning ? 19 : 28,
                fontWeight: FontWeight.w900,
                color: const Color(0xFFFBBF24),
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _instructionTr(DefuserType t) => switch (t) {
        DefuserType.misspelled => 'Yanlış yazılmış kelimenin kablosunu kes',
        DefuserType.antonym => 'Zıt anlamlısının kablosunu kes',
        DefuserType.synonym => 'Eş anlamlısının kablosunu kes',
        DefuserType.meaning => 'Bu anlama gelen kelimenin kablosunu kes',
      };

  String _promptLine(DefuserQuestion q) => switch (q.type) {
        DefuserType.misspelled => 'Spelling',
        DefuserType.antonym => 'Opposite of ${q.target}',
        DefuserType.synonym => 'Synonym of ${q.target}',
        DefuserType.meaning => '"${q.target}"',
      };

  String _noteFor(DefuserQuestion q) => switch (q.type) {
        DefuserType.misspelled => '${q.correct} ✗  →  ${q.note} ✓',
        DefuserType.antonym => '${q.target} ↔ ${q.correct}',
        DefuserType.synonym => '${q.target} = ${q.correct}',
        DefuserType.meaning => q.note ?? '${q.correct} = ${q.target}',
      };

  // ───────────────────────── Input ─────────────────────────

  static final Map<LogicalKeyboardKey, int> _keyMap = {
    LogicalKeyboardKey.digit1: 0,
    LogicalKeyboardKey.numpad1: 0,
    LogicalKeyboardKey.digit2: 1,
    LogicalKeyboardKey.numpad2: 1,
    LogicalKeyboardKey.digit3: 2,
    LogicalKeyboardKey.numpad3: 2,
    LogicalKeyboardKey.digit4: 3,
    LogicalKeyboardKey.numpad4: 3,
  };

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (_isGameOver) {
      if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) {
        _restart();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    final idx = _keyMap[key];
    if (idx != null) {
      _cutWire(idx);
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

  // ───────────────────────── UI ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleExit();
      },
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKey,
        child: Scaffold(
          backgroundColor:
              isDark ? const Color(0xFF0B0F19) : const Color(0xFFF1F5F9),
          appBar: _buildAppBar(isDark),
          body: Stack(
            children: [
              SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: AnimatedBuilder(
                      animation: _shakeController,
                      builder: (context, child) {
                        final t = _shakeController.value;
                        final dx = sin(t * pi * 8) * 10 * (1 - t);
                        return Transform.translate(
                            offset: Offset(dx, 0), child: child);
                      },
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                        child: Column(
                          children: [
                            _buildHeader(isDark),
                            const SizedBox(height: 14),
                            _buildBombPanel(),
                            const SizedBox(height: 18),
                            for (int i = 0; i < _options.length; i++) ...[
                              _buildWire(i, isDark),
                              const SizedBox(height: 10),
                            ],
                            const SizedBox(height: 4),
                            _buildStatusBanner(isDark),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Red explosion flash
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _flash ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Container(color: _red.withValues(alpha: 0.28)),
                  ),
                ),
              ),

              if (_isGameOver) _buildGameOverOverlay(isDark),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : Colors.black87),
        onPressed: _handleExit,
      ),
      title: MarqueeTitle(
        title: 'Word Defuser',
        leadingIcon: const Icon(FontAwesomeIcons.bomb, color: _red, size: 18),
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.bold,
          fontSize: 20,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      actions: [
        LevelBadgeButton(
          difficulty: _difficulty,
          accentColor: _red,
          onTap: () async {
            final wasAnimating = _timerController.isAnimating;
            _timerController.stop();
            final chosen = await LevelSelectionDialog.show(
              context,
              initialDifficulty: _difficulty,
              accentColor: _red,
              title: 'Word Defuser: Seviye Değiştir',
            );
            if (chosen != null && mounted) {
              _updateDifficulty(chosen);
            } else if (wasAnimating && mounted && !_isGameOver) {
              _timerController.forward();
            }
          },
        ),
      ],
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161E31) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          _stat('SCORE', '$_score', isDark),
          const SizedBox(width: 20),
          _stat('DEFUSED', '$_defused', isDark),
          const Spacer(),
          if (_streak >= 3)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final alive = i < _lives;
              return Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(
                  alive
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: alive ? _red : Colors.grey.withValues(alpha: 0.4),
                  size: 22,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildBombPanel() {
    final q = _question;
    if (q == null) return const SizedBox.shrink();

    final Color borderColor = switch (_roundState) {
      _RoundState.playing => const Color(0xFF374151),
      _RoundState.defused => _green,
      _RoundState.exploded => _red,
    };

    return AnimatedBuilder(
      animation: _timerController,
      builder: (context, _) {
        final totalSec = _timerController.duration!.inMilliseconds / 1000;
        final remaining =
            (totalSec * (1 - _timerController.value)).clamp(0.0, 99.0);
        final bool playing = _roundState == _RoundState.playing;
        final bool urgent = playing && remaining < 3;
        final bool blinkOn = (remaining * (urgent ? 4 : 2)).floor() % 2 == 0;
        final Color ledColor =
            _roundState == _RoundState.defused ? _green : _red;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor, width: 2),
          ),
          child: Column(
            children: [
              // Top row: status LED + device id + type chip
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: playing
                          ? (blinkOn ? _red : _red.withValues(alpha: 0.25))
                          : ledColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'DEVICE #${(_defused + 1).toString().padLeft(2, '0')}',
                    style: GoogleFonts.robotoMono(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white54,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _typeAccentColor(q.type).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _typeAccentColor(q.type).withValues(alpha: 0.5),
                        width: 1.2,
                      ),
                    ),
                    child: Text(
                      _typeLabel(q.type),
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                        color: _typeAccentColor(q.type),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // LED countdown
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF030712),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Opacity(
                  opacity: urgent && !blinkOn ? 0.45 : 1,
                  child: Text(
                    _roundState == _RoundState.exploded
                        ? 'BOOM!'
                        : remaining.toStringAsFixed(2).padLeft(5, '0'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.robotoMono(
                      fontSize: 44,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4,
                      color: ledColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: 1 - _timerController.value,
                  minHeight: 4,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation(ledColor),
                ),
              ),
              const SizedBox(height: 16),

              // Task instruction with highlighted colored markers
              _buildInstructionPrompt(q),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWire(int i, bool isDark) {
    final color = _wireColors[i];
    final bool isCut = _cutIndex == i;
    final bool reveal = _roundState == _RoundState.exploded && i == _correctIndex;
    final bool dim = _roundState != _RoundState.playing && !isCut && !reveal;

    Color pillFill = isDark ? const Color(0xFF0B0F19) : Colors.white;
    Color pillText = isDark ? Colors.white : const Color(0xFF0F172A);
    if (isCut) {
      pillFill = i == _correctIndex ? _green : _red;
      pillText = Colors.white;
    }

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: dim ? 0.4 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _cutWire(i),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 66,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161E31) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: reveal
                    ? _green
                    : (isDark
                        ? const Color(0xFF28354E)
                        : Colors.black.withValues(alpha: 0.10)),
                width: reveal ? 2 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: reveal
                      ? const Color(0xFF047857)
                      : (isDark
                          ? const Color(0xFF090D16)
                          : const Color(0xFFCBD5E1)),
                  offset: const Offset(0, 4),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Row(
              children: [
                _terminal(
                  child: Text(
                    '${i + 1}',
                    style: GoogleFonts.robotoMono(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white70,
                    ),
                  ),
                ),
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _WirePainter(
                            color: color,
                            isCut: isCut,
                            phase: i * 1.3,
                          ),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: pillFill,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isCut ? pillFill : color,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              offset: const Offset(0, 3),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Text(
                          _options[i],
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: pillText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _terminal(
                  child: Icon(
                    isCut ? FontAwesomeIcons.scissors : Icons.bolt_rounded,
                    size: 13,
                    color: isCut ? color : Colors.white54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _terminal({required Widget child}) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }

  Widget _buildStatusBanner(bool isDark) {
    final q = _question;
    late final Widget content;
    late final Key key;

    switch (_roundState) {
      case _RoundState.playing:
        key = const ValueKey('playing');
        content = Text(
          'Doğru kabloya dokun ya da 1–4 tuşlarına bas',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        );
      case _RoundState.defused:
        key = const ValueKey('defused');
        content = _pill('DEFUSED!  +$_lastPoints', _green);
      case _RoundState.exploded:
        key = const ValueKey('exploded');
        content = _pill(q == null ? 'BOOM!' : 'BOOM!  ${_noteFor(q)}', _red);
    }

    return SizedBox(
      height: 48,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: KeyedSubtree(key: key, child: content),
        ),
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildGameOverOverlay(bool isDark) {
    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          color: Colors.black.withValues(alpha: 0.7),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131B2E) : Colors.white,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: _red.withValues(alpha: 0.5), width: 2),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _red.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(FontAwesomeIcons.burst,
                          color: _red, size: 40),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'BOMBA PATLADI!',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1A233A)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _overStat('SCORE', '$_score', Colors.amber),
                          _overStat('DEFUSED', '$_defused', _green),
                          _overStat('STREAK', '$_maxStreak',
                              const Color(0xFFF97316)),
                        ],
                      ),
                    ),
                    if (_sessionReviewItems.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      GameReviewAccordion(
                        items: _sessionReviewItems,
                        accentColor: _red,
                      ),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Text('Ana Menü',
                                style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _restart,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Text('Yeniden Oyna',
                                style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold, fontSize: 15)),
                          ),
                        ),
                      ],
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

  Widget _overStat(String label, String value, Color color) {
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
}

/// Draws a slightly wavy wire; when cut, a gap with copper tips appears
/// on the left side (so it stays visible next to the word label).
class _WirePainter extends CustomPainter {
  final Color color;
  final bool isCut;
  final double phase;

  _WirePainter({required this.color, required this.isCut, required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final midY = size.height / 2;
    double yAt(double x) =>
        midY + sin(x / size.width * pi * 3 + phase) * 5;

    Path segment(double x0, double x1) {
      final p = Path()..moveTo(x0, yAt(x0));
      for (double x = x0 + 2; x < x1; x += 2) {
        p.lineTo(x, yAt(x));
      }
      p.lineTo(x1, yAt(x1));
      return p;
    }

    if (!isCut) {
      canvas.drawPath(segment(4, size.width - 4), paint);
      return;
    }

    final gapStart = size.width * 0.12;
    final gapEnd = size.width * 0.24;
    canvas.drawPath(segment(4, gapStart), paint);
    canvas.drawPath(segment(gapEnd, size.width - 4), paint);

    final copper = Paint()..color = const Color(0xFFD97706);
    canvas.drawCircle(Offset(gapStart, yAt(gapStart)), 3.5, copper);
    canvas.drawCircle(Offset(gapEnd, yAt(gapEnd)), 3.5, copper);
  }

  @override
  bool shouldRepaint(covariant _WirePainter old) =>
      old.color != color || old.isCut != isCut || old.phase != phase;
}
