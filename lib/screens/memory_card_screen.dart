import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../data/memory_card_data.dart';
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

const Map<String, String> _memoryDictionary = memoryCardDictionary;

class MemoryCard {
  final int id;
  final String text;
  final String translationPairId;
  final bool isEnglish;
  bool isFaceUp;
  bool isMatched;

  MemoryCard({
    required this.id,
    required this.text,
    required this.translationPairId,
    required this.isEnglish,
    this.isFaceUp = false,
    this.isMatched = false,
  });
}

enum MemoryGameState { starting, playing, won, lost, review }

class MemoryViewModel extends ChangeNotifier {
  final int maxWrongGuesses = 5;
  List<MemoryCard> cards = [];
  int wrongGuesses = 0;
  int score = 0;
  int highScore = 0;
  bool isNewHighScore = false;
  final List<GameReviewItem> sessionReviewItems = [];
  MemoryGameState gameState = MemoryGameState.starting;
  List<int> selectedIndices = [];
  bool isProcessing = false;
  bool _isDisposed = false;
  int gameRound = 0;
  bool isTtsMuted = false;
  String? heartStatusMessage;
  Timer? _statusMessageTimer;
  bool isPaused = false;

  void pause() {
    isPaused = true;
    _statusMessageTimer?.cancel();
    TtsService.instance.stop();
    notifyListeners();
  }

  void resume() {
    isPaused = false;
    notifyListeners();
  }

  void _triggerHeartStatusMessage(String message) {
    _statusMessageTimer?.cancel();
    heartStatusMessage = message;
    notifyListeners();
    _statusMessageTimer = Timer(const Duration(milliseconds: 2200), () {
      if (!_isDisposed) {
        heartStatusMessage = null;
        notifyListeners();
      }
    });
  }

  void toggleTtsMute() {
    isTtsMuted = !isTtsMuted;
    if (isTtsMuted) {
      TtsService.instance.stop();
    }
    notifyListeners();
  }

  final Map<String, String>? customDict;
  late Map<String, String> _activeDict;
  GameDifficulty difficulty = LevelService.instance.currentDifficulty;

  @override
  void dispose() {
    _isDisposed = true;
    _statusMessageTimer?.cancel();
    TtsService.instance.stop();
    super.dispose();
  }

  MemoryViewModel({this.customDict}) {
    _initDict();
    _startNewGame();
  }

  void _initDict() {
    final base = customDict ?? _memoryDictionary;
    _activeDict = LevelService.instance.filterDictionary(base, difficulty);
  }

  void updateDifficulty(GameDifficulty newDiff) {
    difficulty = newDiff;
    LevelService.instance.setDifficulty(newDiff);
    _initDict();
    resetGame();
  }

