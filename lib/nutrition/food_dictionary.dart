/// Merkezi Türkçe gıda sözlüğü. Besin değerleri burada tutulmaz.
library;

enum FoodCategory {
  vegetable,
  fruit,
  nut,
  dairy,
  meat,
  egg,
  legume,
  grain,
  soup,
  dish,
  oil,
  snack,
  sweet,
  drink,
  other,
}

class FoodDictionaryEntry {
  const FoodDictionaryEntry({
    required this.id,
    required this.canonicalName,
    required this.category,
    required this.aliases,
    this.defaultServingGrams = 100,
    double? pieceGrams,
    this.emoji = '🍽️',
    this.liquid = false,
  }) : pieceGrams = pieceGrams ?? defaultServingGrams;

  final String id;
  final String canonicalName;
  final FoodCategory category;
  final List<String> aliases;
  final double defaultServingGrams;
  final double pieceGrams;
  final String emoji;
  final bool liquid;
}

FoodDictionaryEntry _e(
  String id,
  String name,
  FoodCategory cat,
  List<String> aliases, {
  double g = 100,
  double? piece,
  String emoji = '🍽️',
  bool liquid = false,
}) {
  return FoodDictionaryEntry(
    id: id,
    canonicalName: name,
    category: cat,
    aliases: aliases,
    defaultServingGrams: g,
    pieceGrams: piece,
    emoji: emoji,
    liquid: liquid,
  );
}

