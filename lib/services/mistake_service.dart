import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'streak_service.dart';

class MistakeItem {
  final String id;
  final String word;
  final String meaning;
  final String sourceGame;
  final String? wrongAnswer;
  final int mistakeCount;
  final DateTime createdAt;
  final DateTime lastMistakenAt;

  const MistakeItem({
    required this.id,
    required this.word,
    required this.meaning,
    required this.sourceGame,
    this.wrongAnswer,
    this.mistakeCount = 1,
    required this.createdAt,
    required this.lastMistakenAt,
  });

  MistakeItem copyWith({
    String? id,
    String? word,
    String? meaning,
    String? sourceGame,
    String? wrongAnswer,
    int? mistakeCount,
    DateTime? createdAt,
    DateTime? lastMistakenAt,
  }) {
    return MistakeItem(
      id: id ?? this.id,
      word: word ?? this.word,
      meaning: meaning ?? this.meaning,
      sourceGame: sourceGame ?? this.sourceGame,
      wrongAnswer: wrongAnswer ?? this.wrongAnswer,
      mistakeCount: mistakeCount ?? this.mistakeCount,
      createdAt: createdAt ?? this.createdAt,
      lastMistakenAt: lastMistakenAt ?? this.lastMistakenAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'word': word,
        'meaning': meaning,
        'sourceGame': sourceGame,
        'wrongAnswer': wrongAnswer,
        'mistakeCount': mistakeCount,
        'createdAt': createdAt.toIso8601String(),
        'lastMistakenAt': lastMistakenAt.toIso8601String(),
      };

  factory MistakeItem.fromJson(Map json) {
    return MistakeItem(
      id: json['id']?.toString() ?? UniqueKey().toString(),
      word: json['word']?.toString().trim() ?? '',
      meaning: json['meaning']?.toString().trim() ?? '',
      sourceGame: json['sourceGame']?.toString().trim() ?? 'Oyun',
      wrongAnswer: json['wrongAnswer']?.toString().trim(),
      mistakeCount: (json['mistakeCount'] is num)
          ? (json['mistakeCount'] as num).toInt()
          : (int.tryParse(json['mistakeCount']?.toString() ?? '') ?? 1),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      lastMistakenAt: json['lastMistakenAt'] != null
          ? DateTime.tryParse(json['lastMistakenAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class MistakeService {
  MistakeService._();
  static final MistakeService instance = MistakeService._();

  static const String _storageKey = 'playengground_mistakes_v1';
  final ValueNotifier<List<MistakeItem>> mistakesNotifier =
      ValueNotifier<List<MistakeItem>>([]);

  List<MistakeItem> get mistakes => mistakesNotifier.value;
  int get count => mistakesNotifier.value.length;
  bool get hasMistakes => mistakesNotifier.value.isNotEmpty;

  bool _initialized = false;

  static MistakeItem? _safeParseItem(dynamic rawItem) {
    if (rawItem == null || rawItem is! Map) return null;
    try {
      final item = MistakeItem.fromJson(rawItem);
      if (item.word.isEmpty || item.meaning.isEmpty) return null;
      return item;
    } catch (e) {
      debugPrint('MistakeItem parsing error: $e');
      return null;
    }
  }

  /// Servisi başlatır ve kayıtlı hataları hafızadan yükler.
  Future<void> init({bool force = false}) async {
    if (_initialized && !force) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      try {
        await prefs.reload();
      } catch (_) {}

      final rawJson = prefs.getString(_storageKey);
      if (rawJson != null && rawJson.trim().isNotEmpty) {
        final dynamic decoded = jsonDecode(rawJson);
        if (decoded is List) {
          final List<MistakeItem> loaded = [];
          for (final item in decoded) {
            final parsed = _safeParseItem(item);
            if (parsed != null) {
              loaded.add(parsed);
            }
          }
          mistakesNotifier.value = List.unmodifiable(loaded);
          final now = DateTime.now();
          final practicedToday = loaded.any(
            (m) =>
                m.lastMistakenAt.year == now.year &&
                m.lastMistakenAt.month == now.month &&
                m.lastMistakenAt.day == now.day,
          );
          if (practicedToday) {
            await StreakService.instance.recordPractice();
          }
        }
      }
    } catch (e) {
      debugPrint('MistakeService init hatası: $e');
    } finally {
      _initialized = true;
    }
  }

  /// Yeni bir hata kaydeder veya var olan hatanın sayacını artırır.
  Future<void> recordMistake({
    required String word,
    required String meaning,
    required String sourceGame,
    String? wrongAnswer,
  }) async {
    // Hafıza henüz yüklenmemişse önce mutlaka yükle
    if (!_initialized) {
      await init();
    }

    final cleanWord = word.trim();
    final cleanMeaning = meaning.trim();
    if (cleanWord.isEmpty || cleanMeaning.isEmpty) return;

    final currentList = List<MistakeItem>.from(mistakesNotifier.value);
    final now = DateTime.now();

    final existingIndex = currentList.indexWhere(
      (item) => item.word.toLowerCase() == cleanWord.toLowerCase(),
    );

    if (existingIndex >= 0) {
      final existing = currentList[existingIndex];
      final updated = existing.copyWith(
        meaning: cleanMeaning.isNotEmpty ? cleanMeaning : existing.meaning,
        sourceGame: sourceGame,
        wrongAnswer: wrongAnswer ?? existing.wrongAnswer,
        mistakeCount: existing.mistakeCount + 1,
        lastMistakenAt: now,
      );
      // En son hata yapılanı listenin başına taşı
      currentList.removeAt(existingIndex);
      currentList.insert(0, updated);
    } else {
      final newItem = MistakeItem(
        id: '${now.millisecondsSinceEpoch}_${cleanWord.hashCode}',
        word: cleanWord,
        meaning: cleanMeaning,
        sourceGame: sourceGame,
        wrongAnswer: wrongAnswer,
        mistakeCount: 1,
        createdAt: now,
        lastMistakenAt: now,
      );
      currentList.insert(0, newItem);
    }

    mistakesNotifier.value = List.unmodifiable(currentList);
    await StreakService.instance.recordPractice();
    await _persist();
  }

  /// Belirli bir hatayı "Anladım" diyerek listeden kaldırır.
  Future<bool> removeMistake(String id) async {
    final currentList = List<MistakeItem>.from(mistakesNotifier.value);
    final initialLength = currentList.length;
    currentList.removeWhere((item) => item.id == id);

    if (currentList.length != initialLength) {
      mistakesNotifier.value = List.unmodifiable(currentList);
      await _persist();
      return true;
    }
    return false;
  }

  /// Tüm hataları temizler.
  Future<void> clearAll() async {
    mistakesNotifier.value = List.unmodifiable(<MistakeItem>[]);
    await _persist();
  }

  /// Hataları oyunlarda (Memory Match, Hangman, Sound Catch, Meaning Sniper)
  /// doğrudan oynanabilir bir sözlük (`Map<String, String>`) formatında döner.
  Map<String, String> getAsCustomDict() {
    final dict = <String, String>{};
    for (final item in mistakes) {
      final key = item.word.trim();
      final val = item.meaning.trim();
      if (key.isNotEmpty && val.isNotEmpty && !dict.containsKey(key)) {
        dict[key] = val;
      }
    }
    return dict;
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(
        mistakesNotifier.value.map((m) => m.toJson()).toList(),
      );
      await prefs.setString(_storageKey, encoded);
    } catch (e) {
      debugPrint('MistakeService persist hatası: $e');
    }
  }
}
