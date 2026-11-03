import 'dart:async';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../../services/audio_service.dart';
import 'idiom_model.dart';
import 'player_component.dart';
import 'gate_component.dart';
import 'parallax_background.dart';

class IdiomRunnerGame extends FlameGame
    with HasCollisionDetection, KeyboardEvents {
  // Game states
  int score = 0;
  int lives = 3;
  int streak = 0;
  double gameSpeed =
      85.0; // Speed of incoming gates in pixels/sec (calibrated for comfortable reaction)
  bool isGameOver = false;
  bool isBoosting = false;

  double get effectiveSpeed {
    if (isGameOver) return 0.0;
    return isBoosting ? (gameSpeed + 90.0) : gameSpeed;
  }

  void setBoosting(bool value) {
    if (isGameOver) {
      isBoosting = false;
      return;
    }
    isBoosting = value;
  }

  IdiomModel? currentIdiom;
  late PlayerComponent player;

  // Shuffled idiom pool management
  List<IdiomModel> _shuffledPool = [];
  int _currentIdiomIndex = 0;

  // Callbacks to communicate state updates to the Flutter Overlay UI
  Function(int score, int lives, int streak, IdiomModel currentIdiom)?
  onStatsUpdated;
  VoidCallback? onGameOverTriggered;
  VoidCallback? onCorrectAnswerEffect;
  VoidCallback? onWrongAnswerEffect;

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // 1. Add scrolling parallax background component
    add(ParallaxBackground());

    // 2. Add player component
    player = PlayerComponent();
    add(player);

    // 3. Initialize state and spawn first gate
    resetGame();
  }

  /// Reset all game state variables and begin running
  void resetGame() {
    score = 0;
    lives = 3;
    streak = 0;
    gameSpeed = 85.0;
    isBoosting = false;
    isGameOver = false;

    // Clear any existing gates in the component tree
    children.whereType<GateGroupComponent>().forEach(
      (gate) => gate.removeFromParent(),
    );

    // Reset player to center lane
    player.currentLane = 1;
    final laneWidth = size.x / 3;
    player.position.x = (player.currentLane * laneWidth) + (laneWidth / 2);

    // Refresh and shuffle pool
    _shuffledPool = List<IdiomModel>.from(basicIdiomPool)..shuffle();
    _currentIdiomIndex = 0;

    spawnGates();
  }

  /// Choose a new idiom and spawn the gate group
  void spawnGates() {
    if (isGameOver) return;

    // If pool exhausted, reshuffle
    if (_shuffledPool.isEmpty || _currentIdiomIndex >= _shuffledPool.length) {
      _shuffledPool = List<IdiomModel>.from(basicIdiomPool)..shuffle();
      _currentIdiomIndex = 0;
    }

    currentIdiom = _shuffledPool[_currentIdiomIndex++];
    final words = currentIdiom!.getShuffledOptions();

    // Spawn gate group off-screen (above viewport)
    final gateGroup = GateGroupComponent(
      words: words,
      correctAnswer: currentIdiom!.correctAnswer,
      yPosition: -120.0,
    );
    add(gateGroup);

    // Notify Flutter UI
    onStatsUpdated?.call(score, lives, streak, currentIdiom!);
  }

  /// Action when player collides with a word box
  void onWordSelected(String selectedWord, bool isCorrect) {
    if (isGameOver) return;

    if (isCorrect) {
      score += 10;
      streak++;
      AudioService.playCorrect();
      onCorrectAnswerEffect?.call();

      // Make the game gradually speed up and get more challenging
      gameSpeed = (85.0 + score * 0.55).clamp(85.0, 165.0);
    } else {
      lives--;
      streak = 0;
      AudioService.playIncorrect();
      onWrongAnswerEffect?.call();

      if (lives <= 0) {
        triggerGameOver();
        return;
      }
    }

    spawnGates();
  }

  /// Action when player misses a gate entirely (goes off-screen without hitting)
  void onWordMissed() {
    if (isGameOver) return;

    lives--;
    streak = 0;
    AudioService.playIncorrect();
    onWrongAnswerEffect?.call();

    if (lives <= 0) {
      triggerGameOver();
      return;
    }

    spawnGates();
  }

  /// Triggers game over sequence
  void triggerGameOver() {
    isGameOver = true;
    gameSpeed = 0; // Freeze movement
    isBoosting = false;

    // Play failure tune
    AudioService.playFailure();

    // Trigger overlay modal in Flutter
    onGameOverTriggered?.call();
  }

  /// Implement key event listener for keyboard controls (Desktop / Web / ChromeOS)
  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    if (isGameOver) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.space) {
      if (event is KeyDownEvent) {
        setBoosting(true);
      } else if (event is KeyUpEvent) {
        setBoosting(false);
      }
      return KeyEventResult.handled;
    }

    final isKeyDown = event is KeyDownEvent;

    // Check if key was pressed down
    if (isKeyDown) {
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
          event.logicalKey == LogicalKeyboardKey.keyA) {
        player.moveLeft();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
          event.logicalKey == LogicalKeyboardKey.keyD) {
        player.moveRight();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }
}
