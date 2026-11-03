import 'package:google_fonts/google_fonts.dart';
import '../widgets/exit_confirmation_dialog.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/audio_service.dart';
import '../services/tts_service.dart';
import '../utils/ui_utils.dart';
import '../widgets/game_tutorial_popup.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../data/word_hunt_data.dart';
import '../widgets/category_selection_dialog.dart';
import '../widgets/arcade/arcade_widgets.dart';
import '../services/level_service.dart';
import '../widgets/level_selection_dialog.dart';
import '../widgets/marquee_title.dart';
import '../services/mistake_service.dart';
import '../data/word_marathon_data.dart';
import '../services/score_service.dart';
import '../models/game_review_item.dart';

class WordDetectiveScreen extends StatefulWidget {
  const WordDetectiveScreen({super.key});

  @override
  State<WordDetectiveScreen> createState() => _WordDetectiveScreenState();
}

class _WordDetectiveScreenState extends State<WordDetectiveScreen>
    with TickerProviderStateMixin {
  late final FocusNode _keyboardFocusNode;
  // The game now pulls dynamically from randomWordsDb

  // --- Game State ---
  final Set<String> _usedWords = {};
  late String _currentCategory;
  String _selectedFilterCategory = 'All';
  GameDifficulty _difficulty = LevelService.instance.currentDifficulty;
  late String _currentWord;
  late List<String?> _placedLetters;
  late List<bool> _isHintSlot;
  late List<String> _availableLetters;

  int _score = 0;
  int _lives = 3;
  int _streak = 0;
  int _bestStreak = 0;
  bool _isGameOver = false;
  bool _isRoundSuccess = false;
  bool _showErrorFlash = false;
  bool _showSimpleSuccess = false;
  bool _isHandlingTimeout = false;

  final List<GameReviewItem> _sessionReviewItems = [];
  int _highScore = 0;
  bool _isNewHighScore = false;

  void _updateDifficulty(GameDifficulty newDiff) {
    setState(() {
      _difficulty = newDiff;
      LevelService.instance.setDifficulty(newDiff);
      _usedWords.clear();
      _score = 0;
      _lives = 3;
      _streak = 0;
      _isGameOver = false;
      _startNewRound();
    });
    _timerController.forward(from: 0.0);
  }

  final Random _random = Random();
  late AnimationController _timerController;
  late AnimationController _shakeController;
  final int _roundTimeSeconds = 25;

  @override
  void initState() {
    super.initState();
    _highScore = ScoreService.instance.getHighScore('word_detective');
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _timerController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _roundTimeSeconds),
    );
    _timerController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _handleTimeout();
      }
    });

    _startNewRound();
    _timerController.stop(); // Don't start timer until tutorial is gone
    _keyboardFocusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _keyboardFocusNode.requestFocus();

      final isWideScreen = MediaQuery.of(context).size.width > 600;

      String tutorialTextTr =
          "Word Detective oyununda bir dedektif gibi ipuçlarını takip edin ve vakayı çözün!\n\n"
          "• Verilen kategori ve Türkçe anlama ait gizli İngilizce kelimedeki eksik harfleri bulun.\n"
          "• Alttaki harf havuzundan doğru harfleri seçerek boşlukları doldurun. Dikkat: Havuzda yanıltıcı tuzak harfler de bulunur!\n"
          "• Süreniz dolmadan kelimeyi eksiksiz tamamlayın.";
      String tutorialTextEn =
          "In Word Detective, find the missing letters of the hidden English word belonging to the given category! Pick the correct letters from the letter pool to fill the slots and complete the word before time runs out. Watch out for decoy letters!";
      if (isWideScreen) {
        tutorialTextTr +=
            '\n\n⌨️ Klavye İpuçları:\n• Harfleri doğrudan klavyeden tuşlayabilirsiniz\n• Hızlı seçim için [1-9] tuşlarını kullanabilirsiniz\n• Son harfi silmek için Backspace tuşuna basın\n• Cevabı kontrol etmek için Enter tuşuna basın';
        tutorialTextEn +=
            '\n\n⌨️ Keyboard Tips:\n• Type letters directly with your keyboard\n• Use 1-9 numbers for quick selection\n• Press Backspace to remove last letter\n• Press Enter to check answer';
      }

      final result = await GameTutorialPopup.show(
        context,
        tutorialKey: 'word_detective_tutorial',
        title: "Word Detective",
        icon: FontAwesomeIcons.magnifyingGlass,
        color: const Color(0xFFEAB308),
        tutorialTextTr: tutorialTextTr,
        tutorialTextEn: tutorialTextEn,
        includeLevelSelection: true,
        initialDifficulty: _difficulty,
        categories: getWordHuntCategoryOptions(),
        initialCategoryId: _selectedFilterCategory,
      );
      if (mounted) {
        if (result.difficulty != null) {
          _difficulty = result.difficulty!;
          LevelService.instance.setDifficulty(_difficulty);
        }
        if (result.categoryId != null) {
          _selectedFilterCategory = result.categoryId!;
        }
        setState(() {
          _usedWords.clear();
          _score = 0;
          _lives = 3;
          _streak = 0;
          _isGameOver = false;
          _startNewRound();
        });
        _timerController.forward(from: 0.0);
      }
    });
  }

  Future<void> _showCategoryPickerAndStart({bool canDismiss = true}) async {
    final chosen = await CategorySelectionDialog.show(
      context,
      title: 'Word Detective: Kategori Seçin',
      subtitle: 'Eksik harflerini bulacağınız kelime konusunu belirleyin',
      accentColor: const Color(0xFFEAB308),
      headerIcon: FontAwesomeIcons.magnifyingGlass,
      categories: getWordHuntCategoryOptions(),
      initialSelectedId: _selectedFilterCategory,
      canDismiss: canDismiss,
    );
    if (!mounted) return;
    if (chosen != null) {
      setState(() {
        _selectedFilterCategory = chosen;
        _usedWords.clear();
        _score = 0;
        _lives = 3;
        _streak = 0;
        _isGameOver = false;
        _startNewRound();
      });
      _timerController.forward(from: 0.0);
    } else {
      if (mounted) _timerController.forward();
    }
  }

  void _startNewRound() {
    setState(() {
      final categoryNames = wordHuntCategories.keys.toList();

      String selectedCategory =
          (_selectedFilterCategory != 'All' &&
              wordHuntCategories.containsKey(_selectedFilterCategory))
          ? _selectedFilterCategory
          : categoryNames[_random.nextInt(categoryNames.length)];
      final rawWords = wordHuntCategories[selectedCategory]!;
      final words = LevelService.instance.filterWordList(rawWords, _difficulty);

      List<String> availableWords = words
          .where((w) => !_usedWords.contains(w.toUpperCase()))
          .toList();

      int tries = 0;
      while (_selectedFilterCategory == 'All' &&
          availableWords.isEmpty &&
          tries < 20) {
        selectedCategory = categoryNames[_random.nextInt(categoryNames.length)];
        final rWords = wordHuntCategories[selectedCategory]!;
        final fWords = LevelService.instance.filterWordList(
          rWords,
          _difficulty,
        );
        availableWords = fWords
            .where((w) => !_usedWords.contains(w.toUpperCase()))
            .toList();
        tries++;
      }

      if (availableWords.isEmpty) {
        _usedWords.clear();
        availableWords = words;
      }

      _currentCategory = selectedCategory;
      _currentWord = availableWords[_random.nextInt(availableWords.length)]
          .toUpperCase();
      _usedWords.add(_currentWord);

      _placedLetters = List.filled(_currentWord.length, null);
      _isHintSlot = List.filled(_currentWord.length, false);
      _availableLetters = [];

      // Determine hints (e.g., ~30% of characters)
      int numHints = max(1, (_currentWord.length * 0.3).round());
      List<int> indices = List.generate(_currentWord.length, (i) => i);
      indices.shuffle(_random);

      List<int> hintIndices = indices.take(numHints).toList();

      for (int i = 0; i < _currentWord.length; i++) {
        if (hintIndices.contains(i)) {
          _placedLetters[i] = _currentWord[i];
          _isHintSlot[i] = true;
        } else {
          _availableLetters.add(_currentWord[i]);
        }
      }

      _availableLetters.shuffle(_random);

      // Add 2-3 decoy letters to increase difficulty
      const decoyPool = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
      final int decoyCount = _currentWord.length <= 5 ? 2 : 3;
      for (int i = 0; i < decoyCount; i++) {
        _availableLetters.add(decoyPool[_random.nextInt(decoyPool.length)]);
      }
      _availableLetters.shuffle(_random);

      _showErrorFlash = false;
      _isRoundSuccess = false;
      _showSimpleSuccess = false;
      _isHandlingTimeout = false;
    });
    _timerController.reset();
    _timerController.forward();
  }

  void _handleTimeout() {
    if (_isGameOver || _isRoundSuccess || _isHandlingTimeout) return;
    AudioService.playIncorrect();
    HapticFeedback.heavyImpact();
    _shakeController.forward(from: 0.0);

    final trMeaning =
        wordMarathonDictionary[_currentWord] ??
        wordMarathonDictionary[_currentWord.toLowerCase()] ??
        'Kategori: $_currentCategory';
    _sessionReviewItems.add(
      GameReviewItem(
        id: '${_currentWord}_${DateTime.now().millisecondsSinceEpoch}',
        word: _currentWord,
        meaning: trMeaning,
        question: 'Gizli Kelime ($_currentCategory)',
        userAnswer: 'Süre Doldu',
        correctAnswer: _currentWord,
        isCorrect: false,
      ),
    );

    MistakeService.instance.recordMistake(
      word: _currentWord,
      meaning: trMeaning,
      sourceGame: 'Word Detective',
      wrongAnswer: 'Süre Doldu',
    );

    setState(() {
      _lives--;
      _streak = 0;
      if (_lives <= 0) {
        _isGameOver = true;
        _timerController.stop();
        AudioService.playFailure();
        ScoreService.instance
            .recordScore(
              gameId: 'word_detective',
              score: _score,
              streak: _bestStreak,
            )
            .then((res) {
              if (mounted) {
                setState(() {
                  _highScore = res.highScore;
                  _isNewHighScore = res.isNewHighScore;
                });
              }
            });
      } else {
        _isHandlingTimeout = true;
        _showErrorFlash = true;

        UIUtils.showPremiumSnackBar(
          context,
          'Time is up! Word: $_currentWord',
          backgroundColor: Colors.red.shade600,
          duration: const Duration(seconds: 3),
          icon: Icons.timer_off_rounded,
        );

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
    final userWord = _placedLetters.join('');
    final trMeaning =
        wordMarathonDictionary[_currentWord] ??
        wordMarathonDictionary[_currentWord.toLowerCase()] ??
        'Kategori: $_currentCategory';

    if (userWord == _currentWord) {
      _timerController.stop();
      AudioService.playCorrect();
      TtsService.instance.speak(_currentWord);
      HapticFeedback.lightImpact();

      _sessionReviewItems.add(
        GameReviewItem(
          id: '${_currentWord}_${DateTime.now().millisecondsSinceEpoch}',
          word: _currentWord,
          meaning: trMeaning,
          question: 'Gizli Kelime ($_currentCategory)',
          userAnswer: userWord,
          correctAnswer: _currentWord,
          isCorrect: true,
        ),
      );

      setState(() {
        _streak++;
        if (_streak > _bestStreak) _bestStreak = _streak;
        _score +=
            (10 * (1.0 + (_streak * 0.2))).toInt() +
            (_timerController.value < 0.5 ? 5 : 0);
        if (_lives < 3 && _streak % 3 == 0)
          _lives++; // Bonus life every 3 streak
        _isRoundSuccess = true;
        _showSimpleSuccess = true;
      });
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted && _isRoundSuccess) {
          _startNewRound();
        }
      });
    } else {
      AudioService.playIncorrect();
      HapticFeedback.heavyImpact();
      _shakeController.forward(from: 0.0);

      _sessionReviewItems.add(
        GameReviewItem(
          id: '${_currentWord}_${DateTime.now().millisecondsSinceEpoch}',
          word: _currentWord,
          meaning: trMeaning,
          question: 'Gizli Kelime ($_currentCategory)',
          userAnswer: userWord,
          correctAnswer: _currentWord,
          isCorrect: false,
        ),
      );

      MistakeService.instance.recordMistake(
        word: _currentWord,
        meaning: trMeaning,
        sourceGame: 'Word Detective',
        wrongAnswer: userWord,
      );

      setState(() {
        _streak = 0;
        _lives--;
        if (_lives <= 0) {
          _isGameOver = true;
          _timerController.stop();
          AudioService.playFailure();
          ScoreService.instance
              .recordScore(
                gameId: 'word_detective',
                score: _score,
                streak: _bestStreak,
              )
              .then((res) {
                if (mounted) {
                  setState(() {
                    _highScore = res.highScore;
                    _isNewHighScore = res.isNewHighScore;
                  });
                }
              });
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

  void _onAvailableLetterTap(String letter) {
    if (_isHandlingTimeout || _isRoundSuccess) return;
    int firstEmptyIndex = _placedLetters.indexWhere(
      (element) => element == null,
    );
    if (firstEmptyIndex != -1) {
      setState(() {
        _placedLetters[firstEmptyIndex] = letter;
        _availableLetters.remove(letter);
      });
    }
  }

  void _onPlacedLetterTap(int index) {
    if (_isHandlingTimeout ||
        _isRoundSuccess ||
        _isHintSlot[index] ||
        _placedLetters[index] == null)
      return;
    setState(() {
      _availableLetters.add(_placedLetters[index]!);
      _placedLetters[index] = null;
    });
  }

  @override
  void dispose() {
    TtsService.instance.stop();
    _shakeController.dispose();
    _timerController.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (_isGameOver || _isRoundSuccess || _isHandlingTimeout) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;

    // 1-9 to select available letters
    final Map<LogicalKeyboardKey, int> digitKeys = {
      LogicalKeyboardKey.digit1: 0,
      LogicalKeyboardKey.numpad1: 0,
      LogicalKeyboardKey.digit2: 1,
      LogicalKeyboardKey.numpad2: 1,
      LogicalKeyboardKey.digit3: 2,
      LogicalKeyboardKey.numpad3: 2,
      LogicalKeyboardKey.digit4: 3,
      LogicalKeyboardKey.numpad4: 3,
      LogicalKeyboardKey.digit5: 4,
      LogicalKeyboardKey.numpad5: 4,
      LogicalKeyboardKey.digit6: 5,
      LogicalKeyboardKey.numpad6: 5,
      LogicalKeyboardKey.digit7: 6,
      LogicalKeyboardKey.numpad7: 6,
      LogicalKeyboardKey.digit8: 7,
      LogicalKeyboardKey.numpad8: 7,
      LogicalKeyboardKey.digit9: 8,
      LogicalKeyboardKey.numpad9: 8,
    };

    if (digitKeys.containsKey(key)) {
      final index = digitKeys[key]!;
      if (index < _availableLetters.length) {
        _onAvailableLetterTap(_availableLetters[index]);
        return KeyEventResult.handled;
      }
    }

    if (event.character != null && event.character!.isNotEmpty) {
      final char = event.character!.toUpperCase();
      final index = _availableLetters.indexOf(char);
      if (index != -1) {
        _onAvailableLetterTap(_availableLetters[index]);
        return KeyEventResult.handled;
      }
    }

    // Backspace removes last placed letter
    if (key == LogicalKeyboardKey.backspace) {
      // Find last non-hint placed letter
      for (int i = _placedLetters.length - 1; i >= 0; i--) {
        if (!_isHintSlot[i] && _placedLetters[i] != null) {
          _onPlacedLetterTap(i);
          return KeyEventResult.handled;
        }
      }
    }

    // Enter to check answer
    if (key == LogicalKeyboardKey.enter) {
      if (!_placedLetters.contains(null)) {
        _checkAnswer();
        return KeyEventResult.handled;
      }
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
    const bgNoir = Color(0xFF0F0C09);
    const surfaceDark = Color(0xFF191410);
    const amberAccent = Color(0xFFEAB308);

    return Focus(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
        onTap: () => _keyboardFocusNode.requestFocus(),
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            await _handleExit();
          },
          child: Scaffold(
            backgroundColor: bgNoir,
            appBar: _buildAppBar(amberAccent),
            body: SafeArea(
              child: Stack(
                children: [
                  // Atmospheric Vignette & Investigation Watermark
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _DeskInvestigationPainter(accent: amberAccent),
                    ),
                  ),

                  // Main Interactive Layout
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
                                accent: amberAccent,
                                surface: surfaceDark,
                                score: _score,
                                streak: _streak,
                                lives: _lives,
                                maxLives: 3,
                                badge: ArcadeBadge(
                                  icon: FontAwesomeIcons.layerGroup,
                                  text: _currentCategory.toUpperCase(),
                                  color: amberAccent,
                                  onTap: () => _showCategoryPickerAndStart(
                                    canDismiss: true,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Investigation Timer Bar
                              AnimatedBuilder(
                                animation: _timerController,
                                builder: (context, _) => GlowTimerBar(
                                  percent: (1.0 - _timerController.value).clamp(
                                    0.0,
                                    1.0,
                                  ),
                                  height: 6,
                                  label: 'INVESTIGATION TIME',
                                  labelColor: amberAccent,
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Vertically centered game area
                              Expanded(
                                child: Center(
                                  child: SingleChildScrollView(
                                    physics: const BouncingScrollPhysics(),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const SizedBox(height: 10),
                                        // Case Dossier Header
                                        _buildCaseFileHeader(
                                          amberAccent,
                                          surfaceDark,
                                        ),
                                        const SizedBox(height: 18),

                                        // Target Word Blanks / Evidence Slots
                                        _buildWordSlotsCard(
                                          amberAccent,
                                          surfaceDark,
                                        ),
                                        const SizedBox(height: 22),

                                        // Available Evidence Letter Chits
                                        _buildEvidenceLetterPool(
                                          amberAccent,
                                          surfaceDark,
                                        ),
                                        const SizedBox(height: 26),

                                        // Solve Action Button
                                        _buildActionSection(
                                          amberAccent,
                                          surfaceDark,
                                        ),
                                        const SizedBox(height: 12),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Game Over Modal Overlay
                  if (_isGameOver)
                    _buildGameOverOverlay(amberAccent, surfaceDark),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(Color amber) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new,
          color: Colors.white70,
          size: 20,
        ),
        onPressed: _handleExit,
      ),
      title: MarqueeTitle(
        title: 'Word Detective',
        leadingIcon: FaIcon(
          FontAwesomeIcons.magnifyingGlass,
          size: 16,
          color: amber,
        ),
        style: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      actions: [
        LevelBadgeButton(
          difficulty: _difficulty,
          accentColor: amber,
          onTap: () async {
            final wasAnimating = _timerController.isAnimating;
            _timerController.stop();
            final chosen = await LevelSelectionDialog.show(
              context,
              initialDifficulty: _difficulty,
              accentColor: amber,
              title: 'Word Detective: Seviye Değiştir',
            );
            if (chosen != null && mounted) {
              _updateDifficulty(chosen);
            } else if (wasAnimating && mounted && !_isGameOver) {
              _timerController.forward();
            }
          },
        ),
        IconButton(
          icon: const Icon(
            FontAwesomeIcons.layerGroup,
            size: 17,
            color: Colors.white70,
          ),
          tooltip: 'Kategori Seç',
          onPressed: () => _showCategoryPickerAndStart(canDismiss: true),
        ),
        IconButton(
          icon: const Icon(Icons.help_outline, color: Colors.white60, size: 22),
          onPressed: () {
            GameTutorialPopup.show(
              context,
              tutorialKey: 'word_detective_tutorial',
              title: 'Word Detective',
              icon: FontAwesomeIcons.magnifyingGlass,
              color: amber,
              tutorialTextTr:
                  'Word Detective oyununda bir dedektif gibi ipuçlarını takip edin ve vakayı çözün!\n\n'
                  '• Verilen kategori ve Türkçe anlama ait gizli İngilizce kelimedeki eksik harfleri bulun.\n'
                  '• Alttaki harf havuzundan doğru harfleri seçerek boşlukları doldurun. Dikkat: Havuzda yanıltıcı tuzak harfler de bulunur!\n'
                  '• Süreniz dolmadan kelimeyi eksiksiz tamamlayın.',
              tutorialTextEn:
                  'In Word Detective, find the missing letters of the hidden English word belonging to the given category! Pick the correct letters from the letter pool to fill the slots and complete the word before time runs out. Watch out for decoy letters!',
            );
          },
        ),
      ],
    );
  }

  Widget _buildCaseFileHeader(Color amber, Color surface) {
    return InkWell(
      onTap: () => _showCategoryPickerAndStart(canDismiss: true),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: amber.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              getWordHuntCategoryIcon(_currentCategory),
              size: 14,
              color: amber,
            ),
            const SizedBox(width: 8),
            Text(
              'CASE FILE: ${_currentCategory.toUpperCase()}',
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                color: amber,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '(${wordHuntCategoryTr[_currentCategory] ?? _currentCategory})',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.swap_horiz_rounded,
              size: 16,
              color: amber.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWordSlotsCard(Color amber, Color surface) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _showErrorFlash
              ? const Color(0xFFEF4444)
              : (_showSimpleSuccess
                    ? const Color(0xFF10B981)
                    : amber.withValues(alpha: 0.3)),
          width: (_showErrorFlash || _showSimpleSuccess) ? 2.0 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: _showErrorFlash
                ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                : (_showSimpleSuccess
                      ? const Color(0xFF10B981).withValues(alpha: 0.2)
                      : Colors.black.withValues(alpha: 0.35)),
            blurRadius: 20,
            offset: const Offset(0, 6),
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
                _showSimpleSuccess
                    ? FontAwesomeIcons.circleCheck
                    : (_showErrorFlash
                          ? FontAwesomeIcons.circleXmark
                          : FontAwesomeIcons.fingerprint),
                size: 13,
                color: _showSimpleSuccess
                    ? const Color(0xFF10B981)
                    : (_showErrorFlash ? const Color(0xFFEF4444) : amber),
              ),
              const SizedBox(width: 8),
              Text(
                _showSimpleSuccess
                    ? 'CASE SOLVED!'
                    : (_showErrorFlash
                          ? 'EVIDENCE MISMATCH!'
                          : 'TARGET WORD EVIDENCE'),
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: _showSimpleSuccess
                      ? const Color(0xFF10B981)
                      : (_showErrorFlash ? const Color(0xFFEF4444) : amber),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: List.generate(_currentWord.length, (index) {
              return _buildSlotTile(
                index: index,
                letter: _placedLetters[index],
                isHint: _isHintSlot[index],
                amber: amber,
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotTile({
    required int index,
    required String? letter,
    required bool isHint,
    required Color amber,
  }) {
    if (letter == null) {
      return Container(
        width: 48,
        height: 58,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Container(
          width: 16,
          height: 2.5,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
    }

    if (isHint) {
      return Container(
        width: 48,
        height: 58,
        decoration: BoxDecoration(
          color: amber.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: amber.withValues(alpha: 0.6), width: 1.5),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 4,
              right: 5,
              child: FaIcon(
                FontAwesomeIcons.lock,
                size: 8,
                color: amber.withValues(alpha: 0.7),
              ),
            ),
            Text(
              letter,
              style: GoogleFonts.outfit(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: amber,
              ),
            ),
          ],
        ),
      );
    }

    // Placed letter (can be tapped to return to pool)
    return InkWell(
      onTap: () => _onPlacedLetterTap(index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 48,
        height: 58,
        decoration: BoxDecoration(
          color: const Color(0xFF282018),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          letter,
          style: GoogleFonts.outfit(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildEvidenceLetterPool(Color amber, Color surface) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(
              FontAwesomeIcons.magnifyingGlass,
              size: 10,
              color: Colors.white38,
            ),
            const SizedBox(width: 6),
            Text(
              'AVAILABLE EVIDENCE CHITS',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                color: Colors.white38,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: List.generate(_availableLetters.length, (i) {
            final letter = _availableLetters[i];
            return _EvidenceChit(
              letter: letter,
              shortcutIndex: i < 9 ? i + 1 : null,
              amber: amber,
              onTap: () => _onAvailableLetterTap(letter),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildActionSection(Color amber, Color surface) {
    final bool isReady =
        !_placedLetters.contains(null) &&
        !_isGameOver &&
        !_isRoundSuccess &&
        !_isHandlingTimeout;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(bottom: isReady ? 4.0 : 0.0),
      decoration: BoxDecoration(
        color: isReady ? const Color(0xFFB45309) : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: isReady ? _checkAnswer : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: amber,
            foregroundColor: const Color(0xFF140F0A),
            disabledBackgroundColor: Colors.white.withValues(alpha: 0.08),
            disabledForegroundColor: Colors.white30,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const FaIcon(FontAwesomeIcons.magnifyingGlass, size: 14),
              const SizedBox(width: 10),
              Text(
                _placedLetters.contains(null)
                    ? 'FILL ALL SLOTS'
                    : 'INSPECT & SOLVE',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameOverOverlay(Color amber, Color surface) {
    return ArcadeGameOverCard(
      title: 'CASE UNSOLVED!',
      subtitle: 'Tüm canların tükendi. Aranan kelime: $_currentWord',
      icon: FontAwesomeIcons.magnifyingGlass,
      accent: amber,
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
              _resetGame();
            });
          },
        ),
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

class _EvidenceChit extends StatefulWidget {
  final String letter;
  final int? shortcutIndex;
  final Color amber;
  final VoidCallback onTap;

  const _EvidenceChit({
    required this.letter,
    required this.shortcutIndex,
    required this.amber,
    required this.onTap,
  });

  @override
  State<_EvidenceChit> createState() => _EvidenceChitState();
}

class _EvidenceChitState extends State<_EvidenceChit> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 48,
          height: 56,
          transform: Matrix4.translationValues(0, _isHovering ? -3.0 : 0, 0),
          decoration: BoxDecoration(
            color: const Color(0xFF221A14),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHovering
                  ? widget.amber
                  : widget.amber.withValues(alpha: 0.35),
              width: _isHovering ? 1.8 : 1.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0xFF0E0A07),
                blurRadius: 0,
                offset: Offset(0, 3.5),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (widget.shortcutIndex != null)
                Positioned(
                  top: 3,
                  left: 6,
                  child: Text(
                    '${widget.shortcutIndex}',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: widget.amber.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              Text(
                widget.letter,
                style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeskInvestigationPainter extends CustomPainter {
  final Color accent;
  _DeskInvestigationPainter({required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    // Subtle radial warm vignette in the center
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final radialPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.topCenter,
        radius: 1.2,
        colors: [accent.withValues(alpha: 0.04), Colors.transparent],
      ).createShader(rect);
    canvas.drawRect(rect, radialPaint);

    // Subtle detective dossier grid lines
    final gridPaint = Paint()
      ..color = accent.withValues(alpha: 0.025)
      ..strokeWidth = 1.0;
    const spacing = 50.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Faint magnifying crosshair watermark in corner
    final ringPaint = Paint()
      ..color = accent.withValues(alpha: 0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final center = Offset(size.width * 0.85, size.height * 0.18);
    canvas.drawCircle(center, 38, ringPaint);
    canvas.drawLine(
      Offset(center.dx + 26, center.dy + 26),
      Offset(center.dx + 48, center.dy + 48),
      ringPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _DeskInvestigationPainter oldDelegate) => false;
}
