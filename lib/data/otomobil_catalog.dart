import 'dart:convert';

/// Sahibinden tarzı araç ilanı — `ilanlar.kind` yine `ikinciel`, kategori `Otomobil`.
const kOtomobilYakitlar = <String>[
  'Benzin',
  'Dizel',
  'LPG',
  'Benzin & LPG',
  'Hibrit',
  'Elektrik',
];

const kOtomobilVitesler = <String>[
  'Manuel',
  'Otomatik',
  'Yarı Otomatik',
];

const kOtomobilKasalar = <String>[
  'Sedan',
  'Hatchback',
  'Station Wagon',
  'SUV',
  'Crossover',
  'Coupe',
  'Cabrio',
  'MPV',
  'Pickup',
  'Minivan',
  'Ticari',
];

const kOtomobilRenkler = <String>[
  'Beyaz',
  'Siyah',
  'Gri',
  'Gümüş',
  'Kırmızı',
  'Mavi',
  'Lacivert',
  'Yeşil',
  'Kahverengi',
  'Bej',
  'Turuncu',
  'Sarı',
  'Bordo',
  'Diğer',
];

const kOtomobilCekis = <String>[
  'Önden çekiş',
  'Arkadan itiş',
  '4WD / AWD',
];

const kOtomobilKimden = <String>['Sahibinden', 'Galeriden'];

const kOtomobilIlanTipleri = <String>['Satılık', 'Kiralık'];

const kOtomobilMotorHacimleri = <String>[
  '1.0',
  '1.2',
  '1.3',
  '1.4',
  '1.5',
  '1.6',
  '1.8',
  '2.0',
  '2.2',
  '2.5',
  '3.0',
  'Elektrik',
  'Belirtilmedi',
];

const kOtomobilDigerModel = 'Diğer';