/// Module-level sözlük; her render'da yeniden oluşturulmaz.
final kFoodDictionary = List<FoodDictionaryEntry>.unmodifiable(<FoodDictionaryEntry>[
  // --- Mevcut katalog (id'ler korunur) ---
  _e('egg', 'Yumurta', FoodCategory.egg, [
    'yumurta', 'haslanmis yumurta', 'omlet', 'menemen', 'sahanda yumurta',
  ], g: 50, emoji: '🥚'),
  _e('white_cheese', 'Peynir', FoodCategory.dairy, [
    'peynir', 'beyaz peynir', 'lor', 'lor peyniri', 'kasar', 'kasar peyniri',
    'tulum peyniri', 'tulum',
  ], g: 25, emoji: '🧀'),
  _e('olive', 'Zeytin', FoodCategory.vegetable, [
    'zeytin', 'yesil zeytin', 'siyah zeytin',
  ], g: 20, piece: 4, emoji: '🫒'),
  _e('bread', 'Ekmek', FoodCategory.grain, [
    'ekmek', 'dilim ekmek', 'tam bugday ekmek', 'tam bugday ekmegi',
    'beyaz ekmek', 'cavdar ekmegi', 'kepekli ekmek',
  ], g: 30, emoji: '🍞'),
  _e('lentil_soup', 'Mercimek çorbası', FoodCategory.soup, [
    'mercimek corbasi', 'mercimek corba',
  ], g: 250, emoji: '🥣'),
  _e('salad', 'Salata', FoodCategory.vegetable, [
    'salata', 'yesil salata', 'mevsim salata', 'coban salata',
  ], g: 120, emoji: '🥗'),
  _e('chicken', 'Tavuk', FoodCategory.meat, [
    'tavuk', 'izgara tavuk', 'tavuk gogsu', 'tavuk eti', 'tavuk but',
  ], g: 150, emoji: '🍗'),
  _e('ayran', 'Ayran', FoodCategory.dairy, [
    'ayran', 'yogurt icecegi',
  ], g: 200, emoji: '🥛', liquid: true),
  _e('almond', 'Badem', FoodCategory.nut, [
    'badem', 'badem ici',
  ], g: 28, piece: 1.2, emoji: '🥜'),
  _e('banana', 'Muz', FoodCategory.fruit, ['muz'], g: 120, emoji: '🍌'),
  _e('milk', 'Süt', FoodCategory.dairy, [
    'sut', 'sut bardagi',
  ], g: 200, emoji: '🥛', liquid: true),
  _e('yogurt', 'Yoğurt', FoodCategory.dairy, [
    'yogurt', 'yogurd', 'suzme yogurt', 'süzme yogurt',
  ], g: 150, emoji: '🥛'),
  _e('rice', 'Pirinç', FoodCategory.grain, [
    'pirinc', 'pilav',
  ], g: 150, emoji: '🍚'),
  _e('tomato', 'Domates', FoodCategory.vegetable, ['domates'], g: 80, emoji: '🍅'),
  _e('spinach', 'İspanak', FoodCategory.vegetable, ['ispanak'], g: 80, emoji: '🥬'),
  _e('broccoli', 'Brokoli', FoodCategory.vegetable, [
    'brokoli', 'broccoli', 'brocoli', 'haslanmis brokoli', 'buharda brokoli',
  ], g: 100, emoji: '🥦'),
  _e('orange', 'Portakal', FoodCategory.fruit, ['portakal'], g: 130, emoji: '🍊'),
  _e('apple', 'Elma', FoodCategory.fruit, ['elma'], g: 150, emoji: '🍎'),
  _e('red_meat', 'Kırmızı et', FoodCategory.meat, [
    'kirmizi et', 'et', 'dana', 'dana eti', 'dana kiyma', 'kiyma',
    'kusbasi', 'biftek', 'kofte',
  ], g: 120, emoji: '🥩'),
  _e('fish', 'Balık', FoodCategory.meat, [
    'balik', 'somon', 'uskumru', 'hamsi', 'ton baligi', 'sardalya',
    'levrek', 'cipura',
  ], g: 120, emoji: '🐟'),
  _e('chickpea', 'Nohut', FoodCategory.legume, [
    'nohut', 'humus', 'nohut yemegi',
  ], g: 100, emoji: '🫘'),
  _e('olive_oil', 'Zeytinyağı', FoodCategory.oil, [
    'zeytinyagi', 'zeytin yagi',
  ], g: 10, emoji: '🫒'),
  _e('walnut', 'Ceviz', FoodCategory.nut, [
    'ceviz', 'ceviz ici',
  ], g: 28, piece: 4, emoji: '🥜'),
  _e('hazelnut', 'Fındık', FoodCategory.nut, [
    'findik', 'findiklar', 'findik ici', 'kavrulmus findik', 'cig findik',
  ], g: 28, piece: 1.4, emoji: '🌰'),
  _e('cucumber', 'Salatalık', FoodCategory.vegetable, ['salatalik'], g: 80, emoji: '🥒'),
  _e('potato', 'Patates', FoodCategory.vegetable, [
    'patates', 'haslanmis patates',
  ], g: 150, emoji: '🥔'),
  _e('sucuk', 'Sucuk', FoodCategory.meat, [
    'sucuk', 'sosis', 'fermente sucuk',
  ], g: 40, emoji: '🌭'),
  _e('mineral_water', 'Maden suyu', FoodCategory.drink, [
    'maden suyu', 'madensuyu', 'soda', 'maden soda', 'mineralli su', 'sade soda',
  ], g: 200, emoji: '💧', liquid: true),
  _e('soda_drink', 'Gazlı içecek', FoodCategory.drink, [
    'gazoz', 'kola', 'fanta', 'sprite',
  ], g: 330, emoji: '🥤', liquid: true),
  _e('coffee', 'Kahve', FoodCategory.drink, [
    'kahve', 'filtre kahve', 'turk kahvesi', 'turk kahve', 'espresso',
  ], g: 180, emoji: '☕', liquid: true),
  _e('tea', 'Çay', FoodCategory.drink, [
    'cay', 'siyah cay', 'cay bardagi', 'bitki cayi',
  ], g: 200, emoji: '🍵', liquid: true),
  _e('vegetables', 'Sebze', FoodCategory.vegetable, [
    'sebze', 'sebzeler', 'haslanmis sebze', 'sebze yemegi', 'mezeler',
  ], g: 150, emoji: '🥦'),

  // --- Sebzeler ---
  _e('cauliflower', 'Karnabahar', FoodCategory.vegetable, ['karnabahar'], g: 120, emoji: '🥦'),
  _e('chard', 'Pazı', FoodCategory.vegetable, ['pazi'], g: 80, emoji: '🥬'),
  _e('lettuce', 'Marul', FoodCategory.vegetable, ['marul'], g: 80, emoji: '🥬'),
  _e('arugula', 'Roka', FoodCategory.vegetable, ['roka'], g: 40, emoji: '🥬'),
  _e('parsley', 'Maydanoz', FoodCategory.vegetable, ['maydanoz'], g: 10, emoji: '🌿'),
  _e('dill', 'Dereotu', FoodCategory.vegetable, ['dereotu', 'dere otu'], g: 8, emoji: '🌿'),
  _e('cress', 'Tere', FoodCategory.vegetable, ['tere'], g: 20, emoji: '🌿'),
  _e('cabbage', 'Lahana', FoodCategory.vegetable, ['lahana'], g: 100, emoji: '🥬'),
  _e('red_cabbage', 'Kırmızı lahana', FoodCategory.vegetable, ['kirmizi lahana'], g: 100, emoji: '🥬'),
  _e('brussels_sprout', 'Brüksel lahanası', FoodCategory.vegetable, [
    'bruksel lahanasi', 'bruksel lahana',
  ], g: 80, emoji: '🥬'),
  _e('carrot', 'Havuç', FoodCategory.vegetable, ['havuc'], g: 80, emoji: '🥕'),
  _e('zucchini', 'Kabak', FoodCategory.vegetable, ['kabak'], g: 120, emoji: '🥒'),
  _e('eggplant', 'Patlıcan', FoodCategory.vegetable, ['patlican'], g: 150, emoji: '🍆'),
  _e('pepper', 'Biber', FoodCategory.vegetable, [
    'biber', 'kapya biber', 'sivri biber', 'yesil biber', 'kirmizi biber',
  ], g: 80, emoji: '🫑'),
  _e('onion', 'Soğan', FoodCategory.vegetable, ['sogan'], g: 80, emoji: '🧅'),
  _e('garlic', 'Sarımsak', FoodCategory.vegetable, ['sarimsak'], g: 5, emoji: '🧄'),
  _e('leek', 'Pırasa', FoodCategory.vegetable, ['pirasa'], g: 100, emoji: '🥬'),
  _e('celery', 'Kereviz', FoodCategory.vegetable, ['kereviz'], g: 80, emoji: '🥬'),
  _e('peas', 'Bezelye', FoodCategory.legume, ['bezelye'], g: 80, emoji: '🟢'),
  _e('corn', 'Mısır', FoodCategory.vegetable, ['misir'], g: 80, emoji: '🌽'),
  _e('green_beans', 'Taze fasulye', FoodCategory.vegetable, ['taze fasulye'], g: 120, emoji: '🟢'),
  _e('artichoke', 'Enginar', FoodCategory.vegetable, ['enginar'], g: 120, emoji: '🥬'),
  _e('asparagus', 'Kuşkonmaz', FoodCategory.vegetable, ['kuskonmaz'], g: 80, emoji: '🥬'),
  _e('beet', 'Pancar', FoodCategory.vegetable, ['pancar'], g: 80, emoji: '🟣'),
  _e('radish', 'Turp', FoodCategory.vegetable, ['turp'], g: 40, emoji: '🔴'),
  _e('mushroom', 'Mantar', FoodCategory.vegetable, ['mantar'], g: 80, emoji: '🍄'),
  _e('sweet_potato', 'Tatlı patates', FoodCategory.vegetable, ['tatli patates'], g: 150, emoji: '🍠'),

  // --- Meyveler ---
  _e('pear', 'Armut', FoodCategory.fruit, ['armut'], g: 150, emoji: '🍐'),
  _e('mandarin', 'Mandalina', FoodCategory.fruit, ['mandalina'], g: 80, emoji: '🍊'),
  _e('grapefruit', 'Greyfurt', FoodCategory.fruit, ['greyfurt'], g: 150, emoji: '🍊'),
  _e('lemon', 'Limon', FoodCategory.fruit, ['limon'], g: 60, emoji: '🍋'),
  _e('strawberry', 'Çilek', FoodCategory.fruit, ['cilek'], g: 100, emoji: '🍓'),
  _e('blueberry', 'Yaban mersini', FoodCategory.fruit, ['yaban mersini'], g: 80, emoji: '🫐'),
  _e('blackberry', 'Böğürtlen', FoodCategory.fruit, ['bogurtlen'], g: 80, emoji: '🫐'),
  _e('raspberry', 'Ahududu', FoodCategory.fruit, ['ahududu'], g: 80, emoji: '🫐'),
  _e('cherry', 'Kiraz', FoodCategory.fruit, ['kiraz'], g: 80, emoji: '🍒'),
  _e('sour_cherry', 'Vişne', FoodCategory.fruit, ['visne'], g: 80, emoji: '🍒'),
  _e('peach', 'Şeftali', FoodCategory.fruit, ['seftali'], g: 130, emoji: '🍑'),
  _e('nectarine', 'Nektarin', FoodCategory.fruit, ['nektarin'], g: 130, emoji: '🍑'),
  _e('apricot', 'Kayısı', FoodCategory.fruit, ['kayisi'], g: 80, emoji: '🟠'),
  _e('plum', 'Erik', FoodCategory.fruit, ['erik'], g: 80, emoji: '🟣'),
  _e('grape', 'Üzüm', FoodCategory.fruit, ['uzum'], g: 100, emoji: '🍇'),
  _e('watermelon', 'Karpuz', FoodCategory.fruit, ['karpuz'], g: 200, emoji: '🍉'),
  _e('melon', 'Kavun', FoodCategory.fruit, ['kavun'], g: 200, emoji: '🍈'),
  _e('pomegranate', 'Nar', FoodCategory.fruit, ['nar'], g: 100, emoji: '🔴'),
  _e('kiwi', 'Kivi', FoodCategory.fruit, ['kivi'], g: 80, emoji: '🥝'),
  _e('pineapple', 'Ananas', FoodCategory.fruit, ['ananas'], g: 120, emoji: '🍍'),
  _e('mango', 'Mango', FoodCategory.fruit, ['mango'], g: 150, emoji: '🥭'),
  _e('avocado', 'Avokado', FoodCategory.fruit, ['avokado'], g: 100, emoji: '🥑'),
  _e('fig', 'İncir', FoodCategory.fruit, ['incir'], g: 50, emoji: '🟣'),
  _e('date', 'Hurma', FoodCategory.fruit, ['hurma'], g: 20, emoji: '🟤'),
  _e('raisins', 'Kuru üzüm', FoodCategory.fruit, ['kuru uzum'], g: 30, emoji: '🍇'),
  _e('dried_apricot', 'Kuru kayısı', FoodCategory.fruit, ['kuru kayisi'], g: 30, emoji: '🟠'),

  // --- Kuruyemiş ---
  _e('cashew', 'Kaju', FoodCategory.nut, ['kaju'], g: 28, piece: 1.6, emoji: '🥜'),
  _e('pistachio', 'Antep fıstığı', FoodCategory.nut, [
    'antep fistigi', 'antep fistik',
  ], g: 28, piece: 1.2, emoji: '🥜'),
  _e('peanut', 'Yer fıstığı', FoodCategory.nut, [
    'yer fistigi', 'yerfistigi',
  ], g: 28, piece: 1, emoji: '🥜'),
  _e('pine_nut', 'Çam fıstığı', FoodCategory.nut, ['cam fistigi'], g: 15, emoji: '🥜'),
  _e('pumpkin_seed', 'Kabak çekirdeği', FoodCategory.nut, [
    'kabak cekirdegi',
  ], g: 20, emoji: '🌱'),
  _e('sunflower_seed', 'Ay çekirdeği', FoodCategory.nut, [
    'ay cekirdegi', 'aycekirdegi',
  ], g: 20, emoji: '🌻'),
  _e('sesame', 'Susam', FoodCategory.nut, ['susam'], g: 10, emoji: '⚪'),
  _e('chia', 'Chia', FoodCategory.nut, ['chia', 'chia tohumu'], g: 15, emoji: '⚫'),
  _e('flax', 'Keten tohumu', FoodCategory.nut, ['keten tohumu'], g: 15, emoji: '🟤'),

  // --- Süt ---
  _e('kefir', 'Kefir', FoodCategory.dairy, ['kefir'], g: 200, emoji: '🥛', liquid: true),
  _e('labneh', 'Labne', FoodCategory.dairy, ['labne'], g: 30, emoji: '🧀'),
  _e('mozzarella', 'Mozzarella', FoodCategory.dairy, ['mozzarella'], g: 30, emoji: '🧀'),

  // --- Et ---
  _e('turkey', 'Hindi', FoodCategory.meat, ['hindi'], g: 150, emoji: '🦃'),
  _e('shrimp', 'Karides', FoodCategory.meat, ['karides'], g: 80, emoji: '🦐'),

  // --- Baklagiller ---
  _e('lentils', 'Mercimek', FoodCategory.legume, ['mercimek'], g: 100, emoji: '🫘'),
  _e('red_lentil', 'Kırmızı mercimek', FoodCategory.legume, ['kirmizi mercimek'], g: 100, emoji: '🫘'),
  _e('green_lentil', 'Yeşil mercimek', FoodCategory.legume, ['yesil mercimek'], g: 100, emoji: '🫘'),
  _e('dried_beans', 'Kuru fasulye', FoodCategory.legume, [
    'kuru fasulye', 'fasulye',
  ], g: 150, emoji: '🫘'),
  _e('kidney_beans', 'Barbunya', FoodCategory.legume, ['barbunya'], g: 150, emoji: '🫘'),
  _e('black_eyed_pea', 'Börülce', FoodCategory.legume, ['borulce'], g: 120, emoji: '🫘'),
  _e('soy', 'Soya', FoodCategory.legume, ['soya', 'soya fasulyesi'], g: 100, emoji: '🫘'),

  // --- Tahıl ---
  _e('bulgur', 'Bulgur', FoodCategory.grain, [
    'bulgur', 'bulgur pilavi',
  ], g: 150, emoji: '🍚'),
  _e('oats', 'Yulaf', FoodCategory.grain, [
    'yulaf', 'yulaf ezmesi',
  ], g: 40, emoji: '🥣'),
  _e('wheat', 'Buğday', FoodCategory.grain, ['bugday'], g: 80, emoji: '🌾'),
  _e('lavash', 'Lavaş', FoodCategory.grain, ['lavas'], g: 50, emoji: '🫓'),
  _e('bazlama', 'Bazlama', FoodCategory.grain, ['bazlama'], g: 70, emoji: '🫓'),
  _e('simit', 'Simit', FoodCategory.grain, ['simit'], g: 80, emoji: '🥯'),
  _e('pasta', 'Makarna', FoodCategory.grain, [
    'makarna', 'tam bugday makarna', 'eriste',
  ], g: 150, emoji: '🍝'),
  _e('quinoa', 'Kinoa', FoodCategory.grain, ['kinoa'], g: 150, emoji: '🍚'),

  // --- Çorba / yemek ---
  _e('ezogelin_soup', 'Ezogelin çorbası', FoodCategory.soup, ['ezogelin corbasi', 'ezogelin'], g: 250, emoji: '🥣'),
  _e('tarhana_soup', 'Tarhana çorbası', FoodCategory.soup, ['tarhana corbasi', 'tarhana'], g: 250, emoji: '🥣'),
  _e('tomato_soup', 'Domates çorbası', FoodCategory.soup, ['domates corbasi'], g: 250, emoji: '🥣'),
  _e('vegetable_soup', 'Sebze çorbası', FoodCategory.soup, ['sebze corbasi'], g: 250, emoji: '🥣'),
  _e('chicken_soup', 'Tavuk çorbası', FoodCategory.soup, ['tavuk corbasi'], g: 250, emoji: '🥣'),
  _e('yayla_soup', 'Yayla çorbası', FoodCategory.soup, ['yayla corbasi'], g: 250, emoji: '🥣'),
  _e('turlu', 'Türlü', FoodCategory.dish, ['turlu'], g: 200, emoji: '🍲'),
  _e('olive_oil_beans', 'Zeytinyağlı fasulye', FoodCategory.dish, ['zeytinyagli fasulye'], g: 180, emoji: '🍲'),
  _e('imam_bayildi', 'İmam bayıldı', FoodCategory.dish, ['imam bayildi'], g: 180, emoji: '🍆'),
  _e('dolma', 'Dolma', FoodCategory.dish, ['dolma'], g: 150, emoji: '🍃'),
  _e('sarma', 'Sarma', FoodCategory.dish, ['sarma'], g: 150, emoji: '🍃'),
  _e('manti', 'Mantı', FoodCategory.dish, ['manti'], g: 180, emoji: '🥟'),

  // --- Yağ ---
  _e('sunflower_oil', 'Ayçiçek yağı', FoodCategory.oil, ['aycicek yagi'], g: 10, emoji: '🌻'),
  _e('butter', 'Tereyağı', FoodCategory.oil, ['tereyagi'], g: 10, emoji: '🧈'),
  _e('margarine', 'Margarin', FoodCategory.oil, ['margarin'], g: 10, emoji: '🧈'),
  _e('coconut_oil', 'Hindistan cevizi yağı', FoodCategory.oil, [
    'hindistan cevizi yagi',
  ], g: 10, emoji: '🥥'),

  // --- Atıştırmalık ---
  _e('biscuit', 'Bisküvi', FoodCategory.snack, ['biskuvi'], g: 25, emoji: '🍪'),
  _e('cracker', 'Kraker', FoodCategory.snack, ['kraker'], g: 25, emoji: '🍘'),
  _e('chocolate', 'Çikolata', FoodCategory.snack, ['cikolata'], g: 30, emoji: '🍫'),
  _e('dark_chocolate', 'Bitter çikolata', FoodCategory.snack, ['bitter cikolata'], g: 30, emoji: '🍫'),
  _e('popcorn', 'Patlamış mısır', FoodCategory.snack, ['patlamis misir'], g: 30, emoji: '🍿'),
  _e('chips', 'Cips', FoodCategory.snack, ['cips'], g: 30, emoji: '🍟'),
  _e('granola', 'Granola', FoodCategory.snack, ['granola'], g: 40, emoji: '🥣'),

  // --- Tatlı ---
  _e('rice_pudding', 'Sütlaç', FoodCategory.sweet, ['sutlac'], g: 150, emoji: '🍮'),
  _e('yogurt_dessert', 'Yoğurtlu tatlı', FoodCategory.sweet, ['yogurtlu tatli'], g: 120, emoji: '🍮'),
  _e('baklava', 'Baklava', FoodCategory.sweet, ['baklava'], g: 40, emoji: '🍯'),
  _e('revani', 'Revani', FoodCategory.sweet, ['revani'], g: 80, emoji: '🍰'),
  _e('cake', 'Kek', FoodCategory.sweet, ['kek'], g: 80, emoji: '🍰'),
  _e('cookie', 'Kurabiye', FoodCategory.sweet, ['kurabiye'], g: 25, emoji: '🍪'),
  _e('ice_cream', 'Dondurma', FoodCategory.sweet, ['dondurma'], g: 80, emoji: '🍦'),
  _e('honey', 'Bal', FoodCategory.sweet, ['bal'], g: 20, piece: 8, emoji: '🍯'),
]);

