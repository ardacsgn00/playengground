import 'package:flutter/material.dart';

class AnimatedHoverWrapper extends StatefulWidget {
  final Widget child;
  final double scaleAmount;
  final Duration duration;

  const AnimatedHoverWrapper({
    super.key,
    required this.child,
    this.scaleAmount = 1.05,
    this.duration = const Duration(milliseconds: 200),
  });

  @override
  State<AnimatedHoverWrapper> createState() => _AnimatedHoverWrapperState();
}

class _AnimatedHoverWrapperState extends State<AnimatedHoverWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleAmount,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(covariant AnimatedHoverWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scaleAmount != widget.scaleAmount) {
      _scaleAnimation = Tween<double>(
        begin: 1.0,
        end: widget.scaleAmount,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onEnter() {
    _controller.forward();
  }

  void _onExit() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _onEnter(),
      onExit: (_) => _onExit(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}