/// Türkiye pazarı (sahibinden) marka → modeller. Her listede sonda [kOtomobilDigerModel] eklenir.
const kOtomobilMarkaModeller = <String, List<String>>{
  'Alfa Romeo': [
    '146', '147', '156', '159', '166', '4C', 'Giulia', 'Giulietta',
    'GT', 'MiTo', 'Stelvio', 'Tonale',
  ],
  'Audi': [
    'A1', 'A3', 'A4', 'A5', 'A6', 'A7', 'A8', 'e-tron', 'e-tron GT',
    'Q2', 'Q3', 'Q4 e-tron', 'Q5', 'Q7', 'Q8', 'R8', 'TT',
  ],
  'BMW': [
    '1 Serisi', '2 Serisi', '3 Serisi', '4 Serisi', '5 Serisi', '6 Serisi',
    '7 Serisi', '8 Serisi', 'i3', 'i4', 'i5', 'i7', 'i8', 'iX', 'iX1', 'iX3',
    'X1', 'X2', 'X3', 'X4', 'X5', 'X6', 'X7', 'Z4',
  ],
  'BYD': ['Atto 3', 'Dolphin', 'Han', 'Seal', 'Seal U', 'Tang'],
  'Chery': [
    'Alia', 'Chance', 'Omoda 5', 'Tiggo', 'Tiggo 2', 'Tiggo 7 Pro',
    'Tiggo 8 Pro',
  ],
  'Chevrolet': [
    'Aveo', 'Camaro', 'Captiva', 'Cruze', 'Epica', 'Kalos', 'Lacetti',
    'Orlando', 'Spark', 'Trax',
  ],
  'Citroen': [
    'Ami', 'Berlingo', 'C-Elysee', 'C1', 'C2', 'C3', 'C3 Aircross',
    'C3 Picasso', 'C4', 'C4 Cactus', 'C4 Picasso', 'C4 X', 'C4X',
    'C5', 'C5 Aircross', 'C5 X', 'C6', 'C8', 'Grand C4 Picasso',
    'Jumper', 'Jumpy', 'Nemo', 'Saxo', 'Xsara', 'Xsara Picasso',
  ],
  'Cupra': ['Ateca', 'Born', 'Formentor', 'Leon', 'Tavascan'],
  'Dacia': [
    'Bigster', 'Dokker', 'Duster', 'Jogger', 'Lodgy', 'Logan',
    'Sandero', 'Sandero Stepway', 'Solenza', 'Spring',
  ],
  'DS': ['DS 3', 'DS 3 Crossback', 'DS 4', 'DS 5', 'DS 7', 'DS 9'],
  'Fiat': [
    '124 Spider', '500', '500L', '500X', 'Albea', 'Doblo', 'Egea',
    'Egea Cross', 'Fiorino', 'Fullback', 'Linea', 'Palio', 'Panda',
    'Punto', 'Qubo', 'Tipo',
  ],
  'Ford': [
    'B-Max', 'C-Max', 'Connect', 'Courier', 'Custom', 'EcoSport',
    'Edge', 'Fiesta', 'Focus', 'Fusion', 'Galaxy', 'Ka', 'Kuga',
    'Mondeo', 'Mustang', 'Puma', 'Ranger', 'S-Max', 'Tourneo',
    'Transit',
  ],
  'Honda': [
    'Accord', 'City', 'Civic', 'CR-V', 'CR-Z', 'e:Ny1', 'HR-V',
    'Jazz', 'Legend',
  ],
  'Hyundai': [
    'Accent', 'Accent Blue', 'Accent Era', 'Bayon', 'Elantra', 'Getz',
    'i10', 'i20', 'i20 Active', 'i30', 'i40', 'Ioniq', 'Ioniq 5',
    'Ioniq 6', 'ix20', 'ix35', 'Kona', 'Santa Fe', 'Tucson',
  ],
  'Isuzu': ['D-Max', 'NPR', 'NQR'],
  'Jeep': [
    'Avenger', 'Cherokee', 'Compass', 'Grand Cherokee', 'Patriot',
    'Renegade', 'Wrangler',
  ],
  'KGM': ['Actyon', 'Korando', 'Musso', 'Rexton', 'Tivoli', 'Torres'],
  'Kia': [
    'Ceed', 'Cerato', 'EV6', 'EV9', 'Niro', 'Picanto', 'Pride', 'ProCeed',
    'Rio', 'Sorento', 'Soul', 'Sportage', 'Stonic', 'XCeed',
  ],
  'Land Rover': [
    'Defender', 'Discovery', 'Discovery Sport', 'Freelander',
    'Range Rover', 'Range Rover Evoque', 'Range Rover Sport',
    'Range Rover Velar',
  ],
  'Lexus': ['CT', 'ES', 'IS', 'LS', 'NX', 'RX', 'UX'],
  'Mazda': [
    '2', '3', '6', 'CX-3', 'CX-30', 'CX-5', 'CX-60', 'CX-7', 'CX-9', 'MX-5',
  ],
  'Mercedes-Benz': [
    'A Serisi', 'B Serisi', 'C Serisi', 'CLA', 'CLE', 'CLK', 'CLS',
    'E Serisi', 'EQA', 'EQB', 'EQC', 'EQE', 'EQS', 'G Serisi', 'GLA',
    'GLB', 'GLC', 'GLE', 'GLK', 'GLS', 'ML', 'S Serisi', 'SL', 'SLC',
    'SLK', 'Sprinter', 'Vito', 'Vito Tourer',
  ],
  'MG': ['4', '5', 'HS', 'Marvel R', 'ZS', 'ZS EV'],
  'Mini': ['Cabrio', 'Clubman', 'Cooper', 'Countryman', 'Paceman'],
  'Mitsubishi': [
    'ASX', 'Attrage', 'Colt', 'Eclipse Cross', 'L200', 'Lancer',
    'Outlander', 'Pajero', 'Space Star',
  ],
  'Nissan': [
    'Almera', 'Ariya', 'Juke', 'Micra', 'Navara', 'Note', 'NV200',
    'Primera', 'Qashqai', 'Qashqai+2', 'X-Trail',
  ],
  'Opel': [
    'Adam', 'Astra', 'Combo', 'Corsa', 'Crossland', 'Frontera',
    'Grandland', 'Insignia', 'Meriva', 'Mokka', 'Mokka X', 'Vectra',
    'Zafira',
  ],
  'Peugeot': [
    '107', '108', '2008', '206', '207', '208', '3008', '301', '307',
    '308', '407', '408', '5008', '508', 'Boxer', 'Expert', 'Partner',
    'Rifter', 'Traveller',
  ],
  'Porsche': [
    '718', '911', 'Boxster', 'Cayenne', 'Cayman', 'Macan', 'Panamera',
    'Taycan',
  ],
  'Renault': [
    'Austral', 'Captur', 'Clio', 'Clio Symbol', 'Espace', 'Fluence',
    'Kadjar', 'Kangoo', 'Koleos', 'Laguna', 'Latitude', 'Master',
    'Megane', 'Megane E-Tech', 'Megane Sedan', 'Modus', 'Rafale',
    'Scenic', 'Symbol', 'Taliant', 'Talisman', 'Trafic', 'Twingo', 'Zoe',
  ],
  'Seat': [
    'Alhambra', 'Arona', 'Ateca', 'Cordoba', 'Ibiza', 'Leon', 'Tarraco',
    'Toledo',
  ],
  'Skoda': [
    'Citigo', 'Enyaq', 'Fabia', 'Favorit', 'Felicia', 'Kamiq', 'Karoq',
    'Kodiaq', 'Octavia', 'Rapid', 'Roomster', 'Scala', 'Superb', 'Yeti',
  ],
  'SsangYong': [
    'Actyon', 'Korando', 'Kyron', 'Musso', 'Rexton', 'Tivoli', 'XLV',
  ],
  'Subaru': ['BRZ', 'Forester', 'Impreza', 'Legacy', 'Outback', 'XV'],
  'Suzuki': [
    'Alto', 'Baleno', 'Grand Vitara', 'Ignis', 'Jimny', 'S-Cross',
    'Splash', 'Swift', 'SX4', 'Vitara',
  ],
  'Tesla': ['Cybertruck', 'Model 3', 'Model S', 'Model X', 'Model Y'],
  'Togg': ['T10F', 'T10X'],
  'Toyota': [
    'Auris', 'Avensis', 'Aygo', 'C-HR', 'Camry', 'Corolla',
    'Corolla Cross', 'Corolla Verso', 'Hilux', 'Land Cruiser',
    'Proace', 'Proace City', 'RAV4', 'Yaris', 'Yaris Cross',
  ],
  'Volkswagen': [
    'Amarok', 'Arteon', 'Bora', 'Caddy', 'Caravelle', 'Crafter', 'Golf',
    'Golf Plus', 'ID.3', 'ID.4', 'ID.5', 'ID.7', 'ID.Buzz', 'Jetta',
    'Passat', 'Passat Variant', 'Polo', 'Scirocco', 'Sharan', 'T-Cross',
    'T-Roc', 'Taigo', 'Tiguan', 'Tiguan Allspace', 'Touareg', 'Touran',
    'Transporter', 'Up',
  ],
  'Volvo': [
    'C30', 'C40', 'EX30', 'EX90', 'S40', 'S60', 'S80', 'S90', 'V40',
    'V50', 'V60', 'V90', 'XC40', 'XC60', 'XC70', 'XC90',
  ],
  'Diğer': const [kOtomobilDigerModel],
};

