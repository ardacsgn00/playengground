import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/games_screen.dart';
import 'feature_card.dart';

class OnboardingDialog extends StatefulWidget {
  final bool isInitialRoute;
  const OnboardingDialog({super.key, this.isInitialRoute = false});

  static const String prefKey = 'pref_onboarding_dont_show_again';
  static bool _sessionDismissed = false;

  /// Returns true if onboarding should be shown automatically on app open.
  static Future<bool> shouldShow() async {
    if (_sessionDismissed) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      try {
        await prefs.reload();
      } catch (_) {}

      final v1 = prefs.get(prefKey);
      final v2 = prefs.get('flutter.$prefKey');
      final v3 = prefs.get('${prefKey}_v2');
      final v4 = prefs.get('flutter.${prefKey}_v2');

      final bool dontShow = (v1 == true || v1 == 'true' || v1 == 1) ||
          (v2 == true || v2 == 'true' || v2 == 1) ||
          (v3 == true || v3 == 'true' || v3 == 1) ||
          (v4 == true || v4 == 'true' || v4 == 1);

      if (dontShow) {
        _sessionDismissed = true;
        return false;
      }
      return true;
    } catch (_) {
      return false; // Hata halinde kullanıcıyı her açılışta zorunlu onboarding'e sokma
    }
  }

  /// Sets whether the onboarding dialog should be hidden on future app opens.
  static Future<void> setDontShowAgain(bool value) async {
    _sessionDismissed = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefKey, value);
      await prefs.setBool('flutter.$prefKey', value);
      await prefs.setString('${prefKey}_v2', value ? 'true' : 'false');
      await prefs.setString('flutter.${prefKey}_v2', value ? 'true' : 'false');
    } catch (_) {}
  }

  /// Displays the full-screen onboarding.
  static Future<void> show(BuildContext context) async {
    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (context, animation, secondaryAnimation) =>
            const OnboardingDialog(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  /// Automatically displays onboarding on app startup if not marked "Bir daha gösterme".
  static Future<void> showIfFirstTime(BuildContext context) async {
    final should = await shouldShow();
    if (should && context.mounted) {
      await show(context);
    }
  }

  @override
  State<OnboardingDialog> createState() => _OnboardingDialogState();
}

class _OnboardingSlideData {
  final String badgeText;
  final Color accentColor;
  final String title;
  final String description;
  final List<String> bullets;
  final IconData icon;
  final bool useLogoHero;

  const _OnboardingSlideData({
    required this.badgeText,
    required this.accentColor,
    required this.title,
    required this.description,
    required this.bullets,
    required this.icon,
    this.useLogoHero = false,
  });
}

class _OnboardingDialogState extends State<OnboardingDialog> {
  late final PageController _pageController;
  int _currentPage = 0;

  static const double _desktopMaxWidth = 1040.0;

  static const List<_OnboardingSlideData> _slides = [
    _OnboardingSlideData(
      badgeText: 'EĞİTİCİ ARCADE',
      accentColor: Color(0xFF7C3AED),
      title: 'Oyun Oynayarak Öğrenin',
      description:
          'Sıkıcı ezberlere ve monoton testlere son verin! Hangman, Word Guess, Sentence Scramble ve 15 arcade oyunla kelimeleri, deyimleri ve phrasal verb\'leri oynayarak refleks haline getirin.',
      bullets: [
        '15 Farklı Eğitici Arcade Oyun',
        'Hızlı Refleks & Kalıcı Kelime Dağarcığı',
        'Her Yaşa ve Seviyeye Uygun Pratik',
      ],
      icon: Icons.sports_esports_rounded,
      useLogoHero: true,
    ),
    _OnboardingSlideData(
      badgeText: 'AKILLI TEKRAR SİSTEMİ',
      accentColor: Color(0xFFDB2777),
      title: 'Kişisel Hata Bankası',
      description:
          'Oyunlarda takıldığınız veya yanlış bildiğiniz kelimeler asla kaybolmaz! Otomatik olarak Hata Bankası\'nda depolanır; hatalarınızı sesli dinleyebilir ve seçtiğiniz oyuna aktarıp pekiştirebilirsiniz.',
      bullets: [
        'Yanlış Kelimeleri Otomatik Kaydetme',
        'Hataları Seçtiğin Oyuna Aktarıp Pekiştirme',
        'Sesli Telaffuz & Anında Tekrar',
      ],
      icon: FontAwesomeIcons.brain,
    ),
    _OnboardingSlideData(
      badgeText: 'MİKRO ÖĞRENME',
      accentColor: Color(0xFFF59E0B),
      title: 'Boş Zamanınızı Değerlendirin',
      description:
          'Otobüste, kahve molasında, durakta beklerken ya da dinlenirken... Sadece 2-3 dakikalık hızlı mini oyun turlarıyla gününüzün her anını akıcı bir dil pratiğine dönüştürün.',
      bullets: [
        '2-3 Dakikalık Hızlı Arcade Turları',
        'Günlük Seri (Streak) Takibi',
        'Günün Her Anında Anında Pratik',
      ],
      icon: FontAwesomeIcons.stopwatch,
    ),
    _OnboardingSlideData(
      badgeText: 'SIFIR KESİNTİ',
      accentColor: Color(0xFFDC2626),
      title: 'Tamamen Reklamsız',
      description:
          'Ekrana aniden fırlayan pop-up pencereler, zorunlu video reklamlar veya dikkatinizi dağıtan bannerlar ASLA yok. Sıfır kesintiyle sadece oyununuza ve öğrenmeye odaklanın.',
      bullets: [
        '0 Pop-up veya Araya Giren Reklam',
        '0 Zorunlu Video Tanıtımı veya Bekleme',
        'Kesintisiz Öğrenme Odaklı Tasarım',
      ],
      icon: FontAwesomeIcons.ban,
    ),
    _OnboardingSlideData(
      badgeText: '%100 AÇIK & ÜCRETSİZ',
      accentColor: Color(0xFF059669),
      title: 'Tamamen Ücretsiz',
      description:
          'Hiçbir gizli abonelik, kilitli oyun seviyesi ya da deneme süresi ücreti bulunmaz. PlayEngGround\'daki tüm oyunlar ve zengin kelime havuzları herkese baştan sona %100 açıktır.',
      bullets: [
        'Gizli Ücret veya Abonelik Kesinlikle Yok',
        'Kilitli Oyun veya Premium Bölüm Yok',
        'Tüm İçerik ve Özellikler Herkese Açık',
      ],
      icon: FontAwesomeIcons.gift,
    ),
    _OnboardingSlideData(
      badgeText: 'GİZLİLİK & GÜVENLİK',
      accentColor: Color(0xFF2563EB),
      title: 'Kişisel Veri Saklanmıyor',
      description:
          'Kayıt olma, e-posta verme veya şifre oluşturma şartı yok! Skorlarınız, ayarlarınız ve oyun ilerlemeniz yalnızca kendi cihazınızda saklanır.',
      bullets: [
        'Kullanıcı Girişi veya Hesap Şartı Yok',
        'Tüm Veriler Yalnızca Kendi Cihazınızda',
        '%100 Gizlilik ve Yerel Veri Saklama',
      ],
      icon: FontAwesomeIcons.userShield,
    ),
    _OnboardingSlideData(
      badgeText: 'CEFR STANDARTLARI',
      accentColor: Color(0xFF7C3AED),
      title: 'A1–B2 Seviye Dağılımı',
      description:
          'İster temel İngilizce (A1–A2) ister orta-ileri düzey (B1–B2) kelimelerle çalışın. Oyun içi filtre butonuyla soru havuzunu tam kendi seviyenize göre filtreleyebilirsiniz.',
      bullets: [
        'A1–A2 Temel Düzey Günlük Kelimeler',
        'B1–B2 Orta–İleri Düzey Kelimeler',
        'Oyun İçi Tek Dokunuşla Seviye Filtresi',
      ],
      icon: FontAwesomeIcons.layerGroup,
    ),
  ];

  static int get _totalPages => _slides.length;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _navigateAway() {
    if (widget.isInitialRoute) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const GamesScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 350),
        ),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  void _handleDismiss() {
    HapticFeedback.lightImpact();
    OnboardingDialog.setDontShowAgain(true);
    if (mounted) {
      _navigateAway();
    }
  }

  Future<void> _dontShowAgainAndDismiss() async {
    HapticFeedback.mediumImpact();
    await OnboardingDialog.setDontShowAgain(true);
    if (!mounted) return;
    _navigateAway();
    final screenWidth = MediaQuery.of(context).size.width;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        width: screenWidth > 600 ? 460 : null,
        margin: screenWidth > 600
            ? null
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Tanıtım rehberi bir daha açılışta gösterilmeyecek.',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF7C3AED),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _onFinishPressed() async {
    HapticFeedback.selectionClick();
    await OnboardingDialog.setDontShowAgain(true);
    if (mounted) {
      _navigateAway();
    }
  }

  void _nextPage() {
    HapticFeedback.selectionClick();
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      _onFinishPressed();
    }
  }

  void _prevPage() {
    HapticFeedback.selectionClick();
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 760;
    final currentSlide = _slides[_currentPage];

    return PopScope(
      canPop: !widget.isInitialRoute,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && widget.isInitialRoute) {
          _handleDismiss();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D14),
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(isMobile),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _totalPages,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemBuilder: (context, index) {
                    return _buildPage(
                      isMobile: isMobile,
                      slide: _slides[index],
                    );
                  },
                ),
              ),
              _buildBottomBar(isMobile, currentSlide.accentColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isMobile) {
    final double logoHeight = isMobile ? 80.0 : 120.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: isMobile ? 8 : 12,
        bottom: isMobile ? 4 : 6,
        left: isMobile ? 16 : 32,
        right: isMobile ? 16 : 32,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _desktopMaxWidth),
          child: SizedBox(
            width: double.infinity,
            height: logoHeight,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Center(
                  child: Image.asset(
                    'assets/logo/playengground logo.png',
                    height: logoHeight,
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    filterQuality: FilterQuality.high,
                  ),
                ),
                Positioned(
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.only(bottom: 3.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E0E1B),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.28),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Material(
                      color: const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: _handleDismiss,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 12 : 16,
                            vertical: isMobile ? 7 : 9,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFF2E2E4A),
                              width: 1.3,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Atla',
                                style: GoogleFonts.outfit(
                                  fontSize: isMobile ? 12.5 : 14,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: isMobile ? 15 : 17,
                                color: Colors.white70,
                              ),
                            ],
                          ),
                        ),
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
  }

  Widget _buildPage({
    required bool isMobile,
    required _OnboardingSlideData slide,
  }) {
    final lipColor = FeatureCard.darken(slide.accentColor, 0.18);

    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 20 : 40,
          vertical: isMobile ? 12 : 24,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isMobile ? 540 : _desktopMaxWidth,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Tactile 3D Colored Hero Icon Box
              Container(
                padding: const EdgeInsets.only(bottom: 5.5),
                decoration: BoxDecoration(
                  color: lipColor,
                  borderRadius: BorderRadius.circular(isMobile ? 26 : 32),
                  boxShadow: [
                    BoxShadow(
                      color: slide.accentColor.withValues(alpha: 0.28),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Container(
                  width: isMobile ? 84 : 112,
                  height: isMobile ? 84 : 112,
                  decoration: BoxDecoration(
                    color: slide.accentColor,
                    borderRadius: BorderRadius.circular(isMobile ? 24 : 30),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22),
                      width: 1.5,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Subtle top gloss inside icon box
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: isMobile ? 34 : 46,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(isMobile ? 23 : 29),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha: 0.20),
                                Colors.white.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                      slide.useLogoHero
                          ? Padding(
                              padding: EdgeInsets.all(isMobile ? 10 : 13),
                              child: Image.asset(
                                'assets/logo/gamepad_white_hero.png',
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                              ),
                            )
                          : Icon(
                              slide.icon,
                              size: isMobile ? 38 : 50,
                              color: Colors.white,
                            ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: isMobile ? 16 : 22),

              // 2. Category Badge & Page Indicators
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 14 : 18,
                  vertical: isMobile ? 5 : 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF16162A),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: slide.accentColor.withValues(alpha: 0.45),
                    width: 1.2,
                  ),
                ),
                child: Text(
                  slide.badgeText,
                  style: GoogleFonts.outfit(
                    fontSize: isMobile ? 11 : 12.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Page Indicator Dots (with Prev/Next chevrons on Desktop)
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!isMobile)
                    IconButton(
                      onPressed: _currentPage > 0 ? _prevPage : null,
                      icon: const Icon(Icons.chevron_left_rounded, size: 22),
                      color: _currentPage > 0
                          ? const Color(0xFFA1A1AA)
                          : const Color(0xFF2A2A4A),
                      splashRadius: 18,
                      tooltip: 'Önceki',
                    ),
                  ...List.generate(_totalPages, (index) {
                    final isSelected = index == _currentPage;
                    return GestureDetector(
                      onTap: () {
                        _pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isSelected ? 28 : 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? slide.accentColor
                              : const Color(0xFF2A2A4A),
                          borderRadius: BorderRadius.circular(4.5),
                        ),
                      ),
                    );
                  }),
                  if (!isMobile)
                    IconButton(
                      onPressed: _currentPage < _totalPages - 1
                          ? _nextPage
                          : null,
                      icon: const Icon(Icons.chevron_right_rounded, size: 22),
                      color: _currentPage < _totalPages - 1
                          ? const Color(0xFFA1A1AA)
                          : const Color(0xFF2A2A4A),
                      splashRadius: 18,
                      tooltip: 'Sonraki',
                    ),
                ],
              ),
              SizedBox(height: isMobile ? 16 : 22),

              // 3. Clean Title & Description on Dark Background
              Text(
                slide.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: isMobile ? 24 : 36,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Text(
                  slide.description,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: isMobile ? 13.5 : 16.5,
                    color: const Color(0xFF94A3B8),
                    height: 1.5,
                  ),
                ),
              ),
              SizedBox(height: isMobile ? 22 : 34),

              // 4. Tactile 3D Colored Feature Bullet Cards
              if (!isMobile)
                Row(
                  children: [
                    for (int i = 0; i < slide.bullets.length; i++) ...[
                      if (i > 0) const SizedBox(width: 16),
                      Expanded(
                        child: _buildTactileBulletCard(
                          text: slide.bullets[i],
                          accentColor: slide.accentColor,
                          lipColor: lipColor,
                          isMobile: false,
                        ),
                      ),
                    ],
                  ],
                )
              else
                Column(
                  children: [
                    for (int i = 0; i < slide.bullets.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      _buildTactileBulletCard(
                        text: slide.bullets[i],
                        accentColor: slide.accentColor,
                        lipColor: lipColor,
                        isMobile: true,
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTactileBulletCard({
    required String text,
    required Color accentColor,
    required Color lipColor,
    required bool isMobile,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 4.5),
      decoration: BoxDecoration(
        color: lipColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 20,
          vertical: isMobile ? 12 : 18,
        ),
        decoration: BoxDecoration(
          color: accentColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.18),
            width: 1.2,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: isMobile ? 26 : 32,
              height: isMobile ? 26 : 32,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
              ),
              child: Icon(
                Icons.check_rounded,
                size: isMobile ? 16 : 20,
                color: lipColor,
              ),
            ),
            SizedBox(width: isMobile ? 12 : 14),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.outfit(
                  fontSize: isMobile ? 13.5 : 14.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(bool isMobile, Color activeColor) {
    final isLast = _currentPage == _totalPages - 1;
    final activeLipColor = FeatureCard.darken(activeColor, 0.18);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 40,
        vertical: isMobile ? 12 : 16,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF16162A),
        border: Border(top: BorderSide(color: Color(0xFF2A2A4A), width: 1.0)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _desktopMaxWidth),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Tactile 3D "Bir daha gösterme" Button
              Flexible(
                child: Container(
                  padding: const EdgeInsets.only(bottom: 3.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E0E1B),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Material(
                    color: const Color(0xFF1E1E34),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: _dontShowAgainAndDismiss,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 12 : 18,
                          vertical: isMobile ? 9.5 : 11.5,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF3A3A5E),
                            width: 1.2,
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.visibility_off_rounded,
                                size: isMobile ? 15 : 17,
                                color: const Color(0xFFC4B5FD),
                              ),
                              const SizedBox(width: 7),
                              Text(
                                'Bir daha gösterme',
                                style: GoogleFonts.outfit(
                                  fontSize: isMobile ? 12.5 : 14,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFE2E8F0),
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
              const SizedBox(width: 10),
              // Navigation Actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isMobile && _currentPage > 0) ...[
                    Container(
                      padding: const EdgeInsets.only(bottom: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E0E1B),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Material(
                        color: const Color(0xFF1E1E34),
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          onTap: _prevPage,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 11.5,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFF3A3A5E),
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.arrow_back_rounded,
                                  size: 16,
                                  color: Colors.white70,
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  'Önceki',
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  // Tactile 3D Primary Action Button
                  Container(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    decoration: BoxDecoration(
                      color: activeLipColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Material(
                      color: activeColor,
                      borderRadius: BorderRadius.circular(15),
                      child: InkWell(
                        onTap: _nextPage,
                        borderRadius: BorderRadius.circular(15),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 18 : 26,
                            vertical: isMobile ? 10 : 12,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  isLast ? 'Hemen Başla 🚀' : 'Devam Et',
                                  style: GoogleFonts.outfit(
                                    fontSize: isMobile ? 13.5 : 15,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                if (!isLast) ...[
                                  const SizedBox(width: 7),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
