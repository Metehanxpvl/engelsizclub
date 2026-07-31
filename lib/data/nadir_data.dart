// Nadir hastalıklar — varsayılan içerik (Supabase `nadir_hastaliklar` ile güncellenir).

class NadirItem {
  const NadirItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.shortDesc,
    required this.definition,
    required this.effects,
    this.sortOrder = 0,
  });

  final String id;
  final String name;
  final String icon;
  /// Liste kartındaki kısa özet
  final String shortDesc;
  /// Tanım ve Gelişim
  final String definition;
  /// Etkileri
  final String effects;
  final int sortOrder;

  NadirItem copyWith({
    String? name,
    String? icon,
    String? shortDesc,
    String? definition,
    String? effects,
    int? sortOrder,
  }) =>
      NadirItem(
        id: id,
        name: name ?? this.name,
        icon: icon ?? this.icon,
        shortDesc: shortDesc ?? this.shortDesc,
        definition: definition ?? this.definition,
        effects: effects ?? this.effects,
        sortOrder: sortOrder ?? this.sortOrder,
      );
}

class NadirResource {
  const NadirResource(this.label, this.url);
  final String label;
  final String url;
}

const kNadirResources = <NadirResource>[
  NadirResource(
    'NORD — Nadir Hastalıklar Örgütü',
    'https://rarediseases.org',
  ),
  NadirResource(
    'Orphanet Türkiye',
    'https://www.orpha.net',
  ),
  NadirResource(
    'TÜBİTAK Nadir Hastalıklar Portalı / İlgili Programlar',
    'https://www.tubitak.gov.tr',
  ),
];

