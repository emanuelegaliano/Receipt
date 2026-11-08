/// Un piccolo foglio di pixel art: si disegna pixel per pixel (cerchi,
/// ellissi, linee, poligoni senza antialias), poi si mostra ingrandito a
/// multipli interi dei pixel dello schermo, così ogni pixel resta un quadrato
/// netto.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Colori ARGB a 32 bit; 0 è trasparente.
class Px {
  final int w, h;
  final Uint32List data;
  Px(this.w, this.h) : data = Uint32List(w * h);

  bool has(int x, int y) => x >= 0 && y >= 0 && x < w && y < h;
  int get(int x, int y) => has(x, y) ? data[y * w + x] : 0;
  bool opaque(int x, int y) => get(x, y) != 0;

  void set(int x, int y, int c) {
    if (has(x, y) && c != 0) data[y * w + x] = c;
  }

  /// [c] sopra il pixel con opacità [a] (0..1). Su un pixel vuoto lo mette così com'è.
  void blend(int x, int y, int c, double a) {
    if (!has(x, y) || a <= 0) return;
    final under = data[y * w + x];
    data[y * w + x] = under == 0 ? c : mix(under, c, a.clamp(0, 1).toDouble());
  }

  void rect(int x0, int y0, int x1, int y1, int c) {
    for (var y = y0; y < y1; y++) {
      for (var x = x0; x < x1; x++) {
        set(x, y, c);
      }
    }
  }

  /// I pixel il cui centro è nell'ellisse.
  void ellipse(double cx, double cy, double rx, double ry, int c) {
    if (rx <= 0 || ry <= 0) return;
    for (var y = (cy - ry).floor(); y <= (cy + ry).ceil(); y++) {
      for (var x = (cx - rx).floor(); x <= (cx + rx).ceil(); x++) {
        final dx = (x + 0.5 - cx) / rx, dy = (y + 0.5 - cy) / ry;
        if (dx * dx + dy * dy <= 1) set(x, y, c);
      }
    }
  }

  void disc(double cx, double cy, double r, int c) => ellipse(cx, cy, r, r, c);

  /// Linea larga [width] (1 = un pixel).
  void line(double x0, double y0, double x1, double y1, int c, {double width = 1}) {
    final len = math.sqrt((x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0));
    final steps = math.max(1, (len * 2.5).ceil());
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final x = x0 + (x1 - x0) * t, y = y0 + (y1 - y0) * t;
      if (width <= 1.01) {
        set(x.floor(), y.floor(), c);
      } else {
        disc(x, y, width / 2, c);
      }
    }
  }

  /// Poligono pieno (regola pari/dispari, sui centri dei pixel).
  void poly(List<(double, double)> pts, int c) {
    if (pts.length < 3) return;
    final minY = pts.map((p) => p.$2).reduce(math.min).floor();
    final maxY = pts.map((p) => p.$2).reduce(math.max).ceil();
    for (var y = minY; y <= maxY; y++) {
      final sy = y + 0.5;
      final xs = <double>[];
      for (var i = 0; i < pts.length; i++) {
        final (ax, ay) = pts[i];
        final (bx, by) = pts[(i + 1) % pts.length];
        if ((ay <= sy && by > sy) || (by <= sy && ay > sy)) xs.add(ax + (sy - ay) / (by - ay) * (bx - ax));
      }
      xs.sort();
      for (var i = 0; i + 1 < xs.length; i += 2) {
        for (var x = (xs[i] - 0.5).ceil(); x <= (xs[i + 1] - 0.5).floor(); x++) {
          set(x, y, c);
        }
      }
    }
  }

  /// Copia [s] con l'angolo in alto a sinistra in ([ox], [oy]); i pixel vuoti di [s] non coprono.
  void stamp(Px s, int ox, int oy) {
    for (var y = 0; y < s.h; y++) {
      for (var x = 0; x < s.w; x++) {
        final c = s.data[y * s.w + x];
        if (c != 0) set(ox + x, oy + y, c);
      }
    }
  }

  /// Un bordo di un pixel attorno alla figura: ogni pixel vuoto accanto a uno
  /// pieno prende il colore che [color] dà a quel vicino.
  void outline(int Function(int neighbour) color) {
    final copy = Uint32List.fromList(data);
    int at(int x, int y) => has(x, y) ? copy[y * w + x] : 0;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (copy[y * w + x] != 0) continue;
        // Prima sotto e ai lati: il bordo in basso è quello che conta.
        final n = at(x, y - 1) != 0
            ? at(x, y - 1)
            : at(x - 1, y) != 0
            ? at(x - 1, y)
            : at(x + 1, y) != 0
            ? at(x + 1, y)
            : at(x, y + 1);
        if (n != 0) data[y * w + x] = color(n);
      }
    }
  }

  /// Cambia ogni pixel pieno.
  void map(int Function(int c, int x, int y) f) {
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final c = data[y * w + x];
        if (c != 0) data[y * w + x] = f(c, x, y);
      }
    }
  }

  /// Il rettangolo dei pixel pieni (sinistra, alto, destra, basso esclusi), null se vuoto.
  (int, int, int, int)? bounds() {
    var x0 = w, y0 = h, x1 = -1, y1 = -1;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (data[y * w + x] == 0) continue;
        x0 = math.min(x0, x);
        x1 = math.max(x1, x);
        y0 = math.min(y0, y);
        y1 = math.max(y1, y);
      }
    }
    return x1 < 0 ? null : (x0, y0, x1 + 1, y1 + 1);
  }

  /// I pixel come disegno, un pixel = un quadrato di lato 1: si ingrandisce
  /// con canvas.scale. Un drawRawPoints per colore.
  ui.Picture toPicture() {
    final byColor = <int, List<double>>{};
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final c = data[y * w + x];
        if (c != 0) (byColor[c] ??= []).addAll([x + 0.5, y + 0.5]);
      }
    }
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    for (final e in byColor.entries) {
      canvas.drawRawPoints(
        ui.PointMode.points,
        Float32List.fromList(e.value),
        ui.Paint()
          ..color = ui.Color(e.key)
          ..strokeWidth = 1
          ..strokeCap = ui.StrokeCap.square
          ..isAntiAlias = false,
      );
    }
    return recorder.endRecording();
  }
}

