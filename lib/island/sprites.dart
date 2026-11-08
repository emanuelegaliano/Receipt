/// Le piante, i premi e le piccole cose dell'isola in pixel art. Ogni specie
/// è una funzione che disegna su un foglio di 72×80 pixel con la base in
/// (36, 76): chiome fatte di ciuffi di foglie con luce e ombra, tronchi con le
/// radici, frutti grandi messi a distanza tra loro, fiori pixel per pixel.
/// Il mese dà la stagione (foglie, fiori, frutti, neve d'inverno), il seme le
/// piccole differenze tra due piante della stessa specie.
library;

import 'dart:math' as math;

import 'catalog.dart';
import 'pixel.dart';

/// Un disegno con il punto che tocca terra.
class Sprite {
  final Px px;
  final int baseX, baseY;
  const Sprite(this.px, this.baseX, this.baseY);
}

const _w = 72, _h = 80, _bx = 36, _by = 76;

bool _winter(int month) => month == 12 || month <= 2;

class _S {
  final Px p = Px(_w, _h);
  final math.Random r;
  final int month;
  _S(this.r, this.month);
  double rnd(double a, double b) => a + r.nextDouble() * (b - a);
}

bool _ell(double x, double y, double cx, double cy, double rx, double ry) {
  final dx = (x - cx) / rx, dy = (y - cy) / ry;
  return dx * dx + dy * dy <= 1;
}

/// Un ciuffo di foglie: la base, una mezzaluna d'ombra in basso con una riga
/// più scura sul fondo (è lei a staccarlo dal ciuffo sotto) e la luce in alto
/// a sinistra con un riflesso.
void _clump(Px p, double cx, double cy, double r, List<int> tones, int t) {
  for (var y = (cy - r).floor(); y <= (cy + r).ceil(); y++) {
    for (var x = (cx - r).floor(); x <= (cx + r).ceil(); x++) {
      final ux = x + 0.5 - cx, uy = y + 0.5 - cy;
      final d = math.sqrt(ux * ux + uy * uy);
      if (d > r) continue;
      var tone = t;
      if (d > r - 0.8 && uy > r * 0.3) {
        tone = math.max(0, t - 2);
      } else if (d > r - 1.7 && uy * 0.9 + ux * 0.4 > 0) {
        tone = t - 1;
      } else if (ux + uy < -r * 0.5 && d < r - 1.1) {
        tone = math.min(4, t + 1);
      }
      p.set(x, y, tones[tone]);
    }
  }
  p.set((cx - r * 0.45).floor(), (cy - r * 0.5).floor(), tones[math.min(4, t + 2)]);
}

/// Una chioma: ciuffi su una griglia sfalsata dentro [inside] (coordinate
/// relative a [cx], [cy]), disegnati dal basso in alto così che ognuno copra
/// la cima di quello sotto con la sua ombra: le "squame" della pixel art.
/// Quelli in alto a sinistra sono più chiari; [fill] < 1 fa la chioma rada.
void _foliage(
  _S s, {
  required double cx,
  required double cy,
  required double ext,
  required bool Function(double dx, double dy) inside,
  required List<int> tones,
  double cr = 4,
  double? spacing,
  double fill = 1,
}) {
  final step = spacing ?? cr * 1.3;
  final pts = <(double, double)>[];
  var row = 0;
  for (var y = -ext; y <= ext; y += step * 0.78, row++) {
    for (var x = -ext; x <= ext; x += step) {
      final dx = x + (row.isOdd ? step / 2 : 0) + s.rnd(-0.22, 0.22) * step;
      final dy = y + s.rnd(-0.18, 0.18) * step;
      if (inside(dx, dy) && s.r.nextDouble() < fill) pts.add((dx, dy));
    }
  }
  pts.sort((a, b) => (b.$2 - b.$1 * 0.05).compareTo(a.$2 - a.$1 * 0.05));
  for (final (dx, dy) in pts) {
    final light = (-dx * 0.5 - dy * 0.85) / ext + s.rnd(-0.15, 0.15);
    _clump(s.p, cx + dx, cy + dy, cr, tones, light > 0.35 ? 3 : (light > -0.3 ? 2 : 1));
  }
}

/// Tronco da [top] a terra, largo [w0] in basso e [w1] in alto, con le radici
/// che si allargano e la cima spostata di [lean].
void _trunk(
  _S s, {
  required double x,
  required int top,
  required double w0,
  required double w1,
  required List<int> tones,
  double lean = 0,
  bool roots = true,
  int bottom = _by,
}) {
  for (var y = top; y <= bottom; y++) {
    final t = (y - top) / math.max(1, bottom - top);
    var w = w1 + (w0 - w1) * t * t;
    if (roots && t > 0.8) w += (t - 0.8) * 16;
    final cx = x + lean * (1 - t) * (1 - t);
    final l = (cx - w / 2).round(), rr = (cx + w / 2).round();
    for (var px = l; px < rr; px++) {
      final f = (px - l) / math.max(1, rr - l);
      s.p.set(px, y, tones[f < 0.28 ? 3 : (f < 0.62 ? 2 : 1)]);
    }
  }
  // Segni della corteccia.
  for (var i = 0; i < (bottom - top) ~/ 4; i++) {
    final y = top + s.r.nextInt(math.max(1, bottom - top - 3));
    final t = (y - top) / math.max(1, bottom - top);
    final cx = x + lean * (1 - t) * (1 - t);
    final px = (cx + s.rnd(-w1 / 3, w1 / 3)).round();
    s.p.set(px, y, tones[1]);
    s.p.set(px, y + 1, tones[1]);
  }
}

/// Rami spogli che si dividono: restituisce le punte.
List<(double, double)> _branches(
  _S s,
  double x,
  double y,
  double angle,
  double len,
  double width,
  List<int> tones, {
  int depth = 3,
}) {
  final tips = <(double, double)>[];
  void grow(double x, double y, double a, double len, double w, int d) {
    final ex = x + math.cos(a) * len, ey = y + math.sin(a) * len;
    s.p.line(x, y, ex, ey, tones[2], width: w);
    if (w > 1.6) s.p.line(x - 0.6, y - 0.4, ex - 0.6, ey - 0.4, tones[3], width: 1);
    if (d == 0) {
      tips.add((ex, ey));
      return;
    }
    for (final side in [-1.0, 1.0]) {
      grow(ex, ey, a + side * s.rnd(0.35, 0.65), len * s.rnd(0.62, 0.78), math.max(1, w * 0.65), d - 1);
    }
  }

  grow(x, y, angle, len, width, depth);
  return tips;
}

/// Punti nella figura [inside] distanti almeno [minDist] tra loro, per
/// frutti e fiori: niente mucchi a caso. Preferisce quelli davanti (in basso).
List<(double, double)> _spots(
  _S s,
  int n,
  double x0,
  double y0,
  double x1,
  double y1,
  bool Function(double x, double y) inside,
  double minDist,
) {
  final out = <(double, double)>[];
  for (var i = 0; i < 500 && out.length < n; i++) {
    final x = s.rnd(x0, x1), y = s.rnd(y0, y1);
    if (!inside(x, y)) continue;
    // Più facile in basso: i frutti pendono e stanno davanti.
    if (s.r.nextDouble() > 0.35 + 0.65 * (y - y0) / (y1 - y0)) continue;
    if (out.any((o) => (o.$1 - x) * (o.$1 - x) + (o.$2 - y) * (o.$2 - y) < minDist * minDist)) continue;
    out.add((x, y));
  }
  return out;
}

