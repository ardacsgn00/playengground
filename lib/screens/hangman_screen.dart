import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../data/hangman_data.dart';
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

const Map<String, String> _mockDictionary = hangmanDictionary;

enum GameState { playing, won, lost }

class HangmanViewModel extends ChangeNotifier {
  final int maxWrongGuesses = 6;
  final Map<String, String>? customDict;
  GameDifficulty difficulty = LevelService.instance.currentDifficulty;

  late String targetWord;
  late Set<String> guessedLetters;
  late int wrongGuesses;
  late GameState gameState;
  String? currentHint;
  bool isHintLoading = false;
  int hintsRemaining = 3;
  bool _isDisposed = false;

  int score = 0;
  int highScore = 0;
  int winStreak = 0;
  bool isNewHighScore = false;
  List<GameReviewItem> sessionReviewItems = [];

  @override
  void dispose() {
    _isDisposed = true;
    TtsService.instance.stop();
    super.dispose();
  }

  HangmanViewModel({this.customDict}) {
    _startNewGame();
  }

  void updateDifficulty(GameDifficulty newDiff) {
    difficulty = newDiff;
    LevelService.instance.setDifficulty(newDiff);
    _startNewGame();
  }

  void _startNewGame() {
    final Map<String, String> activeDict = {};
    final baseDict = (customDict != null && customDict!.isNotEmpty)
        ? customDict!
        : _mockDictionary;
    final sourceDict =
        LevelService.instance.filterDictionary(baseDict, difficulty);
    sourceDict.forEach((key, value) => activeDict[key.toUpperCase()] = value);

    final allKeys = activeDict.keys.toList();
    targetWord = allKeys[Random().nextInt(allKeys.length)];
    guessedLetters = {};
    wrongGuesses = 0;
    gameState = GameState.playing;
    currentHint = null;
    isHintLoading = false;
    hintsRemaining = 3;
    isNewHighScore = false;
    sessionReviewItems = [];
    highScore = ScoreService.instance.getHighScore('hangman');
    notifyListeners();
  }

  void resetGame() {
    if (gameState == GameState.lost) {
      score = 0;
      winStreak = 0;
    }
    _startNewGame();
  }

  void guessLetter(String letter) {
    if (gameState != GameState.playing || guessedLetters.contains(letter)) {
      return;
    }

    guessedLetters.add(letter);

    if (!targetWord.contains(letter)) {
      wrongGuesses++;
      AudioService.playIncorrect();
    } else {
      AudioService.playCorrect();
    }

    _checkGameState();
    notifyListeners();
  }

  void _checkGameState() {
    bool hasWon = true;
    for (int i = 0; i < targetWord.length; i++) {
      String char = targetWord[i];
      if (char == ' ' || char == '-') continue;
      if (!guessedLetters.contains(char)) {
        hasWon = false;
        break;
      }
    }

    final sourceDict = (customDict != null && customDict!.isNotEmpty)
        ? customDict!
        : _mockDictionary;
    String rawHint = sourceDict[targetWord] ??
        sourceDict[targetWord.toLowerCase()] ??
        sourceDict[targetWord.toUpperCase()] ??
        '';
    String meaning = rawHint;
    if (rawHint.contains('(') && rawHint.contains(')')) {
      int start = rawHint.indexOf('(');
      int end = rawHint.lastIndexOf(')');
      meaning = rawHint.substring(start + 1, end).trim();
    }
    if (meaning.isEmpty) meaning = rawHint;
    if (meaning.isEmpty) meaning = 'Gizli Kelime';

    if (hasWon) {
      gameState = GameState.won;
      AudioService.playSuccess();
      TtsService.instance.speak(targetWord);

      winStreak++;
      score += (maxWrongGuesses - wrongGuesses) * 20 + 50;
      sessionReviewItems = [
        GameReviewItem(
          word: targetWord,
          meaning: meaning,
          question: 'Kelimeyi Bul: ${targetWord.split('').join(' ')}',
          userAnswer: 'Doğru Tahmin',
          correctAnswer: targetWord,
          isCorrect: true,
        ),
      ];
      ScoreService.instance
          .recordScore(gameId: 'hangman', score: score, streak: winStreak)
          .then((res) {
        if (_isDisposed) return;
        highScore = res.highScore;
        isNewHighScore = res.isNewHighScore;
        notifyListeners();
      });
    } else if (wrongGuesses >= maxWrongGuesses) {
      gameState = GameState.lost;
      AudioService.playFailure();
      TtsService.instance.speak(targetWord);

      sessionReviewItems = [
        GameReviewItem(
          word: targetWord,
          meaning: meaning,
          question: 'Kelimeyi Bul: ${targetWord.split('').join(' ')}',
          userAnswer: guessedLetters.join(', '),
          correctAnswer: targetWord,
          isCorrect: false,
        ),
      ];
      ScoreService.instance
          .recordScore(gameId: 'hangman', score: score, streak: winStreak)
          .then((res) {
        if (_isDisposed) return;
        highScore = res.highScore;
        isNewHighScore = res.isNewHighScore;
        notifyListeners();
      });

      MistakeService.instance.recordMistake(
        word: targetWord,
        meaning: meaning,
        sourceGame: 'Hangman',
        wrongAnswer: guessedLetters.join(', '),
      );
    }
  }

