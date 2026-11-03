// Non-web platforms: PWA install is not applicable.

bool pwaSupported() => false;

bool pwaCanPrompt() => false;

bool pwaIsIos() => false;

bool pwaIsAndroid() => false;

bool pwaIsInstalled() => false;

Future<String> pwaPrompt() async => 'unavailable';

void pwaOnChange(void Function() callback) {}