/// Un frutto rotondo (o ovale con [sy]): bordo scuro, ombra in basso a
/// destra, riflesso, picciolo e fogliolina.
void _fruit(Px p, double cx, double cy, double r, List<int> tones, {double sy = 1, int? stem, int? leaf}) {
  final ry = r * sy;
  bool inF(int x, int y) => _ell(x + 0.5, y + 0.5, cx, cy, r, ry);
  for (var y = (cy - ry).floor() - 1; y <= (cy + ry).ceil() + 1; y++) {
    for (var x = (cx - r).floor() - 1; x <= (cx + r).ceil() + 1; x++) {
      if (!inF(x, y)) continue;
      final edge = !inF(x - 1, y) || !inF(x + 1, y) || !inF(x, y - 1) || !inF(x, y + 1);
      final ux = x + 0.5 - cx, uy = y + 0.5 - cy;
      p.set(x, y, edge ? tones[0] : (ux * 0.5 + uy > r * 0.3 ? tones[1] : tones[2]));
    }
  }
  final hx = (cx - r * 0.45).floor(), hy = (cy - ry * 0.45).floor();
  p.set(hx, hy, tones[4]);
  if (r >= 2.5) {
    p.set(hx + 1, hy, tones[3]);
    p.set(hx, hy + 1, tones[3]);
  }
  if (stem != null) {
    final top = (cy - ry).floor();
    p.set(cx.floor(), top - 1, stem);
    if (r >= 2.5) p.set(cx.floor(), top - 2, stem);
    if (leaf != null) {
      p.set(cx.floor() + 1, top - 2, leaf);
      p.set(cx.floor() + 2, top - 2, leaf);
      p.set(cx.floor() + 1, top - 1, darken(leaf, 0.25));
    }
  }
}

/// Fiorellino di cinque pixel a croce.
void _flower(Px p, int x, int y, int petal, int center, {bool big = false}) {
  for (final (dx, dy) in [(0, -1), (-1, 0), (1, 0), (0, 1)]) {
    p.set(x + dx, y + dy, petal);
  }
  if (big) {
    for (final (dx, dy) in [(0, -2), (-2, 0), (2, 0), (0, 2)]) {
      p.set(x + dx, y + dy, petal);
    }
  }
  p.set(x, y, center);
}

/// Neve sulle parti alte: ogni pixel con il vuoto sopra diventa bianco.
void _snow(Px p, math.Random r, {double amount = 0.8}) {
  const white = 0xFFF4F8FF, blue = 0xFFCCDAEA;
  final tops = <(int, int)>[];
  for (var y = 1; y < p.h; y++) {
    for (var x = 0; x < p.w; x++) {
      if (p.opaque(x, y) && !p.opaque(x, y - 1)) tops.add((x, y));
    }
  }
  for (final (x, y) in tops) {
    if (r.nextDouble() > amount) continue;
    p.set(x, y, white);
    if (r.nextDouble() < 0.45 && p.opaque(x, y + 1)) p.set(x, y + 1, blue);
  }
}

enum _Leaf { bare, budding, green, autumn, falling }

_Leaf _leafOf(PlantSpecies s, int month) {
  if (!s.deciduous) return _Leaf.green;
  return switch (month) {
    12 || 1 || 2 => _Leaf.bare,
    3 => _Leaf.budding,
    10 => _Leaf.autumn,
    11 => _Leaf.falling,
    _ => _Leaf.green,
  };
}

/// Verde d'estate, di primavera e colore d'autunno degli alberi che perdono le foglie.
const _seasonal = <String, (int, int, int)>{
  'oak': (0xFF4F7F3A, 0xFF86BC57, 0xFFB8732F),
  'maple': (0xFF578A3C, 0xFF96C75B, 0xFFD2452B),
  'birch': (0xFF86B652, 0xFFB2D77F, 0xFFE2B42A),
  'willow': (0xFF94B254, 0xFFBFD889, 0xFFCBB24A),
  'apple': (0xFF5E973D, 0xFF95C566, 0xFFC9A23A),
  'cherry': (0xFF5A963E, 0xFF94C568, 0xFFD2603A),
  'almond': (0xFF7EA458, 0xFFAACB84, 0xFFC7B15A),
  'fig': (0xFF4B873A, 0xFF8ABF66, 0xFFC2A53E),
  'hydrangea': (0xFF578B48, 0xFF8DBE6E, 0xFF9C8F4A),
};

List<int> _leaves(PlantSpecies s, _Leaf leaf, int evergreen) {
  final f = _seasonal[s.key];
  if (f == null) return ramp(evergreen);
  return ramp(switch (leaf) {
    _Leaf.budding => f.$2,
    _Leaf.autumn || _Leaf.falling => f.$3,
    _ => f.$1,
  });
}

/// Foglie cadute ai piedi dell'albero.
void _fallen(_S s, List<int> tones, int n) {
  for (var i = 0; i < n; i++) {
    final x = (_bx + s.rnd(-16, 16)).round(), y = (_by + s.rnd(-2, 2)).round();
    s.p.set(x, y, tones[s.r.nextBool() ? 2 : 3]);
  }
}

