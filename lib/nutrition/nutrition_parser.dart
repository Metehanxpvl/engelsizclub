import 'food_dictionary.dart';
import 'nutrition_types.dart';

export 'food_dictionary.dart' show nutritionFold, FoodDictionaryEntry, kFoodDictionary;

final _qtyRe = RegExp(
  r'(\d+(?:[.,]\d+)?)\s*(kg|gram|gr|mililitre|ml|litre|lt|yemek kasigi|tatli kasigi|cay kasigi|su bardagi|cay bardagi|adet|tane|dilim|kase|tabak|avuc|bardak|fincan|sise|kutu|porsiyon|g|l)?\s*(.*)$',
);

final _qtyPrefixRe = RegExp(
  r'^\d+(?:[.,]\d+)?\s*(kg|gram|gr|mililitre|ml|litre|lt|yemek kasigi|tatli kasigi|cay kasigi|su bardagi|cay bardagi|adet|tane|dilim|kase|tabak|avuc|bardak|fincan|sise|kutu|porsiyon|g|l)?\s*',
);

const _kTrNumbers = <String, String>{
  'bir': '1',
  'iki': '2',
  'uc': '3',
  'dort': '4',
  'bes': '5',
  'alti': '6',
  'yedi': '7',
  'sekiz': '8',
  'dokuz': '9',
  'on': '10',
};

class _QtyUnit {
  const _QtyUnit(this.qty, this.unit, this.rest);
  final double? qty;
  final String unit;
  final String rest;
}

