import 'package:flame/components.dart';
import 'package:flame/parallax.dart';
import 'package:flutter/material.dart';
import 'idiom_runner_game.dart';

class ParallaxBackground extends ParallaxComponent<IdiomRunnerGame> {
  double _offsetY = 0;

  @override
  Future<void> onLoad() async {
    // Load background image layers
    parallax = await game.loadParallax(
      [
        ParallaxImageData('bg_space.png'),
        ParallaxImageData('bg_city.png'),
        ParallaxImageData('road.jpeg'),
      ],
      // Velocity is adjusted dynamically in update
      baseVelocity: Vector2(0, -30),
      velocityMultiplierDelta: Vector2(0, 1.4),
      repeat: ImageRepeat.repeat,
      alignment: Alignment.center,
      fill: LayerFill.height,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Adjust background scroll speed to match current game speed
    // Scale it down (e.g. 10%) so background movement is smooth and not distracting
    if (parallax != null) {
      final backgroundVelocityY = game.effectiveSpeed * 0.12;
      parallax!.baseVelocity = Vector2(0, -backgroundVelocityY);
    }

    // Scroll the road lines at the actual game speed
    _offsetY = (_offsetY + game.effectiveSpeed * dt) % 60.0;
  }

  @override
  void render(Canvas canvas) {
    // Render the parallax background layers (city & space)
    super.render(canvas);

    // 1. Draw solid dark asphalt highway pavement overlay
    final asphaltPaint = Paint()
      ..color = const Color(0xFF1B1B22).withValues(alpha: 0.85) // Dark asphalt with transparency to let background show through slightly
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, game.size.x, game.size.y),
      asphaltPaint,
    );

    // Configuration for lanes
    final laneWidth = game.size.x / 3;

    // 2. Draw solid yellow shoulders on the outer left and right edges
    final shoulderPaint = Paint()
      ..color = const Color(0xFFF59E0B) // Golden highway yellow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawLine(const Offset(10, 0), Offset(10, game.size.y), shoulderPaint);
    canvas.drawLine(Offset(game.size.x - 10, 0), Offset(game.size.x - 10, game.size.y), shoulderPaint);

    // 3. Draw animating dashed white lane lines
    final dashLength = 32.0;
    final gapLength = 22.0;
    final totalLength = dashLength + gapLength;

    final dividerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45) // Soft highway white dashes
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    // Draw white dashes between Left/Center and Center/Right lanes
    for (int i = 1; i < 3; i++) {
      final xPos = i * laneWidth;
      double currentY = -totalLength + _offsetY;

      while (currentY < game.size.y) {
        canvas.drawLine(
          Offset(xPos, currentY),
          Offset(xPos, (currentY + dashLength).clamp(0, game.size.y)),
          dividerPaint,
        );
        currentY += totalLength;
      }
    }
  }
}