/// Il disegno di [species] nel mese [month].
/// [snow] (0..1) è quanta neve c'è sull'isola: le cime delle piante se ne coprono.
Sprite plantSprite(PlantSpecies species, {required int month, required int seed, double snow = 0}) {
  final s = _S(math.Random(seed * 7919 + species.key.hashCode), month);
  final p = s.p;
  final bloom = species.bloom.contains(month), fruit = species.fruit.contains(month);
  final leaf = _leafOf(species, month);
  var snowy = true;

  switch (species.key) {
    case 'oak':
    case 'maple':
      final bark = ramp(species.key == 'oak' ? 0xFF7A5236 : 0xFF6A4A36);
      // Con le foglie il tronco entra nella chioma.
      _trunk(s, x: 36, top: leaf == _Leaf.bare ? 56 : 49, w0: 10, w1: 7, tones: bark, lean: s.rnd(-1.5, 1.5));
      if (leaf == _Leaf.bare) {
        for (final a in [-2.4, -1.6, -0.8]) {
          _branches(s, 36, 58, a + s.rnd(-0.15, 0.15), 11, 3.4, bark);
        }
        break;
      }
      final tones = _leaves(species, leaf, 0xFF4F7F3A);
      final sparse = leaf == _Leaf.falling || leaf == _Leaf.budding;
      if (sparse) {
        for (final a in [-2.4, -1.6, -0.8]) {
          _branches(s, 36, 58, a, 9, 3, bark, depth: 2);
        }
      }
      final oak = species.key == 'oak';
      bool crown(double dx, double dy) => oak
          ? _ell(dx, dy, 0, 0, 14, 9) ||
                _ell(dx, dy, -9, 4, 7, 5) ||
                _ell(dx, dy, 9, 3, 7.5, 5.5) ||
                _ell(dx, dy, 0, -6, 9, 5)
          : _ell(dx, dy, 0, 0, 12, 10) ||
                _ell(dx, dy, -7, 4, 6.5, 5) ||
                _ell(dx, dy, 7, 4, 6.5, 5) ||
                _ell(dx, dy, 0, -7, 8, 5);
      _foliage(s, cx: 36, cy: 41, ext: 20, inside: crown, tones: tones, cr: 4.4, fill: sparse ? 0.55 : 1);
      if (leaf == _Leaf.falling || leaf == _Leaf.autumn) _fallen(s, tones, leaf == _Leaf.falling ? 12 : 5);
    case 'olive':
      final bark = ramp(0xFF867563);
      _trunk(s, x: 35, top: 52, w0: 5, w1: 3, tones: bark, lean: 5);
      _trunk(s, x: 38, top: 55, w0: 4.5, w1: 2.5, tones: ramp(0xFF7A6A58), lean: -6, roots: false);
      final tones = ramp(0xFF7D9265);
      bool crown(double dx, double dy) =>
          _ell(dx, dy, -9, 2, 7, 4) ||
          _ell(dx, dy, 7, 0, 8, 4.5) ||
          _ell(dx, dy, -1, -5, 7, 4) ||
          _ell(dx, dy, 0, 3, 5, 3);
      _foliage(s, cx: 36, cy: 45, ext: 20, inside: crown, tones: tones, cr: 3.4);
      // Il rovescio argentato delle foglie.
      for (var i = 0; i < 16; i++) {
        final x = (36 + s.rnd(-16, 16)).round(), y = (45 + s.rnd(-8, 6)).round();
        if (p.get(x, y) == tones[2] || p.get(x, y) == tones[3]) p.set(x, y, 0xFFC9D1B4);
      }
      if (fruit) {
        for (final (x, y) in _spots(
          s,
          7,
          20,
          40,
          52,
          52,
          (x, y) => crown(x - 36, y - 45) && p.opaque(x.floor(), y.floor()),
          4,
        )) {
          _fruit(p, x, y, 1.3, ramp(0xFF4A2E4F), sy: 1.35);
        }
      }
    case 'birch':
      final bark = ramp(0xFFE7E3D8);
      _trunk(s, x: 36, top: 34, w0: 3.5, w1: 2.4, tones: bark, roots: false);
      for (var i = 0; i < 7; i++) {
        final y = (s.rnd(38, 74)).round();
        p.set(35, y, 0xFF2D2A2E);
        p.set(36, y, 0xFF2D2A2E);
      }
      if (leaf == _Leaf.bare) {
        for (final a in [-2.1, -1.6, -1.05]) {
          _branches(s, 36, 42, a, 7, 1.4, ramp(0xFF8D7B6A), depth: 2);
        }
        break;
      }
      final tones = _leaves(species, leaf, 0xFF86B652);
      bool crown(double dx, double dy) =>
          _ell(dx, dy, 0, 0, 6, 11) || _ell(dx, dy, -3, 6, 5, 5) || _ell(dx, dy, 4, 5, 4.5, 6);
      _foliage(s, cx: 36, cy: 33, ext: 17, inside: crown, tones: tones, cr: 3.3, fill: leaf == _Leaf.green ? 1 : 0.6);
      if (leaf == _Leaf.falling || leaf == _Leaf.autumn) _fallen(s, tones, 8);
    case 'willow':
      final bark = ramp(0xFF6D5A45);
      _trunk(s, x: 36, top: 46, w0: 6.5, w1: 4.5, tones: bark);
      final tones = leaf == _Leaf.bare ? ramp(0xFF9C8B66) : _leaves(species, leaf, 0xFF94B254);
      if (leaf != _Leaf.bare) {
        _foliage(s, cx: 36, cy: 38, ext: 18, inside: (dx, dy) => _ell(dx, dy, 0, 0, 13, 4.5), tones: tones, cr: 3.6);
      }
      // I rami che pendono.
      final strands = leaf == _Leaf.falling ? 10 : 15;
      for (var i = 0; i < strands; i++) {
        final x0 = 36 - 17 + i * 34 / (strands - 1);
        final side = (x0 - 36).sign;
        final y0 = 39 + (x0 - 36).abs() * 0.18;
        final len = s.rnd(20, 30);
        for (var k = 0; k < len; k++) {
          final t = k / len;
          final x = (x0 + side * t * t * 3.5).floor();
          final y = (y0 + k).floor();
          if (leaf == _Leaf.bare) {
            if (k < len * 0.8) p.set(x, y, tones[1]);
          } else {
            p.set(x, y, tones[k % 3 == 0 ? 3 : 2]);
            p.set(x + 1, y, tones[k % 4 == 0 ? 2 : 1]);
          }
        }
      }
    case 'stonePine':
      final bark = ramp(0xFF8E5B3E);
      _trunk(s, x: 34, top: 30, w0: 4, w1: 2.6, tones: bark, lean: 6);
      p.line(38, 40, 28, 33, bark[2], width: 1.5);
      final tones = ramp(0xFF3E6A3B);
      bool crown(double dx, double dy) =>
          _ell(dx, dy, 0, 0, 17, 3.6) || _ell(dx, dy, -9, 2, 7, 3) || _ell(dx, dy, 8, 1, 8, 3.2);
      _foliage(s, cx: 39, cy: 28, ext: 20, inside: crown, tones: tones, cr: 3.6);
    case 'lemon':
    case 'orange':
    case 'apple':
    case 'cherry':
    case 'fig':
      final key = species.key;
      final bark = ramp(switch (key) {
        'fig' => 0xFF9C9488,
        'cherry' => 0xFF6B4436,
        _ => 0xFF6F5A48,
      });
      final bareNow = leaf == _Leaf.bare && !(key == 'cherry' && bloom);
      _trunk(s, x: 36, top: bareNow ? 59 : 52, w0: 8.5, w1: 6, tones: bark, lean: s.rnd(-1.5, 1.5));
      bool crown(double dx, double dy) =>
          _ell(dx, dy, 0, 0, 12, 9) ||
          _ell(dx, dy, -7, 3, 6, 5) ||
          _ell(dx, dy, 7, 3, 6, 5) ||
          _ell(dx, dy, 0, -5, 7.5, 4.5);
      bool inCrown(double x, double y) => crown(x - 36, y - 46) && p.opaque(x.floor(), y.floor());
      final cherryBlossom = key == 'cherry' && bloom;
      if (leaf == _Leaf.bare && !cherryBlossom) {
        for (final a in [-2.3, -1.6, -0.9]) {
          _branches(s, 36, 60, a, 8, 2.6, bark);
        }
        break;
      }
      if (cherryBlossom) {
        for (final a in [-2.3, -1.6, -0.9]) {
          _branches(s, 36, 60, a, 8, 2.4, bark, depth: 2);
        }
        final pink = ramp(0xFFF2A8C2);
        _foliage(s, cx: 36, cy: 46, ext: 18, inside: crown, tones: pink, cr: 3.8, fill: 0.95);
        for (var i = 0; i < 14; i++) {
          final x = (36 + s.rnd(-14, 14)).round(), y = (46 + s.rnd(-11, 8)).round();
          if (p.opaque(x, y)) p.set(x, y, 0xFFFFF4F8);
        }
        break;
      }
      final sparse = leaf == _Leaf.falling || leaf == _Leaf.budding;
      if (sparse) {
        for (final a in [-2.3, -1.6, -0.9]) {
          _branches(s, 36, 60, a, 8, 2.4, bark, depth: 2);
        }
      }
      final evergreen = switch (key) {
        'lemon' => 0xFF3A7A38,
        'orange' => 0xFF2F6B33,
        _ => 0xFF5E973D,
      };
      final tones = _leaves(species, leaf, evergreen);
      _foliage(
        s,
        cx: 36,
        cy: 46,
        ext: 18,
        inside: crown,
        tones: tones,
        cr: key == 'fig' ? 4.6 : 3.9,
        fill: sparse ? 0.55 : 1,
      );
      if (bloom) {
        final (petal, center) = key == 'apple' ? (0xFFFBEFF2, 0xFFF29BB5) : (0xFFFFFFFF, 0xFFF3E08A);
        for (final (x, y) in _spots(s, 9, 22, 33, 50, 57, inCrown, 4.5)) {
          _flower(p, x.floor(), y.floor(), petal, center);
        }
      }
      if (fruit) {
        switch (key) {
          case 'lemon':
            for (final (x, y) in _spots(s, 5, 24, 39, 48, 57, inCrown, 7)) {
              _fruit(p, x, y, 2.4, ramp(0xFFF2D33B), sy: 1.3, stem: 0xFF4E6B2E);
            }
          case 'orange':
            for (final (x, y) in _spots(s, 5, 24, 39, 48, 57, inCrown, 7.5)) {
              _fruit(p, x, y, 2.8, ramp(0xFFF28C1E), stem: 0xFF4E6B2E);
            }
          case 'apple':
            for (final (x, y) in _spots(s, 4, 24, 39, 48, 57, inCrown, 8.5)) {
              _fruit(p, x, y, 3.2, ramp(0xFFD9342B), stem: 0xFF5A3A22, leaf: 0xFF5E9A3A);
            }
          case 'cherry':
            for (final (x, y) in _spots(s, 5, 24, 41, 48, 57, inCrown, 6)) {
              p.line(x + 1, y - 4, x - 0.5, y - 1, 0xFF4E6B2E);
              p.line(x + 1, y - 4, x + 2.5, y - 1, 0xFF4E6B2E);
              _fruit(p, x - 0.5, y + 0.5, 1.6, ramp(0xFFB0182A));
              _fruit(p, x + 2.7, y + 0.8, 1.6, ramp(0xFFB0182A));
            }
          case 'fig':
            for (final (x, y) in _spots(s, 4, 24, 39, 48, 57, inCrown, 8)) {
              _fruit(p, x, y, 2.2, ramp(0xFF6D3B5C), sy: 1.25, stem: 0xFF4E6B2E);
            }
        }
      }
      if (leaf == _Leaf.falling) _fallen(s, tones, 10);
    case 'almond':
      final bark = ramp(0xFF5E4A3E);
      _trunk(s, x: 36, top: bloom || leaf == _Leaf.bare ? 58 : 50, w0: 6.5, w1: 4.5, tones: bark, lean: 2);
      if (bloom || leaf == _Leaf.bare) {
        final tips = <(double, double)>[];
        for (final a in [-2.35, -1.6, -0.85]) {
          tips.addAll(_branches(s, 36, 59, a + s.rnd(-0.1, 0.1), 9, 2.6, bark));
        }
        if (bloom) {
          for (final (x, y) in tips) {
            for (var i = 0; i < 3; i++) {
              _flower(
                p,
                (x + s.rnd(-2.5, 2.5)).round(),
                (y + s.rnd(-1.5, 2.5)).round(),
                i.isEven ? 0xFFFFF1F4 : 0xFFF7C4D2,
                0xFFE0779A,
              );
            }
          }
        }
        break;
      }
      for (final a in [-2.3, -1.6, -0.9]) {
        _branches(s, 36, 57, a, 7, 2, bark, depth: 2);
      }
      final tones = _leaves(species, leaf, 0xFF7EA458);
      _foliage(
        s,
        cx: 36,
        cy: 44,
        ext: 18,
        inside: (dx, dy) => _ell(dx, dy, 0, 0, 11, 8) || _ell(dx, dy, 0, -5, 7, 5),
        tones: tones,
        cr: 3.4,
        fill: leaf == _Leaf.green ? 0.85 : 0.55,
      );
      if (leaf == _Leaf.falling) _fallen(s, tones, 8);
    case 'fir':
      _trunk(s, x: 36, top: 66, w0: 3, w1: 3, tones: ramp(0xFF5D4037), roots: false);
      final tones = ramp(0xFF2F5E3F);
      for (var i = 0; i < 4; i++) {
        final yb = 70 - i * 10.5, yt = yb - 15, hw = 14.5 - i * 3.1;
        for (var y = yt.floor(); y <= yb.ceil(); y++) {
          final t = (y - yt) / (yb - yt);
          final half = hw * t;
          for (var x = (36 - half).round(); x <= (36 + half).round(); x++) {
            final rel = (x - 36) / math.max(1, half);
            var c = rel < -0.35 ? tones[3] : (rel > 0.4 ? tones[1] : tones[2]);
            if (rel < -0.35 && dither(x, y, 0.4)) c = tones[2];
            // Il bordo in basso a dentelli.
            if (y >= yb.ceil() - 1 && (x + i).isEven) c = tones[1];
            p.set(x, y, c);
          }
        }
      }
    case 'cypress':
      p.rect(35, 72, 38, 77, ramp(0xFF5D4037)[2]);
      final tones = ramp(0xFF2F4F35);
      double half(double y) {
        final t = ((y - 18) / 54).clamp(0, 1).toDouble();
        return 1.2 + 5.2 * math.sin(math.min(1, t * 1.3) * math.pi / 2) - math.max(0, t - 0.88) * 18;
      }

      _foliage(s, cx: 36, cy: 46, ext: 30, inside: (dx, dy) => dx.abs() <= half(46 + dy) - 2.2, tones: tones, cr: 2.9);
    case 'datePalm':
      final bark = ramp(0xFF8D6E4F);
      double xAt(int y) {
        final t = (y - 28) / 48;
        return 34 + 6 * (1 - t) - 1.5 * math.sin(t * math.pi);
      }

      for (var y = 28; y <= _by; y++) {
        final cx = xAt(y), w = 3.6 + (y - 28) / 48 * 1.6;
        for (var x = (cx - w / 2).round(); x < (cx + w / 2).round(); x++) {
          final f = (x - (cx - w / 2)) / w;
          var c = (y % 3 == 0) ? bark[1] : (f < 0.3 ? bark[3] : (f < 0.65 ? bark[2] : bark[1]));
          if (y % 3 == 1 && (x + y ~/ 3).isEven) c = bark[2];
          p.set(x, y, c);
        }
      }
      final top = (xAt(28), 27.0);
      if (fruit) {
        final dates = ramp(0xFFD9822B);
        for (var i = 0; i < 18; i++) {
          final x = (top.$1 + s.rnd(-3.5, 3.5)).round(), y = (top.$2 + 2 + s.rnd(0, 6)).round();
          p.set(x, y, dates[s.r.nextInt(3) + 1]);
        }
      }
      final green = ramp(0xFF4D8B3C);
      // Fronde a piuma: la costola scura e le foglioline che pendono.
      final fronds = [-2.8, -2.25, -1.75, -1.35, -0.9, -0.35, 2.95, 0.2];
      for (final a in fronds) {
        final len = s.rnd(16, 19);
        final droop = 0.55 * math.cos(a).abs() + 0.22;
        (double, double) at(double t) =>
            (top.$1 + math.cos(a) * len * t, top.$2 + math.sin(a) * len * t * 0.7 + droop * len * t * t);
        for (var t = 0.1; t < 0.97; t += 0.075) {
          final (x, y) = at(t);
          final leafLen = 3.4 * (1 - t) + 1.2;
          final side = math.cos(a) >= 0 ? 1.0 : -1.0;
          p.line(x, y, x + side * leafLen * 0.35, y + leafLen, green[((t * 40).round()).isEven ? 2 : 3]);
          p.line(x, y, x - side * leafLen * 0.55, y + leafLen * 0.55, green[1]);
        }
        for (var t = 0.0; t <= 1; t += 0.02) {
          final (x, y) = at(t);
          p.set(x.floor(), y.floor(), t < 0.15 ? green[2] : green[1]);
        }
      }
    case 'fanPalm':
      final bark = ramp(0xFF6F5B44);
      final green = ramp(0xFF5E8E52);
      for (final (x, h) in [(30.0, 14), (41.0, 18), (35.5, 9)]) {
        final topY = _by - h;
        for (var y = topY; y <= _by; y++) {
          p.set(x.floor() - 1, y, bark[3]);
          p.set(x.floor(), y, bark[(y.isEven) ? 2 : 1]);
          p.set(x.floor() + 1, y, bark[1]);
        }
        for (var i = 0; i < 13; i++) {
          final a = -math.pi * 1.08 + i / 12 * math.pi * 1.16;
          final len = 9 + (i.isEven ? 0.8 : 0);
          p.line(
            x,
            topY.toDouble(),
            x + math.cos(a) * len,
            topY + math.sin(a) * len * 0.85,
            green[i % 3 + 1],
            width: 1.6,
          );
        }
      }
    case 'lavender':
      snowy = false;
      final stem = ramp(0xFF8DA08A);
      final tips = <(double, double)>[];
      for (var i = 0; i < 14; i++) {
        final a = -math.pi / 2 + (i / 13 - 0.5) * 1.25;
        final len = (bloom ? s.rnd(13, 17) : s.rnd(7, 10));
        final x0 = 36 + (i / 13 - 0.5) * 6;
        final x1 = x0 + math.cos(a) * len, y1 = 73 + math.sin(a) * len;
        p.line(x0, 73, x1, y1, stem[1]);
        tips.add((x1, y1));
      }
      _foliage(s, cx: 36, cy: 72, ext: 11, inside: (dx, dy) => _ell(dx, dy, 0, 0, 8, 2.2), tones: stem, cr: 2.4);
      if (bloom) {
        final purple = ramp(0xFF8E6BC4);
        for (final (x, y) in tips) {
          for (var k = 0; k < 5; k++) {
            p.set(x.floor(), y.floor() + k, purple[k == 0 ? 4 : (k.isEven ? 2 : 3)]);
            if (k.isOdd) p.set(x.floor() + 1, y.floor() + k, purple[1]);
          }
        }
      }
      if (snow > 0) _snow(p, s.r, amount: 0.5 * snow);
    case 'rosemary':
      final tones = ramp(0xFF4F6E50);
      _foliage(s, cx: 36, cy: 68, ext: 14, inside: (dx, dy) => _ell(dx, dy, 0, 0, 10, 6.5), tones: tones, cr: 2.8);
      for (var i = 0; i < 20; i++) {
        final x = (36 + s.rnd(-10, 10)).round(), y = (66 + s.rnd(-7, 5)).round();
        if (p.opaque(x, y) && p.opaque(x, y - 1)) p.set(x, y - 1, tones[3]);
      }
      if (bloom) {
        for (final (x, y) in _spots(s, 12, 24, 56, 48, 72, (x, y) => p.opaque(x.floor(), y.floor()), 3)) {
          p.set(x.floor(), y.floor(), 0xFFA9C4F0);
          p.set(x.floor() + 1, y.floor(), 0xFF7C9DE0);
        }
      }
    case 'oleander':
      final stem = ramp(0xFF6B5A44);
      for (final x in [33.0, 36.0, 39.0]) {
        p.line(36, 76, x, 60, stem[2]);
      }
      final tones = ramp(0xFF4C7D47);
      _foliage(
        s,
        cx: 36,
        cy: 52,
        ext: 15,
        inside: (dx, dy) => _ell(dx, dy, 0, 0, 9, 11) || _ell(dx, dy, -4, 4, 6, 6) || _ell(dx, dy, 5, 3, 6, 6),
        tones: tones,
        cr: 3,
      );
      if (bloom) {
        final pink = ramp(0xFFF07AA2);
        for (final (x, y) in _spots(s, 7, 24, 38, 48, 62, (x, y) => p.opaque(x.floor(), y.floor()), 5.5)) {
          _flower(p, x.floor(), y.floor(), pink[2], pink[4]);
          _flower(p, x.floor() + 2, y.floor() + 1, pink[3], pink[4]);
        }
      }
    case 'hydrangea':
      if (leaf == _Leaf.bare) {
        final stem = ramp(0xFF8C7A66);
        for (var i = 0; i < 6; i++) {
          final x = 36 + s.rnd(-10, 10), y = s.rnd(58, 64);
          p.line(36 + (x - 36) * 0.3, 76, x, y, stem[2]);
          _fruit(p, x, y, 2.4, ramp(0xFFA58C76));
        }
        break;
      }
      final tones = _leaves(species, leaf, 0xFF578B48);
      _foliage(s, cx: 36, cy: 67, ext: 15, inside: (dx, dy) => _ell(dx, dy, 0, 0, 11, 6), tones: tones, cr: 3.8);
      if (bloom) {
        final spots = _spots(s, 5, 25, 56, 47, 68, (x, y) => p.opaque(x.floor(), y.floor() + 2), 7);
        for (var i = 0; i < spots.length; i++) {
          final (x, y) = spots[i];
          final c = ramp(i.isEven ? 0xFF7FA6E3 : 0xFFA48FE2);
          _fruit(p, x, y - 1, 3.4, c);
          for (var k = 0; k < 6; k++) {
            p.set((x + s.rnd(-2, 2)).floor(), (y - 1 + s.rnd(-2, 2)).floor(), c[3]);
          }
        }
      }
    case 'bougainvillea':
      final stem = ramp(0xFF6B5A44);
      for (final a in [-2.2, -1.57, -0.95]) {
        p.line(36, 76, 36 + math.cos(a) * 6, 76 + math.sin(a) * 9, stem[2], width: 1.5);
      }
      final tones = ramp(0xFF4D873F);
      _foliage(
        s,
        cx: 36,
        cy: 60,
        ext: 15,
        inside: (dx, dy) => _ell(dx, dy, 0, 0, 12, 8),
        tones: tones,
        cr: 3.3,
        fill: 0.92,
      );
      if (bloom) {
        final magenta = ramp(0xFFD8268E);
        for (final (x, y) in _spots(s, 13, 22, 48, 50, 68, (x, y) => p.opaque(x.floor(), y.floor()), 3.6)) {
          for (final (dx, dy) in [(0, 0), (1, 0), (0, 1), (-1, 1)]) {
            p.set(x.floor() + dx, y.floor() + dy, magenta[dx == 0 && dy == 0 ? 3 : 2]);
          }
          p.set(x.floor() + 1, y.floor() + 1, magenta[1]);
        }
      }
    case 'sunflower':
      final leaves = ramp(0xFF5F9440);
      if (bloom || month == 5 || month == 6) {
        for (final (x0, top) in [(33.0, (32.0, 44.0)), (39.0, (41.0, 51.0))]) {
          p.line(x0, 76, top.$1, top.$2, leaves[2], width: 2);
          p.line(x0 - 0.6, 76, top.$1 - 0.6, top.$2, leaves[3]);
          for (var k = 0; k < 3; k++) {
            final y = 72 - k * 8.0, x = x0 + (top.$1 - x0) * (76 - y) / (76 - top.$2);
            final side = k.isEven ? -1.0 : 1.0;
            p.ellipse(x + side * 3, y - 1, 3, 1.6, leaves[k.isEven ? 3 : 2]);
          }
          if (bloom) {
            final yellow = ramp(0xFFF7C51E);
            for (var i = 0; i < 16; i++) {
              final a = i / 16 * 2 * math.pi;
              for (final d in [3.6, 4.6]) {
                p.set((top.$1 + math.cos(a) * d).floor(), (top.$2 + math.sin(a) * d).floor(), yellow[i.isEven ? 2 : 3]);
              }
            }
            final brown = ramp(0xFF5A3A1E);
            p.disc(top.$1, top.$2, 2.8, brown[2]);
            for (var i = 0; i < 6; i++) {
              p.set((top.$1 + s.rnd(-2, 2)).floor(), (top.$2 + s.rnd(-2, 2)).floor(), brown[i.isEven ? 1 : 3]);
            }
          } else {
            _fruit(p, top.$1, top.$2, 2, leaves);
          }
        }
      }
      _foliage(s, cx: 36, cy: 73, ext: 10, inside: (dx, dy) => _ell(dx, dy, 0, 0, 7, 2.2), tones: leaves, cr: 2.6);
    case 'poppy':
    case 'daisy':
      final poppy = species.key == 'poppy';
      final leaves = ramp(poppy ? 0xFF7E9A6A : 0xFF6C9E52);
      if (bloom) {
        final n = poppy ? 5 : 6;
        for (var i = 0; i < n; i++) {
          final x0 = 36 + (i / (n - 1) - 0.5) * 12;
          final height = poppy ? s.rnd(10, 17) : s.rnd(6, 11);
          final tx = x0 + s.rnd(-2, 2), ty = 75 - height;
          p.line(x0, 75, tx, ty, leaves[1]);
          if (poppy) {
            final red = ramp(0xFFE3342F);
            _fruit(p, tx, ty, 2.1, red);
            p.set(tx.floor(), ty.floor(), 0xFF231815);
          } else {
            _flower(p, tx.floor(), ty.floor(), 0xFFF9F9F4, 0xFFF3C623, big: true);
            p.set(tx.floor() + 1, ty.floor() + 1, 0xFFE4E4DC);
          }
        }
      }
      _foliage(
        s,
        cx: 36,
        cy: 73,
        ext: 10,
        inside: (dx, dy) => _ell(dx, dy, 0, 0, 7.5, bloom ? 2 : 3),
        tones: leaves,
        cr: 2.5,
      );
    case 'tulip':
      final leaves = ramp(0xFF6C9A5A);
      if (!bloom && month != 5 && month != 6) {
        // Bulbi sotto terra: una zolla con le punte.
        snowy = false;
        p.ellipse(36, 74, 8, 2.6, ramp(0xFF8B6B4A)[2]);
        p.ellipse(35, 73.5, 5, 1.4, ramp(0xFF8B6B4A)[3]);
        for (final x in [32, 36, 40]) {
          p.set(x, 71, leaves[3]);
        }
        if (snow > 0) _snow(p, s.r, amount: 0.9 * snow);
        break;
      }
      for (var i = 0; i < 5; i++) {
        final x0 = 36 + (i / 4 - 0.5) * 12;
        final a = -math.pi / 2 + (i / 4 - 0.5) * 0.9;
        p.poly([
          (x0 - 1.2, 76),
          (x0 + math.cos(a) * 10, 76 + math.sin(a) * 10),
          (x0 + 1.2, 76),
        ], leaves[i.isEven ? 2 : 3]);
        if (!bloom) continue;
        final h = s.rnd(12, 16), tx = x0 + s.rnd(-1, 1), ty = 76 - h;
        p.line(x0, 76, tx, ty, leaves[1]);
        final cup = ramp((seed + i).isEven ? 0xFFE0322E : 0xFFF5C518);
        final x = tx.floor(), y = ty.floor();
        for (final (dx, dy, t) in [
          (-1, -3, 3), (1, -3, 2), //
          (-1, -2, 3), (0, -2, 2), (1, -2, 2),
          (-1, -1, 3), (0, -1, 2), (1, -1, 1),
          (0, 0, 1),
        ]) {
          p.set(x + dx, y + dy, cup[t]);
        }
      }
    case 'rose':
      final tones = ramp(0xFF3E6B3A);
      if (_winter(month)) {
        final cane = ramp(0xFF6B5D3F);
        for (var i = 0; i < 6; i++) {
          final x = 36 + s.rnd(-9, 9), y = s.rnd(60, 66);
          p.line(36, 76, x, y, cane[2]);
          p.set(((36 + x) / 2).floor() + 1, ((76 + y) / 2).floor(), cane[1]);
        }
        break;
      }
      _foliage(s, cx: 36, cy: 68, ext: 13, inside: (dx, dy) => _ell(dx, dy, 0, 0, 8.5, 5.5), tones: tones, cr: 3.3);
      if (bloom) {
        final red = ramp(0xFFC8213A);
        for (final (x, y) in _spots(s, 5, 25, 58, 47, 72, (x, y) => p.opaque(x.floor(), y.floor() + 2), 5.5)) {
          _fruit(p, x, y, 2.2, red);
          p.set(x.floor(), y.floor(), red[0]);
          p.set(x.floor() + 1, y.floor(), red[1]);
        }
      }
    case 'iris':
      final leaves = ramp(0xFF5D8E6B);
      for (var i = 0; i < 7; i++) {
        final x0 = 36 + (i / 6 - 0.5) * 9;
        final h = s.rnd(11, 17), lean = (i / 6 - 0.5) * 6;
        p.poly([(x0 - 1, 76), (x0 + lean, 76 - h), (x0 + 1.2, 76)], leaves[i.isEven ? 2 : 3]);
      }
      if (bloom) {
        final purple = ramp(0xFF6B4FC8);
        for (final x0 in [32.0, 37.0, 41.0]) {
          final h = s.rnd(19, 23);
          final x = x0.floor(), y = (76 - h).floor();
          p.line(x0, 76, x0, 76 - h + 2, leaves[1]);
          for (final (dx, dy, t) in [
            (0, -3, 4), (-1, -2, 3), (0, -2, 3), (1, -2, 2), // in piedi
            (-2, 0, 2), (-1, 0, 2), (0, 0, 2), (1, 0, 1), (2, 0, 1), // ricadenti
            (-2, 1, 1), (2, 1, 0), (0, -1, 3),
          ]) {
            p.set(x + dx, y + dy, purple[t]);
          }
          p.set(x, y, 0xFFF2C94C);
        }
      }
    case 'jasmine':
      final stem = ramp(0xFF5A5A3A);
      for (final a in [-2.2, -1.57, -0.95]) {
        p.line(36, 76, 36 + math.cos(a) * 4, 76 + math.sin(a) * 6, stem[2]);
      }
      final tones = ramp(0xFF3F6E3A);
      _foliage(
        s,
        cx: 36,
        cy: 64,
        ext: 14,
        inside: (dx, dy) => _ell(dx, dy, 0, 0, 10, 7) || _ell(dx, dy, -3, -5, 5, 4),
        tones: tones,
        cr: 2.9,
        fill: 0.94,
      );
      if (bloom) {
        for (final (x, y) in _spots(s, 11, 24, 50, 48, 70, (x, y) => p.opaque(x.floor(), y.floor()), 3.8)) {
          _flower(p, x.floor(), y.floor(), 0xFFFFFFFF, 0xFFF7E9A8);
          p.set(x.floor() + 1, y.floor() + 1, 0xFFE3E6DE);
        }
        for (final (x, y) in _spots(s, 4, 26, 52, 46, 66, (x, y) => p.opaque(x.floor(), y.floor()), 5)) {
          p.set(x.floor(), y.floor(), 0xFFE9A6BE);
        }
      }
    case 'pricklyPear':
      final green = ramp(0xFF6E9B4C);
      final tops = <(double, double)>[];
      void pad(double bx, double by, double a, double size, int depth) {
        final ux = math.cos(a), uy = math.sin(a);
        final cx = bx + ux * size * 0.52, cy = by + uy * size * 0.52;
        final rx = size * 0.38, ry = size * 0.52;
        for (var y = (cy - size).floor(); y <= (cy + size).ceil(); y++) {
          for (var x = (cx - size).floor(); x <= (cx + size).ceil(); x++) {
            final dx = x + 0.5 - cx, dy = y + 0.5 - cy;
            // Coordinate del cladodio: lungo [a] e di traverso.
            final along = dx * ux + dy * uy, across = -dx * uy + dy * ux;
            final e = (across / rx) * (across / rx) + (along / ry) * (along / ry);
            if (e > 1) continue;
            final t = e > 0.72 ? (across > 0 ? 1 : 2) : (across < -rx * 0.3 ? 3 : 2);
            p.set(x, y, green[t]);
          }
        }
        for (var i = 0; i < 4; i++) {
          p.set((cx + s.rnd(-rx, rx) * 0.6).floor(), (cy + s.rnd(-ry, ry) * 0.6).floor(), 0xFFEDE6C4);
        }
        final tx = bx + ux * size * 1.0, ty = by + uy * size * 1.0;
        if (depth == 0) {
          tops.add((tx, ty));
          return;
        }
        pad(tx, ty, a - s.rnd(0.4, 0.6), size * 0.8, depth - 1);
        if (depth == 2 || s.r.nextBool()) pad(tx, ty, a + s.rnd(0.4, 0.6), size * 0.78, depth - 1);
      }

      pad(36, 77, -math.pi / 2, 14, 2);
      for (final (x, y) in tops) {
        if (bloom) {
          _flower(p, x.floor(), y.floor(), 0xFFF5CF3B, 0xFFE0A526, big: true);
        } else if (fruit) {
          _fruit(p, x - 1.5, y + 0.5, 1.4, ramp(0xFFE1573A), sy: 1.4);
          _fruit(p, x + 1.8, y + 1, 1.4, ramp(0xFFE1573A), sy: 1.4);
        }
      }
    case 'agave':
    case 'aloe':
      final agave = species.key == 'agave';
      final tones = ramp(agave ? 0xFF7EA295 : 0xFF6F9A58);
      if (!agave && bloom) {
        final red = ramp(0xFFE85A2C);
        for (final (x, h) in [(33.0, 24), (39.0, 20)]) {
          p.line(36, 72, x, 72.0 - h, ramp(0xFF6F7F4A)[2]);
          for (var k = 0; k < 7; k++) {
            final half = k / 7 * 1.8;
            for (var dx = -half.round(); dx <= half.round(); dx++) {
              p.set(x.floor() + dx, 72 - h + k, red[dx < 0 ? 3 : (dx > 0 ? 1 : 2)]);
            }
          }
          p.set(x.floor(), 72 - h - 1, 0xFFF2C94C);
        }
      }
      final n = agave ? 11 : 9;
      final angles = [for (var i = 0; i < n; i++) -math.pi + (i + 0.5) / n * math.pi];
      // Prima quelle di lato, poi quelle dritte, poi due davanti.
      angles.sort((a, b) => (b + math.pi / 2).abs().compareTo((a + math.pi / 2).abs()));
      final front = agave ? [2.6, 0.55] : [2.5, 0.65];
      for (final a in [...angles, ...front]) {
        final isFront = front.contains(a);
        final len = (agave ? 17 : 11) * (1 - math.cos(a).abs() * 0.3) * (isFront ? 0.55 : s.rnd(0.9, 1.08));
        final hw = agave ? 2.2 : 2.6;
        final bx = 36.0, by = 73.0;
        final tx = bx + math.cos(a) * len, ty = by + math.sin(a) * len * (isFront ? 0.5 : 1);
        final nx = -math.sin(a), ny = math.cos(a);
        p.poly([(bx + nx * hw, by + ny * hw), (tx, ty), (bx - nx * hw, by - ny * hw)], tones[isFront ? 3 : 2]);
        p.line(bx - nx * hw * 0.5, by - ny * hw * 0.5, tx, ty, tones[3]);
        p.set(tx.floor(), ty.floor(), tones[0]);
        if (!agave) {
          p.set((bx + (tx - bx) * 0.5).floor(), (by + (ty - by) * 0.5).floor(), tones[4]);
        }
      }
    case 'cactus':
      final green = ramp(0xFF4E8B4A);
      void column(int x0, int x1, int y0, int y1) {
        for (var y = y0; y <= y1; y++) {
          for (var x = x0; x <= x1; x++) {
            final f = (x - x0) / math.max(1, x1 - x0);
            // Cima arrotondata.
            if (y - y0 < 2 && (x == x0 || x == x1)) continue;
            var c = f < 0.3 ? green[3] : (f < 0.7 ? green[2] : green[1]);
            if ((x - x0) % 2 == 1 && f > 0.15 && f < 0.85) c = darken(c, 0.12);
            p.set(x, y, c);
          }
        }
      }

      column(33, 39, 40, 76);
      column(27, 30, 47, 60);
      p.rect(27, 57, 34, 61, green[2]);
      p.rect(27, 60, 34, 61, green[1]);
      column(42, 45, 42, 54);
      p.rect(39, 51, 46, 55, green[2]);
      p.rect(39, 54, 46, 55, green[1]);
      for (var i = 0; i < 14; i++) {
        final y = s.r.nextInt(30) + 44;
        p.set(s.r.nextBool() ? 32 : 40, y, 0xFFE8E3C0);
      }
      if (bloom) {
        final pink = ramp(0xFFF0679A);
        for (final (x, y) in [(36, 39), (28, 46), (43, 41)]) {
          _flower(p, x, y, pink[2], pink[4]);
        }
      }
  }

  if (snowy && snow > 0) _snow(p, s.r, amount: 0.8 * snow);
  p.outline((n) => darken(n, 0.6));
  return Sprite(p, _bx, _by);
}

