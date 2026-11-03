import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AudioService {
  static final AudioPlayer _correctPlayer = AudioPlayer();
  static final AudioPlayer _incorrectPlayer = AudioPlayer();
  static final AudioPlayer _successPlayer = AudioPlayer();
  static final AudioPlayer _failurePlayer = AudioPlayer();

  static void playCorrect() {
    try {
      _correctPlayer.stop().then((_) {
        _correctPlayer.play(
          kIsWeb ? UrlSource('assets/assets/correct.wav') : AssetSource('correct.wav')
        );
      });
    } catch (_) {}
  }

  static void playIncorrect() {
    try {
      _incorrectPlayer.stop().then((_) {
        _incorrectPlayer.play(
          kIsWeb ? UrlSource('assets/assets/wrong.mp3') : AssetSource('wrong.mp3')
        );
      });
    } catch (_) {}
  }

  static void playSuccess() {
    try {
      _successPlayer.stop().then((_) {
        _successPlayer.play(
          kIsWeb ? UrlSource('assets/assets/success.wav') : AssetSource('success.wav')
        );
      });
    } catch (_) {}
  }

  static void playFailure() {
    try {
      _failurePlayer.stop().then((_) {
        _failurePlayer.play(
          kIsWeb ? UrlSource('assets/assets/failure.mp3') : AssetSource('failure.mp3')
        );
      });
    } catch (_) {}
  }
}