String _stripFiller(String folded) {
  return folded
      .replaceAll(
        RegExp(
          r'\b(sabah|ogle|oglen|aksam|gece|kahvalti|ogun|bugun|dun|filtre|'
          r'yedim|yedi|yedik|yesin|ictim|icti|ictik|tukettim|aldim|'
          r'icin|sonra|ayrica|ile|olarak)\b',
        ),
        '',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _replaceTrNumbers(String folded) {
  var s = folded;
  for (final e in _kTrNumbers.entries) {
    s = s.replaceAll(RegExp('\\b${e.key}\\b'), e.value);
  }
  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _normUnit(String u) => u.replaceAll(' ', '');

_QtyUnit _splitQty(String folded) {
  final cleaned = _replaceTrNumbers(_stripFiller(folded));
  final m = _qtyRe.firstMatch(cleaned);
  if (m == null) return _QtyUnit(null, '', cleaned);
  final qty = double.tryParse((m[1] ?? '').replaceAll(',', '.'));
  final rest = (m[3] ?? '').trim();
  return _QtyUnit(qty, m[2] ?? '', rest.isEmpty ? cleaned : rest);
}

NutritionUnit _unitFrom(String u, {required bool liquid}) {
  switch (_normUnit(u)) {
    case 'kg':
    case 'gram':
    case 'gr':
    case 'g':
      return NutritionUnit.g;
    case 'mililitre':
    case 'ml':
    case 'litre':
    case 'lt':
    case 'l':
      return NutritionUnit.ml;
    default:
      if (u.isEmpty) return liquid ? NutritionUnit.ml : NutritionUnit.piece;
      return NutritionUnit.piece;
  }
}

double _gramsFor({
  required FoodDictionaryEntry food,
  required double qty,
  required String unitToken,
  required bool specified,
}) {
  final u = _normUnit(unitToken);
  switch (u) {
    case 'kg':
      return qty * 1000;
    case 'gram':
    case 'gr':
    case 'g':
      return qty;
    case 'litre':
    case 'lt':
    case 'l':
      return qty * 1000;
    case 'mililitre':
    case 'ml':
      return qty;
    case 'dilim':
      return qty *
          (food.category == FoodCategory.dairy || food.id == 'bread'
              ? food.pieceGrams
              : 25);
    case 'kase':
      return qty * (food.category == FoodCategory.soup ? 250 : food.defaultServingGrams);
    case 'tabak':
      return qty * food.defaultServingGrams;
    case 'avuc':
      return qty * (food.category == FoodCategory.nut ? 28 : 25);
    case 'bardak':
    case 'subardagi':
      return qty * (food.liquid ? 200 : food.defaultServingGrams);
    case 'caybardagi':
      return qty * (food.liquid ? 100 : food.defaultServingGrams);
    case 'fincan':
      return qty *
          (food.id == 'coffee' || food.id == 'tea' ? 180 : food.defaultServingGrams);
    case 'sise':
      return qty * (food.liquid ? 200 : food.defaultServingGrams);
    case 'kutu':
      return qty * (food.liquid ? 330 : food.defaultServingGrams);
    case 'porsiyon':
      return qty * food.defaultServingGrams;
    case 'yemekkasigi':
      return qty * (food.category == FoodCategory.oil ? 10 : 15);
    case 'tatlikasigi':
      return qty * (food.id == 'honey' || food.category == FoodCategory.oil ? 8 : 10);
    case 'caykasigi':
      return qty * 5;
    case 'adet':
    case 'tane':
      return qty * food.pieceGrams;
    case '':
      if (specified) return qty * food.pieceGrams;
      return food.defaultServingGrams;
    default:
      return qty * food.defaultServingGrams;
  }
}

int _levenshtein(String a, String b, {int max = 2}) {
  if (a == b) return 0;
  if ((a.length - b.length).abs() > max) return max + 1;
  final m = a.length;
  final n = b.length;
  var prev = List<int>.generate(n + 1, (i) => i);
  var curr = List<int>.filled(n + 1, 0);
  for (var i = 1; i <= m; i++) {
    curr[0] = i;
    var rowMin = curr[0];
    for (var j = 1; j <= n; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      curr[j] = [
        prev[j] + 1,
        curr[j - 1] + 1,
        prev[j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
      if (curr[j] < rowMin) rowMin = curr[j];
    }
    if (rowMin > max) return max + 1;
    final tmp = prev;
    prev = curr;
    curr = tmp;
  }
  return prev[n];
}

bool _aliasHits(String hay, String alias) {
  if (hay == alias) return true;
  if (alias.length <= 3) {
    return RegExp('(?:^|\\s)${RegExp.escape(alias)}(?:\\s|\$)').hasMatch(hay);
  }
  if (hay.contains(alias)) return true;
  return false;
}

FoodDictionaryEntry? matchFoodEntry(String foldedName) {
  final hay = _replaceTrNumbers(_stripFiller(foldedName.trim()));
  if (hay.isEmpty) return null;
  FoodDictionaryEntry? best;
  var bestLen = 0;
  for (final item in kFoodAliasIndex) {
    if (!_aliasHits(hay, item.folded)) continue;
    if (item.folded.length > bestLen) {
      best = item.entry;
      bestLen = item.folded.length;
    }
  }
  if (best != null) return best;
  return _fuzzyMatch(hay);
}

FoodDictionaryEntry? _fuzzyMatch(String hay) {
  final tokens = hay.split(RegExp(r'\s+')).where((e) => e.length >= 5);
  FoodDictionaryEntry? best;
  var bestDist = 3;
  var bestLen = 0;
  for (final token in tokens) {
    final maxDist = token.length >= 8 ? 2 : 1;
    for (final item in kFoodAliasIndex) {
      final aliasToken = item.folded.contains(' ')
          ? item.folded.split(' ').last
          : item.folded;
      if (aliasToken.length < 5) continue;
      if ((aliasToken.length - token.length).abs() > maxDist) continue;
      final d = _levenshtein(token, aliasToken, max: maxDist);
      if (d == 0 || d > maxDist) continue;
      if (d < bestDist || (d == bestDist && aliasToken.length > bestLen)) {
        best = item.entry;
        bestDist = d;
        bestLen = aliasToken.length;
      }
    }
  }
  return best;
}

/// Geriye dönük: katalog kaydı yerine sözlük girdisi.
FoodDictionaryEntry? matchFood(String foldedName) => matchFoodEntry(foldedName);

class NutritionParseResult {
  const NutritionParseResult({
    required this.foods,
    required this.unknown,
  });
  final List<ParsedFood> foods;
  final List<String> unknown;
}

List<String> _chunks(String input) {
  final normalized = input
      .replaceAll(RegExp(r'[;•·|/]'), ',')
      .replaceAll(RegExp(r'\s*\+\s*'), ',')
      .replaceAll(RegExp(r'\s+ve\s+', caseSensitive: false), ',')
      .replaceAll('\n', ',');
  return normalized
      .split(RegExp(r'[,;]+|\.\s+'))
      .map(nutritionFold)
      .where((e) => e.length >= 2)
      .toList();
}

String _leftoverAfterMatch(String text, FoodDictionaryEntry food) {
  var s = _replaceTrNumbers(_stripFiller(text));
  s = s.replaceFirst(_qtyPrefixRe, '');
  String? bestAlias;
  var bestLen = 0;
  for (final item in kFoodAliasIndex) {
    if (item.entry.id != food.id) continue;
    if (s.contains(item.folded) && item.folded.length >= bestLen) {
      bestAlias = item.folded;
      bestLen = item.folded.length;
    }
  }
  if (bestAlias != null) {
    s = s.replaceFirst(bestAlias, '');
  } else {
    final fuzzy = _fuzzyMatch(s);
    if (fuzzy != null && fuzzy.id == food.id) {
      final tokens = s.split(RegExp(r'\s+'));
      s = tokens.where((t) {
        final last = nutritionFold(food.canonicalName).split(' ').last;
        return _levenshtein(t, last, max: 2) > 2;
      }).join(' ');
    }
  }
  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}

bool _isNoise(String folded) {
  const noise = <String>{
    'tane',
    'ile',
    've',
    'vs',
    'falan',
    'kadar',
    'yaklasik',
    'porsiyon',
    'ogun',
    'yemek',
    'icecek',
    'yiyecek',
    'bugun',
    'sabah',
    'ogle',
    'aksam',
  };
  final parts = folded.split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
  if (parts.isEmpty) return true;
  return parts.every((w) => noise.contains(w) || w.length < 2 || _kTrNumbers.containsKey(w));
}

bool _scaleHouseholdForAge(String unitToken, bool specified) {
  if (!specified) return true;
  switch (_normUnit(unitToken)) {
    case 'kase':
    case 'tabak':
    case 'avuc':
    case 'bardak':
    case 'subardagi':
    case 'caybardagi':
    case 'fincan':
    case 'porsiyon':
    case 'sise':
    case 'kutu':
      return true;
    default:
      return false;
  }
}

NutritionParseResult parseNutritionInput(
  String raw, {
  NutritionUserProfile profile = const NutritionUserProfile(),
}) {
  final foods = <ParsedFood>[];
  final unknown = <String>[];
  final ageFactor = profile.ageBand.portionFactor;
  for (final chunk in _chunks(raw)) {
    var remaining = chunk;
    while (remaining.length >= 2) {
      if (_isNoise(remaining)) break;
      final split = _splitQty(remaining);
      final name = split.rest.isEmpty ? remaining : split.rest;
      final food = matchFoodEntry(name);
      if (food == null) {
        final leftover = _stripFiller(remaining);
        if (leftover.length >= 3 && !_isNoise(leftover)) {
          unknown.add(leftover);
        }
        break;
      }
      final specified = split.qty != null;
      final qty = split.qty ?? 1;
      var grams = _gramsFor(
        food: food,
        qty: qty,
        unitToken: split.unit,
        specified: specified,
      );
      if (ageFactor < 1 && _scaleHouseholdForAge(split.unit, specified)) {
        grams *= ageFactor;
      }
      foods.add(
        ParsedFood(
          foodId: food.id,
          labelTr: food.canonicalName,
          emoji: food.emoji,
          quantity: qty,
          unit: specified
              ? _unitFrom(split.unit, liquid: food.liquid)
              : NutritionUnit.unknown,
          grams: grams,
          portionSpecified: specified,
          raw: remaining,
        ),
      );
      final next = _leftoverAfterMatch(remaining, food);
      if (next == remaining) break;
      remaining = next;
    }
  }
  return NutritionParseResult(foods: foods, unknown: unknown);
}