List<String> get kOtomobilMarkalar => kOtomobilMarkaModeller.keys.toList();

List<String> otomobilModellerOf(String marka) {
  final list = List<String>.from(
    kOtomobilMarkaModeller[marka] ?? const <String>[],
  );
  if (!list.contains(kOtomobilDigerModel)) list.add(kOtomobilDigerModel);
  return list;
}

/// Listede yoksa "Diğer" seçili kabul edilir (serbest model yazımı).
String otomobilModelSelectValue(String marka, String model) {
  final models = otomobilModellerOf(marka);
  if (models.contains(model) && model != kOtomobilDigerModel) return model;
  if (model.trim().isEmpty) return models.first;
  return kOtomobilDigerModel;
}

bool otomobilModelNeedsCustom(String marka, String model) {
  return otomobilModelSelectValue(marka, model) == kOtomobilDigerModel;
}

List<String> otomobilYillar({int? nowYear}) {
  final y = nowYear ?? DateTime.now().year;
  return [for (var i = y + 1; i >= 1985; i--) '$i'];
}

class OtomobilParca {
  const OtomobilParca(this.id, this.label);
  final String id;
  final String label;
}

const kOtomobilParcalar = <OtomobilParca>[
  OtomobilParca('on_tampon', 'Ön Tampon'),
  OtomobilParca('kaput', 'Motor Kaputu'),
  OtomobilParca('sol_on_camurluk', 'Sol Ön Çamurluk'),
  OtomobilParca('sag_on_camurluk', 'Sağ Ön Çamurluk'),
  OtomobilParca('sol_on_kapi', 'Sol Ön Kapı'),
  OtomobilParca('sag_on_kapi', 'Sağ Ön Kapı'),
  OtomobilParca('sol_arka_kapi', 'Sol Arka Kapı'),
  OtomobilParca('sag_arka_kapi', 'Sağ Arka Kapı'),
  OtomobilParca('sol_arka_camurluk', 'Sol Arka Çamurluk'),
  OtomobilParca('sag_arka_camurluk', 'Sağ Arka Çamurluk'),
  OtomobilParca('bagaj', 'Bagaj Kapağı'),
  OtomobilParca('arka_tampon', 'Arka Tampon'),
  OtomobilParca('tavan', 'Tavan'),
];

