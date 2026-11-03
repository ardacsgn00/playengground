import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/game_review_item.dart';
import '../game_review_accordion.dart';

/// Shared visual building blocks for the arcade-styled games.
/// Purely presentational: no game logic lives here.
/// Intentionally flat colors (no gradients) to match the newer games.

/// Glowing timer bar that shifts green -> amber -> red as time runs out.
class GlowTimerBar extends StatelessWidget {
  final double percent; // 1.0 = full, 0.0 = empty
  final double height;
  final String? label;
  final Color? labelColor;

  const GlowTimerBar({
    super.key,
    required this.percent,
    this.height = 6,
    this.label,
    this.labelColor,
  });

  static Color colorFor(double p) => p < 0.25
      ? const Color(0xFFEF4444)
      : p < 0.55
          ? const Color(0xFFF59E0B)
          : const Color(0xFF10B981);

  @override
  Widget build(BuildContext context) {
    final p = percent.clamp(0.0, 1.0);
    final barColor = colorFor(p);
    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: height,
        color: Colors.white.withValues(alpha: 0.08),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: p,
            child: Container(
              decoration: BoxDecoration(
                color: barColor,
                boxShadow: [
                  BoxShadow(color: barColor.withValues(alpha: 0.7), blurRadius: 6),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (label == null) return bar;
    return Row(
      children: [
        Text(
          label!,
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
            color: labelColor ?? barColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: bar),
      ],
    );
  }
}

/// Top HUD: optional leading badge, score, streak pill and lives.
class ArcadeHud extends StatelessWidget {
  final Color accent;
  final Color surface;
  final Widget? badge;
  final int score;
  final int streak;
  final int lives;
  final int maxLives;
  final Animation<double>? livesScale;

  const ArcadeHud({
    super.key,
    required this.accent,
    required this.surface,
    required this.score,
    required this.streak,
    required this.lives,
    this.maxLives = 3,
    this.badge,
    this.livesScale,
  });

  @override
  Widget build(BuildContext context) {
    Widget hearts = Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxLives, (i) {
        final alive = i < lives;
        return Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Icon(
            alive ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: alive ? const Color(0xFFEF4444) : Colors.white24,
            size: 22,
          ),
        );
      }),
    );
    if (livesScale != null) {
      hearts = ScaleTransition(scale: livesScale!, child: hearts);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (badge != null) ...[
            Flexible(flex: 0, child: badge!),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SCORE',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: Colors.white54,
                  ),
                ),
                Text(
                  '$score',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          if (streak >= 2)
            Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF97316),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '🔥 ${streak}x',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ),
          hearts,
        ],
      ),
    );
  }
}

/// Small pill badge used inside the HUD (category, level, case file...).
class ArcadeBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final VoidCallback? onTap;
  final IconData? trailing;

  const ArcadeBadge({
    super.key,
    required this.icon,
    required this.text,
    required this.color,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 8 : 11,
            vertical: isMobile ? 4 : 6,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
            border: Border.all(
              color: color.withValues(alpha: 0.45),
              width: isMobile ? 1.0 : 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: isMobile ? 12 : 14, color: color),
              SizedBox(width: isMobile ? 4 : 6),
              Flexible(
                child: Text(
                  text,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: isMobile ? 11 : 12.5,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
              if (trailing != null) ...[
                SizedBox(width: isMobile ? 3 : 4),
                Icon(trailing, size: isMobile ? 12 : 14, color: color),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ArcadeGameOverAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;
  const ArcadeGameOverAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });
}

/// Blurred full-screen game over card (score + best streak, themed).
class ArcadeGameOverCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color accent;
  final Color surface;
  final int score;
  final int bestStreak;
  final int? highScore;
  final bool isNewHighScore;
  final List<GameReviewItem>? reviewItems;
  final List<ArcadeGameOverAction> actions;

  const ArcadeGameOverCard({
    super.key,
    required this.title,
    required this.icon,
    required this.accent,
    required this.surface,
    required this.score,
    required this.bestStreak,
    required this.actions,
    this.subtitle,
    this.highScore,
    this.isNewHighScore = false,
    this.reviewItems,
  });

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Container(
        color: Colors.black.withValues(alpha: 0.65),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.85, end: 1.0),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutBack,
          builder: (context, s, child) => Transform.scale(scale: s, child: child),
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440, maxHeight: 720),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: accent.withValues(alpha: 0.5), width: 1.5),
                boxShadow: [
                  BoxShadow(color: accent.withValues(alpha: 0.2), blurRadius: 30),
                ],
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(color: accent.withValues(alpha: 0.5)),
                      ),
                      child: Icon(icon, size: 36, color: accent),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: accent,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(fontSize: 13, color: Colors.white60),
                      ),
                    ],
                    if (isNewHighScore) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.amber, width: 1.2),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.emoji_events, size: 16, color: Colors.amber),
                            const SizedBox(width: 6),
                            Text(
                              'YENİ EN YÜKSEK SKOR!',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: Colors.amber,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(child: _stat('SCORE', '$score')),
                        if (highScore != null) ...[
                          const SizedBox(width: 8),
                          Expanded(child: _stat('BEST', '🏆 $highScore')),
                        ],
                        const SizedBox(width: 8),
                        Expanded(child: _stat('STREAK', '🔥 $bestStreak')),
                      ],
                    ),
                    if (reviewItems != null && reviewItems!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      GameReviewAccordion(
                        items: reviewItems!,
                        accentColor: accent,
                      ),
                    ],
                    const SizedBox(height: 20),
                  for (final a in actions) ...[
                    SizedBox(
                      width: double.infinity,
                      child: a.primary
                          ? ElevatedButton.icon(
                              onPressed: a.onTap,
                              icon: Icon(a.icon, size: 18),
                              label: Text(a.label,
                                  style: GoogleFonts.outfit(
                                      fontSize: 17, fontWeight: FontWeight.w800)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accent,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                            )
                          : OutlinedButton.icon(
                              onPressed: a.onTap,
                              icon: Icon(a.icon, size: 16),
                              label: Text(a.label,
                                  style: GoogleFonts.outfit(
                                      fontSize: 15, fontWeight: FontWeight.w700)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white70,
                                side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _stat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Text(label,
              style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: Colors.white54)),
          const SizedBox(height: 4),
          Text(value,
              style: GoogleFonts.outfit(
                  fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
        ],
      ),
    );
  }
}