  void _startNewGame() async {
    gameRound++;
    final currentRound = gameRound;
    score = 0;
    isNewHighScore = false;
    sessionReviewItems.clear();
    highScore = ScoreService.instance.getHighScore('memory_match');

    final allKeys = _activeDict.keys.toList()..shuffle();
    final selectedPairsCount = min(10, allKeys.length);
    final selectedPairs = allKeys.take(selectedPairsCount).toList();

    cards.clear();
    int idCounter = 0;
    for (var key in selectedPairs) {
      cards.add(
        MemoryCard(
          id: idCounter++,
          text: key,
          translationPairId: key,
          isEnglish: true,
          isFaceUp: true,
        ),
      );
      cards.add(
        MemoryCard(
          id: idCounter++,
          text: _activeDict[key]!,
          translationPairId: key,
          isEnglish: false,
          isFaceUp: true,
        ),
      );
    }

    cards.shuffle();
    wrongGuesses = 0;
    selectedIndices.clear();
    gameState = MemoryGameState.starting;
    isProcessing = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 3500));
    if (_isDisposed) return;
    if (gameRound != currentRound) return;

    if (gameState == MemoryGameState.starting) {
      for (var card in cards) {
        card.isFaceUp = false;
      }
      gameState = MemoryGameState.playing;
      isProcessing = false;
      notifyListeners();
    }
  }

  void resetGame() {
    _startNewGame();
  }

  void flipCard(int index, BuildContext context) async {
    if (gameState != MemoryGameState.playing || isProcessing || isPaused) return;
    if (cards[index].isFaceUp || cards[index].isMatched) return;

    cards[index].isFaceUp = true;
    selectedIndices.add(index);
    notifyListeners();

    if (!isTtsMuted) {
      TtsService.instance.speak(cards[index].translationPairId);
    }

    if (selectedIndices.length == 2) {
      isProcessing = true;
      int idx1 = selectedIndices[0];
      int idx2 = selectedIndices[1];

      if (cards[idx1].translationPairId == cards[idx2].translationPairId &&
          cards[idx1].isEnglish != cards[idx2].isEnglish) {
        bool livesRestored = wrongGuesses > 0;

        cards[idx1].isMatched = true;
        cards[idx2].isMatched = true;
        wrongGuesses = 0;
        selectedIndices.clear();
        isProcessing = false;
        AudioService.playCorrect();

        final word = cards[idx1].translationPairId;
        final meaning = _activeDict[word] ?? '';
        sessionReviewItems.add(
          GameReviewItem(
            word: word,
            meaning: meaning,
            question: 'Kart Çifti',
            userAnswer: '$word ↔ $meaning',
            correctAnswer: '$word ↔ $meaning',
            isCorrect: true,
          ),
        );

        if (livesRestored) {
          _triggerHeartStatusMessage('+ Canlar Yenilendi! ❤️');
        } else {
          _triggerHeartStatusMessage('Harika Eşleşme! ✨');
        }

        _checkWinCondition();
        notifyListeners();
      } else {
        wrongGuesses++;
        AudioService.playIncorrect();

        final cardA = cards[idx1];
        final cardB = cards[idx2];
        final engCard =
            cardA.isEnglish ? cardA : (cardB.isEnglish ? cardB : null);
        if (engCard != null) {
          final word = engCard.translationPairId;
          final meaning = _activeDict[word] ?? '';
          if (meaning.isNotEmpty) {
            final wrong = cardA == engCard ? cardB.text : cardA.text;
            MistakeService.instance.recordMistake(
              word: word,
              meaning: meaning,
              sourceGame: 'Memory Match',
              wrongAnswer: wrong,
            );
            sessionReviewItems.add(
              GameReviewItem(
                word: word,
                meaning: meaning,
                question: 'Kart Çifti',
                userAnswer: '${cardA.text} ↔ ${cardB.text}',
                correctAnswer: '$word ↔ $meaning',
                isCorrect: false,
                note: '$word = $meaning',
              ),
            );
          }
        }

        _checkWinCondition();

        await Future.delayed(const Duration(milliseconds: 1000));
        if (_isDisposed) return;

        if (gameState == MemoryGameState.playing ||
            gameState == MemoryGameState.lost) {
          cards[idx1].isFaceUp = false;
          cards[idx2].isFaceUp = false;
        }
        selectedIndices.clear();
        isProcessing = false;
        notifyListeners();
      }
    }
  }

  void _checkWinCondition() async {
    final matchedCount = cards.where((c) => c.isMatched).length ~/ 2;
    if (cards.isNotEmpty && cards.every((c) => c.isMatched)) {
      gameState = MemoryGameState.won;
      AudioService.playSuccess();
      score = (matchedCount * 100) + ((maxWrongGuesses - wrongGuesses) * 50);
      final res = await ScoreService.instance.recordScore(
        gameId: 'memory_match',
        score: score,
        streak: matchedCount,
      );
      if (!_isDisposed) {
        highScore = res.highScore;
        isNewHighScore = res.isNewHighScore;
        notifyListeners();
      }
    } else if (wrongGuesses >= maxWrongGuesses) {
      gameState = MemoryGameState.lost;
      AudioService.playFailure();
      score = matchedCount * 100;
      final res = await ScoreService.instance.recordScore(
        gameId: 'memory_match',
        score: score,
        streak: matchedCount,
      );
      if (!_isDisposed) {
        highScore = res.highScore;
        isNewHighScore = res.isNewHighScore;
        notifyListeners();
      }
      for (var card in cards) {
        if (!card.isMatched && card.isEnglish) {
          final word = card.translationPairId;
          final meaning = _activeDict[word] ?? '';
          if (meaning.isNotEmpty) {
            MistakeService.instance.recordMistake(
              word: word,
              meaning: meaning,
              sourceGame: 'Memory Match',
            );
            if (!sessionReviewItems.any((r) => r.word == word)) {
              sessionReviewItems.add(
                GameReviewItem(
                  word: word,
                  meaning: meaning,
                  question: 'Kart Çifti',
                  userAnswer: 'Açılamadı',
                  correctAnswer: '$word ↔ $meaning',
                  isCorrect: false,
                  note: '$word = $meaning',
                ),
              );
            }
          }
        }
      }
    }
  }

  void reviewAnswers() {
    gameState = MemoryGameState.review;
    for (var card in cards) {
      card.isFaceUp = true;
    }
    notifyListeners();
  }
}

