import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/level_service.dart';

class LevelSelectionDialog extends StatefulWidget {
  final GameDifficulty initialDifficulty;
  final Color accentColor;
  final String title;
  final String subtitle;

  const LevelSelectionDialog({
    super.key,
    required this.initialDifficulty,
    this.accentColor = const Color(0xFF6366F1),
    this.title = 'Seviye Seçin',
    this.subtitle = 'Oyun zorluğunu İngilizce seviyenize göre belirleyin',
  });

  static Color _darken(Color c, [double amount = 0.20]) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }

  static Future<GameDifficulty?> show(
    BuildContext context, {
    GameDifficulty? initialDifficulty,
    Color accentColor = const Color(0xFF6366F1),
    String title = 'Seviye Seçin',
    String subtitle = 'Oyun zorluğunu İngilizce seviyenize göre belirleyin',
  }) async {
    final current = initialDifficulty ?? LevelService.instance.currentDifficulty;
    return showGeneralDialog<GameDifficulty>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Level Selection',
      barrierColor: Colors.black.withValues(alpha: 0.76),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, anim1, anim2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: LevelSelectionDialog(
              initialDifficulty: current,
              accentColor: accentColor,
              title: title,
              subtitle: subtitle,
            ),
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
  }

  @override
  State<LevelSelectionDialog> createState() => _LevelSelectionDialogState();
}

class _LevelSelectionDialogState extends State<LevelSelectionDialog> {
  late GameDifficulty _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialDifficulty;
  }

  void _confirm() {
    LevelService.instance.setDifficulty(_selected);
    Navigator.of(context).pop(_selected);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final bool isCompact = screenSize.width < 380;

    const Color bgColor = Color(0xFF141422);
    const Color surfaceColor = Color(0xFF1C1C2E);
    const Color borderColor = Color(0xFF2D2D46);
    final Color accentLip = LevelSelectionDialog._darken(widget.accentColor, 0.20);

    final options = [
      GameDifficulty.elementary,
      GameDifficulty.intermediate,
      GameDifficulty.all,
    ];

    return Container(
      width: screenSize.width * (isCompact ? 0.94 : 0.90),
      constraints: BoxConstraints(
        maxWidth: 440,
        maxHeight: screenSize.height * 0.88,
      ),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: EdgeInsets.fromLTRB(
              isCompact ? 16 : 22,
              isCompact ? 16 : 20,
              isCompact ? 16 : 22,
              14,
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: widget.accentColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accentLip,
                        offset: const Offset(0, 4),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: FaIcon(
                      FontAwesomeIcons.graduationCap,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: isCompact ? 18 : 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  icon: const Icon(Icons.close_rounded, color: Colors.white54),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1.5, color: borderColor),

          // Options
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                isCompact ? 16 : 22,
                16,
                isCompact ? 16 : 22,
                16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: options.map((diff) {
                  final bool isSelected = _selected == diff;
                  final Color diffColor = diff.color;
                  final Color diffLip =
                      LevelSelectionDialog._darken(diffColor, 0.22);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GestureDetector(
                      onTap: () => setState(() => _selected = diff),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: EdgeInsets.all(isCompact ? 13 : 15),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? diffColor.withValues(alpha: 0.16)
                              : surfaceColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? diffColor : borderColor,
                            width: isSelected ? 2.0 : 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isSelected
                                  ? diffLip
                                  : const Color(0xFF0A0A12),
                              offset: const Offset(0, 4),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? diffColor
                                    : diffColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: FaIcon(
                                  diff.icon,
                                  size: 18,
                                  color: isSelected ? Colors.white : diffColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    diff.labelTr,
                                    style: GoogleFonts.outfit(
                                      fontSize: isCompact ? 15 : 16,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    diff.descriptionTr,
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      color: Colors.white70,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Icon(
                              isSelected
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: isSelected ? diffColor : Colors.white30,
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const Divider(height: 1, thickness: 1.5, color: borderColor),

          // Action button
          Padding(
            padding: EdgeInsets.fromLTRB(
              isCompact ? 16 : 22,
              12,
              isCompact ? 16 : 22,
              isCompact ? 16 : 20,
            ),
            child: GestureDetector(
              onTap: _confirm,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: _selected.color,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: LevelSelectionDialog._darken(_selected.color, 0.22),
                      offset: const Offset(0, 4),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'SEVİYEYİ UYGULA (${_selected.shortLabel})',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
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
    );
  }
}

/// Compact AppBar action button for in-game screens.
/// Shows active difficulty and opens LevelSelectionDialog on tap.
class LevelBadgeButton extends StatelessWidget {
  final GameDifficulty difficulty;
  final ValueChanged<GameDifficulty>? onChanged;
  final VoidCallback? onTap;
  final Color? accentColor;

  const LevelBadgeButton({
    super.key,
    required this.difficulty,
    this.onChanged,
    this.onTap,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = difficulty.color;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap ??
              () async {
                final chosen = await LevelSelectionDialog.show(
                  context,
                  initialDifficulty: difficulty,
                  accentColor: accentColor ?? color,
                );
                if (chosen != null && onChanged != null) {
                  onChanged!(chosen);
                }
              },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.16 : 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withValues(alpha: 0.65),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: LevelSelectionDialog._darken(color, 0.25)
                      .withValues(alpha: isDark ? 0.6 : 0.25),
                  offset: const Offset(0, 2),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FaIcon(difficulty.icon, size: 12, color: color),
                const SizedBox(width: 6),
                Text(
                  difficulty.shortLabel,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : color,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 15,
                  color: isDark ? Colors.white70 : color,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
