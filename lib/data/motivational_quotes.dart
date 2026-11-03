import 'dart:math';

/// PlayEngGround Hata Bankası ve Ana Ekran için özenle seçilmiş
/// motive edici, pedagojik ve cesaretlendirici sözler.
class MotivationalQuotes {
  static final Random _random = Random();

  static const List<String> quotes = [
    "Hatalar, öğrenmenin en güçlü basamaklarıdır. 💪",
    "Her yanlış, doğruya giden yolda yeni bir adımdır. 🌟",
    "Mistakes are proof that you are trying! 🔥",
    "Pes etmeyen asla kaybetmez, devam et! 🚀",
    "Hatalarını tekrar etmek yerine onları avantaja çevir! 🎯",
    "Bugün yaptığın hata, yarınki başarının temeli olacak. ✨",
    "Büyük başarılar, aşılan hataların üzerine kurulur. 🏆",
    "Pratik yaptıkça kelimeler hafızana kazınır. 🧠",
    "Her yeni hata, yeni bir şey öğrenme fırsatıdır! 📖",
    "Küçük adımlar, büyük zaferler doğurur. Yola devam! ⚡",
    "Hatalarından ders çıkar ve yoluna devam et! 💡",
    "Practice makes progress, not perfection! 🌈",
    "Kendine güven; her gün bir adım daha ileri! 🏅",
    "Zorluklar, seni daha güçlü bir öğrenici yapar. 🛡️",
    "Bir dili öğrenmek cesaret ister, sen başarıyorsun! 🌍",
    "Yanlış yaptığın her kelime, doğrusunu öğrenme fırsatıdır. 🔑",
    "Consistency is the key to mastery! ⏳",
    "Günde birkaç dakika pratik, dev bir fark yaratır. 📈",
    "Hata yapmaktan değil, denemekten vazgeçmekten kork! 🦁",
    "Her gün yeni bir kelime, her gün yeni bir dünya. 🗺️",
    "Başarısızlık yok, sadece geri bildirim var! 🔄",
    "Keep going! Every mistake is a lesson learned. 🎓",
    "Dün zor gelen kelimeler, yarın refleksin olacak. 🌱",
    "Zihnini esnek tut, öğrenme heyecanını asla kaybetme! 💥",
    "Kelime dağarcığın pratik yaptıkça güçlenir. 🌺",
    "Hataların düşmanın değil, en dürüst rehberindir. 📚",
    "Believe in yourself and keep practicing! ⭐",
    "Azim, yeteneğin gidemediği yere götürür. 🏁",
    "Her gün atılan küçük bir adım, seni zirveye taşır! 🏔️",
    "İngilizce, dünyaya açılan bir kapıdır; cesur ol! 🌉",
    "Unutma: en iyi konuşanlar da en çok hata yapanlardı! 🎤",
    "Never give up, great things take time! 💎",
  ];

  /// Rastgele motive edici bir söz döner.
  static String getRandomQuote({String? exclude}) {
    if (quotes.length <= 1) return quotes.first;
    String next;
    do {
      next = quotes[_random.nextInt(quotes.length)];
    } while (next == exclude);
    return next;
  }
}
