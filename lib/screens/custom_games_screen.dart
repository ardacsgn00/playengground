import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/streak_service.dart';
import 'hangman_screen.dart';
import 'meaning_sniper_screen.dart';
import 'memory_card_screen.dart';
import 'sentence_scramble_screen.dart';
import 'sound_catch_screen.dart';

class Flashcard {
  final String front;
  final String back;
  const Flashcard({required this.front, required this.back});
}

class CustomGamesScreen extends StatefulWidget {
  const CustomGamesScreen({super.key});

  @override
  State<CustomGamesScreen> createState() => _CustomGamesScreenState();
}

class _CustomGamesScreenState extends State<CustomGamesScreen> {
  final List<Flashcard> _customCards = [
    const Flashcard(front: "apple", back: "elma"),
    const Flashcard(front: "banana", back: "muz"),
    const Flashcard(front: "cat", back: "kedi"),
    const Flashcard(front: "dog", back: "köpek"),
    const Flashcard(front: "elephant", back: "fil"),
    const Flashcard(front: "grape", back: "üzüm"),
    const Flashcard(front: "house", back: "ev"),
    const Flashcard(front: "water", back: "su"),
    const Flashcard(front: "umbrella", back: "şemsiye"),
    const Flashcard(front: "yellow", back: "sarı"),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final customDict = {
      for (var card in _customCards) card.front: card.back,
    };

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Özel Kelime Oyunları",
          style: TextStyle(
            fontFamily: GoogleFonts.outfit().fontFamily,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // Banner Info
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.blueAccent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.blueAccent,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Şu an listenizde ${_customCards.length} adet özel kelime bulunmaktadır.",
                            style: TextStyle(
                              fontFamily: GoogleFonts.outfit().fontFamily,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueAccent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _ViewCardsButton(
                          onTap: () => _showCardsBottomSheet(context, isDark),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Game Menu
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 680),
                        child: ListView(
                          physics: const BouncingScrollPhysics(),
                          children: [
                            _CustomGameMenuCard(
                              title: "Memory Match",
                              subtitle: "Özel kelimeleriniz ve Türkçe anlamlarıyla kart eşleştirme oyunu oynayın.",
                              icon: FontAwesomeIcons.layerGroup,
                              color: const Color(0xFF3B82F6),
                              onTap: () {
                                StreakService.instance.recordPractice();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MemoryGameScreen(
                                      customDict: customDict,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            _CustomGameMenuCard(
                              title: "Hangman",
                              subtitle: "Özel kelime listenizdeki gizli kelimeleri harf harf tahmin ederek bulun.",
                              icon: FontAwesomeIcons.personThroughWindow,
                              color: const Color(0xFFEF4444),
                              onTap: () {
                                StreakService.instance.recordPractice();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => HangmanGameScreen(
                                      customDict: customDict,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            _CustomGameMenuCard(
                              title: "Sound Catch",
                              subtitle: "Özel kelimelerinizin telaffuzunu dinleyip benzer seçenekler arasından yakalayın.",
                              icon: FontAwesomeIcons.headphones,
                              color: const Color(0xFFF59E0B),
                              onTap: () {
                                StreakService.instance.recordPractice();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SoundCatchScreen(
                                      customDict: customDict,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            _CustomGameMenuCard(
                              title: "Meaning Sniper",
                              subtitle: "Özel kelimelerinizin doğru karşılıklarına hızla kilitlenip nişan alın.",
                              icon: FontAwesomeIcons.crosshairs,
                              color: const Color(0xFF10B981),
                              onTap: () {
                                StreakService.instance.recordPractice();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MeaningSniperScreen(
                                      customDict: customDict,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            _CustomGameMenuCard(
                              title: "Sentence Scramble",
                              subtitle: "Özel kelimelerinizle oluşturulan cümle parçalarını doğru sıraya dizin.",
                              icon: FontAwesomeIcons.arrowDownShortWide,
                              color: const Color(0xFF6C63FF),
                              onTap: () {
                                StreakService.instance.recordPractice();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SentenceScrambleScreen(
                                      customFlashcards: _customCards,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 32),
                          ],
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
    );
  }

  void _showCardsBottomSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Stack(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              behavior: HitTestBehavior.opaque,
              child: const SizedBox.expand(),
            ),
            DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20.0,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.style, color: Colors.blueAccent),
                            const SizedBox(width: 10),
                            Text(
                              "Özel Kelimelerim (${_customCards.length})",
                              style: TextStyle(
                                fontFamily: GoogleFonts.outfit().fontFamily,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(),
                      Expanded(
                        child: ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          itemCount: _customCards.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final card = _customCards[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 10.0,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Colors.blueAccent.withValues(
                                        alpha: 0.15,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blueAccent,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      card.front,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_forward,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      card.back,
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: isDark
                                            ? Colors.grey[300]
                                            : Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _ViewCardsButton extends StatefulWidget {
  final VoidCallback onTap;
  const _ViewCardsButton({required this.onTap});

  @override
  State<_ViewCardsButton> createState() => _ViewCardsButtonState();
}

class _ViewCardsButtonState extends State<_ViewCardsButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.diagonal3Values(_isHovered ? 1.05 : 1.0, _isHovered ? 1.05 : 1.0, 1.0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blueAccent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              if (_isHovered)
                BoxShadow(
                  color: Colors.blueAccent.withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.visibility_outlined, size: 14, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                "Görüntüle",
                style: TextStyle(
                  fontFamily: GoogleFonts.outfit().fontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomGameMenuCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CustomGameMenuCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_CustomGameMenuCard> createState() => _CustomGameMenuCardState();
}

class _CustomGameMenuCardState extends State<_CustomGameMenuCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.03,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark
        ? Theme.of(context).colorScheme.surface
        : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF333344)
        : const Color(0xFFD8DFE8);
    final textColor = isDark ? Colors.white : const Color(0xFF2C3E50);

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _controller.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _controller.reverse();
      },
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _isHovered
                        ? widget.color.withValues(alpha: 0.5)
                        : borderColor,
                    width: _isHovered ? 2 : 1,
                  ),
                  boxShadow: [
                    if (!isDark && !_isHovered)
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    if (_isHovered)
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: widget.color.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(widget.icon, size: 30, color: widget.color),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: TextStyle(
                                fontFamily: GoogleFonts.outfit().fontFamily,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.subtitle,
                              style: TextStyle(
                                fontFamily: GoogleFonts.outfit().fontFamily,
                                fontSize: 14,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 20,
                        color: widget.color.withValues(alpha: 0.6),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
