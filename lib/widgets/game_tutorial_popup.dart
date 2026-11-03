import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/level_service.dart';
import 'category_selection_dialog.dart';

class GameLaunchResult {
  final GameDifficulty? difficulty;
  final String? categoryId;

  const GameLaunchResult({
    this.difficulty,
    this.categoryId,
  });
}

class GameTutorialPopup {
  static bool _sessionIsTr = true;

  static Color _darken(Color c, [double amount = 0.20]) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }

  static Future<GameLaunchResult> show(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required String tutorialTextTr,
    required String tutorialTextEn,
    String? tutorialKey,
    bool forceShow = false,
    bool hideLanguageToggle = false,
    bool includeLevelSelection = false,
    GameDifficulty? initialDifficulty,
    List<CategoryOption>? categories,
    String? initialCategoryId,
    WidgetBuilder? extraSetupBuilder,
  }) async {
    if (!context.mounted) return const GameLaunchResult();

    final bool hasCategories = categories != null && categories.isNotEmpty;

    final result = await showGeneralDialog<GameLaunchResult>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Game Setup & Tutorial',
      barrierColor: Colors.black.withValues(alpha: 0.78),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, anim1, anim2) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: _TutorialDialogContent(
              title: title,
              icon: icon,
              color: color,
              tutorialTextTr: tutorialTextTr,
              tutorialTextEn: tutorialTextEn,
              forceShow: forceShow,
              hideLanguageToggle: hideLanguageToggle,
              includeLevelSelection: includeLevelSelection,
              initialDifficulty:
                  initialDifficulty ?? LevelService.instance.currentDifficulty,
              categories: categories,
              initialCategoryId: initialCategoryId,
              extraSetupBuilder: extraSetupBuilder,
            ),
          ),
        );
      },
      transitionBuilder: (dialogContext, anim1, anim2, child) {
        final curvedValue = Curves.easeOutCubic.transform(anim1.value);
        return Transform.scale(
          scale: 0.94 + (0.06 * curvedValue),
          child: Opacity(
            opacity: anim1.value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
    );

    return result ??
        GameLaunchResult(
          difficulty: includeLevelSelection
              ? (initialDifficulty ?? LevelService.instance.currentDifficulty)
              : null,
          categoryId: hasCategories ? initialCategoryId : null,
        );
  }
}

class _TutorialDialogContent extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String tutorialTextTr;
  final String tutorialTextEn;
  final bool forceShow;
  final bool hideLanguageToggle;
  final bool includeLevelSelection;
  final GameDifficulty initialDifficulty;
  final List<CategoryOption>? categories;
  final String? initialCategoryId;
  final WidgetBuilder? extraSetupBuilder;

  const _TutorialDialogContent({
    required this.title,
    required this.icon,
    required this.color,
    required this.tutorialTextTr,
    required this.tutorialTextEn,
    this.forceShow = false,
    this.hideLanguageToggle = false,
    this.includeLevelSelection = false,
    required this.initialDifficulty,
    this.categories,
    this.initialCategoryId,
    this.extraSetupBuilder,
  });

  @override
  State<_TutorialDialogContent> createState() => _TutorialDialogContentState();
}

class _TutorialDialogContentState extends State<_TutorialDialogContent> {
  late bool _isTr;
  bool _tutorialExpanded = true;
  late GameDifficulty _selectedDifficulty;
  late String _selectedCategoryId;

  bool get _hasCategories =>
      widget.categories != null && widget.categories!.isNotEmpty;
  bool get _hasSetupOptions =>
      widget.includeLevelSelection ||
      _hasCategories ||
      widget.extraSetupBuilder != null;

  @override
  void initState() {
    super.initState();
    _isTr = widget.hideLanguageToggle ? false : GameTutorialPopup._sessionIsTr;
    _tutorialExpanded = true;
    _selectedDifficulty = widget.initialDifficulty;
    _selectedCategoryId = widget.initialCategoryId ??
        (_hasCategories ? widget.categories!.first.id : 'All');
  }

