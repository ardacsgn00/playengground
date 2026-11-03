import 'dart:math';
import 'package:flutter/material.dart';
import '../data/word_hunt_data.dart';
import '../services/audio_service.dart';
import '../services/tts_service.dart';
import '../widgets/exit_confirmation_dialog.dart';
import '../widgets/game_tutorial_popup.dart';
import '../widgets/category_selection_dialog.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/level_service.dart';
import '../widgets/level_selection_dialog.dart';
import '../widgets/marquee_title.dart';
import '../data/hangman_data.dart';
import '../services/score_service.dart';
import '../models/game_review_item.dart';
import '../widgets/game_review_accordion.dart';

class WordHuntScreen extends StatefulWidget {
  const WordHuntScreen({super.key});

  @override
  State<WordHuntScreen> createState() => _WordHuntScreenState();
}

class _WordHuntScreenState extends State<WordHuntScreen> {
  // Grid settings
  static const int gridRows = 10;
  static const int gridCols = 10;
  
  late List<List<String>> _grid;
  late String _currentCategory;
  String _selectedFilterCategory = 'All';
  GameDifficulty _difficulty = LevelService.instance.currentDifficulty;
  late List<String> _wordsToFind;
  late Set<String> _foundWords;
  
  // Interaction state
  Offset? _startTouch;
  Offset? _currentTouch;
  List<Point<int>>? _selectedCells;
  
  // Highlighting found words
  final List<FoundWordPath> _paths = [];
  
  int _score = 0;
  int _highScore = 0;
  bool _isNewHighScore = false;
  List<GameReviewItem> _sessionReviewItems = [];
  bool _isGameOver = false;
  final Random _random = Random();

  void _updateDifficulty(GameDifficulty newDiff) {
    setState(() {
      _difficulty = newDiff;
      LevelService.instance.setDifficulty(newDiff);
      _startNewGame();
    });
  }