class MemoryGameScreen extends StatelessWidget {
  final Map<String, String>? customDict;
  const MemoryGameScreen({super.key, this.customDict});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MemoryViewModel(customDict: customDict),
      child: const _MemoryGameView(),
    );
  }
}

class _MemoryGameView extends StatefulWidget {
  const _MemoryGameView();

  @override
  State<_MemoryGameView> createState() => _MemoryGameViewState();
}

class _MemoryGameViewState extends State<_MemoryGameView> {
  late final FocusNode _focusNode;
  int _cursorIndex = 0;
  bool _showKeyboardCursor = false;

  static const Color _accentBlue = Color(0xFF3B82F6);
  static const Color _accentRed = Color(0xFFEF4444);
  static const Color _accentGreen = Color(0xFF10B981);
  static const Color _accentAmber = Color(0xFFF59E0B);

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final vm = context.read<MemoryViewModel>();
      final bool hasLevelSelect = vm.customDict == null;
      final result = await GameTutorialPopup.show(
        context,
        tutorialKey: 'memory_match_tutorial',
        title: 'Memory Match',
        icon: FontAwesomeIcons.layerGroup,
        color: _accentBlue,
        tutorialTextTr:
            'Memory Match oyununda hafızanızı ve kelime bilginizi konuşturun!\n\n'
            '• Kapalı kartlara dokunarak İngilizce (EN) kelimeleri ve Türkçe (TR) karşılıklarını açın.\n'
            '• Açtığınız iki kart birbiriyle eşleşirse açık kalır ve canlarınız yenilenir.\n'
            '• Kartların yerlerini aklınızda tutarak tüm çiftleri tamamlayın!',
        tutorialTextEn:
            'In Memory Match, flip cards to find pairs of English words and their Turkish meanings. Match all pairs to clear the board!',
        includeLevelSelection: hasLevelSelect,
        initialDifficulty: vm.difficulty,
      );
      if (mounted) {
        if (hasLevelSelect && result.difficulty != null) {
          vm.updateDifficulty(result.difficulty!);
        } else {
          vm.resetGame();
        }
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    TtsService.instance.stop();
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final viewModel = context.read<MemoryViewModel>();
    final key = event.logicalKey;
    final int totalCards = viewModel.cards.length;
    if (totalCards == 0) return KeyEventResult.ignored;
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWide = screenWidth >= 820;
    final int cols = isWide ? 5 : 4;

    if (key == LogicalKeyboardKey.arrowRight) {
      setState(() {
        _showKeyboardCursor = true;
        _cursorIndex = (_cursorIndex + 1).clamp(0, totalCards - 1);
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      setState(() {
        _showKeyboardCursor = true;
        _cursorIndex = (_cursorIndex - 1).clamp(0, totalCards - 1);
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _showKeyboardCursor = true;
        _cursorIndex = (_cursorIndex + cols).clamp(0, totalCards - 1);
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _showKeyboardCursor = true;
        _cursorIndex = (_cursorIndex - cols).clamp(0, totalCards - 1);
      });
      return KeyEventResult.handled;
    }
    if ((key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) &&
        _showKeyboardCursor) {
      viewModel.flipCard(_cursorIndex, context);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MemoryViewModel>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWide = screenWidth >= 820;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
        onTap: () => _focusNode.requestFocus(),
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            final vm = context.read<MemoryViewModel>();
            vm.pause();
            final shouldPop = await showExitConfirmationDialog(context);
            if (shouldPop && context.mounted) {
              Navigator.of(context).pop();
            } else if (context.mounted) {
              vm.resume();
            }
          },
          child: Scaffold(
            backgroundColor:
                isDark ? const Color(0xFF0D0D14) : const Color(0xFFF1F5F9),
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: MarqueeTitle(
                title: 'Memory Match',
                leadingIcon: const Icon(
                  FontAwesomeIcons.layerGroup,
                  color: _accentBlue,
                  size: 18,
                ),
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: textColor,
                ),
              ),
              centerTitle: false,
              actions: [
                LevelBadgeButton(
                  difficulty: viewModel.difficulty,
                  accentColor: _accentBlue,
                  onTap: () async {
                    final chosen = await LevelSelectionDialog.show(
                      context,
                      initialDifficulty: viewModel.difficulty,
                      accentColor: _accentBlue,
                      title: 'Memory Match: Seviye Değiştir',
                    );
                    if (chosen != null && mounted) {
                      viewModel.updateDifficulty(chosen);
                    }
                  },
                ),
                IconButton(
                  icon: Icon(
                    viewModel.isTtsMuted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    color: viewModel.isTtsMuted ? Colors.grey : _accentBlue,
                  ),
                  onPressed: viewModel.toggleTtsMute,
                  tooltip:
                      viewModel.isTtsMuted ? 'Sesi Aç (TTS)' : 'Sustur (TTS)',
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: viewModel.resetGame,
                  tooltip: 'Yeniden Başlat',
                ),
              ],
            ),
            body: Stack(
              children: [
                SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isWide ? 1140 : 640,
                      ),
                      child: isWide
                          ? _buildWideLayout(
                              context,
                              viewModel,
                              isDark,
                              textColor,
                            )
                          : _buildMobileLayout(
                              context,
                              viewModel,
                              isDark,
                              textColor,
                            ),
                    ),
                  ),
                ),
                if (viewModel.gameState == MemoryGameState.won ||
                    viewModel.gameState == MemoryGameState.lost)
                  _buildGameOverPopUp(context, viewModel),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    MemoryViewModel viewModel,
    bool isDark,
    Color textColor,
  ) {
    final int matchedPairs =
        viewModel.cards.where((c) => c.isMatched).length ~/ 2;
    final int totalPairs = viewModel.cards.length ~/ 2;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161622) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF28283E) : const Color(0xFFE2E8F0),
                width: 1.5,
              ),
            ),
            child: viewModel.gameState == MemoryGameState.starting
                ? _buildMemorizeBanner(viewModel)
                : Row(
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: _buildLivesIndicator(viewModel, _accentRed),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _accentBlue.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Eşleşen: $matchedPairs / $totalPairs',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _accentBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _buildRightGameGrid(
              context,
              viewModel,
              isDark,
              textColor,
              false,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildWideLayout(
    BuildContext context,
    MemoryViewModel viewModel,
    bool isDark,
    Color textColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildLeftSidebar(context, viewModel, isDark, textColor),
          const SizedBox(width: 24),
          Expanded(
            child: _buildRightGameGrid(
              context,
              viewModel,
              isDark,
              textColor,
              true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemorizeBanner(MemoryViewModel viewModel) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(viewModel.gameRound),
      tween: Tween<double>(begin: 1.0, end: 0.0),
      duration: const Duration(milliseconds: 3500),
      builder: (context, value, _) {
        final Color barColor = value > 0.3 ? _accentBlue : _accentRed;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.visibility_rounded, color: barColor, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Kartların yerini hafızana kaydet! (${(value * 3.5).ceil()} sn)',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: barColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: barColor.withValues(alpha: 0.18),
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLeftSidebar(
    BuildContext context,
    MemoryViewModel viewModel,
    bool isDark,
    Color textColor,
  ) {
    final int matchedPairs =
        viewModel.cards.where((c) => c.isMatched).length ~/ 2;
    final int totalPairs = viewModel.cards.length ~/ 2;

    return Container(
      width: 290,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161622) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF28283E) : const Color(0xFFE2E8F0),
          width: 2,
        ),
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _accentBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  FontAwesomeIcons.layerGroup,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Memory Match',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                      ),
                    ),
                    Text(
                      'EN ↔ TR Eşleştirme',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textColor.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(
            color: isDark ? Colors.white12 : Colors.black12,
            height: 1,
          ),
          const SizedBox(height: 18),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (viewModel.gameState == MemoryGameState.starting)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _accentBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _accentBlue.withValues(alpha: 0.35),
                        ),
                      ),
                      child: _buildMemorizeBanner(viewModel),
                    )
                  else ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E1E2E)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          _buildLivesIndicator(viewModel, _accentRed),
                          const SizedBox(height: 6),
                          Text(
                            'Kalan Hak: ${viewModel.maxWrongGuesses - viewModel.wrongGuesses} / ${viewModel.maxWrongGuesses}',
                            style: GoogleFonts.outfit(
                              color: textColor.withValues(alpha: 0.7),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E1E2E)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'EŞLEŞEN ÇİFTLER',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: textColor.withValues(alpha: 0.6),
                          ),
                        ),
                        Text(
                          '$matchedPairs / $totalPairs',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: _accentGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E1E2E)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.lightbulb_outline_rounded,
                              color: _accentAmber,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'İpuçları',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• Mavi (EN) ve Turuncu (TR) kart çiftlerini eşleştirin.\n• Her doğru eşleşme canlarınızı tamamen yeniler! ❤️\n• Klavye ok tuşları ve Boşluk/Enter ile de oynayabilirsiniz.',
                          style: GoogleFonts.outfit(
                            fontSize: 12.5,
                            color: textColor.withValues(alpha: 0.7),
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: viewModel.resetGame,
            icon: const Icon(Icons.replay_rounded, size: 18),
            label: Text(
              'Yeniden Başlat',
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () async {
              final vm = context.read<MemoryViewModel>();
              vm.pause();
              final shouldPop = await showExitConfirmationDialog(context);
              if (shouldPop && context.mounted) {
                Navigator.of(context).pop();
              } else if (context.mounted) {
                vm.resume();
              }
            },
            icon: Icon(
              Icons.arrow_back_rounded,
              size: 18,
              color: textColor.withValues(alpha: 0.7),
            ),
            label: Text(
              'Ana Menü',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: textColor.withValues(alpha: 0.7),
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: BorderSide(color: textColor.withValues(alpha: 0.2)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightGameGrid(
    BuildContext context,
    MemoryViewModel viewModel,
    bool isDark,
    Color textColor,
    bool isWide,
  ) {
    final cols = isWide ? 5 : 4;
    final rows = isWide ? 4 : 5;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double spacing = isWide ? 12.0 : 8.0;
        final gridWidth = constraints.maxWidth;
        final gridHeight = constraints.maxHeight;

        double cardWidth = (gridWidth - (cols - 1) * spacing) / cols;
        double cardHeight = (gridHeight - (rows - 1) * spacing) / rows;
        double aspectRatio = 0.85;
        if (cardWidth > 0 && cardHeight > 0) {
          aspectRatio = (cardWidth / cardHeight).clamp(0.55, 2.2);
        }

        return GridView.builder(
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            childAspectRatio: aspectRatio,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          itemCount: viewModel.cards.length,
          itemBuilder: (context, index) {
            final isCursorSelected = _showKeyboardCursor &&
                index == _cursorIndex &&
                viewModel.gameState == MemoryGameState.playing;
            return _buildCard(
              context,
              viewModel,
              index,
              isDark,
              textColor,
              isCursorSelected: isCursorSelected,
            );
          },
        );
      },
    );
  }

  Widget _buildLivesIndicator(MemoryViewModel viewModel, Color heartColor) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: viewModel.heartStatusMessage != null
          ? Container(
              key: ValueKey(viewModel.heartStatusMessage),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.6),
                  width: 1.2,
                ),
              ),
              child: Text(
                viewModel.heartStatusMessage!,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF10B981),
                ),
              ),
            )
          : Row(
              key: const ValueKey('hearts_row'),
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: List.generate(viewModel.maxWrongGuesses, (index) {
                final isLost = index < viewModel.wrongGuesses;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Icon(
                    isLost
                        ? Icons.favorite_border_rounded
                        : Icons.favorite_rounded,
                    color: isLost
                        ? Colors.grey.withValues(alpha: 0.35)
                        : heartColor,
                    size: 24,
                  ),
                );
              }),
            ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    MemoryViewModel viewModel,
    int index,
    bool isDark,
    Color textColor, {
    bool isCursorSelected = false,
  }) {
    final card = viewModel.cards[index];
    final bool isUp = card.isFaceUp ||
        card.isMatched ||
        viewModel.gameState == MemoryGameState.starting ||
        viewModel.gameState == MemoryGameState.review;

    return GestureDetector(
      onTap: () {
        if (_showKeyboardCursor) {
          setState(() => _showKeyboardCursor = false);
        }
        viewModel.flipCard(index, context);
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          transitionBuilder: (Widget child, Animation<double> animation) {
            final rotateAnim = Tween(begin: pi, end: 0.0).animate(animation);
            return AnimatedBuilder(
              animation: rotateAnim,
              child: child,
              builder: (context, widget) {
                final isUnder = (const ValueKey(true) != widget!.key);
                double angle = rotateAnim.value;
                if (isUnder) {
                  angle = min(angle, pi / 2);
                }
                return Transform(
                  transform: Matrix4.rotationY(angle),
                  alignment: Alignment.center,
                  child: angle > pi / 2 ? const SizedBox.shrink() : widget,
                );
              },
            );
          },
          child: isUp
              ? _buildFaceUpCard(
                  card,
                  isDark,
                  textColor,
                  isCursorSelected: isCursorSelected,
                )
              : _buildFaceDownCard(
                  isDark,
                  isCursorSelected: isCursorSelected,
                ),
        ),
      ),
    );
  }

  Widget _buildFaceUpCard(
    MemoryCard card,
    bool isDark,
    Color textColor, {
    required bool isCursorSelected,
  }) {
    final Color langColor =
        card.isEnglish ? const Color(0xFF0284C7) : const Color(0xFFD97706);
    final Color borderColor = card.isMatched
        ? _accentGreen
        : isCursorSelected
            ? _accentBlue
            : langColor.withValues(alpha: 0.7);
    final Color lipColor = card.isMatched
        ? const Color(0xFF047857)
        : (isDark ? const Color(0xFF0B0D14) : const Color(0xFFCBD5E1));
    final Color surfaceColor = card.isMatched
        ? (isDark ? const Color(0xFF0E2923) : const Color(0xFFECFDF5))
        : (isDark ? const Color(0xFF1C2033) : Colors.white);

    return Container(
      key: const ValueKey(true),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor,
          width: card.isMatched || isCursorSelected ? 2.2 : 1.6,
        ),
        boxShadow: [
          BoxShadow(
            color: lipColor,
            offset: const Offset(0, 3),
            blurRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top language / matched badge row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: langColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  card.isEnglish ? 'EN' : 'TR',
                  style: GoogleFonts.outfit(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    color: langColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (card.isMatched)
                const Icon(
                  Icons.check_circle_rounded,
                  color: _accentGreen,
                  size: 14,
                ),
            ],
          ),
          // Word text
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 130),
                  child: Text(
                    card.text,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                      color: card.isMatched
                          ? (isDark
                              ? const Color(0xFF6EE7B7)
                              : const Color(0xFF047857))
                          : textColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
        ],
      ),
    );
  }

  Widget _buildFaceDownCard(
    bool isDark, {
    required bool isCursorSelected,
  }) {
    final Color cardBg =
        isDark ? const Color(0xFF1A2238) : const Color(0xFFDBEAFE);
    final Color borderColor = isCursorSelected
        ? _accentAmber
        : (isDark ? const Color(0xFF2E3B5E) : const Color(0xFF93C5FD));
    final Color lipColor =
        isDark ? const Color(0xFF0E1322) : const Color(0xFF60A5FA);

    return Container(
      key: const ValueKey(false),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor,
          width: isCursorSelected ? 2.5 : 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: lipColor,
            offset: const Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: _accentBlue.withValues(alpha: isDark ? 0.22 : 0.18),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _accentBlue.withValues(alpha: 0.45),
            width: 1.2,
          ),
        ),
        alignment: Alignment.center,
        child: const Icon(
          FontAwesomeIcons.question,
          color: _accentBlue,
          size: 16,
        ),
      ),
    );
  }

  Widget _buildGameOverPopUp(BuildContext context, MemoryViewModel viewModel) {
    final isWon = viewModel.gameState == MemoryGameState.won;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final popupBgColor = isDark ? const Color(0xFF161622) : Colors.white;
    final titleColor = isWon ? _accentGreen : _accentRed;
    final subtextColor = isDark ? Colors.white60 : Colors.black54;
    final backBtnColor = isDark ? Colors.white70 : Colors.black54;

    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            padding: const EdgeInsets.all(24),
            constraints: BoxConstraints(
              maxWidth: 420,
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            decoration: BoxDecoration(
              color: popupBgColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: titleColor.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (viewModel.isNewHighScore)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _accentAmber,
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
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              fontSize: 12,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: titleColor.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isWon
                          ? Icons.emoji_events_rounded
                          : Icons.sentiment_very_dissatisfied_rounded,
                      size: 52,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    isWon ? 'Tebrikler!' : 'Oyun Bitti!',
                    style: GoogleFonts.outfit(
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isWon
                        ? 'Tüm kelime çiftlerini başarıyla eşleştirdin!'
                        : 'Tahmin hakkın sona erdi.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: subtextColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF202032)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.stars_rounded,
                          color: Colors.amber,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'SCORE: ${viewModel.score}',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Icon(
                          Icons.military_tech_rounded,
                          color: Colors.orange,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'BEST: ${viewModel.highScore}',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (viewModel.sessionReviewItems.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    GameReviewAccordion(
                      items: viewModel.sessionReviewItems,
                      accentColor: titleColor,
                    ),
                  ],
                  const SizedBox(height: 18),
                  if (!isWon) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: viewModel.reviewAnswers,
                        icon: const Icon(Icons.visibility_rounded),
                        label: Text(
                          'Doğru Cevapları İncele',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accentBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: viewModel.resetGame,
                      icon: const Icon(Icons.replay_rounded),
                      label: Text(
                        'Yeniden Oyna',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: titleColor,
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
                        foregroundColor: backBtnColor,
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
