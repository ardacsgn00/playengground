import 'package:google_fonts/google_fonts.dart';
import '../widgets/exit_confirmation_dialog.dart';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/audio_service.dart';
import '../services/profanity_filter_service.dart';
import '../services/tts_service.dart';
import '../utils/ui_utils.dart';
import '../widgets/game_tutorial_popup.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../data/wordle_data.dart';
import '../services/level_service.dart';
import '../widgets/level_selection_dialog.dart';
import '../widgets/marquee_title.dart';
import '../services/mistake_service.dart';
import '../services/score_service.dart';
import '../models/game_review_item.dart';
import '../widgets/game_review_accordion.dart';

// --- Vocabulary Massively Expanded ---
const Map<String, String> _wordleDictionary = wordleDictionary;

enum LetterState { initial, absent, present, correct }

enum GameState { playing, won, lost }

class LetterInfo {
  String letter;
  LetterState state;
  LetterInfo({this.letter = '', this.state = LetterState.initial});
}

class WordleViewModel extends ChangeNotifier {
  List<List<LetterInfo>> board = [];
  Map<String, LetterState> keyboardState = {};

  int currentRow = 0;
  int currentCol = 0;
  late String targetWord;
  GameState gameState = GameState.playing;
  bool isProcessing = false;
  bool isValidating = false;
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

  GameDifficulty difficulty = LevelService.instance.currentDifficulty;

  WordleViewModel() {
    _startNewGame();
  }

  void updateDifficulty(GameDifficulty newDiff) {
    difficulty = newDiff;
    LevelService.instance.setDifficulty(newDiff);
    _startNewGame();
  }

  void _startNewGame() {
    board = List.generate(6, (_) => List.generate(5, (_) => LetterInfo()));
    keyboardState.clear();
    currentRow = 0;
    currentCol = 0;
    gameState = GameState.playing;
    isProcessing = false;
    isValidating = false;

    // Hint Values
    hintsRemaining = 3;
    isHintLoading = false;
    currentHint = null;
    isNewHighScore = false;
    sessionReviewItems = [];
    highScore = ScoreService.instance.getHighScore('wordle');

    final filtered =
        LevelService.instance.filterDictionary(_wordleDictionary, difficulty);
    final allKeys = filtered.keys.toList();
    targetWord = allKeys[Random().nextInt(allKeys.length)];
    notifyListeners();
  }

  void resetGame() {
    if (gameState == GameState.lost) {
      score = 0;
      winStreak = 0;
    }
    _startNewGame();
  }

  // --- HINT LOGIC ---
  int hintsRemaining = 3;
  bool isHintLoading = false;
  String? currentHint;

