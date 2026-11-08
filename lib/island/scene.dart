/// L'isola di un anno in pixel art: cielo e mare della stagione (o della
/// notte, con la luna vera e le stelle), la spiaggia, il prato che cambia con
/// la stagione (fiorellini in primavera, erba secca d'estate, foglie e funghi
/// d'autunno, neve d'inverno), sassi, lanterne, le piante nei loro posti e, a
/// fine anno, il premio al centro. Si disegna una volta in un foglio di
/// pixel e si mostra ingrandito a multipli interi dei pixel dello schermo.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'catalog.dart';
import 'pixel.dart';
import 'rules.dart';
import 'sprites.dart';

/// Altezza del disegno in pixel; la larghezza si adatta allo schermo (si
/// vede più mare), le misure dell'isola no.
const sceneHeight = 200;
const sceneMinWidth = 192;

/// Quanti pixel dello schermo per pixel del disegno, sempre un numero intero
/// di pixel fisici: così i quadretti sono tutti uguali.
class PixelFit {
  /// Pixel logici per pixel del disegno.
  final double scale;

  /// Larghezza del disegno in pixel.
  final int width;
  const PixelFit(this.scale, this.width);

  factory PixelFit.forWidth(double logicalWidth, double devicePixelRatio) {
    final k = math.max(1, (logicalWidth * devicePixelRatio / sceneMinWidth).floor());
    final scale = k / devicePixelRatio;
    return PixelFit(scale, math.max(sceneMinWidth, (logicalWidth / scale).ceil()));
  }

  double get height => sceneHeight * scale;
}

/// Dove stanno le cose sull'isola, in pixel del disegno.
class IslandGeometry {
  final int width;
  final int slots;
  const IslandGeometry(this.width, this.slots);

  /// I posti in coordinate dell'ellisse (-1..1), in un ordine che sta bene
  /// anche preso a metà: un'isola di 3 usa i primi 3.
  /// I posti in coordinate dell'ellisse (-1..1): due anelli che lasciano
  /// libero davanti il passaggio verso il centro, così il premio si vede. In
  /// un ordine che sta bene anche preso a metà: un'isola di 3 usa i primi 3.
  static const _spots = [
    (0.0, -0.82), (-0.53, 0.63), (0.53, 0.63), (-0.79, 0.2), (0.79, 0.2), (-0.47, -0.68), //
    (0.47, -0.68), (-0.8, -0.3), (0.8, -0.3), (-0.42, 0.04), (0.42, 0.04), (0.0, -0.5),
  ];

  /// Lanterne e sassi sull'anello di sabbia, a 0,9 del raggio: con la loro
  /// larghezza restano dentro l'isola anche ai lati.
  static const _lanterns = [(-0.2, 0.88), (0.2, 0.88), (-0.9, -0.05), (0.9, -0.05)];
  static const _rocks = [(0.75, 0.52), (-0.75, 0.52), (0.88, -0.25), (-0.88, -0.25), (-0.24, -0.88)];

  double get horizon => 58;
  double get cx => width / 2;
  double get cy => 130;
  double get rx => 82 * (0.62 + 0.38 * math.min(slots, 12) / 12);
  double get ry => rx * 0.48;

  (double, double) at(double u, double v) => (cx + u * rx, cy + v * ry);
  (double, double) slot(int i) {
    final (u, v) = _spots[i % _spots.length];
    return at(u, v);
  }

  /// Come [at], ma in un'ellisse rientrata di mezza lanterna: anche
  /// nell'isola più piccola la loro larghezza resta sulla sabbia.
  (double, double) _inset(double u, double v) => (cx + u * (rx - 7), cy + v * (ry - 2));
  Iterable<(double, double)> get lanterns => _lanterns.map((l) => _inset(l.$1, l.$2));
  Iterable<(double, double)> get rocks => _rocks.map((r) => _inset(r.$1, r.$2));

  /// Il posto toccato in ([x], [y]), pixel del disegno.
  ///
  /// Con [among] (si sta scegliendo dove piantare) conta il cerchio del posto
  /// libero più vicino, che è disegnato sopra a tutto. Altrimenti vince la
  /// pianta più avanti tra quelle che coprono il punto, come nel disegno.
  int? slotAt(double x, double y, {Set<int>? among}) {
    int? best;
    if (among != null) {
      var bestDistance = 13.0;
      for (final i in among) {
        final (sx, sy) = slot(i);
        // Il "+" sta sopra il cerchio: conta anche quello.
        final dy = y > sy ? y - sy : math.max(0, sy - y - 14);
        final d = math.sqrt((x - sx) * (x - sx) + dy * dy);
        if (d < bestDistance) {
          bestDistance = d;
          best = i;
        }
      }
      return best;
    }
    var front = double.negativeInfinity;
    for (var i = 0; i < slots; i++) {
      final (sx, sy) = slot(i);
      if ((x - sx).abs() <= 11 && y <= sy + 4 && y >= sy - 42 && sy > front) {
        front = sy;
        best = i;
      }
    }
    return best;
  }
}

