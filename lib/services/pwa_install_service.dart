import 'package:flutter/foundation.dart';

import 'pwa/pwa_bridge_stub.dart'
    if (dart.library.js_interop) 'pwa/pwa_bridge_web.dart'
    as bridge;

/// Exposes PWA install state (beforeinstallprompt, iOS detection, standalone
/// mode) to Flutter widgets.
class PwaInstallService extends ChangeNotifier {
  PwaInstallService._() {
    if (bridge.pwaSupported()) {
      bridge.pwaOnChange(notifyListeners);
    }
  }

  static final PwaInstallService instance = PwaInstallService._();

  bool get isSupported => kIsWeb && bridge.pwaSupported();

  /// True when the browser handed us a deferred native install prompt
  /// (Chrome/Edge on Android & desktop).
  bool get canPrompt => bridge.pwaCanPrompt();

  bool get isIos => bridge.pwaIsIos();

  bool get isAndroid => bridge.pwaIsAndroid();

  /// Already running as an installed app (or just installed).
  bool get isInstalled => bridge.pwaIsInstalled();

  bool get shouldShowButton => isSupported && !isInstalled;

  /// Triggers the native install prompt. Returns 'accepted', 'dismissed',
  /// 'unavailable' or 'error'.
  Future<String> prompt() async {
    final outcome = await bridge.pwaPrompt();
    notifyListeners();
    return outcome;
  }
}
