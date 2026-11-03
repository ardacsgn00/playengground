import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum GameDifficulty {
  all,
  elementary, // A1–A2
  intermediate, // B1–B2
}

extension GameDifficultyExtension on GameDifficulty {
  String get code {
    switch (this) {
      case GameDifficulty.elementary:
        return 'elementary';
      case GameDifficulty.intermediate:
        return 'intermediate';
      case GameDifficulty.all:
        return 'all';
    }
  }

  String get labelTr {
    switch (this) {
      case GameDifficulty.elementary:
        return 'A1–A2 Başlangıç';
      case GameDifficulty.intermediate:
        return 'B1–B2 Orta–İleri';
      case GameDifficulty.all:
        return 'Tümü (Karışık)';
    }
  }

  String get labelEn {
    switch (this) {
      case GameDifficulty.elementary:
        return 'A1–A2 Elementary';
      case GameDifficulty.intermediate:
        return 'B1–B2 Intermediate';
      case GameDifficulty.all:
        return 'All Levels';
    }
  }

  String get shortLabel {
    switch (this) {
      case GameDifficulty.elementary:
        return 'A1–A2';
      case GameDifficulty.intermediate:
        return 'B1–B2';
      case GameDifficulty.all:
        return 'Tümü';
    }
  }

  String get descriptionTr {
    switch (this) {
      case GameDifficulty.elementary:
        return 'Günlük yaşam ve temel kelimeler. Kolay ve eğlenceli başlangıç.';
      case GameDifficulty.intermediate:
        return 'Zengin, akademik ve ileri düzey kelimeler. Kendini test et.';
      case GameDifficulty.all:
        return 'Başlangıçtan ileriye tüm kelime ve soru havuzu karışık.';
    }
  }

  Color get color {
    switch (this) {
      case GameDifficulty.elementary:
        return const Color(0xFF10B981); // Emerald Green
      case GameDifficulty.intermediate:
        return const Color(0xFF8B5CF6); // Violet / Purple
      case GameDifficulty.all:
        return const Color(0xFFF59E0B); // Amber / Gold
    }
  }

  IconData get icon {
    switch (this) {
      case GameDifficulty.elementary:
        return FontAwesomeIcons.seedling;
      case GameDifficulty.intermediate:
        return FontAwesomeIcons.bolt;
      case GameDifficulty.all:
        return FontAwesomeIcons.dice;
    }
  }
}

class LevelService {
  LevelService._();
  static final LevelService instance = LevelService._();

  static const String _prefKey = 'selected_game_difficulty';
  GameDifficulty _currentDifficulty = GameDifficulty.all;
  bool _initialized = false;