/// Il premio al centro dell'isola. Con [lit] il faro è acceso.
Sprite centerpieceSprite(String key, {bool lit = false}) {
  final s = _S(math.Random(key.hashCode), 6);
  final p = s.p;
  final stone = ramp(0xFFBDB6A8), marble = ramp(0xFFEFEBE2);
  switch (key) {
    case 'lighthouse':
      _foliage(
        s,
        cx: 36,
        cy: 73,
        ext: 14,
        inside: (dx, dy) => _ell(dx, dy, 0, 0, 10, 2.5),
        tones: ramp(0xFF8D8A85),
        cr: 3.2,
      );
      final white = ramp(0xFFF2EFE6), red = ramp(0xFFC0392B);
      for (var y = 30; y <= 71; y++) {
        final hw = 6.5 - (71 - y) / 41 * 2.6;
        final band = (y >= 60 && y <= 65) || (y >= 48 && y <= 53) || (y >= 36 && y <= 41);
        final tones = band ? red : white;
        for (var x = (36 - hw).round(); x < (36 + hw).round(); x++) {
          final f = (x - (36 - hw)) / (2 * hw);
          p.set(x, y, tones[f < 0.22 ? 3 : (f < 0.6 ? 2 : 1)]);
        }
      }
      p.rect(35, 66, 38, 72, 0xFF4A3B34);
      p.set(36, 56, 0xFF37474F);
      p.set(36, 44, 0xFF37474F);
      p.rect(28, 28, 45, 30, 0xFF37474F);
      for (var x = 28; x < 45; x += 2) {
        p.set(x, 27, 0xFF37474F);
      }
      p.rect(31, 20, 42, 28, 0xFF37474F);
      p.rect(32, 21, 41, 27, lit ? 0xFFFFE08A : 0xFFBFE3F2);
      if (!lit) p.rect(32, 21, 34, 27, 0xFFE4F4FA);
      p.rect(36, 21, 37, 27, 0xFF37474F);
      final roof = ramp(0xFFA93226);
      p.poly([(30, 20), (36.5, 13), (43, 20)], roof[2]);
      p.poly([(36.5, 13), (43, 20), (37, 20)], roof[1]);
      p.set(36, 12, roof[1]);
    case 'fountain':
      final water = ramp(0xFF6CC3E8);
      p.rect(21, 66, 52, 74, stone[2]);
      p.rect(21, 72, 52, 74, stone[1]);
      p.ellipse(36.5, 74, 15.5, 2.5, stone[1]);
      p.ellipse(36.5, 66, 15.5, 5, stone[3]);
      p.ellipse(36.5, 66, 13, 3.6, water[2]);
      for (var i = 0; i < 8; i++) {
        p.set((36 + s.rnd(-10, 10)).round(), (66 + s.rnd(-2, 2)).round(), water[4]);
      }
      p.rect(34, 48, 39, 66, stone[2]);
      p.rect(34, 48, 35, 66, stone[3]);
      p.rect(38, 48, 39, 66, stone[1]);
      p.ellipse(36.5, 50, 7, 2.2, stone[3]);
      p.rect(30, 50, 44, 52, stone[2]);
      p.ellipse(36.5, 49.5, 5.5, 1.4, water[2]);
      for (var y = 40; y < 50; y++) {
        p.set(36, y, water[y.isEven ? 3 : 4]);
      }
      for (final side in [-1.0, 1.0]) {
        for (var t = 0.0; t <= 1; t += 0.05) {
          p.set((36.5 + side * t * 8).floor(), (41 + t * t * 9 - t * 3).floor(), water[3]);
          p.set((36.5 + side * (7 + t * 5)).floor(), (51 + t * t * 13).floor(), water[t < 0.5 ? 4 : 3]);
        }
      }
    case 'temple':
      for (final (x0, x1, y0, y1) in [(14, 59, 72, 77), (16, 57, 69, 72), (18, 55, 66, 69)]) {
        p.rect(x0, y0, x1, y1, marble[2]);
        p.rect(x0, y0, x1, y0 + 1, marble[3]);
      }
      p.rect(21, 40, 52, 66, ramp(0xFF8A8172)[1]);
      for (final x in [20, 29, 38, 47]) {
        p.rect(x, 42, x + 5, 66, marble[2]);
        p.rect(x, 42, x + 1, 66, marble[3]);
        p.rect(x + 4, 42, x + 5, 66, marble[1]);
        p.rect(x - 1, 40, x + 6, 42, marble[3]);
      }
      p.rect(17, 34, 56, 40, marble[2]);
      p.rect(17, 38, 56, 40, marble[1]);
      p.poly([(15, 34), (36.5, 21), (58, 34)], marble[3]);
      p.poly([(21, 33), (36.5, 24.5), (52, 33)], marble[1]);
    case 'statue':
      p.rect(27, 56, 46, 77, stone[2]);
      p.rect(27, 56, 29, 77, stone[3]);
      p.rect(43, 56, 46, 77, stone[1]);
      p.rect(25, 54, 48, 57, stone[3]);
      p.poly([(30, 55), (33, 40), (40, 40), (43, 55)], marble[2]);
      for (final x in [33, 36, 39]) {
        p.line(x + 0.5, 42, x + (x - 36) * 0.5 + 0.5, 54, marble[1]);
      }
      p.rect(33, 37, 40, 42, marble[2]);
      p.disc(36.5, 34, 2.8, marble[3]);
      p.line(39, 39, 44, 28, marble[2], width: 2);
      p.line(34, 39, 31, 47, marble[2], width: 2);
      final laurel = ramp(0xFF7C9A4E);
      for (var i = 0; i < 12; i++) {
        final a = i / 12 * 2 * math.pi;
        p.set((45 + math.cos(a) * 2.6).floor(), (25 + math.sin(a) * 2.6).floor(), laurel[i.isEven ? 2 : 3]);
      }
    default: // obelisco
      final sand = ramp(0xFFD8C39B);
      p.rect(29, 70, 45, 77, sand[1]);
      p.rect(29, 70, 45, 71, sand[2]);
      p.poly([(32, 70), (33.5, 24), (39.5, 24), (41, 70)], sand[2]);
      p.poly([(32, 70), (33.5, 24), (35, 24), (34.5, 70)], sand[3]);
      p.poly([(38.5, 70), (38, 24), (39.5, 24), (41, 70)], sand[1]);
      final gold = ramp(0xFFE2B84F);
      p.poly([(33.5, 24), (36.5, 17), (39.5, 24)], gold[2]);
      p.poly([(36.5, 17), (39.5, 24), (37, 24)], gold[1]);
      for (var y = 30; y < 66; y += 6) {
        p.set(36, y, sand[0]);
        p.set(37, y + 1, sand[0]);
        p.set(36, y + 3, sand[0]);
      }
  }
  p.outline((n) => darken(n, 0.6));
  return Sprite(p, _bx, _by);
}