  Future<void> fetchGeminiHint() async {
    if (hintsRemaining <= 0 || isHintLoading) return;

    isHintLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 350));
    if (_isDisposed) return;

    final Map<String, String> activeDict = {};
    final sourceDict = (customDict != null && customDict!.isNotEmpty)
        ? customDict!
        : _mockDictionary;
    sourceDict.forEach((key, value) => activeDict[key.toUpperCase()] = value);

    String fullHint = activeDict[targetWord] ?? 'A custom English word.';
    String englishHint = fullHint;
    String turkishHint = '';

    if (fullHint.contains('(') && fullHint.contains(')')) {
      int start = fullHint.indexOf('(');
      int end = fullHint.lastIndexOf(')');
      englishHint = fullHint.substring(0, start).trim();
      turkishHint = fullHint.substring(start + 1, end).trim();
    }

    if (hintsRemaining == 3) {
      currentHint = englishHint;
    } else if (hintsRemaining == 2) {
      currentHint =
          "${currentHint ?? ''}\n\n💡 İpucu: '${targetWord[0]}' harfi ile başlıyor ve ${targetWord.length} harfli.";
    } else if (hintsRemaining == 1) {
      currentHint = "${currentHint ?? ''}\n\n🇹🇷 Türkçe: $turkishHint";
    }

    hintsRemaining--;
    isHintLoading = false;
    notifyListeners();
  }
}

class HangmanGameScreen extends StatelessWidget {
  final Map<String, String>? customDict;
  const HangmanGameScreen({super.key, this.customDict});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HangmanViewModel(customDict: customDict),
      child: const _HangmanGameView(),
    );
  }
}

class _HangmanGameView extends StatefulWidget {
  const _HangmanGameView();

  @override
  State<_HangmanGameView> createState() => _HangmanGameViewState();
}

class _HangmanGameViewState extends State<_HangmanGameView> {
  late final FocusNode _focusNode;

