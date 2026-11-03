import 'dart:math';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/word_marathon_data.dart';
import '../services/audio_service.dart';
import '../services/mistake_service.dart';
import '../services/streak_service.dart';
import '../services/tts_service.dart';
import 'hangman_screen.dart';
import 'meaning_sniper_screen.dart';
import 'memory_card_screen.dart';
import 'sound_catch_screen.dart';

class MistakeBankScreen extends StatefulWidget {
  const MistakeBankScreen({super.key});

  @override
  State<MistakeBankScreen> createState() => _MistakeBankScreenState();
}

class _MistakeBankScreenState extends State<MistakeBankScreen> {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  List<MistakeItem> _displayedMistakes = [];

  @override
  void initState() {
    super.initState();
    _displayedMistakes = List<MistakeItem>.from(MistakeService.instance.mistakes);
    MistakeService.instance.init().then((_) {
      if (mounted) {
        setState(() {
          _displayedMistakes = List<MistakeItem>.from(MistakeService.instance.mistakes);
        });
      }
    });
  }

  void _onMistakeUnderstood(MistakeItem item, int index) async {
    // Hafif başarı sesi çal
    AudioService.playCorrect();

    // Listeden animasyonla kaldır
    if (index >= 0 && index < _displayedMistakes.length) {
      final removedItem = _displayedMistakes.removeAt(index);
      _listKey.currentState?.removeItem(
        index,
        (context, animation) => _buildMistakeCard(removedItem, animation, null),
        duration: const Duration(milliseconds: 300),
      );
      await MistakeService.instance.removeMistake(item.id);
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _showClearAllConfirmDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E38),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.delete_sweep_rounded, color: Color(0xFFEF4444), size: 24),
            const SizedBox(width: 10),
            Text(
              'Tüm Hataları Temizle',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          'Hata Bankası\'ndaki tüm kelimeleri silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.',
          style: GoogleFonts.outfit(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Vazgeç',
              style: GoogleFonts.outfit(color: Colors.white60),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await MistakeService.instance.clearAll();
              if (mounted) {
                setState(() {
                  _displayedMistakes.clear();
                });
              }
            },
            child: Text(
              'Evet, Temizle',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  /// Hataları oyun için hazırlar; oyun gereksinimini karşılayacak sayıda kelime yoksa
  /// ek kelimelerle zenginleştirir.
  Map<String, String> _prepareGameDict({int minPairs = 4}) {
    final userDict = MistakeService.instance.getAsCustomDict();
    final combined = Map<String, String>.from(userDict);

    if (combined.length < minPairs) {
      final pool = wordMarathonDictionary.entries.toList()..shuffle(Random());
      for (final entry in pool) {
        if (!combined.containsKey(entry.key)) {
          combined[entry.key] = entry.value;
        }
        if (combined.length >= minPairs) break;
      }
    }
    return combined;
  }

  void _openGamePickerBottomSheet() {
    final mistakesCount = MistakeService.instance.count;
    if (mistakesCount == 0) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          decoration: const BoxDecoration(
            color: Color(0xFF16162A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 30,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.sports_esports_rounded, color: Color(0xFF00E5FF), size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'Hatalarınla Oyna & Pekiştir',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Listendeki $mistakesCount hatayı seçtiğin oyuna aktararak pratik yapabilirsin.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 20),

              // Game 1: Memory Match
              _buildGameOptionTile(
                title: 'Memory Match',
                subtitle: 'Hatalı kelimeleri ve anlamlarını kart eşleştirerek pekiştir.',
                icon: FontAwesomeIcons.layerGroup,
                color: const Color(0xFF3B82F6),
                onTap: () {
                  Navigator.pop(ctx);
                  StreakService.instance.recordPractice();
                  final dict = _prepareGameDict(minPairs: 4);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MemoryGameScreen(customDict: dict),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),

              // Game 2: Sound Catch
              _buildGameOptionTile(
                title: 'Sound Catch',
                subtitle: 'Hatalı kelimelerin telaffuzunu dinle, benzer seçenekler arasından doğruyu seç.',
                icon: FontAwesomeIcons.headphones,
                color: const Color(0xFFF59E0B),
                onTap: () {
                  Navigator.pop(ctx);
                  StreakService.instance.recordPractice();
                  final dict = _prepareGameDict(minPairs: 3);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SoundCatchScreen(customDict: dict),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),

              // Game 3: Meaning Sniper
              _buildGameOptionTile(
                title: 'Meaning Sniper',
                subtitle: 'Hatalı kelimelerinin doğru karşılıklarına hızla kilitlenip nişan al.',
                icon: FontAwesomeIcons.crosshairs,
                color: const Color(0xFF10B981),
                onTap: () {
                  Navigator.pop(ctx);
                  StreakService.instance.recordPractice();
                  final dict = _prepareGameDict(minPairs: 4);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MeaningSniperScreen(customDict: dict),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),

              // Game 4: Hangman
              _buildGameOptionTile(
                title: 'Hangman',
                subtitle: 'Hata yaptığın gizli kelimeleri harf harf tahmin ederek çöz.',
                icon: FontAwesomeIcons.personThroughWindow,
                color: const Color(0xFFEF4444),
                onTap: () {
                  Navigator.pop(ctx);
                  StreakService.instance.recordPractice();
                  final dict = _prepareGameDict(minPairs: 1);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HangmanGameScreen(customDict: dict),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGameOptionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C36),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios_rounded, color: color, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMistakeCard(
    MistakeItem item,
    Animation<double> animation,
    int? currentIndex,
  ) {
    return SizeTransition(
      sizeFactor: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
      child: FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF16162A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: item.mistakeCount > 1
                    ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
                    : const Color(0xFF2A2A4A),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Audio pronunciation button
                Tooltip(
                  message: 'Telaffuzu Dinle',
                  child: InkWell(
                    onTap: () => TtsService.instance.speak(item.word),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.volume_up_rounded,
                        color: Color(0xFF00E5FF),
                        size: 22,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Word, Meaning and Badges
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.word,
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (item.mistakeCount > 1) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                                ),
                              ),
                              child: Text(
                                '${item.mistakeCount}x',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFEF4444),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.meaning,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.sourceGame,
                              style: GoogleFonts.outfit(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFFC4B5FD),
                              ),
                            ),
                          ),
                          if (item.wrongAnswer != null &&
                              item.wrongAnswer!.trim().isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Seçtiğin: ${item.wrongAnswer}',
                                style: GoogleFonts.outfit(
                                  fontSize: 10.5,
                                  color: Colors.white60,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // "Anladım" Checkmark Tick Button
                Tooltip(
                  message: 'Hatayı Anladım (Listeden Kaldır)',
                  child: ElevatedButton(
                    onPressed: currentIndex != null
                        ? () => _onMistakeUnderstood(item, currentIndex)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.2),
                      foregroundColor: const Color(0xFF10B981),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: const Color(0xFF10B981).withValues(alpha: 0.4),
                          width: 1.2,
                        ),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF10B981),
                          size: 22,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Anladım',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF10B981),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mistakesCount = _displayedMistakes.length;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                FontAwesomeIcons.circleExclamation,
                color: Color(0xFFEF4444),
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Hata Bankası',
              style: GoogleFonts.outfit(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          if (mistakesCount > 0)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white70),
              tooltip: 'Tüm Hataları Temizle',
              onPressed: _showClearAllConfirmDialog,
            ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),

                  // Top Action: Play With Mistakes CTA (Solid dark background, no gradient)
                  if (mistakesCount > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16162A),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                                width: 1.2,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.sports_esports_rounded,
                              color: Color(0xFF8B5CF6),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hatalarını Oyuna Dönüştür',
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$mistakesCount hata birikti. Seçtiğin oyunda pekiştir!',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _openGamePickerBottomSheet,
                            icon: const Icon(Icons.play_arrow_rounded, size: 20),
                            label: Text(
                              'Oyna',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8B5CF6),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Header Count & Instruction
                  if (mistakesCount > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEF4444),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Öğrenilecek Hatalar ($mistakesCount)',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Tick tuşuna basarak temizle',
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              color: Colors.white38,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),

                  // List of mistakes or Empty state
                  Expanded(
                    child: mistakesCount == 0
                        ? _buildEmptyState()
                        : AnimatedList(
                            key: _listKey,
                            physics: const BouncingScrollPhysics(),
                            initialItemCount: _displayedMistakes.length,
                            itemBuilder: (context, index, animation) {
                              if (index >= _displayedMistakes.length) {
                                return const SizedBox.shrink();
                              }
                              final item = _displayedMistakes[index];
                              return _buildMistakeCard(item, animation, index);
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
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.sentiment_very_satisfied_rounded,
                color: Color(0xFF10B981),
                size: 64,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Tebrikler! 🎉',
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hata Bankası\'nda bekleyen hiç kelime yok!\nTüm hatalarını anladın ve öğrendin.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.white70,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: Text(
                'Oyunlara Dön',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
