import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'tts/tts_bridge_stub.dart'
    if (dart.library.js_interop) 'tts/tts_bridge_web.dart';

class TtsService {
  static final TtsService _instance = TtsService._internal();
  static TtsService get instance => _instance;

  final FlutterTts _flutterTts = FlutterTts();
  bool _initialized = false;
  bool _isMuted = false;

  bool get isMuted => _isMuted;

  TtsService._internal();

  Future<void> init() async {
    if (_initialized) return;
    try {
      if (kIsWeb && ttsWebSupported()) {
        _initialized = true;
        return;
      }
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(0.85);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      // Lock to an English voice on native platforms
      try {
        final dynamic voices = await _flutterTts.getVoices;
        if (voices is List) {
          for (final dynamic v in voices) {
            if (v is Map) {
              final locale = (v['locale'] ?? '').toString().toLowerCase();
              final name = (v['name'] ?? '').toString().toLowerCase();
              if (locale.startsWith('en') ||
                  name.contains('english') ||
                  name.contains('en-')) {
                await _flutterTts.setVoice({
                  'name': v['name'].toString(),
                  'locale': v['locale'].toString(),
                });
                break;
              }
            }
          }
        }
      } catch (_) {}

      _initialized = true;
    } catch (e) {
      debugPrint('Error initializing TtsService: $e');
    }
  }

  void setMuted(bool muted) {
    _isMuted = muted;
    if (_isMuted) {
      stop();
    }
  }

  void toggleMute() {
    setMuted(!_isMuted);
  }

  /// Checks if the text appears to be Turkish or contains Turkish characters.
  /// User rule: "HİÇ BİR TÜRKÇE İFADEYİ SESLENDİRME"
  bool isTurkishOrNonEnglish(String text) {
    final turkishCharRegex = RegExp(r'[çÇğĞıİöÖşŞüÜ]');
    if (turkishCharRegex.hasMatch(text)) {
      return true;
    }
    return false;
  }

  /// Cleans up English text (e.g. blanks like ___ or special symbols).
  String cleanText(String text) {
    var cleaned = text.trim();
    // Replace fill-in blanks like "___" or "____" with a space
    cleaned = cleaned.replaceAll(RegExp(r'_+'), ' ');
    // Remove emojis or special characters if any
    cleaned = cleaned.replaceAll(RegExp(r'[^\w\s\x27\.,!?\-]'), ' ');
    // Collapse multiple spaces
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned;
  }

  /// Speaks the given English text locked strictly to English.
  Future<void> speak(String? text) async {
    if (_isMuted || text == null) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    // Never speak Turkish expressions
    if (isTurkishOrNonEnglish(trimmed)) {
      debugPrint('TtsService: Skipped Turkish/non-English text: $trimmed');
      return;
    }

    final cleaned = cleanText(trimmed);
    if (cleaned.isEmpty) return;

    try {
      // 1. If running on Web, use the English-locked native SpeechSynthesis bridge
      if (kIsWeb && ttsWebSupported()) {
        ttsWebSpeak(cleaned, 0.95);
        return;
      }

      // 2. Non-web platform / fallback
      if (!_initialized) {
        await init();
      }
      await _flutterTts.stop();
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.speak(cleaned);
    } catch (e) {
      debugPrint('Error in TtsService.speak: $e');
    }
  }

  Future<void> stop() async {
    try {
      if (kIsWeb && ttsWebSupported()) {
        ttsWebStop();
      }
      await _flutterTts.stop();
    } catch (e) {
      debugPrint('Error stopping TTS: $e');
    }
  }
}
