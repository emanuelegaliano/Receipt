/// Suggerimento della categoria per una spesa.
///
/// 1. Regole imparate: se hai già salvato una spesa da questo esercente, si
///    riusa la categoria che avevi scelto (anche con piccole differenze di
///    OCR nel nome).
/// 2. Parole chiave: altrimenti si cercano le parole chiave delle categorie
///    nel nome dell'esercente (peso alto) e nel resto dello scontrino.
library;

class CategoryKeywords {
  final int id;
  final List<String> keywords;
  const CategoryKeywords(this.id, this.keywords);

  factory CategoryKeywords.parse(int id, String csv) => CategoryKeywords(
        id,
        [for (final k in csv.split(',')) if (k.trim().isNotEmpty) normalizeText(k)],
      );
}

enum SuggestionSource { learned, keyword, none }

class CategorySuggestion {
  final int? categoryId;
  final SuggestionSource source;
  final String? matched; // regola o parola chiave che ha deciso
  const CategorySuggestion(this.categoryId, this.source, [this.matched]);
}

/// Maiuscolo, senza accenti né punteggiatura, spazi compattati.
String normalizeText(String s) {
  var t = s.toUpperCase();
  const accents = {'À': 'A', 'Á': 'A', 'È': 'E', 'É': 'E', 'Ì': 'I', 'Í': 'I', 'Ò': 'O', 'Ó': 'O', 'Ù': 'U', 'Ú': 'U'};
  accents.forEach((k, v) => t = t.replaceAll(k, v));
  t = t.replaceAll('&', ' AND ').replaceAll(RegExp(r"[^A-Z0-9']+"), ' ').replaceAll("'", '');
  return t.replaceAll(RegExp(r'\s+'), ' ').trim();
}

const _legalSuffixes = {
  'SRL', 'SRLS', 'SPA', 'SNC', 'SAS', 'SS', 'SCARL', 'SOC', 'COOP', 'DI', 'LTD', 'INC', 'LLC', 'CO',
  'SDN', 'BHD', 'PLT', 'ENTERPRISE', 'TRADING', 'GMBH', 'SA', 'SL',
};

/// Chiave stabile per un esercente: niente forma societaria, numeri di
/// negozio o punteggiatura. "CONAD SUPERSTORE S.R.L. 0123" -> "CONAD SUPERSTORE".
String merchantKey(String merchant) {
  var t = normalizeText(merchant.replaceAll('.', ''));
  final words = t.split(' ').where((w) => w.isNotEmpty && !_legalSuffixes.contains(w) && !RegExp(r'^\d+$').hasMatch(w));
  t = words.join(' ');
  return t.length > 40 ? t.substring(0, 40).trim() : t;
}

/// Nome leggibile per l'esercente letto dallo scontrino: "OJC MARKETING SDN BHD"
/// -> "Ojc Marketing Sdn Bhd". Restituisce '' se il parser non l'ha trovato.
String displayMerchant(String company) {
  final c = company.trim();
  if (c.isEmpty || c == 'UNKNOWN') return '';
  final cleaned = c.replaceAll(RegExp(r'^[^A-Za-z0-9À-ÿ]+|[^A-Za-z0-9À-ÿ.)]+$'), '').replaceAll(RegExp(r'\s+'), ' ');
  return cleaned
      .split(' ')
      // Sigle puntate (S.P.A., S.R.L.) e parole con cifre restano come sono.
      .map((w) => w.length <= 1 || RegExp(r'\d').hasMatch(w) || RegExp(r'^([A-Za-z]\.)+[A-Za-z]?\.?$').hasMatch(w)
          ? w
          : w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');
}

int _levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      cur[j] = [prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost].reduce((x, y) => x < y ? x : y);
    }
    prev = cur;
  }
  return prev[b.length];
}

/// Parola intera; le parole chiave lunghe valgono anche come inizio di parola
/// ("mcdonald" trova "MCDONALDS"), quelle corte no ("bar" non trova "BARCODE").
bool _containsWord(String haystack, String keyword) {
  if (keyword.isEmpty) return false;
  return keyword.length >= 5 ? ' $haystack'.contains(' $keyword') : ' $haystack '.contains(' $keyword ');
}

CategorySuggestion suggestCategory({
  required String merchant,
  String ocrText = '',
  required Map<String, int> rules,
  required List<CategoryKeywords> categories,
}) {
  final key = merchantKey(merchant);

  // 1. Regole imparate: esatta, poi tolleranza agli errori di OCR.
  if (key.isNotEmpty) {
    final exact = rules[key];
    if (exact != null) return CategorySuggestion(exact, SuggestionSource.learned, key);
    String? best;
    var bestScore = 0.0;
    for (final r in rules.keys) {
      if (r.length < 4 || key.length < 4) continue;
      double score;
      if (key.startsWith(r) || r.startsWith(key)) {
        score = 0.9;
      } else {
        final d = _levenshtein(key, r);
        score = 1 - d / (key.length > r.length ? key.length : r.length);
      }
      if (score > bestScore) {
        bestScore = score;
        best = r;
      }
    }
    if (best != null && bestScore >= 0.8) return CategorySuggestion(rules[best], SuggestionSource.learned, best);
  }

  // 2. Parole chiave: nel nome valgono 3, nel resto dello scontrino 1.
  final name = normalizeText(merchant);
  final body = normalizeText(ocrText);
  int? bestId;
  String? bestKw;
  var bestPoints = 0;
  for (final c in categories) {
    var points = 0;
    String? kwHit;
    for (final kw in c.keywords) {
      if (_containsWord(name, kw)) {
        points += 3;
        kwHit ??= kw;
      } else if (_containsWord(body, kw)) {
        points += 1;
        kwHit ??= kw;
      }
    }
    if (points > bestPoints) {
      bestPoints = points;
      bestId = c.id;
      bestKw = kwHit;
    }
  }
  if (bestId != null) return CategorySuggestion(bestId, SuggestionSource.keyword, bestKw);
  return const CategorySuggestion(null, SuggestionSource.none);
}
