import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../widgets/category_selection_dialog.dart';

const Map<String, List<String>> wordHuntCategories = {
  'Animals': [
    'monkey', 'tiger', 'rabbit', 'snake', 'horse', 'turtle', 'camel', 'panda', 'spider', 'penguin', 'dolphin', 'parrot', 'lizard', 'donkey', 'kangaroo', 'cheetah', 'giraffe', 'elephant', 'badger', 'beaver', 'falcon', 'flamingo', 'gorilla', 'hedgehog', 'jaguar', 'koala', 'leopard', 'ostrich', 'otter', 'panther', 'raccoon', 'walrus', 'zebra', 'hyena', 'pelican', 'antelope', 'cougar', 'bison', 'weasel'
  ],
  'Fruits': [
    'apple', 'banana', 'orange', 'grape', 'lemon', 'peach', 'melon', 'cherry', 'mango', 'pineapple', 'coconut', 'papaya', 'apricot', 'fig', 'guava', 'kiwi', 'lime', 'plum', 'pear', 'berry', 'avocado', 'mulberry', 'raisin', 'prune', 'citrus', 'quince'
  ],
  'Vegetables': [
    'tomato', 'potato', 'carrot', 'onion', 'garlic', 'pepper', 'cabbage', 'broccoli', 'spinach', 'radish', 'eggplant', 'celery', 'corn', 'cucumber', 'lettuce', 'pumpkin', 'turnip', 'pea', 'bean', 'beet', 'okra', 'kale', 'arugula', 'yam', 'leek'
  ],
  'Professions': [
    'doctor', 'teacher', 'pilot', 'nurse', 'police', 'singer', 'baker', 'farmer', 'artist', 'driver', 'worker', 'writer', 'dentist', 'engineer', 'actor', 'author', 'butcher', 'chef', 'clerk', 'judge', 'lawyer', 'painter', 'plumber', 'tailor', 'waiter', 'sailor', 'chemist', 'biologist', 'curator', 'diplomat', 'geologist'
  ],
  'Vehicles': [
    'train', 'plane', 'truck', 'subway', 'rocket', 'bicycle', 'scooter', 'tractor', 'yacht', 'ferry', 'taxi', 'van', 'boat', 'ship', 'tram', 'wagon', 'canoe', 'kayak', 'glider', 'cruiser', 'monorail', 'sidecar', 'tandem', 'steamer'
  ],
  'Countries': [
    'turkey', 'italy', 'spain', 'france', 'japan', 'china', 'india', 'brazil', 'canada', 'germany', 'egypt', 'russia', 'mexico', 'norway', 'sweden', 'greece', 'poland', 'korea', 'chile', 'peru', 'finland', 'austria', 'denmark', 'belgium', 'ireland'
  ],
  'Body Parts': [
    'mouth', 'finger', 'tooth', 'shoulder', 'stomach', 'muscle', 'tongue', 'elbow', 'ankle', 'thumb', 'throat', 'chest', 'brain', 'heart', 'wrist', 'waist', 'spine', 'skull', 'knee', 'neck', 'nose', 'jaw', 'rib', 'shin', 'nostril', 'eyelash'
  ],
  'Colors': [
    'yellow', 'purple', 'orange', 'brown', 'black', 'white', 'green', 'magenta', 'silver', 'violet', 'indigo', 'golden', 'amber', 'bronze', 'crimson', 'cyan', 'maroon', 'navy', 'olive', 'pink', 'teal', 'charcoal', 'emerald', 'lavender', 'scarlet'
  ],
  'Furniture': [
    'chair', 'table', 'carpet', 'mirror', 'clock', 'window', 'closet', 'drawer', 'blanket', 'cushion', 'sofa', 'desk', 'stool', 'couch', 'shelf', 'wardrobe', 'bench', 'cabinet', 'dresser', 'hammock', 'credenza', 'ottoman', 'sideboard', 'armchair'
  ],
  'Sports': [
    'soccer', 'tennis', 'hockey', 'karate', 'volleyball', 'baseball', 'swimming', 'cycling', 'boxing', 'archery', 'cricket', 'fencing', 'judo', 'rowing', 'rugby', 'skating', 'skiing', 'surfing', 'handball', 'biathlon', 'curling', 'netball', 'polo'
  ],
  'Instruments': [
    'guitar', 'piano', 'flute', 'violin', 'trumpet', 'drumset', 'keyboard', 'banjo', 'bugle', 'cello', 'clarinet', 'cymbal', 'harp', 'organ', 'viola', 'whistle', 'mandolin', 'ukulele', 'bassoon', 'timpani', 'xylophone'
  ],
  'Clothing': [
    'shirt', 'pants', 'jacket', 'glove', 'scarf', 'dress', 'skirt', 'sweater', 'shorts', 'blouse', 'boots', 'coat', 'hoodie', 'jeans', 'socks', 'suit', 'vest', 'sandals', 'slippers', 'cardigan', 'bathrobe', 'mittens', 'overalls', 'beret'
  ],
  'Weather': [
    'cloud', 'storm', 'sunny', 'rainy', 'windy', 'snowy', 'breeze', 'thunder', 'tornado', 'blizzard', 'frost', 'drizzle', 'foggy', 'hail', 'humid', 'rainbow', 'typhoon', 'humidity', 'heatwave', 'sunshine', 'dewdrop', 'overcast'
  ],
  'Emotions': [
    'happy', 'angry', 'scared', 'tired', 'bored', 'excited', 'proud', 'nervous', 'peaceful', 'jealous', 'calm', 'curious', 'eager', 'glad', 'hopeful', 'joyful', 'lonely', 'relieved', 'furious', 'anxious', 'cheerful', 'grateful', 'gloomy'
  ],
  'Universe': [
    'planet', 'earth', 'comet', 'alien', 'galaxy', 'meteor', 'rocket', 'asteroid', 'nebula', 'eclipse', 'cosmos', 'orbit', 'vacuum', 'gravity', 'pulsar', 'star', 'sun', 'moon', 'quasar', 'solstice', 'supernova', 'cluster', 'aurora', 'zenith'
  ],
  'Shapes': [
    'circle', 'square', 'triangle', 'diamond', 'star', 'heart', 'oval', 'hexagon', 'octagon', 'sphere', 'cube', 'pyramid', 'cylinder', 'cone', 'polygon', 'spiral', 'ellipse', 'crescent', 'rhombus', 'trapezoid', 'sector', 'annulus'
  ],
  'Nature': [
    'forest', 'mountain', 'river', 'ocean', 'valley', 'desert', 'jungle', 'island', 'beach', 'cave', 'volcano', 'canyon', 'glacier', 'lagoon', 'meadow', 'swamp', 'cliff', 'tundra', 'savanna', 'geyser', 'crater', 'plateau'
  ],
  'Technology': [
    'computer', 'laptop', 'tablet', 'phone', 'printer', 'keyboard', 'mouse', 'monitor', 'screen', 'software', 'hardware', 'network', 'battery', 'camera', 'charger', 'display', 'modem', 'robot', 'sensor', 'webcam', 'router', 'antenna', 'scanner', 'gadget'
  ],
  'School': [
    'student', 'teacher', 'pencil', 'eraser', 'notebook', 'ruler', 'marker', 'crayon', 'backpack', 'library', 'science', 'history', 'binder', 'chalk', 'compass', 'folder', 'lesson', 'diploma', 'lecture', 'syllabus', 'campus', 'thesis'
  ],
  'House': [
    'kitchen', 'bedroom', 'bathroom', 'garage', 'balcony', 'garden', 'ceiling', 'window', 'chimney', 'stairs', 'hallway', 'basement', 'attic', 'door', 'fence', 'gate', 'porch', 'roof', 'doorknob', 'pantry', 'sunroom', 'shutters', 'hearth'
  ],
  'Insects': [
    'spider', 'ant', 'bee', 'wasp', 'fly', 'mosquito', 'beetle', 'moth', 'cricket', 'ladybug', 'mantis', 'termite', 'hornet', 'locust', 'roach', 'flea', 'gnat', 'firefly', 'cicada', 'maggot', 'earwig', 'aphid'
  ],
  'Ocean Life': [
    'shark', 'whale', 'dolphin', 'octopus', 'squid', 'crab', 'lobster', 'seahorse', 'starfish', 'coral', 'turtle', 'eel', 'clam', 'otter', 'seal', 'walrus', 'shrimp', 'sponge', 'plankton', 'stingray', 'barnacle', 'anemone', 'jellyfish'
  ],
  'Kitchen': [
    'blender', 'toaster', 'kettle', 'teapot', 'pan', 'pot', 'knife', 'fork', 'spoon', 'plate', 'bowl', 'mug', 'cup', 'apron', 'grater', 'whisk', 'strainer', 'colander', 'skillet', 'spatula', 'peeler', 'griddle'
  ],
  'Music': [
    'melody', 'rhythm', 'harmony', 'tempo', 'chorus', 'ballad', 'concert', 'singer', 'album', 'track', 'verse', 'chord', 'opera', 'lyric', 'scale', 'beat', 'aria', 'concerto', 'sonata', 'cantata', 'motet'
  ],
};

