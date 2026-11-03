import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../data/word_chain_data.dart';
import '../models/game_review_item.dart';
import '../services/audio_service.dart';
import '../services/profanity_filter_service.dart';
import '../services/score_service.dart';
import '../widgets/arcade/arcade_widgets.dart';
import '../widgets/exit_confirmation_dialog.dart';
import '../widgets/game_tutorial_popup.dart';
import '../widgets/marquee_title.dart';

class WordChainGameScreen extends StatefulWidget {
  const WordChainGameScreen({super.key});

  @override
  State<WordChainGameScreen> createState() => _WordChainGameScreenState();
}

class _WordChainGameScreenState extends State<WordChainGameScreen>
    with TickerProviderStateMixin {
  final ScrollController _chainScrollController = ScrollController();
  final List<String> _usedWords = [];
  final FocusNode _focusNode = FocusNode();

  String _currentWord = '';
  String _typedWord = '';
  int _score = 0;
  int _streak = 0;
  int _bestStreak = 0;
  double _timeLeftPercent = 1.0;
  bool _isGameOver = false;
  bool _isValidating = false;
  late AnimationController _timerController;
  late AnimationController _shakeController;
  String _errorMessage = '';

  final List<GameReviewItem> _sessionReviewItems = [];
  int _highScore = 0;
  bool _isNewHighScore = false;

  final List<String> _spawnPool = wordChainSpawnPool;

  static const Color _bgDark = Color(0xFF0D0D14);
  static const Color _surfaceDark = Color(0xFF161622);
  static const Color _borderDark = Color(0xFF28283E);
  static const Color _cyanAccent = Color(0xFF06B6D4);
  static const Color _amberLock = Color(0xFFF59E0B);
  static const Color _redError = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _highScore = ScoreService.instance.getHighScore('word_chain');
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _timerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )
      ..addListener(() {
        setState(() => _timeLeftPercent = 1.0 - _timerController.value);
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _handleTimeout();
        }
      });

    _currentWord = _spawnPool[Random().nextInt(_spawnPool.length)];
    _usedWords.add(_currentWord);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await GameTutorialPopup.show(
        context,
        tutorialKey: 'word_chain_tutorial',
        title: 'Word Chain',
        icon: FontAwesomeIcons.link,
        color: _cyanAccent,
        tutorialTextTr:
            'Word Chain oyununda süre bitmeden zinciri koparmadan uzatın!\n\n'
            '• Ekranda gösterilen kelimenin SON harfi ile başlayan yeni ve geçerli bir İngilizce kelime yazın.\n'
            '• Alttaki yerleşik klavyeden (veya bilgisayar klavyenizden) harfleri tuşlayıp GÖNDER / ENTER tuşuna basın.\n'
            '• Her doğru kelimede süre sıfırlanır, zincir uzar ve puanınız artar.\n'
            '• Dikkat: Kelimeler gerçek İngilizce sözlükte bulunmalı ve aynı oyunda tekrar kullanılmamalıdır!',
        tutorialTextEn:
            'In Word Chain, type new English words that start with the last letter of the given word using the built-in keyboard or your physical keyboard. Each correct word resets the timer and increases your score!',
      );

      if (!mounted) return;
      _startGame();
      _focusNode.requestFocus();
    });
  }

  void _startGame() {
    setState(() {
      _score = 0;
      _streak = 0;
      _bestStreak = 0;
      _isGameOver = false;
      _isNewHighScore = false;
      _sessionReviewItems.clear();
      _usedWords.clear();
      _typedWord = '';
      _errorMessage = '';
      _currentWord = _spawnPool[Random().nextInt(_spawnPool.length)];
      _usedWords.add(_currentWord);
    });
    _resetAndStartTimer();
    _focusNode.requestFocus();
  }

  void _resetAndStartTimer() {
    _timerController.stop();
    _timerController.reset();

    final int reduction = (_score ~/ 50);
    final int seconds = 15 - reduction;
    _timerController.duration = Duration(seconds: seconds < 6 ? 6 : seconds);

    _timerController.forward();
  }

  void _handleTimeout() {
    if (_isGameOver) return;
    _endGame();
  }

  void _endGame() {
    _timerController.stop();
    AudioService.playFailure();
    HapticFeedback.heavyImpact();
    setState(() {
      _isGameOver = true;
      _isValidating = false;
    });
    ScoreService.instance
        .recordScore(
      gameId: 'word_chain',
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
  }

  Future<bool> _isRealEnglishWord(String word) async {
    try {
      final response = await http
          .get(Uri.parse('https://api.datamuse.com/words?sp=$word&md=d&max=1'))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final firstMatch = data[0];
          final bool isMatch =
              firstMatch['word'].toString().toLowerCase() == word.toLowerCase();
          final bool hasDefinition = firstMatch['defs'] != null &&
              (firstMatch['defs'] as List).isNotEmpty;
          return isMatch && hasDefinition;
        }
      }
    } catch (_) {}
    return false;
  }

  void _onKeyPress(String letter) {
    if (_isGameOver || _isValidating) return;
    if (_typedWord.length >= 16) return;
    HapticFeedback.selectionClick();
    setState(() {
      _typedWord += letter.toUpperCase();
      if (_errorMessage.isNotEmpty) _errorMessage = '';
    });
  }

  void _onBackspace() {
    if (_isGameOver || _isValidating || _typedWord.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _typedWord = _typedWord.substring(0, _typedWord.length - 1);
      if (_errorMessage.isNotEmpty) _errorMessage = '';
    });
  }

  void _onClear() {
    if (_isGameOver || _isValidating || _typedWord.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _typedWord = '';
      if (_errorMessage.isNotEmpty) _errorMessage = '';
    });
  }

  KeyEventResult _handlePhysicalKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;

    if (_isGameOver) {
      if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) {
        _startGame();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (key == LogicalKeyboardKey.enter) {
      _submitWord();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete) {
      _onBackspace();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      _onClear();
      return KeyEventResult.handled;
    }

    final label = key.keyLabel;
    if (label.length == 1 && RegExp(r'^[a-zA-Z]$').hasMatch(label)) {
      _onKeyPress(label.toUpperCase());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _submitWord() async {
    final word = _typedWord.trim().toLowerCase();
    if (_isGameOver || _isValidating || word.isEmpty) return;

    if (word.length < 3) {
      _showError('En az 3 harfli olmalı!');
      setState(() => _typedWord = '');
      return;
    }

    final requiredChar = _currentWord[_currentWord.length - 1].toLowerCase();
    if (word[0] != requiredChar) {
      _showError("'${requiredChar.toUpperCase()}' harfiyle başlamalı!");
      setState(() => _typedWord = '');
      return;
    }

    if (!RegExp(r'^[a-z]+$').hasMatch(word)) {
      _showError('Sadece harfler kullanılabilir!');
      setState(() => _typedWord = '');
      return;
    }

    if (_usedWords.contains(word)) {
      _showError('Bu kelime daha önce kullanıldı!');
      setState(() => _typedWord = '');
      return;
    }

    if (ProfanityFilterService.containsProfanity(word)) {
      _showError('Bu kelimeye izin verilmiyor!');
      setState(() => _typedWord = '');
      return;
    }

    setState(() {
      _isValidating = true;
    });

    final isReal = await _isRealEnglishWord(word);

    if (!mounted) return;
    setState(() => _isValidating = false);

    if (!isReal) {
      _showError("'${word.toUpperCase()}' geçerli bir İngilizce kelime değil!");
      setState(() => _typedWord = '');
      return;
    }

    AudioService.playCorrect();
    HapticFeedback.lightImpact();
    setState(() {
      _typedWord = '';
      _currentWord = word;
      _usedWords.add(word);
      _sessionReviewItems.add(
        GameReviewItem(
          id: '${word}_${DateTime.now().millisecondsSinceEpoch}',
          word: word,
          meaning: 'Zincir Kelimesi (${word.length} harf)',
          question: 'Önceki kelimenin son harfiyle türetildi',
          userAnswer: word,
          correctAnswer: word,
          isCorrect: true,
        ),
      );

      final int timeBonus = (_timeLeftPercent * 20).round();
      final int lengthBonus = word.length * 2;
      _score += (10 + timeBonus + lengthBonus);

      _streak++;
      if (_streak > _bestStreak) _bestStreak = _streak;
      _errorMessage = '';
      _resetAndStartTimer();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chainScrollController.hasClients) {
        _chainScrollController.animateTo(
          _chainScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    _focusNode.requestFocus();
  }

  void _showError(String msg) {
    AudioService.playIncorrect();
    HapticFeedback.heavyImpact();
    setState(() {
      _errorMessage = msg;
    });
    _shakeController.forward(from: 0);
  }

  @override
  void dispose() {
    _timerController.dispose();
    _chainScrollController.dispose();
    _shakeController.dispose();
    _focusNode.dispose();
    super.dispose();
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 820;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handlePhysicalKey,
      child: GestureDetector(
        onTap: () => _focusNode.requestFocus(),
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            await _handleExit();
          },
          child: Scaffold(
            backgroundColor: _bgDark,
            appBar: _buildAppBar(),
            body: SafeArea(
              child: Stack(
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isDesktop ? 1000 : 620,
                      ),
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
                          padding: EdgeInsets.symmetric(
                            horizontal: isDesktop ? 24.0 : 14.0,
                            vertical: 8.0,
                          ),
                          child: Column(
                            children: [
                              _buildTopHud(),
                              const SizedBox(height: 10),
                              _buildTimerBar(),
                              const SizedBox(height: 10),
                              _buildChainRibbon(),
                              const SizedBox(height: 12),
                              Expanded(
                                child: SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  child: isDesktop
                                      ? _buildDesktopMainArea()
                                      : _buildMobileMainArea(),
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildBuiltInKeyboard(isDesktop: isDesktop),
                              SizedBox(height: isDesktop ? 10 : 6),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_isGameOver) _buildGameOverOverlay(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
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
        title: 'Word Chain',
        leadingIcon: const FaIcon(
          FontAwesomeIcons.link,
          size: 16,
          color: _cyanAccent,
        ),
        style: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
          tooltip: 'Yeniden Başlat',
          onPressed: _startGame,
        ),
        IconButton(
          icon: const Icon(
            Icons.help_outline_rounded,
            color: Colors.white70,
            size: 22,
          ),
          onPressed: () {
            GameTutorialPopup.show(
              context,
              tutorialKey: 'word_chain_tutorial',
              title: 'Word Chain',
              icon: FontAwesomeIcons.link,
              color: _cyanAccent,
              tutorialTextTr:
                  'Word Chain oyununda süre bitmeden zinciri koparmadan uzatın!\n\n'
                  '• Ekranda gösterilen kelimenin SON harfi ile başlayan yeni ve geçerli bir İngilizce kelime yazın.\n'
                  '• Alttaki yerleşik klavyeden (veya bilgisayar klavyenizden) harfleri tuşlayıp GÖNDER / ENTER tuşuna basın.\n'
                  '• Her doğru kelimede süre sıfırlanır, zincir uzar ve puanınız artar.\n'
                  '• Dikkat: Kelimeler gerçek İngilizce sözlükte bulunmalı ve aynı oyunda tekrar kullanılmamalıdır!',
              tutorialTextEn:
                  'In Word Chain, type new English words that start with the last letter of the given word using the built-in keyboard or your physical keyboard!',
            );
          },
        ),
      ],
    );
  }

  Widget _buildTopHud() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderDark, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _cyanAccent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _cyanAccent.withValues(alpha: 0.45)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const FaIcon(
                  FontAwesomeIcons.link,
                  size: 12,
                  color: _cyanAccent,
                ),
                const SizedBox(width: 6),
                Text(
                  'ZİNCİR: ${_usedWords.length}',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: _cyanAccent,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          if (_streak >= 2) ...[
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
              color: const Color(0xFF202032),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.stars_rounded,
                  color: _amberLock,
                  size: 16,
                ),
                const SizedBox(width: 5),
                Text(
                  '$_score',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerBar() {
    final Color barColor = _timeLeftPercent < 0.25
        ? _redError
        : _timeLeftPercent < 0.55
            ? _amberLock
            : const Color(0xFF10B981);

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 8,
        color: const Color(0xFF1E1E2E),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: _timeLeftPercent.clamp(0.0, 1.0),
            child: Container(color: barColor),
          ),
        ),
      ),
    );
  }

  Widget _buildChainRibbon() {
    return Container(
      height: 46,
      width: double.infinity,
      decoration: BoxDecoration(
        color: _surfaceDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderDark, width: 1.5),
      ),
      child: ListView.separated(
        controller: _chainScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        itemCount: _usedWords.length,
        separatorBuilder: (context, index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Center(
            child: FaIcon(
              FontAwesomeIcons.link,
              size: 11,
              color: _cyanAccent.withValues(alpha: 0.55),
            ),
          ),
        ),
        itemBuilder: (context, index) {
          final w = _usedWords[index];
          final isLast = index == _usedWords.length - 1;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isLast
                  ? _cyanAccent.withValues(alpha: 0.16)
                  : const Color(0xFF202032),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isLast ? _cyanAccent : const Color(0xFF2E2E44),
              ),
            ),
            child: Center(
              child: Text(
                w.toUpperCase(),
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: isLast ? _cyanAccent : Colors.white70,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDesktopMainArea() {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _buildActiveWordCard(isDesktop: true)),
          const SizedBox(width: 18),
          Expanded(child: _buildInputDisplayCard(isDesktop: true)),
        ],
      ),
    );
  }

  Widget _buildMobileMainArea() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildActiveWordCard(isDesktop: false),
        const SizedBox(height: 12),
        _buildInputDisplayCard(isDesktop: false),
      ],
    );
  }

  Widget _buildActiveWordCard({required bool isDesktop}) {
    final word = _currentWord.toUpperCase();
    final lastChar = word.isNotEmpty ? word[word.length - 1] : '';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 22 : 16,
        vertical: isDesktop ? 24 : 16,
      ),
      decoration: BoxDecoration(
        color: _surfaceDark,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _borderDark, width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const FaIcon(
                FontAwesomeIcons.link,
                size: 12,
                color: _cyanAccent,
              ),
              const SizedBox(width: 8),
              Text(
                'MEVCUT KELİME',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: _cyanAccent,
                ),
              ),
            ],
          ),
          SizedBox(height: isDesktop ? 16 : 12),
          if (word.isNotEmpty)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(word.length, (i) {
                  final isLast = i == word.length - 1;
                  final char = word[i];
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 14 : 12,
                      vertical: isDesktop ? 8 : 6,
                    ),
                    decoration: BoxDecoration(
                      color: isLast ? _amberLock : const Color(0xFF222234),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isLast ? _amberLock : const Color(0xFF32324A),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isLast
                              ? const Color(0xFFB45309)
                              : const Color(0xFF0A0A10),
                          offset: const Offset(0, 3),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Text(
                      char,
                      style: GoogleFonts.outfit(
                        fontSize: isDesktop ? 32 : 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  );
                }),
              ),
            ),
          SizedBox(height: isDesktop ? 16 : 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _amberLock.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _amberLock.withValues(alpha: 0.45)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const FaIcon(FontAwesomeIcons.lock, size: 11, color: _amberLock),
                const SizedBox(width: 6),
                Text(
                  'YENİ KELİME BAŞLANGICI: ',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white70,
                  ),
                ),
                Text(
                  lastChar,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: _amberLock,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputDisplayCard({required bool isDesktop}) {
    final requiredLetter = _currentWord.isNotEmpty
        ? _currentWord[_currentWord.length - 1].toUpperCase()
        : '';
    final bool startsCorrectly =
        _typedWord.isEmpty || _typedWord.startsWith(requiredLetter);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 22 : 16,
        vertical: isDesktop ? 20 : 14,
      ),
      decoration: BoxDecoration(
        color: _surfaceDark,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _errorMessage.isNotEmpty
              ? _redError
              : (_typedWord.isNotEmpty ? _cyanAccent : _borderDark),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'YAZILAN KELİME',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: Colors.white60,
                ),
              ),
              if (_typedWord.isNotEmpty)
                GestureDetector(
                  onTap: _onClear,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF242438),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Temizle',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Typed Word Slot Box
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 54),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF10101A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: !startsCorrectly
                    ? _redError
                    : const Color(0xFF28283E),
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: _typedWord.isEmpty
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _amberLock.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _amberLock),
                        ),
                        child: Text(
                          requiredLetter,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: _amberLock,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          'ile başlayan kelime yazın...',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white38,
                          ),
                        ),
                      ),
                    ],
                  )
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_typedWord.length, (i) {
                        final char = _typedWord[i];
                        final isFirst = i == 0;
                        final Color tileBg = isFirst
                            ? (char == requiredLetter
                                ? _amberLock
                                : _redError)
                            : const Color(0xFF232336);
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2.5),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: tileBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            char,
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
          ),

          if (_errorMessage.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _redError.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _redError.withValues(alpha: 0.45)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const FaIcon(
                    FontAwesomeIcons.triangleExclamation,
                    size: 13,
                    color: _redError,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _redError,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: (_isGameOver || _isValidating || _typedWord.isEmpty)
                  ? null
                  : _submitWord,
              style: ElevatedButton.styleFrom(
                backgroundColor: _cyanAccent,
                foregroundColor: const Color(0xFF071114),
                disabledBackgroundColor: const Color(0xFF222234),
                disabledForegroundColor: Colors.white30,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isValidating
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF071114),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'KONTROL EDİLİYOR...',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const FaIcon(FontAwesomeIcons.link, size: 14),
                        const SizedBox(width: 8),
                        Text(
                          'ZİNCİRE BAĞLA (ENTER)',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuiltInKeyboard({required bool isDesktop}) {
    final requiredLetter = _currentWord.isNotEmpty
        ? _currentWord[_currentWord.length - 1].toUpperCase()
        : '';

    const List<List<String>> rows = [
      ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
      ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'],
      ['ENTER', 'Z', 'X', 'C', 'V', 'B', 'N', 'M', 'DEL'],
    ];

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 14 : 6,
        vertical: isDesktop ? 12 : 8,
      ),
      decoration: BoxDecoration(
        color: _surfaceDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderDark, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: rows.map((row) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: row.map((key) {
                final bool isAction = key == 'ENTER' || key == 'DEL';
                final bool isRequiredStart =
                    !isAction && _typedWord.isEmpty && key == requiredLetter;

                Color btnBg = const Color(0xFF232336);
                Color lipBg = const Color(0xFF10101A);
                Color txtColor = Colors.white;

                if (key == 'ENTER') {
                  btnBg = _cyanAccent;
                  lipBg = const Color(0xFF0E7490);
                  txtColor = const Color(0xFF071114);
                } else if (key == 'DEL') {
                  btnBg = const Color(0xFF33273A);
                  lipBg = const Color(0xFF1B1420);
                  txtColor = const Color(0xFFFCA5A5);
                } else if (isRequiredStart) {
                  btnBg = _amberLock;
                  lipBg = const Color(0xFFB45309);
                  txtColor = Colors.white;
                }

                return Flexible(
                  flex: isAction ? 15 : 10,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isAction
                          ? (isDesktop ? 88 : 60)
                          : (isDesktop ? 60 : 40),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 3.5 : 2.0,
                      ),
                      child: GestureDetector(
                        onTap: () {
                          if (key == 'ENTER') {
                            _submitWord();
                          } else if (key == 'DEL') {
                            _onBackspace();
                          } else {
                            _onKeyPress(key);
                          }
                        },
                        child: Container(
                          height: isDesktop ? 48 : 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: btnBg,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: lipBg,
                                offset: const Offset(0, 3),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          child: key == 'DEL'
                              ? Icon(
                                  Icons.backspace_outlined,
                                  size: isDesktop ? 19 : 16,
                                  color: txtColor,
                                )
                              : Text(
                                  key == 'ENTER' ? 'OK' : key,
                                  style: GoogleFonts.outfit(
                                    fontSize: isAction
                                        ? (isDesktop ? 14 : 12)
                                        : (isDesktop ? 17 : 15),
                                    fontWeight: FontWeight.w900,
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

  Widget _buildGameOverOverlay() {
    return ArcadeGameOverCard(
      title: 'ZİNCİR KOPTU!',
      subtitle: 'Süre doldu! Oluşturduğun kelime zincirini incele:',
      icon: FontAwesomeIcons.linkSlash,
      accent: _cyanAccent,
      surface: _surfaceDark,
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
          onTap: _startGame,
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
