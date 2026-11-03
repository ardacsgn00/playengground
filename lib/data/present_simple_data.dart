// =============================================================================
// PRESENT SIMPLE – CURRICULUM DATABASE (ENGLISH IMMERSION)
// -----------------------------------------------------------------------------
// Everything in this file is formatted in instructional English.
//  • psScrambleItems  → Sentence Scramble (with trap words & grammar hints)
//  • psQuizItems      → Grammar Penalty (gap-fill questions)
//  • psWheelItems     → Sentence Spin (classroom challenges)
//  • psSampleDialogue → Dialogue Listening (audio + questions)
// =============================================================================

/// Present Simple subtopics.
enum PSTopic { affirmative, negative, question, frequency, routine }

extension PSTopicX on PSTopic {
  String get label {
    switch (this) {
      case PSTopic.affirmative:
        return 'Affirmative (+s / -es / -ies)';
      case PSTopic.negative:
        return "Negative (don't / doesn't)";
      case PSTopic.question:
        return 'Questions & Short Answers';
      case PSTopic.frequency:
        return 'Adverbs of Frequency';
      case PSTopic.routine:
        return 'Routines & Time Expressions';
    }
  }

  String get shortLabel {
    switch (this) {
      case PSTopic.affirmative:
        return 'AFFIRMATIVE';
      case PSTopic.negative:
        return 'NEGATIVE';
      case PSTopic.question:
        return 'QUESTIONS';
      case PSTopic.frequency:
        return 'FREQUENCY';
      case PSTopic.routine:
        return 'ROUTINES';
    }
  }

  /// General word order guidance.
  String get orderHint {
    switch (this) {
      case PSTopic.question:
        return '(Question word) + Do/Does + subject + base verb + ...?';
      case PSTopic.frequency:
        return 'Adverbs of frequency come BEFORE main verbs, but AFTER am/is/are.';
      case PSTopic.negative:
        return "Subject + don't/doesn't + base verb + object + place/time";
      case PSTopic.affirmative:
      case PSTopic.routine:
        return 'Subject + verb + object + place/time';
    }
  }
}

/// Proper nouns that must maintain capitalization.
const Set<String> psProperNouns = {
  'I', 'Ali', 'Ayşe', 'Elif', 'Mehmet', 'Emre', 'Kemal', 'Zeynep', 'Burak',
  'Selin', 'Mert', 'Tom', 'Can', 'Alex', 'Sarah', 'Emma', 'Liam', 'Istanbul', 'Izmir', 'Ankara',
};

// =============================================================================
// SENTENCE SCRAMBLE (ENGLISH)
// =============================================================================

class PSScrambleItem {
  final String sentence;
  final String trap;
  final String hint;
  final PSTopic topic;
  final String? movable;
  final List<String> alts;

  const PSScrambleItem(
    this.sentence, {
    required this.trap,
    required this.hint,
    required this.topic,
    this.movable,
    this.alts = const [],
  });

  List<String> buildTiles({required bool withTrap}) {
    final words = sentence.trim().split(RegExp(r'\s+'));
    words[words.length - 1] = words.last.replaceAll(RegExp(r'[.?!]+$'), '');
    if (!psProperNouns.contains(words.first)) {
      words[0] = words.first.toLowerCase();
    }
    if (withTrap) words.add(trap);
    return words;
  }

  List<String> get acceptedAnswers {
    final list = <String>[sentence, ...alts];
    final m = movable;
    if (m != null) {
      final core = sentence.trim().replaceAll(RegExp(r'[.?!]+$'), '');
      if (core.toLowerCase().endsWith(m.toLowerCase())) {
        final front = core.substring(0, core.length - m.length).trim();
        list.add('$m $front');
      }
    }
    return list;
  }
}

