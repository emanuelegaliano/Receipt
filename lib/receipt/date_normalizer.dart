/// Converte la data letta dallo scontrino in un DateTime.
///
/// Gli scontrini italiani (e quelli SROIE) sono giorno/mese/anno: si usa
/// mese/giorno solo quando il primo numero non può essere un mese.
DateTime? normalizeReceiptDate(String raw, {DateTime? now}) {
  final s = raw.trim();
  if (s.isEmpty) return null;
  final today = now ?? DateTime.now();

  DateTime? build(int y, int m, int d) {
    if (y < 100) y += 2000;
    if (m < 1 || m > 12 || d < 1 || d > 31 || y < 2000) return null;
    final dt = DateTime(y, m, d);
    if (dt.month != m) return null; // es. 31/02
    // Scarta date nel futuro (con un giorno di margine per i fusi).
    if (dt.isAfter(today.add(const Duration(days: 1)))) return null;
    return dt;
  }

  // yyyy-mm-dd, yyyy/mm/dd, yyyy.mm.dd
  var m = RegExp(r'(\d{4})\s*[-/.]\s*(\d{1,2})\s*[-/.]\s*(\d{1,2})').firstMatch(s);
  if (m != null) return build(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));

  // dd/mm/yy(yy) con / - .
  m = RegExp(r'(\d{1,2})\s*[-/.]\s*(\d{1,2})\s*[-/.]\s*(\d{2,4})').firstMatch(s);
  if (m != null) {
    final a = int.parse(m[1]!), b = int.parse(m[2]!), y = int.parse(m[3]!);
    return build(y, b, a) ?? (a <= 12 ? build(y, a, b) : null);
  }

  // Mesi in lettere (italiano e inglese): "15 Jan 2019", "Jan 15, 2019", "15 gen 2024".
  final month = _monthNames.keys.join('|');
  m = RegExp('(\\d{1,2})\\s*[-/ ]?\\s*($month)[a-z]*\\.?\\s*[-/ ]?\\s*(\\d{2,4})', caseSensitive: false).firstMatch(s);
  if (m != null) return build(int.parse(m[3]!), _monthNames[m[2]!.toLowerCase().substring(0, 3)]!, int.parse(m[1]!));
  m = RegExp('($month)[a-z]*\\.?\\s+(\\d{1,2}),?\\s+(\\d{2,4})', caseSensitive: false).firstMatch(s);
  if (m != null) return build(int.parse(m[3]!), _monthNames[m[1]!.toLowerCase().substring(0, 3)]!, int.parse(m[2]!));

  return null;
}

const _monthNames = {
  'jan': 1, 'gen': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'mag': 5, 'jun': 6, 'giu': 6,
  'jul': 7, 'lug': 7, 'aug': 8, 'ago': 8, 'sep': 9, 'set': 9, 'oct': 10, 'ott': 10,
  'nov': 11, 'dec': 12, 'dic': 12,
};
