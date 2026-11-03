import 'dart:js_interop';

@JS('navigator.userAgent')
external JSString? get _userAgent;

String getBrowserName() {
  try {
    final ua = _userAgent?.toDart ?? '';
    if (ua.isEmpty) return 'Web Tarayıcısı';

    final lower = ua.toLowerCase();

    // Check specific browsers in order of distinct user-agent signatures
    if (lower.contains('edg/') || lower.contains('edge/')) {
      return 'Microsoft Edge';
    }
    if (lower.contains('opr/') || lower.contains('opera')) {
      return 'Opera';
    }
    if (lower.contains('brave') || lower.contains('brave/')) {
      return 'Brave';
    }
    if (lower.contains('vivaldi')) {
      return 'Vivaldi';
    }
    if (lower.contains('samsungbrowser')) {
      return 'Samsung Internet';
    }
    if (lower.contains('ucbrowser')) {
      return 'UC Browser';
    }
    if (lower.contains('firefox') || lower.contains('fxios')) {
      return 'Firefox';
    }
    if (lower.contains('chrome') || lower.contains('crios')) {
      return 'Chrome';
    }
    if (lower.contains('safari') && !lower.contains('chrome')) {
      return 'Safari';
    }

    return 'Web Tarayıcısı';
  } catch (_) {
    return 'Web';
  }
}

