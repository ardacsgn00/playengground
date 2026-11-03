import 'dart:ui';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart' show Colors;
import 'player_component.dart';
import 'idiom_runner_game.dart';

class WordBoxComponent extends PositionComponent
    with HasGameReference<IdiomRunnerGame>, CollisionCallbacks {
  final String word;
  final bool isCorrect;
  final int lane;

  WordBoxComponent({
    required this.word,
    required this.isCorrect,
    required this.lane,
    required Vector2 position,
    required Vector2 size,
  }) : super(position: position, size: size, anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // Attach collision hitbox
    add(RectangleHitbox(
      size: size,
    ));
  }

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);

    if (other is PlayerComponent) {
      final parentGroup = parent as GateGroupComponent?;
      parentGroup?.onChildCollision(this);
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Simple glassmorphic semi-transparent dark background
    final bgPaint = Paint()
      ..color = const Color(0xFF0F172A).withValues(alpha: 0.35) // transparent dark overlay
      ..style = PaintingStyle.fill;

    // Simple borders using brand pinkish-red color
    final borderPaint = Paint()
      ..color = const Color(0xFFFF6B6B) // Brand color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Soft brand color glow
    final shadowPaint = Paint()
      ..color = const Color(0xFFFF6B6B).withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    // Draw shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-3, -3, size.x + 6, size.y + 6),
        const Radius.circular(12),
      ),
      shadowPaint,
    );

    // Draw background
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.x, size.y),
        const Radius.circular(12),
      ),
      bgPaint,
    );

    // Draw border
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.x, size.y),
        const Radius.circular(12),
      ),
      borderPaint,
    );

    // Render word text centered with brand color shadow
    final textPaint = TextPaint(
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
        fontFamily: 'Outfit',
        shadows: [
          Shadow(
            color: Color(0xFFFF6B6B),
            offset: Offset(0, 0),
            blurRadius: 3,
          ),
        ],
      ),
    );

    textPaint.render(
      canvas,
      word,
      Vector2(size.x / 2, size.y / 2),
      anchor: Anchor.center,
    );
  }
}

class GateGroupComponent extends PositionComponent with HasGameReference<IdiomRunnerGame> {
  final List<String> words;
  final String correctAnswer;
  bool collisionProcessed = false;

  GateGroupComponent({
    required this.words,
    required this.correctAnswer,
    required double yPosition,
  }) : super(position: Vector2(0, yPosition));

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // Spacing configuration
    final laneWidth = game.size.x / 3;
    final boxWidth = laneWidth * 0.85; // 85% of the lane width
    final boxHeight = 55.0;

    // Add three option boxes, one in each lane
    for (int i = 0; i < 3; i++) {
      final word = words[i];
      final isCorrect = word == correctAnswer;
      final xPos = (i * laneWidth) + (laneWidth / 2);

      add(WordBoxComponent(
        word: word,
        isCorrect: isCorrect,
        lane: i,
        position: Vector2(xPos, 0),
        size: Vector2(boxWidth, boxHeight),
      ));
    }
  }

  void onChildCollision(WordBoxComponent collidedBox) {
    if (collisionProcessed) return;
    collisionProcessed = true;

    // Report choice result to the main game coordinator
    game.onWordSelected(collidedBox.word, collidedBox.isCorrect);

    // Instantly remove from the game loop to avoid double hits
    removeFromParent();
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Gates move downwards/towards player
    position.y += game.effectiveSpeed * dt;

    // If game speed is active and gate goes off screen
    if (position.y > game.size.y) {
      if (!collisionProcessed) {
        collisionProcessed = true;
        game.onWordMissed();
      }
      removeFromParent();
    }
  }
}