/// Lanterna su un palo; [lit] di notte.
Sprite lanternSprite({required bool lit, bool snow = false}) {
  final p = Px(13, 26);
  final iron = ramp(0xFF3B3532);
  p.rect(6, 8, 8, 24, iron[2]);
  p.rect(6, 8, 7, 24, iron[3]);
  p.rect(4, 23, 10, 25, iron[1]);
  p.rect(4, 3, 10, 10, iron[1]);
  p.rect(5, 4, 9, 9, lit ? 0xFFFFD27A : 0xFFF1E8C8);
  if (lit) p.rect(5, 4, 7, 6, 0xFFFFF2C2);
  p.poly([(3, 3.5), (7, 0), (11, 3.5)], iron[2]);
  if (snow) {
    for (var x = 4; x < 10; x++) {
      p.set(x, 1 + (x - 7).abs() ~/ 2, 0xFFF4F8FF);
    }
  }
  p.outline((n) => darken(n, 0.6));
  return Sprite(p, 7, 24);
}

/// Funghetto d'autunno (rosso a pois o marrone).
Sprite mushroomSprite({required bool red}) {
  final p = Px(9, 9);
  final cap = ramp(red ? 0xFFD03A2E : 0xFF9A6A3E);
  p.rect(3, 4, 6, 8, 0xFFEDE3CF);
  p.rect(5, 4, 6, 8, 0xFFCFC3AA);
  for (var y = 1; y < 5; y++) {
    final hw = [1.5, 2.6, 3.2, 3.5][y - 1];
    for (var x = (4.5 - hw).round(); x < (4.5 + hw).round(); x++) {
      p.set(x, y, cap[x < 4 ? 3 : 2]);
    }
  }
  if (red) {
    p.set(3, 2, 0xFFFFFFFF);
    p.set(6, 3, 0xFFFFFFFF);
  }
  p.outline((n) => darken(n, 0.6));
  return Sprite(p, 4, 8);
}

/// Sasso della spiaggia, con la neve d'inverno.
Sprite rockSprite(int seed, {bool snow = false}) {
  final r = math.Random(seed);
  final p = Px(12, 9);
  final grey = ramp(0xFF9E9A92);
  final rx = 3.5 + r.nextDouble() * 1.5;
  for (var y = 1; y < 8; y++) {
    for (var x = 0; x < 12; x++) {
      if (!_ell(x + 0.5, y + 0.5, 6, 5, rx, 3.2)) continue;
      p.set(x, y, grey[y < 4 ? 3 : (x > 6 ? 1 : 2)]);
    }
  }
  if (snow) {
    for (var x = 0; x < 12; x++) {
      for (var y = 0; y < 9; y++) {
        if (p.opaque(x, y)) {
          p.set(x, y, 0xFFF4F8FF);
          break;
        }
      }
    }
  }
  p.outline((n) => darken(n, 0.6));
  return Sprite(p, 6, 8);
}
