import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacyPolicyDialog extends StatelessWidget {
  const PrivacyPolicyDialog({super.key});

  static Future<void> show(BuildContext context) async {
    HapticFeedback.lightImpact();
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => const PrivacyPolicyDialog(),
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
      contentPadding: EdgeInsets.all(isMobile ? 16 : 22),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Header: Icon + Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    color: Color(0xFF10B981),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gizlilik Politikası',
                        style: GoogleFonts.outfit(
                          fontSize: isMobile ? 18 : 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'PlayEngGround • Sürüm v0.4.9',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white60),
                  splashRadius: 20,
                  tooltip: 'Kapat',
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(color: Color(0xFF2A2A4A), height: 1),
            const SizedBox(height: 12),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Taahhüt Kartı
                    _buildHighlightBanner(
                      icon: Icons.verified_user_rounded,
                      color: const Color(0xFF10B981),
                      title: 'Sıfır Kişisel Veri İlkesi',
                      description:
                          'PlayEngGround, tamamen ücretsiz, reklamsız ve üyeliksiz bir İngilizce pratik platformudur. Adınız, e-postanız veya kimliğiniz asla istenmez ve toplanmaz.',
                    ),
                    const SizedBox(height: 14),

                    // Toplanmayan Veriler
                    _buildSectionHeader(
                      '1. Toplanmayan Veriler (Kişisel Gizlilik Güvencesi)',
                      const Color(0xFFEF4444),
                    ),
                    const SizedBox(height: 8),
                    _buildBulletItem(
                      'Kişisel Kimlik Bilgileri:',
                      'Ad, soyad, e-posta adresi, telefon numarası veya şifre toplanmaz. Hesap açma zorunluluğu yoktur.',
                      Icons.no_accounts_rounded,
                      const Color(0xFFEF4444),
                    ),
                    _buildBulletItem(
                      'Konum Verileri:',
                      'GPS, IP tabanlı hassas coğrafi konum bilgisi kesinlikle alınmaz.',
                      Icons.location_off_rounded,
                      const Color(0xFFEF4444),
                    ),
                    _buildBulletItem(
                      'Kamera & Mikrofon:',
                      'Kameranıza veya mikrofonunuza erişilmez; hiçbir ses veya görüntü kaydı yapılmaz.',
                      Icons.mic_off_rounded,
                      const Color(0xFFEF4444),
                    ),
                    _buildBulletItem(
                      'Ödeme ve Finansal Bilgiler:',
                      'Kredi kartı veya banka bilgisi toplanmaz; uygulama tamamen ücretsizdir.',
                      Icons.money_off_rounded,
                      const Color(0xFFEF4444),
                    ),
                    _buildBulletItem(
                      'Kişisel Oyun & Hata Geçmişi:',
                      'Hata defteriniz ve ses/tema ayarlarınız yalnızca kendi cihazınızda (tarayıcınızın yerel depolama alanında) tutulur; harici bir sunucuya kişisel kimliğinizle aktarılmaz.',
                      Icons.storage_rounded,
                      const Color(0xFFEF4444),
                    ),
                    const SizedBox(height: 16),

                    // Toplanan Anonim Teknik Veriler
                    _buildSectionHeader(
                      '2. Toplanan Anonim Teknik Veriler (Neden Toplanır?)',
                      const Color(0xFF38BDF8),
                    ),
                    const SizedBox(height: 8),
                    _buildBulletItem(
                      'Rastgele Cihaz Kimliği (deviceId):',
                      'Tamamen rastgele ve kişisel olmayan bir UUID üretilerek tekil oturum istatistikleri için kullanılır.',
                      Icons.fingerprint_rounded,
                      const Color(0xFF38BDF8),
                    ),
                    _buildBulletItem(
                      'Cihaz & İşletim Sistemi:',
                      'Mobil, tablet veya masaüstü uyumluluğunu test etmek için cihaz türü ve işletim sistemi (Windows, iOS, Android vb.) kaydedilir.',
                      Icons.devices_rounded,
                      const Color(0xFF38BDF8),
                    ),
                    _buildBulletItem(
                      'Tarayıcı & Ekran Çözünürlüğü:',
                      'Oyunların farklı ekran boyutlarında taşmasını engellemek ve TTS ses uyumluluğunu optimize etmek için taranır.',
                      Icons.aspect_ratio_rounded,
                      const Color(0xFF38BDF8),
                    ),
                    _buildBulletItem(
                      'Anonim Ziyaret Sayacı:',
                      'Platformun genel sunucu yükünü ve kullanım yoğunluğunu ölçmek için anonim ziyaret zaman damgası tutulur.',
                      Icons.analytics_rounded,
                      const Color(0xFF38BDF8),
                    ),
                    const SizedBox(height: 16),

                    // Seslendirme (TTS) Güvenliği
                    _buildSectionHeader(
                      '3. Seslendirme (TTS) ve Web Teknolojileri',
                      const Color(0xFFF59E0B),
                    ),
                    const SizedBox(height: 8),
                    _buildInfoCard(
                      'İngilizce kelime ve deyim telaffuzları, cihazınızın ve tarayıcınızın kendi yerel Konuşma Sentezi (Web Speech Synthesis API) motoru tarafından istemci tarafında üretilir. Ses verileriniz dinlenmez veya kaydedilmez.',
                    ),
                    const SizedBox(height: 16),

                    // Veri Güvenliği ve Üçüncü Taraflar
                    _buildSectionHeader(
                      '4. Veri Güvenliği ve Üçüncü Taraflar',
                      const Color(0xFFA78BFA),
                    ),
                    const SizedBox(height: 8),
                    _buildInfoCard(
                      '• Teknik analiz verileri Google Firebase altyapısında SSL şifrelemeli olarak barındırılır.\n'
                      '• Hiçbir veri reklam verenlerle, veri tüccarlarıyla veya üçüncü taraf kuruluşlarla satılmaz, kiralanmaz veya paylaşılmaz.\n'
                      '• Uygulama içerisinde üçüncü taraf reklam izleyicileri veya pazarlama çerezleri bulunmaz.',
                    ),
                    const SizedBox(height: 16),

                    // Kullanıcı Hakları & Sıfırlama
                    _buildSectionHeader(
                      '5. Verilerinizi Sıfırlama ve Kontrol Hakkı',
                      const Color(0xFF34D399),
                    ),
                    const SizedBox(height: 8),
                    _buildInfoCard(
                      'Cihazınızda yerel olarak saklanan Hata Bankası kayıtlarını ve tercihlerinizi, tarayıcınızın "Önbelleği ve Site Verilerini Temizle" seçeneğini kullanarak dilediğiniz an tek tıkla silebilirsiniz.',
                    ),
                    const SizedBox(height: 16),

                    // İletişim
                    _buildSectionHeader(
                      '6. İletişim ve Geliştirici',
                      const Color(0xFFEC4899),
                    ),
                    const SizedBox(height: 8),
                    _buildInfoCard(
                      'Geliştirici: Arda Coşgun\n'
                      'Gizlilik politikasıyla ilgili soru, öneri veya geri bildirimleriniz için portföy sitemiz (ardacosgun.web.app) üzerinden doğrudan iletişime geçebilirsiniz.',
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),
            const Divider(color: Color(0xFF2A2A4A), height: 1),
            const SizedBox(height: 12),

            // Bottom Action: Anladım Button
            Container(
              padding: const EdgeInsets.only(bottom: 3.5),
              decoration: BoxDecoration(
                color: const Color(0xFF047857),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Material(
                color: const Color(0xFF10B981),
                borderRadius: BorderRadius.circular(15),
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    child: Text(
                      'Anladım, Kapat',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightBanner({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    height: 1.35,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 3.5,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBulletItem(
    String label,
    String desc,
    IconData icon,
    Color iconColor,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7.0, left: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Icon(icon, size: 14, color: iconColor.withValues(alpha: 0.85)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.outfit(fontSize: 12, height: 1.35, color: Colors.white70),
                children: [
                  TextSpan(
                    text: '$label ',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  TextSpan(text: desc),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String text) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2E2E4A), width: 1.0),
      ),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 12,
          height: 1.4,
          color: Colors.white70,
        ),
      ),
    );
  }
}