/// Tutto quello da cui dipende il disegno: se non cambia, si riusa.
class IslandSceneSpec {
  final int width;
  final int slots;

  /// Posto → (specie, mese in cui è stata piantata).
  final Map<int, (String, int)> plants;
  final String? centerpiece;

  /// Il giorno (stagione, sfumata giorno per giorno) e la luna, arrotondata a
  /// un sessantesimo del ciclo.
  final DateTime date;
  final double moonAge;
  final bool night;
  final int seed;

  IslandSceneSpec({
    required this.width,
    required this.slots,
    required this.plants,
    required this.centerpiece,
    required DateTime now,
    required this.night,
    required this.seed,
  }) : date = DateTime(now.year, now.month, now.day),
       moonAge = (_moonAgeAt(now) * 60).round() / 60;

  int get month => date.month;

  String get key {
    final p = (plants.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
        .map((e) => '${e.key}:${e.value.$1}:${e.value.$2}')
        .join(',');
    return '$width|$slots|$p|$centerpiece|${dayOfYear(date)}|$moonAge|$night|$seed';
  }
}

/// Fuori dalla classe, dove "moonAge" è il campo.
double _moonAgeAt(DateTime t) => moonAge(t);

/// Le mappe di Dart tengono l'ordine d'inserimento: la prima è la più vecchia.
final _cache = <String, ui.Picture>{};

/// Il disegno di [spec], dalla cache se c'è già.
ui.Picture islandPicture(IslandSceneSpec spec) {
  final key = spec.key;
  final hit = _cache.remove(key);
  if (hit != null) return _cache[key] = hit;
  final picture = renderIsland(spec).toPicture();
  _cache[key] = picture;
  while (_cache.length > 8) {
    _cache.remove(_cache.keys.first)!.dispose();
  }
  return picture;
}

// --- Il disegno ------------------------------------------------------------

/// Media dei colori pesata (inverno, primavera, estate, autunno).
int _blend(List<int> colors, List<double> w) {
  double r = 0, g = 0, b = 0;
  for (var i = 0; i < colors.length; i++) {
    r += ((colors[i] >> 16) & 0xFF) * w[i];
    g += ((colors[i] >> 8) & 0xFF) * w[i];
    b += (colors[i] & 0xFF) * w[i];
  }
  return rgb(r.round(), g.round(), b.round());
}

/// Colori del cielo (alto, basso) e del mare (vicino all'orizzonte, in fondo),
/// sfumati tra le stagioni.
List<int> _palette(SeasonLook look, bool night) {
  if (night) {
    const other = [0xFF0A0F2E, 0xFF2B3766, 0xFF22345E, 0xFF0E1A3A];
    const winter = [0xFF0E1430, 0xFF34405E, 0xFF253457, 0xFF111C38];
    return [for (var i = 0; i < 4; i++) mix(other[i], winter[i], look.winter)];
  }
  const bySeason = [
    [0xFF9DB1C4, 0xFFDDE5EC, 0xFF6F9AB8, 0xFF3D6788], // inverno
    [0xFF63B9F0, 0xFFC6EAF8, 0xFF5BB6DE, 0xFF2F7DB6], // primavera
    [0xFF3FA6EE, 0xFFB4E4F8, 0xFF3FB0DE, 0xFF1F72B0], // estate
    [0xFF7FA9D0, 0xFFF0D2A8, 0xFF5E9EC4, 0xFF2D6697], // autunno
  ];
  return [
    for (var i = 0; i < 4; i++) _blend([for (final s in bySeason) s[i]], look.weights),
  ];
}

/// Sfumatura a bande con il retino: [colors] dall'alto in basso.
void _gradient(Px p, int y0, int y1, List<int> colors) {
  final n = colors.length - 1;
  for (var y = y0; y < y1; y++) {
    final t = (y - y0) / math.max(1, y1 - y0 - 1) * n;
    final band = math.min(n - 1, t.floor());
    final frac = t - band;
    for (var x = 0; x < p.w; x++) {
      p.set(x, y, dither(x, y, frac) ? colors[band + 1] : colors[band]);
    }
  }
}

List<int> _steps(int a, int b, int n) => [for (var i = 0; i < n; i++) mix(a, b, i / (n - 1))];

Px renderIsland(IslandSceneSpec spec) {
  final g = IslandGeometry(spec.width, spec.slots);
  final look = SeasonLook.at(spec.date);
  // La stagione che pesa di più, per le cose che non si sfumano (le nuvole).
  final main = [for (var i = 0; i < 4; i++) i].reduce((a, b) => look.weights[a] >= look.weights[b] ? a : b);
  final snowy = look.snow > 0.5;
  // Stesse stelle, nuvole e onde per tutto l'anno.
  final r = math.Random(spec.seed * 31);
  final bg = Px(spec.width, sceneHeight);
  final [skyTop, skyBottom, seaTop, seaBottom] = _palette(look, spec.night);
  final horizon = g.horizon.round();

  // Cielo.
  _gradient(bg, 0, horizon, _steps(skyTop, skyBottom, 5));
  final (bodyX, bodyY) = (spec.width - 36.0, 20.0);
  if (spec.night) {
    for (var i = 0; i < 70; i++) {
      final x = r.nextInt(spec.width), y = r.nextInt(horizon - 4);
      final bright = r.nextDouble();
      bg.set(x, y, bright > 0.7 ? 0xFFFFFFFF : mix(skyTop, 0xFFFFFFFF, 0.35 + bright * 0.4));
      if (bright > 0.93) {
        for (final (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
          bg.set(x + dx, y + dy, mix(skyTop, 0xFFFFFFFF, 0.45));
        }
      }
    }
    _moon(bg, bodyX, bodyY, 7.5, spec.moonAge);
  } else {
    final sun = _blend(const [0xFFFFF0C0, 0xFFFFDC5E, 0xFFFFDC5E, 0xFFFFC266], look.weights);
    final winter = look.winter > 0.5;
    for (var y = (bodyY - 13).floor(); y <= bodyY + 13; y++) {
      for (var x = (bodyX - 13).floor(); x <= bodyX + 13; x++) {
        final d = math.sqrt((x + 0.5 - bodyX) * (x + 0.5 - bodyX) + (y + 0.5 - bodyY) * (y + 0.5 - bodyY));
        if (d < 12.5 && d > 7.5 && dither(x, y, (12.5 - d) / 9)) bg.blend(x, y, sun, 0.35);
      }
    }
    final tones = ramp(sun);
    bg.disc(bodyX, bodyY, winter ? 6 : 7, tones[3]);
    bg.disc(bodyX - 1, bodyY - 1, winter ? 4 : 5, tones[4]);
    final clouds = const [5, 3, 2, 3][main];
    for (var i = 0; i < clouds; i++) {
      _cloud(
        bg,
        r.nextDouble() * (spec.width - 40) + 14,
        10 + r.nextDouble() * (horizon - 26),
        0.7 + r.nextDouble() * 0.6,
        mix(0xFFFFFFFF, 0xFFEDF1F5, look.winter),
        r,
      );
    }
  }

  // Mare.
  _gradient(bg, horizon, sceneHeight, _steps(seaTop, seaBottom, 4));
  for (var x = 0; x < spec.width; x++) {
    bg.set(x, horizon, mix(seaTop, skyBottom, 0.5));
  }
  final wave = spec.night ? mix(seaTop, 0xFFFFFFFF, 0.25) : mix(seaTop, 0xFFFFFFFF, 0.55);
  for (var i = 0; i < 46; i++) {
    final x = r.nextDouble() * spec.width, y = horizon + 3 + r.nextDouble() * (sceneHeight - horizon - 5);
    if (_inEll(x, y, g.cx, g.cy + 4, g.rx + 10, g.ry + 9)) continue;
    final len = 2 + (y - horizon) / 30;
    for (var k = 0; k < len; k++) {
      bg.set((x + k).floor(), y.floor(), wave);
    }
    bg.set((x + len).floor(), y.floor() + 1, darken(wave, 0.15));
  }
  // Riflesso del sole o della luna.
  final shine = spec.night ? moonIllumination(spec.moonAge) : 1.0;
  if (shine > 0.05) {
    // Qualche riflesso sparso sull'acqua, sotto il sole o la luna.
    final glints = math.Random(spec.seed + 7);
    for (var k = 0; k < 9; k++) {
      final y = horizon + 2 + (k * 2.2 + k * k * 0.25).round();
      final w = math.max(1, 5 - k ~/ 2), x0 = (bodyX + glints.nextInt(9) - 4 - w / 2).round();
      for (var x = 0; x < w; x++) {
        bg.blend(x0 + x, y, 0xFFFFF6D8, (0.55 - k * 0.04) * shine);
      }
    }
  }
  // Acqua bassa e schiuma attorno all'isola.
  for (var y = (g.cy - g.ry - 12).floor(); y <= g.cy + g.ry + 16; y++) {
    for (var x = (g.cx - g.rx - 14).floor(); x <= g.cx + g.rx + 14; x++) {
      final e = _e(x + 0.5, y + 0.5, g.cx, g.cy + 6, g.rx + 9, g.ry + 8);
      if (e > 1) continue;
      final water = bg.get(x, y);
      if (e > 0.82 && dither(x, y, 0.55)) {
        bg.set(x, y, mix(water, 0xFFFFFFFF, spec.night ? 0.25 : 0.6));
      } else {
        bg.set(x, y, mix(water, spec.night ? 0xFF3B5F7E : 0xFF8FE0E8, 0.45));
      }
    }
  }

  // L'isola su un foglio a parte, per scurirla di notte senza toccare il cielo.
  final land = Px(spec.width, sceneHeight);
  _land(land, g, look, math.Random(spec.seed * 31 + 5), spec.seed);

  final things = <(double, void Function())>[];
  void place(Sprite s, double x, double y, {double shadow = 0}) {
    things.add((
      y,
      () {
        if (shadow > 0) _shadow(land, x, y, shadow);
        land.stamp(s.px, (x - s.baseX).round(), (y - s.baseY).round());
      },
    ));
  }

  for (var i = 0; i < spec.slots; i++) {
    final (x, y) = g.slot(i);
    final plant = spec.plants[i];
    final species = plant == null ? null : speciesByKey(plant.$1);
    if (species == null) {
      _emptySlot(land, x, y, snowy, math.Random(spec.seed + i));
    } else {
      final sprite = plantSprite(species, month: spec.month, seed: plant!.$2, snow: look.snow);
      place(sprite, x, y, shadow: species.shape == PlantShape.flower ? 7 : 10);
    }
  }
  final lantern = lanternSprite(lit: spec.night, snow: snowy);
  for (final (x, y) in g.lanterns) {
    place(lantern, x, y, shadow: 3);
  }
  var i = 0;
  for (final (x, y) in g.rocks) {
    place(rockSprite(spec.seed + i++, snow: snowy), x, y);
  }
  final (cx, cy) = (g.cx, g.cy + 2);
  if (spec.centerpiece != null) {
    place(centerpieceSprite(spec.centerpiece!, lit: spec.night), cx, cy, shadow: 13);
  } else {
    _rewardSpot(land, cx, cy, snowy);
  }
  if (look.leaves > 0.4 && look.snow < 0.3) {
    final spots = math.Random(spec.seed * 31 + 6);
    for (var k = 0; k < (look.leaves * 4).round(); k++) {
      final (x, y) = _freeSpot(g, spots);
      place(mushroomSprite(red: k.isEven), x, y);
    }
  }
  things.sort((a, b) => a.$1.compareTo(b.$1));
  for (final t in things) {
    t.$2();
  }

  if (spec.night) {
    land.map((c, x, y) => mix(c, 0xFF1B2347, 0.5));
  }
  bg.stamp(land, 0, 0);

  if (spec.night) {
    for (final (x, y) in g.lanterns) {
      _glow(bg, x, y - 20, 13);
      bg.rect((x - 2).round(), (y - 20).round(), (x + 2).round(), (y - 15).round(), 0xFFFFD27A);
      bg.rect((x - 2).round(), (y - 20).round(), x.round(), (y - 18).round(), 0xFFFFF2C2);
    }
    if (spec.centerpiece == 'lighthouse') {
      final (lx, ly) = (cx, cy - 52);
      for (final side in [-1.0, 1.0]) {
        for (var k = 4; k < 60; k++) {
          final half = k * 0.12;
          for (var dy = -half.round(); dy <= half.round(); dy++) {
            final x = (lx + side * k).round(), y = (ly + dy).round();
            if (dither(x, y, 0.5 - k / 140)) bg.blend(x, y, 0xFFFFE08A, 0.3);
          }
        }
      }
      _glow(bg, lx, ly, 14);
    }
  }
  if (look.snow > 0.2) {
    final flakes = math.Random(spec.seed + 99);
    for (var k = 0; k < (55 * look.snow).round(); k++) {
      final x = flakes.nextInt(spec.width), y = flakes.nextInt(sceneHeight);
      bg.set(x, y, 0xFFFFFFFF);
      if (flakes.nextDouble() < 0.3) bg.set(x + 1, y, 0xFFE4ECF5);
    }
  }
  return bg;
}

bool _inEll(double x, double y, double cx, double cy, double rx, double ry) => _e(x, y, cx, cy, rx, ry) <= 1;
double _e(double x, double y, double cx, double cy, double rx, double ry) {
  final dx = (x - cx) / rx, dy = (y - cy) / ry;
  return dx * dx + dy * dy;
}

void _cloud(Px p, double x, double y, double size, int white, math.Random r) {
  final shade = mix(white, 0xFF9FB4CC, 0.35);
  final puffs = [(-9.0, 1.0, 4.5), (-3.0, -2.0, 6.0), (4.0, -1.0, 5.0), (9.0, 1.5, 3.8)];
  for (final (dx, dy, rad) in puffs) {
    p.disc(x + dx * size, y + dy * size + 1.2, rad * size, shade);
  }
  for (final (dx, dy, rad) in puffs) {
    p.disc(x + dx * size, y + dy * size, rad * size, white);
  }
  p.rect((x - 11 * size).round(), (y + 1).round(), (x + 11 * size).round(), (y + 3 * size).round(), white);
  p.rect((x - 11 * size).round(), (y + 3 * size).round(), (x + 11 * size).round(), (y + 3 * size + 1).round(), shade);
}

/// La luna: per ogni pixel del disco, illuminato se sta oltre il terminatore
/// (mezza ellisse larga |cos(2π·età)|): a destra quando cresce, a sinistra
/// quando cala, come la si vede dall'emisfero nord.
void _moon(Px p, double cx, double cy, double rad, double age) {
  final waxing = age < 0.5;
  final tx = math.cos(2 * math.pi * age);
  for (var y = (cy - rad - 6).floor(); y <= cy + rad + 6; y++) {
    for (var x = (cx - rad - 6).floor(); x <= cx + rad + 6; x++) {
      final u = (x + 0.5 - cx) / rad, v = (y + 0.5 - cy) / rad;
      final d = math.sqrt(u * u + v * v);
      if (d > 1) {
        if (d < 1.7 && dither(x, y, (1.7 - d) * 0.5 * moonIllumination(age))) p.blend(x, y, 0xFFFFF6D8, 0.25);
        continue;
      }
      final xt = tx * math.sqrt(math.max(0, 1 - v * v));
      final lit = waxing ? u > xt : u < -xt;
      if (!lit) {
        // La parte in ombra si vede appena (la luce della Terra).
        p.set(x, y, mix(p.get(x, y), 0xFF33406A, 0.35));
        continue;
      }
      var c = d > 0.82 ? 0xFFE3DCC2 : 0xFFF6F1DC;
      for (final (mx, my, mr) in [(-0.3, -0.25, 0.22), (0.3, 0.35, 0.18), (0.38, -0.3, 0.12)]) {
        if ((u - mx) * (u - mx) + (v - my) * (v - my) < mr * mr) c = 0xFFD6CFB4;
      }
      p.set(x, y, c);
    }
  }
}

/// Chiazze morbide (0..1) per la neve che arriva e se ne va: dove il valore
/// è basso la neve c'è già, dove è alto arriva per ultima.
double _patch(int x, int y) =>
    (math.sin(x * 0.29 + y * 0.53) + math.sin(x * 0.11 - y * 0.37 + 1.7) + math.sin((x + 2 * y) * 0.07 + 0.4) + 3) / 6;

bool _snowAt(int x, int y, double snow) => snow >= 1 || (snow > 0 && _patch(x, y) < 0.2 + snow * 0.85);

/// Fianco di terra, spiaggia e prato della stagione: neve a chiazze che
/// arrivano e si sciolgono, fiorellini, erba secca e foglie cadute che
/// crescono e calano giorno per giorno. Ogni cosa ha i suoi posti fissi per
/// tutto l'anno, così di giorno in giorno se ne aggiunge o se ne toglie
/// qualcuna invece di cambiare tutto.
void _land(Px p, IslandGeometry g, SeasonLook look, math.Random r, int seed) {
  final dirt = ramp(0xFF9C6B45);
  final sand = ramp(mix(0xFFE9D3A0, 0xFFE3DED2, look.snow));
  p.ellipse(g.cx, g.cy + 8, g.rx, g.ry, dirt[1]);
  p.ellipse(g.cx, g.cy + 5, g.rx, g.ry, dirt[2]);
  for (var k = 0; k < 40; k++) {
    final x = g.cx + (r.nextDouble() * 2 - 1) * g.rx, y = g.cy + g.ry * 0.6 + r.nextDouble() * 12;
    if (p.get(x.floor(), y.floor()) == dirt[2]) p.set(x.floor(), y.floor(), dirt[r.nextBool() ? 1 : 3]);
  }
  p.ellipse(g.cx, g.cy, g.rx, g.ry, sand[2]);
  p.ellipse(g.cx - 1, g.cy - 1, g.rx - 2, g.ry - 1.5, sand[3]);
  p.ellipse(g.cx, g.cy, g.rx - 3, g.ry - 1.5, sand[2]);
  for (var k = 0; k < 70; k++) {
    final x = g.cx + (r.nextDouble() * 2 - 1) * g.rx, y = g.cy + (r.nextDouble() * 2 - 1) * g.ry;
    if (p.get(x.floor(), y.floor()) == sand[2]) p.set(x.floor(), y.floor(), sand[r.nextBool() ? 1 : 3]);
  }
  p.outline((n) => darken(n, 0.55));

  // Il verde del prato scivola da una stagione all'altra (d'inverno è
  // quello che si vede sotto la neve che si scioglie).
  final grass = ramp(_blend(const [0xFF8FA36A, 0xFF7CC152, 0xFF9DB84A, 0xFFA3A24C], look.weights));
  final snow = ramp(0xFFEEF3F9);
  final (gx, gy, grx, gry) = (g.cx, g.cy - 2, g.rx * 0.86, g.ry * 0.8);
  // Il bordo del prato fa un piccolo gradino sulla sabbia.
  p.ellipse(gx, gy + 2, grx, gry, look.snow > 0.5 ? snow[1] : grass[1]);
  p.ellipse(gx, gy + 1, grx, gry, look.snow > 0.5 ? snow[1] : grass[0]);
  for (var y = (gy - gry).floor(); y <= gy + gry; y++) {
    for (var x = (gx - grx).floor(); x <= gx + grx; x++) {
      final e = _e(x + 0.5, y + 0.5, gx, gy, grx, gry);
      if (e > 1) continue;
      int c;
      if (_snowAt(x, y, look.snow)) {
        c = snow[2];
        if (e > 0.86 && y < gy) c = snow[3];
        // Ombre azzurre a chiazze sulla neve.
        if (math.sin(x * 0.35) + math.cos(y * 0.6 + x * 0.1) > 1.3 && dither(x, y, 0.5)) c = snow[1];
      } else {
        c = grass[2];
        if (e > 0.86 && y < gy) c = grass[3];
        if (dither(x, y, 0.1)) {
          c = grass[3];
        } else if (dither(x + 2, y + 1, 0.06)) {
          c = grass[1];
        }
      }
      p.set(x, y, c);
    }
  }

  /// [n] punti fissi del prato per il seme [salt], i primi [count] disegnati.
  void each(int salt, int n, int count, void Function(int x, int y, int k) draw) {
    final at = math.Random(seed * 131 + salt);
    for (var k = 0; k < n; k++) {
      final (x, y) = (gx + (at.nextDouble() * 2 - 1) * grx * 0.9, gy + (at.nextDouble() * 2 - 1) * gry * 0.85);
      if (k >= count || !_inEll(x, y, gx, gy, grx * 0.9, gry * 0.85)) continue;
      draw(x.floor(), y.floor(), k);
    }
  }

  // Ciuffi d'erba: sulla neve ne spunta qualcuno.
  final tuftGreen = ramp(0xFF7F9A6A);
  each(1, 40, 40, (x, y, k) {
    final onSnow = _snowAt(x, y, look.snow);
    if (onSnow && k >= 14) return;
    final t = onSnow ? tuftGreen : grass;
    p.set(x, y, t[1]);
    p.set(x - 1, y - 1, t[onSnow ? 2 : 1]);
    p.set(x + 1, y - 1, t[onSnow ? 2 : 3]);
  });
  // Primavera: fiorellini.
  each(2, 22, (22 * look.flowers).round(), (x, y, k) {
    if (_snowAt(x, y, look.snow)) return;
    final petal = const [0xFFFFFFFF, 0xFFFFE066, 0xFFF7A8C4, 0xFFC9B6F2][k % 4];
    for (final (dx, dy) in [(0, -1), (-1, 0), (1, 0)]) {
      p.set(x + dx, y + dy, petal);
    }
    p.set(x, y, 0xFFF2B33D);
  });
  // Estate: erba secca e qualche fiore giallo.
  final dry = ramp(0xFFD6C26A);
  each(3, 16, (16 * look.dry).round(), (x, y, k) {
    p.set(x, y, dry[2]);
    p.set(x - 1, y - 1, dry[3]);
    p.set(x + 1, y - 1, dry[2]);
    if (k.isEven) p.set(x + 3, y + 1, 0xFFFFE066);
  });
  // Autunno: foglie cadute.
  each(4, 34, (34 * look.leaves).round(), (x, y, k) {
    if (_snowAt(x, y, look.snow)) return;
    p.set(x, y, const [0xFFE07B2E, 0xFFC4432A, 0xFFE3B23C, 0xFF9A5B30][k % 4]);
    if (k.isOdd) p.set(x + 1, y, const [0xFFE07B2E, 0xFFC4432A][k % 2]);
  });
  // Inverno: mucchietti di neve con l'ombra.
  each(5, 10, look.snow > 0.3 ? (10 * look.snow).round() : 0, (x, y, k) {
    p.set(x, y, snow[4]);
    p.set(x + 1, y, snow[4]);
    p.set(x, y + 1, snow[1]);
    p.set(x + 1, y + 1, snow[1]);
  });
}

(double, double) _freeSpot(IslandGeometry g, math.Random r) {
  for (var i = 0; i < 60; i++) {
    final x = g.cx + (r.nextDouble() * 2 - 1) * g.rx * 0.75, y = g.cy - 2 + (r.nextDouble() * 2 - 1) * g.ry * 0.65;
    var ok = (x - g.cx).abs() > 14 || (y - g.cy).abs() > 8;
    for (var s = 0; s < 12 && ok; s++) {
      final (sx, sy) = g.slot(s);
      if ((sx - x).abs() < 10 && (sy - y).abs() < 6) ok = false;
    }
    if (ok) return (x, y);
  }
  return (g.cx + g.rx * 0.5, g.cy + g.ry * 0.3);
}

/// Ombra a retino sotto una cosa, larga [w].
void _shadow(Px p, double x, double y, double w) {
  for (var yy = (y - 2.5).floor(); yy <= y + 2.5; yy++) {
    for (var xx = (x - w).floor(); xx <= x + w; xx++) {
      if (!_inEll(xx + 0.5, yy + 0.5, x, y + 0.5, w, 2.6)) continue;
      final c = p.get(xx, yy);
      if (c != 0 && dither(xx, yy, 0.6)) p.set(xx, yy, darken(c, 0.22));
    }
  }
}

void _emptySlot(Px p, double x, double y, bool snowy, math.Random r) {
  final tones = snowy ? ramp(0xFF7F9A6A) : ramp(0xFF5E8F45);
  final xi = x.floor(), yi = y.floor();
  for (final (dx, h) in [(-2, 2), (-1, 3), (0, 4), (1, 3), (2, 2)]) {
    for (var k = 0; k < h; k++) {
      if (snowy && k == h - 1) {
        p.set(xi + dx, yi - k, 0xFFF4F8FF);
      } else {
        p.set(xi + dx, yi - k, tones[k == h - 1 ? 3 : 2]);
      }
    }
  }
  if (r.nextBool()) {
    final grey = ramp(0xFFA9A49A);
    p.set(xi + 4, yi, grey[2]);
    p.set(xi + 5, yi, grey[1]);
    p.set(xi + 4, yi - 1, grey[3]);
  }
}

/// Il posto del premio prima della fine dell'anno: un cerchio di sassi.
void _rewardSpot(Px p, double x, double y, bool winter) {
  final ground = ramp(winter ? 0xFFDCE3EC : 0xFFD9C79A);
  p.ellipse(x, y, 9, 4, ground[2]);
  p.ellipse(x, y - 0.6, 7.5, 3, ground[3]);
  final grey = ramp(0xFFA9A49A);
  for (var k = 0; k < 12; k++) {
    final a = k / 12 * 2 * math.pi;
    final sx = (x + math.cos(a) * 9.5).floor(), sy = (y + math.sin(a) * 4.2).floor();
    p.set(sx, sy, grey[2]);
    p.set(sx + 1, sy, grey[1]);
    p.set(sx, sy - 1, winter ? 0xFFF4F8FF : grey[3]);
  }
}

/// Alone caldo di una luce, a bande col retino.
void _glow(Px p, double x, double y, double radius) {
  for (var yy = (y - radius).floor(); yy <= y + radius; yy++) {
    for (var xx = (x - radius).floor(); xx <= x + radius; xx++) {
      final d = math.sqrt((xx + 0.5 - x) * (xx + 0.5 - x) + (yy + 0.5 - y) * (yy + 0.5 - y) * 1.6);
      if (d > radius) continue;
      final t = 1 - d / radius;
      if (t > 0.6 || dither(xx, yy, t * 1.4)) p.blend(xx, yy, 0xFFFFC870, 0.12 + 0.3 * t);
    }
  }
}

// --- Pittori ---------------------------------------------------------------

/// L'isola già disegnata, ingrandita di [scale], con sopra i posti liberi da
/// mettere in evidenza (si sta scegliendo dove piantare).
class IslandPainter extends CustomPainter {
  final IslandSceneSpec spec;
  final double scale;
  final Set<int> highlight;
  final double pulse;
  final Color highlightColor;

  IslandPainter({
    required this.spec,
    required this.scale,
    this.highlight = const {},
    this.pulse = 0,
    this.highlightColor = const Color(0xFF2E7D5B),
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(scale);
    canvas.drawPicture(islandPicture(spec));
    final g = IslandGeometry(spec.width, spec.slots);
    final px = Paint()..isAntiAlias = false;
    void dot(int x, int y, Color c) => canvas.drawRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1), px..color = c);
    final big = pulse > 0.5;
    for (final i in highlight) {
      final (sx, sy) = g.slot(i);
      final rx = big ? 8.5 : 7.5, ry = big ? 3.8 : 3.3;
      for (var y = (sy - ry - 1).floor(); y <= sy + ry + 1; y++) {
        for (var x = (sx - rx - 1).floor(); x <= sx + rx + 1; x++) {
          final e = _e(x + 0.5, y + 0.5, sx, sy, rx, ry);
          if (e <= 1 && e > 0.55) dot(x, y, highlightColor);
          if (e <= 0.55 && dither(x, y, 0.3)) dot(x, y, highlightColor.withValues(alpha: 0.5));
        }
      }
      // Un "+" bianco sopra.
      final (mx, my) = (sx.floor(), (sy - 11).floor());
      for (var y = -4; y <= 4; y++) {
        for (var x = -4; x <= 4; x++) {
          if (x * x + y * y <= 17) dot(mx + x, my + y, const Color(0xF2FFFFFF));
        }
      }
      for (var k = -2; k <= 2; k++) {
        dot(mx + k, my, highlightColor);
        dot(mx, my + k, highlightColor);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(IslandPainter old) =>
      old.spec.key != spec.key ||
      old.scale != scale ||
      old.pulse != pulse ||
      old.highlight.length != highlight.length ||
      !old.highlight.containsAll(highlight) ||
      old.highlightColor != highlightColor;
}

final _thumbs = <String, (ui.Picture, (int, int, int, int))>{};

/// Una pianta da sola, per il catalogo e l'elenco dei mesi: nel mese in cui è
/// più bella, senza neve, ingrandita a pixel interi e appoggiata in basso.
class PlantThumbnailPainter extends CustomPainter {
  final PlantSpecies species;
  final double devicePixelRatio;
  PlantThumbnailPainter(this.species, {required this.devicePixelRatio});

  @override
  void paint(Canvas canvas, Size size) {
    final (picture, bounds) = _thumbs[species.key] ??= () {
      final sprite = plantSprite(species, month: species.best, seed: 7);
      return (sprite.px.toPicture(), sprite.px.bounds() ?? (0, 0, 1, 1));
    }();
    final (x0, y0, x1, y1) = bounds;
    final fit = math.min(size.width / (x1 - x0), size.height / (y1 - y0));
    // Grande: pixel interi, tutti uguali. Piccola (le icone dell'elenco): la
    // misura giusta, se no arrotondando una quercia verrebbe metà di un fiore.
    final k = fit * devicePixelRatio;
    final scale = k >= 3 ? k.floor() / devicePixelRatio : fit;
    canvas.save();
    canvas.translate((size.width - (x1 - x0) * scale) / 2, size.height - (y1 - y0) * scale);
    canvas.scale(scale);
    canvas.translate(-x0.toDouble(), -y0.toDouble());
    canvas.drawPicture(picture);
    canvas.restore();
  }

  @override
  bool shouldRepaint(PlantThumbnailPainter old) => old.species != species || old.devicePixelRatio != devicePixelRatio;
}
