/// Le regole dell'isola (docs/ISLAND.md), senza database né interfaccia:
/// mesi, limiti, controllo delle registrazioni, posti e premio, stagioni e
/// luna. Tutto qui si prova da solo.
library;

import 'dart:math' as math;

// --- Mesi ------------------------------------------------------------------

/// Mese come aaaamm (es. 202610): così sta in un intero e non si sposta col
/// fuso orario come una data a mezzanotte.
int monthKey(DateTime d) => d.year * 100 + d.month;

DateTime monthStart(int key) => DateTime(key ~/ 100, key % 100);

int addMonths(int key, int n) => monthKey(DateTime(key ~/ 100, key % 100 + n));

int daysInMonth(int key) => DateTime(key ~/ 100, key % 100 + 1, 0).day;

/// I mesi da [from] a [to] compresi.
Iterable<int> monthsBetween(int from, int to) sync* {
  for (var m = from; m <= to; m = addMonths(m, 1)) {
    yield m;
  }
}

/// Numero del giorno (giorni dal 1970) di [d], senza ore: in UTC, così un
/// cambio d'ora non fa durare un giorno 23 o 25 ore.
int dayNumber(DateTime d) => DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;

// --- Limiti ----------------------------------------------------------------

/// Fino a questo giorno del mese un limite cambiato vale già per il mese in
/// corso; dopo, per l'isola vale dal mese successivo.
const limitChangeDays = 5;

/// Da quando i limiti che contano per [month] sono fissati: l'inizio del 6.
DateTime limitsFixedAt(int month) => DateTime(month ~/ 100, month % 100, limitChangeDays + 1);

/// Il primo mese per cui vale un limite cambiato in [now].
int firstMonthOfLimitChange(DateTime now) => now.day <= limitChangeDays ? monthKey(now) : addMonths(monthKey(now), 1);

// --- Registrazioni ---------------------------------------------------------

/// Quanti giorni prima del mese guarda il modello del ritmo.
const historyDays = 90;

/// Buco più lungo tollerato, in giorni, qualunque sia il ritmo.
const minGap = 5, maxGap = 14;

/// Stima prudente delle registrazioni al giorno: N registrazioni in T giorni
/// danno (N − 2√N) / T, il limite basso invece della media. Con pochi dati
/// è molto sotto la media, quindi il controllo è morbido; sovrastimare è
/// l'unico errore che fa danni (negherebbe la pianta a chi registra).
double prudentRate(int records, int days) {
  if (days <= 0 || records <= 0) return 0;
  return math.max(0, (records - 2 * math.sqrt(records)) / days);
}

/// Il buco più lungo (giorni di fila senza registrazioni) che il ritmo
/// [rate] rende improbabile: con un processo di Poisson, in un mese di 30
/// giorni i buchi lunghi almeno G sono in media 30λ·e^(−λG); G è quello che
/// li porta sotto 1 su 100, cioè ln(3000λ)/λ, tenuto tra 5 e 14 giorni.
double gapLimit(double rate) {
  // Sotto circa 0,5 al giorno la formula dà già più di 14; con λ quasi zero
  // non ha più senso (non ci sono registrazioni da cui far partire un buco).
  if (rate < 0.01) return maxGap.toDouble();
  final g = math.log(3000 * rate) / rate;
  return g.clamp(minGap.toDouble(), maxGap.toDouble());
}

/// Com'è andato un mese quanto a registrazioni.
class RecordingCheck {
  /// Registrazioni al giorno stimate prima del mese (prudente).
  final double rate;

  /// Giorni del mese considerati: quelli dalla prima registrazione in poi.
  final int days;

  /// Registrazioni nel mese.
  final int records;

  /// Il buco più lungo nel mese e quello tollerato.
  final int longestGap;
  final double gapAllowed;

  const RecordingCheck({
    required this.rate,
    required this.days,
    required this.records,
    required this.longestGap,
    required this.gapAllowed,
  });

  /// Le registrazioni che il ritmo fa aspettare; ne basta la metà, perché
  /// risparmiare può anche voler dire uscire meno.
  double get expected => rate * days;
  int get minimum => (expected / 2).ceil();

  bool get enough => records >= minimum;
  bool get noLongGap => longestGap <= gapAllowed;
  bool get ok => records > 0 && enough && noLongGap;
}