  @override
  void initState() {
    super.initState();
    _highScore = ScoreService.instance.getHighScore('word_hunt');
    // Initialize late variables with safe defaults to prevent
    // LateInitializationError when build() runs during the tutorial dialog.
    _foundWords = {};
    _grid = List.generate(gridRows, (_) => List.generate(gridCols, (_) => ''));
    _wordsToFind = [];
    _currentCategory = '';

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final result = await GameTutorialPopup.show(
        context,
        tutorialKey: 'word_hunt_tutorial',
        title: "Word Hunt",
        icon: FontAwesomeIcons.searchengin,
        color: const Color(0xFF06B6D4),
        tutorialTextTr:
            'Word Hunt oyununda harf tablosundaki gizli kelimeleri keşfedin!\n\n'
            '• Listede verilen kategoriye ait İngilizce kelimeleri harf ızgarasında arayın.\n'
            '• Kelimeler yatay, dikey veya çapraz yönlerde gizlenmiş olabilir.\n'
            '• Bulduğunuz kelimenin ilk harfinden son harfine doğru parmağınızı veya farenizi sürükleyerek işaretleyin.\n'
            '• Listedeki tüm kelimeleri bularak seviyeyi tamamlayın!',
        tutorialTextEn: "In Word Hunt, find the hidden words from the category in the letter grid by dragging your finger or mouse!",
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
        _startNewGame();
      }
    });
  }

  @override
  void dispose() {
    TtsService.instance.stop();
    super.dispose();
  }

  Future<void> _showCategoryPickerAndStart({bool canDismiss = true}) async {
    final chosen = await CategorySelectionDialog.show(
      context,
      title: 'Word Hunt: Kategori Seçin',
      subtitle: 'Harf tablosunda aramak istediğiniz konuyu belirleyin',
      accentColor: const Color(0xFF06B6D4),
      headerIcon: FontAwesomeIcons.binoculars,
      categories: getWordHuntCategoryOptions(),
      initialSelectedId: _selectedFilterCategory,
      canDismiss: canDismiss,
    );
    if (!mounted) return;
    if (chosen != null) {
      _selectedFilterCategory = chosen;
      _startNewGame();
    } else if (_currentCategory.isEmpty) {
      _startNewGame();
    }
  }

  void _startNewGame() {
    setState(() {
      _foundWords = {};
      _paths.clear();
      _score = 0;
      _isGameOver = false;
      _isNewHighScore = false;
      _sessionReviewItems.clear();
      _highScore = ScoreService.instance.getHighScore('word_hunt');
      
      final categories = wordHuntCategories.keys.toList();
      if (_selectedFilterCategory == 'All' || !wordHuntCategories.containsKey(_selectedFilterCategory)) {
        _currentCategory = categories[_random.nextInt(categories.length)];
      } else {
        _currentCategory = _selectedFilterCategory;
      }
      
      // Select 6-8 words from categories filtered by difficulty
      List<String> rawWords = List.from(wordHuntCategories[_currentCategory]!);
      List<String> allWords = LevelService.instance.filterWordList(rawWords, _difficulty);
      allWords.shuffle();
      _wordsToFind = allWords.take(min(8, allWords.length)).map((w) => w.toUpperCase()).toList();
      
      _generateGrid();
    });
  }

  void _generateGrid() {
    // Initialize empty grid
    _grid = List.generate(gridRows, (_) => List.generate(gridCols, (_) => ''));

    List<String> placedWords = [];
    
    // Try to place each word
    for (String word in _wordsToFind) {
      bool placed = false;
      int attempts = 0;
      
      while (!placed && attempts < 500) { // Increased attempts for better reliability
        attempts++;
        int row = _random.nextInt(gridRows);
        int col = _random.nextInt(gridCols);
        
        // Random direction: 0: horizontal, 1: vertical, 2: diagonal
        int dir = _random.nextInt(3);
        int dRow = 0, dCol = 0;
        
        if (dir == 0) {
          dCol = 1;
        } else if (dir == 1) {
          dRow = 1;
        } else { 
          dRow = 1; dCol = 1; 
        }

        if (_canPlaceWord(word, row, col, dRow, dCol)) {
          _placeWord(word, row, col, dRow, dCol);
          placed = true;
          placedWords.add(word);
        }
      }
    }
    
    // CRITICAL: Only keep words that were actually placed in the grid
    _wordsToFind = placedWords;

    // Fill remaining cells with random letters
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    for (int r = 0; r < gridRows; r++) {
      for (int c = 0; c < gridCols; c++) {
        if (_grid[r][c] == '') {
          _grid[r][c] = alphabet[_random.nextInt(alphabet.length)];
        }
      }
    }
  }

  bool _canPlaceWord(String word, int r, int c, int dr, int dc) {
    if (r + dr * word.length > gridRows || c + dc * word.length > gridCols || r + dr * word.length < 0 || c + dc * word.length < 0) {
      return false;
    }
    for (int i = 0; i < word.length; i++) {
      String cell = _grid[r + i * dr][c + i * dc];
      if (cell != '' && cell != word[i]) return false;
    }
    return true;
  }

  void _placeWord(String word, int r, int c, int dr, int dc) {
    for (int i = 0; i < word.length; i++) {
      _grid[r + i * dr][c + i * dc] = word[i];
    }
  }

  void _onPanStart(DragStartDetails details, double cellSize) {
    if (_isGameOver) return;
    setState(() {
      _startTouch = details.localPosition;
      _currentTouch = details.localPosition;
      _updateSelectedCells(cellSize);
    });
  }

  void _onPanUpdate(DragUpdateDetails details, double cellSize) {
    if (_isGameOver) return;
    setState(() {
      _currentTouch = details.localPosition;
      _updateSelectedCells(cellSize);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isGameOver || _selectedCells == null || _selectedCells!.isEmpty) return;

    String selectedWord = _selectedCells!.map((p) => _grid[p.y][p.x]).join('');
    String reversedWord = selectedWord.split('').reversed.join('');

    if (_wordsToFind.contains(selectedWord) && !_foundWords.contains(selectedWord)) {
      _handleWordFound(selectedWord);
    } else if (_wordsToFind.contains(reversedWord) && !_foundWords.contains(reversedWord)) {
      _handleWordFound(reversedWord);
    } else {
      // If none of the words match, play incorrect sound
      AudioService.playIncorrect();
    }

    setState(() {
      _startTouch = null;
      _currentTouch = null;
      _selectedCells = null;
    });
  }

  String _lookupMeaning(String word) {
    final raw = hangmanDictionary[word.toUpperCase()] ?? hangmanDictionary[word.toLowerCase()] ?? '';
    if (raw.contains('(') && raw.contains(')')) {
      final start = raw.indexOf('(');
      final end = raw.lastIndexOf(')');
      final tr = raw.substring(start + 1, end).trim();
      if (tr.isNotEmpty) return tr;
    }
    if (raw.isNotEmpty) return raw;
    final catTr = wordHuntCategoryTr[_currentCategory] ?? _currentCategory;
    return '$catTr kategorisinde bir kelime';
  }

  void _handleWordFound(String word) {
    AudioService.playCorrect();
    TtsService.instance.speak(word);
    setState(() {
      _foundWords.add(word);
      _score += word.length * 10;
      
      // Add persistent path for coloring
      _paths.add(FoundWordPath(
        cells: List.from(_selectedCells!),
        color: _getNextPathColor(),
      ));

      if (_foundWords.length == _wordsToFind.length) {
        _isGameOver = true;
        AudioService.playSuccess();
        
        _sessionReviewItems = _wordsToFind.map((w) {
          final found = _foundWords.contains(w);
          return GameReviewItem(
            word: w,
            meaning: _lookupMeaning(w),
            question: 'Kategori: ${wordHuntCategoryTr[_currentCategory] ?? _currentCategory}',
            userAnswer: found ? 'Bulundu' : 'Bulunamadı',
            correctAnswer: w,
            isCorrect: found,
          );
        }).toList();

        ScoreService.instance.recordScore(gameId: 'word_hunt', score: _score).then((res) {
          if (mounted) {
            setState(() {
              _highScore = res.highScore;
              _isNewHighScore = res.isNewHighScore;
            });
            _showVictoryDialog();
          }
        });
      }
    });
  }

  Color _getNextPathColor() {
    final colors = [
      Colors.blue.withValues(alpha: 0.4),
      Colors.green.withValues(alpha: 0.4),
      Colors.orange.withValues(alpha: 0.4),
      Colors.purple.withValues(alpha: 0.4),
      Colors.pink.withValues(alpha: 0.4),
      Colors.teal.withValues(alpha: 0.4),
      Colors.amber.withValues(alpha: 0.4),
    ];
    return colors[_paths.length % colors.length];
  }

  void _updateSelectedCells(double cellSize) {
    if (_startTouch == null || _currentTouch == null) return;

    int startCol = (_startTouch!.dx / cellSize).floor();
    int startRow = (_startTouch!.dy / cellSize).floor();
    int currentCol = (_currentTouch!.dx / cellSize).floor();
    int currentRow = (_currentTouch!.dy / cellSize).floor();

    // Limit to grid bounds
    startCol = startCol.clamp(0, gridCols - 1);
    startRow = startRow.clamp(0, gridRows - 1);
    currentCol = currentCol.clamp(0, gridCols - 1);
    currentRow = currentRow.clamp(0, gridRows - 1);

    int dCol = currentCol - startCol;
    int dRow = currentRow - startRow;

    // Detect direction
    int absDCol = dCol.abs();
    int absDRow = dRow.abs();

    List<Point<int>> cells = [];

    if (absDRow < 2 && absDCol >= 1) {
      // Horizontal
      int step = dCol > 0 ? 1 : -1;
      for (int i = 0; i <= absDCol; i++) {
        cells.add(Point(startCol + i * step, startRow));
      }
    } else if (absDCol < 2 && absDRow >= 1) {
      // Vertical
      int step = dRow > 0 ? 1 : -1;
      for (int i = 0; i <= absDRow; i++) {
        cells.add(Point(startCol, startRow + i * step));
      }
    } else if (absDCol == absDRow && absDCol >= 1) {
      // Diagonal
      int stepCol = dCol > 0 ? 1 : -1;
      int stepRow = dRow > 0 ? 1 : -1;
      for (int i = 0; i <= absDCol; i++) {
        cells.add(Point(startCol + i * stepCol, startRow + i * stepRow));
      }
    } else {
      cells.add(Point(startCol, startRow));
    }

    _selectedCells = cells;
  }

  void _showVictoryDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final popupBgColor = isDark
            ? Theme.of(ctx).colorScheme.surface
            : Colors.white;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 440,
              maxHeight: MediaQuery.of(ctx).size.height * 0.85,
            ),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: popupBgColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isNewHighScore)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFB45309), width: 2),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.emoji_events, color: Colors.black87, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'YENİ EN YÜKSEK SKOR!',
                            style: TextStyle(
                              fontFamily: 'Outfit',
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
                      color: const Color(0xFF06B6D4).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.emoji_events_rounded,
                      size: 56,
                      color: Color(0xFF06B6D4),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tebrikler!',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.cyanAccent : const Color(0xFF0891B2),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tüm kelimeleri başarıyla buldun!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 14,
                      color: isDark ? Colors.grey[400] : Colors.black54,
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
                          'SCORE: $_score',
                          style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(width: 14),
                        const Icon(Icons.military_tech, color: Colors.orange, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          'BEST: $_highScore',
                          style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  if (_sessionReviewItems.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    GameReviewAccordion(
                      items: _sessionReviewItems,
                      accentColor: const Color(0xFF06B6D4),
                      initiallyExpanded: true,
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _startNewGame();
                      },
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text(
                        'Sonraki Seviye',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF06B6D4),
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
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.arrow_back),
                      label: const Text(
                        'Ana Menü',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: isDark ? Colors.grey[400] : Colors.grey[700],
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isAmoled = theme.scaffoldBackgroundColor == Colors.black;
    final textColor = isDark ? Colors.white : Colors.black87;
    
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await showExitConfirmationDialog(context);
        if (shouldPop && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const MarqueeTitle(
            title: 'Word Hunt',
            leadingIcon: Icon(FontAwesomeIcons.binoculars, color: Color(0xFF06B6D4), size: 18),
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: false,
          actions: [
            LevelBadgeButton(
              difficulty: _difficulty,
              accentColor: const Color(0xFF06B6D4),
              onTap: () async {
                final chosen = await LevelSelectionDialog.show(
                  context,
                  initialDifficulty: _difficulty,
                  accentColor: const Color(0xFF06B6D4),
                  title: 'Word Hunt: Seviye Değiştir',
                );
                if (chosen != null && mounted) {
                  _updateDifficulty(chosen);
                }
              },
            ),
            IconButton(
              icon: const Icon(FontAwesomeIcons.layerGroup, size: 18),
              tooltip: 'Kategori Seç',
              onPressed: () => _showCategoryPickerAndStart(canDismiss: true),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Yeniden Başlat',
              onPressed: _startNewGame,
            ),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool isDesktop = constraints.maxWidth >= 820;

              if (isDesktop) {
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1080),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, gridConstraints) {
                                final double maxSide = min(
                                  gridConstraints.maxWidth - 16,
                                  gridConstraints.maxHeight - 16,
                                ).clamp(260.0, 620.0);
                                final double cellSize = maxSide / gridCols;
                                return Center(
                                  child: _buildTactileGridBoard(
                                    cellSize: cellSize,
                                    isDark: isDark,
                                    isAmoled: isAmoled,
                                    textColor: textColor,
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 24),
                          SizedBox(
                            width: 340,
                            child: _buildDesktopSidebar(isDark, textColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              // Mobile / Compact Layout
              final bool isLandscape = constraints.maxWidth > constraints.maxHeight;
              final double topOffset = isLandscape ? 54 : 84;
              final double bottomOffset = isLandscape ? 64 : 118;
              const double paddingHorizontal = 12;

              final double availableWidth = (constraints.maxWidth - (paddingHorizontal * 2)).clamp(200.0, 560.0);
              final double availableHeight = (constraints.maxHeight - topOffset - bottomOffset).clamp(200.0, 560.0);

              final double cellSize = min(availableWidth / gridCols, (availableHeight / gridRows).clamp(18.0, 64.0));

              return Column(
                children: [
                  // Mobile Tactile HUD Header
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: paddingHorizontal,
                      vertical: isLandscape ? 6 : 10,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Row(
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: _buildCompactCategoryChip(_currentCategory),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? const Color(0xFF32324A) : const Color(0xFFE2E8F0),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 15),
                                const SizedBox(width: 4),
                                Text(
                                  '${_foundWords.length}/${_wordsToFind.length}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: textColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF06B6D4).withValues(alpha: isDark ? 0.16 : 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF06B6D4), width: 1.5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.stars_rounded, color: Color(0xFFF59E0B), size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  '$_score',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: textColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // The Grid
                  Expanded(
                    child: Center(
                      child: _buildTactileGridBoard(
                        cellSize: cellSize,
                        isDark: isDark,
                        isAmoled: isAmoled,
                        textColor: textColor,
                      ),
                    ),
                  ),

                  // Word List (Mobile)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: isLandscape ? 4 : 10,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: isLandscape ? 6 : 8,
                        alignment: WrapAlignment.center,
                        children: _wordsToFind.map((word) {
                          final bool found = _foundWords.contains(word);
                          return GestureDetector(
                            onTap: found ? () => TtsService.instance.speak(word) : null,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: isLandscape ? 5 : 8,
                              ),
                              decoration: BoxDecoration(
                                color: found
                                    ? const Color(0xFF10B981).withValues(alpha: isDark ? 0.18 : 0.12)
                                    : (isDark ? const Color(0xFF1E1E2E) : Colors.white),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: found
                                      ? const Color(0xFF10B981)
                                      : (isDark ? const Color(0xFF32324A) : const Color(0xFFCBD5E1)),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: found
                                        ? const Color(0xFF047857)
                                        : (isDark ? const Color(0xFF0F0F18) : const Color(0xFFCBD5E1)),
                                    offset: const Offset(0, 2),
                                    blurRadius: 0,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (found) ...[
                                    const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF10B981)),
                                    const SizedBox(width: 5),
                                  ],
                                  Text(
                                    word,
                                    style: TextStyle(
                                      fontSize: isLandscape ? 11 : 13,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.6,
                                      color: found
                                          ? (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857))
                                          : textColor.withValues(alpha: 0.88),
                                      decoration: found ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  if (_isGameOver)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: isLandscape ? 8 : 16,
                        left: 16,
                        right: 16,
                      ),
                      child: _buildGameOverActionButtons(),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTactileGridBoard({
    required double cellSize,
    required bool isDark,
    required bool isAmoled,
    required Color textColor,
  }) {
    final double gridWidth = cellSize * gridCols;
    final double gridHeight = cellSize * gridRows;
    final Set<Point<int>> activeSelectionSet = _selectedCells?.toSet() ?? {};

    return Container(
      width: gridWidth + 8,
      height: gridHeight + 8,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isDark ? (isAmoled ? const Color(0xFF0A0A0F) : const Color(0xFF161622)) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF2E2E44) : const Color(0xFFCBD5E1),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0xFF090910) : const Color(0xFFCBD5E1),
            offset: const Offset(0, 6),
            blurRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: gridWidth,
          height: gridHeight,
          child: Stack(
            children: [
              // Subtle tactile cell background grid
              GridView.builder(
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: gridRows * gridCols,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: gridCols,
                  childAspectRatio: 1,
                ),
                itemBuilder: (context, index) {
                  final int r = index ~/ gridCols;
                  final int c = index % gridCols;
                  final bool isSelected = activeSelectionSet.contains(Point(c, r));
                  return Container(
                    margin: const EdgeInsets.all(1.5),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF06B6D4).withValues(alpha: 0.22)
                          : (isDark ? const Color(0xFF1F1F30) : const Color(0xFFF8FAFC)),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF06B6D4)
                            : (isDark ? const Color(0xFF2B2B40) : const Color(0xFFE2E8F0)),
                        width: 1,
                      ),
                    ),
                  );
                },
              ),

              // Found Word Highlights
              ..._paths.map((path) => _buildPathHighlight(path, cellSize)),

              // Current Selection Highlight
              if (_selectedCells != null)
                _buildPathHighlight(
                  FoundWordPath(
                    cells: _selectedCells!,
                    color: const Color(0xFF06B6D4).withValues(alpha: 0.38),
                  ),
                  cellSize,
                ),

              // Interaction & Letter Layer
              GestureDetector(
                onPanStart: (d) => _onPanStart(d, cellSize),
                onPanUpdate: (d) => _onPanUpdate(d, cellSize),
                onPanEnd: _onPanEnd,
                child: GridView.builder(
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: gridRows * gridCols,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: gridCols,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (context, index) {
                    final int r = index ~/ gridCols;
                    final int c = index % gridCols;
                    return Center(
                      child: Text(
                        _grid[r][c],
                        style: TextStyle(
                          fontSize: (cellSize * 0.50).clamp(12.0, 26.0),
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopSidebar(bool isDark, Color textColor) {
    final double progress = _wordsToFind.isEmpty
        ? 0.0
        : (_foundWords.length / _wordsToFind.length).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161622) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF2E2E44) : const Color(0xFFCBD5E1),
          width: 2,
        ),
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
          // Score & Best Row
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1F1F30) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? const Color(0xFF2E2E44) : const Color(0xFFE2E8F0),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SKOR',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.stars_rounded, color: Color(0xFFF59E0B), size: 20),
                          const SizedBox(width: 6),
                          Text(
                            '$_score',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1F1F30) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? const Color(0xFF2E2E44) : const Color(0xFFE2E8F0),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EN İYİ',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.emoji_events_rounded, color: Color(0xFF06B6D4), size: 20),
                          const SizedBox(width: 6),
                          Text(
                            '$_highScore',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Category Selector Chip
          _buildCompactCategoryChip(_currentCategory),
          const SizedBox(height: 16),

          // Progress Header + Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ARANAN KELİMELER',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              Text(
                '${_foundWords.length} / ${_wordsToFind.length}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF06B6D4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: isDark ? const Color(0xFF26263A) : const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
            ),
          ),
          const SizedBox(height: 14),

          // Words Checklist
          Expanded(
            child: ListView.separated(
              itemCount: _wordsToFind.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final String word = _wordsToFind[index];
                final bool found = _foundWords.contains(word);
                final String meaning = found ? _lookupMeaning(word) : '';

                return InkWell(
                  onTap: found ? () => TtsService.instance.speak(word) : null,
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: found
                          ? const Color(0xFF10B981).withValues(alpha: isDark ? 0.14 : 0.10)
                          : (isDark ? const Color(0xFF1F1F30) : const Color(0xFFF8FAFC)),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: found
                            ? const Color(0xFF10B981)
                            : (isDark ? const Color(0xFF2E2E44) : const Color(0xFFE2E8F0)),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          found ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          size: 18,
                          color: found
                              ? const Color(0xFF10B981)
                              : (isDark ? Colors.white38 : Colors.black38),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                word,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                  color: found
                                      ? (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857))
                                      : textColor,
                                  decoration: found ? TextDecoration.lineThrough : null,
                                ),
                              ),
                              if (found && meaning.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  meaning,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white70 : Colors.black54,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (found)
                          const Icon(
                            Icons.volume_up_rounded,
                            size: 18,
                            color: Color(0xFF10B981),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          if (_isGameOver) ...[
            const SizedBox(height: 12),
            _buildGameOverActionButtons(),
          ],
        ],
      ),
    );
  }

  Widget _buildGameOverActionButtons() {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: _showVictoryDialog,
          icon: const Icon(Icons.rate_review, color: Colors.white, size: 18),
          label: const Text(
            "Kelimeleri İncele",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF06B6D4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _startNewGame,
          icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
          label: const Text(
            "Sonraki Seviye",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactCategoryChip(String category) {
    final tr = wordHuntCategoryTr[category] ?? category;
    final icon = getWordHuntCategoryIcon(category);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showCategoryPickerAndStart(canDismiss: true),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF06B6D4).withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF06B6D4),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: const Color(0xFF06B6D4)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '${category.toUpperCase()} ($tr)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF06B6D4),
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.swap_horiz_rounded, size: 16, color: Color(0xFF06B6D4)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPathHighlight(FoundWordPath path, double cellSize) {
    if (path.cells.isEmpty) return const SizedBox();
    
    // Simplification: We assume the cells are in a line
    final start = path.cells.first;
    final end = path.cells.last;
    
    final startX = start.x * cellSize + cellSize / 2;
    final startY = start.y * cellSize + cellSize / 2;
    final endX = end.x * cellSize + cellSize / 2;
    final endY = end.y * cellSize + cellSize / 2;

    return CustomPaint(
      painter: LineHighlightPainter(
        Offset(startX, startY),
        Offset(endX, endY),
        path.color,
        cellSize * 0.8,
      ),
    );
  }
}

class FoundWordPath {
  final List<Point<int>> cells;
  final Color color;
  FoundWordPath({required this.cells, required this.color});
}

class LineHighlightPainter extends CustomPainter {
  final Offset start;
  final Offset end;
  final Color color;
  final double thickness;

  LineHighlightPainter(this.start, this.end, this.color, this.thickness);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(start, end, paint);
  }

  @override
  bool shouldRepaint(LineHighlightPainter oldDelegate) => true;
}