  void fetchGeminiHint() async {
    if (hintsRemaining <= 0 ||
        isHintLoading ||
        gameState != GameState.playing) {
      return;
    }

    isHintLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 1));
    if (_isDisposed) return;

    String fullHint =
        _wordleDictionary[targetWord] ?? 'A common 5-letter English word.';

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
      currentHint = "$englishHint\n\n💡 İlk Harf: ${targetWord[0]}";
    } else if (hintsRemaining == 1) {
      currentHint =
          "$englishHint\n\n💡 İlk Harf: ${targetWord[0]}\n🇹🇷 Türkçe: $turkishHint";
    }

    hintsRemaining--;
    isHintLoading = false;
    notifyListeners();
  }

  void enterLetter(String letter) {
    if (gameState != GameState.playing || isProcessing) return;
    if (currentCol < 5) {
      board[currentRow][currentCol].letter = letter;
      currentCol++;
      notifyListeners();
    }
  }

  void deleteLetter() {
    if (gameState != GameState.playing || isProcessing) return;
    if (currentCol > 0) {
      currentCol--;
      board[currentRow][currentCol].letter = '';
      notifyListeners();
    }
  }

  void submitRow(BuildContext context) async {
    if (gameState != GameState.playing || isProcessing || isValidating) return;

    if (currentCol < 5) {
      ScaffoldMessenger.of(context).clearSnackBars();
      UIUtils.showPremiumSnackBar(
        context,
        'Not enough letters',
        backgroundColor: Colors.redAccent,
        icon: Icons.warning_amber,
        duration: const Duration(seconds: 1),
      );
      // Yanlış giriş sesi
      AudioService.playIncorrect();
      return;
    }

    String guess = board[currentRow]
        .map((e) => e.letter)
        .join('')
        .toLowerCase();

    // 1. Profanity Validation
    if (ProfanityFilterService.containsProfanity(guess)) {
      AudioService.playIncorrect();
      if (context.mounted) {
        UIUtils.showPremiumSnackBar(
          context,
          'Word not allowed',
          backgroundColor: Colors.redAccent,
          icon: Icons.block,
          duration: const Duration(seconds: 1),
        );
      }
      return;
    }

    // 2. Real Word Validation
    isValidating = true;
    notifyListeners();

    bool isReal = await _isRealEnglishWord(guess);

    if (_isDisposed) return;
    isValidating = false;

    if (!isReal) {
      AudioService.playIncorrect();
      if (context.mounted) {
        UIUtils.showPremiumSnackBar(
          context,
          'Not in word list',
          backgroundColor: Colors.orange,
          icon: Icons.error_outline,
          duration: const Duration(seconds: 1),
        );
      }
      notifyListeners();
      return;
    }

    // Doğrulama ok, şimdi harf sayısına bakıyoruz (targetWord uppercase olduğu için guess de upper yapalım)
    guess = guess.toUpperCase();
    isProcessing = true;
    notifyListeners();

    List<LetterState> rowStates = List.filled(5, LetterState.absent);
    List<bool> targetUsed = List.filled(5, false);
    List<bool> guessUsed = List.filled(5, false);

    // İlk adım: Yeşil olanları (Correct) bul
    for (int i = 0; i < 5; i++) {
      if (guess[i] == targetWord[i]) {
        rowStates[i] = LetterState.correct;
        targetUsed[i] = true;
        guessUsed[i] = true;
      }
    }

    // İkinci adım: Sarı olanları (Present) bul (Fazla sarı vermemek için detaylı tarama)
    for (int i = 0; i < 5; i++) {
      if (!guessUsed[i]) {
        for (int j = 0; j < 5; j++) {
          if (!targetUsed[j] && guess[i] == targetWord[j]) {
            rowStates[i] = LetterState.present;
            targetUsed[j] = true;
            break;
          }
        }
      }
    }

    // Harfleri yarım saniyelik Wordle animasyon gecikmesiyle ekranda renklendir
    for (int i = 0; i < 5; i++) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (_isDisposed) return;
      board[currentRow][i].state = rowStates[i];

      final currentKeyStatus = keyboardState[guess[i]] ?? LetterState.initial;
      if (rowStates[i] == LetterState.correct) {
        keyboardState[guess[i]] = LetterState.correct;
      } else if (rowStates[i] == LetterState.present &&
          currentKeyStatus != LetterState.correct) {
        keyboardState[guess[i]] = LetterState.present;
      } else if (rowStates[i] == LetterState.absent &&
          currentKeyStatus == LetterState.initial) {
        keyboardState[guess[i]] = LetterState.absent;
      }
      notifyListeners();
    }

    // Satır bitti, durumu kontrol et
    if (guess == targetWord) {
      gameState = GameState.won;
      AudioService.playSuccess(); // Mükemmel Başarı sesi
      TtsService.instance.speak(targetWord);

      String rawHint = _wordleDictionary[targetWord] ?? '';
      String meaning = rawHint;
      if (rawHint.contains('(') && rawHint.contains(')')) {
        int start = rawHint.indexOf('(');
        int end = rawHint.lastIndexOf(')');
        meaning = rawHint.substring(start + 1, end).trim();
      }
      if (meaning.isEmpty) meaning = rawHint;
      if (meaning.isEmpty) meaning = '5 Harfli Kelime';

      winStreak++;
      score += (6 - currentRow) * 25 + 50;
      sessionReviewItems = [
        GameReviewItem(
          word: targetWord,
          meaning: meaning,
          question: 'Wordle (5 Harf)',
          userAnswer: guess,
          correctAnswer: targetWord,
          isCorrect: true,
          note: '${currentRow + 1}. denemede bildin!',
        ),
      ];
      ScoreService.instance.recordScore(gameId: 'wordle', score: score, streak: winStreak).then((res) {
        highScore = res.highScore;
        isNewHighScore = res.isNewHighScore;
        notifyListeners();
      });
    } else if (currentRow == 5) {
      gameState = GameState.lost;
      AudioService.playFailure();

      String rawHint = _wordleDictionary[targetWord] ?? '';
      String meaning = rawHint;
      if (rawHint.contains('(') && rawHint.contains(')')) {
        int start = rawHint.indexOf('(');
        int end = rawHint.lastIndexOf(')');
        meaning = rawHint.substring(start + 1, end).trim();
      }
      if (meaning.isEmpty) meaning = rawHint;
      if (meaning.isEmpty) meaning = '5 Harfli Kelime';

      sessionReviewItems = [
        GameReviewItem(
          word: targetWord,
          meaning: meaning,
          question: 'Wordle (5 Harf)',
          userAnswer: guess,
          correctAnswer: targetWord,
          isCorrect: false,
          note: '6 denemede bulunamadı',
        ),
      ];
      ScoreService.instance.recordScore(gameId: 'wordle', score: score, streak: winStreak).then((res) {
        highScore = res.highScore;
        isNewHighScore = res.isNewHighScore;
        notifyListeners();
      });

      MistakeService.instance.recordMistake(
        word: targetWord,
        meaning: meaning,
        sourceGame: 'Wordle',
        wrongAnswer: guess,
      );
    } else {
      currentRow++;
      currentCol = 0;
    }

    isProcessing = false;
    notifyListeners();
  }

  Future<bool> _isRealEnglishWord(String word) async {
    final cleanWord = word.trim().toUpperCase();

    // 1. Check local dictionary (Fast Path)
    if (_wordleDictionary.containsKey(cleanWord)) return true;

    // 2. Check strict Dictionary API
    try {
      final response = await http
          .get(
            Uri.parse(
              'https://api.dictionaryapi.dev/api/v2/entries/en/${cleanWord.toLowerCase()}',
            ),
          )
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.isNotEmpty;
      }

      // If Dictionary API fails/404s, we can try Datamuse as fallback but with stricter check
      // However, for "AEIOU" prevention, 404 is exactly what we want.
      if (response.statusCode == 404) return false;

      // Fallback to Datamuse if API is down, but with a stricter check
      final dmResponse = await http
          .get(
            Uri.parse(
              'https://api.datamuse.com/words?sp=${cleanWord.toLowerCase()}&md=d&max=1',
            ),
          )
          .timeout(const Duration(seconds: 2));

      if (dmResponse.statusCode == 200) {
        final List dmData = jsonDecode(dmResponse.body);
        if (dmData.isNotEmpty) {
          final firstMatch = dmData[0];
          // Stricter: must match exactly and have a definition (defs)
          return firstMatch['word'].toString().toLowerCase() ==
                  cleanWord.toLowerCase() &&
              (firstMatch['defs'] != null &&
                  (firstMatch['defs'] as List).isNotEmpty);
        }
      }
    } catch (_) {}
    return false;
  }
}

