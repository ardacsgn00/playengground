import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/analytics_service.dart';
import 'admin_stats_screen.dart';

import '../widgets/feature_card.dart';
import '../widgets/pwa_prompt_dialog.dart';
import '../widgets/privacy_policy_dialog.dart';
import '../widgets/animated_hover_wrapper.dart';
import 'hangman_screen.dart';
import 'memory_card_screen.dart';
import 'wordle_screen.dart';
import 'sound_catch_screen.dart';
import 'word_chain_game_screen.dart';
import 'meaning_sniper_screen.dart';
import 'category_trap_screen.dart';
import 'sentence_scramble_screen.dart';
import 'word_detective_screen.dart';
import 'word_hunt_screen.dart';
import 'idiom_runner_screen.dart';
import 'penalty_game.dart';
import 'collocation_magnet_screen.dart';
import 'word_defuser_screen.dart';
import 'phrasal_rocket_screen.dart';
import '../services/audio_manager.dart';
import '../services/mistake_service.dart';
import '../services/score_service.dart';
import '../services/streak_service.dart';
import '../services/settings_service.dart';
import '../data/motivational_quotes.dart';
import '../widgets/onboarding_dialog.dart';
import 'mistake_bank_screen.dart';

enum ViewMode { grid, list, carousel }

class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key});

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GameItem {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget Function(BuildContext) builder;
  final String description;
  final String? topicBadge;

  const _GameItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.builder,
    required this.description,
    this.topicBadge,
  });
}

class _GamesScreenState extends State<GamesScreen> {
  ViewMode? _userSelectedViewMode;
  late final PageController _pageController;

  static const int _kLoopFactor = 1000;
  int get _loopTotalCount =>
      _activeGames.isEmpty ? 0 : _activeGames.length * _kLoopFactor;
  int get _initialPage {
    if (_activeGames.isEmpty) return 0;
    final half = _loopTotalCount ~/ 2;
    return half - (half % _activeGames.length);
  }

  ViewMode _effectiveViewMode(bool isMobile) =>
      _userSelectedViewMode ?? (isMobile ? ViewMode.carousel : ViewMode.grid);

  List<_GameItem> get _activeGames => _games;

  final List<_GameItem> _games = [
    _GameItem(
      id: 'collocation_magnet',
      title: 'Collocation Magnet',
      subtitle: 'MAKE mi DO mu? Doğru fiile kaydır!',
      icon: FontAwesomeIcons.magnet,
      color: const Color(0xFF0284C7),
      topicBadge: 'COLLOCATIONS',
      builder: (_) => const CollocationMagnetScreen(),
      description:
          '"___ the dishes" boşluğuna hangi fiil gelir? Kartı doğru fiilin tarafına (sola/sağa) kaydır ya da alt butonlara dokun. Make/Do, Say/Tell, Take/Have gibi sık kullanılan kalıpları eğlenerek öğren!',
    ),
    _GameItem(
      id: 'word_defuser',
      title: 'Word Defuser',
      subtitle: 'Bomba patlamadan doğru kabloyu kes!',
      icon: FontAwesomeIcons.bomb,
      color: const Color(0xFFDC2626),
      topicBadge: 'SPELLING & VOCAB',
      builder: (_) => const WordDefuserScreen(),
      description:
          'Zamana karşı bomba imha uzmanı ol! Paneldeki göreve göre (yazım hatası, zıt/eş anlam veya Türkçe karşılık) doğru kabloyu seç ve patlamadan önce bombayı etkisiz hale getir.',
    ),
    _GameItem(
      id: 'phrasal_rocket',
      title: 'Phrasal Rocket',
      subtitle: 'Doğru edatla rokete yakıt sağla!',
      icon: FontAwesomeIcons.rocket,
      color: const Color(0xFF7C3AED),
      topicBadge: 'PHRASAL VERBS',
      builder: (_) => const PhrasalRocketScreen(),
      description:
          'Cümledeki phrasal verb boşluğunu doğru edatla (up, out, off...) tamamlayarak roketine yakıt sağla, irtifa kazan ve atmosferi aşıp Ay\'a ulaş!',
    ),
    _GameItem(
      id: 'hangman',
      title: 'Hangman',
      subtitle: 'Harfleri tahmin et, adamı kurtar!',
      icon: FontAwesomeIcons.personThroughWindow,
      color: const Color(0xFFE11D48),
      topicBadge: 'VOCABULARY',
      builder: (_) => const HangmanGameScreen(),
      description:
          'Klasik adam asmaca heyecanı! Canların tükenmeden gizli İngilizce kelimeyi harf harf tahmin et; takıldığında ipuçlarından yararlanarak kelimeyi çöz.',
    ),
    _GameItem(
      id: 'memory_match',
      title: 'Memory Match',
      subtitle: 'İngilizce & Türkçe kelimeleri eşleştir!',
      icon: FontAwesomeIcons.layerGroup,
      color: const Color(0xFF2563EB),
      topicBadge: 'VOCABULARY',
      builder: (_) => const MemoryGameScreen(),
      description:
          'Kartların arkasında gizlenen İngilizce kelimeler ile Türkçe karşılıklarını hafızanda tutarak eşleştir. En az hamleyle tüm çiftleri tamamla!',
    ),
    _GameItem(
      id: 'wordle',
      title: 'Word Guess',
      subtitle: '6 denemede 5 harfli gizli kelimeyi bul!',
      icon: FontAwesomeIcons.tableCells,
      color: const Color(0xFF059669),
      topicBadge: 'WORD PUZZLE',
      builder: (_) => const WordleScreen(),
      description:
          'Wordle tarzı kelime bulmaca! 5 harfli gizli İngilizce kelimeyi 6 denemede tahmin et; yeşil ve sarı renkli ipuçlarını takip ederek hedefe ulaş.',
    ),
    _GameItem(
      id: 'sound_catch',
      title: 'Sound Catch',
      subtitle: 'Sesi dinle, benzer kelimelerden doğruyu yakala!',
      icon: FontAwesomeIcons.headphones,
      color: const Color(0xFFD97706),
      topicBadge: 'LISTENING & PHONICS',
      builder: (_) => const SoundCatchScreen(),
      description:
          'Kulak ve telaffuz refleksi! Telaffuz edilen İngilizce kelimeyi dinle; sesi birbirine çok benzeyen veya kafiyeli 4 seçenek arasından doğru olanı yakala.',
    ),
    _GameItem(
      id: 'word_chain',
      title: 'Word Chain',
      subtitle: 'Son harften yeni kelime türet, zinciri uzat!',
      icon: FontAwesomeIcons.link,
      color: const Color(0xFF0891B2),
      topicBadge: 'VOCABULARY',
      builder: (_) => const WordChainGameScreen(),
      description:
          'Bir önceki İngilizce kelimenin son harfiyle başlayan yeni ve geçerli kelimeler türeterek süre bitmeden kelime zincirini uzat.',
    ),
    _GameItem(
      id: 'meaning_sniper',
      title: 'Meaning Sniper',
      subtitle: 'Hedefteki Türkçe kelimeyi hızla vur!',
      icon: FontAwesomeIcons.crosshairs,
      color: const Color(0xFF16A34A),
      topicBadge: 'VOCABULARY & MEANING',
      builder: (_) => const MeaningSniperScreen(),
      description:
          'Hedefteki Türkçe kelimenin doğru İngilizce karşılığına hızla kilitlen ve vur! Klavyeden [1-4] tuşlarıyla ya da dokunarak nişan al, kombolarla puanını katla.',
    ),
    _GameItem(
      id: 'category_trap',
      title: 'Category Trap',
      subtitle: 'Kategoriye ait mi? Kapandan kaç!',
      icon: FontAwesomeIcons.skullCrossbones,
      color: const Color(0xFFEA580C),
      topicBadge: 'VOCABULARY',
      builder: (_) => const CategoryTrapScreen(),
      description:
          'Ekrana gelen İngilizce kelimenin belirtilen kategoriye ait olup olmadığına hızla karar ver. Kapana yakalanmadan doğru seçimler yaparak canlarını koru.',
    ),
    _GameItem(
      id: 'sentence_scramble',
      title: 'Sentence Scramble',
      subtitle: 'Karışık kelimeleri doğru sıraya diz!',
      icon: FontAwesomeIcons.arrowDownShortWide,
      color: const Color(0xFF4F46E5),
      topicBadge: 'GRAMMAR & SYNTAX',
      builder: (_) => const SentenceScrambleScreen(),
      description:
          'Karışık sırada verilen kelimeleri İngilizce dilbilgisi kurallarına göre doğru sıraya dizerek anlamlı ve kurallı cümleler oluştur.',
    ),
    _GameItem(
      id: 'word_detective',
      title: 'Word Detective',
      subtitle: 'İpuçlarını çöz, gizemli kelimeyi bul!',
      icon: FontAwesomeIcons.magnifyingGlass,
      color: const Color(0xFFB45309),
      topicBadge: 'SPELLING & DEDUCTION',
      builder: (_) => const WordDetectiveScreen(),
      description:
          'Bir dedektif gibi ipuçlarını takip et! Anlamı ve harf sayısı verilen İngilizce kelimedeki eksik harfleri tamamlayarak vakayı çöz.',
    ),
    _GameItem(
      id: 'word_hunt',
      title: 'Word Hunt',
      subtitle: 'Harf ızgarasında gizli kelimeleri avla!',
      icon: FontAwesomeIcons.binoculars,
      color: const Color(0xFF0D9488),
      topicBadge: 'VOCABULARY',
      builder: (_) => const WordHuntScreen(),
      description:
          'Harf ızgarasında sağa, sola, yukarı, aşağı veya çapraz olarak gizlenmiş İngilizce kelimeleri dikkatle ara ve parmağınla işaretle.',
    ),
    _GameItem(
      id: 'idiom_runner',
      title: 'Idiom Driver',
      subtitle: 'Pistte yarış, deyimi tamamla!',
      icon: FontAwesomeIcons.car,
      color: const Color(0xFFDB2777),
      topicBadge: 'IDIOMS',
      builder: (_) => const IdiomRunnerScreen(),
      description:
          'Pistte engellere çarpmadan yarış! Ekranda gösterilen İngilizce deyimin eksik parçasını içeren doğru kapıdan geçerek deyimleri tamamla.',
    ),
    _GameItem(
      id: 'penalty',
      title: 'Word Penalty',
      subtitle: 'Doğru köşeye vur, golü at!',
      icon: FontAwesomeIcons.futbol,
      color: const Color(0xFF15803D),
      topicBadge: 'VOCABULARY',
      builder: (_) => const PenaltyGameScreen(),
      description:
          'Futbol ve İngilizce bir arada! Şut çekerken sorulan kelimenin doğru karşılığı olan köşeye vurup gol at ya da kaleci olup doğru köşeye uzanarak şutları kurtar.',
    ),
  ];

