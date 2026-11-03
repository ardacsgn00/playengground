import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'browser_detector_stub.dart'
    if (dart.library.js_interop) 'browser_detector_web.dart';
import 'user_identity_service.dart';

class VisitRecord {
  final String id;
  final String deviceId;
  final String os;
  final String deviceType;
  final String browser;
  final String resolution;
  final int timestamp;
  final String formattedDate;
  final int visitNumber;
  final String appVersion;

  const VisitRecord({
    required this.id,
    required this.deviceId,
    required this.os,
    required this.deviceType,
    this.browser = 'Bilinmiyor',
    required this.resolution,
    required this.timestamp,
    required this.formattedDate,
    required this.visitNumber,
    required this.appVersion,
  });

  factory VisitRecord.fromJson(String id, Map<dynamic, dynamic> json) {
    return VisitRecord(
      id: id,
      deviceId: json['deviceId']?.toString() ?? 'anon',
      os: json['os']?.toString() ?? 'Bilinmiyor',
      deviceType: json['deviceType']?.toString() ?? 'Cihaz',
      browser: json['browser']?.toString() ?? 'Bilinmiyor',
      resolution: json['resolution']?.toString() ?? '-',
      timestamp: (json['timestamp'] is num)
          ? (json['timestamp'] as num).toInt()
          : (int.tryParse(json['timestamp']?.toString() ?? '') ?? 0),
      formattedDate: json['formattedDate']?.toString() ?? '',
      visitNumber: (json['visitNumber'] is num)
          ? (json['visitNumber'] as num).toInt()
          : (int.tryParse(json['visitNumber']?.toString() ?? '') ?? 1),
      appVersion: json['appVersion']?.toString() ?? 'v0.0.x',
    );
  }
}

class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  static const String _rtdbBaseUrl =
      'https://playengground-5cf88-default-rtdb.firebaseio.com/stats';
  static const String _visitCountKey = 'playengground_local_visit_count';

  bool _sessionRecorded = false;

  /// Güvenli, anonim rastgele bir cihaz kimliği üretir veya var olanı döner.
  Future<String> _getOrCreateDeviceId() async {
    return UserIdentityService.instance.getDeviceId();
  }

  /// Ziyaret sayacını yerel olarak artırıp kaçıncı ziyaret olduğunu döner.
  Future<int> _incrementLocalVisitCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getInt(_visitCountKey) ?? 0;
      final next = current + 1;
      await prefs.setInt(_visitCountKey, next);
      return next;
    } catch (_) {
      return 1;
    }
  }

  /// İşletim sistemini tespit eder.
  String _detectOS() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.iOS:
        return 'iOS';
      case TargetPlatform.windows:
        return 'Windows';
      case TargetPlatform.macOS:
        return 'macOS';
      case TargetPlatform.linux:
        return 'Linux';
      case TargetPlatform.fuchsia:
        return 'Fuchsia';
    }
  }

  /// Ekran genişliğine göre cihaz tipini belirler.
  String _detectDeviceType(double width) {
    if (width < 600) return 'Mobil';
    if (width < 1024) return 'Tablet';
    return 'Masaüstü';
  }

  /// Tarih ve saati Türkçe okunabilir formatta döner.
  String _formatDateTime(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year.toString();
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day.$month.$year • $hour:$minute';
  }

  /// Oturum başında tamamen kişisel veri içermeyen anonim ziyareti kaydeder.
  /// Asla hata fırlatmaz ve arayüzü bloklamaz.
  Future<void> recordVisit(
    BuildContext context, {
    String appVersion = 'v0.4.9',
  }) async {
    if (_sessionRecorded) return;
    _sessionRecorded = true;

    try {
      final media = MediaQuery.maybeOf(context);
      final size = media?.size ?? const Size(0, 0);
      final dpr = media?.devicePixelRatio ?? 1.0;

      final deviceId = await _getOrCreateDeviceId();
      final visitNumber = await _incrementLocalVisitCount();
      final os = _detectOS();
      final deviceType = _detectDeviceType(size.width);
      final browser = kIsWeb ? getBrowserName() : 'Native';
      final resolution = size.width > 0
          ? '${size.width.toInt()}x${size.height.toInt()} (${dpr.toStringAsFixed(1)}x)'
          : 'Bilinmiyor';

      final now = DateTime.now();
      final payload = {
        'deviceId': deviceId,
        'os': os,
        'deviceType': deviceType,
        'browser': browser,
        'resolution': resolution,
        'timestamp': now.millisecondsSinceEpoch,
        'formattedDate': _formatDateTime(now),
        'visitNumber': visitNumber,
        'appVersion': appVersion,
      };

      final uri = Uri.parse('$_rtdbBaseUrl/visits.json');
      await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 6));
    } catch (e) {
      debugPrint('AnalyticsService visit logging error: $e');
    }
  }

  /// Kayıtlı tüm anonim ziyaretleri Realtime Database üzerinden çeker.
  Future<List<VisitRecord>> fetchVisits() async {
    try {
      final uri = Uri.parse('$_rtdbBaseUrl/visits.json');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        if (res.body == 'null' || res.body.trim().isEmpty) {
          return [];
        }
        final dynamic decoded = jsonDecode(res.body);
        if (decoded is Map) {
          final List<VisitRecord> list = [];
          decoded.forEach((key, val) {
            if (val is Map) {
              list.add(VisitRecord.fromJson(key.toString(), val));
            }
          });
          // En yeni ziyaret en başta olacak şekilde sırala
          list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return list;
        }
      }
      return [];
    } catch (e) {
      debugPrint('AnalyticsService fetchVisits error: $e');
      rethrow;
    }
  }
}
