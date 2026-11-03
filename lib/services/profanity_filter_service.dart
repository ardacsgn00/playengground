class ProfanityFilterService {
  static const Set<String> _profanityList = {
    'badword', 'offensiveword', 'fuck', 'shit', 'ass', 'bitch', 'cunt', 'dick', 'pussy'
  };

  static bool containsProfanity(String word) {
    return _profanityList.contains(word.toLowerCase().trim());
  }
}
