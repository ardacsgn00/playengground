import 'dart:js_interop';

/// Mirrors `window.pwaInstall` defined in web/index.html.
extension type _PwaInstall._(JSObject _) implements JSObject {
  external bool canPrompt();
  external bool isIos();
  external bool isAndroid();
  external bool isInstalled();
  external JSPromise<JSString> prompt();
  external void onChange(JSFunction cb);
}

@JS('pwaInstall')
external _PwaInstall? get _pwa;

bool pwaSupported() => _pwa != null;

bool pwaCanPrompt() => _pwa?.canPrompt() ?? false;

bool pwaIsIos() => _pwa?.isIos() ?? false;

bool pwaIsAndroid() => _pwa?.isAndroid() ?? false;

bool pwaIsInstalled() => _pwa?.isInstalled() ?? false;

Future<String> pwaPrompt() async {
  final pwa = _pwa;
  if (pwa == null) return 'unavailable';
  final result = await pwa.prompt().toDart;
  return result.toDart;
}

void pwaOnChange(void Function() callback) {
  _pwa?.onChange(callback.toJS);
}
