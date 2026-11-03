import 'dart:ui' show lerpDouble;
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'idiom_runner_game.dart';

class PlayerComponent extends SpriteComponent
    with HasGameReference<IdiomRunnerGame>, CollisionCallbacks {
  int currentLane = 1; // 0 = Left, 1 = Center, 2 = Right
  double targetX = 0;
  double speedMultiplier = 18.0; // Snappy lane transition speed

  // Aspect ratio is 4:3 (horizontal). When rotated -pi/2, it displays vertically (84 wide, 112 high)
  PlayerComponent() : super(size: Vector2(112, 84), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // Load custom car sprite
    sprite = await game.loadSprite('car.png');

    // Rotate -90 degrees (facing right -> facing up)
    angle = -1.57079632679; // -pi / 2

    // Set initial position
    final laneWidth = game.size.x / 3;
    targetX = (currentLane * laneWidth) + (laneWidth / 2);
    position = Vector2(targetX, game.size.y - 160);

    // Add rectangle hitbox for collision detection (will rotate automatically)
    add(RectangleHitbox(
      size: size * 0.9,
      position: size * 0.05,
    ));
  }

  /// Change lane to the left
  void moveLeft() {
    if (currentLane > 0) {
      currentLane--;
      _updateTargetX();
    }
  }

  /// Change lane to the right
  void moveRight() {
    if (currentLane < 2) {
      currentLane++;
      _updateTargetX();
    }
  }

  void _updateTargetX() {
    final laneWidth = game.size.x / 3;
    targetX = (currentLane * laneWidth) + (laneWidth / 2);
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Ensure the Y position is stable near the bottom of the screen
    position.y = game.size.y - 160;

    // Snappily interpolate X position towards targetX
    position.x = lerpDouble(position.x, targetX, dt * speedMultiplier) ?? targetX;
  }
}
