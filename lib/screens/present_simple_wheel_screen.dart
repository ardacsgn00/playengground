import 'dart:math';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/present_simple_data.dart';
import '../widgets/exit_confirmation_dialog.dart';
import '../widgets/game_tutorial_popup.dart';
import '../widgets/marquee_title.dart';

class PresentSimpleWheelScreen extends StatefulWidget {
  const PresentSimpleWheelScreen({super.key});

  @override
  State<PresentSimpleWheelScreen> createState() =>
      _PresentSimpleWheelScreenState();
}

class _PresentSimpleWheelScreenState extends State<PresentSimpleWheelScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinController;
  late Animation<double> _spinAnimation;

  final Random _random = Random();

  // Aktif soru havuzu ve elenen sorular
  List<PSWheelItem> _activePool = [];
  final List<PSWheelItem> _eliminatedList = [];

  bool _isSpinning = false;
  double _currentAngle = 0.0;

  @override
  void initState() {
    super.initState();
    _resetPool();

    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await GameTutorialPopup.show(
        context,
        tutorialKey: 'ps_wheel_tutorial',
        title: 'Sentence Spin',
        icon: FontAwesomeIcons.arrowsSpin,
        color: const Color(0xFFF59E0B),
        tutorialTextTr:
            'Sentence Spin oyununda çarkı çevirerek Present Simple (Geniş Zaman) pratikleri yapın!\n\n'
            '• Ortadaki butona basarak çarkı çevirin ve gelen dilbilgisi görevini inceleyin.\n'
            '• Kendi cümlenizi kurduktan sonra "Cevabı Göster" butonuna dokunarak doğru yapıyı ve kural açıklamasını kontrol edin.\n'
            '• Öğrendiğiniz cümleleri "Havuzdan Ele" butonuyla eleyerek tüm cümle havuzunu tamamlamaya çalışın!',
        tutorialTextEn:
            'Spin the wheel! Solve the chosen Present Simple challenge on the board. Tap "Show Answer" to check grammar rules, and eliminate used sentences from the pool.',
        hideLanguageToggle: false,
      );
    });
  }

  void _resetPool() {
    setState(() {
      _eliminatedList.clear();
      _activePool = List.from(psWheelItems)..shuffle(_random);
      _currentAngle = 0.0;
    });
  }

  void _spinWheel() {
    if (_isSpinning || _activePool.isEmpty) return;

    setState(() {
      _isSpinning = true;
    });

    // Rastgele bir öğe seç
    final int selectedIndex = _random.nextInt(_activePool.length);
    final PSWheelItem selectedItem = _activePool[selectedIndex];

    // Çark dönüş açısı hesabı:
    final double extraSpins = (4 + _random.nextInt(3)) * 2 * pi;
    final double sweepAngle = (2 * pi) / _activePool.length;
    final double textAngle = selectedIndex * sweepAngle + sweepAngle / 2;

    // Add a random offset within the slice (up to 80% of the half-slice)
    final double randomOffset = (_random.nextDouble() - 0.5) * sweepAngle * 0.8;

    double targetAngleMod = (3 * pi / 2) - (textAngle + randomOffset);
    while (targetAngleMod < 0) {
      targetAngleMod += 2 * pi;
    }

    // Ensure we always spin forward
    final double baseAngle = _currentAngle - (_currentAngle % (2 * pi));
    double endAngle = baseAngle + targetAngleMod;
    if (endAngle <= _currentAngle) {
      endAngle += 2 * pi;
    }
    endAngle += extraSpins;

    _spinAnimation = Tween<double>(begin: _currentAngle, end: endAngle).animate(
      CurvedAnimation(parent: _spinController, curve: Curves.easeOutCubic),
    );

    _spinController.reset();
    _spinController.forward().whenComplete(() {
      setState(() {
        _currentAngle = endAngle % (2 * pi);
        _isSpinning = false;
      });
      _showResultDialog(selectedItem);
    });
  }

  void _eliminateCurrent(PSWheelItem item) {
    setState(() {
      _activePool.removeWhere((e) => e.id == item.id);
      _eliminatedList.add(item);
    });
  }

  void _showResultDialog(PSWheelItem item) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Dialog(
              backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Kategori Başlığı (Topic)
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFF59E0B,
                            ).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(
                                0xFFF59E0B,
                              ).withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            item.topic.shortLabel,
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFF59E0B),
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Görev Metni (Büyük ve Net Font)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF13111C)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(
                        item.prompt,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          height: 1.4,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Buton (Ele ve Devam Et)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _eliminateCurrent(item);
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.delete_sweep_rounded),
                        label: Text(
                          'Havuzdan Ele ve Devam Et',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 600;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await showExitConfirmationDialog(context);
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: MarqueeTitle(
            title: 'Sentence Spin',
            leadingIcon: const Icon(FontAwesomeIcons.dharmachakra, color: Color(0xFFF59E0B), size: 18),
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.transparent,
          actions: [
            IconButton(
              tooltip: 'Reset Pool',
              icon: const Icon(Icons.restart_alt_rounded),
              onPressed: _resetPool,
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  children: [
                    // Çark Alanı
                    GestureDetector(
                      onTap: _activePool.isEmpty ? _resetPool : _spinWheel,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Çark Dairesi
                          SizedBox(
                            width: isSmall ? screenWidth * 0.95 : 700,
                            height: isSmall ? screenWidth * 0.95 : 700,
                            child: AnimatedBuilder(
                              animation: _spinController,
                              builder: (context, child) {
                                final angle = _isSpinning
                                    ? _spinAnimation.value
                                    : _currentAngle;
                                return Transform.rotate(
                                  angle: angle,
                                  child: child,
                                );
                              },
                              child: RepaintBoundary(
                                child: CustomPaint(
                                  painter: _WheelPainter(
                                    activePool: _activePool,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Üst İbre / Pointer Ok
                          Positioned(
                            top: 0,
                            child: Transform.rotate(
                              angle: pi / 2,
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                size: 56,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Colors.black54,
                                    blurRadius: 10,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Eğer havuz boşsa ortada uyarı gösterelim
                          if (_activePool.isEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'TAP TO RESET',
                                style: GoogleFonts.outfit(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
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

class _WheelPainter extends CustomPainter {
  final List<PSWheelItem> activePool;

  _WheelPainter({required this.activePool});

  final List<Color> _colors = const [
    Color(0xFFEF4444),
    Color(0xFF3B82F6),
    Color(0xFFF59E0B),
    Color(0xFF10B981),
    Color(0xFF8B5CF6),
    Color(0xFF06B6D4),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final count = activePool.isEmpty ? 1 : activePool.length;
    final sweepAngle = (2 * pi) / count;

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;

    canvas.drawCircle(center, radius + 2, shadowPaint);

    for (int i = 0; i < count; i++) {
      final startAngle = i * sweepAngle;

      final fillPaint = Paint()
        ..color = _colors[i % _colors.length]
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        fillPaint,
      );

      // Sektör kenar çizgisi
      final linePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.6)
        ..strokeWidth = 2;

      final edgeX = center.dx + radius * cos(startAngle);
      final edgeY = center.dy + radius * sin(startAngle);
      canvas.drawLine(center, Offset(edgeX, edgeY), linePaint);

      // Metin çizimi
      if (activePool.isNotEmpty) {
        final textAngle = startAngle + sweepAngle / 2;
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(textAngle);

        final item = activePool[i];
        final String rawText = item.prompt;
        final String text = rawText.length > 65
            ? '${rawText.substring(0, 62)}...'
            : rawText;

        final bool isLargeWheel = radius > 200;
        final double fontSize = isLargeWheel
            ? (count > 12 ? 14.0 : 18.0)
            : (count > 12 ? 10.0 : 13.0);

        final textSpan = TextSpan(
          text: text,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            shadows: const [
              Shadow(
                color: Colors.black45,
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          maxLines: 4,
        );

        // Define max width based on wheel size and slice count
        // An approximation for text bounds inside a slice:
        double maxWidth = radius * 0.8;
        textPainter.layout(minWidth: 0, maxWidth: maxWidth);

        // Draw slightly offset from center towards the edge
        textPainter.paint(
          canvas,
          Offset(radius * 0.12, -textPainter.height / 2),
        );
        canvas.restore();
      }
    }

    canvas.drawCircle(center, radius, borderPaint);

    // Merkez boş yuvarlak (Center Pin)
    final centerCirclePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final centerCircleBorder = Paint()
      ..color = Colors.black12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    canvas.drawCircle(center, radius * 0.08, centerCirclePaint);
    canvas.drawCircle(center, radius * 0.08, centerCircleBorder);
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) {
    return activePool != oldDelegate.activePool ||
        activePool.length != oldDelegate.activePool.length;
  }
}
