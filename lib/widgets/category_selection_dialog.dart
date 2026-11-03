import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

class CategoryOption {
  final String id;
  final String titleTr;
  final String titleEn;
  final IconData icon;
  final int? count;
  final bool isAll;
  final Color? color;

  const CategoryOption({
    required this.id,
    required this.titleTr,
    this.titleEn = '',
    required this.icon,
    this.count,
    this.isAll = false,
    this.color,
  });
}

class CategorySelectionDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final Color accentColor;
  final IconData headerIcon;
  final List<CategoryOption> categories;
  final String initialSelectedId;
  final bool canDismiss;

  const CategorySelectionDialog({
    super.key,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.headerIcon,
    required this.categories,
    required this.initialSelectedId,
    this.canDismiss = true,
  });

  static Color _darken(Color c, [double amount = 0.20]) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }

  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Color accentColor,
    required IconData headerIcon,
    required List<CategoryOption> categories,
    required String initialSelectedId,
    bool canDismiss = true,
  }) async {
    return showGeneralDialog<String>(
      context: context,
      barrierDismissible: canDismiss,
      barrierLabel: 'Category Selection',
      barrierColor: Colors.black.withValues(alpha: 0.76),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, anim1, anim2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: CategorySelectionDialog(
              title: title,
              subtitle: subtitle,
              accentColor: accentColor,
              headerIcon: headerIcon,
              categories: categories,
              initialSelectedId: initialSelectedId,
              canDismiss: canDismiss,
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
  State<CategorySelectionDialog> createState() =>
      _CategorySelectionDialogState();
}

class _CategorySelectionDialogState extends State<CategorySelectionDialog> {
  late String _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialSelectedId;
  }

  void _confirmAndClose([String? overrideId]) {
    final id = overrideId ?? _selectedId;
    Navigator.of(context).pop(id);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final bool isCompact = screenSize.width < 380;

    const Color bgColor = Color(0xFF141422);
    const Color surfaceColor = Color(0xFF1C1C2E);
    const Color borderColor = Color(0xFF2D2D46);
    final Color accentLip =
        CategorySelectionDialog._darken(widget.accentColor, 0.20);

    final specialOption =
        widget.categories.where((c) => c.isAll).firstOrNull;
    final regularOptions =
        widget.categories.where((c) => !c.isAll).toList();

    return Container(
      width: screenSize.width * (isCompact ? 0.94 : 0.90),
      constraints: BoxConstraints(
        maxWidth: 500,
        maxHeight: screenSize.height * 0.86,
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
                  child: Center(
                    child: FaIcon(
                      widget.headerIcon,
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
                if (widget.canDismiss)
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white54,
                    ),
                  ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1.5, color: borderColor),

          // Body
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (specialOption != null) ...[
                    _buildSpecialAllBanner(
                      specialOption,
                      surfaceColor: surfaceColor,
                      borderColor: borderColor,
                      isCompact: isCompact,
                    ),
                    const SizedBox(height: 12),
                  ],
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: isCompact ? 2.15 : 2.35,
                    ),
                    itemCount: regularOptions.length,
                    itemBuilder: (ctx, i) {
                      return _buildCategoryGridTile(
                        regularOptions[i],
                        surfaceColor: surfaceColor,
                        borderColor: borderColor,
                        isCompact: isCompact,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 1, thickness: 1.5, color: borderColor),

          // Footer Button
          Padding(
            padding: EdgeInsets.fromLTRB(
              isCompact ? 16 : 22,
              12,
              isCompact ? 16 : 22,
              isCompact ? 16 : 20,
            ),
            child: GestureDetector(
              onTap: () => _confirmAndClose(),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: widget.accentColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
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
                      'KATEGORİYİ UYGULA',
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

  Widget _buildSpecialAllBanner(
    CategoryOption opt, {
    required Color surfaceColor,
    required Color borderColor,
    required bool isCompact,
  }) {
    final isSelected = _selectedId == opt.id;
    final Color optColor = opt.color ?? widget.accentColor;
    final optLip = CategorySelectionDialog._darken(optColor, 0.22);

    return GestureDetector(
      onTap: () => setState(() => _selectedId = opt.id),
      onDoubleTap: () => _confirmAndClose(opt.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 12 : 16,
          vertical: isCompact ? 11 : 13,
        ),
        decoration: BoxDecoration(
          color: isSelected ? optColor.withValues(alpha: 0.18) : surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? optColor : borderColor,
            width: isSelected ? 2.0 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? optLip : const Color(0xFF0A0A12),
              offset: const Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isSelected
                    ? optColor
                    : optColor.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Center(
                child: FaIcon(
                  opt.icon,
                  color: isSelected ? Colors.white : optColor,
                  size: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    opt.titleTr,
                    style: GoogleFonts.outfit(
                      fontSize: isCompact ? 14 : 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  if (opt.titleEn.isNotEmpty)
                    Text(
                      opt.titleEn,
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        color: Colors.white60,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              isSelected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isSelected ? optColor : Colors.white30,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryGridTile(
    CategoryOption opt, {
    required Color surfaceColor,
    required Color borderColor,
    required bool isCompact,
  }) {
    final isSelected = _selectedId == opt.id;
    final Color optColor = opt.color ?? widget.accentColor;
    final optLip = CategorySelectionDialog._darken(optColor, 0.22);

    return GestureDetector(
      onTap: () => setState(() => _selectedId = opt.id),
      onDoubleTap: () => _confirmAndClose(opt.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 10 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? optColor.withValues(alpha: 0.18) : surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? optColor : borderColor,
            width: isSelected ? 2.0 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? optLip : const Color(0xFF0A0A12),
              offset: const Offset(0, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: isCompact ? 30 : 34,
              height: isCompact ? 30 : 34,
              decoration: BoxDecoration(
                color: isSelected
                    ? optColor
                    : optColor.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Center(
                child: FaIcon(
                  opt.icon,
                  color: isSelected ? Colors.white : optColor,
                  size: isCompact ? 13 : 15,
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    opt.titleTr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: isCompact ? 12 : 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.15,
                    ),
                  ),
                  if (opt.count != null)
                    Text(
                      '${opt.count} kelime',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? optColor : Colors.white54,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