const kOtomobilHasarLokal = 'lb';
const kOtomobilHasarBoya = 'b';
const kOtomobilHasarDegisen = 'd';

const kOtomobilHasarEtiket = <String, String>{
  kOtomobilHasarLokal: 'Lokal Boyalı',
  kOtomobilHasarBoya: 'Boyalı',
  kOtomobilHasarDegisen: 'Değişen',
};

const kOtomobilHasarKisa = <String, String>{
  kOtomobilHasarLokal: 'LB',
  kOtomobilHasarBoya: 'B',
  kOtomobilHasarDegisen: 'D',
};

String? otomobilParcaLabel(String id) {
  for (final p in kOtomobilParcalar) {
    if (p.id == id) return p.label;
  }
  return null;
}

/// Orijinal → lokal boyalı → boyalı → değişen → orijinal.
String otomobilHasarSonraki(String? current) {
  return switch (current) {
    kOtomobilHasarLokal => kOtomobilHasarBoya,
    kOtomobilHasarBoya => kOtomobilHasarDegisen,
    kOtomobilHasarDegisen => '',
    _ => kOtomobilHasarLokal,
  };
}

Map<String, String> otomobilHasarToggle(Map<String, String> current, String id) {
  final next = Map<String, String>.from(current);
  final s = otomobilHasarSonraki(next[id]);
  if (s.isEmpty) {
    next.remove(id);
  } else {
    next[id] = s;
  }
  return next;
}

Map<String, String> _parseHasar(dynamic raw) {
  if (raw is! Map) return const {};
  const ok = {kOtomobilHasarLokal, kOtomobilHasarBoya, kOtomobilHasarDegisen};
  final ids = {for (final p in kOtomobilParcalar) p.id};
  final out = <String, String>{};
  raw.forEach((k, v) {
    final id = k.toString();
    final st = v.toString();
    if (ids.contains(id) && ok.contains(st)) out[id] = st;
  });
  return out;
}