const Map<String, String> wordHuntCategoryTr = {
  'Animals': 'Hayvanlar',
  'Fruits': 'Meyveler',
  'Vegetables': 'Sebzeler',
  'Professions': 'Meslekler',
  'Vehicles': 'Taşıtlar',
  'Countries': 'Ülkeler',
  'Body Parts': 'Vücut Bölümleri',
  'Colors': 'Renkler',
  'Furniture': 'Mobilyalar',
  'Sports': 'Sporlar',
  'Instruments': 'Müzik Aletleri',
  'Clothing': 'Kıyafetler',
  'Weather': 'Hava Durumu',
  'Emotions': 'Duygular',
  'Universe': 'Uzay & Evren',
  'Shapes': 'Geometrik Şekiller',
  'Nature': 'Doğa & Coğrafya',
  'Technology': 'Teknoloji',
  'School': 'Okul & Eğitim',
  'House': 'Ev & Eşyalar',
  'Insects': 'Böcekler',
  'Ocean Life': 'Deniz Canlıları',
  'Kitchen': 'Mutfak',
  'Music': 'Müzik & Şarkı',
};

IconData getWordHuntCategoryIcon(String cat) {
  switch (cat) {
    case 'Animals': return FontAwesomeIcons.paw;
    case 'Fruits': return FontAwesomeIcons.appleWhole;
    case 'Vegetables': return FontAwesomeIcons.carrot;
    case 'Professions': return FontAwesomeIcons.userDoctor;
    case 'Vehicles': return FontAwesomeIcons.car;
    case 'Countries': return FontAwesomeIcons.earthAmericas;
    case 'Body Parts': return FontAwesomeIcons.hand;
    case 'Colors': return FontAwesomeIcons.palette;
    case 'Furniture': return FontAwesomeIcons.couch;
    case 'Sports': return FontAwesomeIcons.futbol;
    case 'Instruments': return FontAwesomeIcons.guitar;
    case 'Clothing': return FontAwesomeIcons.shirt;
    case 'Weather': return FontAwesomeIcons.cloudSun;
    case 'Emotions': return FontAwesomeIcons.faceSmile;
    case 'Universe': return FontAwesomeIcons.shuttleSpace;
    case 'Shapes': return FontAwesomeIcons.shapes;
    case 'Nature': return FontAwesomeIcons.tree;
    case 'Technology': return FontAwesomeIcons.laptop;
    case 'School': return FontAwesomeIcons.graduationCap;
    case 'House': return FontAwesomeIcons.house;
    case 'Insects': return FontAwesomeIcons.bug;
    case 'Ocean Life': return FontAwesomeIcons.fish;
    case 'Kitchen': return FontAwesomeIcons.utensils;
    case 'Music': return FontAwesomeIcons.music;
    default: return FontAwesomeIcons.layerGroup;
  }
}

List<CategoryOption> getWordHuntCategoryOptions() {
  final List<CategoryOption> list = [
    const CategoryOption(
      id: 'All',
      titleTr: 'Rastgele Kategori',
      titleEn: 'All / Random Categories',
      icon: FontAwesomeIcons.dice,
      isAll: true,
    ),
  ];

  for (final entry in wordHuntCategories.entries) {
    final cat = entry.key;
    list.add(
      CategoryOption(
        id: cat,
        titleTr: wordHuntCategoryTr[cat] ?? cat,
        titleEn: cat,
        icon: getWordHuntCategoryIcon(cat),
        count: entry.value.length,
      ),
    );
  }

  return list;
}

