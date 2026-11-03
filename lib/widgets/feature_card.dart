import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'animated_hover_wrapper.dart';

class FeatureCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? badgeText;
  final String? highScoreText;

  const FeatureCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.badgeText,
    this.highScoreText,
  });

  static Color darken(Color c, [double amount = 0.15]) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.06, 0.85))
        .toColor();
  }

  static Color lighten(Color c, [double amount = 0.08]) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.12, 0.92))
        .toColor();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth;
        // Normalized scale factor: 0.0 on small mobile (~135px) to 1.0 on desktop (~260px+)
        final double t = ((cardWidth - 135.0) / 125.0).clamp(0.0, 1.0);

        final double padH = (12.0 + t * 6.0).clamp(11.0, 18.0);
        final double padV = (12.0 + t * 6.0).clamp(11.0, 18.0);
        final double iconBoxPadding = (9.0 + t * 4.0).clamp(8.5, 13.0);
        final double iconSize = (20.0 + t * 6.0).clamp(19.0, 26.0);
        final double titleSize = (15.0 + t * 4.5).clamp(14.5, 19.5);
        final double subtitleSize = (11.5 + t * 2.0).clamp(11.0, 13.5);
        final double badgeFontSize = (7.5 + t * 2.0).clamp(7.5, 9.5);
        final double watermarkSize = (84.0 + t * 32.0).clamp(80.0, 116.0);
        final double lipHeight = t > 0.4 ? 5.0 : 4.0;

        final Color lipColor = darken(color, 0.16);
        final Color topSurfaceColor = lighten(color, 0.04);

        return AnimatedHoverWrapper(
          scaleAmount: 1.03,
          child: Container(
            decoration: BoxDecoration(
              color: lipColor,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.32),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            padding: EdgeInsets.only(bottom: lipHeight),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [topSurfaceColor, color],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.20),
                  width: 1.2,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(20),
                  splashColor: Colors.white.withValues(alpha: 0.18),
                  highlightColor: Colors.black.withValues(alpha: 0.08),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Sağ alt dekoratif arka plan ikon silüeti (Watermark)
                      Positioned(
                        right: -14,
                        bottom: -14,
                        child: IgnorePointer(
                          child: Transform.rotate(
                            angle: -0.22,
                            child: Icon(
                              icon,
                              size: watermarkSize,
                              color: Colors.white.withValues(alpha: 0.11),
                            ),
                          ),
                        ),
                      ),

                      // Asimetrik sol-hizalı kart içeriği
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: padH,
                          vertical: padV,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Üst Satır: Sol kare ikon kutusu + Sağ rozetler
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(iconBoxPadding),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.20),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.24),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Icon(
                                    icon,
                                    color: Colors.white,
                                    size: iconSize,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (badgeText != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black
                                                .withValues(alpha: 0.24),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: Colors.white
                                                  .withValues(alpha: 0.16),
                                              width: 1.0,
                                            ),
                                          ),
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              badgeText!,
                                              maxLines: 1,
                                              style: GoogleFonts.outfit(
                                                fontSize: badgeFontSize,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                        ),
                                      if (highScoreText != null) ...[
                                        if (badgeText != null)
                                          const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2.5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF3C7),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.emoji_events_rounded,
                                                size: badgeFontSize + 2,
                                                color: const Color(0xFFB45309),
                                              ),
                                              const SizedBox(width: 3),
                                              Text(
                                                highScoreText!,
                                                style: GoogleFonts.outfit(
                                                  fontSize: badgeFontSize,
                                                  fontWeight: FontWeight.w900,
                                                  color:
                                                      const Color(0xFF92400E),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            // Alt Kısım: Sol-hizalı güçlü başlık + açıklama
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.left,
                                  style: GoogleFonts.outfit(
                                    fontSize: titleSize,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.3,
                                    height: 1.15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  subtitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.left,
                                  style: GoogleFonts.outfit(
                                    fontSize: subtitleSize,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withValues(alpha: 0.90),
                                    height: 1.25,
                                  ),
                                ),
                              ],
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
        );
      },
    );
  }
}