class OtomobilSpec {
  const OtomobilSpec({
    this.ilanTip = 'Satılık',
    this.marka = 'Renault',
    this.model = 'Clio',
    this.yil = '2020',
    this.km = '',
    this.yakit = 'Benzin',
    this.vites = 'Manuel',
    this.kasa = 'Hatchback',
    this.renk = 'Beyaz',
    this.cekis = 'Önden çekiş',
    this.kimden = 'Sahibinden',
    this.motor = '1.6',
    this.sifir = false,
    this.takas = false,
    this.hasar = const <String, String>{},
  });

  final String ilanTip;
  final String marka;
  final String model;
  final String yil;
  final String km;
  final String yakit;
  final String vites;
  final String kasa;
  final String renk;
  final String cekis;
  final String kimden;
  final String motor;
  final bool sifir;
  final bool takas;
  /// Parça id → lb / b / d. Boş = orijinal.
  final Map<String, String> hasar;

  List<(String, String)> get hasarSatirlari {
    final rows = <(String, String)>[];
    for (final p in kOtomobilParcalar) {
      final st = hasar[p.id];
      if (st == null) continue;
      final etiket = kOtomobilHasarEtiket[st];
      if (etiket == null) continue;
      rows.add((p.label, etiket));
    }
    return rows;
  }

  OtomobilSpec copyWith({
    String? ilanTip,
    String? marka,
    String? model,
    String? yil,
    String? km,
    String? yakit,
    String? vites,
    String? kasa,
    String? renk,
    String? cekis,
    String? kimden,
    String? motor,
    bool? sifir,
    bool? takas,
    Map<String, String>? hasar,
  }) {
    return OtomobilSpec(
      ilanTip: ilanTip ?? this.ilanTip,
      marka: marka ?? this.marka,
      model: model ?? this.model,
      yil: yil ?? this.yil,
      km: km ?? this.km,
      yakit: yakit ?? this.yakit,
      vites: vites ?? this.vites,
      kasa: kasa ?? this.kasa,
      renk: renk ?? this.renk,
      cekis: cekis ?? this.cekis,
      kimden: kimden ?? this.kimden,
      motor: motor ?? this.motor,
      sifir: sifir ?? this.sifir,
      takas: takas ?? this.takas,
      hasar: hasar ?? this.hasar,
    );
  }

  String get brandLine {
    final parts = <String>[
      if (marka.trim().isNotEmpty) marka.trim(),
      if (model.trim().isNotEmpty) model.trim(),
    ];
    return parts.isEmpty ? '—' : parts.join(' ');
  }

  String get autoTitle {
    final parts = <String>[
      if (marka.trim().isNotEmpty) marka.trim(),
      if (model.trim().isNotEmpty) model.trim(),
      if (yil.trim().isNotEmpty) yil.trim(),
    ];
    return parts.join(' ');
  }

  List<(String, String)> get detailRows {
    String kmLabel() {
      final n = int.tryParse(km.replaceAll(RegExp(r'[^0-9]'), ''));
      if (n == null) return km.trim();
      final s = n.toString();
      final buf = StringBuffer();
      for (var i = 0; i < s.length; i++) {
        final fromEnd = s.length - i;
        buf.write(s[i]);
        if (fromEnd > 1 && fromEnd % 3 == 1) buf.write('.');
      }
      return '${buf.toString()} km';
    }

    return [
      ('İlan tipi', ilanTip),
      ('Marka', marka),
      ('Model', model),
      ('Yıl', yil),
      if (km.trim().isNotEmpty) ('KM', kmLabel()),
      ('Yakıt', yakit),
      ('Vites', vites),
      ('Kasa', kasa),
      ('Renk', renk),
      ('Çekiş', cekis),
      ('Motor', motor),
      ('Kimden', kimden),
      ('Durum', sifir ? 'Sıfır' : 'İkinci El'),
      ('Takas', takas ? 'Evet' : 'Hayır'),
    ];
  }

