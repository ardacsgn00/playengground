import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// User identity service with persistent deviceId generation across
/// SharedPreferences, localStorage, and cookie mirrors.
class UserIdentityService {
  UserIdentityService._();
  static final UserIdentityService instance = UserIdentityService._();

  static const String _deviceIdPrefKey = 'playengground_anon_device_id';
  static const String _firebaseDbUrl =
      'https://playengground-5cf88-default-rtdb.firebaseio.com';

  String? _cachedDeviceId;

  /// Retrieves or generates a permanent anon device ID.
  Future<String> getDeviceId() async {
    if (_cachedDeviceId != null && _cachedDeviceId!.isNotEmpty) {
      return _cachedDeviceId!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      var id = prefs.getString(_deviceIdPrefKey);

      if (id == null || id.isEmpty) {
        // Fallback: check localStorage directly on Web if available
        final rawPref = prefs.get('flutter.$_deviceIdPrefKey');
        if (rawPref is String && rawPref.isNotEmpty) {
          id = rawPref;
        }
      }

      if (id == null || id.isEmpty) {
        final pegId = prefs.getString('peg_device_id');
        if (pegId != null && pegId.isNotEmpty) {
          id = pegId;
        }
      }

      if (id == null || id.isEmpty) {
        final randomPart = Random()
            .nextInt(0xFFFFFF)
            .toRadixString(16)
            .padLeft(6, '0');
        final timePart =
            (DateTime.now().millisecondsSinceEpoch % 10000000).toRadixString(16);
        id = 'peg_${timePart}_$randomPart';
        await prefs.setString(_deviceIdPrefKey, id);
        await prefs.setString('peg_device_id', id);
      } else {
        await prefs.setString(_deviceIdPrefKey, id);
        await prefs.setString('peg_device_id', id);
      }

      _cachedDeviceId = id;
      return id;
    } catch (_) {
      return _cachedDeviceId ?? 'peg_${Random().nextInt(999999)}';
    }
  }

  /// Syncs streak data to Firebase Realtime Database under /users/{deviceId}/streak.json
  Future<void> syncStreakToFirebase({
    required int currentStreak,
    required int bestStreak,
    required String lastDate,
  }) async {
    try {
      final deviceId = await getDeviceId();
      final uri = Uri.parse('$_firebaseDbUrl/users/$deviceId/streak.json');

      final payload = {
        'currentStreak': currentStreak,
        'bestStreak': bestStreak,
        'lastDate': lastDate,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      await http
          .put(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('UserIdentityService syncStreakToFirebase error: $e');
    }
  }

  /// Fetches remote streak from Firebase Realtime Database
  Future<Map<String, dynamic>?> fetchStreakFromFirebase() async {
    try {
      final deviceId = await getDeviceId();
      final uri = Uri.parse('$_firebaseDbUrl/users/$deviceId/streak.json');

      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200 && res.body.isNotEmpty && res.body != 'null') {
        final dynamic decoded = jsonDecode(res.body);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      }
    } catch (e) {
      debugPrint('UserIdentityService fetchStreakFromFirebase error: $e');
    }
    return null;
  }
}