  static const Color _accentRed = Color(0xFFEF4444);
  static const Color _accentBlue = Color(0xFF3B82F6);

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final vm = context.read<HangmanViewModel>();
      final bool hasLevelSelect = vm.customDict == null;
      final result = await GameTutorialPopup.show(
        context,
        tutorialKey: 'hangman_tutorial',
        title: 'Hangman',
        icon: FontAwesomeIcons.personThroughWindow,
        color: _accentRed,
        tutorialTextTr:
            'Hangman oyununda gizli İngilizce kelimeyi harf harf tahmin edin!\n\n'
            '• Ekrandaki yerleşik klavyeden harflere dokunabilir veya doğrudan fiziksel klavyenizden harf tuşlayabilirsiniz.\n'
            '• Her yanlış tahmin bir canınızı eksiltir ve çizimi bir adım ilerletir. Toplam 6 hakkınız vardır.\n'
            '• Takıldığınız anlarda İpucu butonunu kullanarak İngilizce tanım, ilk harf ve Türkçe anlam desteği alabilirsiniz.',
        tutorialTextEn:
            'In Hangman, try to guess the hidden English word letter by letter. Each wrong guess costs you a heart and brings the hangman one step closer. Use the hints when you get stuck!',
        includeLevelSelection: hasLevelSelect,
        initialDifficulty: vm.difficulty,
      );
      if (mounted && hasLevelSelect && result.difficulty != null) {
        vm.updateDifficulty(result.difficulty!);
      }
      if (mounted) _focusNode.requestFocus();
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
    final viewModel = context.read<HangmanViewModel>();
    if (viewModel.gameState != GameState.playing) {
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.space) {
        viewModel.resetGame();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    final label = event.logicalKey.keyLabel;
    if (label.length == 1 && RegExp(r'^[a-zA-Z]$').hasMatch(label)) {
      viewModel.guessLetter(label.toUpperCase());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<HangmanViewModel>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 820;

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
            final shouldPop = await showExitConfirmationDialog(context);
            if (shouldPop && context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: Scaffold(
            backgroundColor:
                isDark ? const Color(0xFF0D0D14) : const Color(0xFFF1F5F9),
            appBar: AppBar(
              elevation: 0,
              iconTheme: IconThemeData(color: textColor),
              title: MarqueeTitle(
                title: 'Hangman',
                leadingIcon: const Icon(
                  FontAwesomeIcons.personThroughWindow,
                  color: _accentRed,
                  size: 18,
                ),
                style: GoogleFonts.outfit(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              centerTitle: false,
              backgroundColor: Colors.transparent,
              actions: [
                LevelBadgeButton(
                  difficulty: viewModel.difficulty,
                  accentColor: _accentRed,
                  onTap: () async {
                    final chosen = await LevelSelectionDialog.show(
                      context,
                      initialDifficulty: viewModel.difficulty,
                      accentColor: _accentRed,
                      title: 'Hangman: Seviye Değiştir',
                    );
                    if (chosen != null && mounted) {
                      viewModel.updateDifficulty(chosen);
                    }
                  },
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
                        maxWidth: isDesktop ? 980 : 620,
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 24 : 14,
                          vertical: 8,
                        ),
                        child: Column(
                          children: [
                            _buildTopHud(viewModel, isDark, textColor),
                            const SizedBox(height: 12),
                            Expanded(
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                child: isDesktop
                                    ? _buildDesktopCenterArea(
                                        viewModel,
                                        isDark,
                                        textColor,
                                      )
                                    : _buildMobileCenterArea(
                                        viewModel,
                                        isDark,
                                        textColor,
                                      ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            HangmanKeyboardWidget(
                              viewModel: viewModel,
                              textColor: textColor,
                              isDesktop: isDesktop,
                            ),
                            SizedBox(height: isDesktop ? 12 : 6),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (viewModel.gameState != GameState.playing)
                  _buildGameOverPopUp(context, viewModel),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopHud(
    HangmanViewModel viewModel,
    bool isDark,
    Color textColor,
  ) {
    final remainingLives = viewModel.maxWrongGuesses - viewModel.wrongGuesses;
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
          // Hearts
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...List.generate(viewModel.maxWrongGuesses, (index) {
                    final isAlive = index < remainingLives;
                    return Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        isAlive
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: isAlive
                            ? _accentRed
                            : Colors.grey.withValues(alpha: 0.35),
                        size: 22,
                      ),
                    );
                  }),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _accentRed.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$remainingLives / ${viewModel.maxWrongGuesses}',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _accentRed,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (viewModel.winStreak > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF97316),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '🔥 ${viewModel.winStreak}x',
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
                const Icon(
                  Icons.stars_rounded,
                  color: Color(0xFFF59E0B),
                  size: 16,
                ),
                const SizedBox(width: 5),
                Text(
                  '${viewModel.score}',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
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

  Widget _buildDesktopCenterArea(
    HangmanViewModel viewModel,
    bool isDark,
    Color textColor,
  ) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left: Gallows Stage Card
          SizedBox(
            width: 280,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161622) : Colors.white,
                borderRadius: BorderRadius.circular(22),
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
                  _buildHangmanDrawing(
                    viewModel,
                    isDark,
                    textColor,
                    height: 170,
                    width: 150,
                  ),
                  const SizedBox(height: 14),
                  _buildHintButtonOnly(viewModel),
                ],
              ),
            ),
          ),
          const SizedBox(width: 18),

          // Right: Target Word & Hints Card
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161622) : Colors.white,
                borderRadius: BorderRadius.circular(22),
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _accentRed.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'GİZLİ KELİME (${viewModel.targetWord.replaceAll(' ', '').length} HARF)',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                        color: _accentRed,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  _buildWordDisplay(viewModel, isDark, textColor),
                  if (viewModel.currentHint != null) ...[
                    const SizedBox(height: 20),
                    _buildHintCardOnly(viewModel, isDark, textColor),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileCenterArea(
    HangmanViewModel viewModel,
    bool isDark,
    Color textColor,
  ) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161622) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF28283E) : const Color(0xFFE2E8F0),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildHangmanDrawing(
                    viewModel,
                    isDark,
                    textColor,
                    height: 125,
                    width: 115,
                  ),
                  if (viewModel.customDict == null ||
                      viewModel.customDict!.isEmpty) ...[
                    const SizedBox(width: 16),
                    Flexible(child: _buildHintButtonOnly(viewModel)),
                  ],
                ],
              ),
              const SizedBox(height: 18),
              _buildWordDisplay(viewModel, isDark, textColor),
              if (viewModel.currentHint != null) ...[
                const SizedBox(height: 14),
                _buildHintCardOnly(viewModel, isDark, textColor),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHangmanDrawing(
    HangmanViewModel viewModel,
    bool isDark,
    Color textColor, {
    double height = 150,
    double width = 130,
  }) {
    return Container(
      height: height,
      width: width,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2D2D44) : const Color(0xFFE2E8F0),
        ),
      ),
      child: CustomPaint(
        painter: HangmanPainter(
          wrongGuesses: viewModel.wrongGuesses,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildWordDisplay(
    HangmanViewModel viewModel,
    bool isDark,
    Color textColor,
  ) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 10,
      children: viewModel.targetWord.split('').map((char) {
        if (char == ' ' || char == '-') {
          return Container(
            width: 18,
            height: 48,
            alignment: Alignment.center,
            child: Text(
              char,
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: textColor,
              ),
            ),
          );
        }
        final bool isGuessed = viewModel.guessedLetters.contains(char);
        final bool isLostReveal =
            viewModel.gameState == GameState.lost && !isGuessed;
        final bool showChar = isGuessed || isLostReveal;

        final Color boxBg = isGuessed
            ? const Color(0xFF10B981).withValues(alpha: isDark ? 0.18 : 0.12)
            : isLostReveal
                ? _accentRed.withValues(alpha: 0.16)
                : (isDark ? const Color(0xFF202032) : const Color(0xFFF1F5F9));
        final Color boxBorder = isGuessed
            ? const Color(0xFF10B981)
            : isLostReveal
                ? _accentRed
                : (isDark ? const Color(0xFF32324A) : const Color(0xFFCBD5E1));

        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 42,
          height: 50,
          decoration: BoxDecoration(
            color: boxBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: boxBorder, width: 2),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? const Color(0xFF0A0A10)
                    : Colors.black.withValues(alpha: 0.06),
                offset: const Offset(0, 3),
                blurRadius: 0,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            showChar ? char : '',
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: isLostReveal
                  ? _accentRed
                  : isGuessed
                      ? (isDark ? Colors.white : const Color(0xFF065F46))
                      : textColor,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHintButtonOnly(HangmanViewModel viewModel) {
    if (viewModel.customDict != null && viewModel.customDict!.isNotEmpty) {
      return const SizedBox.shrink();
    }
    if (viewModel.hintsRemaining <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'İpucu kalmadı',
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.grey,
          ),
        ),
      );
    }

    final String label = viewModel.hintsRemaining == 3
        ? 'İpucu (3)'
        : viewModel.hintsRemaining == 2
            ? 'Harf İpucu (2)'
            : 'Türkçe Anlam (1)';

    return ElevatedButton.icon(
      onPressed: viewModel.isHintLoading ? null : viewModel.fetchGeminiHint,
      icon: viewModel.isHintLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.lightbulb_rounded, size: 18),
      label: Text(
        label,
        style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: _accentBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _buildHintCardOnly(
    HangmanViewModel viewModel,
    bool isDark,
    Color textColor,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _accentBlue.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _accentBlue.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_rounded, color: _accentBlue, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              viewModel.currentHint!,
              style: GoogleFonts.outfit(
                color: textColor,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameOverPopUp(BuildContext context, HangmanViewModel viewModel) {
    final bool isWon = viewModel.gameState == GameState.won;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final popupBgColor = isDark ? const Color(0xFF161622) : Colors.white;
    final titleColor =
        isWon ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final subtextColor = isDark ? Colors.white60 : Colors.black54;
    final wordColor = isDark ? Colors.white : Colors.black87;
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
              maxWidth: 440,
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
                        color: const Color(0xFFF59E0B),
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
                    isWon ? 'Harika Tahmin!' : 'Oyun Bitti!',
                    style: GoogleFonts.outfit(
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isWon ? 'Kelimeyi başarıyla buldun!' : 'Doğru kelime:',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: subtextColor,
                    ),
                  ),
                  if (!isWon)
                    Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text(
                        viewModel.targetWord,
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: wordColor,
                          letterSpacing: 2,
                        ),
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
                      initiallyExpanded: true,
                    ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: viewModel.resetGame,
                      icon: const Icon(Icons.replay_rounded),
                      label: Text(
                        isWon ? 'Sonraki Kelime' : 'Yeniden Oyna',
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

class HangmanKeyboardWidget extends StatelessWidget {
  final HangmanViewModel viewModel;
  final Color textColor;
  final bool isDesktop;

  const HangmanKeyboardWidget({
    super.key,
    required this.viewModel,
    required this.textColor,
    this.isDesktop = false,
  });

  static const List<List<String>> _rows = [
    ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
    ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'],
    ['Z', 'X', 'C', 'V', 'B', 'N', 'M'],
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 16 : 6,
        vertical: isDesktop ? 14 : 10,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161622) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF28283E) : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _rows.map((row) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: row.map((letter) {
                final isGuessed = viewModel.guessedLetters.contains(letter);
                final isCorrect =
                    isGuessed && viewModel.targetWord.contains(letter);
                final isWrong =
                    isGuessed && !viewModel.targetWord.contains(letter);

                Color btnColor = isDark
                    ? const Color(0xFF232336)
                    : const Color(0xFFF1F5F9);
                Color lipColor = isDark
                    ? const Color(0xFF12121D)
                    : const Color(0xFFCBD5E1);
                Color txtColor = textColor;

                if (isCorrect) {
                  btnColor = const Color(0xFF10B981);
                  lipColor = const Color(0xFF047857);
                  txtColor = Colors.white;
                } else if (isWrong) {
                  btnColor = isDark
                      ? const Color(0xFF1A1A26)
                      : const Color(0xFFE2E8F0);
                  lipColor = Colors.transparent;
                  txtColor = textColor.withValues(alpha: 0.3);
                }

                return Flexible(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isDesktop ? 62 : 42,
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 4 : 2.5,
                      ),
                      child: GestureDetector(
                        onTap: (isGuessed ||
                                viewModel.gameState != GameState.playing)
                            ? null
                            : () => viewModel.guessLetter(letter),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          height: isDesktop ? 50 : 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: btnColor,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: isWrong
                                ? null
                                : [
                                    BoxShadow(
                                      color: lipColor,
                                      offset: const Offset(0, 3),
                                      blurRadius: 0,
                                    ),
                                  ],
                          ),
                          child: Text(
                            letter,
                            style: GoogleFonts.outfit(
                              fontSize: isDesktop ? 18 : 15,
                              fontWeight: FontWeight.w800,
                              color: txtColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class HangmanPainter extends CustomPainter {
  final int wrongGuesses;
  final Color color;

  HangmanPainter({required this.wrongGuesses, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(size.width * 0.1, size.height * 0.9),
      Offset(size.width * 0.9, size.height * 0.9),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.3, size.height * 0.9),
      Offset(size.width * 0.3, size.height * 0.1),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.3, size.height * 0.1),
      Offset(size.width * 0.7, size.height * 0.1),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.7, size.height * 0.1),
      Offset(size.width * 0.7, size.height * 0.2),
      paint,
    );

    if (wrongGuesses >= 1) {
      canvas.drawCircle(
        Offset(size.width * 0.7, size.height * 0.3),
        size.height * 0.1,
        paint,
      );
    }
    if (wrongGuesses >= 2) {
      canvas.drawLine(
        Offset(size.width * 0.7, size.height * 0.4),
        Offset(size.width * 0.7, size.height * 0.65),
        paint,
      );
    }
    if (wrongGuesses >= 3) {
      canvas.drawLine(
        Offset(size.width * 0.7, size.height * 0.45),
        Offset(size.width * 0.55, size.height * 0.55),
        paint,
      );
    }
    if (wrongGuesses >= 4) {
      canvas.drawLine(
        Offset(size.width * 0.7, size.height * 0.45),
        Offset(size.width * 0.85, size.height * 0.55),
        paint,
      );
    }
    if (wrongGuesses >= 5) {
      canvas.drawLine(
        Offset(size.width * 0.7, size.height * 0.65),
        Offset(size.width * 0.55, size.height * 0.8),
        paint,
      );
    }
    if (wrongGuesses >= 6) {
      canvas.drawLine(
        Offset(size.width * 0.7, size.height * 0.65),
        Offset(size.width * 0.85, size.height * 0.8),
        paint,
      );

      final xPaint = Paint()
        ..color = const Color(0xFFEF4444)
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(size.width * 0.66, size.height * 0.27),
        Offset(size.width * 0.69, size.height * 0.3),
        xPaint,
      );
      canvas.drawLine(
        Offset(size.width * 0.69, size.height * 0.27),
        Offset(size.width * 0.66, size.height * 0.3),
        xPaint,
      );
      canvas.drawLine(
        Offset(size.width * 0.71, size.height * 0.27),
        Offset(size.width * 0.74, size.height * 0.3),
        xPaint,
      );
      canvas.drawLine(
        Offset(size.width * 0.74, size.height * 0.27),
        Offset(size.width * 0.71, size.height * 0.3),
        xPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant HangmanPainter oldDelegate) {
    return oldDelegate.wrongGuesses != wrongGuesses ||
        oldDelegate.color != color;
  }
}