  String get cardSubtitle {
    final bits = <String>[
      if (yil.trim().isNotEmpty) yil.trim(),
      if (km.trim().isNotEmpty)
        '${int.tryParse(km.replaceAll(RegExp(r'[^0-9]'), '')) ?? km} km',
      if (yakit.trim().isNotEmpty) yakit.trim(),
      if (vites.trim().isNotEmpty) vites.trim(),
    ];
    return bits.join(' · ');
  }

  Map<String, dynamic> toJson() => {
        'tip': ilanTip,
        'marka': marka,
        'model': model,
        'yil': yil,
        'km': km.replaceAll(RegExp(r'[^0-9]'), ''),
        'yakit': yakit,
        'vites': vites,
        'kasa': kasa,
        'renk': renk,
        'cekis': cekis,
        'kimden': kimden,
        'motor': motor,
        'sifir': sifir,
        'takas': takas,
        if (hasar.isNotEmpty) 'hasar': hasar,
      };

  factory OtomobilSpec.fromJson(Map<String, dynamic> j) {
    String s(String k, [String d = '']) => (j[k] ?? d).toString().trim();
    bool b(String k) => j[k] == true || j[k] == 'true' || j[k] == 1;
    final marka = s('marka', 'Renault');
    final models = otomobilModellerOf(
      kOtomobilMarkaModeller.containsKey(marka) ? marka : 'Diğer',
    );
    var model = s('model', models.first);
    if (model.isEmpty) model = models.first;
    return OtomobilSpec(
      ilanTip: kOtomobilIlanTipleri.contains(s('tip')) ? s('tip') : 'Satılık',
      marka: kOtomobilMarkaModeller.containsKey(marka) ? marka : 'Diğer',
      model: model,
      yil: s('yil', '2020'),
      km: s('km'),
      yakit: kOtomobilYakitlar.contains(s('yakit')) ? s('yakit') : 'Benzin',
      vites: kOtomobilVitesler.contains(s('vites')) ? s('vites') : 'Manuel',
      kasa: kOtomobilKasalar.contains(s('kasa')) ? s('kasa') : 'Sedan',
      renk: kOtomobilRenkler.contains(s('renk')) ? s('renk') : 'Beyaz',
      cekis: kOtomobilCekis.contains(s('cekis')) ? s('cekis') : 'Önden çekiş',
      kimden: kOtomobilKimden.contains(s('kimden')) ? s('kimden') : 'Sahibinden',
      motor: kOtomobilMotorHacimleri.contains(s('motor'))
          ? s('motor')
          : 'Belirtilmedi',
      sifir: b('sifir'),
      takas: b('takas'),
      hasar: _parseHasar(j['hasar']),
    );
  }
}

final _carBlockRe = RegExp(
  r'\[\[EC_CAR\]\](.*?)\[\[/EC_CAR\]\]',
  dotAll: true,
);

String encodeOtomobilNote(OtomobilSpec spec, String description) {
  final json = jsonEncode(spec.toJson());
  final desc = description.trim();
  final body = desc.isEmpty || desc == '—' ? '' : desc;
  return '[[EC_CAR]]$json[[/EC_CAR]]${body.isEmpty ? '' : '\n$body'}';
}

({OtomobilSpec? spec, String note}) splitOtomobilNote(String raw) {
  final m = _carBlockRe.firstMatch(raw);
  if (m == null) {
    return (spec: null, note: raw);
  }
  OtomobilSpec? spec;
  try {
    final decoded = jsonDecode(m.group(1) ?? '');
    if (decoded is Map) {
      spec = OtomobilSpec.fromJson(Map<String, dynamic>.from(decoded));
    }
  } catch (_) {}
  final note = raw.replaceFirst(_carBlockRe, '').trim();
  return (spec: spec, note: note);
}

String visibleIlanNote(String raw) {
  final split = splitOtomobilNote(raw);
  final n = split.note.trim();
  if (n.isEmpty || n == '—') return split.spec == null ? raw : '';
  return n;
}