// ----------------------------------------------------------------------
// UI
// ----------------------------------------------------------------------

class WordleScreen extends StatelessWidget {
  const WordleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => WordleViewModel(),
      child: const _WordleView(),
    );
  }
}

class _WordleView extends StatefulWidget {
  const _WordleView();

  @override
  State<_WordleView> createState() => _WordleViewState();
}

class _WordleViewState extends State<_WordleView> {
  late final FocusNode _focusNode;
  bool _xpAwarded = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final vm = context.read<WordleViewModel>();
      final result = await GameTutorialPopup.show(
        context,
        tutorialKey: 'wordle_tutorial',
        title: "Word Guess",
        icon: FontAwesomeIcons.tableCells,
        color: const Color(0xFF538D4E),
        tutorialTextTr:
            'Word Guess oyununda 5 harfli gizli İngilizce kelimeyi 6 denemede bulun!\n\n'
            '• Sanal klavyeden veya bilgisayar klavyenizden harfleri yazın ve Enter tuşuna basarak kelimenizi onaylayın.\n'
            '• Her tahminin ardından kutuların renkleri size ipucu verir:\n'
            '  🟩 Yeşil: Harf kelimede var ve yeri TAMAMEN doğru.\n'
            '  🟨 Sarı: Harf kelimede yer alıyor fakat YANLIŞ kutuda.\n'
            '  ⬛ Gri: Harf gizli kelimede HİÇ bulunmuyor.\n'
            '• Renk ipuçlarını takip ederek 6 deneme hakkınız dolmadan kelimeyi çözün!',
        tutorialTextEn: "Try to guess the hidden 5-letter English word in 6 attempts! After each guess, letters will be colored: Green = correct position, Yellow = in the word but wrong position, Gray = not in the word.",
        includeLevelSelection: true,
        initialDifficulty: vm.difficulty,
      );
      if (mounted && result.difficulty != null) {
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
    final viewModel = context.read<WordleViewModel>();
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.enter) {
      viewModel.submitRow(context);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete) {
      viewModel.deleteLetter();
      return KeyEventResult.handled;
    }
    // A-Z keys
    final label = event.logicalKey.keyLabel;
    if (label.length == 1 && RegExp(r'^[a-zA-Z]$').hasMatch(label)) {
      viewModel.enterLetter(label.toUpperCase());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<WordleViewModel>();

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
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(
              title: const MarqueeTitle(
                title: 'Word Guess',
                leadingIcon: Icon(FontAwesomeIcons.tableCells, color: Color(0xFF10B981), size: 18),
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              centerTitle: false,
              actions: [
                LevelBadgeButton(
                  difficulty: viewModel.difficulty,
                  onTap: () async {
                    final chosen = await LevelSelectionDialog.show(
                      context,
                      initialDifficulty: viewModel.difficulty,
                      accentColor: const Color(0xFF538D4E),
                      title: 'Word Guess: Seviye Değiştir',
                    );
                    if (chosen != null && mounted) {
                      viewModel.updateDifficulty(chosen);
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: viewModel.resetGame,
                  tooltip: 'Restart Game',
                ),
              ],
            ),
            body: Stack(
              children: [
                SafeArea(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Column(
                        children: [
                          // Top Scrollable Section: Grid and Hints
                          Expanded(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Column(
                                children: [
                                  const SizedBox(height: 20),
                                  // Grid
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      // Genişliğe göre en iyi 5x6 uyumu
                                      final itemWidth = min(
                                        (constraints.maxWidth - 40) / 5,
                                        65.0,
                                      );
                                      return Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: List.generate(6, (rIndex) {
                                          return Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: List.generate(5, (
                                              cIndex,
                                            ) {
                                              final info = viewModel
                                                  .board[rIndex][cIndex];
                                              return Container(
                                                width: itemWidth,
                                                height: itemWidth,
                                                margin: const EdgeInsets.all(4),
                                                child: _TileWidget(
                                                  info: info,
                                                  isCurrentRow:
                                                      rIndex ==
                                                      viewModel.currentRow,
                                                ),
                                              );
                                            }),
                                          );
                                        }),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 20),
                                  if (viewModel.currentHint != null)
                                    _buildHintView(context, viewModel),
                                  if (viewModel.hintsRemaining > 0 &&
                                      viewModel.gameState == GameState.playing)
                                    _buildHintButton(context, viewModel),
                                  const SizedBox(height: 20),
                                ],
                              ),
                            ),
                          ),

                          // Fixed Bottom Section: Keyboard
                          _buildKeyboard(context, viewModel),
                        ],
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

  Widget _buildHintView(BuildContext context, WordleViewModel viewModel) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 4.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[800] : Colors.blue[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
        ),
        child: Text(
          viewModel.currentHint!,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.normal,
            color: isDark ? Colors.white : Colors.blue[900],
          ),
        ),
      ),
    );
  }

  Widget _buildHintButton(BuildContext context, WordleViewModel viewModel) {
    return ElevatedButton.icon(
      onPressed: viewModel.isHintLoading ? null : viewModel.fetchGeminiHint,
      icon: viewModel.isHintLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.psychology),
      label: Text(
        viewModel.hintsRemaining == 3
            ? 'Get a Hint (3)'
            : (viewModel.hintsRemaining == 2
                  ? 'Need an easier hint? (2)'
                  : 'Show Turkish translation (1)'),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF538D4E),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    );
  }

