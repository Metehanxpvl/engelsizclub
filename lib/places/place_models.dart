/// Places API `places/ChIJ…` → `ChIJ…`
String? normalizeGooglePlaceId(String? raw) {
  var s = (raw ?? '').trim();
  if (s.isEmpty) return null;
  if (s.startsWith('places/')) s = s.substring(7);
  return s.isEmpty ? null : s;
}

/// Places (New) satırından `id` (yoksa resource `name`).
String? googlePlaceIdFromPlacesJson(Map<String, dynamic> place) {
  return normalizeGooglePlaceId(
    place['id']?.toString() ?? place['name']?.toString(),
  );
}

/// Katalog satırı için kararlı anahtar (Places id yoksa).
String catalogPlaceKey(int localId) => 'local:$localId';

const kAccessCriteria = <({String key, String label})>[
  (key: 'ramp', label: 'Rampa'),
  (key: 'elevator', label: 'Asansör'),
  (key: 'accessible_wc', label: 'Engelli WC'),
  (key: 'entrance', label: 'Giriş'),
  (key: 'parking', label: 'Otopark'),
];

const kAccessScale = <({int value, String label})>[
  (value: 0, label: 'Yok'),
  (value: 1, label: 'Kısmi'),
  (value: 2, label: 'Var'),
];

class PlaceReview {
  const PlaceReview({
    required this.id,
    required this.placeId,
    required this.userId,
    required this.criteria,
    required this.note,
  });

  final String id;
  final String placeId;
  final String userId;
  final Map<String, int> criteria;
  final String note;

  factory PlaceReview.fromJson(Map<String, dynamic> json) {
    final raw = json['criteria'];
    final map = <String, int>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v is num) map[k.toString()] = v.toInt();
      });
    }
    return PlaceReview(
      id: json['id']?.toString() ?? '',
      placeId: json['place_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      criteria: map,
      note: json['note']?.toString() ?? '',
    );
  }
}

class PlaceAccessSummary {
  const PlaceAccessSummary({required this.reviews});

  final List<PlaceReview> reviews;

  bool get isEmpty => reviews.isEmpty;

  int get count => reviews.length;

  /// 0–2 ortalama; yorum yoksa null.
  double? average(String key) {
    if (reviews.isEmpty) return null;
    var sum = 0;
    var n = 0;
    for (final r in reviews) {
      final v = r.criteria[key];
      if (v == null) continue;
      sum += v;
      n++;
    }
    if (n == 0) return null;
    return sum / n;
  }

  String labelFor(String key) {
    final avg = average(key);
    if (avg == null) return '—';
    if (avg < 0.67) return 'Yok';
    if (avg < 1.5) return 'Kısmi';
    return 'Var';
  }
}