  Future<void> _confirmAndClose() async {
    if (widget.includeLevelSelection) {
      await LevelService.instance.setDifficulty(_selectedDifficulty);
    }
    if (!mounted) return;
    Navigator.of(context).pop(
      GameLaunchResult(
        difficulty: widget.includeLevelSelection ? _selectedDifficulty : null,
        categoryId: _hasCategories ? _selectedCategoryId : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final bool isCompact = screenSize.width < 400;
    final double maxDialogWidth = _hasCategories ? 540.0 : 480.0;

    const Color bgColor = Color(0xFF141422);
    const Color surfaceColor = Color(0xFF1C1C2E);
    const Color borderColor = Color(0xFF2D2D46);
    final Color accentLip = GameTutorialPopup._darken(widget.color, 0.20);

    return Container(
      width: screenSize.width * (isCompact ? 0.94 : 0.90),
      constraints: BoxConstraints(
        maxWidth: maxDialogWidth,
        maxHeight: screenSize.height * 0.90,
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
          // ── TOP HEADER ──
          Padding(
            padding: EdgeInsets.fromLTRB(
              isCompact ? 16 : 22,
              isCompact ? 16 : 20,
              isCompact ? 16 : 22,
              14,
            ),
            child: Row(
              children: [
                // 3D Tactile Icon Box
                Container(
                  width: isCompact ? 46 : 52,
                  height: isCompact ? 46 : 52,
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(15),
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
                      widget.icon,
                      color: Colors.white,
                      size: isCompact ? 20 : 22,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: borderColor),
                        ),
                        child: Text(
                          _hasSetupOptions
                              ? (_isTr ? 'OYUN KURULUMU & REHBER' : 'SETUP & GUIDE')
                              : (_isTr ? 'OYUN REHBERİ' : 'HOW TO PLAY'),
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: widget.color,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: isCompact ? 19 : 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!widget.hideLanguageToggle)
                  _buildLanguageToggle(surfaceColor, borderColor),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1.5, color: borderColor),

          // ── SCROLLABLE BODY ──
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
                  // 1. HOW TO PLAY SECTION
                  _buildTutorialSection(
                    surfaceColor: surfaceColor,
                    borderColor: borderColor,
                    isCompact: isCompact,
                  ),

                  // 2. EXTRA GAME-SPECIFIC SETUP (e.g. Word Penalty Role/Mode)
                  if (widget.extraSetupBuilder != null) ...[
                    const SizedBox(height: 16),
                    widget.extraSetupBuilder!(context),
                  ],

                  // 3. LEVEL SELECTION SECTION
                  if (widget.includeLevelSelection) ...[
                    const SizedBox(height: 16),
                    _buildLevelSelectionSection(
                      surfaceColor: surfaceColor,
                      borderColor: borderColor,
                      isCompact: isCompact,
                    ),
                  ],

                  // 4. CATEGORY SELECTION SECTION
                  if (_hasCategories) ...[
                    const SizedBox(height: 16),
                    _buildCategorySelectionSection(
                      surfaceColor: surfaceColor,
                      borderColor: borderColor,
                      isCompact: isCompact,
                    ),
                  ],
                ],
              ),
            ),
          ),

          const Divider(height: 1, thickness: 1.5, color: borderColor),

          // ── FOOTER ACTION ──
          Padding(
            padding: EdgeInsets.fromLTRB(
              isCompact ? 16 : 22,
              12,
              isCompact ? 16 : 22,
              isCompact ? 14 : 18,
            ),
            child: GestureDetector(
              onTap: _confirmAndClose,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: widget.color,
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
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.forceShow
                          ? (_isTr ? 'DEVAM ET' : 'CONTINUE')
                          : (_isTr ? 'OYUNA BAŞLA' : 'START GAME'),
                      style: GoogleFonts.outfit(
                        fontSize: isCompact ? 15 : 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
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

  Widget _buildLanguageToggle(Color surfaceColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLangPill('TR', _isTr, () {
            setState(() {
              _isTr = true;
              GameTutorialPopup._sessionIsTr = true;
            });
          }),
          _buildLangPill('EN', !_isTr, () {
            setState(() {
              _isTr = false;
              GameTutorialPopup._sessionIsTr = false;
            });
          }),
        ],
      ),
    );
  }

  Widget _buildLangPill(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? widget.color : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: active ? Colors.white : Colors.white54,
          ),
        ),
      ),
    );
  }

  Widget _buildTutorialSection({
    required Color surfaceColor,
    required Color borderColor,
    required bool isCompact,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF0A0A12),
            offset: Offset(0, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: _hasSetupOptions
                ? () => setState(() => _tutorialExpanded = !_tutorialExpanded)
                : null,
            borderRadius: BorderRadius.circular(15),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  Icon(
                    Icons.menu_book_rounded,
                    size: 17,
                    color: widget.color,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isTr ? 'Nasıl Oynanır?' : 'How to Play?',
                      style: GoogleFonts.outfit(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (_hasSetupOptions)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141422),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _tutorialExpanded
                                ? (_isTr ? 'Daralt' : 'Hide')
                                : (_isTr ? 'Göster' : 'Show'),
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            _tutorialExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 15,
                            color: Colors.white70,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_tutorialExpanded) ...[
            const Divider(height: 1, thickness: 1, color: Color(0xFF2D2D46)),
            Padding(
              padding: EdgeInsets.all(isCompact ? 12 : 14),
              child: Text(
                _isTr ? widget.tutorialTextTr : widget.tutorialTextEn,
                style: GoogleFonts.outfit(
                  fontSize: isCompact ? 13 : 13.8,
                  height: 1.48,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFD6D6E7),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLevelSelectionSection({
    required Color surfaceColor,
    required Color borderColor,
    required bool isCompact,
  }) {
    final options = [
      GameDifficulty.elementary,
      GameDifficulty.intermediate,
      GameDifficulty.all,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.tune_rounded, size: 16, color: widget.color),
            const SizedBox(width: 7),
            Text(
              _isTr ? 'SEVİYE SEÇİMİ (CEFR)' : 'SELECT LEVEL (CEFR)',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.9,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: options.map((diff) {
            final bool isSelected = _selectedDifficulty == diff;
            final Color diffColor = diff.color;
            final Color diffLip = GameTutorialPopup._darken(diffColor, 0.22);

            String shortTitle;
            String subTitle;
            switch (diff) {
              case GameDifficulty.elementary:
                shortTitle = 'A1–A2';
                subTitle = _isTr ? 'Başlangıç' : 'Elementary';
                break;
              case GameDifficulty.intermediate:
                shortTitle = 'B1–B2';
                subTitle = _isTr ? 'Orta–İleri' : 'Intermediate';
                break;
              case GameDifficulty.all:
                shortTitle = _isTr ? 'Tümü' : 'All';
                subTitle = _isTr ? 'Karışık' : 'Mixed';
                break;
            }

            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: diff != options.last ? 8.0 : 0.0,
                ),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedDifficulty = diff),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: EdgeInsets.symmetric(
                      vertical: isCompact ? 10 : 12,
                      horizontal: isCompact ? 6 : 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? diffColor.withValues(alpha: 0.18)
                          : surfaceColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? diffColor : borderColor,
                        width: isSelected ? 2.0 : 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isSelected
                              ? diffLip
                              : const Color(0xFF0A0A12),
                          offset: const Offset(0, 3),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FaIcon(
                              diff.icon,
                              size: 13,
                              color: isSelected ? diffColor : Colors.white54,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                shortTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: isCompact ? 13 : 14,
                                  fontWeight: FontWeight.w900,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white70,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: isCompact ? 10.5 : 11.5,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? diffColor : Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCategorySelectionSection({
    required Color surfaceColor,
    required Color borderColor,
    required bool isCompact,
  }) {
    final cats = widget.categories!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.grid_view_rounded, size: 16, color: widget.color),
            const SizedBox(width: 7),
            Text(
              _isTr ? 'KATEGORİ SEÇİMİ' : 'SELECT CATEGORY',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.9,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 210),
          child: GridView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 4),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isCompact ? 2 : 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: isCompact ? 2.5 : 2.35,
            ),
            itemCount: cats.length,
            itemBuilder: (context, index) {
              final cat = cats[index];
              final bool isSelected = _selectedCategoryId == cat.id;
              final Color catColor = cat.color ?? widget.color;
              final Color catLip = GameTutorialPopup._darken(catColor, 0.22);

              return GestureDetector(
                onTap: () => setState(() => _selectedCategoryId = cat.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? catColor.withValues(alpha: 0.18)
                        : surfaceColor,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: isSelected ? catColor : borderColor,
                      width: isSelected ? 2.0 : 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected ? catLip : const Color(0xFF0A0A12),
                        offset: const Offset(0, 3),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? catColor
                              : catColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: FaIcon(
                            cat.icon,
                            size: 13,
                            color: isSelected ? Colors.white : catColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cat.titleTr,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.88),
                                height: 1.1,
                              ),
                            ),
                            if (cat.count != null)
                              Text(
                                '${cat.count} kelime',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      isSelected ? catColor : Colors.white54,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
