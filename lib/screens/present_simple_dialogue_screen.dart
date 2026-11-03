import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import '../data/present_simple_data.dart';
import '../services/audio_service.dart';
import '../widgets/exit_confirmation_dialog.dart';
import '../widgets/game_tutorial_popup.dart';
import '../widgets/marquee_title.dart';

class PresentSimpleDialogueScreen extends StatefulWidget {
  const PresentSimpleDialogueScreen({super.key});

  @override
  State<PresentSimpleDialogueScreen> createState() =>
      _PresentSimpleDialogueScreenState();
}

class _PresentSimpleDialogueScreenState
    extends State<PresentSimpleDialogueScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _audioError = false;

  // Kullanıcı durumu
  bool _showQuestions = false;
  bool _hasCheckedAnswers = false;

  // Öğrenci cevapları (questionId -> user selected option)
  final Map<int, String> _userAnswers = {};

  final PSDialogueData _dialogue = psSampleDialogue;

  @override
  void initState() {
    super.initState();
    _setupAudio();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await GameTutorialPopup.show(
        context,
        tutorialKey: 'ps_dialogue_tutorial',
        title: 'Present Simple Listening',
        icon: FontAwesomeIcons.headphones,
        color: const Color(0xFFEC4899),
        tutorialTextTr:
            'Present Simple Listening ekranında dinleme ve anlama becerilerinizi geliştirin!\n\n'
            '• Oynatıcıyı başlatarak günlük konuşma diyaloğunu dikkatle dinleyin.\n'
            '• Konuşma balonlarını takip ederek karakterlerin kurduğu Present Simple cümlelerini inceleyin.\n'
            '• Dinlemeyi tamamladıktan sonra "Soruları Göster" butonuna dokunarak diyaloğa ait Doğru/Yanlış ve boşluk doldurma sorularını yanıtlayın!',
        tutorialTextEn:
            'Listen to the dialogue! When finished, tap "Show Questions" to solve True/False and fill-in-the-blank questions.',
        hideLanguageToggle: false,
      );
    });
  }

  void _setupAudio() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state == PlayerState.playing);
      }
    });

    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) {
        setState(() => _duration = newDuration);
      }
    });

    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) {
        _position = newPosition; // Avoid setState here to prevent full screen rebuilds
      }
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  Future<void> _playPause() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.setPlaybackRate(1.0);
        bool started = false;

        if (kIsWeb) {
          final candidates = [
            'assets/assets/audio/present_simple_dialogue.wav.wav',
            'assets/audio/present_simple_dialogue.wav.wav',
            'audio/present_simple_dialogue.wav.wav',
          ];
          for (final path in candidates) {
            try {
              await _audioPlayer.play(UrlSource(path));
              started = true;
              break;
            } catch (_) {}
          }
        }

        if (!started) {
          final assetCandidates = [
            'audio/present_simple_dialogue.wav.wav',
            'assets/audio/present_simple_dialogue.wav.wav',
          ];
          for (final path in assetCandidates) {
            try {
              await _audioPlayer.play(AssetSource(path));
              started = true;
              break;
            } catch (_) {}
          }
        }

        if (!started) {
          throw Exception('Could not play audio asset from any candidate path');
        }
      }
      setState(() => _audioError = false);
    } catch (e) {
      debugPrint('Audio playback error: $e');
      setState(() {
        _audioError = true;
        _isPlaying = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEC4899),
            content: Text(
              'Ses dosyası oynatılamadı. Aşağıdaki konuşma metnini açarak okuyabilir ve soruları çözebilirsiniz!',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _seek(Duration position) async {
    await _audioPlayer.seek(position);
  }


  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _checkAnswers() {
    setState(() => _hasCheckedAnswers = true);

    int correctCount = 0;
    for (final q in _dialogue.questions) {
      if (_userAnswers[q.id] == q.correctAnswer) {
        correctCount++;
      }
    }

    if (correctCount == _dialogue.questions.length) {
      AudioService.playSuccess();
    } else {
      AudioService.playCorrect();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Text(
          'Well done! You answered $correctCount out of ${_dialogue.questions.length} questions correctly.',
          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _resetQuiz() {
    setState(() {
      _userAnswers.clear();
      _hasCheckedAnswers = false;
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await showExitConfirmationDialog(context);
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: MarqueeTitle(
            title: 'Present Simple Dialogue',
            leadingIcon: const Icon(FontAwesomeIcons.comments, color: Color(0xFF8B5CF6), size: 18),
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.transparent,
          actions: [
            IconButton(
              tooltip: 'Reset Quiz',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _resetQuiz,
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Dinleme Paneli (Audio Player Card)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset(
                        'assets/images/dialogue_background.jpg',
                        width: double.infinity,
                        fit: BoxFit.fitWidth,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildAudioPlayerCard(isDark, cardBg),
                    const SizedBox(height: 24),

                    // 3. "Soruları Göster" Butonu veya Soru Listesi
                    if (!_showQuestions) ...[
                      Center(
                        child: SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() => _showQuestions = true);
                            },
                            icon: const Icon(FontAwesomeIcons.clipboardQuestion),
                            label: Text(
                              'SHOW QUESTIONS 📝',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEC4899),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              elevation: 6,
                              shadowColor: const Color(0xFFEC4899).withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      // Sorular Başlığı
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'LISTENING QUESTIONS',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                              color: const Color(0xFFEC4899),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => setState(() => _showQuestions = false),
                            icon: const Icon(Icons.visibility_off_outlined, size: 18),
                            label: Text('Hide Questions', style: GoogleFonts.outfit()),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Sorular
                      ..._dialogue.questions.map((q) => _buildQuestionCard(q, isDark, cardBg)),

                      const SizedBox(height: 20),
                      // Kontrol Et Butonu
                      SizedBox(
                        height: 58,
                        child: ElevatedButton.icon(
                          onPressed: _checkAnswers,
                          icon: const Icon(Icons.check_circle_rounded),
                          label: Text(
                            'CHECK ANSWERS',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            elevation: 5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- AUDIO PLAYER CARD ---
  Widget _buildAudioPlayerCard(bool isDark, Color cardBg) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFEC4899).withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEC4899).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  FontAwesomeIcons.headphones,
                  color: Color(0xFFEC4899),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _dialogue.title,
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _dialogue.subtitle,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Progress Slider
          StreamBuilder<Duration>(
            stream: _audioPlayer.onPositionChanged,
            initialData: _position,
            builder: (context, snapshot) {
              final currentPos = snapshot.data ?? Duration.zero;
              return Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFFEC4899),
                      inactiveTrackColor: isDark ? Colors.white12 : Colors.grey.shade300,
                      thumbColor: const Color(0xFFEC4899),
                      trackHeight: 6,
                    ),
                    child: Slider(
                      value: _duration.inMilliseconds > 0
                          ? (currentPos.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
                          : 0.0,
                      onChanged: (val) {
                        final targetMs = (val * _duration.inMilliseconds).toInt();
                        _seek(Duration(milliseconds: targetMs));
                      },
                    ),
                  ),
                  // Duration Labels
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(currentPos),
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        Text(
                          _formatDuration(_duration),
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),

          // Controls Row (Play/Pause)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _playPause,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEC4899),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
              ),
            ],
          ),
          if (_audioError) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'ℹ️ Audio dialogue. If audio cannot be played, expand the transcript below to read along and solve the questions!',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 12, color: Colors.amber[800]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Transcript removed

  // --- QUESTION CARD ---
  Widget _buildQuestionCard(PSDialogueQuestion q, bool isDark, Color cardBg) {
    final userAnswer = _userAnswers[q.id];
    final isChecked = _hasCheckedAnswers;
    final isCorrect = userAnswer == q.correctAnswer;

    Color borderColor = isDark ? Colors.white12 : Colors.grey.shade300;
    if (isChecked) {
      borderColor = isCorrect ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: isChecked ? 2.0 : 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  q.type == DialogueQuestionType.trueFalse
                      ? 'TRUE / FALSE'
                      : (q.type == DialogueQuestionType.fillBlank
                          ? 'FILL THE BLANK'
                          : 'MULTIPLE CHOICE'),
                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
              if (isChecked)
                Icon(
                  isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: isCorrect ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  size: 22,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${q.id}. ${q.question}',
            style: GoogleFonts.outfit(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 14),

          // Seçenekler (Radio Buttons / Option Pills)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: q.options.map((opt) {
              final isSelected = userAnswer == opt;
              Color chipColor = isSelected
                  ? const Color(0xFFEC4899)
                  : (isDark ? const Color(0xFF13111C) : const Color(0xFFF1F5F9));
              Color chipTextColor = isSelected
                  ? Colors.white
                  : (isDark ? Colors.white70 : Colors.black87);

              if (isChecked) {
                if (opt == q.correctAnswer) {
                  chipColor = const Color(0xFF10B981);
                  chipTextColor = Colors.white;
                } else if (isSelected && !isCorrect) {
                  chipColor = const Color(0xFFEF4444);
                  chipTextColor = Colors.white;
                }
              }

              return InkWell(
                onTap: isChecked
                    ? null
                    : () {
                        setState(() => _userAnswers[q.id] = opt);
                      },
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: chipColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? Colors.transparent : (isDark ? Colors.white10 : Colors.black12),
                    ),
                  ),
                  child: Text(
                    opt,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: chipTextColor,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          if (isChecked && !isCorrect) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '💡 Doğru Cevap: ${q.correctAnswer}\n${q.hint}',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.red[200] : Colors.red[800],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