const List<PSScrambleItem> psScrambleItems = [
  // --- AFFIRMATIVE ---
  PSScrambleItem('She watches a documentary every evening.',
      trap: 'watchs', topic: PSTopic.affirmative, movable: 'every evening',
      hint: 'Verbs ending in -ch add -es with he/she/it: watch → watches'),
  PSScrambleItem('My father fixes old cars in his free time.',
      trap: 'fixs', topic: PSTopic.affirmative, movable: 'in his free time',
      hint: 'Verbs ending in -x add -es: fix → fixes'),
  PSScrambleItem('The baby cries a lot at night.',
      trap: 'crys', topic: PSTopic.affirmative, movable: 'at night',
      hint: 'Consonant + y changes to -ies: cry → cries'),
  PSScrambleItem('Our teacher always carries a big bag.',
      trap: 'carrys', topic: PSTopic.affirmative,
      hint: 'Consonant + y changes to -ies: carry → carries'),
  PSScrambleItem('He plays basketball with his friends on Saturdays.',
      trap: 'plaies', topic: PSTopic.affirmative, movable: 'on Saturdays',
      hint: 'Vowel + y simply adds -s: play → plays'),
  PSScrambleItem('Mehmet goes to the gym three times a week.',
      trap: 'gos', topic: PSTopic.affirmative, movable: 'three times a week',
      hint: 'Verbs ending in -o add -es: go → goes'),
  PSScrambleItem("The shop opens at nine o'clock.",
      trap: 'open', topic: PSTopic.affirmative, movable: "at nine o'clock",
      hint: 'Singular third-person subject (the shop = it) takes -s: opens'),
  PSScrambleItem('My cousin studies medicine in Istanbul.',
      trap: 'studys', topic: PSTopic.affirmative,
      hint: 'Consonant + y changes to -ies: study → studies'),
  PSScrambleItem('Water boils at 100 degrees.',
      trap: 'boil', topic: PSTopic.affirmative,
      hint: 'General facts use Present Simple; water (it) → boils'),
  PSScrambleItem('She teaches English at a high school.',
      trap: 'teachs', topic: PSTopic.affirmative,
      hint: 'Verbs ending in -ch add -es: teach → teaches'),
  PSScrambleItem('My brother has breakfast at seven.',
      trap: 'haves', topic: PSTopic.affirmative, movable: 'at seven',
      hint: 'Have becomes has with he/she/it'),
  PSScrambleItem('Elif washes the dishes after lunch.',
      trap: 'washs', topic: PSTopic.affirmative, movable: 'after lunch',
      hint: 'Verbs ending in -sh add -es: wash → washes'),
  PSScrambleItem('The train leaves at half past eight.',
      trap: 'leave', topic: PSTopic.affirmative, movable: 'at half past eight',
      hint: 'Timetables use Present Simple; the train (it) → leaves'),
  PSScrambleItem('I live in a small flat near the city centre.',
      trap: 'lives', topic: PSTopic.affirmative,
      hint: 'I / you / we / they take the base verb: live'),
  PSScrambleItem('They work in the same office.',
      trap: 'works', topic: PSTopic.affirmative,
      hint: 'They takes the base verb: work'),

  // --- NEGATIVE ---
  PSScrambleItem("She doesn't drink coffee in the morning.",
      trap: "don't", topic: PSTopic.negative, movable: 'in the morning',
      hint: "Use doesn't with he/she/it"),
  PSScrambleItem("My parents don't watch TV on weekdays.",
      trap: "doesn't", topic: PSTopic.negative, movable: 'on weekdays',
      hint: "Plural subject (my parents = they) takes don't"),
  PSScrambleItem("He doesn't like horror films.",
      trap: 'likes', topic: PSTopic.negative,
      hint: "Always use the base verb after doesn't: like"),
  PSScrambleItem("We don't have classes on Fridays.",
      trap: "doesn't", topic: PSTopic.negative, movable: 'on Fridays',
      hint: "We takes don't"),
  PSScrambleItem("Ayşe doesn't eat meat.",
      trap: 'eats', topic: PSTopic.negative,
      hint: "doesn't + base verb: eat"),
  PSScrambleItem("I don't understand this question.",
      trap: "doesn't", topic: PSTopic.negative,
      hint: "I takes don't"),
  PSScrambleItem("The bus doesn't stop here at night.",
      trap: "don't", topic: PSTopic.negative, movable: 'at night',
      hint: "Singular subject (the bus = it) takes doesn't"),
  PSScrambleItem("My grandmother doesn't use social media.",
      trap: 'uses', topic: PSTopic.negative,
      hint: "doesn't + base verb: use"),
  PSScrambleItem("You don't need a ticket for the museum.",
      trap: "doesn't", topic: PSTopic.negative,
      hint: "You takes don't"),
  PSScrambleItem("It doesn't snow much in Izmir.",
      trap: 'snows', topic: PSTopic.negative,
      hint: "doesn't + base verb: snow"),
  PSScrambleItem("Cats don't like water.",
      trap: "doesn't", topic: PSTopic.negative,
      hint: "Plural subject (cats) takes don't"),
  PSScrambleItem("My best friend doesn't live near me.",
      trap: 'lives', topic: PSTopic.negative,
      hint: "doesn't + base verb: live"),

  // --- QUESTIONS ---
  PSScrambleItem('Does your brother play the guitar?',
      trap: 'plays', topic: PSTopic.question,
      hint: 'In questions with Does, use the base verb: play'),
  PSScrambleItem('Do you walk to school every day?',
      trap: 'does', topic: PSTopic.question,
      hint: 'You takes Do in questions'),
  PSScrambleItem('Where does your father work?',
      trap: 'works', topic: PSTopic.question,
      hint: 'Question word + does + subject + base verb: work'),
  PSScrambleItem('What time do you get up on Sundays?',
      trap: 'does', topic: PSTopic.question,
      hint: 'You takes do'),
  PSScrambleItem('How often does she go swimming?',
      trap: 'goes', topic: PSTopic.question,
      hint: 'does + base verb: go'),
  PSScrambleItem('Do your friends speak English?',
      trap: 'does', topic: PSTopic.question,
      hint: 'Plural subject (your friends) takes Do'),
  PSScrambleItem('Why does he always come late?',
      trap: 'comes', topic: PSTopic.question,
      hint: 'does + base verb: come'),
  PSScrambleItem('What does this word mean?',
      trap: 'means', topic: PSTopic.question,
      hint: 'does + base verb: mean'),
  PSScrambleItem('Does the library open on Sundays?',
      trap: 'do', topic: PSTopic.question,
      hint: 'The library (it) takes Does'),
  PSScrambleItem('When do they finish school?',
      trap: 'does', topic: PSTopic.question,
      hint: 'They takes do'),
  PSScrambleItem('Which bus do you take to work?',
      trap: 'does', topic: PSTopic.question,
      hint: 'You takes do'),

  // --- ADVERBS OF FREQUENCY ---
  PSScrambleItem('I always brush my teeth before bed.',
      trap: 'am', topic: PSTopic.frequency,
      hint: 'Do not use am/is/are before an active main verb: I always brush'),
  PSScrambleItem('She is never late for school.',
      trap: 'does', topic: PSTopic.frequency,
      hint: 'Place the adverb AFTER the verb to be: is never'),
  PSScrambleItem('We usually have lunch at the canteen.',
      trap: 'has', topic: PSTopic.frequency,
      hint: 'We takes have; place usually BEFORE the main verb: usually have'),
  PSScrambleItem('My dad often reads the newspaper at breakfast.',
      trap: 'read', topic: PSTopic.frequency, movable: 'at breakfast',
      hint: 'My dad (he) takes reads; place often BEFORE the verb'),
  PSScrambleItem('They are always busy on Mondays.',
      trap: 'is', topic: PSTopic.frequency, movable: 'on Mondays',
      hint: 'They takes are; always comes AFTER are: are always'),
  PSScrambleItem('He sometimes plays computer games.',
      trap: 'play', topic: PSTopic.frequency,
      alts: ['Sometimes he plays computer games', 'He plays computer games sometimes'],
      hint: 'He takes plays; sometimes normally precedes the verb'),
  PSScrambleItem('I rarely eat fast food.',
      trap: 'eats', topic: PSTopic.frequency,
      hint: 'I takes the base verb eat; rarely comes before it'),
  PSScrambleItem('Ali hardly ever misses a class.',
      trap: 'miss', topic: PSTopic.frequency,
      hint: 'Verbs ending in -ss add -es: miss → misses'),
  PSScrambleItem('My sister is usually tired after work.',
      trap: 'are', topic: PSTopic.frequency, movable: 'after work',
      hint: 'My sister (she) takes is; usually comes after is: is usually'),
  PSScrambleItem('Do you often go to the cinema?',
      trap: 'does', topic: PSTopic.frequency,
      hint: 'In questions, the adverb comes after the subject: Do you often go...?'),
  PSScrambleItem('Our cat never sleeps in its bed.',
      trap: 'sleep', topic: PSTopic.frequency,
      hint: 'Our cat (it) takes sleeps; never comes before the verb'),
  PSScrambleItem('The students are often noisy before the lesson.',
      trap: 'is', topic: PSTopic.frequency, movable: 'before the lesson',
      hint: 'The students (they) takes are; often comes after are'),

  // --- ROUTINES & TIME EXPRESSIONS ---
  PSScrambleItem('I wake up at half past six every morning.',
      trap: 'wakes', topic: PSTopic.routine, movable: 'every morning',
      hint: 'I takes the base verb: wake up'),
  PSScrambleItem('She takes a shower before breakfast.',
      trap: 'take', topic: PSTopic.routine, movable: 'before breakfast',
      hint: 'She takes the -s form: takes'),
  PSScrambleItem('My brother gets dressed in five minutes.',
      trap: 'get', topic: PSTopic.routine,
      hint: 'My brother (he) takes gets'),
  PSScrambleItem('We visit our grandparents once a month.',
      trap: 'visits', topic: PSTopic.routine, movable: 'once a month',
      hint: 'We takes the base verb: visit'),
  PSScrambleItem('He catches the bus at quarter to eight.',
      trap: 'catchs', topic: PSTopic.routine, movable: 'at quarter to eight',
      hint: 'Verbs ending in -ch add -es: catch → catches'),
  PSScrambleItem('They go to bed late at the weekend.',
      trap: 'goes', topic: PSTopic.routine, movable: 'at the weekend',
      hint: 'They takes go'),
  PSScrambleItem('My mother cooks dinner every evening.',
      trap: 'cook', topic: PSTopic.routine, movable: 'every evening',
      hint: 'My mother (she) takes cooks'),
  PSScrambleItem('I do my homework in the afternoon.',
      trap: 'does', topic: PSTopic.routine, movable: 'in the afternoon',
      hint: 'I takes do'),
  PSScrambleItem('Burak walks the dog twice a day.',
      trap: 'walk', topic: PSTopic.routine, movable: 'twice a day',
      hint: 'Burak (he) takes walks'),
  PSScrambleItem('We have English lessons on Tuesdays and Thursdays.',
      trap: 'has', topic: PSTopic.routine, movable: 'on Tuesdays and Thursdays',
      hint: 'We takes have'),
  PSScrambleItem('She tidies her room every weekend.',
      trap: 'tidys', topic: PSTopic.routine, movable: 'every weekend',
      hint: 'Consonant + y changes to -ies: tidy → tidies'),
  PSScrambleItem('My father leaves home early in the morning.',
      trap: 'leave', topic: PSTopic.routine, movable: 'early in the morning',
      hint: 'My father (he) takes leaves'),
  PSScrambleItem('The train arrives at the station on time.',
      trap: 'arrive', topic: PSTopic.affirmative, movable: 'on time',
      hint: 'Singular subject (it) takes -s: arrives'),
  PSScrambleItem('My sister washes her hair with organic shampoo.',
      trap: 'washs', topic: PSTopic.affirmative,
      hint: 'Verbs ending in -sh take -es: wash → washes'),
  PSScrambleItem('They do not like sugary drinks.',
      trap: 'likes', topic: PSTopic.negative,
      hint: 'Base form of the verb follows do not: like'),
  PSScrambleItem('He does not understand this complex rule.',
      trap: 'understands', topic: PSTopic.negative,
      hint: 'Base form follows does not: understand'),
  PSScrambleItem('Do you know the answer to this question?',
      trap: 'knows', topic: PSTopic.question,
      hint: 'Auxiliary do is used with you'),
  PSScrambleItem('Does your brother speak French fluently?',
      trap: 'speaks', topic: PSTopic.question,
      hint: 'Base form speak follows does'),
  PSScrambleItem('She seldom complains about her difficult job.',
      trap: 'complain', topic: PSTopic.frequency,
      hint: 'Third-person singular takes -s: complains'),
  PSScrambleItem('We rarely eat fast food on weekdays.',
      trap: 'eats', topic: PSTopic.frequency, movable: 'on weekdays',
      hint: 'We takes base verb eat'),
  PSScrambleItem('The gardener waters the flowers twice a week.',
      trap: 'water', topic: PSTopic.routine, movable: 'twice a week',
      hint: 'The gardener (he/she) takes waters'),
  PSScrambleItem('I brush my teeth before going to sleep.',
      trap: 'brushes', topic: PSTopic.routine, movable: 'before going to sleep',
      hint: 'First-person I takes base form brush'),
];

