import 'dart:async';
import 'package:flutter/material.dart';

/// An auto-scrolling description text widget that:
/// - Fits normally and stays centered if text doesn't overflow.
/// - If text overflows vertically (especially on mobile devices),
///   it smoothly scrolls down to the end, pauses briefly, and scrolls back up to the top,
///   looping continuously (ping-pong auto-scroll), just like MarqueeTitle.
/// - Automatically resets to top when card becomes inactive in a PageView.
/// - Temporarily pauses while user is manually dragging/touching.
class AutoScrollDescription extends StatefulWidget {
  final String text;
  final TextStyle style;
  final TextAlign textAlign;
  final PageController? pageController;
  final int? pageIndex;
  final double pauseDurationMs;
  final double scrollSpeedPxPerSec;

  const AutoScrollDescription({
    super.key,
    required this.text,
    required this.style,
    this.textAlign = TextAlign.center,
    this.pageController,
    this.pageIndex,
    this.pauseDurationMs = 1500,
    this.scrollSpeedPxPerSec = 22.0,
  });

  @override
  State<AutoScrollDescription> createState() => _AutoScrollDescriptionState();
}

class _AutoScrollDescriptionState extends State<AutoScrollDescription> {
  late final ScrollController _scrollController;
  bool _isLooping = false;
  bool _isUserInteracting = false;
  bool _isActive = true;
  Timer? _resumeTimer;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _checkInitialActive();
    widget.pageController?.addListener(_onPageScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startLoopIfNeeded());
  }

  void _checkInitialActive() {
    if (widget.pageController != null && widget.pageIndex != null) {
      if (widget.pageController!.hasClients &&
          widget.pageController!.position.haveDimensions) {
        final page = widget.pageController!.page ??
            widget.pageController!.initialPage.toDouble();
        _isActive = (page.round() == widget.pageIndex);
      } else {
        _isActive = (widget.pageController!.initialPage == widget.pageIndex);
      }
    } else {
      _isActive = true;
    }
  }

  void _onPageScroll() {
    if (widget.pageController == null || widget.pageIndex == null) return;
    final page = widget.pageController!.page;
    if (page == null) return;

    final isNowActive = (page - widget.pageIndex!).abs() < 0.35;
    if (isNowActive != _isActive) {
      if (!mounted) return;
      setState(() {
        _isActive = isNowActive;
      });
      if (_isActive) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _startLoopIfNeeded());
      } else {
        _stopLoop();
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0.0);
        }
      }
    }
  }

  @override
  void didUpdateWidget(covariant AutoScrollDescription oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageController != widget.pageController) {
      oldWidget.pageController?.removeListener(_onPageScroll);
      widget.pageController?.addListener(_onPageScroll);
      _checkInitialActive();
    }
    if (oldWidget.text != widget.text || oldWidget.pageIndex != widget.pageIndex) {
      _stopLoop();
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0.0);
      }
      _checkInitialActive();
      WidgetsBinding.instance.addPostFrameCallback((_) => _startLoopIfNeeded());
    }
  }

  @override
  void dispose() {
    _resumeTimer?.cancel();
    widget.pageController?.removeListener(_onPageScroll);
    _stopLoop();
    _scrollController.dispose();
    super.dispose();
  }

  void _stopLoop() {
    _isLooping = false;
  }

  void _startLoopIfNeeded() {
    if (!mounted ||
        !_scrollController.hasClients ||
        _isLooping ||
        !_isActive ||
        _isUserInteracting) {
      return;
    }
    if (!_scrollController.position.haveDimensions) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startLoopIfNeeded());
      return;
    }
    if (_scrollController.position.maxScrollExtent > 2.0) {
      _runLoop();
    }
  }

  Future<void> _runLoop() async {
    if (!mounted || !_scrollController.hasClients || _isLooping) return;
    _isLooping = true;

    while (mounted &&
        _scrollController.hasClients &&
        _isLooping &&
        _isActive &&
        !_isUserInteracting) {
      // 1. Üst kısımda bekleme (okuyucunun başlangıcı rahatça okuyabilmesi için)
      await Future.delayed(
        Duration(milliseconds: widget.pauseDurationMs.toInt()),
      );
      if (!mounted ||
          !_scrollController.hasClients ||
          !_isLooping ||
          !_isActive ||
          _isUserInteracting) {
        break;
      }

      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll <= 2.0) break;

      // 2. Aşağıya doğru akıcı şekilde kay
      final forwardDistance = (maxScroll - _scrollController.offset).abs();
      if (forwardDistance > 1.0) {
        final forwardDurationMs =
            ((forwardDistance / widget.scrollSpeedPxPerSec) * 1000)
                .toInt()
                .clamp(400, 15000);
        try {
          await _scrollController.animateTo(
            maxScroll,
            duration: Duration(milliseconds: forwardDurationMs),
            curve: Curves.easeInOut,
          );
        } catch (_) {
          break;
        }
      }
      if (!mounted ||
          !_scrollController.hasClients ||
          !_isLooping ||
          !_isActive ||
          _isUserInteracting) {
        break;
      }

      // 3. Alt kısımda bekleme (son cümleyi okuyabilmesi için)
      await Future.delayed(
        Duration(milliseconds: widget.pauseDurationMs.toInt()),
      );
      if (!mounted ||
          !_scrollController.hasClients ||
          !_isLooping ||
          !_isActive ||
          _isUserInteracting) {
        break;
      }

      // 4. Yukarıya doğru akıcı şekilde geri kay
      final returnDistance = _scrollController.offset;
      if (returnDistance > 1.0) {
        final returnDurationMs =
            ((returnDistance / widget.scrollSpeedPxPerSec) * 1000)
                .toInt()
                .clamp(400, 15000);
        try {
          await _scrollController.animateTo(
            0.0,
            duration: Duration(milliseconds: returnDurationMs),
            curve: Curves.easeInOut,
          );
        } catch (_) {
          break;
        }
      }
    }

    _isLooping = false;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _startLoopIfNeeded());

        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollStartNotification) {
              if (notification.dragDetails != null) {
                _isUserInteracting = true;
                _resumeTimer?.cancel();
                _stopLoop();
              }
            } else if (notification is ScrollEndNotification) {
              if (_isUserInteracting) {
                _resumeTimer?.cancel();
                _resumeTimer = Timer(const Duration(milliseconds: 2000), () {
                  if (mounted) {
                    _isUserInteracting = false;
                    _startLoopIfNeeded();
                  }
                });
              }
            }
            return false;
          },
          child: ScrollConfiguration(
            behavior:
                ScrollConfiguration.of(context).copyWith(scrollbars: false),
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight.isFinite
                      ? constraints.maxHeight
                      : 0.0,
                  minWidth: constraints.maxWidth.isFinite
                      ? constraints.maxWidth
                      : 0.0,
                ),
                child: Align(
                  alignment: Alignment.center,
                  child: Text(
                    widget.text,
                    textAlign: widget.textAlign,
                    style: widget.style,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
