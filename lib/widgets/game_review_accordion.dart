import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/game_review_item.dart';
import '../services/tts_service.dart';

class GameReviewAccordion extends StatefulWidget {
  final List<GameReviewItem> items;
  final Color? accentColor;
  final bool initiallyExpanded;

  const GameReviewAccordion({
    super.key,
    required this.items,
    this.accentColor,
    this.initiallyExpanded = false,
  });

  @override
  State<GameReviewAccordion> createState() => _GameReviewAccordionState();
}

class _GameReviewAccordionState extends State<GameReviewAccordion> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    // Akıllı başlangıç: 1 kelimelik oyunlarda (Wordle, Hangman vb.) açık,
    // çok sorulu oyunlarda mobil ekranları korumak için kapalı başlasın.
    _isExpanded = widget.initiallyExpanded || widget.items.length <= 1;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = widget.accentColor ?? const Color(0xFF6C63FF);

    // Yanlışlar en üstte, doğrular ardından gelecek şekilde sırala
    final sortedItems = [...widget.items]..sort((a, b) {
        if (a.isCorrect == b.isCorrect) return 0;
        return a.isCorrect ? 1 : -1;
      });

    final mistakeCount = widget.items.where((e) => !e.isCorrect).length;
    final correctCount = widget.items.length - mistakeCount;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: mistakeCount > 0
              ? Colors.redAccent.withValues(alpha: 0.3)
              : accent.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Başlık ve Aç/Kapa Butonu
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: (mistakeCount > 0 ? Colors.redAccent : accent)
                          .withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      mistakeCount > 0
                          ? FontAwesomeIcons.bookBookmark
                          : FontAwesomeIcons.circleCheck,
                      size: 14,
                      color: mistakeCount > 0 ? Colors.redAccent : accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Çalışılan Kelimeler & Sorular',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (mistakeCount > 0) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '$mistakeCount Yanlış',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$correctCount Doğru',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: isDark ? Colors.white60 : Colors.black54,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),

          // Akordeon İçeriği (Küçük ekranlar için maxHeight ile sınırlandırılmış kaydırma alanı)
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                itemCount: sortedItems.length,
                separatorBuilder: (context, index) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final item = sortedItems[index];
                  return _buildItemCard(context, item, isDark, accent);
                },
              ),
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(
    BuildContext context,
    GameReviewItem item,
    bool isDark,
    Color accent,
  ) {
    final statusColor = item.isCorrect ? Colors.green : Colors.redAccent;
    final cardBg = isDark
        ? (item.isCorrect
            ? const Color(0xFF13201B)
            : const Color(0xFF281418))
        : (item.isCorrect
            ? const Color(0xFFF0FDF4)
            : const Color(0xFFFEF2F2));

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst Satır: Durum İkonu, Kelime, Ses Butonu
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                item.isCorrect
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                size: 16,
                color: statusColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.word,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              // Sesli Telaffuz Butonu
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    TtsService.instance.speak(item.word);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: Icon(
                      Icons.volume_up_rounded,
                      size: 18,
                      color: accent,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Türkçe Anlam
          if (item.meaning.isNotEmpty) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: Text(
                item.meaning,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ),
          ],

          // Soru / Cümle Bağlamı (Varsa ve kelimeden farklıysa)
          if (item.question != null &&
              item.question!.trim().isNotEmpty &&
              item.question!.trim() != item.word.trim()) ...[
            const SizedBox(height: 6),
            Container(
              margin: const EdgeInsets.only(left: 24),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Soru: ${item.question}',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: isDark ? Colors.white60 : Colors.black87,
                ),
              ),
            ),
          ],

          // Yanlış yapıldıysa: Kullanıcı Cevabı vs Doğru Cevap Karşılaştırması
          if (!item.isCorrect &&
              (item.userAnswer != null || item.correctAnswer != null)) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (item.userAnswer != null && item.userAnswer!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Senin cevabın: ${item.userAnswer}',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  if (item.correctAnswer != null &&
                      item.correctAnswer!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Doğru cevap: ${item.correctAnswer}',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.green,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