// =============================================================================
// GRAMMAR PENALTY (GAP-FILL QUESTIONS)
// =============================================================================

class PSQuizItem {
  final String question;
  final String answer;
  final List<String> wrong;
  final String hint;
  final PSTopic topic;

  const PSQuizItem(
    this.question,
    this.answer,
    this.wrong, {
    required this.hint,
    required this.topic,
  });

  String get filled => question.replaceFirst('___', answer);
}

const List<PSQuizItem> psQuizItems = [
  // --- AFFIRMATIVE ---
  PSQuizItem('My brother ___ TV every evening.', 'watches',
      ['watch', 'watchs', 'watching'], topic: PSTopic.affirmative,
      hint: 'Verbs ending in -ch add -es: watches'),
  PSQuizItem('She ___ to work by bus.', 'goes',
      ['go', 'gos', 'going'], topic: PSTopic.affirmative,
      hint: 'Verbs ending in -o add -es: goes'),
  PSQuizItem('The baby ___ a lot at night.', 'cries',
      ['cry', 'crys', 'cryes'], topic: PSTopic.affirmative,
      hint: 'Consonant + y changes to -ies: cries'),
  PSQuizItem('He ___ football on Saturdays.', 'plays',
      ['play', 'plaies', 'playes'], topic: PSTopic.affirmative,
      hint: 'Vowel + y simply adds -s: plays'),
  PSQuizItem('My mother ___ three languages.', 'speaks',
      ['speak', 'speakes', 'speaking'], topic: PSTopic.affirmative,
      hint: 'My mother (she) takes speaks'),
  PSQuizItem('Water ___ at 0 °C.', 'freezes',
      ['freeze', 'freezs', 'freezing'], topic: PSTopic.affirmative,
      hint: 'General scientific fact; water (it) takes freezes'),
  PSQuizItem('Our teacher ___ a lot of homework.', 'gives',
      ['give', 'giveing', 'is give'], topic: PSTopic.affirmative,
      hint: 'Our teacher (he/she) takes gives'),
  PSQuizItem('My cousin ___ at university.', 'studies',
      ['study', 'studys', 'studyies'], topic: PSTopic.affirmative,
      hint: 'Consonant + y changes to -ies: studies'),
  PSQuizItem('I ___ in Ankara.', 'live',
      ['lives', 'living', 'am live'], topic: PSTopic.affirmative,
      hint: 'I takes the base verb: live'),
  PSQuizItem('They ___ in a big hospital.', 'work',
      ['works', 'working', 'is work'], topic: PSTopic.affirmative,
      hint: 'They takes the base verb: work'),
  PSQuizItem('Emre ___ his car every Sunday.', 'washes',
      ['wash', 'washs', 'washing'], topic: PSTopic.affirmative,
      hint: 'Verbs ending in -sh add -es: washes'),
  PSQuizItem('The film ___ at 8 p.m.', 'starts',
      ['start', 'starting', 'is start'], topic: PSTopic.affirmative,
      hint: 'The film (it) takes starts'),
  PSQuizItem('My dad ___ two cups of tea every morning.', 'has',
      ['have', 'haves', 'having'], topic: PSTopic.affirmative,
      hint: 'Have becomes has with third-person singular'),
  PSQuizItem('The sun ___ in the east.', 'rises',
      ['rise', 'rising', 'rised'], topic: PSTopic.affirmative,
      hint: 'General fact; the sun (it) takes rises'),
  PSQuizItem('She ___ her keys every day!', 'loses',
      ['lose', 'losing', 'is lose'], topic: PSTopic.affirmative,
      hint: 'She takes loses'),
  PSQuizItem('We ___ English on Mondays.', 'have',
      ['has', 'having', 'haves'], topic: PSTopic.affirmative,
      hint: 'We takes have'),
  PSQuizItem('Zeynep ___ the piano beautifully.', 'plays',
      ['play', 'playing', 'plaies'], topic: PSTopic.affirmative,
      hint: 'Vowel + y simply adds -s: plays'),
  PSQuizItem('He ___ his room every weekend.', 'tidies',
      ['tidy', 'tidys', 'tidyes'], topic: PSTopic.affirmative,
      hint: 'Consonant + y changes to -ies: tidies'),
  PSQuizItem('My uncle ___ old watches.', 'fixes',
      ['fix', 'fixs', 'fixing'], topic: PSTopic.affirmative,
      hint: 'Verbs ending in -x add -es: fixes'),

  // --- NEGATIVE ---
  PSQuizItem('She ___ like spicy food.', "doesn't",
      ["don't", "isn't", 'not'], topic: PSTopic.negative,
      hint: "Third-person singular takes doesn't"),
  PSQuizItem('My parents ___ watch horror films.', "don't",
      ["doesn't", "aren't", 'not'], topic: PSTopic.negative,
      hint: "Plural subject (they) takes don't"),
  PSQuizItem("He doesn't ___ meat.", 'eat',
      ['eats', 'eating', 'ate'], topic: PSTopic.negative,
      hint: "Use the base verb after doesn't: eat"),
  PSQuizItem('I ___ understand the question.', "don't",
      ["doesn't", 'am not', 'not'], topic: PSTopic.negative,
      hint: "I takes don't"),
  PSQuizItem('The museum ___ have a café.', "doesn't",
      ["don't", "isn't", "hasn't"], topic: PSTopic.negative,
      hint: "The museum (it) takes doesn't have"),
  PSQuizItem('We ___ go to school on Saturdays.', "don't",
      ["doesn't", "aren't", 'not'], topic: PSTopic.negative,
      hint: "We takes don't"),
  PSQuizItem("My sister doesn't ___ coffee.", 'drink',
      ['drinks', 'drinking', 'drank'], topic: PSTopic.negative,
      hint: "Use the base verb after doesn't: drink"),
  PSQuizItem('It ___ rain much here in summer.', "doesn't",
      ["don't", "isn't", 'not'], topic: PSTopic.negative,
      hint: "It takes doesn't"),
  PSQuizItem('You ___ need a passport for this trip.', "don't",
      ["doesn't", "aren't", 'not'], topic: PSTopic.negative,
      hint: "You takes don't"),
  PSQuizItem('Ali ___ live near the school.', "doesn't",
      ["don't", "isn't", 'not'], topic: PSTopic.negative,
      hint: "Ali (he) takes doesn't"),
  PSQuizItem('Cats ___ like water.', "don't",
      ["doesn't", "aren't", "isn't"], topic: PSTopic.negative,
      hint: "Plural subject (cats) takes don't"),
  PSQuizItem("My grandfather doesn't ___ a mobile phone.", 'have',
      ['has', 'having', 'haves'], topic: PSTopic.negative,
      hint: "Use base verb have after doesn't"),
  PSQuizItem('This bus ___ stop at the hospital.', "doesn't",
      ["don't", "isn't", 'not'], topic: PSTopic.negative,
      hint: "This bus (it) takes doesn't"),
  PSQuizItem('They ___ speak French.', "don't",
      ["doesn't", "aren't", "isn't"], topic: PSTopic.negative,
      hint: "They takes don't"),
  PSQuizItem('Mert ___ get up early at weekends.', "doesn't",
      ["don't", "isn't", 'not'], topic: PSTopic.negative,
      hint: "Mert (he) takes doesn't"),

  // --- QUESTIONS ---
  PSQuizItem('___ your parents work on Saturdays?', 'Do',
      ['Does', 'Are', 'Is'], topic: PSTopic.question,
      hint: 'Plural subject (your parents = they) takes Do'),
  PSQuizItem('___ she speak Spanish?', 'Does',
      ['Do', 'Is', 'Are'], topic: PSTopic.question,
      hint: 'She takes Does in questions'),
  PSQuizItem('Does he ___ the guitar?', 'play',
      ['plays', 'playing', 'played'], topic: PSTopic.question,
      hint: 'Does + subject + base verb: play'),
  PSQuizItem('Where ___ your brother live?', 'does',
      ['do', 'is', 'are'], topic: PSTopic.question,
      hint: 'Your brother (he) takes does'),
  PSQuizItem('What time ___ you get up?', 'do',
      ['does', 'are', 'is'], topic: PSTopic.question,
      hint: 'You takes do in questions'),
  PSQuizItem('How often ___ they go to the cinema?', 'do',
      ['does', 'are', 'is'], topic: PSTopic.question,
      hint: 'They takes do'),
  PSQuizItem('___ the train leave at 9?', 'Does',
      ['Do', 'Is', 'Are'], topic: PSTopic.question,
      hint: 'The train (it) takes Does'),
  PSQuizItem('What ___ this word mean?', 'does',
      ['do', 'is', 'are'], topic: PSTopic.question,
      hint: 'This word (it) takes does'),
  PSQuizItem('Do you ___ tea or coffee?', 'like',
      ['likes', 'liking', 'liked'], topic: PSTopic.question,
      hint: 'Do + subject + base verb: like'),
  PSQuizItem('Why ___ Selin always come late?', 'does',
      ['do', 'is', 'are'], topic: PSTopic.question,
      hint: 'Selin (she) takes does'),
  PSQuizItem('Which sport ___ you like most?', 'do',
      ['does', 'are', 'is'], topic: PSTopic.question,
      hint: 'You takes do'),
  PSQuizItem('When ___ the lesson start?', 'does',
      ['do', 'is', 'are'], topic: PSTopic.question,
      hint: 'The lesson (it) takes does'),
  PSQuizItem('___ your cat sleep on your bed?', 'Does',
      ['Do', 'Is', 'Are'], topic: PSTopic.question,
      hint: 'Your cat (it) takes Does'),

  // --- SHORT ANSWERS ---
  PSQuizItem('Does Ali play chess? – Yes, ___.', 'he does',
      ['he plays', 'he is', 'he do'], topic: PSTopic.question,
      hint: 'Short answers use the auxiliary verb: Yes, he does.'),
  PSQuizItem('Do you like pizza? – No, ___.', "I don't",
      ["I doesn't", "I'm not", 'I not'], topic: PSTopic.question,
      hint: "Do you...? → No, I don't."),
  PSQuizItem('Does your mother work? – No, ___.', "she doesn't",
      ["she don't", "she isn't", 'she not'], topic: PSTopic.question,
      hint: "Does she...? → No, she doesn't."),
  PSQuizItem('Do they live here? – Yes, ___.', 'they do',
      ['they does', 'they are', 'they is'], topic: PSTopic.question,
      hint: 'Do they...? → Yes, they do.'),
  PSQuizItem('Does it rain a lot in Rize? – Yes, ___.', 'it does',
      ['it do', 'it is', 'it rain'], topic: PSTopic.question,
      hint: 'Does it...? → Yes, it does.'),
  PSQuizItem('Do you and Can play tennis? – Yes, ___.', 'we do',
      ['we does', 'we are', 'you do'], topic: PSTopic.question,
      hint: 'Subject "you and Can" answers with "we": Yes, we do.'),
  PSQuizItem('Does your brother drive? – No, ___.', "he doesn't",
      ["he don't", "he isn't", 'he not'], topic: PSTopic.question,
      hint: "Does he...? → No, he doesn't."),

  // --- ADVERBS OF FREQUENCY ---
  PSQuizItem('Tom ___ late for school.', 'is never',
      ['never is', 'never are', 'is nevers'], topic: PSTopic.frequency,
      hint: "Place the frequency adverb AFTER the verb to be: is never"),
  PSQuizItem('I ___ breakfast.', 'always have',
      ['have always', 'always has', 'am always have'], topic: PSTopic.frequency,
      hint: 'Place the frequency adverb BEFORE the main verb: always have'),
  PSQuizItem('She ___ tired after work.', 'is usually',
      ['usually is', 'usually are', 'usually does'], topic: PSTopic.frequency,
      hint: "Place frequency adverb AFTER to be: is usually"),
  PSQuizItem('We ___ to the beach in summer.', 'often go',
      ['go often', 'often goes', 'are often go'], topic: PSTopic.frequency,
      hint: 'Adverb comes BEFORE the main verb: often go'),
  PSQuizItem('My father ___ coffee at night.', 'never drinks',
      ['drinks never', 'never drink', 'is never drink'], topic: PSTopic.frequency,
      hint: 'never + verb; my father (he) takes drinks: never drinks'),
  PSQuizItem('They ___ busy on Mondays.', 'are always',
      ['always are', 'always is', 'is always'], topic: PSTopic.frequency,
      hint: "They takes are; adverb comes after are: are always"),
  PSQuizItem('He ___ his homework on time.', 'rarely does',
      ['does rarely', 'rarely do', 'is rarely do'], topic: PSTopic.frequency,
      hint: 'Adverb before verb; he takes does: rarely does'),
  PSQuizItem("I ___ eat fast food. It's unhealthy.", 'hardly ever',
      ['always', 'usually', 'often'], topic: PSTopic.frequency,
      hint: 'Unhealthy food is consumed almost never: hardly ever'),
  PSQuizItem('Elif ___ at home on Sundays.', 'is usually',
      ['usually is', 'usually are', 'usually does'], topic: PSTopic.frequency,
      hint: "Adverb comes AFTER the verb to be: is usually"),
  PSQuizItem('Do you ___ walk to school?', 'usually',
      ['usualy', 'usual', 'are usually'], topic: PSTopic.frequency,
      hint: 'In questions, adverb sits between subject and verb: Do you usually walk...?'),
  PSQuizItem('My little brother ___ his teeth before bed.', 'always brushes',
      ['always brush', 'brushes always', 'is always brush'], topic: PSTopic.frequency,
      hint: 'Adverb before verb; he takes brushes: always brushes'),
  PSQuizItem('How often do you exercise? – ___', 'Three times a week.',
      ['Last week.', 'Right now.', 'Yesterday.'], topic: PSTopic.frequency,
      hint: 'How often asks for frequency: Three times a week.'),

  // --- ROUTINES & TIME EXPRESSIONS ---
  PSQuizItem('We visit our grandparents ___.', 'every Sunday',
      ['now', 'yesterday', 'at the moment'], topic: PSTopic.routine,
      hint: 'Repeated regular routine uses: every Sunday'),
  PSQuizItem('I ___ up at 7 o\'clock every day.', 'wake',
      ['wakes', 'waking', 'am wake'], topic: PSTopic.routine,
      hint: 'I takes the base verb: wake'),
  PSQuizItem('She ___ a shower every morning.', 'takes',
      ['take', 'taking', 'is take'], topic: PSTopic.routine,
      hint: 'She takes takes'),
  PSQuizItem('My dad goes to work ___.', 'every day',
      ['right now', 'last night', 'at the moment'], topic: PSTopic.routine,
      hint: 'Present Simple regular routine: every day'),
  PSQuizItem('He ___ the dog twice a day.', 'walks',
      ['walk', 'walking', 'is walk'], topic: PSTopic.routine,
      hint: 'He takes walks'),
  PSQuizItem('I go to the gym ___.', 'three times a week',
      ['at the moment', 'now', 'last month'], topic: PSTopic.routine,
      hint: 'Habitual frequency: three times a week'),
  PSQuizItem('The shops close at 9 p.m. ___.', 'every night',
      ['right now', 'last night', 'at this moment'], topic: PSTopic.routine,
      hint: 'Regular schedule: every night'),
  PSQuizItem('My mother ___ dinner at 7 p.m.', 'cooks',
      ['cook', 'cooking', 'is cook'], topic: PSTopic.routine,
      hint: 'My mother (she) takes cooks'),
  PSQuizItem('We ___ our homework after school.', 'do',
      ['does', 'doing', 'are do'], topic: PSTopic.routine,
      hint: 'We takes do'),
  PSQuizItem('Burak ___ to bed at 11 p.m.', 'goes',
      ['go', 'going', 'is go'], topic: PSTopic.routine,
      hint: 'Burak (he) takes goes'),
  PSQuizItem('___ do you brush your teeth? – Twice a day.', 'How often',
      ['How much', 'How many', 'How long'], topic: PSTopic.routine,
      hint: 'Asking about frequency requires: How often'),
  PSQuizItem('Selin ___ dressed very quickly.', 'gets',
      ['get', 'getting', 'is get'], topic: PSTopic.routine,
      hint: 'Selin (she) takes gets'),
  PSQuizItem('On weekdays, I ___ the 7:30 bus.', 'catch',
      ['catches', 'catching', 'am catch'], topic: PSTopic.routine,
      hint: 'I takes the base verb: catch'),
  PSQuizItem('The sun ___ in the east.', 'rises',
      ['rise', 'rising', 'is rise'], topic: PSTopic.affirmative,
      hint: 'Scientific facts and singular subjects (it) take -s: rises'),
  PSQuizItem('Water ___ at 100 degrees Celsius.', 'boils',
      ['boil', 'boiling', 'is boil'], topic: PSTopic.affirmative,
      hint: 'General truths use Present Simple with -s for uncountable nouns: boils'),
  PSQuizItem('He ___ like waking up early on weekends.', 'does not',
      ['do not', 'is not', 'are not'], topic: PSTopic.negative,
      hint: 'He takes does not (doesn\'t) in negative statements.'),
  PSQuizItem('We ___ have school on Saturdays.', 'do not',
      ['does not', 'are not', 'is not'], topic: PSTopic.negative,
      hint: 'We takes do not (don\'t) with simple present verbs.'),
  PSQuizItem('___ your parents live in Ankara?', 'Do',
      ['Does', 'Are', 'Is'], topic: PSTopic.question,
      hint: 'Plural subject (parents = they) uses Do in questions.'),
  PSQuizItem('Where ___ she work on Mondays?', 'does',
      ['do', 'is', 'are'], topic: PSTopic.question,
      hint: 'Third person singular she takes does in questions.'),
  PSQuizItem('He is ___ on time for his morning classes.', 'always',
      ['now', 'yesterday', 'tomorrow'], topic: PSTopic.frequency,
      hint: 'Adverbs of frequency come after the verb to be: is always.'),
  PSQuizItem('They ___ ever watch television on weekdays.', 'hardly',
      ['always', 'every', 'rare'], topic: PSTopic.frequency,
      hint: 'Hardly ever means almost never.'),
  PSQuizItem('The plane ___ off at 8:00 every morning.', 'takes',
      ['take', 'taking', 'is take'], topic: PSTopic.routine,
      hint: 'Timetable events in simple present take -s for singular: takes'),
  PSQuizItem('She ___ a book before turning off the lamp.', 'reads',
      ['read', 'reading', 'is read'], topic: PSTopic.routine,
      hint: 'Routine action for she takes reads.'),
];

