/// Un dipinto del Metropolitan Museum of Art, come lo descrive
/// assets/art/paintings.json (generato da tools/make_paintings.py). Solo
/// opere di pubblico dominio e verticali: stanno bene come sfondo del
/// telefono. Nessun testo è scritto per Receipt: dati del Met e di Wikidata
/// (CC0), immagine da Wikimedia Commons, introduzione da Wikipedia (CC BY-SA).
class Painting {
  final int id;
  final String title;
  final String artist;
  final String artistBio;
  final String date;
  final String medium;
  final String dimensions;
  final String credit;
  final Uri page;
  final Uri image;
  final Uri imagePage;
  final String imageLicense;
  final Uri? wikidata;

  /// Per lingua ("it", "en"): titolo e descrizione breve da Wikidata,
  /// introduzione della voce di Wikipedia. Ognuno può mancare.
  final Map<String, PaintingTexts> texts;

  const Painting({
    required this.id,
    required this.title,
    required this.artist,
    required this.artistBio,
    required this.date,
    required this.medium,
    required this.dimensions,
    required this.credit,
    required this.page,
    required this.image,
    required this.imagePage,
    required this.imageLicense,
    this.wikidata,
    required this.texts,
  });

  factory Painting.fromJson(Map<String, dynamic> json) => Painting(
    id: json['id'] as int,
    title: json['title'] as String,
    artist: json['artist'] as String,
    artistBio: json['artistBio'] as String,
    date: json['date'] as String,
    medium: json['medium'] as String,
    dimensions: json['dimensions'] as String,
    credit: json['credit'] as String,
    page: Uri.parse(json['page'] as String),
    image: Uri.parse(json['image'] as String),
    imagePage: Uri.parse(json['imagePage'] as String),
    imageLicense: json['imageLicense'] as String,
    wikidata: json['wikidata'] == null ? null : Uri.parse(json['wikidata'] as String),
    texts: {
      for (final e in (json['texts'] as Map<String, dynamic>).entries)
        e.key: PaintingTexts.fromJson(e.value as Map<String, dynamic>),
    },
  );

  /// Titolo in [lang] da Wikidata, se c'è, altrimenti quello del Met.
  String titleIn(String lang) => texts[lang]?.title ?? title;

  /// La voce di Wikipedia in [lang], o in inglese se manca.
  WikipediaText? wikipediaIn(String lang) => texts[lang]?.wikipedia ?? texts['en']?.wikipedia;

  /// La descrizione breve di Wikidata in [lang] (es. "dipinto di Claude Monet").
  String? summaryIn(String lang) => texts[lang]?.summary;

  /// Le misure in [lang]: in italiano solo i centimetri ("73,2 × 93,4 cm"),
  /// in inglese come le scrive il Met (pollici e centimetri).
  String dimensionsIn(String lang) {
    if (lang != 'it') return dimensions;
    final cm = RegExp(r'\(([^()]*cm)\)').firstMatch(dimensions)?[1];
    return cm?.replaceAll('.', ',') ?? dimensions;
  }
}

class PaintingTexts {
  final String? title;
  final String? summary;
  final WikipediaText? wikipedia;
  const PaintingTexts({this.title, this.summary, this.wikipedia});

  factory PaintingTexts.fromJson(Map<String, dynamic> json) => PaintingTexts(
    title: json['title'] as String?,
    summary: json['summary'] as String?,
    wikipedia: json['wikipedia'] == null ? null : WikipediaText.fromJson(json['wikipedia'] as Map<String, dynamic>),
  );
}

/// L'introduzione di una voce di Wikipedia, da citare con titolo e link.
class WikipediaText {
  final String title;
  final Uri url;
  final String extract;
  const WikipediaText({required this.title, required this.url, required this.extract});

  factory WikipediaText.fromJson(Map<String, dynamic> json) => WikipediaText(
    title: json['title'] as String,
    url: Uri.parse(json['url'] as String),
    extract: json['extract'] as String,
  );

  /// "it", "en": la lingua della voce.
  String get lang => url.host.split('.').first;
}

/// Elenco dei dipinti dal JSON di assets/art.
List<Painting> parsePaintings(Map<String, dynamic> json) => [
  for (final p in json['paintings'] as List) Painting.fromJson(p as Map<String, dynamic>),
];

/// Il dipinto di [day]: uno diverso ogni giorno, lo stesso per tutto il
/// giorno, in ordine (l'elenco è già mescolato) e poi da capo.
Painting paintingOfDay(List<Painting> paintings, DateTime day) {
  // In UTC per non contare due volte il giorno del cambio d'ora.
  final days = DateTime.utc(day.year, day.month, day.day).difference(DateTime.utc(2026)).inDays;
  return paintings[days % paintings.length];
}
