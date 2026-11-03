import 'dart:async';
import 'package:flutter/material.dart';

/// An animated game AppBar title widget that:
/// - Keeps the leading game icon stationary on the left.
/// - If the title fits completely within available width, renders statically without scrolling.
/// - If the title overflows (especially on mobile), smoothly scrolls to the left,
///   pauses briefly, and loops back to the beginning.
class MarqueeTitle extends StatefulWidget {
  final String title;
  final TextStyle style;
  final Widget? leadingIcon;
  final double pauseDurationMs;
  final double scrollSpeedPxPerSec;
  final double endSpacing;

  const MarqueeTitle({
    super.key,
    required this.title,
    required this.style,
    this.leadingIcon,
    this.pauseDurationMs = 1200,
    this.scrollSpeedPxPerSec = 32.0,
    this.endSpacing = 36.0,
  });

  @override
  State<MarqueeTitle> createState() => _MarqueeTitleState();
}

class _MarqueeTitleState extends State<MarqueeTitle> {
  late final ScrollController _scrollController;
  bool _isLooping = false;
  int _loopGeneration = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startLoopIfNeeded());
  }

  @override
  void didUpdateWidget(covariant MarqueeTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool titleChanged = oldWidget.title != widget.title;
    final bool metricsChanged =
        oldWidget.style.fontSize != widget.style.fontSize ||
        oldWidget.style.fontWeight != widget.style.fontWeight ||
        oldWidget.style.fontFamily != widget.style.fontFamily;
    if (titleChanged || metricsChanged) {
      _stopLoop();
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0.0);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _startLoopIfNeeded());
    }
  }

  @override
  void dispose() {
    _stopLoop();
    _scrollController.dispose();
    super.dispose();
  }

  void _stopLoop() {
    _loopGeneration++;
    _isLooping = false;
  }

  void _startLoopIfNeeded() {
    if (!mounted || _isLooping) return;
    if (!_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isLooping) _startLoopIfNeeded();
      });
      return;
    }
    if (_scrollController.position.maxScrollExtent > 0) {
      _runLoop();
    } else {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted &&
            !_isLooping &&
            _scrollController.hasClients &&
            _scrollController.position.maxScrollExtent > 0) {
          _runLoop();
        }
      });
    }
  }

  Future<void> _runLoop() async {
    if (!mounted || !_scrollController.hasClients) return;
    final int myGeneration = ++_loopGeneration;
    _isLooping = true;

    while (mounted &&
        _scrollController.hasClients &&
        _isLooping &&
        _loopGeneration == myGeneration) {
      // 1. Başlangıçta kısa bekleme (ilk kelimelerin rahat okunabilmesi için)
      await Future.delayed(
          Duration(milliseconds: widget.pauseDurationMs.toInt()));
      if (!mounted ||
          !_scrollController.hasClients ||
          !_isLooping ||
          _loopGeneration != myGeneration) {
        break;
      }

      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll <= 0) {
        break;
      }

      // 2. Sona doğru akıcı bir şekilde kay
      final forwardDistance = (maxScroll - _scrollController.offset).abs();
      final forwardDurationMs =
          ((forwardDistance / widget.scrollSpeedPxPerSec) * 1000)
              .toInt()
              .clamp(300, 12000);
      try {
        await _scrollController.animateTo(
          maxScroll,
          duration: Duration(milliseconds: forwardDurationMs),
          curve: Curves.easeInOut,
        );
      } catch (_) {
        break;
      }
      if (!mounted ||
          !_scrollController.hasClients ||
          !_isLooping ||
          _loopGeneration != myGeneration) {
        break;
      }

      // 3. Sona ulaşıldığında kısa bir bekleme
      await Future.delayed(
          Duration(milliseconds: widget.pauseDurationMs.toInt()));
      if (!mounted ||
          !_scrollController.hasClients ||
          !_isLooping ||
          _loopGeneration != myGeneration) {
        break;
      }

      // 4. Aniden başa atlamak (resetlemek) yerine tersine doğru akıcı şekilde geri kay
      final returnDistance = _scrollController.offset;
      final returnDurationMs =
          ((returnDistance / widget.scrollSpeedPxPerSec) * 1000)
              .toInt()
              .clamp(300, 12000);
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

    if (_loopGeneration == myGeneration) {
      _isLooping = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // AppBar başlıkları fontSize vermeden DefaultTextStyle'dan (≈22px) miras alır.
    // Ölçümü gerçek render stiliyle yapmazsak metin 14px sanılıp yanlışlıkla kırpılıyor.
    final TextStyle effectiveStyle =
        DefaultTextStyle.of(context).style.merge(widget.style);
    final TextScaler textScaler = MediaQuery.textScalerOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxAvailableWidth = constraints.maxWidth;
        final double effectiveMaxWidth =
            maxAvailableWidth.isFinite ? maxAvailableWidth : 200.0;
        final double iconWidth = widget.leadingIcon != null ? 30.0 : 0.0;
        final double textMaxAllowedWidth =
            (effectiveMaxWidth - iconWidth).clamp(0.0, double.infinity);

        final textPainter = TextPainter(
          text: TextSpan(text: widget.title, style: effectiveStyle),
          maxLines: 1,
          textScaler: textScaler,
          textDirection: Directionality.of(context),
        )..layout();
        // Küçük yuvarlama farklarının ellipsis'e yol açmaması için pay bırak.
        final double measuredWidth = textPainter.width.ceilToDouble() + 2;
        textPainter.dispose();

        final bool overflows = measuredWidth > textMaxAllowedWidth;

        if (overflows) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _startLoopIfNeeded();
          });
        }

        return ClipRect(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (widget.leadingIcon != null) ...[
                widget.leadingIcon!,
                const SizedBox(width: 6),
              ],
              SizedBox(
                width: overflows ? textMaxAllowedWidth : measuredWidth,
                child: overflows
                    ? SingleChildScrollView(
                        controller: _scrollController,
                        scrollDirection: Axis.horizontal,
                        physics: const NeverScrollableScrollPhysics(),
                        child: Padding(
                          padding: EdgeInsets.only(right: widget.endSpacing),
                          child: Text(
                            widget.title,
                            style: effectiveStyle,
                            maxLines: 1,
                            softWrap: false,
                          ),
                        ),
                      )
                    : Text(
                        widget.title,
                        style: effectiveStyle,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.visible,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
