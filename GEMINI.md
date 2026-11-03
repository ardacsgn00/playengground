# PLAYENGGROUND PROJE KURALLARI

## 1. Sürüm ve Firebase Deploy Süreci
- Her deploy öncesinde sürüm numarasını şu 4 dosyada eşzamanlı güncelle:
  1. `lib/screens/games_screen.dart` (`_AppVersionTag`)
  2. `lib/services/analytics_service.dart` (`appVersion`)
  3. `pubspec.yaml` (`version: X.Y.Z+N`)
  4. `web/index.html` (`flutter_bootstrap.js?v=X.Y.Z`)
- `flutter build web` komutundan sonra tarayıcı önbellek (cache) sorunlarını önlemek için `build/web/flutter_bootstrap.js` içindeki `main.dart.js` referansını `main.dart.js?v=X.Y.Z` olarak güncelle ve ardından `cmd.exe /c firebase deploy` çalıştır.

## 2. Veri Kalıcılığı (Streak, Hata Bankası, Skorlar)
- Yeni sürüm geçişlerinde kullanıcının `SharedPreferences` / `localStorage` üzerindeki verilerini (`StreakService`, `MistakeService`, `ScoreService`, `LevelService`) asla sıfırlama veya anahtar isimlerini değiştirme.

## 3. Oyun Açılış ve Pop-up Standardı
- Oyun açılışlarında (`initState` / `addPostFrameCallback`) asla peş peşe birden fazla pop-up (`GameTutorialPopup` -> `LevelSelectionDialog` -> `CategorySelectionDialog`) açma.
- Oyun tanıtımı (Nasıl Oynanır?), CEFR seviye seçimi (`A1–A2`, `B1–B2`, `Tümü`) ve kategori seçimini tek bir birleşik `GameTutorialPopup.show` menüsünde topla.
- Birleşik açılış menüsünü eski `SharedPreferences` (`*_tutorial`) kayıtlarıyla otomatik atlatma veya gizleme; her oyun açılışında doğrudan göster.

## 4. UI / UX ve Çözünürlük Standartları
- Abartılı glow/gradyan yerine `#141422` / `#1C1C2E` koyu yüzeyler ve `Offset(0, 4)`, `blurRadius: 0` alt kenarlı 3D dokunsal (tactile) kart/buton stili kullan.
- Masaüstünde (`>= 820px` / `980px`) oyun alanının tek başına ortada dar kalmasını önlemek için yan paneller veya 2 sütunlu yerleşim kullan.
- Küçük mobil ekranlarda (`320px–380px`) taşma (overflow) olmamasına ve vitrin kartlarının ekranı aşırı uzatmamasına (`max 420px`) dikkat et.
- Klavye odak (focus) halkasının açılışta kartlar üzerinde otomatik sarı çerçeve olarak görünmesini engelle; yalnızca yön tuşlarıyla etkileşim başladığında özel çerçeve göster.