final kFoodDictionaryById = Map<String, FoodDictionaryEntry>.unmodifiable({
  for (final e in kFoodDictionary) e.id: e,
});

class IndexedFoodAlias {
  const IndexedFoodAlias(this.folded, this.entry);
  final String folded;
  final FoodDictionaryEntry entry;
}

String nutritionFold(String raw) {
  const tr = <String, String>{
    'ç': 'c',
    'Ç': 'c',
    'ğ': 'g',
    'Ğ': 'g',
    'ı': 'i',
    'I': 'i',
    'İ': 'i',
    'ö': 'o',
    'Ö': 'o',
    'ş': 's',
    'Ş': 's',
    'ü': 'u',
    'Ü': 'u',
  };
  final buf = StringBuffer();
  for (final rune in raw.trim().runes) {
    final ch = String.fromCharCode(rune);
    buf.write(tr[ch] ?? ch.toLowerCase());
  }
  return buf.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// En uzun alias önce; eşleştirme her yazımda sözlük üretmez.
final kFoodAliasIndex = () {
  final seen = <String>{};
  final list = <IndexedFoodAlias>[];
  for (final e in kFoodDictionary) {
    final names = <String>{e.canonicalName, ...e.aliases};
    for (final name in names) {
      final folded = nutritionFold(name);
      if (folded.isEmpty) continue;
      final key = '${e.id}|$folded';
      if (!seen.add(key)) continue;
      list.add(IndexedFoodAlias(folded, e));
    }
  }
  list.sort((a, b) => b.folded.length.compareTo(a.folded.length));
  return List<IndexedFoodAlias>.unmodifiable(list);
}();