  late String _currentMotivationalQuote;
  Timer? _quoteRotateTimer;

  @override
  void initState() {
    super.initState();
    // Sayfa yenilendiğinde veya ilk açılışta hataların ve skorların yüklendiğinden emin ol
    _initServices();
    _currentMotivationalQuote = MotivationalQuotes.getRandomQuote();
    _startQuoteRotateTimer();
    _pageController = PageController(
      initialPage: _initialPage,
      viewportFraction: 0.85,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted) {
          AnalyticsService.instance.recordVisit(context, appVersion: 'v0.4.9');
          // Ana sayfaya girişte %35 olasılıkla PWA yükleme daveti
          Future.delayed(const Duration(milliseconds: 1400), () {
            if (mounted) {
              PwaPromptDialog.maybeShowRandomly(context, probability: 0.35);
            }
          });
        }
      });
    });
  }

  Future<void> _initServices() async {
    await StreakService.instance.init();
    await MistakeService.instance.init();
    await ScoreService.instance.init();
    await SettingsService.instance.init();
  }

  int _logoTapCount = 0;
  DateTime _lastLogoTapTime = DateTime.fromMillisecondsSinceEpoch(0);

  void _onLogoTap() {
    final now = DateTime.now();
    if (now.difference(_lastLogoTapTime).inMilliseconds > 2000) {
      _logoTapCount = 1;
    } else {
      _logoTapCount++;
    }
    _lastLogoTapTime = now;

    if (_logoTapCount >= 5) {
      _logoTapCount = 0;
      HapticFeedback.heavyImpact();
      _showSecretCodeDialog();
    }
  }

  void _showSecretCodeDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => const _SecretPinDialog(),
    );
  }

  void _startQuoteRotateTimer() {
    _quoteRotateTimer?.cancel();
    _quoteRotateTimer = Timer.periodic(const Duration(seconds: 7), (timer) {
      if (mounted && MistakeService.instance.hasMistakes) {
        setState(() {
          _currentMotivationalQuote = MotivationalQuotes.getRandomQuote(
            exclude: _currentMotivationalQuote,
          );
        });
      }
    });
  }

  Future<void> _onReturnToHome() async {
    if (!mounted) return;
    await MistakeService.instance.init();
    if (!mounted) return;
    setState(() {
      _currentMotivationalQuote = MotivationalQuotes.getRandomQuote(
        exclude: _currentMotivationalQuote,
      );
    });
    _startQuoteRotateTimer();
    // Oyun sonrasında ana ekrana dönüşte %40 olasılıkla PWA yükleme daveti
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) {
        PwaPromptDialog.maybeShowRandomly(context, probability: 0.40);
      }
    });
  }

  Future<void> _navigateToScreen(
    Widget Function(BuildContext) builder, {
    bool isGame = false,
  }) async {
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: builder));
    await _onReturnToHome();
  }

  void _launchRandomGame() {
    if (_activeGames.isEmpty) return;
    final randomGame = _activeGames[Random().nextInt(_activeGames.length)];
    _navigateToScreen(randomGame.builder, isGame: true);
  }

  @override
  void dispose() {
    _quoteRotateTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _openPortfolio() async {
    final Uri url = Uri.parse('https://ardacosgun.web.app/');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
          webOnlyWindowName: '_blank',
        );
      } else {
        await launchUrl(url, webOnlyWindowName: '_blank');
      }
    } catch (e) {
      debugPrint('Error launching portfolio: $e');
      try {
        await launchUrl(url);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = screenWidth < 600;
    final currentViewMode = _effectiveViewMode(isMobile);

    final double logoHeight = isMobile
        ? 85.0
        : (screenHeight * 0.115).clamp(92.0, 125.0);
    final double headerSpacer = logoHeight + (isMobile ? 10.0 : 6.0);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Bottom Layer: Content (Scrollable Games List)
            Column(
              children: [
                // Spacer matching the height of the header
                SizedBox(height: headerSpacer),
                ValueListenableBuilder<List<MistakeItem>>(
                  valueListenable: MistakeService.instance.mistakesNotifier,
                  builder: (context, mistakes, _) {
                    return _HeaderBannerCarousel(
                      isMobile: isMobile,
                      mistakes: mistakes,
                      currentMotivationalQuote: _currentMotivationalQuote,
                      onOpenRandomGame: _launchRandomGame,
                      onOpenMistakeBank: () => _navigateToScreen(
                        (_) => const MistakeBankScreen(),
                        isGame: true,
                      ),
                    );
                  },
                ),
                Expanded(
                  child: ValueListenableBuilder<SettingsData>(
                    valueListenable: SettingsService.instance.settingsNotifier,
                    builder: (context, settings, _) {
                      return LayoutBuilder(
                        builder: (context, outerConstraints) {
                          if (currentViewMode == ViewMode.carousel) {
                            return _buildCarouselView(
                              outerConstraints,
                              settings,
                            );
                          } else if (currentViewMode == ViewMode.list) {
                            return _buildListView(outerConstraints, settings);
                          }
                          return _buildGridView(outerConstraints, settings);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),

            // Top Layer: The Header Logo
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: GestureDetector(
                onTap: _onLogoTap,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 0.5),
                  child: Image.asset(
                    'assets/logo/playengground logo.png',
                    height: logoHeight,
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            ),

            // Left Controls
            Positioned(
              top: 20.0,
              left: 16.0,
              child: isMobile
                  ? const _MobileMusicDropdown()
                  : const _MusicControlsWidget(),
            ),

            // Right Controls: Settings and View Mode Dropdown
            Positioned(
              top: 20.0,
              right: 16.0,
              child: _SettingsViewDropdown(
                currentMode: currentViewMode,
                onModeChanged: (mode) =>
                    setState(() => _userSelectedViewMode = mode),
                onOpenPortfolio: _openPortfolio,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView(
    BoxConstraints outerConstraints,
    SettingsData settings,
  ) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 24,
            vertical: 20,
          ),
          child: Column(
            children: [
              ..._activeGames.map((game) {
                final lipColor = FeatureCard.darken(game.color, 0.16);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14.0),
                  child: Container(
                    padding: const EdgeInsets.only(bottom: 4.5),
                    decoration: BoxDecoration(
                      color: lipColor,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.28),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: game.color,
                      borderRadius: BorderRadius.circular(20),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () =>
                            _navigateToScreen(game.builder, isGame: true),
                        borderRadius: BorderRadius.circular(20),
                        splashColor: Colors.white.withValues(alpha: 0.18),
                        child: Stack(
                          children: [
                            Positioned(
                              right: -12,
                              bottom: -18,
                              child: IgnorePointer(
                                child: Transform.rotate(
                                  angle: -0.2,
                                  child: Icon(
                                    game.icon,
                                    size: isMobile ? 84 : 104,
                                    color: Colors.black.withValues(alpha: 0.11),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(isMobile ? 14 : 18),
                              child: Row(
                                children: [
                                  Container(
                                    width: isMobile ? 50 : 58,
                                    height: isMobile ? 50 : 58,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.18,
                                      ),
                                      borderRadius: BorderRadius.circular(15),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.24,
                                        ),
                                        width: 1.4,
                                      ),
                                    ),
                                    child: Icon(
                                      game.icon,
                                      color: Colors.white,
                                      size: isMobile ? 24 : 28,
                                    ),
                                  ),
                                  SizedBox(width: isMobile ? 14 : 18),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                game.title,
                                                style: GoogleFonts.outfit(
                                                  fontSize: isMobile
                                                      ? 17.5
                                                      : 20,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                            if (settings.showTopicBadges &&
                                                game.topicBadge != null) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                constraints: BoxConstraints(
                                                  maxWidth: isMobile
                                                      ? 105
                                                      : 170,
                                                ),
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: isMobile ? 7 : 9,
                                                  vertical: isMobile ? 3 : 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.22),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: Colors.white
                                                        .withValues(
                                                          alpha: 0.24,
                                                        ),
                                                    width: 1.0,
                                                  ),
                                                ),
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  child: Text(
                                                    game.topicBadge!,
                                                    maxLines: 1,
                                                    style: GoogleFonts.outfit(
                                                      fontSize: isMobile
                                                          ? 8.5
                                                          : 10.5,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: Colors.white,
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          game.description,
                                          style: GoogleFonts.outfit(
                                            fontSize: isMobile ? 12.5 : 14,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.white.withValues(
                                              alpha: 0.90,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    width: isMobile ? 34 : 38,
                                    height: isMobile ? 34 : 38,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(11),
                                    ),
                                    child: Icon(
                                      Icons.play_arrow_rounded,
                                      color: lipColor,
                                      size: isMobile ? 22 : 24,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 20),
              _buildBottomActionButtons(isMobile),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridView(
    BoxConstraints outerConstraints,
    SettingsData settings,
  ) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;
    final bool isDesktop = screenWidth > 1200;
    final double spacing = isDesktop ? 14.0 : 16.0;
    final double runSpacing = isDesktop ? 12.0 : 16.0;
    final double padding = isDesktop ? 16.0 : 20.0;

    final int columns = screenWidth > 1200
        ? 5
        : screenWidth > 800
            ? 3
            : 2;

    // Responsive card height: on desktop 5-column layout, calculate height so 3 rows + footer fit 1920x945 without scroll
    final double cardHeight = isDesktop
        ? ((outerConstraints.maxHeight - 88.0 - (runSpacing * 2)) / 3.0)
            .clamp(172.0, 205.0)
        : (screenWidth > 800 ? 200.0 : 185.0);

    final double cardWidth = screenWidth > 1200
        ? ((outerConstraints.maxWidth - spacing * (columns - 1) - padding * 2) /
                  columns)
              .clamp(200.0, 270.0)
        : screenWidth > 800
            ? ((outerConstraints.maxWidth - spacing * (columns - 1) - padding * 2) /
                  columns)
              .clamp(230.0, 320.0)
            : (outerConstraints.maxWidth - spacing - padding * 2) / 2;

    final double gridWidth = (columns * cardWidth + (columns - 1) * spacing)
        .clamp(0.0, outerConstraints.maxWidth - padding * 2);

    final gamesList = _activeGames.map((game) {
      return FeatureCard(
        title: game.title,
        subtitle: game.subtitle,
        icon: game.icon,
        color: game.color,
        badgeText: settings.showTopicBadges ? game.topicBadge : null,
        onTap: () => _navigateToScreen(game.builder, isGame: true),
      );
    }).toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: outerConstraints.maxHeight),
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: padding,
              vertical: isDesktop ? 8.0 : 16.0,
            ),
            child: SizedBox(
              width: gridWidth,
              child: Column(
                children: [
                  Wrap(
                    spacing: spacing,
                    runSpacing: runSpacing,
                    alignment: screenWidth > 800
                        ? WrapAlignment.center
                        : WrapAlignment.start,
                    children: gamesList
                        .map(
                          (card) => SizedBox(
                            width: cardWidth,
                            height: cardHeight,
                            child: card,
                          ),
                        )
                        .toList(),
                  ),
                  SizedBox(height: isDesktop ? 12.0 : 20.0),
                  _buildBottomActionButtons(isMobile),
                  SizedBox(height: isDesktop ? 6.0 : 12.0),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCarouselView(BoxConstraints constraints, SettingsData settings) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final bool isSmall =
        constraints.maxWidth < 600 || constraints.maxHeight < 700;

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Center(
                child: SizedBox(
                  height: isMobile
                      ? (constraints.maxHeight * 0.78).clamp(310.0, 420.0)
                      : (constraints.maxHeight * 0.85).clamp(360.0, 520.0),
                  child: PageView.builder(
                    controller: _pageController,
                    physics: const PageScrollPhysics(
                      parent: ClampingScrollPhysics(),
                    ),
                    itemCount: _loopTotalCount,
                    itemBuilder: (context, index) {
                      final actualIndex = index % _activeGames.length;
                      final game = _activeGames[actualIndex];
                      final lipColor = FeatureCard.darken(game.color, 0.17);
                      return RepaintBoundary(
                        child: AnimatedBuilder(
                          animation: _pageController,
                          builder: (context, child) {
                            double value = 1.0;
                            if (_pageController.hasClients &&
                                _pageController.position.haveDimensions) {
                              value = _pageController.page! - index;
                              value = (1 - (value.abs() * 0.13)).clamp(0.87, 1.0);
                            } else {
                              value = index == _initialPage ? 1.0 : 0.87;
                            }
                            return Center(
                              child: Transform.scale(
                                scale: Curves.easeOut.transform(value),
                                child: child,
                              ),
                            );
                          },
                          child: Container(
                            margin: EdgeInsets.symmetric(
                              horizontal: isSmall ? 8.0 : 16.0,
                              vertical: isSmall ? 6.0 : 18.0,
                            ),
                            padding: const EdgeInsets.only(bottom: 6.0),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              color: lipColor,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 4,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Material(
                              color: game.color,
                              borderRadius: BorderRadius.circular(28),
                              clipBehavior: Clip.hardEdge,
                            child: InkWell(
                              onTap: () =>
                                  _navigateToScreen(game.builder, isGame: true),
                              borderRadius: BorderRadius.circular(28),
                              splashColor: Colors.white.withValues(alpha: 0.18),
                              child: Stack(
                                children: [
                                  // Subtle top glossy highlight
                                  Positioned(
                                    top: 0,
                                    left: 0,
                                    right: 0,
                                    height: 80,
                                    child: IgnorePointer(
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.white.withValues(
                                                alpha: 0.16,
                                              ),
                                              Colors.white.withValues(
                                                alpha: 0.0,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Giant rotated watermark icon in bottom-right
                                  Positioned(
                                    right: -24,
                                    bottom: -24,
                                    child: IgnorePointer(
                                      child: Transform.rotate(
                                        angle: -0.22,
                                        child: Icon(
                                          game.icon,
                                          size: isSmall ? 165 : 220,
                                          color: Colors.black.withValues(
                                            alpha: 0.11,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isSmall ? 18.0 : 32.0,
                                      vertical: isSmall ? 16.0 : 28.0,
                                    ),
                                    child: LayoutBuilder(
                                      builder: (context, cardInner) {
                                        return SingleChildScrollView(
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          child: ConstrainedBox(
                                            constraints: BoxConstraints(
                                              minHeight: cardInner.maxHeight,
                                            ),
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                // Top Row: Topic Badge
                                                if (settings.showTopicBadges &&
                                                    game.topicBadge != null)
                                                  Container(
                                                    constraints: BoxConstraints(
                                                      maxWidth: isSmall
                                                          ? 160
                                                          : 300,
                                                    ),
                                                    padding: EdgeInsets.symmetric(
                                                      horizontal: isSmall
                                                          ? 10
                                                          : 14,
                                                      vertical: isSmall
                                                          ? 4
                                                          : 5.5,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black
                                                          .withValues(
                                                            alpha: 0.22,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                      border: Border.all(
                                                        color: Colors.white
                                                            .withValues(
                                                              alpha: 0.24,
                                                            ),
                                                        width: 1.2,
                                                      ),
                                                    ),
                                                    child: FittedBox(
                                                      fit: BoxFit.scaleDown,
                                                      child: Text(
                                                        game.topicBadge!,
                                                        maxLines: 1,
                                                        style: GoogleFonts.outfit(
                                                          fontSize: isSmall
                                                              ? 10
                                                              : 12,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          color: Colors.white,
                                                          letterSpacing: 0.7,
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                else
                                                  const SizedBox(height: 4),

                                                SizedBox(
                                                  height: isSmall ? 10 : 16,
                                                ),

                                                // Center Hero Icon + Typography
                                                Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Container(
                                                      width: isSmall ? 68 : 92,
                                                      height: isSmall ? 68 : 92,
                                                      decoration: BoxDecoration(
                                                        color: Colors.black
                                                            .withValues(
                                                              alpha: 0.18,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              isSmall ? 20 : 26,
                                                            ),
                                                        border: Border.all(
                                                          color: Colors.white
                                                              .withValues(
                                                                alpha: 0.28,
                                                              ),
                                                          width: 1.8,
                                                        ),
                                                      ),
                                                      child: Icon(
                                                        game.icon,
                                                        size: isSmall ? 34 : 48,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      height: isSmall ? 12 : 18,
                                                    ),
                                                    Text(
                                                      game.title,
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: GoogleFonts.outfit(
                                                        fontSize: isSmall
                                                            ? 24
                                                            : 34,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: Colors.white,
                                                        height: 1.12,
                                                        shadows: [
                                                          Shadow(
                                                            color: Colors.black
                                                                .withValues(
                                                                  alpha: 0.22,
                                                                ),
                                                            offset:
                                                                const Offset(
                                                                  0,
                                                                  2,
                                                                ),
                                                            blurRadius: 4,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      height: isSmall ? 6 : 10,
                                                    ),
                                                    Text(
                                                      game.subtitle,
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: GoogleFonts.outfit(
                                                        fontSize: isSmall
                                                            ? 14
                                                            : 18,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: Colors.white
                                                            .withValues(
                                                              alpha: 0.95,
                                                            ),
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      height: isSmall ? 8 : 14,
                                                    ),
                                                    ConstrainedBox(
                                                      constraints:
                                                          const BoxConstraints(
                                                            maxWidth: 520,
                                                          ),
                                                      child: Text(
                                                        game.description,
                                                        textAlign:
                                                            TextAlign.center,
                                                        maxLines: isSmall ? 3 : 4,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: GoogleFonts.outfit(
                                                          fontSize: isSmall
                                                              ? 12.0
                                                              : 15.0,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: Colors.white
                                                              .withValues(
                                                                alpha: 0.88,
                                                              ),
                                                          height: 1.35,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),

                                                SizedBox(
                                                  height: isSmall ? 14 : 22,
                                                ),

                                                // Tactile 3D White "HEMEN OYNA" CTA Button
                                                Container(
                                                  width: double.infinity,
                                                  constraints:
                                                      const BoxConstraints(
                                                        maxWidth: 280,
                                                      ),
                                                  padding:
                                                      const EdgeInsets.only(
                                                        bottom: 4.0,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFFCBD5E1,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          16,
                                                        ),
                                                  ),
                                                  child: Container(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          vertical: isSmall
                                                              ? 10
                                                              : 13,
                                                          horizontal: isSmall
                                                              ? 12
                                                              : 20,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            15,
                                                          ),
                                                    ),
                                                    child: FittedBox(
                                                      fit: BoxFit.scaleDown,
                                                      child: Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            Icons
                                                                .play_arrow_rounded,
                                                            size: isSmall
                                                                ? 20
                                                                : 24,
                                                            color: lipColor,
                                                          ),
                                                          const SizedBox(
                                                            width: 6,
                                                          ),
                                                          Text(
                                                            'OYNA',
                                                            style:
                                                                GoogleFonts.outfit(
                                                                  fontSize:
                                                                      isSmall
                                                                      ? 14
                                                                      : 16,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w900,
                                                                  letterSpacing:
                                                                      0.8,
                                                                  color:
                                                                      lipColor,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
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
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  ),
                ),
              ),
              if (MediaQuery.of(context).size.width > 800) ...[
                Positioned(
                  left: 32,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IconButton(
                      iconSize: 56,
                      icon: const Icon(Icons.chevron_left_rounded),
                      color: Colors.white70,
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                    ),
                  ),
                ),
                Positioned(
                  right: 32,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IconButton(
                      iconSize: 56,
                      icon: const Icon(Icons.chevron_right_rounded),
                      color: Colors.white70,
                      onPressed: () {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        // Compact Tactile Counter Pill ("◀  12 / 15  ▶") instead of 15 dots
        Padding(
          padding: const EdgeInsets.only(top: 4.0, bottom: 10.0),
          child: AnimatedBuilder(
            animation: _pageController,
            builder: (context, _) {
              int currentIndex = 0;
              if (_pageController.hasClients &&
                  _pageController.position.haveDimensions) {
                final int virtualPage =
                    _pageController.page?.round() ?? _initialPage;
                currentIndex =
                    ((virtualPage % _activeGames.length) +
                        _activeGames.length) %
                    _activeGames.length;
              }
              final activeColor = _activeGames[currentIndex].color;
              return Container(
                padding: const EdgeInsets.only(bottom: 3.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F1C),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: const Color(0xFF2E2E4A),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                          );
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: const Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Icon(
                            Icons.chevron_left_rounded,
                            size: 18,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: activeColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              '${currentIndex + 1} / ${_activeGames.length}',
                              style: GoogleFonts.outfit(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                          );
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: const Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10.0),
          child: _buildBottomActionButtons(isMobile),
        ),
      ],
    );
  }

  Widget _buildBottomActionButtons(bool isMobile) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 12, right: 12),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.language_rounded,
                  size: 13,
                  color: Color(0xFF64748B),
                ),
                const SizedBox(width: 5),
                Text(
                  'En iyi deneyim için Google Chrome önerilir',
                  style: GoogleFonts.outfit(
                    fontSize: isMobile ? 11 : 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedHoverWrapper(
              scaleAmount: 1.06,
              child: InkWell(
                onTap: _openPortfolio,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.code_rounded,
                        size: 13,
                        color: Color(0xFFA78BFA),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Geliştirici: Arda Coşgun',
                        style: GoogleFonts.outfit(
                          fontSize: isMobile ? 11.5 : 12.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '•',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: const Color(0xFF475569),
                ),
              ),
            ),
            AnimatedHoverWrapper(
              scaleAmount: 1.06,
              child: InkWell(
                onTap: () => OnboardingDialog.show(context),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.menu_book_rounded,
                        size: 12.5,
                        color: Color(0xFF38BDF8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Rehber',
                        style: GoogleFonts.outfit(
                          fontSize: isMobile ? 11.5 : 12.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '•',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: const Color(0xFF475569),
                ),
              ),
            ),
            AnimatedHoverWrapper(
              scaleAmount: 1.06,
              child: InkWell(
                onTap: () => PrivacyPolicyDialog.show(context),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        size: 12.5,
                        color: Color(0xFF34D399),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Gizlilik Politikası',
                        style: GoogleFonts.outfit(
                          fontSize: isMobile ? 11.5 : 12.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '•',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: const Color(0xFF475569),
                ),
              ),
            ),
            const AnimatedHoverWrapper(
              scaleAmount: 1.08,
              child: _AppVersionTag(),
            ),
          ],
        ),
      ),
    ),
  ],
);
  }
}

/// Ana sayfadaki Duolingo/Arcade tarzı kompakt, dokunsal (3D alt tabanlı) HUD durum barı.
/// Rastgele Oyun başlatıcı ve Hata Bankası butonlarını barındırır.
class _HeaderBannerCarousel extends StatelessWidget {
  final bool isMobile;
  final List<MistakeItem> mistakes;
  final String currentMotivationalQuote;
  final VoidCallback onOpenRandomGame;
  final VoidCallback onOpenMistakeBank;

  const _HeaderBannerCarousel({
    required this.isMobile,
    required this.mistakes,
    required this.currentMotivationalQuote,
    required this.onOpenRandomGame,
    required this.onOpenMistakeBank,
  });

  Widget _buildRandomGamePill() {
    const Color accentColor = Color(0xFFF59E0B); // Amber / yellow tone
    const Color lipColor = Color(0xFFB45309);    // Tactile 3D bottom lip

    return AnimatedHoverWrapper(
      scaleAmount: 1.05,
      child: Container(
        padding: const EdgeInsets.only(bottom: 3.5),
        decoration: BoxDecoration(
          color: lipColor,
          borderRadius: BorderRadius.circular(16),
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
          borderRadius: BorderRadius.circular(15),
          child: InkWell(
            onTap: onOpenRandomGame,
            borderRadius: BorderRadius.circular(15),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 15,
                vertical: isMobile ? 6.5 : 8,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.65),
                  width: 1.4,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    FontAwesomeIcons.dice,
                    size: isMobile ? 14 : 16,
                    color: accentColor,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'Rastgele Oyun',
                    style: GoogleFonts.outfit(
                      fontSize: isMobile ? 12.5 : 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMistakePill() {
    final hasMistakes = mistakes.isNotEmpty;
    final Color accentColor = hasMistakes
        ? const Color(0xFFEF4444)
        : const Color(0xFF8B5CF6);
    final Color lipColor = hasMistakes
        ? const Color(0xFFB91C1C)
        : const Color(0xFF5B21B6);

    return Tooltip(
      message: 'Hata Bankasına Git',
      child: AnimatedHoverWrapper(
        scaleAmount: 1.05,
        child: Container(
          padding: const EdgeInsets.only(bottom: 3.5),
          decoration: BoxDecoration(
            color: lipColor,
            borderRadius: BorderRadius.circular(16),
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
            borderRadius: BorderRadius.circular(15),
            child: InkWell(
              onTap: onOpenMistakeBank,
              borderRadius: BorderRadius.circular(15),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 10 : 14,
                  vertical: isMobile ? 6.5 : 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.55),
                    width: 1.4,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasMistakes
                          ? FontAwesomeIcons.circleExclamation
                          : Icons.check_circle_rounded,
                      size: isMobile ? 12.5 : 14,
                      color: hasMistakes
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      hasMistakes ? '${mistakes.length} Hata' : '0 Hata',
                      style: GoogleFonts.outfit(
                        fontSize: isMobile ? 12.5 : 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: isMobile ? 6 : 8),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 7 : 9,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            hasMistakes ? 'Çalış' : 'İncele',
                            style: GoogleFonts.outfit(
                              fontSize: isMobile ? 10.5 : 11.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: isMobile ? 11 : 12.5,
                            color: Colors.white,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showMistakePill = isMobile || mistakes.isNotEmpty;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 10 : 24,
        vertical: 4,
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildRandomGamePill(),
              if (showMistakePill) ...[
                SizedBox(width: isMobile ? 8 : 12),
                _buildMistakePill(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MusicControlsWidget extends StatelessWidget {
  final bool isPopup = false;
  const _MusicControlsWidget();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: AudioManager.instance,
      builder: (context, _) {
        final isPlaying = AudioManager.instance.isBgmPlaying;
        final isLoading = AudioManager.instance.isLoadingBgm;
        final volume = AudioManager.instance.bgmVolume;

        final children = [
          isLoading
              ? const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Color(0xFF8B5CF6),
                    ),
                  ),
                )
              : IconButton(
                  icon: Icon(
                    isPlaying
                        ? Icons.music_note_rounded
                        : Icons.music_off_rounded,
                    color: isPlaying ? const Color(0xFF8B5CF6) : Colors.white70,
                  ),
                  onPressed: () {
                    AudioManager.instance.toggleBgm();
                  },
                  tooltip: 'Müzik Aç/Kapat',
                ),
          if (isPlaying)
            SizedBox(
              width: isPopup ? 120 : 80,
              child: SliderTheme(
                data: SliderThemeData(
                  thumbColor: const Color(0xFF8B5CF6),
                  activeTrackColor: const Color(0xFF8B5CF6),
                  inactiveTrackColor: isDark ? Colors.white24 : Colors.black12,
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                ),
                child: Slider(
                  value: volume,
                  onChanged: (val) {
                    AudioManager.instance.setBgmVolume(val);
                  },
                ),
              ),
            ),
        ];

        return Container(
          padding: const EdgeInsets.only(bottom: 3.5),
          decoration: BoxDecoration(
            color: const Color(0xFF0E0E1B),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: isPlaying
                    ? const Color(0xFF8B5CF6).withValues(alpha: 0.5)
                    : const Color(0xFF2E2E4A),
                width: 1.3,
              ),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: isPopup ? 12 : 6,
              vertical: isPopup ? 12 : 2,
            ),
            child: isPopup
                ? Column(mainAxisSize: MainAxisSize.min, children: children)
                : Row(mainAxisSize: MainAxisSize.min, children: children),
          ),
        );
      },
    );
  }
}

class _MobileMusicDropdown extends StatefulWidget {
  const _MobileMusicDropdown();

  @override
  State<_MobileMusicDropdown> createState() => _MobileMusicDropdownState();
}

class _MobileMusicDropdownState extends State<_MobileMusicDropdown> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: AudioManager.instance,
      builder: (context, _) {
        final isPlaying = AudioManager.instance.isBgmPlaying;
        final volume = AudioManager.instance.bgmVolume;
        final isLoading = AudioManager.instance.isLoadingBgm;

        return TapRegion(
          onTapOutside: (_) {
            if (_isExpanded) {
              setState(() => _isExpanded = false);
            }
          },
          child: Container(
            padding: const EdgeInsets.only(bottom: 3.5),
            decoration: BoxDecoration(
              color: const Color(0xFF0E0E1B),
              borderRadius: BorderRadius.circular(_isExpanded ? 22 : 16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: _isExpanded ? 0.35 : 0.25,
                  ),
                  blurRadius: _isExpanded ? 12 : 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOutBack,
              width: 44,
              height: _isExpanded ? 240 : 44,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(_isExpanded ? 21 : 15),
                border: Border.all(
                  color: isPlaying
                      ? const Color(0xFF8B5CF6).withValues(alpha: 0.55)
                      : const Color(0xFF2E2E4A),
                  width: 1.3,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  children: [
                    InkWell(
                      onTap: () {
                        if (_isExpanded) {
                          setState(() => _isExpanded = false);
                        } else {
                          AudioManager.instance.toggleBgm();
                          if (!isPlaying) {
                            setState(() => _isExpanded = true);
                          }
                        }
                      },
                      onLongPress: () {
                        setState(() => _isExpanded = !_isExpanded);
                      },
                      borderRadius: BorderRadius.circular(15),
                      child: SizedBox(
                        height: 44,
                        width: 44,
                        child: isLoading
                            ? const Padding(
                                padding: EdgeInsets.all(11.0),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.0,
                                  color: Color(0xFF8B5CF6),
                                ),
                              )
                            : AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                child: Icon(
                                  _isExpanded
                                      ? Icons.keyboard_arrow_up_rounded
                                      : (isPlaying
                                            ? Icons.music_note_rounded
                                            : Icons.music_off_rounded),
                                  key: ValueKey<String>(
                                    '${_isExpanded}_$isPlaying',
                                  ),
                                  color: isPlaying
                                      ? const Color(0xFF8B5CF6)
                                      : Colors.white70,
                                  size: 20,
                                ),
                              ),
                      ),
                    ),
                    if (_isExpanded) ...[
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () => AudioManager.instance.toggleBgm(),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: isPlaying
                                ? const Color(0xFF8B5CF6).withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.06),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: isPlaying
                                ? const Color(0xFF8B5CF6)
                                : Colors.white70,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 135,
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: SliderTheme(
                            data: SliderThemeData(
                              thumbColor: const Color(0xFF8B5CF6),
                              activeTrackColor: const Color(0xFF8B5CF6),
                              inactiveTrackColor: isDark
                                  ? Colors.white24
                                  : Colors.black12,
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 7,
                              ),
                            ),
                            child: Slider(
                              value: volume,
                              onChanged: AudioManager.instance.setBgmVolume,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SettingsViewDropdown extends StatefulWidget {
  final ViewMode currentMode;
  final ValueChanged<ViewMode> onModeChanged;
  final VoidCallback onOpenPortfolio;

  const _SettingsViewDropdown({
    required this.currentMode,
    required this.onModeChanged,
    required this.onOpenPortfolio,
  });

  @override
  State<_SettingsViewDropdown> createState() => _SettingsViewDropdownState();
}

class _SettingsViewDropdownState extends State<_SettingsViewDropdown> {
  bool _isExpanded = false;
  int _selectedTab = 0; // 0: Görünüm, 1: Ayarlar

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final double expandedWidth = screenWidth < 360 ? 250.0 : 278.0;
    final double expandedHeight = _selectedTab == 0 ? 198.0 : 265.0;

    return TapRegion(
      onTapOutside: (_) {
        if (_isExpanded) {
          setState(() => _isExpanded = false);
        }
      },
      child: Container(
        padding: const EdgeInsets.only(bottom: 3.5),
        decoration: BoxDecoration(
          color: const Color(0xFF0E0E1B),
          borderRadius: BorderRadius.circular(_isExpanded ? 21 : 16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _isExpanded ? 0.45 : 0.25),
              blurRadius: _isExpanded ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOutBack,
          width: _isExpanded ? expandedWidth : 44.0,
          height: _isExpanded ? expandedHeight : 44.0,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(_isExpanded ? 20 : 15),
            border: Border.all(
              color: _isExpanded
                  ? const Color(0xFF8B5CF6).withValues(alpha: 0.5)
                  : const Color(0xFF2E2E4A),
              width: 1.3,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: _isExpanded
              ? OverflowBox(
                  alignment: Alignment.topRight,
                  minWidth: expandedWidth,
                  maxWidth: expandedWidth,
                  minHeight: expandedHeight,
                  maxHeight: expandedHeight,
                  child: SizedBox(
                    width: expandedWidth,
                    height: expandedHeight,
                    child: _buildExpandedContent(),
                  ),
                )
              : _buildCollapsedButton(),
        ),
      ),
    );
  }

  Widget _buildCollapsedButton() {
    return Tooltip(
      message: 'Görünüm ve Ayarlar',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _isExpanded = true),
          borderRadius: BorderRadius.circular(15),
          child: const Center(
            child: Icon(
              Icons.settings_rounded,
              color: Colors.white70,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tab Header
        Container(
          padding: const EdgeInsets.only(left: 12, right: 8, top: 6, bottom: 6),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFF2A2A4A), width: 1),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildTabButton(
                  index: 0,
                  icon: Icons.visibility_rounded,
                  label: 'Görünüm',
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildTabButton(
                  index: 1,
                  icon: Icons.settings_rounded,
                  label: 'Ayarlar',
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: () => setState(() => _isExpanded = false),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  child: const Icon(
                    Icons.keyboard_arrow_up_rounded,
                    color: Colors.white70,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Tab Body
        if (_selectedTab == 0) _buildViewModeTab() else _buildSettingsTab(),
      ],
    );
  }

  Widget _buildTabButton({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF8B5CF6).withValues(alpha: 0.22)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? const Color(0xFF8B5CF6) : Colors.white60,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewModeTab() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildViewModeItem(
          mode: ViewMode.grid,
          icon: Icons.grid_view_rounded,
          title: 'Izgara Görünümü',
        ),
        _buildViewModeItem(
          mode: ViewMode.list,
          icon: Icons.view_list_rounded,
          title: 'Liste Görünümü',
        ),
        _buildViewModeItem(
          mode: ViewMode.carousel,
          icon: Icons.view_carousel_rounded,
          title: 'Vitrin Görünümü',
        ),
      ],
    );
  }

  Widget _buildViewModeItem({
    required ViewMode mode,
    required IconData icon,
    required String title,
  }) {
    final isSelected = widget.currentMode == mode;
    return InkWell(
      onTap: () {
        widget.onModeChanged(mode);
        setState(() => _isExpanded = false);
      },
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        color: isSelected
            ? const Color(0xFF8B5CF6).withValues(alpha: 0.12)
            : Colors.transparent,
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? const Color(0xFF8B5CF6)
                  : Colors.grey.shade400,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.white70,
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_rounded,
                size: 16,
                color: Color(0xFF8B5CF6),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTab() {
    return ValueListenableBuilder<SettingsData>(
      valueListenable: SettingsService.instance.settingsNotifier,
      builder: (context, settings, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSwitchItem(
              icon: Icons.local_offer_rounded,
              iconColor: const Color(0xFF00E5FF),
              title: 'Kategori Rozeti',
              subtitle: 'Vocab, Idioms vb. etiketler',
              value: settings.showTopicBadges,
              onChanged: (val) =>
                  SettingsService.instance.setShowTopicBadges(val),
            ),
            const Divider(color: Color(0xFF2A2A4A), height: 8, thickness: 1),
            _buildActionItem(
              icon: Icons.menu_book_rounded,
              iconColor: const Color(0xFF38BDF8),
              title: 'Özellikler & Tanıtım Rehberi',
              onTap: () {
                setState(() => _isExpanded = false);
                OnboardingDialog.show(context);
              },
            ),
            _buildActionItem(
              icon: Icons.download_rounded,
              iconColor: const Color(0xFF10B981),
              title: 'Uygulamayı Yükle',
              onTap: () {
                setState(() => _isExpanded = false);
                PwaPromptDialog.show(context);
              },
            ),
            _buildActionItem(
              icon: Icons.shield_rounded,
              iconColor: const Color(0xFF34D399),
              title: 'Gizlilik Politikası',
              onTap: () {
                setState(() => _isExpanded = false);
                PrivacyPolicyDialog.show(context);
              },
            ),
            _buildActionItem(
              icon: Icons.code_rounded,
              iconColor: const Color(0xFFA78BFA),
              title: 'Geliştirici: Arda Coşgun',
              onTap: () {
                setState(() => _isExpanded = false);
                widget.onOpenPortfolio();
              },
            ),
            const SizedBox(height: 6),
          ],
        );
      },
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7.5),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 14, color: iconColor),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: Colors.white54,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6.5),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 26,
            width: 40,
            child: FittedBox(
              fit: BoxFit.contain,
              child: Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: Colors.white,
                activeTrackColor: const Color(0xFF8B5CF6),
                inactiveThumbColor: Colors.white54,
                inactiveTrackColor: const Color(0xFF2A2A4A),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppVersionTag extends StatelessWidget {
  const _AppVersionTag();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      'v0.4.9',
      style: GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.6,
        color: isDark ? const Color(0xFF71717A) : const Color(0xFFA1A1AA),
      ),
    );
  }
}

class _SecretPinDialog extends StatefulWidget {
  const _SecretPinDialog();

  @override
  State<_SecretPinDialog> createState() => _SecretPinDialogState();
}

class _SecretPinDialogState extends State<_SecretPinDialog> {
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String? _errorMessage;
  bool _isSuccess = false;

  static const String _targetPin = '578857';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }

    if (value.length == 6) {
      if (value == _targetPin) {
        setState(() => _isSuccess = true);
        HapticFeedback.mediumImpact();
        Future.delayed(const Duration(milliseconds: 250), () {
          if (mounted) {
            Navigator.of(context).pop();
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const AdminStatsScreen()));
          }
        });
      } else {
        HapticFeedback.heavyImpact();
        setState(() {
          _errorMessage = 'Hatalı Güvenlik Kodu!';
        });
        _pinController.clear();
        _showNotAdminPopup();
      }
    } else {
      setState(() {});
    }
  }

  void _showNotAdminPopup() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1424),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFEF4444), width: 1.8),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 26,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
              child: const Center(
                child: Text('😡', style: TextStyle(fontSize: 40)),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Sen admin değilsin!',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Burada ne arıyorsun bakalım? Gizli bölge yalnızca yetkili personele aittir! 👀🚫',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: const Color(0xFFCBD5E1),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                _focusNode.requestFocus();
              },
              child: Text(
                'Tamam, Yakalandım 😅',
                style: GoogleFonts.outfit(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentText = _pinController.text;

    return AlertDialog(
      backgroundColor: const Color(0xFF16162A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: _isSuccess
              ? const Color(0xFF10B981)
              : _errorMessage != null
              ? const Color(0xFFEF4444)
              : const Color(0xFF2A2A4A),
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color:
                    (_isSuccess
                            ? const Color(0xFF10B981)
                            : _errorMessage != null
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF8B5CF6))
                        .withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  _isSuccess
                      ? Icons.check_circle_rounded
                      : _errorMessage != null
                      ? Icons.error_outline_rounded
                      : Icons.lock_rounded,
                  color: _isSuccess
                      ? const Color(0xFF10B981)
                      : _errorMessage != null
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF8B5CF6),
                  size: 26,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Güvenlik Doğrulaması',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'İstatistik paneline erişmek için 6 haneli kodu girin:',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 20),

            // 6 Haneli Kutu Tasarımı
            GestureDetector(
              onTap: () => _focusNode.requestFocus(),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Gerçek görünmez input
                  Opacity(
                    opacity: 0.0,
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: TextField(
                        controller: _pinController,
                        focusNode: _focusNode,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        autofocus: true,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: _onChanged,
                      ),
                    ),
                  ),

                  // Görsel 6 Kutu
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(6, (index) {
                      final hasDigit = index < currentText.length;
                      final isCurrent = index == currentText.length;
                      final digit = hasDigit ? currentText[index] : '';

                      return Container(
                        width: 44,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D0D14),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isSuccess
                                ? const Color(0xFF10B981)
                                : _errorMessage != null
                                ? const Color(0xFFEF4444)
                                : isCurrent
                                ? const Color(0xFF8B5CF6)
                                : hasDigit
                                ? const Color(0xFF6366F1)
                                : const Color(0xFF2A2A4A),
                            width: isCurrent || hasDigit ? 1.8 : 1.2,
                          ),
                          boxShadow: isCurrent
                              ? [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF8B5CF6,
                                    ).withValues(alpha: 0.3),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            hasDigit ? digit : '',
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFEF4444),
                ),
              ),
            ],

            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Vazgeç',
                    style: GoogleFonts.outfit(color: const Color(0xFF94A3B8)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