/// Il controllo delle registrazioni per [month]. [dates] sono le date delle
/// spese (almeno quelle dei 90 giorni prima e del mese); [firstRecord] la
/// data della prima spesa in assoluto: i giorni prima non contano, l'app non
/// c'era ancora. Con [until] (il mese in corso) contano solo i giorni fino a
/// quello, compreso.
RecordingCheck checkRecording({
  required int month,
  required Iterable<DateTime> dates,
  required DateTime? firstRecord,
  DateTime? until,
}) {
  final start = dayNumber(monthStart(month));
  var end = start + daysInMonth(month);
  if (until != null) end = math.max(start + 1, math.min(end, dayNumber(until) + 1));
  if (firstRecord == null || dayNumber(firstRecord) >= end) {
    return RecordingCheck(rate: 0, days: 0, records: 0, longestGap: end - start, gapAllowed: gapLimit(0));
  }
  final first = dayNumber(firstRecord);
  final historyStart = math.max(start - historyDays, first);
  final from = math.max(start, first);
  var history = 0, records = 0;
  final recordedDays = <int>{};
  for (final d in dates) {
    final n = dayNumber(d);
    if (n >= historyStart && n < start) history++;
    if (n >= from && n < end) {
      records++;
      recordedDays.add(n);
    }
  }
  final rate = prudentRate(history, start - historyStart);
  var longest = 0, run = 0;
  for (var n = from; n < end; n++) {
    run = recordedDays.contains(n) ? 0 : run + 1;
    longest = math.max(longest, run);
  }
  return RecordingCheck(
    rate: rate,
    days: end - from,
    records: records,
    longestGap: longest,
    gapAllowed: gapLimit(rate),
  );
}

// --- Il mese ---------------------------------------------------------------

/// Una spesa ridotta a quello che serve all'isola.
class ExpenseFact {
  final DateTime date;
  final int categoryId;
  final int cents;
  const ExpenseFact(this.date, this.categoryId, this.cents);
}

/// Il risultato di un mese: limiti, speso nelle categorie con limite,
/// registrazioni. Per il mese in corso è "finora".
class MonthResult {
  final int month;

  /// Somma dei limiti e speso nelle categorie che li hanno.
  final int limit, spent;
  final RecordingCheck recording;

  const MonthResult({required this.month, required this.limit, required this.spent, required this.recording});

  bool get hasLimits => limit > 0;
  bool get withinLimits => hasLimits && spent <= limit;
  bool get eligible => withinLimits && recording.ok;
}

/// Valuta [month] con i limiti che contano per quel mese ([limits]: id
/// categoria → centesimi). Per il mese in corso [until] è oggi.
MonthResult evaluateMonth({
  required int month,
  required Map<int, int> limits,
  required List<ExpenseFact> expenses,
  required DateTime? firstRecord,
  DateTime? until,
}) {
  final start = monthStart(month), end = monthStart(addMonths(month, 1));
  var spent = 0;
  for (final e in expenses) {
    if (!e.date.isBefore(start) && e.date.isBefore(end) && limits.containsKey(e.categoryId)) spent += e.cents;
  }
  return MonthResult(
    month: month,
    limit: limits.values.fold(0, (a, b) => a + b),
    spent: spent,
    recording: checkRecording(month: month, dates: expenses.map((e) => e.date), firstRecord: firstRecord, until: until),
  );
}

// --- Isole -----------------------------------------------------------------

/// Il mese regalato alla prima apertura dell'isola in [now]: il mese prima,
/// tranne a gennaio (sarebbe dell'isola dell'anno passato).
int? giftMonth(DateTime now) => now.month == 1 ? null : addMonths(monthKey(now), -1);

/// Il primo mese della prima isola.
int islandStart(DateTime now) => giftMonth(now) ?? monthKey(now);

/// I mesi (cioè i posti) dell'isola di [year]: da gennaio, o dal primo mese
/// dell'isola, a dicembre.
List<int> islandMonths(int year, int start) {
  if (year < start ~/ 100) return const [];
  final from = year == start ~/ 100 ? start : year * 100 + 1;
  return monthsBetween(from, year * 100 + 12).toList();
}

/// Piante che servono per il premio al centro: più della metà dei posti.
int rewardThreshold(int slots) => slots ~/ 2 + 1;

/// Cosa spunta al centro, un anno dopo l'altro.
const centerpieces = ['lighthouse', 'fountain', 'temple', 'statue', 'obelisk'];

String centerpieceFor(int year, int firstYear) => centerpieces[(year - firstYear) % centerpieces.length];

// --- Cielo -----------------------------------------------------------------

enum Season { winter, spring, summer, autumn }

/// Stagione dell'emisfero nord, per mesi interi.
Season seasonOf(int month) => switch (month) {
  12 || 1 || 2 => Season.winter,
  3 || 4 || 5 => Season.spring,
  6 || 7 || 8 => Season.summer,
  _ => Season.autumn,
};

/// Mese sinodico (da luna nuova a luna nuova), in giorni.
const synodicMonth = 29.530588853;

/// Una luna nuova nota: 6 gennaio 2000, 18:14 UTC.
final _knownNewMoon = DateTime.utc(2000, 1, 6, 18, 14);

/// Età della luna come frazione del ciclo: 0 nuova, 0,25 primo quarto,
/// 0,5 piena, 0,75 ultimo quarto.
double moonAge(DateTime t) {
  final days = t.toUtc().difference(_knownNewMoon).inSeconds / Duration.secondsPerDay;
  final age = (days / synodicMonth) % 1;
  return age < 0 ? age + 1 : age;
}

/// Parte illuminata del disco, da 0 (nuova) a 1 (piena).
double moonIllumination(double age) => (1 - math.cos(2 * math.pi * age)) / 2;
