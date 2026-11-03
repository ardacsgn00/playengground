import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/pwa_install_service.dart';
import 'pwa_install_button.dart';

class PwaPromptDialog extends StatelessWidget {
  const PwaPromptDialog({super.key});

  static const String prefDontShowAgainKey = 'pref_pwa_popup_dont_show_again';
  static bool _sessionShown = false;

  /// Bu oturumda veya kalıcı olarak gösterilmemesi gerekip gerekmediğini kontrol eder.
  static Future<bool> shouldShow() async {
    // Web harici platformlarda gösterme
    if (!kIsWeb) return false;

    // Bu oturumda zaten gösterildiyse tekrar rahatsız etme
    if (_sessionShown) return false;

    // Zaten PWA kurulu/standalone moddaysa gösterme
    if (PwaInstallService.instance.isInstalled) return false;

    try {
      final prefs = await SharedPreferences.getInstance();
      final dontShow = prefs.getBool(prefDontShowAgainKey) ?? false;
      if (dontShow) return false;
    } catch (_) {
      return false;
    }

    return true;
  }

  /// Belirli bir olasılıkla (örn. %35-%40) rastgele tetikler.
  static Future<void> maybeShowRandomly(
    BuildContext context, {
    double probability = 0.35,
  }) async {
    // Rastgelelik kontrolü
    if (Random().nextDouble() > probability) return;

    final canShow = await shouldShow();
    if (!canShow) return;

    if (!context.mounted) return;

    _sessionShown = true;
    await show(context);
  }

  /// Diyaloğu ekranda gösterir.
  static Future<void> show(BuildContext context) async {
    HapticFeedback.lightImpact();
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => const PwaPromptDialog(),
    );
  }

  Future<void> _handleDontShowAgain(BuildContext context) async {
    HapticFeedback.mediumImpact();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefDontShowAgainKey, true);
    } catch (_) {}

    if (!context.mounted) return;
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Yükleme hatırlatıcısı bir daha gösterilmeyecek.',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E1E34),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _handleInstall(BuildContext context) async {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop();

    final pwa = PwaInstallService.instance;

    // iOS cihazlarda Safari yönergesi
    if (pwa.isIos) {
      await showInstallGuideDialog(context, platform: InstallGuidePlatform.ios);
      return;
    }

    // Doğrudan browser native prompt desteği
    if (pwa.canPrompt) {
      final outcome = await pwa.prompt();
      if (!context.mounted) return;
      if (outcome == 'accepted') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF1E1E34),
            content: Row(
              children: [
                const Icon(Icons.install_mobile_rounded, color: Color(0xFF10B981), size: 20),
                const SizedBox(width: 10),
                Text(
                  'PlayEngGround yükleniyor 🎉',
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        );
      }
      return;
    }

    // Desteklenmeyen veya manuel gereken tarayıcılarda rehber aç
    await showInstallGuideDialog(
      context,
      platform: pwa.isAndroid
          ? InstallGuidePlatform.android
          : InstallGuidePlatform.desktop,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return AlertDialog(
      backgroundColor: const Color(0xFF16162A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(
          color: Color(0xFF2A2A4A),
          width: 1.2,
        ),
      ),
      contentPadding: EdgeInsets.all(isMobile ? 18 : 22),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 350),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Rozet: Flat, gradyansız
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                    width: 1.0,
                  ),
                ),
                child: Text(
                  'UYGULAMA OLARAK KULLAN',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: const Color(0xFF8B5CF6),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Logo (Kutusuz & sınırsız, saf logo)
              Image.asset(
                'assets/logo/kare logo.png',
                width: 64,
                height: 64,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 12),

              // Başlık
              Text(
                'PlayEngGround\'ı Cihazına Yükle',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: isMobile ? 17.5 : 19,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),

              // Açıklama
              Text(
                'Tarayıcı çubukları olmadan tam ekran oyna, ana ekranından tek dokunuşla oyunlarına anında ulaş.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: isMobile ? 12 : 13,
                  color: const Color(0xFF94A3B8),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),

              // Sade Avantaj Maddeleri (Gradyansız, kompakt)
              _buildFeatureRow(
                icon: Icons.fullscreen_rounded,
                text: 'Tam ekran & dikkat dağıtmayan deneyim',
              ),
              const SizedBox(height: 7),
              _buildFeatureRow(
                icon: Icons.touch_app_rounded,
                text: 'Ana ekrandan tek dokunuşla hızlı açılış',
              ),
              const SizedBox(height: 7),
              _buildFeatureRow(
                icon: Icons.speed_rounded,
                text: 'Düşük gecikme & yüksek akıcılık',
              ),
              const SizedBox(height: 18),

              // 1. Sıra: Yükle Butonu (Geniş & Belirgin)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _handleInstall(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.download_rounded, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Yükle',
                        style: GoogleFonts.outfit(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // 2. Sıra: Daha Sonra Butonu
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFA1A1AA),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Daha Sonra',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // 3. Sıra: Bir daha gösterme (Aynı ufaklıkta)
              InkWell(
                onTap: () => _handleDontShowAgain(context),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.visibility_off_outlined,
                        size: 13,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Bir daha gösterme',
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7.5),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF2A2A4A),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF8B5CF6)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFFE2E8F0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