// --- Colori ----------------------------------------------------------------

int _r(int c) => (c >> 16) & 0xFF;
int _g(int c) => (c >> 8) & 0xFF;
int _b(int c) => c & 0xFF;
int rgb(int r, int g, int b) => 0xFF000000 | (r.clamp(0, 255) << 16) | (g.clamp(0, 255) << 8) | b.clamp(0, 255);

int mix(int a, int b, double t) => rgb(
  (_r(a) + (_r(b) - _r(a)) * t).round(),
  (_g(a) + (_g(b) - _g(a)) * t).round(),
  (_b(a) + (_b(b) - _b(a)) * t).round(),
);

/// Più scuro verso un viola profondo, come si fa nella pixel art (le ombre
/// non sono grigie).
int darken(int c, double t) => mix(c, 0xFF1C1430, t);

/// Più chiaro verso un bianco caldo.
int lighten(int c, double t) => mix(c, 0xFFFFF6D8, t);

(double, double, double) _hsv(int c) {
  final r = _r(c) / 255, g = _g(c) / 255, b = _b(c) / 255;
  final mx = math.max(r, math.max(g, b)), mn = math.min(r, math.min(g, b));
  final d = mx - mn;
  var h = 0.0;
  if (d > 0) {
    if (mx == r) {
      h = 60 * (((g - b) / d) % 6);
    } else if (mx == g) {
      h = 60 * ((b - r) / d + 2);
    } else {
      h = 60 * ((r - g) / d + 4);
    }
  }
  return ((h + 360) % 360, mx == 0 ? 0 : d / mx, mx);
}

int _fromHsv(double h, double s, double v) {
  s = s.clamp(0, 1);
  v = v.clamp(0, 1);
  final c = v * s, x = c * (1 - ((h / 60) % 2 - 1).abs()), m = v - c;
  final (r, g, b) = switch ((h % 360) ~/ 60) {
    0 => (c, x, 0.0),
    1 => (x, c, 0.0),
    2 => (0.0, c, x),
    3 => (0.0, x, c),
    4 => (x, 0.0, c),
    _ => (c, 0.0, x),
  };
  return rgb(((r + m) * 255).round(), ((g + m) * 255).round(), ((b + m) * 255).round());
}

double _towards(double h, double target, double amount) {
  var d = (target - h + 540) % 360 - 180;
  if (d.abs() < amount) return target;
  return (h + d.sign * amount + 360) % 360;
}

/// Cinque toni da [base]: 0 il bordo, 1 l'ombra, 2 la base, 3 la luce, 4 il
/// riflesso. Le ombre girano verso il blu, le luci verso il giallo.
List<int> ramp(int base) {
  final (h, s, v) = _hsv(base);
  final grey = s < 0.08;
  double hue(double target, double amount) => grey ? h : _towards(h, target, amount);
  return [
    _fromHsv(hue(250, 28), grey ? s : s * 0.9 + 0.1, v * 0.36),
    _fromHsv(hue(250, 14), grey ? s : s * 0.95 + 0.05, v * 0.66),
    base,
    _fromHsv(hue(55, 10), s * 0.85, v * 1.12 + 0.04),
    _fromHsv(hue(55, 22), s * 0.6, v * 1.25 + 0.1),
  ];
}

const _bayer = [
  [0, 8, 2, 10],
  [12, 4, 14, 6],
  [3, 11, 1, 9],
  [15, 7, 13, 5],
];

/// Retino ordinato 4×4: vero in una frazione [t] dei pixel, distribuiti a scacchiera.
bool dither(int x, int y, double t) => t * 16 > _bayer[y & 3][x & 3] + 0.5;
