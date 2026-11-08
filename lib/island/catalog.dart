/// Le piante che si possono mettere sull'isola. Ogni specie è un insieme di
/// parametri su una delle sette forme base disegnate in plant_painter.dart:
/// aggiungerne una vuol dire aggiungere una riga qui (più il nome nelle due
/// lingue).
library;

enum PlantShape { tree, fruitTree, conifer, palm, shrub, flower, succulent }

class PlantSpecies {
  /// Chiave salvata nel database: non va mai cambiata.
  final String key;
  final PlantShape shape;

  /// Mesi (1-12) in fiore e con i frutti, nell'emisfero nord.
  final Set<int> bloom;
  final Set<int> fruit;

  /// Perde le foglie d'inverno.
  final bool deciduous;

  /// Il mese in cui si mostra nel catalogo: quando è più bella.
  final int best;

  const PlantSpecies(
    this.key,
    this.shape, {
    this.bloom = const {},
    this.fruit = const {},
    this.deciduous = false,
    required this.best,
  });
}

const plantCatalog = <PlantSpecies>[
  // Alberi
  PlantSpecies('oak', PlantShape.tree, deciduous: true, best: 6),
  PlantSpecies('olive', PlantShape.tree, fruit: {10, 11, 12}, best: 11),
  PlantSpecies('maple', PlantShape.tree, deciduous: true, best: 10),
  PlantSpecies('birch', PlantShape.tree, deciduous: true, best: 5),
  PlantSpecies('willow', PlantShape.tree, deciduous: true, best: 6),
  PlantSpecies('stonePine', PlantShape.tree, best: 7),
  // Alberi da frutto
  PlantSpecies(
    'lemon',
    PlantShape.fruitTree,
    bloom: {3, 4, 5},
    fruit: {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12},
    best: 3,
  ),
  PlantSpecies('orange', PlantShape.fruitTree, bloom: {4, 5}, fruit: {11, 12, 1, 2, 3}, best: 1),
  PlantSpecies('apple', PlantShape.fruitTree, bloom: {4, 5}, fruit: {8, 9, 10}, deciduous: true, best: 9),
  PlantSpecies('cherry', PlantShape.fruitTree, bloom: {3, 4}, fruit: {6}, deciduous: true, best: 4),
  PlantSpecies('almond', PlantShape.fruitTree, bloom: {2, 3}, deciduous: true, best: 2),
  PlantSpecies('fig', PlantShape.fruitTree, fruit: {8, 9}, deciduous: true, best: 8),
  // Conifere
  PlantSpecies('fir', PlantShape.conifer, best: 12),
  PlantSpecies('cypress', PlantShape.conifer, best: 6),
  // Palme
  PlantSpecies('datePalm', PlantShape.palm, fruit: {9, 10, 11}, best: 10),
  PlantSpecies('fanPalm', PlantShape.palm, best: 6),
  // Arbusti
  PlantSpecies('lavender', PlantShape.shrub, bloom: {6, 7, 8}, best: 7),
  PlantSpecies('rosemary', PlantShape.shrub, bloom: {1, 2, 3, 4}, best: 3),
  PlantSpecies('oleander', PlantShape.shrub, bloom: {5, 6, 7, 8, 9}, best: 7),
  PlantSpecies('hydrangea', PlantShape.shrub, bloom: {6, 7, 8, 9}, deciduous: true, best: 7),
  PlantSpecies('bougainvillea', PlantShape.shrub, bloom: {4, 5, 6, 7, 8, 9, 10, 11}, best: 8),
  // Fiori
  PlantSpecies('sunflower', PlantShape.flower, bloom: {7, 8, 9}, best: 8),
  PlantSpecies('poppy', PlantShape.flower, bloom: {4, 5, 6}, best: 5),
  PlantSpecies('daisy', PlantShape.flower, bloom: {3, 4, 5, 6, 7, 8, 9, 10}, best: 5),
  PlantSpecies('tulip', PlantShape.flower, bloom: {3, 4}, best: 4),
  PlantSpecies('rose', PlantShape.flower, bloom: {5, 6, 7, 8, 9, 10}, best: 6),
  PlantSpecies('iris', PlantShape.flower, bloom: {4, 5}, best: 5),
  PlantSpecies('jasmine', PlantShape.flower, bloom: {5, 6, 7, 8, 9}, best: 6),
  // Piante grasse
  PlantSpecies('pricklyPear', PlantShape.succulent, bloom: {5, 6}, fruit: {8, 9, 10}, best: 9),
  PlantSpecies('agave', PlantShape.succulent, best: 6),
  PlantSpecies('aloe', PlantShape.succulent, bloom: {12, 1, 2}, best: 1),
  PlantSpecies('cactus', PlantShape.succulent, bloom: {4, 5, 6}, best: 5),
];

final _byKey = {for (final s in plantCatalog) s.key: s};

/// La specie con chiave [key]; null per una chiave sconosciuta (es. un
/// backup di una versione più nuova con piante che qui non ci sono).
PlantSpecies? speciesByKey(String key) => _byKey[key];

/// Il primo e l'ultimo mese di [months] presi come intervallo sul calendario
/// circolare (es. {12, 1, 2} → (12, 2)); null se vuoto o tutto l'anno.
(int, int)? monthRange(Set<int> months) {
  if (months.isEmpty || months.length == 12) return null;
  // L'inizio è il mese che c'è senza quello prima.
  final first = [for (var m = 1; m <= 12; m++) m]
      .firstWhere((m) => months.contains(m) && !months.contains(m == 1 ? 12 : m - 1));
  var last = first;
  while (months.contains(last % 12 + 1)) {
    last = last % 12 + 1;
  }
  return (first, last);
}
