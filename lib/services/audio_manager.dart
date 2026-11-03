import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioManager extends ChangeNotifier {
  static final AudioManager _instance = AudioManager._internal();
  static AudioManager get instance => _instance;

  AudioManager._internal() {
    _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    _bgmPlayer.setVolume(_bgmVolume);
    _openingPlayer.setVolume(_openingVolume);
  }

  final AudioPlayer _bgmPlayer = AudioPlayer(playerId: 'bgm_player');
  final AudioPlayer _openingPlayer = AudioPlayer(playerId: 'opening_player');

  bool _isBgmPlaying = false;
  bool _isLoadingBgm = false;
  double _bgmVolume = 0.5;
  final double _openingVolume = 0.7;

  bool get isBgmPlaying => _isBgmPlaying;
  bool get isLoadingBgm => _isLoadingBgm;
  double get bgmVolume => _bgmVolume;

  Source _getOpeningSource() {
    return kIsWeb
        ? UrlSource('assets/assets/opening.mp3')
        : AssetSource('opening.mp3');
  }

  Source _getBgmSource() {
    return kIsWeb
        ? UrlSource('assets/assets/bgmusic.mp3')
        : AssetSource('bgmusic.mp3');
  }

  Future<void> playOpeningSound() async {
    try {
      if (_openingPlayer.state == PlayerState.playing) {
        await _openingPlayer.stop();
      }
      try {
        await _openingPlayer.play(_getOpeningSource());
      } catch (_) {
        await _openingPlayer.play(
          kIsWeb ? UrlSource('assets/assets/opening.wav') : AssetSource('opening.wav'),
        );
      }
    } catch (e) {
      debugPrint("Error playing opening sound: $e");
    }
  }

  Future<void> toggleBgm() async {
    try {
      if (_isBgmPlaying) {
        await _bgmPlayer.pause();
        _isBgmPlaying = false;
        _isLoadingBgm = false;
        notifyListeners();
      } else {
        _isLoadingBgm = true;
        notifyListeners();

        await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
        await _bgmPlayer.setVolume(_bgmVolume);

        try {
          await _bgmPlayer.play(_getBgmSource());
        } catch (e) {
          debugPrint("Failed to play primary BGM source, trying wav fallback: $e");
          final fallback = kIsWeb
              ? UrlSource('assets/assets/bgmusic.wav')
              : AssetSource('bgmusic.wav');
          await _bgmPlayer.play(fallback);
        }

        _isBgmPlaying = true;
        _isLoadingBgm = false;
        notifyListeners();
      }
    } catch (e) {
      _isLoadingBgm = false;
      _isBgmPlaying = false;
      notifyListeners();
      debugPrint("Error toggling bgm: $e");
    }
  }

  Future<void> setBgmVolume(double volume) async {
    _bgmVolume = volume;
    await _bgmPlayer.setVolume(_bgmVolume);
    notifyListeners();
  }

  void disposePlayers() {
    _bgmPlayer.dispose();
    _openingPlayer.dispose();
  }
}