  Widget _buildKeyboard(BuildContext context, WordleViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _buildKeyboardRow(
            ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
            context,
            viewModel,
          ),
          _buildKeyboardRow(
            ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'],
            context,
            viewModel,
          ),
          _buildKeyboardRow(
            ['ENTER', 'Z', 'X', 'C', 'V', 'B', 'N', 'M', 'DEL'],
            context,
            viewModel,
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildKeyboardRow(
    List<String> keys,
    BuildContext context,
    WordleViewModel viewModel,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: keys.map((k) {
        // Compute key color
        final state = viewModel.keyboardState[k] ?? LetterState.initial;

        final isDark = Theme.of(context).brightness == Brightness.dark;
        Color bgColor;
        Color lipColor;
        Color fgColor = Colors.white;

        if (state == LetterState.correct) {
          bgColor = const Color(0xFF538D4E);
          lipColor = const Color(0xFF3A6337);
        } else if (state == LetterState.present) {
          bgColor = const Color(0xFFB59F3B);
          lipColor = const Color(0xFF827229);
        } else if (state == LetterState.absent) {
          bgColor = const Color(0xFF3A3A3C);
          lipColor = const Color(0xFF1F1F21);
          fgColor = Colors.white54;
        } else {
          bgColor = isDark ? const Color(0xFF2D2D3F) : const Color(0xFFE2E8F0);
          lipColor = isDark ? const Color(0xFF161622) : const Color(0xFF94A3B8);
          fgColor = isDark ? Colors.white : Colors.black87;
        }

        final isActionKey = k == 'ENTER' || k == 'DEL';

        if (k == 'ENTER') {
          bgColor = const Color(0xFF538D4E); // Green
          lipColor = const Color(0xFF3A6337);
          fgColor = Colors.white;
        } else if (k == 'DEL') {
          bgColor = const Color(0xFFEF4444); // Red
          lipColor = const Color(0xFFB91C1C);
          fgColor = Colors.white;
        }

        return Expanded(
          flex: isActionKey ? 3 : 2,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 3.5),
            child: Container(
              padding: const EdgeInsets.only(bottom: 3.5),
              decoration: BoxDecoration(
                color: lipColor,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Material(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: () {
                    if (k == 'ENTER') {
                      viewModel.submitRow(context);
                    } else if (k == 'DEL') {
                      viewModel.deleteLetter();
                    } else {
                      viewModel.enterLetter(k);
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    child: k == 'DEL'
                        ? Icon(Icons.backspace_outlined, size: 20, color: fgColor)
                        : Text(
                            (k == 'ENTER' && viewModel.isValidating) ? '...' : k,
                            style: TextStyle(
                              fontSize: isActionKey ? 13 : 16,
                              fontWeight: FontWeight.bold,
                              color: fgColor,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGameOverPopUp(BuildContext context, WordleViewModel viewModel) {
    final bool isWon = viewModel.gameState == GameState.won;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Award XP on win (only once per game)
    if (isWon && !_xpAwarded) {
      _xpAwarded = true;
    }

    final popupBgColor = isDark
        ? Theme.of(context).colorScheme.surface
        : Colors.white;
    final titleColor = isWon
        ? (isDark ? Colors.greenAccent : Colors.green[700])
        : (isDark ? Colors.redAccent : Colors.red[700]);
    final subtextColor = isDark ? Colors.grey[400] : Colors.black54;
    final wordColor = isDark ? Colors.white : Colors.black87;
    final backBtnColor = isDark ? Colors.grey[300] : Colors.grey[700];

    return Container(
      color: Colors.black.withValues(alpha: 0.4),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.8, end: 1.0),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) {
              return Transform.scale(scale: scale, child: child);
            },
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
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (viewModel.isNewHighScore)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.emoji_events, color: Colors.black87, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'YENİ EN YÜKSEK SKOR!',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                  fontSize: 13,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isWon
                              ? Colors.green.withValues(alpha: 0.1)
                              : Colors.red.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isWon
                              ? Icons.emoji_events
                              : Icons.sentiment_very_dissatisfied,
                          size: 56,
                          color: isWon ? Colors.green : Colors.red,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isWon ? 'Genius!' : 'Game Over!',
                        style: TextStyle(
                          fontFamily: GoogleFonts.outfit().fontFamily,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isWon
                            ? 'You guessed the word completely!'
                            : 'The target word was:',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: GoogleFonts.outfit().fontFamily,
                          fontSize: 14,
                          color: subtextColor,
                        ),
                      ),
                      if (!isWon)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            viewModel.targetWord,
                            style: TextStyle(
                              fontFamily: GoogleFonts.outfit().fontFamily,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: wordColor,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.stars, color: Colors.amber, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'SCORE: ${viewModel.score}',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(width: 14),
                            const Icon(Icons.military_tech, color: Colors.orange, size: 18),
                            const SizedBox(width: 4),
                            Text(
                              'BEST: ${viewModel.highScore}',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      if (viewModel.sessionReviewItems.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        GameReviewAccordion(
                          items: viewModel.sessionReviewItems,
                          accentColor: isWon ? const Color(0xFF538D4E) : Colors.red,
                          initiallyExpanded: true,
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: viewModel.resetGame,
                          icon: const Icon(Icons.replay),
                          label: Text(
                            'Yeniden Oyna',
                            style: TextStyle(
                              fontFamily: GoogleFonts.outfit().fontFamily,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isWon ? Colors.green : Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back),
                          label: Text(
                            'Ana Menü',
                            style: TextStyle(
                              fontFamily: GoogleFonts.outfit().fontFamily,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
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
        ),
      ),
    );
  }
}

class _TileWidget extends StatelessWidget {
  final LetterInfo info;
  final bool isCurrentRow;

  const _TileWidget({required this.info, required this.isCurrentRow});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bgColor;
    Color fgColor = Colors.white;
    Color borderColor = isDark ? Colors.grey[700]! : Colors.grey[300]!;

    if (info.state == LetterState.correct) {
      bgColor = const Color(0xFF538D4E);
      borderColor = bgColor;
    } else if (info.state == LetterState.present) {
      bgColor = const Color(0xFFB59F3B);
      borderColor = bgColor;
    } else if (info.state == LetterState.absent) {
      bgColor = const Color(0xFF3A3A3C);
      borderColor = bgColor;
    } else {
      bgColor = Colors.transparent;
      fgColor = isDark ? Colors.white : Colors.black87;
      if (info.letter.isNotEmpty) {
        borderColor = isDark ? Colors.grey[500]! : Colors.grey[600]!;
      }
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        // Simple subtle scale bump for input, 3D flip for evaluation
        if (info.state == LetterState.initial && info.letter.isNotEmpty) {
          return ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            ),
            child: child,
          );
        } else if (info.state != LetterState.initial) {
          final rotateAnim = Tween(begin: pi / 2, end: 0.0).animate(animation);
          return AnimatedBuilder(
            animation: rotateAnim,
            child: child,
            builder: (context, widget) {
              return Transform(
                transform: Matrix4.rotationX(rotateAnim.value),
                alignment: Alignment.center,
                child: widget,
              );
            },
          );
        }
        return child;
      },
      child: Container(
        key: ValueKey('${info.state}_${info.letter}'),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor, width: 2),
        ),
        alignment: Alignment.center,
        child: Text(
          info.letter,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: fgColor,
          ),
        ),
      ),
    );
  }
}
