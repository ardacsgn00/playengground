import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/present_simple_data.dart';
import '../data/sentence_scramble_data.dart';
import '../models/game_review_item.dart';
import '../services/audio_service.dart';
import '../services/level_service.dart';
import '../services/mistake_service.dart';
import '../services/score_service.dart';
import '../services/tts_service.dart';
import '../widgets/exit_confirmation_dialog.dart';
import '../widgets/game_review_accordion.dart';
import '../widgets/game_tutorial_popup.dart';
import '../widgets/level_selection_dialog.dart';
import '../widgets/marquee_title.dart';

class _ScrambleTile {
  final int id;
  final String word;
  const _ScrambleTile({required this.id, required this.word});
}

class _DragTileData {
  final _ScrambleTile tile;
  final bool fromPlaced;
  final int sourceIndex;

  const _DragTileData({
    required this.tile,
    required this.fromPlaced,
    required this.sourceIndex,
  });
}

class SentenceScrambleScreen extends StatefulWidget {
  final List<dynamic>? customFlashcards;
  final bool presentSimple;

  const SentenceScrambleScreen({
    super.key,
    this.customFlashcards,
    this.presentSimple = false,
  });

  @override
  State<SentenceScrambleScreen> createState() => _SentenceScrambleScreenState();
}

class _SentenceScrambleScreenState extends State<SentenceScrambleScreen>
    with TickerProviderStateMixin {
  final Random _random = Random();

  static const Color _primaryColor = Color(0xFF6C63FF);
  static const Color _greenColor = Color(0xFF10B981);
  static const Color _redColor = Color(0xFFEF4444);
  static const Color _amberColor = Color(0xFFF59E0B);

  // --- Present Simple mode state ---
  bool _psModeEnabled = false;
  bool get _ps => widget.presentSimple || _psModeEnabled;
  bool _psStarted = false;
  PSTopic? _psTopic;
  bool _trapEnabled = true;
  int? _psTimeLimit = 40;
  List<PSScrambleItem> _psDeck = [];
  int _psIndex = 0;
  PSScrambleItem? _currentPs;
  String? _hintText;
  String? _currentTurkishMeaning;
  bool _isRevealed = false;
  Set<String> _accepted = {};

  final List<Map<String, dynamic>> _staticPool = sentenceScramblePool;
  GameDifficulty _difficulty = LevelService.instance.currentDifficulty;

  int _tileIdSeed = 0;
  List<_ScrambleTile> _availableTiles = [];
  List<_ScrambleTile> _placedTiles = [];
  int? _hoverInsertIndex;
  bool _isHoveringPoolRemove = false;

  List<String> get _placedWords => _placedTiles.map((e) => e.word).toList();

  late String _correctSentence;
  late String _displayCorrectSentence;

  int _score = 0;
  int _highScore = 0;
  bool _isNewHighScore = false;
  int _lives = 3;
  int _streak = 0;
  int _bestStreak = 0;
  final List<GameReviewItem> _sessionReviewItems = [];
  bool _isGameOver = false;
  bool _isRoundSuccess = false;
  bool _showErrorFlash = false;
  bool _showSimpleSuccess = false;
  bool _isHandlingTimeout = false;

  late AnimationController _timerController;
  int _roundTimeSeconds = 50;

  bool get _timerActive => !_ps || _psTimeLimit != null;

  static const List<String> _movableExpressions = [
    'today',
    'tonight',
    'yesterday',
    'tomorrow',
    'someday',
    'every day',
    'every morning',
    'every afternoon',
    'every evening',
    'on weekends',
    'on sunny days',
    'on sunday afternoons',
    'this morning',
    'this afternoon',
    'this evening',
    'this summer',
    'next week',
    'next month',
    'last night',
    'last weekend',
    'last year',
    'by friday',
    'before friday',
    'in the morning',
    'in the afternoon',
    'before leaving',
    'before going to bed',
    'before going to sleep',
    'before eating dinner',
    'before answering the question',
    'during exams',
    'during the presentation',
    'in less than five minutes',
    'for two hours every evening',
    'for a few minutes',
    'for three days',
  ];

  static String _clean(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\s]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  Set<String> _buildAcceptedVariations(
    String correctClean, [
    Iterable<String>? explicitAlts,
  ]) {
    final set = <String>{correctClean};
    if (explicitAlts != null) {
      for (final alt in explicitAlts) {
        set.add(_clean(alt));
      }
    }

    final toCheck = Set<String>.from(set);
    for (final s in toCheck) {
      for (final expr in _movableExpressions) {
        if (s.endsWith(' $expr')) {
          final front = s.substring(0, s.length - expr.length - 1).trim();
          set.add('$expr $front');
        } else if (s.startsWith('$expr ')) {
          final back = s.substring(expr.length + 1).trim();
          set.add('$back $expr');
        }
      }
    }
    return set;
  }

  GameDifficulty _getSentenceDifficulty(String sentence) {
    final words = sentence.split(RegExp(r'\s+'));
    int intermediateCount = 0;
    for (final w in words) {
      if (LevelService.instance.getWordDifficulty(w) ==
          GameDifficulty.intermediate) {
        intermediateCount++;
      }
    }
    if (words.length <= 6 && intermediateCount <= 1) {
      return GameDifficulty.elementary;
    }
    if (words.length >= 8 || intermediateCount >= 2) {
      return GameDifficulty.intermediate;
    }
    return words.length <= 7
        ? GameDifficulty.elementary
        : GameDifficulty.intermediate;
  }

  List<Map<String, dynamic>> get _filteredPool {
    if (_difficulty == GameDifficulty.all) return _staticPool;
    final list = _staticPool.where((item) {
      final s = item['correct'] as String;
      return _getSentenceDifficulty(s) == _difficulty;
    }).toList();
    return list.length >= 8 ? list : _staticPool;
  }

  void _updateDifficulty(GameDifficulty newDiff) {
    setState(() {
      _difficulty = newDiff;
      LevelService.instance.setDifficulty(newDiff);
      _score = 0;
      _lives = 3;
      _streak = 0;
      _bestStreak = 0;
      _isGameOver = false;
      _isNewHighScore = false;
      _sessionReviewItems.clear();
      _startNewRound();
    });
  }

  @override
  void initState() {
    super.initState();
    _highScore = ScoreService.instance.getHighScore('sentence_scramble');
    _timerController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _roundTimeSeconds),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _handleTimeout();
        }
      });

    _placedTiles = [];
    _availableTiles = [];
    _correctSentence = '';
    _displayCorrectSentence = '';

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_ps) {
        await GameTutorialPopup.show(
          context,
          tutorialKey: 'ps_sentence_scramble_tutorial',
          title: 'Present Simple Scramble',
          icon: FontAwesomeIcons.arrowDownShortWide,
          color: _primaryColor,
          tutorialTextTr:
              'Present Simple Scramble oyununda Geniş Zaman cümleleri kurun!\n\n'
              '• Kelime kartlarına dokunarak veya sürükleyip istediğiniz araya bırakarak cümleyi oluşturun.\n'
              '• Cümle içindeki kelimelerin yerini sürükleyerek değiştirebilir veya aşağı sürükleyip çıkarabilirsiniz.\n'
              '• DİKKAT: Kelimeler arasına 1 adet TUZAK kelime gizlenmiştir (örneğin "goes" yerine yanlış çekim "go").',
          tutorialTextEn:
              'Arrange the scrambled words by tapping or dragging them into any position! Careful: one TRAP word is hidden among the tiles.',
          hideLanguageToggle: false,
        );
        if (mounted) {
          _psTopic = null;
          _trapEnabled = true;
          _psTimeLimit = null;
          _startPsGame();
        }
        return;
      }
      final result = await GameTutorialPopup.show(
        context,
        tutorialKey: 'sentence_scramble_tutorial',
        title: 'Sentence Scramble',
        icon: FontAwesomeIcons.arrowDownShortWide,
        color: _primaryColor,
        tutorialTextTr:
            'Sentence Scramble oyununda İngilizce kelimeleri doğru sıraya dizin!\n\n'
            '• Alttaki kelimelere dokunarak veya sürükleyip cümle kutusunda istediğiniz iki kelimenin arasına bırakarak yerleştirin.\n'
            '• Yukarıdaki kelimeleri kendi aralarında sürükleyerek sıralamasını değiştirebilir ya da aşağı sürükleyerek geri çıkarabilirsiniz.',
        tutorialTextEn:
            'Arrange the scrambled English words to form a meaningful sentence! Tap words or drag and drop them between any words to reorder or remove them.',
        includeLevelSelection: !_ps,
        initialDifficulty: _difficulty,
      );
      if (!_ps && mounted && result.difficulty != null) {
        _updateDifficulty(result.difficulty!);
        return;
      }
      if (mounted) {
        _startNewRound();
      }
    });
  }

  void _startPsGame() {
    _psDeck = psScrambleItems
        .where((e) => _psTopic == null || e.topic == _psTopic)
        .toList()
      ..shuffle(_random);
    _psIndex = 0;
    if (_psTimeLimit != null) {
      _roundTimeSeconds = _psTimeLimit!;
      _timerController.duration = Duration(seconds: _roundTimeSeconds);
    }
    setState(() {
      _psStarted = true;
      _score = 0;
      _lives = 3;
      _streak = 0;
      _bestStreak = 0;
      _isGameOver = false;
      _isNewHighScore = false;
      _sessionReviewItems.clear();
    });
    _startNewRound();
  }

  void _openPsSetup() {
    _timerController.stop();
    setState(() {
      _psStarted = false;
      _isGameOver = false;
    });
  }

  PSScrambleItem _nextPsItem() {
    if (_psIndex >= _psDeck.length) {
      _psDeck.shuffle(_random);
      _psIndex = 0;
    }
    return _psDeck[_psIndex++];
  }

  String _buildPsHint() {
    final item = _currentPs!;
    final placedClean = _placedWords.map(_clean).toList();
    final trapClean = _clean(item.trap);
    final sentenceTiles = item.buildTiles(withTrap: false).map(_clean).toList();
    final trapInSentence = sentenceTiles.where((w) => w == trapClean).length;
    final trapPlaced = placedClean.where((w) => w == trapClean).length;

    if (_trapEnabled && trapPlaced > trapInSentence) {
      return '🪤 Tuzak kelime kullanıldı! ${item.hint}';
    }
    if (_placedWords.length < sentenceTiles.length) {
      return '🧩 Tuzak kelime hariç tüm kelimeleri kullanın.';
    }
    return '🔀 Kelime sırasını kontrol edin: ${item.topic.orderHint}';
  }

  void _revealAnswer() {
    if (_isGameOver || _isRoundSuccess || _isRevealed) return;
    _timerController.stop();
    setState(() {
      _streak = 0;
      _isRevealed = true;
      _isHandlingTimeout = true;
      _hintText = '💡 ${_currentPs!.hint}';
    });
  }

  void _startNewRound() {
    setState(() {
      List<String> rawWords;
      if (_ps) {
        final item = _nextPsItem();
        _currentPs = item;
        _displayCorrectSentence = item.sentence;
        _correctSentence = _clean(item.sentence);
        _accepted = _buildAcceptedVariations(
          _correctSentence,
          item.acceptedAnswers,
        );
        rawWords = item.buildTiles(withTrap: _trapEnabled);
      } else {
        final pool = _filteredPool;
        final sentenceData = pool[_random.nextInt(pool.length)];
        _displayCorrectSentence = sentenceData['correct'] as String;
        _currentTurkishMeaning = sentenceData['turkish'] as String?;

        _correctSentence = _clean(_displayCorrectSentence);
        final alts = (sentenceData['alternatives'] as List<dynamic>?)
            ?.map((e) => e.toString());
        _accepted = _buildAcceptedVariations(_correctSentence, alts);

        rawWords = List<String>.from(sentenceData['scrambled']);
        _roundTimeSeconds = max(50, rawWords.length * 6);
        _timerController.duration = Duration(seconds: _roundTimeSeconds);
      }
      rawWords.shuffle(_random);
      _availableTiles = rawWords
          .map((w) => _ScrambleTile(id: ++_tileIdSeed, word: w))
          .toList();
      _placedTiles = [];
      _hoverInsertIndex = null;
      _isHoveringPoolRemove = false;

      _showErrorFlash = false;
      _isRoundSuccess = false;
      _showSimpleSuccess = false;
      _isHandlingTimeout = false;
      _isRevealed = false;
      _hintText = null;
    });

    _timerController.reset();
    if (_timerActive) {
      _timerController.forward();
    }
  }

  // --- Drag & Drop / Tap Manipulation ---
  void _tapAvailableTile(int index) {
    if (_isHandlingTimeout || _isRoundSuccess || _isGameOver) return;
    final tile = _availableTiles[index];
    HapticFeedback.selectionClick();
    TtsService.instance.speak(tile.word);
    setState(() {
      _availableTiles.removeAt(index);
      _placedTiles.add(tile);
    });
  }

  void _tapPlacedTile(int index) {
    if (_isHandlingTimeout || _isRoundSuccess || _isGameOver) return;
    final tile = _placedTiles[index];
    HapticFeedback.selectionClick();
    TtsService.instance.speak(tile.word);
    setState(() {
      _placedTiles.removeAt(index);
      _availableTiles.add(tile);
    });
  }

  void _clearPlacedTiles() {
    if (_isHandlingTimeout ||
        _isRoundSuccess ||
        _isGameOver ||
        _placedTiles.isEmpty) {
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _availableTiles.addAll(_placedTiles);
      _placedTiles.clear();
    });
  }

  void _handleDropIntoSentence(_DragTileData data, int targetIndex) {
    if (_isHandlingTimeout || _isRoundSuccess || _isGameOver) return;
    HapticFeedback.selectionClick();
    TtsService.instance.speak(data.tile.word);

    setState(() {
      _hoverInsertIndex = null;
      _isHoveringPoolRemove = false;

      if (data.fromPlaced) {
        final int oldIdx =
            _placedTiles.indexWhere((t) => t.id == data.tile.id);
        if (oldIdx == -1) return;
        final removed = _placedTiles.removeAt(oldIdx);
        int insertIdx = targetIndex;
        if (oldIdx < insertIdx) {
          insertIdx -= 1;
        }
        insertIdx = insertIdx.clamp(0, _placedTiles.length);
        _placedTiles.insert(insertIdx, removed);
      } else {
        final int poolIdx =
            _availableTiles.indexWhere((t) => t.id == data.tile.id);
        if (poolIdx == -1) return;
        final removed = _availableTiles.removeAt(poolIdx);
        final int insertIdx = targetIndex.clamp(0, _placedTiles.length);
        _placedTiles.insert(insertIdx, removed);
      }
    });
  }

  void _handleDropIntoPool(_DragTileData data) {
    if (_isHandlingTimeout || _isRoundSuccess || _isGameOver) return;
    setState(() {
      _hoverInsertIndex = null;
      _isHoveringPoolRemove = false;
      if (data.fromPlaced) {
        final int oldIdx =
            _placedTiles.indexWhere((t) => t.id == data.tile.id);
        if (oldIdx != -1) {
          final removed = _placedTiles.removeAt(oldIdx);
          _availableTiles.add(removed);
          HapticFeedback.selectionClick();
        }
      }
    });
  }

  void _triggerGameOver() async {
    _isGameOver = true;
    _timerController.stop();
    AudioService.playFailure();
    final res = await ScoreService.instance.recordScore(
      gameId: 'sentence_scramble',
      score: _score,
      streak: _bestStreak,
    );
    if (mounted) {
      setState(() {
        _highScore = res.highScore;
        _isNewHighScore = res.isNewHighScore;
      });
    }
  }

  void _handleTimeout() {
    if (_isGameOver || _isRoundSuccess || _isHandlingTimeout) return;
    AudioService.playIncorrect();

    _sessionReviewItems.add(
      GameReviewItem(
        word: _displayCorrectSentence,
        meaning: _currentTurkishMeaning ??
            (_ps && _currentPs != null ? _currentPs!.hint : 'Cümle Sıralaması'),
        question: 'Cümleyi sırayla oluşturun',
        userAnswer: 'Süre Doldu',
        correctAnswer: _displayCorrectSentence,
        isCorrect: false,
        note: _displayCorrectSentence,
      ),
    );

    setState(() {
      _lives--;
      _streak = 0;
      if (_lives <= 0) {
        _triggerGameOver();
      } else if (_ps) {
        _isHandlingTimeout = true;
        _isRevealed = true;
        _showErrorFlash = true;
        _hintText = '⏰ Süre doldu! 💡 ${_currentPs!.hint}';
      } else {
        _isHandlingTimeout = true;
        _showErrorFlash = true;

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && !_isGameOver) {
            setState(() {
              _isHandlingTimeout = false;
              _showErrorFlash = false;
            });
            _startNewRound();
          }
        });
      }
    });
  }

  void _checkAnswer() {
    if (_isHandlingTimeout) return;
    final userSentence = _clean(_placedWords.join(' '));

    if (_accepted.contains(userSentence)) {
      _timerController.stop();
      AudioService.playCorrect();
      TtsService.instance.speak(_displayCorrectSentence);

      _sessionReviewItems.add(
        GameReviewItem(
          word: _displayCorrectSentence,
          meaning: _currentTurkishMeaning ??
              (_ps && _currentPs != null
                  ? _currentPs!.hint
                  : 'Cümle Sıralaması'),
          question: 'Cümleyi sırayla oluşturun',
          userAnswer: _placedWords.join(' '),
          correctAnswer: _displayCorrectSentence,
          isCorrect: true,
        ),
      );

      setState(() {
        _streak++;
        if (_streak > _bestStreak) _bestStreak = _streak;
        _score += (10 * (1.0 + (_streak * 0.2))).toInt();
        if (_lives < 3 && _streak % 3 == 0) _lives++;
        _isRoundSuccess = true;
        _showSimpleSuccess = true;
        _hintText = null;
      });
      Future.delayed(Duration(milliseconds: _ps ? 1600 : 1200), () {
        if (mounted && _isRoundSuccess) {
          _startNewRound();
        }
      });
    } else {
      AudioService.playIncorrect();
      final userSentenceRaw = _placedWords.join(' ');
      MistakeService.instance.recordMistake(
        word: _displayCorrectSentence,
        meaning: _currentTurkishMeaning ??
            (_ps && _currentPs != null ? _currentPs!.hint : 'Cümle Sıralaması'),
        sourceGame: 'Sentence Scramble',
        wrongAnswer:
            userSentenceRaw.isNotEmpty ? userSentenceRaw : 'Eksik / Yanlış Sıra',
      );

      _sessionReviewItems.add(
        GameReviewItem(
          word: _displayCorrectSentence,
          meaning: _currentTurkishMeaning ??
              (_ps && _currentPs != null
                  ? _currentPs!.hint
                  : 'Cümle Sıralaması'),
          question: 'Cümleyi sırayla oluşturun',
          userAnswer: userSentenceRaw.isNotEmpty
              ? userSentenceRaw
              : 'Eksik / Yanlış Sıra',
          correctAnswer: _displayCorrectSentence,
          isCorrect: false,
          note: _displayCorrectSentence,
        ),
      );

      setState(() {
        _streak = 0;
        _lives--;
        if (_ps) _hintText = _buildPsHint();
        if (_lives <= 0) {
          _triggerGameOver();
        } else {
          _showErrorFlash = true;
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) setState(() => _showErrorFlash = false);
          });
        }
      });
    }
  }

  void _resetGame() {
    if (_ps && !_psStarted) return;
    if (_ps) {
      _startPsGame();
      return;
    }
    setState(() {
      _score = 0;
      _lives = 3;
      _streak = 0;
      _bestStreak = 0;
      _isGameOver = false;
      _isNewHighScore = false;
      _sessionReviewItems.clear();
    });
    _startNewRound();
  }

  @override
  void dispose() {
    TtsService.instance.stop();
    _timerController.dispose();
    super.dispose();
  }

  Future<void> _handleExit() async {
    final wasAnimating = _timerController.isAnimating;
    _timerController.stop();
    final shouldPop = await showExitConfirmationDialog(context);
    if (shouldPop && mounted) {
      Navigator.of(context).pop();
    } else if (wasAnimating && mounted && !_isGameOver && _timerActive) {
      _timerController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF161622) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 820;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleExit();
      },
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0D0D14) : const Color(0xFFF1F5F9),
        appBar: AppBar(
          title: MarqueeTitle(
            title: _ps ? 'Present Simple Scramble' : 'Sentence Scramble',
            leadingIcon: const Icon(
              FontAwesomeIcons.arrowDownShortWide,
              color: _primaryColor,
              size: 18,
            ),
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: textColor,
            ),
          ),
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.transparent,
          actions: [
            if (!_ps)
              LevelBadgeButton(
                difficulty: _difficulty,
                accentColor: _primaryColor,
                onTap: () async {
                  final wasAnimating = _timerController.isAnimating;
                  _timerController.stop();
                  final chosen = await LevelSelectionDialog.show(
                    context,
                    initialDifficulty: _difficulty,
                    accentColor: _primaryColor,
                    title: 'Sentence Scramble: Seviye Değiştir',
                  );
                  if (chosen != null && mounted) {
                    _updateDifficulty(chosen);
                  } else if (wasAnimating &&
                      mounted &&
                      !_isGameOver &&
                      _timerActive) {
                    _timerController.forward();
                  }
                },
              ),
            if (screenWidth < 600)
              IconButton(
                tooltip: _ps ? 'Genel Mod' : 'Gramer Modu',
                icon: Icon(
                  _ps ? Icons.shuffle_rounded : Icons.menu_book_rounded,
                  size: 20,
                  color: _primaryColor,
                ),
                onPressed: () {
                  setState(() {
                    _psModeEnabled = !_ps;
                    if (_psModeEnabled) {
                      _psStarted = false;
                    } else {
                      _score = 0;
                      _lives = 3;
                      _streak = 0;
                      _isGameOver = false;
                      _startNewRound();
                    }
                  });
                },
              )
            else
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _psModeEnabled = !_ps;
                    if (_psModeEnabled) {
                      _psStarted = false;
                    } else {
                      _score = 0;
                      _lives = 3;
                      _streak = 0;
                      _isGameOver = false;
                      _startNewRound();
                    }
                  });
                },
                icon: Icon(
                  _ps ? Icons.shuffle_rounded : Icons.menu_book_rounded,
                  size: 16,
                  color: _primaryColor,
                ),
                label: Text(
                  _ps ? 'Genel Mod' : 'Gramer Modu',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: _primaryColor,
                  ),
                ),
              ),
            if (_ps && _psStarted)
              IconButton(
                icon: const Icon(Icons.tune_rounded),
                tooltip: 'Ayarlar',
                onPressed: _openPsSetup,
              ),
            if (!_ps || _psStarted)
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _resetGame,
              ),
          ],
        ),
        body: (_ps && !_psStarted)
            ? _buildPsSetup(isDark, cardColor, textColor)
            : Stack(
                children: [
                  SafeArea(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isDesktop ? 940 : 620,
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isDesktop ? 24.0 : 14.0,
                            vertical: 8.0,
                          ),
                          child: Column(
                            children: [
                              _buildTopHud(isDark, textColor),
                              const SizedBox(height: 10),
                              if (_timerActive) _buildTimerBar(isDark),
                              const SizedBox(height: 14),
                              Expanded(
                                child: SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (_currentTurkishMeaning != null &&
                                          !_ps) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? const Color(0xFF161622)
                                                : Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            border: Border.all(
                                              color: isDark
                                                  ? const Color(0xFF28283E)
                                                  : const Color(0xFFE2E8F0),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.translate_rounded,
                                                color: _primaryColor,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  _currentTurkishMeaning!,
                                                  style: GoogleFonts.outfit(
                                                    fontSize: isDesktop
                                                        ? 15
                                                        : 13.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: textColor.withValues(
                                                      alpha: 0.85,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                      ],

                                      // 1. Sentence Drop & Reorder Area
                                      _buildSentenceDropZone(
                                        isDark: isDark,
                                        cardColor: cardColor,
                                        textColor: textColor,
                                        isDesktop: isDesktop,
                                      ),

                                      if (_ps && _hintText != null) ...[
                                        const SizedBox(height: 14),
                                        _buildPsHintBox(isDark),
                                      ],

                                      const SizedBox(height: 18),

                                      // 2. Available Word Pool (also accepts drag-to-remove)
                                      _buildAvailableWordPool(
                                        isDark: isDark,
                                        cardColor: cardColor,
                                        textColor: textColor,
                                        isDesktop: isDesktop,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (_showSimpleSuccess)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _greenColor.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: _greenColor),
                                  ),
                                  child: Text(
                                    _ps ? 'CORRECT! ✨' : 'DOĞRU CÜMLE! ✨',
                                    style: GoogleFonts.outfit(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: _greenColor,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                              if (_ps &&
                                  !_isRevealed &&
                                  !_isRoundSuccess &&
                                  !_isGameOver)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: TextButton.icon(
                                    onPressed: _revealAnswer,
                                    icon: const Icon(
                                      Icons.visibility_outlined,
                                      size: 18,
                                    ),
                                    label: Text(
                                      'Cevabı Göster',
                                      style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    style: TextButton.styleFrom(
                                      foregroundColor: isDark
                                          ? Colors.white60
                                          : Colors.black54,
                                    ),
                                  ),
                                ),
                              _buildBottomActionButton(isDark),
                              SizedBox(height: isDesktop ? 10 : 6),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_isGameOver) _buildGameOverDialog(isDark, cardColor),
                ],
              ),
      ),
    );
  }

  Widget _buildTopHud(bool isDark, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (index) {
              final alive = index < _lives;
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  alive
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: alive
                      ? _redColor
                      : Colors.grey.withValues(alpha: 0.35),
                  size: 24,
                ),
              );
            }),
          ),
          const Spacer(),
          if (_streak > 1) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF97316),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '🔥 ${_streak}x',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF222234) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars_rounded, color: _amberColor, size: 16),
                const SizedBox(width: 5),
                Text(
                  '$_score',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerBar(bool isDark) {
    return AnimatedBuilder(
      animation: _timerController,
      builder: (context, child) {
        final timeLeftPercent =
            (1.0 - _timerController.value).clamp(0.0, 1.0);
        final Color timerColor = timeLeftPercent < 0.25
            ? _redColor
            : timeLeftPercent < 0.55
                ? _amberColor
                : _greenColor;
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: timeLeftPercent,
            color: timerColor,
            backgroundColor:
                isDark ? const Color(0xFF1E1E2E) : const Color(0xFFE2E8F0),
            minHeight: 8,
          ),
        );
      },
    );
  }

  Widget _buildSentenceDropZone({
    required bool isDark,
    required Color cardColor,
    required Color textColor,
    required bool isDesktop,
  }) {
    return DragTarget<_DragTileData>(
      onWillAcceptWithDetails: (details) {
        if (_hoverInsertIndex == null) {
          setState(() => _hoverInsertIndex = _placedTiles.length);
        }
        return true;
      },
      onLeave: (_) {
        if (_hoverInsertIndex == _placedTiles.length) {
          setState(() => _hoverInsertIndex = null);
        }
      },
      onAcceptWithDetails: (details) {
        final idx = _hoverInsertIndex ?? _placedTiles.length;
        _handleDropIntoSentence(details.data, idx);
      },
      builder: (context, candidateData, rejectedData) {
        final bool isHighlighted = candidateData.isNotEmpty;
        final Color borderColor = _showErrorFlash
            ? _redColor
            : _isRoundSuccess
                ? _greenColor
                : isHighlighted
                    ? _primaryColor
                    : (isDark
                        ? const Color(0xFF2D2D44)
                        : const Color(0xFFCBD5E1));

        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: double.infinity,
          constraints: BoxConstraints(minHeight: isDesktop ? 160 : 135),
          padding: EdgeInsets.all(isDesktop ? 22 : 16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor, width: 2.2),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? const Color(0xFF08080D)
                    : Colors.black.withValues(alpha: 0.05),
                offset: const Offset(0, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.edit_note_rounded,
                          size: 18,
                          color: _primaryColor,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'CÜMLE ALANI (Sürükle veya Dokun)',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                              color: _primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_placedTiles.isNotEmpty)
                    GestureDetector(
                      onTap: _clearPlacedTiles,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF242438)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.restart_alt_rounded,
                              size: 14,
                              color: textColor.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Temizle',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: textColor.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              if (_placedTiles.isEmpty && _hoverInsertIndex == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      _ps
                          ? 'Kelimeleri buraya sürükleyin veya sırayla dokunun (Tuzak kelimeye dikkat! 🪤)'
                          : 'Kelimeleri buraya sürükleyin, istediğiniz araya bırakın veya dokunun',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: textColor.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: _buildPlacedWidgetsWithSlots(
                    isDark: isDark,
                    textColor: textColor,
                    isDesktop: isDesktop,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildPlacedWidgetsWithSlots({
    required bool isDark,
    required Color textColor,
    required bool isDesktop,
  }) {
    final List<Widget> children = [];

    for (int i = 0; i < _placedTiles.length; i++) {
      final tile = _placedTiles[i];
      final bool showSlotBefore = _hoverInsertIndex == i;

      children.add(
        DragTarget<_DragTileData>(
          onWillAcceptWithDetails: (details) {
            if (_hoverInsertIndex != i) {
              setState(() => _hoverInsertIndex = i);
            }
            return true;
          },
          onLeave: (_) {
            if (_hoverInsertIndex == i) {
              setState(() => _hoverInsertIndex = null);
            }
          },
          onAcceptWithDetails: (details) {
            _handleDropIntoSentence(details.data, i);
          },
          builder: (context, candidateData, rejectedData) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showSlotBefore) _buildInsertionIndicator(isDesktop),
                _buildDraggableWordChip(
                  tile: tile,
                  fromPlaced: true,
                  index: i,
                  onTap: () => _tapPlacedTile(i),
                  isDark: isDark,
                  textColor: textColor,
                  isDesktop: isDesktop,
                ),
              ],
            );
          },
        ),
      );
    }

    // Trailing slot at the end of the sentence
    children.add(
      DragTarget<_DragTileData>(
        onWillAcceptWithDetails: (details) {
          if (_hoverInsertIndex != _placedTiles.length) {
            setState(() => _hoverInsertIndex = _placedTiles.length);
          }
          return true;
        },
        onLeave: (_) {
          if (_hoverInsertIndex == _placedTiles.length) {
            setState(() => _hoverInsertIndex = null);
          }
        },
        onAcceptWithDetails: (details) {
          _handleDropIntoSentence(details.data, _placedTiles.length);
        },
        builder: (context, candidateData, rejectedData) {
          if (_hoverInsertIndex == _placedTiles.length) {
            return _buildInsertionIndicator(isDesktop);
          }
          return const SizedBox(width: 28, height: 42);
        },
      ),
    );

    return children;
  }

  Widget _buildInsertionIndicator(bool isDesktop) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      width: 6,
      height: isDesktop ? 44 : 38,
      decoration: BoxDecoration(
        color: _primaryColor,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildAvailableWordPool({
    required bool isDark,
    required Color cardColor,
    required Color textColor,
    required bool isDesktop,
  }) {
    return DragTarget<_DragTileData>(
      onWillAcceptWithDetails: (details) {
        if (details.data.fromPlaced && !_isHoveringPoolRemove) {
          setState(() => _isHoveringPoolRemove = true);
        }
        return details.data.fromPlaced;
      },
      onLeave: (_) {
        if (_isHoveringPoolRemove) {
          setState(() => _isHoveringPoolRemove = false);
        }
      },
      onAcceptWithDetails: (details) {
        _handleDropIntoPool(details.data);
      },
      builder: (context, candidateData, rejectedData) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 110),
          padding: EdgeInsets.all(isDesktop ? 20 : 16),
          decoration: BoxDecoration(
            color: _isHoveringPoolRemove
                ? _redColor.withValues(alpha: isDark ? 0.14 : 0.08)
                : (isDark
                    ? const Color(0xFF14141F)
                    : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isHoveringPoolRemove
                  ? _redColor
                  : (isDark
                      ? const Color(0xFF28283E)
                      : const Color(0xFFE2E8F0)),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isHoveringPoolRemove
                        ? Icons.delete_outline_rounded
                        : Icons.apps_rounded,
                    size: 15,
                    color: _isHoveringPoolRemove
                        ? _redColor
                        : textColor.withValues(alpha: 0.55),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      _isHoveringPoolRemove
                          ? 'CÜMLEDEN ÇIKARMAK İÇİN BURAYA BIRAKIN'
                          : 'KELİME HAVUZU',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: _isHoveringPoolRemove
                            ? _redColor
                            : textColor.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_availableTiles.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Tüm kelimeler yerleştirildi',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textColor.withValues(alpha: 0.35),
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: List.generate(_availableTiles.length, (i) {
                    final tile = _availableTiles[i];
                    return _buildDraggableWordChip(
                      tile: tile,
                      fromPlaced: false,
                      index: i,
                      onTap: () => _tapAvailableTile(i),
                      isDark: isDark,
                      textColor: textColor,
                      isDesktop: isDesktop,
                    );
                  }),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDraggableWordChip({
    required _ScrambleTile tile,
    required bool fromPlaced,
    required int index,
    required VoidCallback onTap,
    required bool isDark,
    required Color textColor,
    required bool isDesktop,
  }) {
    final data = _DragTileData(
      tile: tile,
      fromPlaced: fromPlaced,
      sourceIndex: index,
    );

    final Widget chip = _buildWordChipVisual(
      word: tile.word,
      fromPlaced: fromPlaced,
      isDark: isDark,
      textColor: textColor,
      isDesktop: isDesktop,
    );

    return Draggable<_DragTileData>(
      data: data,
      feedback: Material(
        color: Colors.transparent,
        child: Transform.scale(
          scale: 1.06,
          child: _buildWordChipVisual(
            word: tile.word,
            fromPlaced: true,
            isDark: isDark,
            textColor: Colors.white,
            isDesktop: isDesktop,
            isDraggingFeedback: true,
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: chip,
      ),
      onDragEnd: (_) {
        if (mounted) {
          setState(() {
            _hoverInsertIndex = null;
            _isHoveringPoolRemove = false;
          });
        }
      },
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: chip,
        ),
      ),
    );
  }

  Widget _buildWordChipVisual({
    required String word,
    required bool fromPlaced,
    required bool isDark,
    required Color textColor,
    required bool isDesktop,
    bool isDraggingFeedback = false,
  }) {
    final Color bg = isDraggingFeedback
        ? _primaryColor
        : fromPlaced
            ? (isDark ? const Color(0xFF28254B) : const Color(0xFFEDE9FE))
            : (isDark ? const Color(0xFF222234) : Colors.white);
    final Color border = isDraggingFeedback
        ? Colors.white
        : fromPlaced
            ? _primaryColor
            : (isDark ? const Color(0xFF34344E) : const Color(0xFFCBD5E1));
    final Color lip = isDraggingFeedback
        ? const Color(0xFF4338CA)
        : fromPlaced
            ? const Color(0xFF4338CA)
            : (isDark ? const Color(0xFF10101A) : const Color(0xFFCBD5E1));

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _ps ? 18 : (isDesktop ? 16 : 14),
        vertical: _ps ? 12 : (isDesktop ? 10 : 9),
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 1.8),
        boxShadow: [
          BoxShadow(
            color: lip,
            offset: const Offset(0, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Text(
        word,
        style: GoogleFonts.outfit(
          fontSize: _ps ? (isDesktop ? 21 : 18) : (isDesktop ? 17 : 15),
          fontWeight: FontWeight.w800,
          color: isDraggingFeedback ? Colors.white : textColor,
        ),
      ),
    );
  }

  Widget _buildBottomActionButton(bool isDark) {
    if (_ps && _isRevealed && !_isGameOver) {
      return SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton.icon(
          onPressed: _startNewRound,
          icon: const Icon(Icons.arrow_forward_rounded),
          label: Text(
            'SONRAKİ CÜMLE',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _greenColor,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      );
    }

    final bool disabled = _isGameOver ||
        _isRoundSuccess ||
        _isHandlingTimeout ||
        _placedTiles.isEmpty;

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: disabled ? null : _checkAnswer,
        icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
        label: Text(
          _ps ? 'CHECK SENTENCE' : 'KONTROL ET',
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              isDark ? const Color(0xFF222234) : const Color(0xFFE2E8F0),
          disabledForegroundColor:
              isDark ? Colors.white30 : Colors.black38,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildPsHintBox(bool isDark) {
    final revealed = _isRevealed;
    final accent = revealed ? _greenColor : _amberColor;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.45), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (revealed) ...[
            Text(
              'DOĞRU CÜMLE',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: accent,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _displayCorrectSentence,
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            _hintText ?? '',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.amber[200] : Colors.brown[700],
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPsSetup(
    bool isDark,
    Color cardColor,
    Color textColor,
  ) {
    final counts = <PSTopic?, int>{null: psScrambleItems.length};
    for (final t in PSTopic.values) {
      counts[t] = psScrambleItems.where((e) => e.topic == t).length;
    }

    Widget sectionLabel(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 12, top: 4),
          child: Text(
            text,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: _primaryColor,
            ),
          ),
        );

    Widget choice({
      required String label,
      required bool selected,
      required VoidCallback onTap,
      String? badge,
    }) {
      return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? _primaryColor
                : (isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF3F4F6)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? _primaryColor
                  : (isDark ? Colors.white12 : Colors.black12),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: selected
                      ? Colors.white
                      : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white24
                        : _primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: selected ? Colors.white : _primaryColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 640),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: isDark ? const Color(0xFF28283E) : const Color(0xFFE2E8F0),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 68,
                  height: 68,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _primaryColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    FontAwesomeIcons.arrowDownShortWide,
                    size: 30,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Present Simple Scramble',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Cümleyi oluşturun ve tuzak kelimeden kaçının!',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 24),
              sectionLabel('KONU (TOPIC)'),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  choice(
                    label: 'Tümü (Karışık)',
                    badge: '${counts[null]}',
                    selected: _psTopic == null,
                    onTap: () => setState(() => _psTopic = null),
                  ),
                  ...PSTopic.values.map(
                    (t) => choice(
                      label: t.label,
                      badge: '${counts[t]}',
                      selected: _psTopic == t,
                      onTap: () => setState(() => _psTopic = t),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              sectionLabel('TUZAK KELİME (TRAP WORD)'),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  choice(
                    label: '🪤 Açık (Zorlu)',
                    selected: _trapEnabled,
                    onTap: () => setState(() => _trapEnabled = true),
                  ),
                  choice(
                    label: 'Kapalı (Standart)',
                    selected: !_trapEnabled,
                    onTap: () => setState(() => _trapEnabled = false),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              sectionLabel('SÜRE LİMİTİ'),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final t in const [40, 60, 90])
                    choice(
                      label: '${t}s',
                      selected: _psTimeLimit == t,
                      onTap: () => setState(() => _psTimeLimit = t),
                    ),
                  choice(
                    label: '∞ Süresiz',
                    selected: _psTimeLimit == null,
                    onTap: () => setState(() => _psTimeLimit = null),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _startPsGame,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'BAŞLA 🚀',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameOverDialog(bool isDark, Color cardBg) {
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 440),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _redColor.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isNewHighScore)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _amberColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.emoji_events_rounded,
                            color: Colors.white,
                            size: 18,
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
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _redColor.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.sentiment_very_dissatisfied_rounded,
                      size: 52,
                      color: _redColor,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Oyun Bitti!',
                    style: GoogleFonts.outfit(
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      color: _redColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'SCORE: $_score',
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'BEST: $_highScore',
                        style: GoogleFonts.outfit(
                          color: _amberColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'STREAK: 🔥 $_bestStreak',
                        style: GoogleFonts.outfit(
                          color: Colors.grey,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'Doğru Cümle:\n$_displayCorrectSentence',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (_sessionReviewItems.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    GameReviewAccordion(
                      items: _sessionReviewItems,
                      accentColor: _primaryColor,
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _resetGame,
                      icon: const Icon(Icons.replay_rounded),
                      label: Text(
                        'Yeniden Oyna',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _redColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: Text(
                        'Ana Menü',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor:
                            isDark ? Colors.white70 : Colors.black54,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
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
