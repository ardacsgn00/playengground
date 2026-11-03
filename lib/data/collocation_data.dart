class CollocationPair {
  final String leftVerb;
  final String rightVerb;
  final String themeName;
  final int level;
  final List<CollocationItem> items;

  const CollocationPair({
    required this.leftVerb,
    required this.rightVerb,
    required this.themeName,
    required this.level,
    required this.items,
  });
}

class CollocationItem {
  final String phrase;
  final bool isLeft; // true if leftVerb, false if rightVerb
  final String turkishMeaning;

  const CollocationItem({
    required this.phrase,
    required this.isLeft,
    required this.turkishMeaning,
  });
}

class CollocationData {
  static final List<CollocationPair> pairs = [
    // Level 1: MAKE vs DO
    CollocationPair(
      leftVerb: 'MAKE',
      rightVerb: 'DO',
      themeName: 'Actions & Creations',
      level: 1,
      items: [
        // MAKE
        CollocationItem(phrase: 'a decision', isLeft: true, turkishMeaning: 'karar vermek'),
        CollocationItem(phrase: 'a mistake', isLeft: true, turkishMeaning: 'hata yapmak'),
        CollocationItem(phrase: 'money', isLeft: true, turkishMeaning: 'para kazanmak'),
        CollocationItem(phrase: 'a phone call', isLeft: true, turkishMeaning: 'telefon etmek'),
        CollocationItem(phrase: 'noise', isLeft: true, turkishMeaning: 'gürültü yapmak'),
        CollocationItem(phrase: 'progress', isLeft: true, turkishMeaning: 'ilerleme kaydetmek'),
        CollocationItem(phrase: 'an effort', isLeft: true, turkishMeaning: 'çaba sarf etmek'),
        CollocationItem(phrase: 'friends', isLeft: true, turkishMeaning: 'arkadaş edinmek'),
        CollocationItem(phrase: 'an excuse', isLeft: true, turkishMeaning: 'bahane bulmak'),
        CollocationItem(phrase: 'a suggestion', isLeft: true, turkishMeaning: 'öneride bulunmak'),
        CollocationItem(phrase: 'sense', isLeft: true, turkishMeaning: 'anlamlı gelmek'),
        CollocationItem(phrase: 'an appointment', isLeft: true, turkishMeaning: 'randevu almak'),
        CollocationItem(phrase: 'a wish', isLeft: true, turkishMeaning: 'dilek tutmak'),
        CollocationItem(phrase: 'a difference', isLeft: true, turkishMeaning: 'fark yaratmak'),
        CollocationItem(phrase: 'a point', isLeft: true, turkishMeaning: 'önemli bir noktaya değinmek'),
        CollocationItem(phrase: 'a promise', isLeft: true, turkishMeaning: 'söz vermek'),
        CollocationItem(phrase: 'a speech', isLeft: true, turkishMeaning: 'konuşma yapmak'),
        CollocationItem(phrase: 'coffee', isLeft: true, turkishMeaning: 'kahve yapmak'),
        CollocationItem(phrase: 'a plan', isLeft: true, turkishMeaning: 'plan yapmak'),
        CollocationItem(phrase: 'an impression', isLeft: true, turkishMeaning: 'izlenim bırakmak'),
        CollocationItem(phrase: 'a mess', isLeft: true, turkishMeaning: 'ortalığı dağıtmak'),
        CollocationItem(phrase: 'trouble', isLeft: true, turkishMeaning: 'sorun çıkarmak'),
        CollocationItem(phrase: 'a discovery', isLeft: true, turkishMeaning: 'keşif yapmak'),
        CollocationItem(phrase: 'a profit', isLeft: true, turkishMeaning: 'kâr etmek'),
        CollocationItem(phrase: 'a payment', isLeft: true, turkishMeaning: 'ödeme yapmak'),
        CollocationItem(phrase: 'an arrangement', isLeft: true, turkishMeaning: 'düzenleme yapmak'),
        CollocationItem(phrase: 'an announcement', isLeft: true, turkishMeaning: 'duyuru yapmak'),
        CollocationItem(phrase: 'a confession', isLeft: true, turkishMeaning: 'itirafta bulunmak'),
        CollocationItem(phrase: 'a deal', isLeft: true, turkishMeaning: 'anlaşma yapmak'),
        CollocationItem(phrase: 'an inquiry', isLeft: true, turkishMeaning: 'soruşturma yapmak'),

        // DO
        CollocationItem(phrase: 'homework', isLeft: false, turkishMeaning: 'ödev yapmak'),
        CollocationItem(phrase: 'the dishes', isLeft: false, turkishMeaning: 'bulaşıkları yıkamak'),
        CollocationItem(phrase: 'research', isLeft: false, turkishMeaning: 'araştırma yapmak'),
        CollocationItem(phrase: 'your best', isLeft: false, turkishMeaning: 'elinden geleni yapmak'),
        CollocationItem(phrase: 'business', isLeft: false, turkishMeaning: 'iş yapmak / ticaret'),
        CollocationItem(phrase: 'laundry', isLeft: false, turkishMeaning: 'çamaşır yıkamak'),
        CollocationItem(phrase: 'exercise', isLeft: false, turkishMeaning: 'egzersiz yapmak'),
        CollocationItem(phrase: 'damage', isLeft: false, turkishMeaning: 'hasar vermek'),
        CollocationItem(phrase: 'chores', isLeft: false, turkishMeaning: 'ev işlerini yapmak'),
        CollocationItem(phrase: 'harm', isLeft: false, turkishMeaning: 'zarar vermek'),
        CollocationItem(phrase: 'a favor', isLeft: false, turkishMeaning: 'iyilik yapmak'),
        CollocationItem(phrase: 'the shopping', isLeft: false, turkishMeaning: 'alışveriş yapmak'),
        CollocationItem(phrase: 'wonders', isLeft: false, turkishMeaning: 'harikalar yaratmak'),
        CollocationItem(phrase: 'crosswords', isLeft: false, turkishMeaning: 'bulmaca çözmek'),
        CollocationItem(phrase: 'nothing', isLeft: false, turkishMeaning: 'hiçbir şey yapmamak'),
        CollocationItem(phrase: 'an experiment', isLeft: false, turkishMeaning: 'deney yapmak'),
        CollocationItem(phrase: 'well / badly', isLeft: false, turkishMeaning: 'başarılı/kötü gitmek'),
        CollocationItem(phrase: 'the cooking', isLeft: false, turkishMeaning: 'yemek pişirmek'),
        CollocationItem(phrase: 'yoga', isLeft: false, turkishMeaning: 'yoga yapmak'),
        CollocationItem(phrase: 'an assignment', isLeft: false, turkishMeaning: 'ödev/görev yapmak'),
        CollocationItem(phrase: 'gymnastics', isLeft: false, turkishMeaning: 'jimnastik yapmak'),
        CollocationItem(phrase: 'an audit', isLeft: false, turkishMeaning: 'denetim yapmak'),
        CollocationItem(phrase: 'the ironing', isLeft: false, turkishMeaning: 'ütü yapmak'),
        CollocationItem(phrase: 'good', isLeft: false, turkishMeaning: 'iyilik yapmak'),
        CollocationItem(phrase: 'justice to', isLeft: false, turkishMeaning: 'hakkını vermek'),
      ],
    ),

    // Level 2: SAY vs TELL
    CollocationPair(
      leftVerb: 'SAY',
      rightVerb: 'TELL',
      themeName: 'Communication & Speech',
      level: 2,
      items: [
        // SAY
        CollocationItem(phrase: 'hello / goodbye', isLeft: true, turkishMeaning: 'merhaba / hoşça kal demek'),
        CollocationItem(phrase: 'sorry', isLeft: true, turkishMeaning: 'özür dilemek'),
        CollocationItem(phrase: 'thank you', isLeft: true, turkishMeaning: 'teşekkür etmek'),
        CollocationItem(phrase: 'please', isLeft: true, turkishMeaning: 'lütfen demek'),
        CollocationItem(phrase: 'nothing', isLeft: true, turkishMeaning: 'hiçbir şey söylememek'),
        CollocationItem(phrase: 'yes or no', isLeft: true, turkishMeaning: 'evet ya da hayır demek'),
        CollocationItem(phrase: 'a prayer', isLeft: true, turkishMeaning: 'dua etmek'),
        CollocationItem(phrase: 'cheese!', isLeft: true, turkishMeaning: 'fotoğrafta gülümsemek'),
        CollocationItem(phrase: 'so', isLeft: true, turkishMeaning: 'öyle demek'),
        CollocationItem(phrase: 'out loud', isLeft: true, turkishMeaning: 'sesli söylemek'),
        CollocationItem(phrase: 'a few words', isLeft: true, turkishMeaning: 'birkaç kelime etmek'),
        CollocationItem(phrase: 'for sure', isLeft: true, turkishMeaning: 'kesin olarak söylemek'),
        CollocationItem(phrase: 'a word', isLeft: true, turkishMeaning: 'tek bir kelime söylemek'),
        CollocationItem(phrase: 'no more', isLeft: true, turkishMeaning: 'daha fazla konuşmamak'),
        CollocationItem(phrase: 'good morning', isLeft: true, turkishMeaning: 'günaydın demek'),
        CollocationItem(phrase: 'it again', isLeft: true, turkishMeaning: 'tekrar söylemek'),
        CollocationItem(phrase: 'something nice', isLeft: true, turkishMeaning: 'güzel bir şey söylemek'),

        // TELL
        CollocationItem(phrase: 'the truth', isLeft: false, turkishMeaning: 'doğruyu söylemek'),
        CollocationItem(phrase: 'a lie', isLeft: false, turkishMeaning: 'yalan söylemek'),
        CollocationItem(phrase: 'a story', isLeft: false, turkishMeaning: 'hikaye anlatmak'),
        CollocationItem(phrase: 'the time', isLeft: false, turkishMeaning: 'saati söylemek'),
        CollocationItem(phrase: 'a secret', isLeft: false, turkishMeaning: 'sır vermek'),
        CollocationItem(phrase: 'a joke', isLeft: false, turkishMeaning: 'fıkra anlatmak'),
        CollocationItem(phrase: 'the difference', isLeft: false, turkishMeaning: 'farkı ayırt etmek'),
        CollocationItem(phrase: 'someone the way', isLeft: false, turkishMeaning: 'yol tarif etmek'),
        CollocationItem(phrase: 'fortunes', isLeft: false, turkishMeaning: 'fal bakmak'),
        CollocationItem(phrase: 'the future', isLeft: false, turkishMeaning: 'geleceği söylemek'),
        CollocationItem(phrase: 'a fib', isLeft: false, turkishMeaning: 'küçük yalan söylemek'),
        CollocationItem(phrase: 'tales', isLeft: false, turkishMeaning: 'masal anlatmak'),
        CollocationItem(phrase: 'a white lie', isLeft: false, turkishMeaning: 'zararsız yalan söylemek'),
        CollocationItem(phrase: 'right from wrong', isLeft: false, turkishMeaning: 'doğruyu yanlıştan ayırt etmek'),
        CollocationItem(phrase: 'the news', isLeft: false, turkishMeaning: 'haberi vermek'),
      ],
    ),

    // Level 3: TAKE vs HAVE
    CollocationPair(
      leftVerb: 'TAKE',
      rightVerb: 'HAVE',
      themeName: 'Daily Life & Actions',
      level: 3,
      items: [
        // TAKE
        CollocationItem(phrase: 'a shower', isLeft: true, turkishMeaning: 'duş almak'),
        CollocationItem(phrase: 'a photo', isLeft: true, turkishMeaning: 'fotoğraf çekmek'),
        CollocationItem(phrase: 'a break', isLeft: true, turkishMeaning: 'mola vermek'),
        CollocationItem(phrase: 'notes', isLeft: true, turkishMeaning: 'not almak'),
        CollocationItem(phrase: 'a seat', isLeft: true, turkishMeaning: 'oturmak / yer almak'),
        CollocationItem(phrase: 'care of', isLeft: true, turkishMeaning: 'ilgilenmek / bakmak'),
        CollocationItem(phrase: 'a chance / risk', isLeft: true, turkishMeaning: 'risk almak'),
        CollocationItem(phrase: 'an exam', isLeft: true, turkishMeaning: 'sınava girmek'),
        CollocationItem(phrase: 'medicine', isLeft: true, turkishMeaning: 'ilaç içmek'),
        CollocationItem(phrase: 'place', isLeft: true, turkishMeaning: 'meydana gelmek'),
        CollocationItem(phrase: 'part in', isLeft: true, turkishMeaning: 'katılmak / yer almak'),
        CollocationItem(phrase: 'pride in', isLeft: true, turkishMeaning: 'gurur duymak'),
        CollocationItem(phrase: 'a look', isLeft: true, turkishMeaning: 'bir göz atmak'),
        CollocationItem(phrase: 'time', isLeft: true, turkishMeaning: 'zaman almak'),
        CollocationItem(phrase: 'action', isLeft: true, turkishMeaning: 'harekete geçmek'),
        CollocationItem(phrase: 'a deep breath', isLeft: true, turkishMeaning: 'derin bir nefes almak'),
        CollocationItem(phrase: 'responsibility', isLeft: true, turkishMeaning: 'sorumluluk almak'),
        CollocationItem(phrase: 'a shortcut', isLeft: true, turkishMeaning: 'kestirmeden gitmek'),
        CollocationItem(phrase: 'advantage of', isLeft: true, turkishMeaning: 'fırsata çevirmek'),
        CollocationItem(phrase: 'turns', isLeft: true, turkishMeaning: 'sırayla yapmak'),

        // HAVE
        CollocationItem(phrase: 'fun', isLeft: false, turkishMeaning: 'eğlenmek'),
        CollocationItem(phrase: 'a dream', isLeft: false, turkishMeaning: 'rüya görmek'),
        CollocationItem(phrase: 'a party', isLeft: false, turkishMeaning: 'parti vermek'),
        CollocationItem(phrase: 'lunch / dinner', isLeft: false, turkishMeaning: 'öğle/akşam yemeği yemek'),
        CollocationItem(phrase: 'a good time', isLeft: false, turkishMeaning: 'iyi vakit geçirmek'),
        CollocationItem(phrase: 'a headache', isLeft: false, turkishMeaning: 'başı ağrımak'),
        CollocationItem(phrase: 'a problem', isLeft: false, turkishMeaning: 'sorunu olmak'),
        CollocationItem(phrase: 'a rest', isLeft: false, turkishMeaning: 'dinlenmek'),
        CollocationItem(phrase: 'patience', isLeft: false, turkishMeaning: 'sabırlı olmak'),
        CollocationItem(phrase: 'an argument', isLeft: false, turkishMeaning: 'tartışmak'),
        CollocationItem(phrase: 'doubts', isLeft: false, turkishMeaning: 'şüpheleri olmak'),
        CollocationItem(phrase: 'sympathy', isLeft: false, turkishMeaning: 'sempati duymak'),
        CollocationItem(phrase: 'a chat', isLeft: false, turkishMeaning: 'sohbet etmek'),
        CollocationItem(phrase: 'an idea', isLeft: false, turkishMeaning: 'bir fikri olmak'),
        CollocationItem(phrase: 'a conversation', isLeft: false, turkishMeaning: 'sohbet etmek'),
        CollocationItem(phrase: 'a feeling', isLeft: false, turkishMeaning: 'bir hisse kapılmak'),
        CollocationItem(phrase: 'faith', isLeft: false, turkishMeaning: 'inancı olmak'),
        CollocationItem(phrase: 'an effect on', isLeft: false, turkishMeaning: 'üzerinde etkisi olmak'),
        CollocationItem(phrase: 'an appetite', isLeft: false, turkishMeaning: 'iştahı olmak'),
        CollocationItem(phrase: 'a dispute', isLeft: false, turkishMeaning: 'anlaşmazlık yaşamak'),
      ],
    ),

    // Level 4: GIVE vs GET
    CollocationPair(
      leftVerb: 'GIVE',
      rightVerb: 'GET',
      themeName: 'Exchanges & States',
      level: 4,
      items: [
        // GIVE
        CollocationItem(phrase: 'advice', isLeft: true, turkishMeaning: 'öğüt vermek'),
        CollocationItem(phrase: 'a ride', isLeft: true, turkishMeaning: 'arabayla bırakmak'),
        CollocationItem(phrase: 'a hand', isLeft: true, turkishMeaning: 'yardım eli uzatmak'),
        CollocationItem(phrase: 'permission', isLeft: true, turkishMeaning: 'izin vermek'),
        CollocationItem(phrase: 'an opinion', isLeft: true, turkishMeaning: 'fikir belirtmek'),
        CollocationItem(phrase: 'a warning', isLeft: true, turkishMeaning: 'uyarmak'),
        CollocationItem(phrase: 'a hug', isLeft: true, turkishMeaning: 'sarılmak'),
        CollocationItem(phrase: 'credit to', isLeft: true, turkishMeaning: 'hakkını vermek'),
        CollocationItem(phrase: 'priority to', isLeft: true, turkishMeaning: 'öncelik tanımak'),
        CollocationItem(phrase: 'a presentation', isLeft: true, turkishMeaning: 'sunum yapmak'),
        CollocationItem(phrase: 'an example', isLeft: true, turkishMeaning: 'örnek vermek'),
        CollocationItem(phrase: 'a reason', isLeft: true, turkishMeaning: 'gerekçe sunmak'),
        CollocationItem(phrase: 'a chance', isLeft: true, turkishMeaning: 'şans tanımak'),
        CollocationItem(phrase: 'a discount', isLeft: true, turkishMeaning: 'indirim yapmak'),
        CollocationItem(phrase: 'a lift', isLeft: true, turkishMeaning: 'arabayla bırakmak'),
        CollocationItem(phrase: 'an explanation', isLeft: true, turkishMeaning: 'açıklama yapmak'),

        // GET
        CollocationItem(phrase: 'ready', isLeft: false, turkishMeaning: 'hazırlanmak'),
        CollocationItem(phrase: 'married', isLeft: false, turkishMeaning: 'evlenmek'),
        CollocationItem(phrase: 'lost', isLeft: false, turkishMeaning: 'kaybolmak'),
        CollocationItem(phrase: 'angry', isLeft: false, turkishMeaning: 'sinirlenmek'),
        CollocationItem(phrase: 'dark', isLeft: false, turkishMeaning: 'havanın kararması'),
        CollocationItem(phrase: 'a job', isLeft: false, turkishMeaning: 'iş bulmak'),
        CollocationItem(phrase: 'started', isLeft: false, turkishMeaning: 'başlamak'),
        CollocationItem(phrase: 'tired', isLeft: false, turkishMeaning: 'yorulmak'),
        CollocationItem(phrase: 'upset', isLeft: false, turkishMeaning: 'üzülmek'),
        CollocationItem(phrase: 'home', isLeft: false, turkishMeaning: 'eve varmak'),
        CollocationItem(phrase: 'better', isLeft: false, turkishMeaning: 'iyileşmek'),
        CollocationItem(phrase: 'dressed', isLeft: false, turkishMeaning: 'giyinmek'),
        CollocationItem(phrase: 'a promotion', isLeft: false, turkishMeaning: 'terfi almak'),
        CollocationItem(phrase: 'a refund', isLeft: false, turkishMeaning: 'para iadesi almak'),
        CollocationItem(phrase: 'confused', isLeft: false, turkishMeaning: 'kafası karışmak'),
        CollocationItem(phrase: 'in trouble', isLeft: false, turkishMeaning: 'başı derde girmek'),
        CollocationItem(phrase: 'jealous', isLeft: false, turkishMeaning: 'kıskanmak'),
      ],
    ),

    // Level 5: PAY vs KEEP
    CollocationPair(
      leftVerb: 'PAY',
      rightVerb: 'KEEP',
      themeName: 'Focus & Commitment',
      level: 5,
      items: [
        // PAY
        CollocationItem(phrase: 'attention', isLeft: true, turkishMeaning: 'dikkat etmek'),
        CollocationItem(phrase: 'a visit', isLeft: true, turkishMeaning: 'ziyaret etmek'),
        CollocationItem(phrase: 'respect', isLeft: true, turkishMeaning: 'saygı göstermek'),
        CollocationItem(phrase: 'a compliment', isLeft: true, turkishMeaning: 'iltifat etmek'),
        CollocationItem(phrase: 'in cash', isLeft: true, turkishMeaning: 'nakit ödemek'),
        CollocationItem(phrase: 'the bill', isLeft: true, turkishMeaning: 'hesabı ödemek'),
        CollocationItem(phrase: 'a fine', isLeft: true, turkishMeaning: 'ceza ödemek'),
        CollocationItem(phrase: 'tribute to', isLeft: true, turkishMeaning: 'anısına saygı durmak'),
        CollocationItem(phrase: 'a fee', isLeft: true, turkishMeaning: 'harç/ücret ödemek'),
        CollocationItem(phrase: 'interest', isLeft: true, turkishMeaning: 'faiz ödemek'),
        CollocationItem(phrase: 'rent', isLeft: true, turkishMeaning: 'kira ödemek'),
        CollocationItem(phrase: 'the penalty', isLeft: true, turkishMeaning: 'cezayı ödemek'),

        // KEEP
        CollocationItem(phrase: 'a secret', isLeft: false, turkishMeaning: 'sır tutmak'),
        CollocationItem(phrase: 'a promise', isLeft: false, turkishMeaning: 'sözünü tutmak'),
        CollocationItem(phrase: 'calm', isLeft: false, turkishMeaning: 'sakin kalmak'),
        CollocationItem(phrase: 'in touch', isLeft: false, turkishMeaning: 'iletişimde kalmak'),
        CollocationItem(phrase: 'quiet', isLeft: false, turkishMeaning: 'sessiz kalmak'),
        CollocationItem(phrase: 'a diary', isLeft: false, turkishMeaning: 'günlük tutmak'),
        CollocationItem(phrase: 'control', isLeft: false, turkishMeaning: 'kontrolü elinde tutmak'),
        CollocationItem(phrase: 'an eye on', isLeft: false, turkishMeaning: 'göz kulak olmak'),
        CollocationItem(phrase: 'fit', isLeft: false, turkishMeaning: 'zinde kalmak'),
        CollocationItem(phrase: 'a record', isLeft: false, turkishMeaning: 'kayıt tutmak'),
        CollocationItem(phrase: 'the change', isLeft: false, turkishMeaning: 'para üstünü tutmak'),
        CollocationItem(phrase: 'track of', isLeft: false, turkishMeaning: 'takibini yapmak'),
        CollocationItem(phrase: 'in mind', isLeft: false, turkishMeaning: 'akılda tutmak'),
        CollocationItem(phrase: 'a distance', isLeft: false, turkishMeaning: 'mesafeyi korumak'),
      ],
    ),

    // Level 6: CATCH vs MISS
    CollocationPair(
      leftVerb: 'CATCH',
      rightVerb: 'MISS',
      themeName: 'Opportunities & Timing',
      level: 6,
      items: [
        // CATCH
        CollocationItem(phrase: 'a cold', isLeft: true, turkishMeaning: 'soğuk algınlığı kapmak'),
        CollocationItem(phrase: 'the bus / train', isLeft: true, turkishMeaning: 'otobüse/trene yetişmek'),
        CollocationItem(phrase: 'fire', isLeft: true, turkishMeaning: 'alev almak, tutuşmak'),
        CollocationItem(phrase: "someone's eye", isLeft: true, turkishMeaning: 'dikkatini çekmek'),
        CollocationItem(phrase: 'a ball', isLeft: true, turkishMeaning: 'topu yakalamak'),
        CollocationItem(phrase: 'your breath', isLeft: true, turkishMeaning: 'soluklanmak'),
        CollocationItem(phrase: 'a thief', isLeft: true, turkishMeaning: 'hırsız yakalamak'),
        CollocationItem(phrase: 'a glimpse of', isLeft: true, turkishMeaning: 'şöyle bir gözüne çarpmak'),
        CollocationItem(phrase: 'the flu', isLeft: true, turkishMeaning: 'gribe yakalanmak'),
        CollocationItem(phrase: 'someone red-handed', isLeft: true, turkishMeaning: 'suçüstü yakalamak'),
        CollocationItem(phrase: 'a fish', isLeft: true, turkishMeaning: 'balık tutmak'),
        CollocationItem(phrase: 'an infection', isLeft: true, turkishMeaning: 'enfeksiyon kapmak'),

        // MISS
        CollocationItem(phrase: 'the flight', isLeft: false, turkishMeaning: 'uçağı kaçırmak'),
        CollocationItem(phrase: 'an opportunity', isLeft: false, turkishMeaning: 'fırsatı kaçırmak'),
        CollocationItem(phrase: 'a friend', isLeft: false, turkishMeaning: 'bir arkadaşı özlemek'),
        CollocationItem(phrase: 'the point', isLeft: false, turkishMeaning: 'esas noktayı kaçırmak'),
        CollocationItem(phrase: 'a lesson / class', isLeft: false, turkishMeaning: 'dersi kaçırmak'),
        CollocationItem(phrase: 'the target', isLeft: false, turkishMeaning: 'hedefi ıskalamak'),
        CollocationItem(phrase: 'a deadline', isLeft: false, turkishMeaning: 'teslim süresini kaçırmak'),
        CollocationItem(phrase: 'a chance', isLeft: false, turkishMeaning: 'şansı kaçırmak'),
        CollocationItem(phrase: 'a turn', isLeft: false, turkishMeaning: 'dönüşü kaçırmak'),
        CollocationItem(phrase: 'an appointment', isLeft: false, turkishMeaning: 'randevuyu kaçırmak'),
        CollocationItem(phrase: 'out on', isLeft: false, turkishMeaning: 'fırsatı kaçırmak'),
      ],
    ),

    // Level 7: COME vs GO
    CollocationPair(
      leftVerb: 'COME',
      rightVerb: 'GO',
      themeName: 'Movement & Change',
      level: 7,
      items: [
        // COME
        CollocationItem(phrase: 'true', isLeft: true, turkishMeaning: 'gerçek olmak (rüya vb.)'),
        CollocationItem(phrase: 'first / last', isLeft: true, turkishMeaning: 'birinci / sonuncu olmak'),
        CollocationItem(phrase: 'close', isLeft: true, turkishMeaning: 'yaklaşmak'),
        CollocationItem(phrase: 'prepared', isLeft: true, turkishMeaning: 'hazırlıklı gelmek'),
        CollocationItem(phrase: 'to an end', isLeft: true, turkishMeaning: 'sona ermek'),
        CollocationItem(phrase: 'early', isLeft: true, turkishMeaning: 'erken gelmek'),
        CollocationItem(phrase: 'to a decision', isLeft: true, turkishMeaning: 'karara varmak'),
        CollocationItem(phrase: 'to light', isLeft: true, turkishMeaning: 'gün yüzüne çıkmak'),
        CollocationItem(phrase: 'into effect', isLeft: true, turkishMeaning: 'yürürlüğe girmek'),
        CollocationItem(phrase: 'to a conclusion', isLeft: true, turkishMeaning: 'sonuca varmak'),
        CollocationItem(phrase: 'clean', isLeft: true, turkishMeaning: 'itiraf etmek'),

        // GO
        CollocationItem(phrase: 'bankrupt', isLeft: false, turkishMeaning: 'iflas etmek'),
        CollocationItem(phrase: 'crazy / mad', isLeft: false, turkishMeaning: 'çıldırmak'),
        CollocationItem(phrase: 'abroad', isLeft: false, turkishMeaning: 'yurt dışına gitmek'),
        CollocationItem(phrase: 'missing', isLeft: false, turkishMeaning: 'kaybolmak'),
        CollocationItem(phrase: 'online', isLeft: false, turkishMeaning: 'çevrim içi olmak'),
        CollocationItem(phrase: 'smoothly', isLeft: false, turkishMeaning: 'sorunsuz ilerlemek'),
        CollocationItem(phrase: 'blind / deaf', isLeft: false, turkishMeaning: 'kör/sağır olmak'),
        CollocationItem(phrase: 'bald', isLeft: false, turkishMeaning: 'kelleşmek'),
        CollocationItem(phrase: 'bad / sour', isLeft: false, turkishMeaning: 'bozulmak (yiyecek)'),
        CollocationItem(phrase: 'silent', isLeft: false, turkishMeaning: 'sessizliğe bürünmek'),
        CollocationItem(phrase: 'viral', isLeft: false, turkishMeaning: 'internette yayılmak'),
        CollocationItem(phrase: 'broke', isLeft: false, turkishMeaning: 'parasız kalmak'),
      ],
    ),

    // Level 8: LOSE vs WIN
    CollocationPair(
      leftVerb: 'LOSE',
      rightVerb: 'WIN',
      themeName: 'Victory & Defeat',
      level: 8,
      items: [
        // LOSE
        CollocationItem(phrase: 'weight', isLeft: true, turkishMeaning: 'kilo vermek'),
        CollocationItem(phrase: 'your temper', isLeft: true, turkishMeaning: 'öfkesine yenik düşmek'),
        CollocationItem(phrase: 'interest', isLeft: true, turkishMeaning: 'ilgisini kaybetmek'),
        CollocationItem(phrase: 'your way', isLeft: true, turkishMeaning: 'yolunu kaybetmek'),
        CollocationItem(phrase: 'control', isLeft: true, turkishMeaning: 'kontrolü kaybetmek'),
        CollocationItem(phrase: 'a match', isLeft: true, turkishMeaning: 'maçı kaybetmek'),
        CollocationItem(phrase: 'patience', isLeft: true, turkishMeaning: 'sabrı taşmak'),
        CollocationItem(phrase: 'hope', isLeft: true, turkishMeaning: 'umudunu kaybetmek'),
        CollocationItem(phrase: 'confidence', isLeft: true, turkishMeaning: 'özgüvenini kaybetmek'),
        CollocationItem(phrase: 'track of time', isLeft: true, turkishMeaning: 'zamanı unutmak'),
        CollocationItem(phrase: 'face', isLeft: true, turkishMeaning: 'itibarını kaybetmek'),

        // WIN
        CollocationItem(phrase: 'an award', isLeft: false, turkishMeaning: 'ödül kazanmak'),
        CollocationItem(phrase: 'a prize', isLeft: false, turkishMeaning: 'ikramiye/ödül kazanmak'),
        CollocationItem(phrase: 'a competition', isLeft: false, turkishMeaning: 'yarışma kazanmak'),
        CollocationItem(phrase: 'the lottery', isLeft: false, turkishMeaning: 'piyango kazanmak'),
        CollocationItem(phrase: "someone's trust", isLeft: false, turkishMeaning: 'birinin güvenini kazanmak'),
        CollocationItem(phrase: 'a scholarship', isLeft: false, turkishMeaning: 'burs kazanmak'),
        CollocationItem(phrase: 'a medal', isLeft: false, turkishMeaning: 'madalya kazanmak'),
        CollocationItem(phrase: 'a trophy', isLeft: false, turkishMeaning: 'kupa kazanmak'),
        CollocationItem(phrase: 'a championship', isLeft: false, turkishMeaning: 'şampiyonluk kazanmak'),
        CollocationItem(phrase: 'an election', isLeft: false, turkishMeaning: 'seçimi kazanmak'),
        CollocationItem(phrase: 'support', isLeft: false, turkishMeaning: 'destek kazanmak'),
      ],
    ),

    // Level 9: SAVE vs SPEND
    CollocationPair(
      leftVerb: 'SAVE',
      rightVerb: 'SPEND',
      themeName: 'Time & Resources',
      level: 9,
      items: [
        // SAVE
        CollocationItem(phrase: 'money', isLeft: true, turkishMeaning: 'para biriktirmek'),
        CollocationItem(phrase: 'time', isLeft: true, turkishMeaning: 'zaman kazanmak'),
        CollocationItem(phrase: 'lives', isLeft: true, turkishMeaning: 'hayat kurtarmak'),
        CollocationItem(phrase: 'energy', isLeft: true, turkishMeaning: 'enerji tasarrufu yapmak'),
        CollocationItem(phrase: 'space', isLeft: true, turkishMeaning: 'yerden tasarruf etmek'),
        CollocationItem(phrase: "someone's seat", isLeft: true, turkishMeaning: 'birine yer tutmak'),
        CollocationItem(phrase: 'water', isLeft: true, turkishMeaning: 'su tasarrufu yapmak'),
        CollocationItem(phrase: 'electricity', isLeft: true, turkishMeaning: 'elektrik tasarrufu yapmak'),
        CollocationItem(phrase: 'face', isLeft: true, turkishMeaning: 'itibarını kurtarmak'),

        // SPEND
        CollocationItem(phrase: 'a fortune', isLeft: false, turkishMeaning: 'servet harcamak'),
        CollocationItem(phrase: 'hours', isLeft: false, turkishMeaning: 'saatler harcamak'),
        CollocationItem(phrase: 'a holiday', isLeft: false, turkishMeaning: 'tatil geçirmek'),
        CollocationItem(phrase: 'money on clothes', isLeft: false, turkishMeaning: 'kıyafete para harcamak'),
        CollocationItem(phrase: 'time with family', isLeft: false, turkishMeaning: 'aileyle vakit geçirmek'),
        CollocationItem(phrase: 'the night', isLeft: false, turkishMeaning: 'geceyi geçirmek'),
        CollocationItem(phrase: 'the weekend', isLeft: false, turkishMeaning: 'hafta sonunu geçirmek'),
        CollocationItem(phrase: 'valuable time', isLeft: false, turkishMeaning: 'değerli zaman harcamak'),
      ],
    ),

    // Level 10: BREAK vs SET
    CollocationPair(
      leftVerb: 'BREAK',
      rightVerb: 'SET',
      themeName: 'Rules & Records',
      level: 10,
      items: [
        // BREAK
        CollocationItem(phrase: 'a rule', isLeft: true, turkishMeaning: 'kuralı çiğnemek'),
        CollocationItem(phrase: 'a promise', isLeft: true, turkishMeaning: 'sözünü tutmamak'),
        CollocationItem(phrase: 'a record', isLeft: true, turkishMeaning: 'rekor kırmak'),
        CollocationItem(phrase: 'the law', isLeft: true, turkishMeaning: 'kanunu çiğnemek'),
        CollocationItem(phrase: 'the ice', isLeft: true, turkishMeaning: 'sohbeti başlatmak (buzları eritmek)'),
        CollocationItem(phrase: "someone's heart", isLeft: true, turkishMeaning: 'kalp kırmak'),
        CollocationItem(phrase: 'a habit', isLeft: true, turkishMeaning: 'kötü alışkanlığı bırakmak'),
        CollocationItem(phrase: 'the silence', isLeft: true, turkishMeaning: 'sessizliği bozmak'),
        CollocationItem(phrase: 'a code', isLeft: true, turkishMeaning: 'şifre kırmak'),
        CollocationItem(phrase: 'free', isLeft: true, turkishMeaning: 'özgürlüğe kavuşmak'),

        // SET
        CollocationItem(phrase: 'an alarm', isLeft: false, turkishMeaning: 'alarm kurmak'),
        CollocationItem(phrase: 'a goal', isLeft: false, turkishMeaning: 'hedef belirlemek'),
        CollocationItem(phrase: 'the table', isLeft: false, turkishMeaning: 'masayı kurmak'),
        CollocationItem(phrase: 'a record', isLeft: false, turkishMeaning: 'yeni rekor belirlemek'),
        CollocationItem(phrase: 'a good example', isLeft: false, turkishMeaning: 'iyi örnek oluşturmak'),
        CollocationItem(phrase: 'a fire', isLeft: false, turkishMeaning: 'ateş yakmak'),
        CollocationItem(phrase: 'a date', isLeft: false, turkishMeaning: 'tarih belirlemek'),
        CollocationItem(phrase: 'a standard', isLeft: false, turkishMeaning: 'standart belirlemek'),
        CollocationItem(phrase: 'the pace', isLeft: false, turkishMeaning: 'tempoyu belirlemek'),
        CollocationItem(phrase: 'a precedent', isLeft: false, turkishMeaning: 'emsal oluşturmak'),
      ],
    ),
  ];
}