// =============================================================================
// SENTENCE SPIN (WHEEL ITEMS IN 100% ENGLISH)
// =============================================================================

class PSWheelItem {
  final int id;
  final String category;
  final String prompt;
  final String answer;
  final String hint;
  final PSTopic topic;

  const PSWheelItem({
    required this.id,
    required this.category,
    required this.prompt,
    required this.answer,
    required this.hint,
    required this.topic,
  });
}

const List<PSWheelItem> psWheelItems = [
  PSWheelItem(
    id: 1,
    category: 'SPEAKING',
    prompt: 'How long does it take you to get ready for school in the morning?',
    answer: 'Student\'s own answer.',
    hint: 'Use present simple to describe your morning routine.',
    topic: PSTopic.routine,
  ),
  PSWheelItem(
    id: 2,
    category: 'SPEAKING',
    prompt: 'What do you usually do when you need to relieve stress?',
    answer: 'Student\'s own answer.',
    hint: 'Use adverbs of frequency like usually, often, or sometimes.',
    topic: PSTopic.routine,
  ),
  PSWheelItem(
    id: 3,
    category: 'SPEAKING',
    prompt: 'How often do you check your social media accounts during the day?',
    answer: 'Student\'s own answer.',
    hint: 'Use expressions like "twice a day", "every hour", etc.',
    topic: PSTopic.frequency,
  ),
  PSWheelItem(
    id: 4,
    category: 'SPEAKING',
    prompt: 'What is one habit you want to change in your daily routine?',
    answer: 'Student\'s own answer.',
    hint: 'Talk about a habit you have.',
    topic: PSTopic.routine,
  ),
  PSWheelItem(
    id: 5,
    category: 'SPEAKING',
    prompt: 'How do you balance your study time and personal life?',
    answer: 'Student\'s own answer.',
    hint: 'Explain your routine.',
    topic: PSTopic.routine,
  ),
  PSWheelItem(
    id: 6,
    category: 'SPEAKING',
    prompt: 'What do you usually do on a typical rainy afternoon?',
    answer: 'Student\'s own answer.',
    hint: 'Describe your typical activities.',
    topic: PSTopic.routine,
  ),
  PSWheelItem(
    id: 7,
    category: 'SPEAKING',
    prompt: 'Do you prefer studying alone or working in a group? Why?',
    answer: 'Student\'s own answer.',
    hint: 'State your preference and give a reason.',
    topic: PSTopic.affirmative,
  ),
  PSWheelItem(
    id: 8,
    category: 'SPEAKING',
    prompt: 'Do you think daily routines make life easier or more boring?',
    answer: 'Student\'s own answer.',
    hint: 'Give your opinion using present simple.',
    topic: PSTopic.affirmative,
  ),
  PSWheelItem(
    id: 9,
    category: 'SPEAKING',
    prompt: 'What kind of music helps you concentrate while you study?',
    answer: 'Student\'s own answer.',
    hint: 'Name the type of music and explain why.',
    topic: PSTopic.affirmative,
  ),
  PSWheelItem(
    id: 10,
    category: 'SPEAKING',
    prompt: 'Do you prefer spending money on experiences or items? Why?',
    answer: 'Student\'s own answer.',
    hint: 'Explain your preference.',
    topic: PSTopic.affirmative,
  ),
  PSWheelItem(
    id: 11,
    category: 'SPEAKING',
    prompt: 'What type of video games or movies do you usually avoid?',
    answer: 'Student\'s own answer.',
    hint: 'Use negative sentences or verbs like "avoid".',
    topic: PSTopic.negative,
  ),
  PSWheelItem(
    id: 12,
    category: 'SPEAKING',
    prompt: 'How do you choose the clothes you wear on a normal day?',
    answer: 'Student\'s own answer.',
    hint: 'Describe your decision process.',
    topic: PSTopic.routine,
  ),
  PSWheelItem(
    id: 13,
    category: 'SPEAKING',
    prompt: 'How often do you practice speaking English outside class?',
    answer: 'Student\'s own answer.',
    hint: 'Use frequency adverbs.',
    topic: PSTopic.frequency,
  ),
  PSWheelItem(
    id: 14,
    category: 'SPEAKING',
    prompt: 'What kind of activities do you usually do with your close friends?',
    answer: 'Student\'s own answer.',
    hint: 'List the activities you do together.',
    topic: PSTopic.routine,
  ),
  PSWheelItem(
    id: 15,
    category: 'SPEAKING',
    prompt: 'How do you usually spend your weekends?',
    answer: 'Student\'s own answer.',
    hint: 'Describe your weekend routine.',
    topic: PSTopic.routine,
  ),
  PSWheelItem(
    id: 16,
    category: 'SPEAKING',
    prompt: 'Do you often cook for yourself or buy food outside?',
    answer: 'Student\'s own answer.',
    hint: 'Talk about your eating habits.',
    topic: PSTopic.routine,
  ),
  PSWheelItem(
    id: 17,
    category: 'SPEAKING',
    prompt: 'What is a topic you love talking about with friends?',
    answer: 'Student\'s own answer.',
    hint: 'Mention the topic and why you love it.',
    topic: PSTopic.affirmative,
  ),
  PSWheelItem(
    id: 18,
    category: 'SPEAKING',
    prompt: 'Do you read books before you go to sleep?',
    answer: 'Student\'s own answer.',
    hint: 'Answer with yes/no and give details.',
    topic: PSTopic.routine,
  ),
  PSWheelItem(
    id: 19,
    category: 'SPEAKING',
    prompt: 'How do you motivate yourself to do homework?',
    answer: 'Student\'s own answer.',
    hint: 'Explain your motivation strategy.',
    topic: PSTopic.routine,
  ),
  PSWheelItem(
    id: 20,
    category: 'SPEAKING',
    prompt: 'What do you think is the best way to start a day?',
    answer: 'Student\'s own answer.',
    hint: 'Describe a good morning routine.',
    topic: PSTopic.routine,
  ),
];

