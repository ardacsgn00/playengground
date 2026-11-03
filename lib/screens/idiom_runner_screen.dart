import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../games/idiom_runner/idiom_model.dart';
import '../games/idiom_runner/idiom_runner_game.dart';
import '../services/tts_service.dart';
import '../widgets/exit_confirmation_dialog.dart';
import '../widgets/game_tutorial_popup.dart';
import '../widgets/marquee_title.dart';
import '../services/mistake_service.dart';
import '../services/score_service.dart';
import '../models/game_review_item.dart';
import '../widgets/game_review_accordion.dart';

class IdiomRunnerScreen extends StatefulWidget {
  const IdiomRunnerScreen({super.key});

  @override
  State<IdiomRunnerScreen> createState() => _IdiomRunnerScreenState();
}

class _IdiomRunnerScreenState extends State<IdiomRunnerScreen>
    with SingleTickerProviderStateMixin {
  late IdiomRunnerGame _game;

  // Track state mirrored from the Flame Game
  int _score = 0;
  int _lives = 3;
  int _streak = 0;
  String _prompt = "...";
  bool _isGameOver = false;

  // Review
  final List<GameReviewItem> _sessionReviewItems = [];

  // Feedback states
  String? _feedbackText;
  Color? _feedbackColor;
  bool _showFeedback = false;

  // Translation states
  String? _completedIdiom;
  String? _turkishMeaning;
  bool _showTranslation = false;
  int _translationSession = 0;

  @override
  void initState() {
    super.initState();

    // 1. Initialize the Flame Game class
    _game = IdiomRunnerGame();

    // 2. Set callbacks to sync stats and trigger effects
    _game.onStatsUpdated = (score, lives, streak, IdiomModel currentIdiom) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _score = score;
              _lives = lives;
              _streak = streak;
              _prompt = currentIdiom.prompt;
            });
          }
        });
      }
    };

    _game.onGameOverTriggered = () async {
      await ScoreService.instance.recordScore(
        gameId: 'idiom_runner',
        score: _score,
        streak: _streak,
      );
      if (mounted) {
        setState(() {
          _isGameOver = true;
          _showTranslation = false; // Hide translation on game over
        });
      }
    };

    _game.onCorrectAnswerEffect = () {
      final completedIdiom = _game.currentIdiom;
      if (completedIdiom != null) {
        final phrase = "${completedIdiom.prompt.replaceAll('...', '')} ${completedIdiom.correctAnswer}";
        final translation = completedIdiom.turkish;
        TtsService.instance.speak(phrase);

        _sessionReviewItems.add(
          GameReviewItem(
            word: phrase,
            meaning: translation,
            question: completedIdiom.prompt,
            userAnswer: completedIdiom.correctAnswer,
            correctAnswer: completedIdiom.correctAnswer,
            isCorrect: true,
          ),
        );

        final currentSession = ++_translationSession;
        if (mounted) {
          setState(() {
            _completedIdiom = phrase;
            _turkishMeaning = translation;
            _showTranslation = true;

            // Set correct feedback bubble
            _feedbackText = "Correct! +10";
            _feedbackColor = Colors.greenAccent;
            _showFeedback = true;
          });
        }

        // Hide feedback after 1.2 seconds
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted && _translationSession == currentSession) {
            setState(() {
              _showFeedback = false;
            });
          }
        });

        // Hide translation after 2.5 seconds
        Future.delayed(const Duration(milliseconds: 2500), () {
          if (mounted && _translationSession == currentSession) {
            setState(() {
              _showTranslation = false;
            });
          }
        });
      }
    };

    _game.onWrongAnswerEffect = () {
      final currentSession = ++_translationSession;
      if (mounted) {
        setState(() {
          // Set incorrect feedback bubble
          _feedbackText = "Wrong!";
          _feedbackColor = Colors.redAccent;
          _showFeedback = true;
          
          final idiom = _game.currentIdiom;
          if (idiom != null) {
            _completedIdiom = idiom.prompt.replaceAll("...", " ${idiom.correctAnswer}");
            _turkishMeaning = idiom.turkish;
            _showTranslation = true;
            TtsService.instance.speak(_completedIdiom!);

            _sessionReviewItems.add(
              GameReviewItem(
                word: _completedIdiom!,
                meaning: idiom.turkish,
                question: idiom.prompt,
                userAnswer: 'Wrong Lane',
                correctAnswer: idiom.correctAnswer,
                isCorrect: false,
              ),
            );

            MistakeService.instance.recordMistake(
              word: _completedIdiom!,
              meaning: idiom.turkish,
              sourceGame: 'Idiom Driver',
            );
          } else {
            _showTranslation = false;
          }
        });
      }

      // Hide feedback after 1.2 seconds
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted && _translationSession == currentSession) {
          setState(() {
            _showFeedback = false;
          });
        }
      });

      // Hide translation after 3.0 seconds to give enough time to read
      Future.delayed(const Duration(milliseconds: 3000), () {
        if (mounted && _translationSession == currentSession) {
          setState(() {
            _showTranslation = false;
          });
        }
      });
    };

    // 3. Show tutorial dialog on first mount
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await GameTutorialPopup.show(
        context,
        tutorialKey: 'idiom_driver_tutorial',
        title: "Idiom Driver",
        icon: FontAwesomeIcons.car,
        color: const Color(0xFFFF6B6B),
        tutorialTextTr:
            'Idiom Driver oyununda pistte hızla ilerlerken İngilizce deyimleri tamamlayın!\n\n'
            '• Üst kısımda gösterilen eksik deyimi okuyun (örn: "Piece of ___").\n'
            '• Karşınıza çıkan kapılardan deyimi doğru tamamlayan kelimenin bulunduğu şeride geçin ve kapıdan geçin.\n'
            '• Şerit Değiştirme: Ekranda sola/sağa kaydırabilir, alt yön butonlarına dokunabilir veya klavyede Sol/Sağ Ok (A/D) tuşlarını kullanabilirsiniz.\n'
            '• Hızlanma: Sarı "Hız Artır" butonuna (veya PC\'de Boşluk tuşuna) basılı tutarak arabanızı hızlandırabilirsiniz!',
        tutorialTextEn: "In Idiom Driver, complete the English idiom shown at the top by driving your car through the gate with the correct word!\n\nSwipe left/right, tap the bottom arrows, or use the Keyboard Arrow / A-D keys to switch lanes. You can also hold down the yellow Speed Boost button (or hold the Spacebar on PC) to accelerate!",
      );
    });
  }

  @override
  void dispose() {
    TtsService.instance.stop();
    super.dispose();
  }

  void _resetGame() {
    setState(() {
      _isGameOver = false;
      _showTranslation = false;
      _sessionReviewItems.clear();
    });
    _game.resetGame();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E2C) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final wasRunning = !_isGameOver && !_game.paused;
        if (wasRunning) {
          _game.pauseEngine();
        }
        final shouldPop = await showExitConfirmationDialog(context);
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        } else if (wasRunning && context.mounted && !_isGameOver) {
          _game.resumeEngine();
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: MarqueeTitle(
            title: 'Idiom Driver',
            leadingIcon: const Icon(FontAwesomeIcons.car, color: Color(0xFFFF6B6B), size: 18),
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.transparent,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _resetGame,
              tooltip: 'Restart',
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final bool isDesktop = constraints.maxWidth >= 980;
            final Widget centerRoadArena = ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ClipRRect(
                borderRadius: isDesktop
                    ? BorderRadius.circular(22)
                    : BorderRadius.zero,
                child: Stack(
                  children: [
                    // 1. The Game Widget (handles horizontal swipe navigation)
                    GestureDetector(
                      onHorizontalDragEnd: (details) {
                        if (details.primaryVelocity != null && !_isGameOver) {
                          if (details.primaryVelocity! < -300) {
                            _game.player.moveLeft();
                          } else if (details.primaryVelocity! > 300) {
                            _game.player.moveRight();
                          }
                        }
                      },
                      child: GameWidget(game: _game),
                    ),

                    // 4. Flutter UI stats overlay
                    SafeArea(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Header panel containing Hearts + Score + Streak
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24.0, vertical: 8.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  // Lives Hearts
                                  Row(
                                    children: List.generate(3, (index) {
                                      return Icon(
                                        index < _lives
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        color: Colors.redAccent,
                                        size: 28,
                                      );
                                    }),
                                  ),
                                  // Score & Streak
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        "Score: $_score",
                                        style: GoogleFonts.outfit(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          shadows: const [
                                            Shadow(
                                              color: Colors.black45,
                                              offset: Offset(1.5, 1.5),
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (_streak > 1)
                                        Container(
                                          margin:
                                              const EdgeInsets.only(top: 4),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.orange
                                                .withValues(alpha: 0.88),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            "🔥 Streak: x$_streak",
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Solid Tactile Idiom Prompt Card
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 8),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: cardColor.withValues(alpha: 0.94),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: _showFeedback
                                      ? (_feedbackColor ?? Colors.transparent)
                                      : (isDark
                                          ? const Color(0xFF32324A)
                                          : Colors.black12),
                                  width: 2.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black
                                        .withValues(alpha: isDark ? 0.35 : 0.12),
                                    blurRadius: 0,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    "COMPLETE THE IDIOM:",
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFFFF6B6B),
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _prompt,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.outfit(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
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

                    // 5. Accessible Arrow button controls with bottom feedback/correction bar
                    SafeArea(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Unobstructed bottom feedback & translation bar
                            AnimatedSize(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutBack,
                              child: (_showFeedback ||
                                      (_showTranslation &&
                                          _completedIdiom != null))
                                  ? Container(
                                      constraints:
                                          const BoxConstraints(maxWidth: 520),
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 6),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF141422)
                                            .withValues(alpha: 0.95),
                                        borderRadius:
                                            BorderRadius.circular(18),
                                        border: Border.all(
                                          color: _showFeedback
                                              ? (_feedbackColor ??
                                                  const Color(0xFF10B981))
                                              : const Color(0xFFF59E0B),
                                          width: 2.0,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0xFF090910),
                                            offset: Offset(0, 4),
                                            blurRadius: 0,
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (_showFeedback &&
                                              _feedbackText != null)
                                            Padding(
                                              padding: EdgeInsets.only(
                                                bottom: (_showTranslation &&
                                                        _completedIdiom != null)
                                                    ? 4.0
                                                    : 0.0,
                                              ),
                                              child: Row(
                                                mainAxisSize:
                                                    MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    _feedbackColor ==
                                                            Colors.redAccent
                                                        ? Icons.cancel_rounded
                                                        : Icons
                                                            .check_circle_rounded,
                                                    color: _feedbackColor,
                                                    size: 16,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    _feedbackText!,
                                                    style:
                                                        GoogleFonts.outfit(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: _feedbackColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          if (_showTranslation &&
                                              _completedIdiom != null) ...[
                                            Text(
                                              _completedIdiom!,
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.outfit(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                                fontStyle:
                                                    FontStyle.italic,
                                              ),
                                            ),
                                            if (_turkishMeaning != null) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                _turkishMeaning!,
                                                textAlign: TextAlign.center,
                                                style: GoogleFonts.outfit(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color:
                                                      const Color(0xFFFBBF24),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ],
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(
                                  bottom: 24.0, top: 4.0),
                              child: Builder(
                                builder: (context) {
                              final isMobile =
                                  MediaQuery.of(context).size.width < 600;
                              final buttonSize = isMobile ? 80.0 : 64.0;
                              final iconSize = isMobile ? 32.0 : 24.0;

                              return Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  // Left Arrow
                                  GestureDetector(
                                    onTap: () {
                                      if (!_isGameOver) {
                                        _game.player.moveLeft();
                                      }
                                    },
                                    child: Container(
                                      width: buttonSize,
                                      height: buttonSize,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF1E1E2C)
                                                .withValues(alpha: 0.85)
                                            : Colors.white
                                                .withValues(alpha: 0.85),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isDark
                                              ? Colors.white24
                                              : Colors.black12,
                                          width: 2,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.arrow_back_ios_new_rounded,
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.black87,
                                        size: iconSize,
                                      ),
                                    ),
                                  ),
                                  // Boost / Gas Button (Center)
                                  GestureDetector(
                                    onTapDown: (_) {
                                      if (!_isGameOver) {
                                        _game.setBoosting(true);
                                      }
                                    },
                                    onTapUp: (_) {
                                      _game.setBoosting(false);
                                    },
                                    onTapCancel: () {
                                      _game.setBoosting(false);
                                    },
                                    child: Container(
                                      width: buttonSize,
                                      height: buttonSize,
                                      decoration: BoxDecoration(
                                        color: Colors.amberAccent
                                            .withValues(alpha: 0.18),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.amberAccent
                                              .withValues(alpha: 0.75),
                                          width: 2.5,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.speed_rounded,
                                        color: Colors.amberAccent,
                                        size: iconSize + 4,
                                      ),
                                    ),
                                  ),
                                  // Right Arrow
                                  GestureDetector(
                                    onTap: () {
                                      if (!_isGameOver) {
                                        _game.player.moveRight();
                                      }
                                    },
                                    child: Container(
                                      width: buttonSize,
                                      height: buttonSize,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF1E1E2C)
                                                .withValues(alpha: 0.85)
                                            : Colors.white
                                                .withValues(alpha: 0.85),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isDark
                                              ? Colors.white24
                                              : Colors.black12,
                                          width: 2,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.black87,
                                        size: iconSize,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                    // 6. Game Over Overlay Dialog
                    if (_isGameOver)
                      _buildGameOverDialog(isDark, cardColor, textColor),
                  ],
                ),
              ),
            );

            if (!isDesktop) {
              return Center(child: centerRoadArena);
            }

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1220),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 280,
                        child: _buildDesktopLeftPanel(isDark, textColor),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Center(child: centerRoadArena),
                      ),
                      const SizedBox(width: 20),
                      SizedBox(
                        width: 280,
                        child: _buildDesktopRightPanel(isDark, textColor),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDesktopLeftPanel(bool isDark, Color textColor) {
    final Color cardBg = isDark ? const Color(0xFF161622) : Colors.white;
    final Color innerBg = isDark ? const Color(0xFF1F1F30) : const Color(0xFFF8FAFC);
    final Color borderColor = isDark ? const Color(0xFF2E2E44) : const Color(0xFFCBD5E1);

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
          // Header Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B6B).withValues(alpha: isDark ? 0.14 : 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFF6B6B), width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(FontAwesomeIcons.car, size: 16, color: Color(0xFFFF6B6B)),
                const SizedBox(width: 10),
                Text(
                  'SÜRÜŞ TELEMETRİSİ',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.9,
                    color: const Color(0xFFFF6B6B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Lives Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: innerBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CAN HAKKI',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
                Row(
                  children: List.generate(3, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(
                        index < _lives ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: const Color(0xFFEF4444),
                        size: 20,
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Score Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
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

          // Active Idiom Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: innerBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AKTİF DEYİM',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.9,
                    color: const Color(0xFFFF6B6B),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _prompt,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),

          // Tactile Controls & Keyboard Shortcuts
          Text(
            'SÜRÜŞ KONTROLLERİ',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      if (!_isGameOver) _game.player.moveLeft();
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: innerBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderColor, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: isDark ? const Color(0xFF090910) : const Color(0xFFCBD5E1),
                            offset: const Offset(0, 3),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.arrow_back_rounded, color: textColor, size: 22),
                          const SizedBox(height: 4),
                          Text(
                            'SOL [A / ←]',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      if (!_isGameOver) _game.player.moveRight();
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: innerBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderColor, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: isDark ? const Color(0xFF090910) : const Color(0xFFCBD5E1),
                            offset: const Offset(0, 3),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.arrow_forward_rounded, color: textColor, size: 22),
                          const SizedBox(height: 4),
                          Text(
                            'SAĞ [D / →]',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: textColor,
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
          const SizedBox(height: 8),
          GestureDetector(
            onTapDown: (_) {
              if (!_isGameOver) _game.setBoosting(true);
            },
            onTapUp: (_) => _game.setBoosting(false),
            onTapCancel: () => _game.setBoosting(false),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.16 : 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0xFFB45309),
                    offset: Offset(0, 3),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.speed_rounded, color: Color(0xFFF59E0B), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'BASILI TUT: HIZLAN [SPACE]',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFF59E0B),
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

  Widget _buildDesktopRightPanel(bool isDark, Color textColor) {
    final Color cardBg = isDark ? const Color(0xFF161622) : Colors.white;
    final Color innerBg = isDark ? const Color(0xFF1F1F30) : const Color(0xFFF8FAFC);
    final Color borderColor = isDark ? const Color(0xFF2E2E44) : const Color(0xFFCBD5E1);
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
          // Persistent Last Idiom Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.14 : 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lightbulb_rounded, color: Color(0xFFF59E0B), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'SON GEÇİLEN DEYİM',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: const Color(0xFFF59E0B),
                          ),
                        ),
                      ],
                    ),
                    if (_completedIdiom != null)
                      InkWell(
                        onTap: () => TtsService.instance.speak(_completedIdiom!),
                        child: const Icon(Icons.volume_up_rounded, size: 18, color: Color(0xFFF59E0B)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _completedIdiom ?? 'Henüz bir kapıdan geçilmedi',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                if (_turkishMeaning != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _turkishMeaning!,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Session Idioms Log Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DEYİM GEÇMİŞİ',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              Text(
                '${items.length} Deyim',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFFF6B6B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Scrollable Session Idioms
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
                      child: Text(
                        'Pistte kapılardan geçtikçe tamamladığın deyimler ve Türkçe anlamları burada listelenir.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final bool ok = item.isCorrect;
                      final Color accent =
                          ok ? const Color(0xFF10B981) : const Color(0xFFEF4444);

                      return InkWell(
                        onTap: () => TtsService.instance.speak(item.word),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: isDark ? 0.12 : 0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: accent, width: 1.5),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                ok
                                    ? Icons.check_circle_rounded
                                    : Icons.cancel_rounded,
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
                                        fontSize: 13,
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
                              Icon(
                                Icons.volume_up_rounded,
                                size: 16,
                                color: accent,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameOverDialog(bool isDark, Color cardBg, Color textColor) {
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.85, end: 1.0),
          duration: const Duration(milliseconds: 300),
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
                maxWidth: 420,
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.sentiment_very_dissatisfied_rounded,
                        size: 56,
                        color: Colors.redAccent,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Game Over!',
                      style: GoogleFonts.outfit(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "SCORE: $_score",
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🔥', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Text(
                            'EN YÜKSEK SERİ: $_streak',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    if (_sessionReviewItems.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      GameReviewAccordion(
                        items: _sessionReviewItems,
                        accentColor: const Color(0xFFFF6B6B),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _resetGame,
                        icon: const Icon(Icons.replay),
                        label: Text(
                          'Yeniden Oyna',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.arrow_back),
                        label: Text(
                          'Ana Menü',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: isDark ? Colors.grey[400] : Colors.grey[600],
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
    );
  }
}
