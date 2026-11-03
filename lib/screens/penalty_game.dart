import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:audioplayers/audioplayers.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/penalty_game_data.dart';
import '../data/present_simple_data.dart';
import '../services/tts_service.dart';
import '../widgets/exit_confirmation_dialog.dart';
import '../services/level_service.dart';
import '../widgets/level_selection_dialog.dart';
import '../widgets/marquee_title.dart';
import '../services/mistake_service.dart';
import '../services/score_service.dart';
import '../models/game_review_item.dart';
import '../widgets/game_review_accordion.dart';

enum GameRole { goalkeeper, shooter }

enum TranslationMode { engToTur, turToEng }

enum GameState { setup, playing, gameOver }

enum RefereeCall { goal, yellowCard, redCard, saved }

class PenaltyGameScreen extends StatefulWidget {
  /// Present Simple etkinlik modu (boşluk doldurma soruları).
  final bool presentSimple;
  const PenaltyGameScreen({super.key, this.presentSimple = false});

  @override
  State<PenaltyGameScreen> createState() => _PenaltyGameScreenState();
}

class _PenaltyGameScreenState extends State<PenaltyGameScreen>
    with TickerProviderStateMixin {
  // Game Configuration States
  GameState _gameState = GameState.setup;
  GameRole _selectedRole = GameRole.shooter;
  TranslationMode _translationMode = TranslationMode.engToTur;
  String _selectedCategory = 'All';
  GameDifficulty _difficulty = LevelService.instance.currentDifficulty;

  void _updateDifficulty(GameDifficulty newDiff) {
    setState(() {
      _difficulty = newDiff;
      LevelService.instance.setDifficulty(newDiff);
      if (_gameState == GameState.playing) {
        _startGame();
      }
    });
  }

  // Present Simple mode
  bool get _ps => widget.presentSimple;
  PSTopic? _psTopic; // null = all
  List<PSQuizItem> _psList = [];
  PSQuizItem? _currentPs;
  int get _roundTime => _ps ? 15 : 10;

  // Gameplay Scores/Lives
  int _score = 0;
  int _streak = 0;
  int _bestStreak = 0;
  final List<GameReviewItem> _sessionReviewItems = [];
  int _cardsReceived = 0; // 1 = Yellow, 2 = 2x Yellow, 3 = Red (Game Over)
  int _timeLeft = 10;
  Timer? _countdownTimer;

  // Active Vocab Map
  List<MapEntry<String, String>> _vocabularyList = [];
  int _currentIndex = 0;
  String _questionWord = '';
  String _correctTranslation = '';
  List<String> _options = ['', '', '', ''];
  int _correctOptionIndex = 0;

  // Sound States
  bool _isMuted = false;
  final List<AudioPlayer> _players = [];
  final AudioPlayer _bgPlayer = AudioPlayer();

  // Animation States
  bool _isAnimating = false;
  bool _hasResponded = false;

  // Visual Positions & Asset states
  String _currentGkAsset =
      'assets/images/penaltygame/goalkeeper/gk_standing0.png';
  String _currentPlayerAsset =
      'assets/images/penaltygame/player/player_standing.png';

  // Ball animation coordinates
  double _ballAlignX = 0.0; // Center penalty spot
  double _ballAlignY =
      0.76; // Penalty spot - in front of kicker's feet (0.76 alignment corresponds to 88% height)
  double _ballScale = 1.0;
  double _ballOpacity = 1.0;

  double? _lastPitchWidth;
  double? _lastPitchHeight;
  double _goalHeight = 100.0; // Dynamic goal height in local pixels
  double _gkAlignX = 0.0; // Goalkeeper horizontal position (dives side to side)
  double _gkOffsetY = 0.0; // Goalkeeper vertical offset (dives up/down)
  double _gkAngle = 0.0; // Goalkeeper rotation angle (tilted dives)
  double _crossbarAlignY = -0.5; // Calculated dynamically in LayoutBuilder
  double _goalLineAlignY = 0.3; // Calculated dynamically in LayoutBuilder

  // Overlay triggers
  RefereeCall? _activeRefereeCall;
  bool _showOverlay = false;

  bool _setupGuideExpanded = true;
  bool _setupGuideIsTr = true;

  @override
  void initState() {
    super.initState();
    _bgPlayer.setReleaseMode(ReleaseMode.loop);
    _bgPlayer.setVolume(_isMuted ? 0.0 : 0.45);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precacheAssets();
  }

  void _precacheAssets() {
    final images = [
      'assets/images/penaltygame/goal/goal.png',
      'assets/images/penaltygame/goalkeeper/gk_standing0.png',
      'assets/images/penaltygame/goalkeeper/gk_diving_left.png',
      'assets/images/penaltygame/goalkeeper/gk_diving_right.png',
      'assets/images/penaltygame/goalkeeper/gk_diving_left_ball.png',
      'assets/images/penaltygame/goalkeeper/gk_diving_right_ball.png',
      'assets/images/penaltygame/player/player_standing.png',
      'assets/images/penaltygame/player/player_shooting_left.png',
      'assets/images/penaltygame/player/player_shooting_right.png',
      'assets/images/penaltygame/player/player_shoot_left.png',
      'assets/images/penaltygame/player/player_shoot_right.png',
      'assets/images/penaltygame/ball/ball.png',
      'assets/images/penaltygame/referee/referee_goal.png',
      'assets/images/penaltygame/referee/referee_yellow.png',
      'assets/images/penaltygame/referee/referee_red.png',
      'assets/images/penaltygame/referee/referee_end.png',
    ];
    for (var imgPath in images) {
      precacheImage(AssetImage(imgPath), context);
    }
  }

  @override
  void dispose() {
    TtsService.instance.stop();
    _countdownTimer?.cancel();
    for (var p in _players) {
      p.dispose();
    }
    _bgPlayer.dispose();
    super.dispose();
  }

  // --- Sound Effects Player ---
  Future<void> _playSound(String fileName, {double? volume}) async {
    if (_isMuted) return;
    try {
      final player = AudioPlayer();
      _players.add(player);
      player.onPlayerComplete.listen((_) {
        player.dispose();
        _players.remove(player);
      });

      Source source;
      if (fileName == 'wrong.mp3') {
        source = kIsWeb
            ? UrlSource('assets/assets/wrong.mp3')
            : AssetSource('wrong.mp3');
      } else {
        source = kIsWeb
            ? UrlSource('assets/assets/images/penaltygame/sounds/$fileName')
            : AssetSource('images/penaltygame/sounds/$fileName');
      }
      // Cheering sound is very loud by default, reduce to 20%
      final double targetVolume =
          volume ?? (fileName == 'cheering.mp3' ? 0.20 : 1.0);
      await player.setVolume(targetVolume);
      await player.play(source);
    } catch (e) {
      debugPrint("Audio Playback Error ($fileName): $e");
    }
  }

  Future<void> _startBackgroundMusic() async {
    try {
      await _bgPlayer.stop();
      final source = kIsWeb
          ? UrlSource('assets/assets/images/penaltygame/sounds/crowd.mp3')
          : AssetSource('images/penaltygame/sounds/crowd.mp3');
      await _bgPlayer.setVolume(_isMuted ? 0.0 : 0.45);
      await _bgPlayer.play(source);
    } catch (e) {
      debugPrint("BG Music Playback Error: $e");
    }
  }

  void _stopBackgroundMusic() {
    try {
      _bgPlayer.stop();
    } catch (e) {
      debugPrint("BG Music Stop Error: $e");
    }
  }

  // --- Game Controls ---
  void _startGame() {
    if (_ps) {
      _psList =
          psQuizItems
              .where((e) => _psTopic == null || e.topic == _psTopic)
              .toList()
            ..shuffle();
    }
    // Generate active vocab
    final List<MapEntry<String, String>> temp = [];
    if (_selectedCategory == 'All') {
      for (var cat in penaltyGameCategories.values) {
        temp.addAll(cat.entries);
      }
    } else {
      if (penaltyGameCategories.containsKey(_selectedCategory)) {
        temp.addAll(penaltyGameCategories[_selectedCategory]!.entries);
      }
    }
    List<MapEntry<String, String>> filtered = temp;
    if (_difficulty != GameDifficulty.all) {
      filtered = temp.where((entry) {
        return LevelService.instance.getWordDifficulty(entry.key) ==
            _difficulty;
      }).toList();
      if (filtered.length < 8) filtered = temp;
    }
    filtered.shuffle();
    _vocabularyList = filtered;

    if (_vocabularyList.isEmpty) {
      // Fallback
      _vocabularyList = [const MapEntry('apple', 'elma')];
    }

    setState(() {
      _gameState = GameState.playing;
      _score = 0;
      _streak = 0;
      _bestStreak = 0;
      _sessionReviewItems.clear();
      _cardsReceived = 0;
      _currentIndex = 0;
    });

    _startBackgroundMusic();
    _playSound('startwhistle.mp3');
    _nextRound();
  }

  void _nextRound() {
    if (_cardsReceived >= 3) {
      _endGame();
      return;
    }

    if (_ps) {
      if (_currentIndex >= _psList.length) {
        _psList.shuffle();
        _currentIndex = 0;
      }
      final item = _psList[_currentIndex];
      _currentPs = item;
      _questionWord = item.question;
      _correctTranslation = item.answer;
      final roundOptions = <String>[item.answer, ...item.wrong.take(3)]
        ..shuffle();
      _options = roundOptions;
      _correctOptionIndex = roundOptions.indexOf(item.answer);
      _resetRoundVisuals();
      _startCountdown();
      TtsService.instance.speak(_questionWord);
      return;
    }

    if (_currentIndex >= _vocabularyList.length) {
      _vocabularyList.shuffle();
      _currentIndex = 0;
    }

    final entry = _vocabularyList[_currentIndex];

    // Choose question depending on mode
    if (_translationMode == TranslationMode.engToTur) {
      _questionWord = entry.key.toUpperCase();
      _correctTranslation = entry.value;
    } else {
      _questionWord = entry.value.toUpperCase();
      _correctTranslation = entry.key;
    }

    // Generate distractors from the active list
    final allPossibleWrong = _vocabularyList
        .map(
          (e) => _translationMode == TranslationMode.engToTur ? e.value : e.key,
        )
        .where((val) => val.toLowerCase() != _correctTranslation.toLowerCase())
        .toList();

    allPossibleWrong.shuffle();
    final List<String> roundOptions = [];
    roundOptions.add(_correctTranslation);

    for (int i = 0; i < min(3, allPossibleWrong.length); i++) {
      roundOptions.add(allPossibleWrong[i]);
    }

    // Fallback if we don't have enough words
    while (roundOptions.length < 4) {
      roundOptions.add(
        _translationMode == TranslationMode.engToTur
            ? 'yanlış${roundOptions.length}'
            : 'wrong${roundOptions.length}',
      );
    }

    roundOptions.shuffle();
    _options = roundOptions;
    _correctOptionIndex = roundOptions.indexOf(_correctTranslation);

    _resetRoundVisuals();
    _startCountdown();
    TtsService.instance.speak(_questionWord);
  }

  void _resetRoundVisuals() {
    setState(() {
      // Reset position/animations
      _isAnimating = false;
      _hasResponded = false;
      _showOverlay = false;
      _activeRefereeCall = null;
      _timeLeft = _roundTime;
      _currentGkAsset = 'assets/images/penaltygame/goalkeeper/gk_standing0.png';
      _currentPlayerAsset =
          'assets/images/penaltygame/player/player_standing.png';
      _ballAlignX = 0.0;
      _ballAlignY = 0.76;
      _ballScale = 1.0;
      _ballOpacity = 1.0;
      _gkAlignX = 0.0;
      _gkOffsetY = 0.0;
      _gkAngle = 0.0;
    });
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    if (_ps) return; // Sınırsız süre
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_timeLeft > 1) {
            _timeLeft--;
          } else {
            _timeLeft = 0;
            _countdownTimer?.cancel();
            _handleTimeout();
          }
        });
      }
    });
  }

  void _resumeCountdown() {
    _countdownTimer?.cancel();
    if (_ps || _timeLeft <= 0 || _hasResponded || _gameState != GameState.playing) return;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_timeLeft > 1) {
            _timeLeft--;
          } else {
            _timeLeft = 0;
            _countdownTimer?.cancel();
            _handleTimeout();
          }
        });
      }
    });
  }

  void _handleTimeout() {
    if (_hasResponded) return;
    _hasResponded = true;
    _handleAction(selectedOptionIndex: null, isTimeout: true);
  }

  void _handleAnswer(int optionIndex) {
    if (_hasResponded || _isAnimating) return;
    _hasResponded = true;
    _countdownTimer?.cancel();
    _handleAction(selectedOptionIndex: optionIndex, isTimeout: false);
  }

  void _handleAction({
    required int? selectedOptionIndex,
    required bool isTimeout,
  }) {
    final bool isCorrect =
        selectedOptionIndex != null &&
        (selectedOptionIndex == _correctOptionIndex);

    final String qWord = _questionWord;
    final String cTrans = _correctTranslation;
    final String uAns = isTimeout
        ? 'Süre Doldu'
        : (selectedOptionIndex != null && selectedOptionIndex < _options.length
              ? _options[selectedOptionIndex]
              : 'Boş');

    _sessionReviewItems.add(
      GameReviewItem(
        word: _ps
            ? (_currentPs?.question ?? qWord)
            : (_translationMode == TranslationMode.engToTur ? qWord : cTrans),
        meaning: _ps
            ? (_currentPs?.answer ?? cTrans)
            : (_translationMode == TranslationMode.engToTur ? cTrans : qWord),
        question: qWord,
        userAnswer: uAns,
        correctAnswer: cTrans,
        isCorrect: isCorrect,
        note: _ps && _currentPs != null ? _currentPs!.hint : null,
      ),
    );

    if (!isCorrect) {
      if (_ps && _currentPs != null) {
        MistakeService.instance.recordMistake(
          word: _currentPs!.question,
          meaning: _currentPs!.answer,
          sourceGame: 'Word Penalty',
          wrongAnswer:
              selectedOptionIndex != null &&
                  selectedOptionIndex < _options.length
              ? _options[selectedOptionIndex]
              : (isTimeout ? 'Süre Doldu' : null),
        );
      } else if (_currentIndex < _vocabularyList.length) {
        final entry = _vocabularyList[_currentIndex];
        final String engWord = entry.key;
        final String trMeaning = entry.value;
        final String? wrongChoice =
            selectedOptionIndex != null && selectedOptionIndex < _options.length
            ? _options[selectedOptionIndex]
            : (isTimeout ? 'Süre Doldu' : null);
        MistakeService.instance.recordMistake(
          word: engWord,
          meaning: trMeaning,
          sourceGame: 'Word Penalty',
          wrongAnswer: wrongChoice,
        );
      }
    }

    setState(() {
      _isAnimating = true;
    });

    if (_selectedRole == GameRole.shooter) {
      _animateShooterRole(isCorrect, selectedOptionIndex ?? 0);
    } else {
      _animateGoalkeeperRole(isCorrect, selectedOptionIndex, isTimeout);
    }
  }

  // --- SHOOTER ROLE LOGIC ---
  void _animateShooterRole(bool isCorrect, int selectedOptionIndex) {
    final bool shootLeft =
        (selectedOptionIndex == 0 || selectedOptionIndex == 1);
    final bool shootTop =
        (selectedOptionIndex == 0 || selectedOptionIndex == 2);

    // Determine goalkeeper dive target corner
    int gkDiveCorner;
    if (isCorrect) {
      // GK dives to opposite corner (Wrong side -> Goal!)
      gkDiveCorner = 3 - selectedOptionIndex;
    } else {
      // GK dives to selected corner (Correct side -> Save!)
      gkDiveCorner = selectedOptionIndex;
    }

    final bool gkDiveLeft = (gkDiveCorner == 0 || gkDiveCorner == 1);
    final bool gkDiveTop = (gkDiveCorner == 0 || gkDiveCorner == 2);

    // Step 1: Kicker kicks
    setState(() {
      _currentPlayerAsset = shootLeft
          ? 'assets/images/penaltygame/player/player_shooting_left.png'
          : 'assets/images/penaltygame/player/player_shooting_right.png';
    });

    Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _currentPlayerAsset = shootLeft
            ? 'assets/images/penaltygame/player/player_shoot_left.png'
            : 'assets/images/penaltygame/player/player_shoot_right.png';

        // Ball moves to the targeted corner
        _ballAlignX = shootLeft ? -0.55 : 0.55;
        _ballAlignY = shootTop
            ? (_crossbarAlignY + 0.10)
            : (_goalLineAlignY - 0.12);
        _ballScale = 0.45;

        // Goalkeeper dives to gkDiveCorner
        _gkAlignX = gkDiveLeft ? -0.45 : 0.45;
        _gkOffsetY = gkDiveTop ? -_goalHeight * 0.25 : _goalHeight * 0.05;
        _gkAngle = gkDiveLeft
            ? (gkDiveTop ? pi / 6 : pi / 12)
            : (gkDiveTop ? -pi / 6 : -pi / 12);

        if (isCorrect) {
          // Goalkeeper dives to the WRONG side (Goal!)
          _currentGkAsset = gkDiveLeft
              ? 'assets/images/penaltygame/goalkeeper/gk_diving_left.png'
              : 'assets/images/penaltygame/goalkeeper/gk_diving_right.png';
        } else {
          // Goalkeeper dives to the CORRECT side (Catches the ball!)
          _currentGkAsset = gkDiveLeft
              ? 'assets/images/penaltygame/goalkeeper/gk_diving_left_ball.png'
              : 'assets/images/penaltygame/goalkeeper/gk_diving_right_ball.png';
          _ballOpacity = 0.0; // Fade the ball out as goalkeeper catches it
        }
      });

      Timer(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        if (isCorrect) {
          // GOAL!
          _score += 10;
          _streak++;
          if (_streak > _bestStreak) _bestStreak = _streak;
          _playSound('ballhitsnetgoal.mp3');
          _playSound('cheering.mp3', volume: 0.20);
          _playSound('goalwhistle.mp3');
          _showRefereeOverlay(RefereeCall.goal);
        } else {
          // SAVED BY GK (Kicker missed / got yellow card)
          _streak = 0;
          _cardsReceived++;
          _playSound('cardwhistle.mp3');
          _playSound('wrong.mp3');
          _showRefereeOverlay(
            _cardsReceived >= 3 ? RefereeCall.redCard : RefereeCall.yellowCard,
          );
        }
      });
    });
  }

  // --- GOALKEEPER ROLE LOGIC ---
  void _animateGoalkeeperRole(
    bool isCorrect,
    int? selectedOptionIndex,
    bool isTimeout,
  ) {
    // If correct: GK saves ball. If incorrect/timeout: Opponent scores.
    final int gkDiveCorner =
        selectedOptionIndex ?? 1; // Default to bottom-left if timeout
    final int opponentShootCorner = isCorrect
        ? gkDiveCorner
        : (3 - gkDiveCorner);

    final bool shootLeft =
        (opponentShootCorner == 0 || opponentShootCorner == 1);
    final bool shootTop =
        (opponentShootCorner == 0 || opponentShootCorner == 2);

    final bool gkDiveLeft = (gkDiveCorner == 0 || gkDiveCorner == 1);
    final bool gkDiveTop = (gkDiveCorner == 0 || gkDiveCorner == 2);

    // Step 1: Opponent kicker winds up for the shot
    setState(() {
      _currentPlayerAsset = shootLeft
          ? 'assets/images/penaltygame/player/player_shooting_left.png'
          : 'assets/images/penaltygame/player/player_shooting_right.png';
    });

    Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        // Step 2: Kicker shoots (follow-through frame)
        _currentPlayerAsset = shootLeft
            ? 'assets/images/penaltygame/player/player_shoot_left.png'
            : 'assets/images/penaltygame/player/player_shoot_right.png';

        // Ball shoots from penalty spot towards the corner
        _ballAlignX = shootLeft ? -0.55 : 0.55;
        _ballAlignY = shootTop
            ? (_crossbarAlignY + 0.10)
            : (_goalLineAlignY - 0.12);
        _ballScale = 0.45;

        if (isTimeout) {
          // Did not dive, GK remains standing, ball goes in
          _currentGkAsset =
              'assets/images/penaltygame/goalkeeper/gk_standing0.png';
          _gkAlignX = 0.0;
          _gkOffsetY = 0.0;
          _gkAngle = 0.0;
        } else {
          // GK dives to the selected side
          _gkAlignX = gkDiveLeft ? -0.45 : 0.45;
          _gkOffsetY = gkDiveTop ? -_goalHeight * 0.25 : _goalHeight * 0.05;
          _gkAngle = gkDiveLeft
              ? (gkDiveTop ? pi / 6 : pi / 12)
              : (gkDiveTop ? -pi / 6 : -pi / 12);

          if (isCorrect) {
            // Saves the ball!
            _currentGkAsset = gkDiveLeft
                ? 'assets/images/penaltygame/goalkeeper/gk_diving_left_ball.png'
                : 'assets/images/penaltygame/goalkeeper/gk_diving_right_ball.png';
            _ballOpacity = 0.0; // Fade the ball out as goalkeeper catches it
          } else {
            // Wrong way!
            _currentGkAsset = gkDiveLeft
                ? 'assets/images/penaltygame/goalkeeper/gk_diving_left.png'
                : 'assets/images/penaltygame/goalkeeper/gk_diving_right.png';
          }
        }
      });

      Timer(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        if (isCorrect) {
          // SAVED!
          _score += 10;
          _streak++;
          if (_streak > _bestStreak) _bestStreak = _streak;
          _playSound('cheering.mp3', volume: 0.20);
          _showRefereeOverlay(RefereeCall.saved);
        } else {
          // CONCEDED!
          _streak = 0;
          _cardsReceived++;
          _playSound('ballhitsnetgoal.mp3');
          _playSound('cardwhistle.mp3');
          _showRefereeOverlay(
            _cardsReceived >= 3 ? RefereeCall.redCard : RefereeCall.yellowCard,
          );
        }
      });
    });
  }

  void _showRefereeOverlay(RefereeCall call) {
    setState(() {
      _activeRefereeCall = call;
      _showOverlay = true;
    });

    if (call == RefereeCall.redCard) {
      _playSound('endwhistle.mp3');
      _endGame();
    } else {
      Timer(
        Duration(
          milliseconds: (_ps && call == RefereeCall.yellowCard) ? 4000 : 2000,
        ),
        () {
          if (mounted && _gameState == GameState.playing) {
            _currentIndex++;
            _nextRound();
          }
        },
      );
    }
  }

  void _endGame() async {
    _countdownTimer?.cancel();
    _stopBackgroundMusic();
    await ScoreService.instance.recordScore(
      gameId: 'penalty',
      score: _score,
      streak: _bestStreak,
    );
    if (mounted) {
      setState(() {
        _gameState = GameState.gameOver;
      });
    }
  }

  void _restartGame() {
    setState(() {
      _gameState = GameState.setup;
      _cardsReceived = 0;
      _score = 0;
      _streak = 0;
      _bestStreak = 0;
      _sessionReviewItems.clear();
      _showOverlay = false;
      _activeRefereeCall = null;
    });
    _stopBackgroundMusic();
  }

  // --- UI WIDGETS ---

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final wasTimerActive = _countdownTimer?.isActive ?? false;
        _countdownTimer?.cancel();
        final shouldPop = await showExitConfirmationDialog(context);
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        } else if (wasTimerActive && context.mounted && _gameState == GameState.playing && !_hasResponded) {
          _resumeCountdown();
        }
      },
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF0F0E17)
            : const Color(0xFFF3F4F6),
        appBar: AppBar(
          title: MarqueeTitle(
            title: _ps ? 'Grammar Penalty' : 'Word Penalty',
            leadingIcon: const Icon(
              FontAwesomeIcons.futbol,
              color: Color(0xFF10B981),
              size: 18,
            ),
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          centerTitle: false,
          actions: [
            if (!_ps)
              LevelBadgeButton(
                difficulty: _difficulty,
                accentColor: const Color(0xFF10B981),
                onTap: () async {
                  final chosen = await LevelSelectionDialog.show(
                    context,
                    initialDifficulty: _difficulty,
                    accentColor: const Color(0xFF10B981),
                    title: 'Word Penalty: Seviye Değiştir',
                  );
                  if (chosen != null && mounted) {
                    _updateDifficulty(chosen);
                  }
                },
              ),
            IconButton(
              icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up),
              onPressed: () {
                setState(() {
                  _isMuted = !_isMuted;
                  _bgPlayer.setVolume(_isMuted ? 0.0 : 0.45);
                });
              },
            ),
          ],
        ),
        body: Focus(
          autofocus: true,
          onKeyEvent: _handleKeyEvent,
          child: SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildCurrentStateView(),
            ),
          ),
        ),
      ),
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (_gameState != GameState.playing || _hasResponded || _isAnimating) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.digit1 ||
        key == LogicalKeyboardKey.numpad1 ||
        key == LogicalKeyboardKey.keyQ) {
      _handleAnswer(0); // Top Left
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.digit2 ||
        key == LogicalKeyboardKey.numpad2 ||
        key == LogicalKeyboardKey.keyW) {
      _handleAnswer(2); // Top Right
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.digit3 ||
        key == LogicalKeyboardKey.numpad3 ||
        key == LogicalKeyboardKey.keyA) {
      _handleAnswer(1); // Bottom Left
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.digit4 ||
        key == LogicalKeyboardKey.numpad4 ||
        key == LogicalKeyboardKey.keyS) {
      _handleAnswer(3); // Bottom Right
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _buildCurrentStateView() {
    switch (_gameState) {
      case GameState.setup:
        return _buildSetupDashboard();
      case GameState.playing:
      case GameState.gameOver:
        return LayoutBuilder(
          builder: (context, constraints) {
            final bool isDesktop = constraints.maxWidth >= 980;
            final Widget pitchStack = ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Stack(
                children: [
                  _buildGameplayView(),
                  if (_showOverlay && _activeRefereeCall != null)
                    _buildRefereeOverlay(),
                  if (_gameState == GameState.gameOver) _buildGameOverOverlay(),
                ],
              ),
            );

            if (!isDesktop) {
              return Center(child: pitchStack);
            }

            final bool isDark = Theme.of(context).brightness == Brightness.dark;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 290,
                        child: _buildDesktopLeftPanel(isDark),
                      ),
                      const SizedBox(width: 20),
                      Expanded(child: Center(child: pitchStack)),
                      const SizedBox(width: 20),
                      SizedBox(
                        width: 290,
                        child: _buildDesktopRightPanel(isDark),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
    }
  }

  Widget _buildDesktopLeftPanel(bool isDark) {
    final Color cardBg = isDark ? const Color(0xFF161622) : Colors.white;
    final Color innerBg = isDark
        ? const Color(0xFF1F1F30)
        : const Color(0xFFF8FAFC);
    final Color borderColor = isDark
        ? const Color(0xFF2E2E44)
        : const Color(0xFFCBD5E1);
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0xFF090910) : const Color(0xFFCBD5E1),
            offset: const Offset(0, 6),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Role & Mode Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(
                0xFF10B981,
              ).withValues(alpha: isDark ? 0.14 : 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF10B981), width: 1.5),
            ),
            child: Row(
              children: [
                Icon(
                  _selectedRole == GameRole.shooter
                      ? FontAwesomeIcons.shoePrints
                      : FontAwesomeIcons.hands,
                  size: 16,
                  color: const Color(0xFF10B981),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedRole == GameRole.shooter
                            ? 'PENALTICI (SHOOTER)'
                            : 'KALECİ (GOALKEEPER)',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                      Text(
                        _ps
                            ? 'Present Simple Modu'
                            : (_translationMode == TranslationMode.engToTur
                                  ? 'İngilizce ➔ Türkçe'
                                  : 'Türkçe ➔ İngilizce'),
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Score / Best / Streak Grid
          // Score Container
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              vertical: 10,
              horizontal: 14,
            ),
            decoration: BoxDecoration(
              color: innerBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SKOR',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.9,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$_score',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Streak & Referee Cards Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: innerBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SERİ',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.9,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                    Text(
                      '🔥 $_streak',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ),
                _buildTopCardsRow(),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2x2 Quick Corner Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _selectedRole == GameRole.shooter
                    ? 'HIZLI KÖŞE ŞUTU'
                    : 'HIZLI KÖŞE KURTARIŞI',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              Text(
                'Q/W/A/S',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _buildDesktopCornerButton(
                          cornerLabel: 'SOL ÜST',
                          shortcutKey: 'Q / 1',
                          optionIndex: 0,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildDesktopCornerButton(
                          cornerLabel: 'SAĞ ÜST',
                          shortcutKey: 'W / 2',
                          optionIndex: 2,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _buildDesktopCornerButton(
                          cornerLabel: 'SOL ALT',
                          shortcutKey: 'A / 3',
                          optionIndex: 1,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildDesktopCornerButton(
                          cornerLabel: 'SAĞ ALT',
                          shortcutKey: 'S / 4',
                          optionIndex: 3,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopCornerButton({
    required String cornerLabel,
    required String shortcutKey,
    required int optionIndex,
    required bool isDark,
  }) {
    final String optionText = (_options.length > optionIndex)
        ? _options[optionIndex]
        : '';
    final bool canInteract =
        _gameState == GameState.playing && !_hasResponded && !_isAnimating;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: canInteract ? () => _handleAnswer(optionIndex) : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1F1F30) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF32324A) : const Color(0xFFCBD5E1),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? const Color(0xFF0B0B12)
                    : const Color(0xFFCBD5E1),
                offset: const Offset(0, 3),
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    cornerLabel,
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      shortcutKey,
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                optionText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopRightPanel(bool isDark) {
    final Color cardBg = isDark ? const Color(0xFF161622) : Colors.white;
    final Color innerBg = isDark
        ? const Color(0xFF1F1F30)
        : const Color(0xFFF8FAFC);
    final Color borderColor = isDark
        ? const Color(0xFF2E2E44)
        : const Color(0xFFCBD5E1);
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final items = _sessionReviewItems.reversed.toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0xFF090910) : const Color(0xFFCBD5E1),
            offset: const Offset(0, 6),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.history_edu_rounded,
                    size: 18,
                    color: Color(0xFF10B981),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'CANLI MAÇ AKIŞI',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: innerBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                ),
                child: Text(
                  '${items.length} Pozisyon',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Expanded(
            child: items.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: innerBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            FontAwesomeIcons.futbol,
                            size: 28,
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'İlk penaltı vuruşunu yaptığında kelime geçmişi burada listelenecek.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final bool ok = item.isCorrect;
                      final Color accent = ok
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444);

                      return InkWell(
                        onTap: () => TtsService.instance.speak(item.word),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(
                              alpha: isDark ? 0.12 : 0.08,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: accent, width: 1.5),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                ok
                                    ? Icons.sports_soccer_rounded
                                    : Icons.style_rounded,
                                size: 18,
                                color: accent,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.word,
                                      style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: textColor,
                                      ),
                                    ),
                                    Text(
                                      item.meaning,
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.volume_up_rounded,
                                size: 16,
                                color: Color(0xFF10B981),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),

          // Quick Match Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _countdownTimer?.cancel();
                    setState(() {
                      _gameState = GameState.setup;
                    });
                  },
                  icon: const Icon(Icons.tune_rounded, size: 16),
                  label: Text(
                    'Ayarlar',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textColor,
                    side: BorderSide(color: borderColor, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _restartGame,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(
                    'Yenile',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- 1. SETUP DASHBOARD ---
  Widget _buildSetupDashboard() {
    final categories = ['All', ...penaltyGameCategories.keys];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isCompact = screenWidth < 380;

    const Color accentGreen = Color(0xFF10B981);
    const Color accentGreenLip = Color(0xFF047857);
    final Color cardBg = isDark ? const Color(0xFF141422) : Colors.white;
    final Color surfaceBg = isDark
        ? const Color(0xFF1C1C2E)
        : const Color(0xFFF8FAFC);
    final Color borderColor = isDark
        ? const Color(0xFF2D2D46)
        : const Color(0xFFCBD5E1);
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    final String guideTr = _ps
        ? '• Cümledeki boşluğa uygun Present Simple fiil çekimini 4 kale köşesinden seçin.\n'
              '• Şutçu olarak gol atın, Kaleci olarak doğru köşeye uzanıp kurtarış yapın!\n'
              '• Köşelere dokunabilir veya klavyeden Q/W/A/S (1-4) tuşlarını kullanabilirsiniz.'
        : '• Şutçu (Penaltıcı) veya Kaleci rolünüzü seçin.\n'
              '• Kale çerçevesindeki 4 köşeden kelimenin doğru karşılığını seçerek gol atın veya şutu kurtarın!\n'
              '• Köşelere dokunabilir veya klavyeden Q/W/A/S (1-4) tuşlarını kullanabilirsiniz. 3 kartta maç biter!';
    final String guideEn = _ps
        ? '• Pick the correct Present Simple verb form from the 4 goal corners.\n'
              '• Score goals as Shooter or make saves as Goalkeeper using touch or Q/W/A/S (1-4) keys!'
        : '• Choose Shooter or Goalkeeper and pick the right translation among the 4 goal corners.\n'
              '• Tap corners or use Q/W/A/S (1-4) keys. 3 cards end the match!';

    final levelOptions = [
      GameDifficulty.elementary,
      GameDifficulty.intermediate,
      GameDifficulty.all,
    ];

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 14 : 22,
          vertical: 16,
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: borderColor, width: 2),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? const Color(0xFF080810)
                    : const Color(0xFFCBD5E1),
                blurRadius: 0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(isCompact ? 18.0 : 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Row
                Row(
                  children: [
                    Container(
                      width: isCompact ? 48 : 54,
                      height: isCompact ? 48 : 54,
                      decoration: BoxDecoration(
                        color: accentGreen,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                          width: 1.5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: accentGreenLip,
                            offset: Offset(0, 4),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Center(
                        child: FaIcon(
                          FontAwesomeIcons.futbol,
                          color: Colors.white,
                          size: isCompact ? 20 : 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: surfaceBg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: borderColor),
                            ),
                            child: Text(
                              'MAÇ KURULUMU',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                                color: accentGreen,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _ps ? 'Grammar Penalty' : 'Word Penalty',
                            style: GoogleFonts.outfit(
                              fontSize: isCompact ? 20 : 23,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Collapsible How To Play Card
                Container(
                  decoration: BoxDecoration(
                    color: surfaceBg,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: borderColor, width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InkWell(
                        onTap: () => setState(
                          () => _setupGuideExpanded = !_setupGuideExpanded,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.menu_book_rounded,
                                size: 17,
                                color: accentGreen,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Nasıl Oynanır?',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: textColor,
                                  ),
                                ),
                              ),
                              if (_setupGuideExpanded) ...[
                                GestureDetector(
                                  onTap: () => setState(
                                    () => _setupGuideIsTr = !_setupGuideIsTr,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    margin: const EdgeInsets.only(right: 6),
                                    decoration: BoxDecoration(
                                      color: accentGreen.withValues(
                                        alpha: 0.16,
                                      ),
                                      borderRadius: BorderRadius.circular(7),
                                      border: Border.all(color: accentGreen),
                                    ),
                                    child: Text(
                                      _setupGuideIsTr ? 'TR' : 'EN',
                                      style: GoogleFonts.outfit(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        color: accentGreen,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              Icon(
                                _setupGuideExpanded
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                size: 18,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_setupGuideExpanded) ...[
                        Divider(height: 1, thickness: 1, color: borderColor),
                        Padding(
                          padding: const EdgeInsets.all(13),
                          child: Text(
                            _setupGuideIsTr ? guideTr : guideEn,
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              height: 1.45,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // ROLE SELECTOR
                Text(
                  'ROLÜNÜ SEÇ',
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildRoleCard(
                        role: GameRole.shooter,
                        title: 'Penaltıcı',
                        desc: 'Şut Çek (Shooter)',
                        icon: FontAwesomeIcons.shoePrints,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildRoleCard(
                        role: GameRole.goalkeeper,
                        title: 'Kaleci',
                        desc: 'Kurtar (Keeper)',
                        icon: FontAwesomeIcons.hands,
                      ),
                    ),
                  ],
                ),

                if (!_ps) ...[
                  const SizedBox(height: 18),

                  // LEVEL SELECTOR
                  Text(
                    'SEVİYE SEÇİMİ (CEFR)',
                    style: GoogleFonts.outfit(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: levelOptions.map((diff) {
                      final bool isSelected = _difficulty == diff;
                      final Color diffColor = diff.color;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: diff != levelOptions.last ? 8.0 : 0.0,
                          ),
                          child: GestureDetector(
                            onTap: () => _updateDifficulty(diff),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? diffColor.withValues(alpha: 0.16)
                                    : surfaceBg,
                                borderRadius: BorderRadius.circular(13),
                                border: Border.all(
                                  color: isSelected ? diffColor : borderColor,
                                  width: isSelected ? 2.0 : 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isSelected
                                        ? diffColor.withValues(alpha: 0.55)
                                        : (isDark
                                              ? const Color(0xFF0A0A12)
                                              : const Color(0xFFE2E8F0)),
                                    offset: const Offset(0, 3),
                                    blurRadius: 0,
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      FaIcon(
                                        diff.icon,
                                        size: 12,
                                        color: isSelected
                                            ? diffColor
                                            : (isDark
                                                  ? Colors.white54
                                                  : Colors.black45),
                                      ),
                                      const SizedBox(width: 5),
                                      Flexible(
                                        child: Text(
                                          diff.shortLabel,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.outfit(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                            color: textColor,
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
                    }).toList(),
                  ),
                  const SizedBox(height: 18),

                  // TRANSLATION DIRECTION
                  Text(
                    'ÇEVİRİ YÖNÜ',
                    style: GoogleFonts.outfit(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildModeButton(
                          mode: TranslationMode.engToTur,
                          label: 'İngilizce ➔ Türkçe',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildModeButton(
                          mode: TranslationMode.turToEng,
                          label: 'Türkçe ➔ İngilizce',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // CATEGORY DROPDOWN
                  Text(
                    'KELİME KATEGORİSİ',
                    style: GoogleFonts.outfit(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: surfaceBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? const Color(0xFF0A0A12)
                              : const Color(0xFFE2E8F0),
                          offset: const Offset(0, 3),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCategory,
                        isExpanded: true,
                        dropdownColor: isDark
                            ? const Color(0xFF1C1C2E)
                            : Colors.white,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          color: textColor,
                          fontWeight: FontWeight.w700,
                        ),
                        items: categories.map((cat) {
                          return DropdownMenuItem<String>(
                            value: cat,
                            child: Text(
                              cat == 'All' ? 'Tüm Kategoriler (Karışık)' : cat,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedCategory = val;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 22),

                // KICK OFF BUTTON
                GestureDetector(
                  onTap: _startGame,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: accentGreen,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.24),
                        width: 1.5,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: accentGreenLip,
                          offset: Offset(0, 4),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.sports_soccer_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'MAÇA BAŞLA (KICK OFF)',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required GameRole role,
    required String title,
    required String desc,
    required IconData icon,
  }) {
    final isSelected = _selectedRole == role;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const Color accentGreen = Color(0xFF10B981);
    const Color accentGreenLip = Color(0xFF047857);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRole = role;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? accentGreen.withValues(alpha: isDark ? 0.16 : 0.10)
              : (isDark ? const Color(0xFF1C1C2E) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? accentGreen
                : (isDark ? const Color(0xFF2D2D46) : const Color(0xFFCBD5E1)),
            width: isSelected ? 2.0 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? accentGreenLip
                  : (isDark
                        ? const Color(0xFF0A0A12)
                        : const Color(0xFFE2E8F0)),
              offset: const Offset(0, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Column(
          children: [
            FaIcon(
              icon,
              size: 22,
              color: isSelected ? accentGreen : Colors.grey,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isSelected
                    ? (isDark ? Colors.white : accentGreen)
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              desc,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton({
    required TranslationMode mode,
    required String label,
  }) {
    final isSelected = _translationMode == mode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const Color accentGreen = Color(0xFF10B981);
    const Color accentGreenLip = Color(0xFF047857);

    return GestureDetector(
      onTap: () {
        setState(() {
          _translationMode = mode;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? accentGreen
              : (isDark ? const Color(0xFF1C1C2E) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? accentGreen
                : (isDark ? const Color(0xFF2D2D46) : const Color(0xFFCBD5E1)),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? accentGreenLip
                  : (isDark
                        ? const Color(0xFF0A0A12)
                        : const Color(0xFFE2E8F0)),
              offset: const Offset(0, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  // --- 2. GAMEPLAY VIEW ---
  Widget _buildGameplayView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Live Score Dashboard Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // 1. Left cell: Stats aligned to the left
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Score: $_score',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        'Streak: $_streak 🔥',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // 2. Middle cell: Category Chip aligned to the center
              Expanded(
                child: Align(
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.blue.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      _ps
                          ? (_psTopic?.shortLabel ?? 'MIXED')
                          : _selectedCategory.toUpperCase(),
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ),
              ),
              // 3. Right cell: Referee Cards aligned to the right
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _buildTopCardsRow(),
                ),
              ),
            ],
          ),
        ),

        // Countdown Timer Bar
        if (!_ps)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _timeLeft / _roundTime,
                minHeight: 8,
                backgroundColor: isDark ? Colors.white10 : Colors.black12,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _timeLeft > 3 ? Colors.green : Colors.red,
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),

        // Question Word Display
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1B29) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black12,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  _ps
                      ? 'Choose the correct option:'
                      : 'What is the translation of:',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _questionWord,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: _ps ? 24 : 28,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Football Pitch Area
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final pitchH = constraints.maxHeight;
                final pitchW = constraints.maxWidth;

                // Calculate goal line and crossbar positions based on image scale
                final double imgWidth = 1536.0;
                final double imgHeight = 2752.0;
                final double scaleX = pitchW / imgWidth;
                final double scaleY = pitchH / imgHeight;
                final double scale = scaleX > scaleY ? scaleX : scaleY;

                final double goalLineY = pitchH - (imgHeight - 1820.0) * scale;
                final double crossbarY = pitchH - (imgHeight - 1000.0) * scale;
                final double goalHeight = goalLineY - crossbarY;

                final double gkHeight =
                    goalHeight *
                    0.90; // Enlarged slightly for better prominence

                // Prevent baseline jittering by checking current asset's bottom bounds
                final double gkFootFactor =
                    _currentGkAsset.contains('gk_standing1.png')
                    ? (1819.0 / 2048.0)
                    : (1721.0 / 2048.0);
                final double gkTop = goalLineY - gkHeight * gkFootFactor;
                final double optionY =
                    crossbarY + goalHeight * 0.35; // Centered inside the net

                // Update state if they changed
                if (_lastPitchWidth != pitchW || _lastPitchHeight != pitchH) {
                  _lastPitchWidth = pitchW;
                  _lastPitchHeight = pitchH;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _crossbarAlignY = 2.0 * (crossbarY / pitchH) - 1.0;
                        _goalLineAlignY = 2.0 * (goalLineY / pitchH) - 1.0;
                        _goalHeight = goalHeight;
                        if (!_isAnimating) {
                          _ballAlignY = 0.76;
                        }
                      });
                    }
                  });
                }

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // 1. Goal.png background - bottomCenter anchoring crops maximum sky
                    Positioned.fill(
                      child: Image.asset(
                        'assets/images/penaltygame/goal/goal.png',
                        fit: BoxFit.cover,
                        alignment: Alignment.bottomCenter,
                      ),
                    ),

                    // 2. Goalkeeper - inside the goal mouth, standing on the goal line
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      top: gkTop + _gkOffsetY,
                      left: 0,
                      right: 0,
                      child: AnimatedAlign(
                        alignment: Alignment(_gkAlignX, -1.0),
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        child: Transform.rotate(
                          angle: _gkAngle,
                          child: SizedBox(
                            height: gkHeight,
                            width:
                                gkHeight, // Keep square to maintain asset aspect ratio
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 150),
                              child: Image.asset(
                                _currentGkAsset,
                                key: ValueKey(_currentGkAsset),
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 3. 4 Option bubbles INSIDE the goal net
                    if (_options.length == 4) ...[
                      // Top Left (0)
                      Positioned(
                        top: optionY - goalHeight * 0.18,
                        left: pitchW * 0.15,
                        child: _buildCornerOptionBubble(
                          text: _options[0],
                          optionIndex: 0,
                          maxWidth: _ps ? min(160.0, pitchW * 0.34) : 110,
                        ),
                      ),
                      // Bottom Left (1)
                      Positioned(
                        top: optionY + goalHeight * 0.18,
                        left: pitchW * 0.15,
                        child: _buildCornerOptionBubble(
                          text: _options[1],
                          optionIndex: 1,
                          maxWidth: _ps ? min(160.0, pitchW * 0.34) : 110,
                        ),
                      ),
                      // Top Right (2)
                      Positioned(
                        top: optionY - goalHeight * 0.18,
                        right: pitchW * 0.15,
                        child: _buildCornerOptionBubble(
                          text: _options[2],
                          optionIndex: 2,
                          maxWidth: _ps ? min(160.0, pitchW * 0.34) : 110,
                        ),
                      ),
                      // Bottom Right (3)
                      Positioned(
                        top: optionY + goalHeight * 0.18,
                        right: pitchW * 0.15,
                        child: _buildCornerOptionBubble(
                          text: _options[3],
                          optionIndex: 3,
                          maxWidth: _ps ? min(160.0, pitchW * 0.34) : 110,
                        ),
                      ),
                    ],

                    // 4. Soccer Ball - in middle layer
                    Positioned.fill(
                      child: AnimatedAlign(
                        alignment: Alignment(_ballAlignX, _ballAlignY),
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOutCubic,
                        child: AnimatedScale(
                          scale: _ballScale,
                          duration: const Duration(milliseconds: 500),
                          child: AnimatedOpacity(
                            opacity: _ballOpacity,
                            duration: const Duration(milliseconds: 500),
                            child: Image.asset(
                              'assets/images/penaltygame/ball/ball.png',
                              height: 100,
                              width: 100,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 5. Kicker (Player) - foreground layer, renders on top of the ball in z-order
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: SizedBox(
                            height: pitchH * 0.58, // Larger player height
                            width:
                                pitchW *
                                0.85, // Prevent width from restricting height scale
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 150),
                              child: Image.asset(
                                _currentPlayerAsset,
                                key: ValueKey(_currentPlayerAsset),
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCornerOptionBubble({
    required String text,
    required int optionIndex,
    double maxWidth = 110,
  }) {
    return GestureDetector(
      onTap: () => _handleAnswer(optionIndex),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white70, width: 2.0),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.outfit(
            fontSize: _ps ? 15 : 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildTopCardsRow() {
    return Row(
      children: [
        _buildCardIcon(1, 'yellow_card.png'),
        const SizedBox(width: 8),
        _buildCardIcon(2, 'yellow_card.png'),
        const SizedBox(width: 8),
        _buildCardIcon(3, 'red_card.png'),
      ],
    );
  }

  Widget _buildCardIcon(int index, String assetName) {
    final bool active = _cardsReceived >= index;
    return Opacity(
      opacity: active ? 1.0 : 0.2,
      child: Image.asset(
        'assets/images/penaltygame/cards/$assetName',
        height: 40,
        width: 29,
        fit: BoxFit.contain,
      ),
    );
  }

  // --- 3. REFEREE OVERLAYS ---
  Widget _buildRefereeOverlay() {
    String messageText = '';
    String refereeAsset = '';

    switch (_activeRefereeCall) {
      case RefereeCall.goal:
        messageText = 'GOAL!';
        refereeAsset = 'assets/images/penaltygame/referee/referee_goal.png';
        break;
      case RefereeCall.saved:
        messageText = 'SAVED!';
        refereeAsset =
            'assets/images/penaltygame/referee/referee_goal.png'; // No specific save image, we reuse referee goal or normal. Let's look at the referee folder assets. We have referee_goal.png
        break;
      case RefereeCall.yellowCard:
        if (_selectedRole == GameRole.shooter) {
          messageText = 'MISSED!\nYELLOW CARD!';
        } else {
          messageText = 'GOAL CONCEDED!\nYELLOW CARD!';
        }
        refereeAsset = 'assets/images/penaltygame/referee/referee_yellow.png';
        break;
      case RefereeCall.redCard:
        messageText = 'RED CARD!\nSENT OFF!';
        refereeAsset = 'assets/images/penaltygame/referee/referee_red.png';
        break;
      default:
        break;
    }

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.75),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(refereeAsset, height: 240, fit: BoxFit.contain),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  messageText,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.5,
                    height: 1.3,
                  ),
                ),
              ),
              if (_activeRefereeCall == RefereeCall.yellowCard) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _ps ? 'CORRECT ANSWER' : 'DOĞRU CEVAP / CORRECT ANSWER',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: Colors.amberAccent,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _ps && _currentPs != null
                            ? _currentPs!.filled
                            : '$_questionWord = $_correctTranslation',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: _ps ? 22 : 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (_ps && _currentPs != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          '💡 ${_currentPs!.hint}',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber[200],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // --- 4. GAME OVER OVERLAY ---
  Widget _buildGameOverOverlay() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.85),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1B29) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 15,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/penaltygame/referee/referee_end.png',
                    height: 160,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'FULL TIME!',
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You received a red card and got sent off.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: isDark ? 0.15 : 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _ps
                              ? 'LAST ANSWER'
                              : 'SON SORUNUN CEVABI / LAST ANSWER',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: Colors.redAccent,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _ps && _currentPs != null
                              ? _currentPs!.filled
                              : '$_questionWord = $_correctTranslation',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        if (_ps && _currentPs != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            '💡 ${_currentPs!.hint}',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.amber[200]
                                  : Colors.brown[700],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Divider(color: isDark ? Colors.white12 : Colors.black12),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            'SCORE',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                          Text(
                            '$_score',
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            'STREAK',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                          Text(
                            '🔥 $_bestStreak',
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (_sessionReviewItems.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    GameReviewAccordion(
                      items: _sessionReviewItems,
                      accentColor: const Color(0xFF10B981),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            side: BorderSide(
                              color: isDark ? Colors.white24 : Colors.black26,
                            ),
                          ),
                          child: Text(
                            'Ana Menü',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _restartGame,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Yeniden Oyna',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
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
      ),
    );
  }
}

// --- SOCCER PITCH CUSTOM BACKGROUND PAINT ---
class FootballFieldBackground extends StatelessWidget {
  const FootballFieldBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: FootballFieldPainter());
  }
}

class FootballFieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintGrass1 = Paint()..color = const Color(0xFF2E7D32);
    final paintGrass2 = Paint()..color = const Color(0xFF388E3C);

    final paintLines = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final paintSpot = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;

    // Draw alternating horizontal stripes for grass
    const int stripesCount = 8;
    final double stripeHeight = size.height / stripesCount;
    for (int i = 0; i < stripesCount; i++) {
      final rect = Rect.fromLTWH(0, i * stripeHeight, size.width, stripeHeight);
      canvas.drawRect(rect, i % 2 == 0 ? paintGrass1 : paintGrass2);
    }

    // Draw penalty box (18-yard box) at the top
    final double boxWidth = size.width * 0.75;
    final double boxHeight = size.height * 0.40;
    final double boxLeft = (size.width - boxWidth) / 2;

    // Top border box
    final penaltyBox = Rect.fromLTWH(boxLeft, 0, boxWidth, boxHeight);
    canvas.drawRect(penaltyBox, paintLines);

    // Goal area box (6-yard box)
    final double smallBoxWidth = size.width * 0.45;
    final double smallBoxHeight = size.height * 0.16;
    final double smallBoxLeft = (size.width - smallBoxWidth) / 2;
    final smallGoalBox = Rect.fromLTWH(
      smallBoxLeft,
      0,
      smallBoxWidth,
      smallBoxHeight,
    );
    canvas.drawRect(smallGoalBox, paintLines);

    // Penalty spot (center under goal box)
    final double spotY = size.height * 0.7; // Aligning with ball location
    canvas.drawCircle(Offset(size.width / 2, spotY), 5, paintSpot);

    // Penalty box arc (D-Arc at bottom of penalty box)
    final double arcRadius = size.width * 0.18;
    final arcRect = Rect.fromCircle(
      center: Offset(size.width / 2, boxHeight),
      radius: arcRadius,
    );
    canvas.drawArc(arcRect, 0, pi, false, paintLines);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
