import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/phrasal_rocket_data.dart';
import '../services/audio_service.dart';
import '../services/tts_service.dart';
import '../widgets/game_tutorial_popup.dart';
import '../widgets/exit_confirmation_dialog.dart';
import '../widgets/marquee_title.dart';
import '../services/mistake_service.dart';
import '../services/score_service.dart';
import '../models/game_review_item.dart';
import '../widgets/game_review_accordion.dart';

class _Layer {
  final String name;
  final double start; // km
  final Color color;
  const _Layer(this.name, this.start, this.color);
}

class _Mistake {
  final String sentence;
  final String meaning;
  const _Mistake(this.sentence, this.meaning);
}

class PhrasalRocketScreen extends StatefulWidget {
  const PhrasalRocketScreen({super.key});

  @override
  State<PhrasalRocketScreen> createState() => _PhrasalRocketScreenState();
}

class _PhrasalRocketScreenState extends State<PhrasalRocketScreen>
    with TickerProviderStateMixin {
  static const Color _accent = Color(0xFF8B5CF6);
  static const Color _green = Color(0xFF10B981);
  static const Color _red = Color(0xFFEF4444);

  static const List<_Layer> _layers = [
    _Layer('TROPOSPHERE', 0, Color(0xFF7DD3FC)),
    _Layer('STRATOSPHERE', 15, Color(0xFF3B82F6)),
    _Layer('MESOSPHERE', 50, Color(0xFF1E3A8A)),
    _Layer('THERMOSPHERE', 90, Color(0xFF312E81)),
    _Layer('EXOSPHERE', 160, Color(0xFF1E1B4B)),
    _Layer('ORBIT', 250, Color(0xFF0F172A)),
    _Layer('MOON', 400, Color(0xFF020617)),
    _Layer('DEEP SPACE', 600, Color(0xFF000000)),
  ];

  final FocusNode _focusNode = FocusNode();
  final Random _random = Random();
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  // --- Flight state ---
  double _altitude = 0; // target km
  double _displayAlt = 0; // smoothed km for rendering
  double _fuel = 100;
  double _idleTime = 0; // keeps clouds/stars drifting
  double _shakeTime = 0;
  double _flameTime = 0;

  // --- Question state ---
  final List<PhrasalQuestion> _deck = [];
  PhrasalQuestion? _question;
  List<String> _options = const [];
  int? _selected;
  bool _locked = false;
  double _questionTime = 0;

  // --- Meta ---
  int _score = 0;
  int _highScore = 0;
  bool _isNewHighScore = false;
  int _streak = 0;
  int _maxStreak = 0;
  int _correctCount = 0;
  bool _running = false;
  bool _isGameOver = false;
  String? _layerBanner;
  final List<_Mistake> _mistakes = [];
  final List<GameReviewItem> _sessionReviewItems = [];

  int _layerIndexFor(double alt) {
    int idx = 0;
    for (int i = 0; i < _layers.length; i++) {
      if (alt >= _layers[i].start) idx = i;
    }
    return idx;
  }

  double get _drainPerSecond => 5.0 + _layerIndexFor(_altitude) * 1.0;

  @override
  void initState() {
    super.initState();
    _highScore = ScoreService.instance.getHighScore('phrasal_rocket');
    _ticker = createTicker(_onTick)..start();
    _nextQuestion();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _focusNode.requestFocus();
      await GameTutorialPopup.show(
        context,
        tutorialKey: 'phrasal_rocket_tutorial',
        title: 'Phrasal Rocket',
        icon: FontAwesomeIcons.rocket,
        color: _accent,
        tutorialTextTr:
            'Phrasal Rocket oyununda roketin yakıtı sürekli tükeniyor! Cümledeki boşluğa doğru edatı (UP, OUT, OFF...) yerleştirerek phrasal verb\'ü tamamlayın:\n\n'
            '• Doğru cevap: Rokete yakıt pompalar ve irtifa kazandırır. Ne kadar hızlı cevaplarsanız o kadar güçlü itiş gücü alırsınız!\n'
            '• Yanlış cevap: Türbülansa yol açar; yakıt ve irtifa kaybedersiniz.\n'
            '• Yüksek atmosfer katmanlarına çıktıkça yakıt tüketimi hızlanır.\n\n'
            'Seçeneklere dokunabilir veya klavyeden [1-4] tuşlarını kullanabilirsiniz. Hedef: Atmosferi aşıp Ay\'a ulaşmak! 🌙',
        tutorialTextEn:
            'Your rocket is burning fuel nonstop! Pick the right particle (UP, OUT, OFF...) to complete the phrasal verb.\n\n'
            '• Correct: refuel and climb. Faster answers = bigger boost!\n'
            '• Wrong: turbulence! You lose fuel and altitude.\n'
            '• Higher atmosphere layers burn fuel faster.\n\n'
            'Tap or press keys 1–4. Goal: reach the Moon! 🌙',
      );
      if (!mounted) return;
      setState(() => _running = true);
    });
  }

  @override
  void dispose() {
    TtsService.instance.stop();
    _ticker.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ───────────────────────── Loop ─────────────────────────

  void _onTick(Duration elapsed) {
    final double dt =
        ((elapsed - _lastElapsed).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _lastElapsed = elapsed;
    if (!mounted) return;

    setState(() {
      _flameTime += dt;
      _displayAlt += (_altitude - _displayAlt) * min(1.0, dt * 4);
      if (_shakeTime > 0) _shakeTime = max(0, _shakeTime - dt);

      if (_running && !_isGameOver) {
        _idleTime += dt;
        if (!_locked) {
          _questionTime += dt;
          _fuel -= _drainPerSecond * dt;
        }
        if (_fuel <= 0) {
          _fuel = 0;
          _gameOver();
        }
      }
    });
  }

  // ───────────────────────── Logic ─────────────────────────

  void _nextQuestion() {
    if (_deck.isEmpty) {
      _deck.addAll(PhrasalRocketData.questions);
      _deck.shuffle(_random);
    }
    final q = _deck.removeLast();
    _question = q;
    _options = [q.answer, ...q.wrong]..shuffle(_random);
    _selected = null;
    _locked = false;
    _questionTime = 0;
  }

  void _answer(int index) {
    final q = _question;
    if (q == null || !_running || _locked || _isGameOver) return;
    if (index >= _options.length) return;

    final bool correct = _options[index] == q.answer;
    final int prevLayer = _layerIndexFor(_altitude);

    final String phrasalVerb = q.meaning.split('=').first.trim();
    TtsService.instance.speak(phrasalVerb);

    String turkishMeaning = q.meaning;
    if (q.meaning.contains('=')) {
      turkishMeaning = q.meaning.split('=').last.trim();
    }

    setState(() {
      _locked = true;
      _selected = index;

      if (correct) {
        final double mult = _streak >= 10
            ? 3.0
            : _streak >= 6
                ? 2.0
                : _streak >= 3
                    ? 1.5
                    : 1.0;
        final double speed = max(0.0, 6 - _questionTime);
        _altitude += (6 + speed) * mult;
        _fuel = min(100, _fuel + 18);
        _score += ((100 + speed * 20) * mult).round();
        _streak += 1;
        _maxStreak = max(_maxStreak, _streak);
        _correctCount += 1;

        _sessionReviewItems.add(GameReviewItem(
          word: phrasalVerb,
          meaning: turkishMeaning,
          question: q.sentence,
          userAnswer: _options[index],
          correctAnswer: q.answer,
          isCorrect: true,
        ));
      } else {
        _fuel = max(0, _fuel - 20);
        _altitude = max(0, _altitude - 3);
        _streak = 0;
        _shakeTime = 0.45;
        _mistakes.add(_Mistake(
          q.sentence.replaceFirst('___', q.answer.toUpperCase()),
          q.meaning,
        ));
        MistakeService.instance.recordMistake(
          word: phrasalVerb,
          meaning: turkishMeaning,
          sourceGame: 'Phrasal Rocket',
          wrongAnswer: _options[index],
        );

        _sessionReviewItems.add(GameReviewItem(
          word: phrasalVerb,
          meaning: turkishMeaning,
          question: q.sentence,
          userAnswer: _options[index],
          correctAnswer: q.answer,
          isCorrect: false,
          note: q.sentence.replaceFirst('___', q.answer.toUpperCase()),
        ));
      }
    });

    if (correct) {
      HapticFeedback.lightImpact();
      final int newLayer = _layerIndexFor(_altitude);
      if (newLayer > prevLayer) {
        AudioService.playSuccess();
        _showLayerBanner(_layers[newLayer].name);
      } else {
        AudioService.playCorrect();
      }
    } else {
      HapticFeedback.heavyImpact();
      AudioService.playIncorrect();
    }

    Future.delayed(Duration(milliseconds: correct ? 900 : 1600), () {
      if (!mounted || _isGameOver) return;
      if (_fuel <= 0) {
        _gameOver();
      } else {
        setState(_nextQuestion);
      }
    });
  }

  void _showLayerBanner(String name) {
    setState(() => _layerBanner = name);
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted && _layerBanner == name) setState(() => _layerBanner = null);
    });
  }

  void _gameOver() async {
    if (_isGameOver) return;
    _isGameOver = true;
    AudioService.playFailure();
    final res = await ScoreService.instance.recordScore(
      gameId: 'phrasal_rocket',
      score: _score,
      streak: _maxStreak,
    );
    if (mounted) {
      setState(() {
        _highScore = res.highScore;
        _isNewHighScore = res.isNewHighScore;
      });
    }
  }

  void _restart() {
    setState(() {
      _altitude = 0;
      _displayAlt = 0;
      _fuel = 100;
      _idleTime = 0;
      _score = 0;
      _streak = 0;
      _maxStreak = 0;
      _correctCount = 0;
      _isGameOver = false;
      _isNewHighScore = false;
      _layerBanner = null;
      _mistakes.clear();
      _sessionReviewItems.clear();
      _deck.clear();
      _nextQuestion();
    });
  }

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
      _answer(idx);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _handleExit() async {
    final wasRunning = _running;
    _running = false;
    final shouldPop = await showExitConfirmationDialog(context);
    if (shouldPop && mounted) {
      Navigator.of(context).pop();
    } else if (wasRunning && mounted && !_isGameOver) {
      _lastElapsed = Duration.zero;
      _running = true;
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
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final skyH =
                            (constraints.maxHeight * 0.4).clamp(170.0, 330.0);
                        return SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                          child: Column(
                            children: [
                              SizedBox(height: skyH, child: _buildSky()),
                              const SizedBox(height: 12),
                              _buildFuelBar(isDark),
                              const SizedBox(height: 12),
                              _buildQuestionCard(isDark),
                              const SizedBox(height: 12),
                              _buildOptions(isDark),
                            ],
                          ),
                        );
                      },
                    ),
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
        title: 'Phrasal Rocket',
        leadingIcon: const Icon(FontAwesomeIcons.rocket, color: _accent, size: 18),
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.bold,
          fontSize: 20,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
    );
  }

  Color _skyColor(double alt) {
    final i = _layerIndexFor(alt);
    if (i >= _layers.length - 1) return _layers.last.color;
    final a = _layers[i], b = _layers[i + 1];
    final t = ((alt - a.start) / (b.start - a.start)).clamp(0.0, 1.0);
    return Color.lerp(a.color, b.color, t)!;
  }

  Widget _buildSky() {
    final layerIdx = _layerIndexFor(_displayAlt);
    final next = layerIdx < _layers.length - 1 ? _layers[layerIdx + 1] : null;
    final bool boosting = (_altitude - _displayAlt) > 0.4;
    final bool lowFuel = _fuel < 25;

    final double shakeDx =
        _shakeTime > 0 ? sin(_shakeTime * 70) * 9 * (_shakeTime / 0.45) : 0;
    final double flicker = (sin(_flameTime * 40) + 1) / 2;
    final double flameH = (boosting ? 34 : 16) + flicker * (boosting ? 14 : 6);
    final double bob = sin(_flameTime * 2.4) * 3;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _SkyPainter(
                altitude: _displayAlt,
                scroll: _displayAlt * 18 + _idleTime * 30,
                background: _skyColor(_displayAlt),
              ),
            ),
          ),

          // Rocket + flame
          Align(
            alignment: const Alignment(0, 0.15),
            child: Transform.translate(
              offset: Offset(shakeDx, bob),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.rotate(
                    angle: -pi / 4,
                    child: const Icon(FontAwesomeIcons.rocket,
                        size: 54, color: Color(0xFFF8FAFC)),
                  ),
                  const SizedBox(height: 2),
                  if (_running && !_isGameOver && _fuel > 0)
                    Container(
                      width: 14,
                      height: flameH,
                      decoration: BoxDecoration(
                        color: lowFuel && flicker > 0.5
                            ? _red
                            : const Color(0xFFF97316),
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(14),
                          top: Radius.circular(4),
                        ),
                      ),
                      alignment: Alignment.topCenter,
                      child: Container(
                        width: 6,
                        height: flameH * 0.55,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDE047),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // HUD
          Positioned(
            left: 12,
            top: 12,
            child: _hudChip(
              icon: Icons.height_rounded,
              text: '${_displayAlt.toStringAsFixed(1)} km',
            ),
          ),
          Positioned(
            right: 12,
            top: 12,
            child: _hudChip(text: _layers[layerIdx].name),
          ),
          Positioned(
            left: 12,
            bottom: 12,
            child: _hudChip(
              icon: Icons.star_rounded,
              text: '$_score',
            ),
          ),
          if (_streak >= 3)
            Positioned(
              right: 12,
              bottom: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF97316),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '🔥 ${_streak}x',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            )
          else if (next != null)
            Positioned(
              right: 12,
              bottom: 12,
              child: _hudChip(
                text:
                    '${next.name} ▲ ${(next.start - _displayAlt).clamp(0, 9999).toStringAsFixed(0)} km',
              ),
            ),

          // Layer reached banner
          if (_layerBanner != null)
            Align(
              alignment: const Alignment(0, -0.55),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFBBF24), width: 1.5),
                ),
                child: Text(
                  '🚀 $_layerBanner',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFFFBBF24),
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _hudChip({IconData? icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: GoogleFonts.robotoMono(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFuelBar(bool isDark) {
    final pct = (_fuel / 100).clamp(0.0, 1.0);
    final Color c = pct > 0.5
        ? _green
        : pct > 0.25
            ? const Color(0xFFF59E0B)
            : _red;

    return Row(
      children: [
        Icon(FontAwesomeIcons.gasPump, size: 16, color: c),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 10,
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation(c),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 44,
          child: Text(
            '${_fuel.round()}%',
            textAlign: TextAlign.right,
            style: GoogleFonts.robotoMono(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: c,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionCard(bool isDark) {
    final q = _question;
    if (q == null) return const SizedBox.shrink();

    final parts = q.sentence.split('___');
    final bool revealed = _selected != null;
    final bool wasCorrect = revealed && _options[_selected!] == q.answer;
    final Color blankColor = !revealed
        ? _accent
        : wasCorrect
            ? _green
            : _red;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161E31) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        children: [
          Text.rich(
            TextSpan(
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: textColor,
                height: 1.5,
              ),
              children: [
                TextSpan(text: parts.first),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    decoration: BoxDecoration(
                      color: blankColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: blankColor, width: 2),
                    ),
                    child: Text(
                      revealed ? q.answer.toUpperCase() : '  ?  ',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: blankColor,
                      ),
                    ),
                  ),
                ),
                if (parts.length > 1) TextSpan(text: parts[1]),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: revealed ? 1 : 0,
            child: Text(
              q.meaning,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptions(bool isDark) {
    Widget row(int a, int b) => Row(
          children: [
            Expanded(child: _optionButton(a, isDark)),
            const SizedBox(width: 12),
            Expanded(child: _optionButton(b, isDark)),
          ],
        );
    if (_options.length < 4) return const SizedBox.shrink();
    return Column(
      children: [
        row(0, 1),
        const SizedBox(height: 12),
        row(2, 3),
      ],
    );
  }

  Widget _optionButton(int i, bool isDark) {
    final q = _question!;
    final opt = _options[i];
    final bool revealed = _selected != null;
    final bool isAnswer = opt == q.answer;
    final bool isSelected = _selected == i;

    Color fill = isDark ? const Color(0xFF1A233A) : Colors.white;
    Color border = isDark
        ? const Color(0xFF2D3B5E)
        : Colors.black.withValues(alpha: 0.12);
    Color lipColor = isDark ? const Color(0xFF0D1322) : const Color(0xFFCBD5E1);
    Color text = isDark ? Colors.white : const Color(0xFF0F172A);

    if (revealed && isAnswer) {
      fill = _green;
      border = const Color(0xFF34D399);
      lipColor = const Color(0xFF047857);
      text = Colors.white;
    } else if (revealed && isSelected) {
      fill = _red;
      border = const Color(0xFFF87171);
      lipColor = const Color(0xFFB91C1C);
      text = Colors.white;
    }

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: revealed && !isAnswer && !isSelected ? 0.45 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _answer(i),
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 62,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: lipColor,
                  offset: const Offset(0, 4),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 10,
                  top: 8,
                  child: Text(
                    '${i + 1}',
                    style: GoogleFonts.robotoMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: text.withValues(alpha: 0.45),
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    opt.toUpperCase(),
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: text,
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

  Widget _buildGameOverOverlay(bool isDark) {
    final layer = _layers[_layerIndexFor(_altitude)];
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
                border:
                    Border.all(color: _accent.withValues(alpha: 0.5), width: 2),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(FontAwesomeIcons.gasPump,
                          color: _accent, size: 36),
                    ),
                    const SizedBox(height: 14),
                    if (_isNewHighScore) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF59E0B)
                                  .withValues(alpha: 0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.emoji_events_rounded,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'YENİ EN YÜKSEK SKOR!',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    Text(
                      'YAKIT BİTTİ!',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ulaşılan katman: ${layer.name}',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 8),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1A233A)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _overStat('ALTITUDE',
                              '${_altitude.toStringAsFixed(0)} km', _accent),
                          _overStat('SCORE', '$_score', Colors.amber),
                          _overStat(
                              'BEST', '$_highScore', const Color(0xFFFBBF24)),
                          _overStat('CORRECT', '$_correctCount', _green),
                          _overStat('STREAK', '$_maxStreak',
                              const Color(0xFFF97316)),
                        ],
                      ),
                    ),
                    if (_sessionReviewItems.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      GameReviewAccordion(
                        items: _sessionReviewItems,
                        accentColor: _accent,
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
                              backgroundColor: _accent,
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
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Flat sky: solid background (changes with altitude), drifting clouds at
/// low altitude, stars higher up, launch pad at start and the Moon near 400 km.
class _SkyPainter extends CustomPainter {
  final double altitude;
  final double scroll;
  final Color background;

  _SkyPainter({
    required this.altitude,
    required this.scroll,
    required this.background,
  });

  static final List<Offset> _stars = _seeded(70, 7);
  static final List<Offset> _clouds = _seeded(7, 3);

  static List<Offset> _seeded(int n, int seed) {
    final r = Random(seed);
    return List.generate(n, (_) => Offset(r.nextDouble(), r.nextDouble()));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(Offset.zero & size, Paint()..color = background);

    // Stars
    final starAlpha = ((altitude - 12) / 50).clamp(0.0, 1.0);
    if (starAlpha > 0) {
      final p = Paint()..color = Colors.white.withValues(alpha: starAlpha);
      for (int i = 0; i < _stars.length; i++) {
        final s = _stars[i];
        final y = (s.dy * h + scroll * 0.25) % h;
        canvas.drawCircle(Offset(s.dx * w, y), i % 3 == 0 ? 1.6 : 1.0, p);
      }
    }

    // Clouds
    final cloudAlpha = (1 - altitude / 22).clamp(0.0, 1.0);
    if (cloudAlpha > 0) {
      final p = Paint()..color = Colors.white.withValues(alpha: 0.85 * cloudAlpha);
      for (int i = 0; i < _clouds.length; i++) {
        final c = _clouds[i];
        final y = (c.dy * (h + 80) + scroll) % (h + 80) - 40;
        final x = c.dx * w;
        final s = 14.0 + (i % 3) * 6;
        canvas.drawCircle(Offset(x, y), s, p);
        canvas.drawCircle(Offset(x + s, y + 3), s * 0.8, p);
        canvas.drawCircle(Offset(x - s, y + 4), s * 0.7, p);
      }
    }

    // Ground & launch pad (scrolls away right after liftoff)
    if (altitude < 6) {
      final groundTop = h * 0.84 + altitude * 40;
      canvas.drawRect(
        Rect.fromLTRB(0, groundTop, w, h),
        Paint()..color = const Color(0xFF16A34A),
      );
      canvas.drawRect(
        Rect.fromCenter(
            center: Offset(w / 2, groundTop), width: 90, height: 8),
        Paint()..color = const Color(0xFF475569),
      );
    }

    // Moon
    if (altitude > 300) {
      final t = ((altitude - 300) / 120).clamp(0.0, 1.0);
      final center = Offset(w * 0.8, h * 0.24);
      final r = 18 + t * 34;
      canvas.drawCircle(center, r, Paint()..color = const Color(0xFFE5E7EB));
      final crater = Paint()..color = const Color(0xFFCBD5E1);
      canvas.drawCircle(center + Offset(-r * 0.3, -r * 0.2), r * 0.2, crater);
      canvas.drawCircle(center + Offset(r * 0.35, r * 0.25), r * 0.15, crater);
      canvas.drawCircle(center + Offset(-r * 0.1, r * 0.45), r * 0.1, crater);
    }
  }

  @override
  bool shouldRepaint(covariant _SkyPainter old) =>
      old.altitude != altitude ||
      old.scroll != scroll ||
      old.background != background;
}
