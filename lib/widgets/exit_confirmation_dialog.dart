import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

Future<bool> showExitConfirmationDialog(BuildContext context) async {
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Exit Confirmation',
    barrierColor: Colors.black.withValues(alpha: 0.76),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, anim1, anim2) {
      return const Center(
        child: Material(
          color: Colors.transparent,
          child: _TactileExitConfirmationDialog(),
        ),
      );
    },
    transitionBuilder: (ctx, anim1, anim2, child) {
      final curved = Curves.easeOutCubic.transform(anim1.value);
      return Transform.scale(
        scale: 0.94 + 0.06 * curved,
        child: Opacity(opacity: anim1.value.clamp(0.0, 1.0), child: child),
      );
    },
  );
  return result ?? false;
}

class _TactileExitConfirmationDialog extends StatelessWidget {
  const _TactileExitConfirmationDialog();

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final bool isCompact = screenSize.width < 380;

    const Color bgColor = Color(0xFF141422);
    const Color surfaceColor = Color(0xFF1C1C2E);
    const Color borderColor = Color(0xFF2D2D46);
    const Color warningColor = Color(0xFFF59E0B);
    const Color warningLip = Color(0xFFB45309);
    const Color dangerColor = Color(0xFFEF4444);
    const Color dangerLip = Color(0xFFB91C1C);

    return Container(
      width: screenSize.width * (isCompact ? 0.92 : 0.88),
      constraints: const BoxConstraints(maxWidth: 400),
      padding: EdgeInsets.all(isCompact ? 20 : 24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF080810),
            offset: Offset(0, 8),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tactile 3D Warning Icon Badge
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: warningColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 1.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: warningLip,
                  offset: Offset(0, 4),
                  blurRadius: 0,
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.warning_amber_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
          const SizedBox(height: 18),

          Text(
            'Oyundan Çıkılsın mı?',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: isCompact ? 20 : 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 1.5),
            ),
            child: Text(
              'Mevcut oyun oturumunuz sonlandırılacak ve bu turdaki ilerlemeniz sıfırlanacaktır. Çıkmak istediğinize emin misiniz?',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 22),

          Row(
            children: [
              // Stay Button (Tactile Secondary)
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor, width: 1.5),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0xFF0A0A12),
                          offset: Offset(0, 4),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 19,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Devam Et',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Exit Button (Tactile Danger)
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: dangerColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                        width: 1.5,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: dangerLip,
                          offset: Offset(0, 4),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.exit_to_app_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Çıkış Yap',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w900,
                            fontSize: 14.5,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
