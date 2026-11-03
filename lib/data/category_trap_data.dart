/// Category Trap: category -> words.
/// A word must belong to exactly ONE category (the game checks membership).
const Map<String, List<String>> categoryTrapCategories = {
  'Animals': [
    'Lion', 'Tiger', 'Elephant', 'Giraffe', 'Monkey', 'Zebra', 'Rabbit', 'Panda', 'Kangaroo', 'Wolf', 'Fox', 'Bear', 'Deer', 'Horse', 'Cow', 'Dog', 'Cat', 'Mouse', 'Snake', 'Shark', 'Whale', 'Dolphin', 'Eagle', 'Penguin', 'Turtle', 'Cheetah', 'Hippopotamus', 'Gorilla', 'Squirrel', 'Beaver', 'Crocodile', 'Flamingo', 'Hedgehog', 'Otter', 'Koala', 'Chameleon', 'Octopus', 'Squid', 'Crab', 'Lobster', 'Peacock', 'Bat', 'Camel', 'Donkey', 'Badger', 'Hyena', 'Jaguar', 'Pelican', 'Antelope', 'Koala Bear', 'Seagull', 'Walrus'
  ],
  'Fruits': [
    'Apple', 'Banana', 'Orange', 'Grape', 'Strawberry', 'Watermelon', 'Pineapple', 'Mango', 'Kiwi', 'Peach', 'Pear', 'Cherry', 'Melon', 'Lemon', 'Plum', 'Papaya', 'Coconut', 'Fig', 'Avocado', 'Pomegranate', 'Apricot', 'Blackberry', 'Raspberry', 'Blueberry', 'Tangerine', 'Grapefruit', 'Cranberry', 'Lime', 'Guava', 'Cantaloupe', 'Passionfruit', 'Dragonfruit', 'Mulberry', 'Gooseberry', 'Clementine'
  ],
  'Vegetables': [
    'Carrot', 'Potato', 'Tomato', 'Onion', 'Garlic', 'Broccoli', 'Cabbage', 'Spinach', 'Corn', 'Cucumber', 'Pepper', 'Mushroom', 'Eggplant', 'Pea', 'Radish', 'Celery', 'Pumpkin', 'Zucchini', 'Lettuce', 'Artichoke', 'Cauliflower', 'Asparagus', 'Beetroot', 'Leek', 'Turnip', 'Parsley', 'Arugula', 'Okra', 'Kale', 'Sweet Potato', 'Bok Choy', 'Shallot'
  ],
  'Objects': [
    'Phone', 'Hammer', 'Pencil', 'Clock', 'Window', 'Door', 'Key', 'Bottle', 'Wallet', 'Lamp', 'Scissors', 'Knife', 'Spoon', 'Fork', 'Plate', 'Cup', 'Brush', 'Comb', 'Umbrella', 'Flashlight', 'Mirror', 'Backpack', 'Rope', 'Bucket', 'Flash Drive', 'Padlock', 'Corkscrew', 'Stapler Tool', 'Magnifying Glass', 'Compass Device'
  ],
  'Colors': [
    'Red', 'Blue', 'Green', 'Yellow', 'Purple', 'Orange Color', 'Pink', 'Brown', 'Black', 'White', 'Cyan', 'Magenta', 'Lime Color', 'Grey', 'Gold Color', 'Silver Color', 'Teal', 'Navy', 'Maroon', 'Olive Color', 'Turquoise', 'Indigo', 'Violet', 'Beige', 'Amber', 'Crimson', 'Emerald Color', 'Lavender', 'Charcoal Color', 'Bronze Color', 'Coral Color'
  ],
  'Jobs': [
    'Doctor', 'Teacher', 'Engineer', 'Artist', 'Cook', 'Nurse', 'Pilot', 'Worker', 'Farmer', 'Scientist', 'Police', 'Singer', 'Writer', 'Judge', 'Actor', 'Lawyer', 'Dentist', 'Driver', 'Mechanic', 'Plumber', 'Architect', 'Surgeon', 'Pharmacist', 'Baker', 'Butcher', 'Electrician', 'Carpenter', 'Accountant', 'Firefighter', 'Journalist', 'Veterinarian', 'Biologist', 'Chemist', 'Geologist', 'Curator', 'Diplomat'
  ],
  'Body Parts': [
    'Head', 'Hand', 'Foot', 'Eye', 'Nose', 'Ear', 'Mouth', 'Shoulder', 'Knee', 'Elbow', 'Finger', 'Back', 'Neck', 'Heart', 'Brain', 'Stomach', 'Leg', 'Arm', 'Tooth', 'Hair', 'Tongue', 'Ankle', 'Wrist', 'Thumb', 'Chest', 'Throat', 'Forehead', 'Spine', 'Rib', 'Jaw', 'Shin', 'Nostril', 'Eyelash'
  ],
  'Vehicles': [
    'Car', 'Bus', 'Train', 'Bicycle', 'Motorcycle', 'Airplane', 'Helicopter', 'Boat', 'Ship', 'Truck', 'Van', 'Subway', 'Scooter', 'Taxi', 'Ambulance', 'Tractor', 'Ferry', 'Yacht', 'Tram', 'Hot Air Balloon', 'Rocket', 'Sailboat', 'Cable Car', 'Monorail', 'Hovercraft', 'Bulldozer', 'Submarine Vessel'
  ],
  'Clothes': [
    'Shirt', 'Pants', 'Dress', 'Skirt', 'Jacket', 'Coat', 'Sweater', 'T-shirt', 'Shoes', 'Socks', 'Hat', 'Gloves', 'Scarf', 'Belt', 'Tie', 'Boots', 'Jeans', 'Raincoat', 'Pajamas', 'Vest', 'Suit', 'Sandals', 'Slippers', 'Hoodie', 'Cardigan', 'Bathrobe', 'Mittens', 'Overalls', 'Bowtie', 'Beret Hat'
  ],
  'Weather': [
    'Sun', 'Rain', 'Snow', 'Wind', 'Cloud', 'Storm', 'Thunder', 'Lightning', 'Fog', 'Ice', 'Breeze', 'Tornado', 'Hurricane', 'Frost', 'Hail', 'Rainbow', 'Drizzle', 'Blizzard', 'Heatwave', 'Humidity', 'Heatwave Days', 'Sunstroke', 'Cloudburst', 'Morning Dew', 'Solar Flare'
  ],
  'Furniture': [
    'Sofa', 'Bed', 'Desk', 'Cabinet', 'Bookshelf', 'Wardrobe', 'Couch', 'Stool', 'Armchair', 'Dresser', 'Nightstand', 'Bookcase', 'Coffee Table', 'Dining Table', 'Chandelier', 'Bunk Bed', 'Rocking Chair', 'Beanbag', 'Ottoman Stool', 'Sideboard'
  ],
  'Emotions': [
    'Happy', 'Sad', 'Angry', 'Scared', 'Surprised', 'Disgusted', 'Excited', 'Bored', 'Tired', 'Nervous', 'Proud', 'Confused', 'Calm', 'Jealous', 'Grateful', 'Curious', 'Lonely', 'Anxious', 'Hopeful', 'Relieved', 'Enthusiastic', 'Disappointed', 'Furious', 'Sympathetic', 'Optimistic', 'Pessimistic'
  ],
  'Sports': [
    'Football', 'Basketball', 'Tennis', 'Baseball', 'Volleyball', 'Golf', 'Swimming', 'Boxing', 'Cycling', 'Skiing', 'Running', 'Rugby', 'Hockey', 'Badminton', 'Archery', 'Karate', 'Gymnastics', 'Surfing', 'Rowing', 'Wrestling', 'Triathlon', 'Fencing Sport', 'Handball', 'Water Polo', 'Bobsleigh', 'Snowboarding'
  ],
  'Instruments': [
    'Piano', 'Guitar', 'Violin', 'Drums', 'Flute', 'Trumpet', 'Saxophone', 'Cello', 'Clarinet', 'Harp', 'Keyboard', 'Accordion', 'Trombone', 'Harmonica', 'Banjo', 'Ukulele', 'Bagpipes', 'Tambourine', 'Xylophone', 'Bassoon', 'Mandolin'
  ],
  'Kitchen Appliances': [
    'Refrigerator', 'Microwave', 'Toaster', 'Blender', 'Kettle', 'Dishwasher', 'Oven', 'Stove', 'Coffee Machine', 'Mixer', 'Waffle Maker', 'Food Processor', 'Air Fryer', 'Pressure Cooker', 'Slow Cooker', 'Juicer', 'Electric Kettle', 'Deep Fryer'
  ],
  'School Items': [
    'Notebook', 'Textbook', 'Eraser', 'Ruler', 'Sharpener', 'Highlighter', 'Stapler', 'Calculator', 'Compass Tool', 'Globe', 'Folder', 'Binder', 'Blackboard', 'Protractor', 'Pencil Sharpener', 'Correction Tape', 'Index Cards', 'Hall Pass', 'Geometry Set'
  ],
  'City Places': [
    'Airport', 'Museum', 'Library', 'Hospital', 'Hotel', 'Cinema', 'Bank', 'Pharmacy', 'Bakery', 'Supermarket', 'Stadium', 'Castle', 'Factory', 'Zoo', 'Park', 'Town Hall', 'Amusement Park', 'Post Office', 'Police Station', 'Fire Station', 'Courthouse'
  ],
  'Nature Features': [
    'Forest', 'Mountain', 'River', 'Desert', 'Valley', 'Volcano', 'Waterfall', 'Canyon', 'Glacier', 'Island', 'Jungle', 'Ocean', 'Cave', 'Lake', 'Swamp', 'Geyser', 'Tundra', 'Savanna', 'Coral Reef', 'Sand Dune', 'Hot Spring'
  ],
};