const kDefaultNadirItems = <NadirItem>[
  NadirItem(
    id: 'spina_bifida',
    name: 'Spina Bifida',
    icon: '🧠',
    shortDesc: 'Omurilik ve omurga gelişim bozukluğu.',
    definition:
        'Omurganın ve omuriliğin anne karnındaki gelişim sürecinde (gebeliğin ilk haftalarında) '
        'tam olarak kapanmaması sonucu ortaya çıkan konjenital (doğuştan) bir nöral tüp defektidir.',
    effects:
        'Omuriliğin dışarıya kesecik şeklinde çıkmasına veya açık kalmasına neden olabilir. '
        'Etkilenen bölgeye bağlı olarak bacaklarda kısmi veya tam felç, idrar ve dışkı kontrolü '
        'sorunları gibi fiziksel engellerle seyredebilir.',
    sortOrder: 0,
  ),
  NadirItem(
    id: 'rett',
    name: 'Rett Sendromu',
    icon: '🌸',
    shortDesc:
        'Ağırlıklı olarak kız çocuklarında görülen nörolojik gelişim bozukluğu.',
    definition:
        'Genellikle MECP2 genindeki mutasyonlardan kaynaklanan, nadir görülen ve ilerleyici '
        'nörogelişimsel bir bozukluktur. Ağırlıklı olarak kız çocuklarını etkiler.',
    effects:
        'Bebek ilk aylarında normal bir gelişim gösterdikten sonra; el becerilerini '
        '(amaçlı el hareketlerini) kaybeder, konuşma yeteneği geriler, yürüme bozuklukları '
        've karakteristik el ovuşturma/bükme hareketleri başlar.',
    sortOrder: 1,
  ),
  NadirItem(
    id: 'angelman',
    name: 'Angelman Sendromu',
    icon: '😊',
    shortDesc:
        'Mutluluk davranışı ve gelişim geriliğiyle karakterize genetik hastalık.',
    definition:
        '15 numaralı kromozomdaki genetik bir bozukluktan (genellikle anneden gelen kopyanın '
        'eksikliği veya işlevsizliği) kaynaklanan nörogelişimsel bir sendromdur.',
    effects:
        'Şiddetli zihinsel yetersizlik, konuşma yokluğu veya ciddi derecede kısıtlı konuşma, '
        'denge ve yürüme bozuklukları (ataksik/marazi yürüyüş) görülür. En belirgin '
        'özelliklerinden biri, sık gülme, neşeli görünüm, el çırpma gibi davranışlar ve '
        'aşırı heyecan halidir.',
    sortOrder: 2,
  ),
  NadirItem(
    id: 'prader_willi',
    name: 'Prader-Willi Sendromu',
    icon: '🧬',
    shortDesc:
        'Hipotoni, obezite eğilimi ve gelişim geriliğiyle seyreden genetik durum.',
    definition:
        '15 numaralı kromozomun babadan gelen kısmındaki bir eksiklikten kaynaklanan '
        'karmaşık bir genetik hastalıktır.',
    effects:
        'Bebeklik döneminde derin kas gevşekliği (hipotoni) ve beslenme güçlükleri ile başlar. '
        'Çocukluk dönemine geçişle birlikte doyum noktası olmama (sürekli açlık hissi - hiperfaji) '
        'durumu baş gösterir; bu da kontrol edilmezse aşırı obeziteye ve buna bağlı metabolik '
        'sorunlara yol açabilir.',
    sortOrder: 3,
  ),
  NadirItem(
    id: 'pku',
    name: 'PKU (Fenilketonüri)',
    icon: '🔴',
    shortDesc:
        'Fenilalanin metabolizmasındaki enzim eksikliğinden kaynaklanan metabolik hastalık.',
    definition:
        'Karaciğerde fenilalanin amino asidini parçalayan enzimin eksikliği veya çalışmaması '
        'nedeniyle ortaya çıkan kalıtsal bir metabolik hastalıktır.',
    effects:
        'Vücutta biriken fenilalanin ve türevleri beyin dokusuna zarar vererek tedavi edilmediği '
        'takdirde kalıcı zihinsel geriliğe yol açar. Doğan her bebeğe rutin olarak topuk kanı '
        'testi ile taranır ve ömür boyu düşük fenilalaninli diyetle kontrol altında tutulur.',
    sortOrder: 4,
  ),
  NadirItem(
    id: 'fragile_x',
    name: 'Fragile X (Kırılgan X Sendromu)',
    icon: '🔬',
    shortDesc:
        'En yaygın kalıtsal zihinsel engel nedeni olan genetik bozukluk.',
    definition:
        'X kromozomu üzerinde bulunan FMR1 genindeki mutasyon sonucu gelişen, en sık rastlanan '
        'kalıtsal zihinsel engel nedenlerinden biridir.',
    effects:
        'Öğrenme güçlükleri, dikkat eksikliği, hiperaktivite, sosyal kaygı ve otizm benzeri '
        'davranışsal özellikler görülebilir. Erkeklerde genellikle kızlara kıyasla daha ağır '
        'tablolara yol açar.',
    sortOrder: 5,
  ),
  NadirItem(
    id: 'tuberous',
    name: 'Tuberous Sclerosis (Tüberoskleroz)',
    icon: '🔵',
    shortDesc:
        'Beyin, cilt ve organlarda iyi huylu tümörlere yol açan genetik hastalık.',
    definition:
        'Vücudun farklı organlarında (özellikle beyin, böbrek, kalp, akciğer ve cilt) iyi huylu '
        'tümörlerin (hamartom) oluşmasına neden olan genetik bir hastalıktır.',
    effects:
        'Beyindeki lezyonlara bağlı olarak epilepsi (nöbetler), öğrenme güçlükleri veya otizm '
        'spektrum bozuklukları görülebilir. Ciltte karakteristik lekeler ve kabarıklıklar '
        'eşlik edebilir.',
    sortOrder: 6,
  ),
  NadirItem(
    id: 'dmd',
    name: 'Duchenne Müsküler Distrofi (DMD)',
    icon: '💪',
    shortDesc:
        'Kas gücünün ilerleyici kaybıyla seyreden genetik kas hastalığı.',
    definition:
        'Kasların yapısını koruyan distrofin proteininin eksikliğinden kaynaklanan, X kromozomuna '
        'bağlı geçiş gösteren ilerleyici bir genetik kas hastalığıdır. Genellikle erkek '
        'çocuklarında görülür.',
    effects:
        'Çocukluk çağında yürüme zorlukları, sık düşme ve merdiven çıkmada güçlükle başlar. '
        'Zamanla tüm iskelet kaslarını ve solunum/kalp kaslarını zayıflatarak hastanın '
        'tekerlekli sandalyeye bağımlı hale gelmesine yol açar.',
    sortOrder: 7,
  ),
  NadirItem(
    id: 'williams',
    name: 'Williams Sendromu',
    icon: '🎵',
    shortDesc:
        'Sosyal kişilik, müzikal yetenek ve kardiyovasküler sorunlarla karakterize durum.',
    definition:
        '7 numaralı kromozomun belirli bir bölgesindeki genlerin eksilmesi (mikrodelesyon) '
        'sonucu oluşan nadir bir genetik sendromdur.',
    effects:
        'Hastalar genellikle aşırı sosyal, dışa dönük, empatik ve müzik kulağı gelişmiş kişilik '
        'yapılarıyla bilinirler. Buna karşın yüz hatlarında belirgin özellikler (elf benzeri yüz), '
        'böbrek anomalileri ve ilerleyici kardiyovasküler (kalp-damar) sorunlar barındırabilir.',
    sortOrder: 8,
  ),
  NadirItem(
    id: 'cdkl5',
    name: 'CDKL5 Eksikliği',
    icon: '⚡',
    shortDesc:
        'Erken başlangıçlı nöbetler ve ciddi gelişimsel gecikmeye yol açan genetik bozukluk.',
    definition:
        'X kromozomu üzerindeki CDKL5 geninin mutasyonu veya eksikliğinden kaynaklanan, erken '
        'çocukluk döneminde ortaya çıkan ağır bir genetik nörolojik bozukluktur.',
    effects:
        'Yaşamın ilk aylarından itibaren başlayan, kontrol edilmesi zor ve dirençli epilepsi '
        'nöbetleri (erken başlangıçlı nöbetler), ağır motor ve zihinsel gelişim gerilikleri, '
        'konuşma yokluğu ve ellerde tekrarlayan stereotipik hareketlerle karakterizedir.',
    sortOrder: 9,
  ),
];