  GameDifficulty get currentDifficulty => _currentDifficulty;

  Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_prefKey);
      if (code != null) {
        _currentDifficulty = _fromCode(code);
      }
    } catch (_) {
      _currentDifficulty = GameDifficulty.all;
    }
    _initialized = true;
  }

  static GameDifficulty _fromCode(String code) {
    switch (code) {
      case 'elementary':
        return GameDifficulty.elementary;
      case 'intermediate':
        return GameDifficulty.intermediate;
      default:
        return GameDifficulty.all;
    }
  }

  Future<void> setDifficulty(GameDifficulty difficulty) async {
    _currentDifficulty = difficulty;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, difficulty.code);
    } catch (_) {}
  }

  /// Determines the CEFR tier for a given English word or phrase.
  GameDifficulty getWordDifficulty(String text) {
    final clean = text
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z]'), '');

    if (clean.isEmpty) return GameDifficulty.elementary;

    if (_elementaryWordSet.contains(clean)) {
      return GameDifficulty.elementary;
    }
    if (_intermediateWordSet.contains(clean)) {
      return GameDifficulty.intermediate;
    }

    // Heuristics based on morphology and length
    if (clean.endsWith('tion') ||
        clean.endsWith('sion') ||
        clean.endsWith('ment') ||
        clean.endsWith('ance') ||
        clean.endsWith('ence') ||
        clean.endsWith('ious') ||
        clean.endsWith('able') ||
        clean.endsWith('ible') ||
        clean.endsWith('ology') ||
        clean.endsWith('ity') ||
        clean.endsWith('ism') ||
        clean.endsWith('ize') ||
        clean.endsWith('ise') ||
        clean.length >= 8) {
      return GameDifficulty.intermediate;
    }

    if (clean.length <= 5) {
      return GameDifficulty.elementary;
    }

    // Default balance
    return clean.hashCode.abs() % 2 == 0
        ? GameDifficulty.elementary
        : GameDifficulty.intermediate;
  }

  /// Filters a dictionary map (e.g. English word -> Turkish hint) based on difficulty.
  /// Always guarantees a non-empty result.
  Map<String, String> filterDictionary(
    Map<String, String> source,
    GameDifficulty difficulty,
  ) {
    if (difficulty == GameDifficulty.all || source.length <= 12) {
      return Map<String, String>.from(source);
    }

    final filtered = <String, String>{};
    for (final entry in source.entries) {
      final diff = getWordDifficulty(entry.key);
      if (diff == difficulty) {
        filtered[entry.key] = entry.value;
      }
    }

    // Safeguard: If too few words match, supplement from source to avoid starvation
    if (filtered.length < 12) {
      return Map<String, String>.from(source);
    }

    return filtered;
  }

  /// Filters a list of English words based on difficulty.
  List<String> filterWordList(
    List<String> source,
    GameDifficulty difficulty,
  ) {
    if (difficulty == GameDifficulty.all || source.length <= 10) {
      return List<String>.from(source);
    }

    final filtered = source.where((w) {
      return getWordDifficulty(w) == difficulty;
    }).toList();

    if (filtered.length < 8) {
      return List<String>.from(source);
    }

    return filtered;
  }

  /// Elementary (A1-A2) core vocabulary set
  static final Set<String> _elementaryWordSet = {
    // Basics & Numbers & Colors
    'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten',
    'red', 'blue', 'green', 'yellow', 'black', 'white', 'brown', 'pink', 'orange', 'grey', 'gray', 'purple',
    // Animals
    'cat', 'dog', 'fish', 'bird', 'horse', 'cow', 'pig', 'sheep', 'duck', 'mouse',
    'bear', 'lion', 'tiger', 'monkey', 'rabbit', 'snake', 'frog', 'elephant', 'chicken', 'bee',
    'donkey', 'goat', 'wolf', 'fox', 'deer', 'camel', 'turtle', 'panda', 'spider', 'zebra',
    // Food & Drinks
    'apple', 'bread', 'water', 'milk', 'coffee', 'tea', 'juice', 'cheese', 'egg', 'meat',
    'fruit', 'rice', 'soup', 'sugar', 'salt', 'banana', 'cake', 'lemon', 'butter',
    'pizza', 'salad', 'potato', 'tomato', 'onion', 'carrot', 'melon', 'grape', 'peach', 'plum',
    // Family & People
    'man', 'woman', 'child', 'boy', 'girl', 'baby', 'friend', 'family', 'mother', 'father',
    'parent', 'brother', 'sister', 'son', 'daughter', 'husband', 'wife', 'doctor', 'teacher',
    'driver', 'farmer', 'worker', 'student', 'people', 'person', 'police', 'nurse', 'cook',
    // Home & Daily Objects
    'house', 'home', 'room', 'door', 'window', 'table', 'chair', 'bed', 'desk', 'clock',
    'lamp', 'key', 'book', 'pen', 'pencil', 'paper', 'bag', 'phone', 'box', 'cup', 'glass',
    'bottle', 'plate', 'fork', 'spoon', 'knife', 'sofa', 'wall', 'floor', 'mirror', 'carpet',
    // Body Parts
    'head', 'face', 'eye', 'ear', 'nose', 'mouth', 'tooth', 'teeth', 'hair', 'hand',
    'arm', 'leg', 'foot', 'feet', 'finger', 'toe', 'back', 'neck', 'shoulder', 'heart', 'knee',
    // Clothes
    'shirt', 'pants', 'dress', 'skirt', 'shoes', 'socks', 'hat', 'coat', 'jacket', 'boots',
    'jeans', 'suit', 'tshirt', 'scarf', 'glove', 'gloves', 'belt', 'pocket', 'wallet',
    // Nature & Weather
    'sun', 'moon', 'star', 'sky', 'rain', 'snow', 'wind', 'cloud', 'storm', 'fire',
    'tree', 'flower', 'grass', 'plant', 'sea', 'river', 'lake', 'beach', 'forest', 'garden',
    'park', 'street', 'road', 'city', 'town', 'village', 'country', 'world', 'earth',
    // Common Verbs
    'go', 'come', 'see', 'look', 'hear', 'listen', 'say', 'speak', 'talk', 'tell',
    'eat', 'drink', 'sleep', 'wake', 'walk', 'run', 'swim', 'play', 'read', 'write',
    'sing', 'dance', 'laugh', 'smile', 'cry', 'open', 'close', 'sit', 'stand', 'stop',
    'start', 'begin', 'give', 'take', 'buy', 'sell', 'help', 'learn', 'teach', 'work',
    'make', 'do', 'have', 'like', 'love', 'live', 'stay', 'meet', 'wash', 'clean',
    'drive', 'ride', 'fly', 'bake', 'wait', 'call', 'ask', 'answer', 'know', 'think',
    // Common Adjectives
    'good', 'bad', 'big', 'small', 'little', 'hot', 'cold', 'warm', 'new', 'old',
    'young', 'happy', 'sad', 'angry', 'tired', 'hungry', 'fast', 'slow', 'easy', 'hard',
    'rich', 'poor', 'tall', 'short', 'long', 'pure', 'dirty', 'sweet', 'sour', 'quiet',
    'loud', 'busy', 'free', 'safe', 'strong', 'weak', 'heavy', 'light', 'dark', 'bright',
    'funny', 'nice', 'fine', 'ready', 'early', 'late', 'cheap', 'expensive', 'true', 'false',
    // Time & Days
    'day', 'night', 'morning', 'afternoon', 'evening', 'week', 'month', 'year', 'time',
    'hour', 'minute', 'today', 'yesterday', 'tomorrow', 'summer', 'winter', 'spring', 'autumn',
  };

  /// Intermediate (B1-B2) vocabulary set
  static final Set<String> _intermediateWordSet = {
    // Abstract & Cognitive
    'abandon', 'ability', 'absolute', 'abstract', 'accurate', 'achieve', 'acknowledge',
    'acquire', 'adapt', 'adequate', 'adjust', 'administration', 'admit', 'adopt',
    'advance', 'advantage', 'advocate', 'affect', 'afford', 'aggressive', 'allocate',
    'alter', 'alternative', 'ambiguous', 'ambition', 'analyze', 'analysis', 'antique',
    'apparent', 'appeal', 'appoint', 'appreciate', 'approach', 'appropriate', 'approximate',
    'arbitrary', 'aspect', 'assemble', 'assess', 'asset', 'assign', 'assist', 'assume',
    'assumption', 'assure', 'attach', 'attain', 'attempt', 'attitude', 'attribute',
    'authentic', 'author', 'authority', 'automatic', 'available', 'aware', 'barrier',
    'behalf', 'beneficial', 'benefit', 'bias', 'bond', 'boundary', 'brief', 'bulk',
    'capable', 'capacity', 'category', 'cease', 'challenge', 'channel', 'chaos',
    'characteristic', 'chronic', 'circumstance', 'cite', 'civil', 'clarify', 'clause',
    'client', 'clue', 'code', 'coherent', 'coincide', 'collapse', 'colleague',
    'commence', 'commission', 'commit', 'commodity', 'compatible', 'compel', 'compensate',
    'compile', 'complement', 'complex', 'component', 'compound', 'comprehensive',
    'comprise', 'compute', 'concede', 'conceive', 'concentrate', 'concept', 'conclude',
    'concrete', 'conduct', 'confer', 'confine', 'confirm', 'conform', 'consent',
    'consequence', 'considerable', 'consist', 'consistent', 'constant', 'constitute',
    'constrain', 'construct', 'consult', 'consume', 'contact', 'contemporary',
    'context', 'contradict', 'contrary', 'contrast', 'contribute', 'controversy',
    'conventional', 'converse', 'convert', 'convey', 'convince', 'cooperate',
    'coordinate', 'core', 'corporate', 'correspond', 'create', 'credit', 'criterion',
    'crucial', 'culture', 'currency', 'cycle', 'debate', 'decade', 'decline',
    'deduce', 'define', 'definite', 'demonstrate', 'denote', 'deny', 'depress',
    'deprive', 'derive', 'design', 'designate', 'despair', 'detect', 'deteriorate',
    'deviate', 'device', 'devote', 'differentiate', 'dimension', 'diminish',
    'discrete', 'discriminate', 'displace', 'display', 'dispose', 'dispute',
    'distinct', 'distort', 'distribute', 'diverse', 'document', 'domain', 'domestic',
    'dominate', 'draft', 'drama', 'duration', 'dynamic', 'economy', 'editorial',
    'element', 'eliminate', 'emerge', 'emphasis', 'empirical', 'enable', 'encounter',
    'energy', 'enforce', 'enhance', 'enormous', 'ensure', 'entity', 'environment',
    'equate', 'equip', 'equivalent', 'erode', 'error', 'establish', 'estate',
    'estimate', 'ethical', 'ethnic', 'evaluate', 'eventual', 'evident', 'evolve',
    'exceed', 'exclude', 'exhibit', 'expand', 'expert', 'explicit', 'exploit',
    'export', 'expose', 'external', 'extract', 'facilitate', 'factor', 'feature',
    'federal', 'fee', 'file', 'final', 'finance', 'finite', 'flexible', 'fluctuate',
    'focus', 'format', 'formula', 'forthcoming', 'foundation', 'framework', 'function',
    'fund', 'fundamental', 'furthermore', 'gender', 'generate', 'generation',
    'globe', 'goal', 'grade', 'grant', 'guarantee', 'guideline', 'hence',
    'hierarchy', 'highlight', 'hypothesis', 'identical', 'identify', 'ideology',
    'ignore', 'illustrate', 'image', 'immigrate', 'impact', 'implement', 'implicate',
    'implicit', 'imply', 'impose', 'incentive', 'incidence', 'incline', 'income',
    'incorporate', 'index', 'indicate', 'individual', 'induce', 'inevitable',
    'infer', 'infrastructure', 'inherent', 'inhibit', 'initial', 'initiate',
    'injure', 'innovate', 'input', 'insert', 'insight', 'inspect', 'instance',
    'institute', 'instruct', 'integral', 'integrate', 'integrity', 'intellectual',
    'intelligence', 'intense', 'interact', 'intermediate', 'internal', 'interpret',
    'interval', 'intervene', 'intrinsic', 'invest', 'investigate', 'invoke',
    'involve', 'isolate', 'issue', 'item', 'job', 'journal', 'justify', 'label',
    'labor', 'layer', 'lecture', 'legal', 'legislate', 'levy', 'liberal', 'license',
    'likewise', 'link', 'locate', 'logic', 'maintain', 'major', 'manipulate',
    'manual', 'margin', 'mature', 'maximize', 'mechanism', 'media', 'mediate',
    'medical', 'medium', 'mental', 'method', 'migrate', 'military', 'minimal',
    'minimize', 'minimum', 'ministry', 'minor', 'mode', 'modify', 'monitor',
    'motive', 'mutual', 'negate', 'network', 'neutral', 'nevertheless', 'nonetheless',
    'norm', 'normal', 'notion', 'nuclear', 'objective', 'obtain', 'obvious',
    'occupy', 'occur', 'odd', 'offset', 'ongoing', 'option', 'orient', 'outcome',
    'output', 'overall', 'overlap', 'overseas', 'panel', 'paradigm', 'paragraph',
    'parallel', 'parameter', 'participate', 'partner', 'passive', 'perceive',
    'percent', 'period', 'persist', 'perspective', 'phase', 'phenomenon', 'philosophy',
    'physical', 'plus', 'policy', 'portion', 'pose', 'positive', 'potential',
    'practitioner', 'precede', 'precise', 'predict', 'predominant', 'preliminary',
    'presume', 'previous', 'primary', 'prime', 'principal', 'principle', 'prior',
    'priority', 'proceed', 'process', 'professional', 'prohibit', 'project',
    'promote', 'proportion', 'prospect', 'protocol', 'psychology', 'publication',
    'publish', 'purchase', 'pursue', 'qualitative', 'quote', 'radical', 'random',
    'range', 'ratio', 'rational', 'react', 'recover', 'refine', 'regime',
    'region', 'register', 'regulate', 'reinforce', 'reject', 'relax', 'release',
    'relevant', 'reluctance', 'rely', 'remove', 'require', 'research', 'reside',
    'resolve', 'resource', 'respond', 'restore', 'restrain', 'restrict', 'retain',
    'reveal', 'revenue', 'reverse', 'revise', 'revolution', 'rigid', 'role',
    'route', 'scenario', 'schedule', 'scheme', 'scope', 'section', 'sector',
    'secure', 'seek', 'select', 'sequence', 'series', 'shift', 'significant',
    'similar', 'simulate', 'site', 'so-called', 'sole', 'somewhat', 'source',
    'specific', 'specify', 'sphere', 'stable', 'statistic', 'status', 'straightforward',
    'strategy', 'stress', 'structure', 'style', 'submit', 'subordinate', 'subsequent',
    'subsidy', 'substitute', 'successor', 'sufficient', 'sum', 'summary', 'supplement',
    'survey', 'survive', 'suspend', 'sustain', 'symbol', 'tape', 'target',
    'task', 'team', 'technical', 'technique', 'technology', 'temporary', 'tense',
    'terminate', 'theme', 'theory', 'thereby', 'thesis', 'topic', 'trace',
    'tradition', 'transfer', 'transform', 'transit', 'transmit', 'transport',
    'trend', 'trigger', 'ultimate', 'undergo', 'underlie', 'undertake', 'uniform',
    'unify', 'unique', 'utilize', 'valid', 'vary', 'vehicle', 'version', 'via',
    'violate', 'virtual', 'visible', 'vision', 'visual', 'volume', 'voluntary',
    'welfare', 'whereas', 'whereby', 'widespread', 'yield',
  };
}