// =============================================================================
// DIALOGUE LISTENING ACTIVITY (100% ENGLISH)
// =============================================================================

class PSDialogueLine {
  final String speaker;
  final String text;

  const PSDialogueLine({
    required this.speaker,
    required this.text,
  });
}

enum DialogueQuestionType { trueFalse, multipleChoice, fillBlank }

class PSDialogueQuestion {
  final int id;
  final DialogueQuestionType type;
  final String question;
  final List<String> options;
  final String correctAnswer;
  final String hint;

  const PSDialogueQuestion({
    required this.id,
    required this.type,
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.hint,
  });
}

class PSDialogueData {
  final String title;
  final String subtitle;
  final String audioAsset;
  final List<PSDialogueLine> lines;
  final List<PSDialogueQuestion> questions;

  const PSDialogueData({
    required this.title,
    required this.subtitle,
    required this.audioAsset,
    required this.lines,
    required this.questions,
  });
}

const PSDialogueData psSampleDialogue = PSDialogueData(
  title: 'Dialogue Activity',
  subtitle: 'Listen to the dialogue and answer the questions',
  audioAsset: 'assets/audio/present_simple_dialogue.wav.wav',
  lines: [],
  questions: [
    // 1. True / False
    PSDialogueQuestion(
      id: 1,
      type: DialogueQuestionType.trueFalse,
      question: 'Alex plays Minecraft every day.',
      options: ['True', 'False'],
      correctAnswer: 'False',
      hint: 'Listen carefully to how often Alex plays.',
    ),
    PSDialogueQuestion(
      id: 2,
      type: DialogueQuestionType.trueFalse,
      question: 'Alex\'s brother likes creative mode.',
      options: ['True', 'False'],
      correctAnswer: 'True',
      hint: 'Listen to what her brother likes.',
    ),
    PSDialogueQuestion(
      id: 3,
      type: DialogueQuestionType.trueFalse,
      question: 'Steve starts a new world with his friends.',
      options: ['True', 'False'],
      correctAnswer: 'True',
      hint: 'Listen to what Steve does with his friends.',
    ),
    PSDialogueQuestion(
      id: 4,
      type: DialogueQuestionType.trueFalse,
      question: 'Steve never builds big cities in the game.',
      options: ['True', 'False'],
      correctAnswer: 'True',
      hint: 'Listen to what Steve builds.',
    ),

    // 2. Fill in the Blank
    PSDialogueQuestion(
      id: 5,
      type: DialogueQuestionType.fillBlank,
      question: 'Alex usually ___ (play) twice a week.',
      options: ['play', 'plays', 'playing', 'is play'],
      correctAnswer: 'plays',
      hint: 'Alex is third-person singular.',
    ),
    PSDialogueQuestion(
      id: 6,
      type: DialogueQuestionType.fillBlank,
      question: 'Her brother ___ (not / like) survival mode.',
      options: ['doesn\'t like', 'don\'t like', 'not like', 'isn\'t like'],
      correctAnswer: 'doesn\'t like',
      hint: 'Third-person singular negative.',
    ),
    PSDialogueQuestion(
      id: 7,
      type: DialogueQuestionType.fillBlank,
      question: 'Steve and his friends ___ (not / play) every night.',
      options: ['don\'t play', 'doesn\'t play', 'not play', 'aren\'t play'],
      correctAnswer: 'don\'t play',
      hint: 'Plural subject negative.',
    ),
    PSDialogueQuestion(
      id: 8,
      type: DialogueQuestionType.fillBlank,
      question: 'Steve ___ (never / build) big cities.',
      options: ['never builds', 'never build', 'is never build', 'never building'],
      correctAnswer: 'never builds',
      hint: 'Third-person singular with frequency adverb.',
    ),
  ],
);

