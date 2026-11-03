import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/pwa_install_service.dart';

/// Same image as the current favicon / manifest icons (web/icons/icon-v2-*.png).
const String kAppLogoAsset = 'assets/logo/kare logo.png';

const Color _violet = Color(0xFF8B5CF6);
const Color _violetLight = Color(0xFFA78BFA);

/// "Uygulamayı Yükle" button shown under the developer credit on the home
/// screen. Hidden on native builds and when already running as an installed
/// PWA.
///
/// - Android / Desktop (Chrome, Edge…): triggers the native install prompt.
/// - iOS: shows step-by-step "Add to Home Screen" instructions.
/// - Other browsers / prompt unavailable: shows manual install instructions.
class PwaInstallButton extends StatefulWidget {
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? margin;

  const PwaInstallButton({
    super.key,
    this.width,
    this.height,
    this.margin,
  });

  @override
  State<PwaInstallButton> createState() => _PwaInstallButtonState();
}

class _PwaInstallButtonState extends State<PwaInstallButton> {
  final PwaInstallService _pwa = PwaInstallService.instance;
  bool _isHovered = false;
  bool _isBusy = false;

  Future<void> _handleTap() async {
    if (_isBusy) return;

    if (_pwa.isIos) {
      await showInstallGuideDialog(context, platform: InstallGuidePlatform.ios);
      return;
    }

    if (_pwa.canPrompt) {
      setState(() => _isBusy = true);
      final outcome = await _pwa.prompt();
      if (!mounted) return;
      setState(() => _isBusy = false);
      if (outcome == 'accepted') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF1E1E38),
            content: Text(
              'PlayEngGround yükleniyor 🎉',
              style: GoogleFonts.outfit(color: Colors.white),
            ),
          ),
        );
      }
      return;
    }

    await showInstallGuideDialog(
      context,
      platform: _pwa.isAndroid
          ? InstallGuidePlatform.android
          : InstallGuidePlatform.desktop,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pwa,
      builder: (context, _) {
        if (!_pwa.shouldShowButton) return const SizedBox.shrink();

        final screenWidth = MediaQuery.of(context).size.width;
        final isNarrow = screenWidth < 420;

        return Padding(
          padding: widget.margin ?? const EdgeInsets.only(top: 14),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: Tooltip(
              message: 'PlayEngGround Uygulamasını Yükle',
              child: AnimatedScale(
                scale: _isHovered ? 1.02 : 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  width: widget.width,
                  height: widget.height,
                  decoration: BoxDecoration(
                    color: _isHovered
                        ? const Color(0xFF1E1E38)
                        : const Color(0xFF16162A),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _isHovered
                          ? const Color(0xFF8B5CF6)
                          : const Color(0xFF2A2A4A),
                      width: 1.0,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _handleTap,
                      borderRadius: BorderRadius.circular(24),
                      hoverColor: Colors.transparent,
                      splashColor:
                          const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _AppLogo(size: isNarrow ? 22 : 24),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Uygulamayı Yükle',
                                style: GoogleFonts.outfit(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _isBusy
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFFA78BFA),
                                    ),
                                  )
                                : AnimatedSlide(
                                    offset: _isHovered
                                        ? const Offset(0, 0.15)
                                        : Offset.zero,
                                    duration:
                                        const Duration(milliseconds: 200),
                                    child: Icon(
                                      _pwa.isIos
                                          ? Icons.ios_share_rounded
                                          : Icons.download_rounded,
                                      size: 15,
                                      color: const Color(0xFFA78BFA),
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    ),
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

class _AppLogo extends StatelessWidget {
  final double size;
  final double? radius;

  const _AppLogo({required this.size, this.radius});

  @override
  Widget build(BuildContext context) {
    Widget image = Image.asset(
      kAppLogoAsset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );

    if (radius != null && radius! > 0) {
      image = ClipRRect(
        borderRadius: BorderRadius.circular(radius!),
        child: image,
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: image,
    );
  }
}

enum InstallGuidePlatform { ios, android, desktop }

class _GuideStep {
  final IconData icon;
  final String title;
  final String detail;

  const _GuideStep(this.icon, this.title, this.detail);
}

Future<void> showInstallGuideDialog(
  BuildContext context, {
  required InstallGuidePlatform platform,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Kapat',
    barrierColor: Colors.black.withValues(alpha: 0.6),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (context, _, _) => _InstallGuideDialog(platform: platform),
    transitionBuilder: (context, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _InstallGuideDialog extends StatelessWidget {
  final InstallGuidePlatform platform;

  const _InstallGuideDialog({required this.platform});

  String get _subtitle {
    switch (platform) {
      case InstallGuidePlatform.ios:
        return 'iPhone / iPad ana ekranına 3 adımda ekleyin.';
      case InstallGuidePlatform.android:
        return 'Tarayıcınız otomatik yüklemeyi sunmadı. Şu adımlarla yükleyebilirsiniz:';
      case InstallGuidePlatform.desktop:
        return 'Tarayıcınız otomatik yüklemeyi sunmadı. Şu adımlarla yükleyebilirsiniz:';
    }
  }

  List<_GuideStep> get _steps {
    switch (platform) {
      case InstallGuidePlatform.ios:
        return const [
          _GuideStep(
            Icons.ios_share_rounded,
            'Paylaş butonuna dokunun',
            'Safari\'de alt çubuktaki (iPad\'de üstteki) kare ve yukarı ok simgesi.',
          ),
          _GuideStep(
            Icons.add_box_outlined,
            '"Ana Ekrana Ekle"yi seçin',
            'Menüyü aşağı kaydırarak seçeneği bulun.',
          ),
          _GuideStep(
            Icons.check_circle_outline_rounded,
            '"Ekle"ye dokunun',
            'PlayEngGround simgesi ana ekranınızda belirecek.',
          ),
        ];
      case InstallGuidePlatform.android:
        return const [
          _GuideStep(
            Icons.more_vert_rounded,
            'Tarayıcı menüsünü açın',
            'Sağ üstteki üç nokta (⋮) simgesine dokunun.',
          ),
          _GuideStep(
            Icons.install_mobile_rounded,
            '"Uygulamayı yükle"yi seçin',
            'Bazı tarayıcılarda "Ana ekrana ekle" olarak görünür.',
          ),
          _GuideStep(
            Icons.check_circle_outline_rounded,
            '"Yükle"ye dokunun',
            'PlayEngGround uygulama çekmecenize eklenecek.',
          ),
        ];
      case InstallGuidePlatform.desktop:
        return const [
          _GuideStep(
            Icons.install_desktop_rounded,
            'Adres çubuğundaki yükle simgesi',
            'Chrome / Edge\'de adres çubuğunun sağındaki simgeye tıklayın.',
          ),
          _GuideStep(
            Icons.more_vert_rounded,
            'Ya da tarayıcı menüsünden',
            'Chrome: ⋮ → "Yayınla, kaydet ve paylaş" → "Yükle". Edge: ⋯ → "Uygulamalar" → "Bu siteyi uygulama olarak yükle".',
          ),
          _GuideStep(
            Icons.laptop_mac_rounded,
            'Mac Safari kullanıyorsanız',
            'Dosya menüsü → "Dock\'a Ekle".',
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF16162A) : Colors.white;
    final border = isDark ? const Color(0xFF2A2A4A) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final bodyColor = isDark ? Colors.white70 : const Color(0xFF475569);

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Material(
              color: bg,
              borderRadius: BorderRadius.circular(28),
              clipBehavior: Clip.antiAlias,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: border),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: _violet.withValues(alpha: 0.35),
                              blurRadius: 28,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const _AppLogo(size: 84, radius: 22),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'PlayEngGround\'u Yükle',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _subtitle,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: bodyColor,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 22),
                      for (var i = 0; i < _steps.length; i++)
                        _StepTile(
                          index: i + 1,
                          step: _steps[i],
                          isDark: isDark,
                          titleColor: titleColor,
                          bodyColor: bodyColor,
                        ),
                      if (platform == InstallGuidePlatform.ios) ...[
                        const SizedBox(height: 4),
                        _NoteBox(
                          isDark: isDark,
                          text:
                              'Seçeneği göremiyorsanız sayfayı Safari\'de açın.',
                        ),
                      ] else ...[
                        const SizedBox(height: 4),
                        _NoteBox(
                          isDark: isDark,
                          text:
                              'Uygulama zaten yüklüyse menüden "Uygulamada aç" seçeneğini kullanabilirsiniz.',
                        ),
                      ],
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: FilledButton.styleFrom(
                            backgroundColor: _violet,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Anladım',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final int index;
  final _GuideStep step;
  final bool isDark;
  final Color titleColor;
  final Color bodyColor;

  const _StepTile({
    required this.index,
    required this.step,
    required this.isDark,
    required this.titleColor,
    required this.bodyColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _violet.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _violet.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(step.icon, color: _violetLight, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$index. ${step.title}',
                  style: GoogleFonts.outfit(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  step.detail,
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    color: bodyColor,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteBox extends StatelessWidget {
  final bool isDark;
  final String text;

  const _NoteBox({required this.isDark, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline_rounded,
          size: 16,
          color: isDark ? Colors.white54 : Colors.black45,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black54,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
