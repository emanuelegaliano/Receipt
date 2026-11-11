// clipperOffsetRound is ported from Clipper 6.4.2 (http://www.angusj.com),
// Copyright Angus Johnson 2010-2017, under the Boost Software License 1.0
// (see NOTICES). Changed for Receipt: translated from C++ to
// Dart, only the round offset of a closed polygon. orderMiniBox and
// orderPointsClockwise follow RapidOCR 1.4.4 (https://github.com/RapidAI/RapidOCR),
// derived from PaddleOCR: Copyright (c) 2020 PaddlePaddle Authors, Apache
// License 2.0 (see NOTICES).

import 'dart:math' as math;

class Point2 {
  final double x;
  final double y;
  const Point2(this.x, this.y);

  Point2 operator -(Point2 o) => Point2(x - o.x, y - o.y);
  Point2 operator +(Point2 o) => Point2(x + o.x, y + o.y);
  Point2 scale(double k) => Point2(x * k, y * k);
  double distanceTo(Point2 o) => math.sqrt((x - o.x) * (x - o.x) + (y - o.y) * (y - o.y));

  @override
  String toString() => '(${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)})';
}

/// Rettangolo ruotato: i 4 vertici in ordine lungo il perimetro e i lati.
class RotatedRect {
  final List<Point2> corners;
  final double width;
  final double height;
  const RotatedRect(this.corners, this.width, this.height);

  double get shortSide => math.min(width, height);
}

double _cross(Point2 o, Point2 a, Point2 b) =>
    (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x);

/// Inviluppo convesso (monotone chain), senza punti collineari.
List<Point2> convexHull(List<Point2> points) {
  final pts = [...points]..sort((a, b) => a.x != b.x ? a.x.compareTo(b.x) : a.y.compareTo(b.y));
  if (pts.length < 3) return pts;
  final lower = <Point2>[];
  for (final p in pts) {
    while (lower.length >= 2 && _cross(lower[lower.length - 2], lower.last, p) <= 0) {
      lower.removeLast();
    }
    lower.add(p);
  }
  final upper = <Point2>[];
  for (final p in pts.reversed) {
    while (upper.length >= 2 && _cross(upper[upper.length - 2], upper.last, p) <= 0) {
      upper.removeLast();
    }
    upper.add(p);
  }
  lower.removeLast();
  upper.removeLast();
  return [...lower, ...upper];
}

/// Rettangolo di area minima che contiene i punti (equivalente a
/// cv2.minAreaRect + cv2.boxPoints), con rotating calipers sull'inviluppo.
RotatedRect minAreaRect(List<Point2> points) {
  final hull = convexHull(points);
  if (hull.isEmpty) return const RotatedRect([], 0, 0);
  if (hull.length == 1) {
    final p = hull.first;
    return RotatedRect([p, p, p, p], 0, 0);
  }
  if (hull.length == 2) {
    final a = hull[0], b = hull[1];
    return RotatedRect([a, b, b, a], a.distanceTo(b), 0);
  }

  var bestArea = double.infinity;
  late RotatedRect best;
  for (var i = 0; i < hull.length; i++) {
    final a = hull[i];
    final b = hull[(i + 1) % hull.length];
    final len = a.distanceTo(b);
    if (len == 0) continue;
    final ux = (b.x - a.x) / len, uy = (b.y - a.y) / len; // asse lungo il lato
    final vx = -uy, vy = ux; // asse perpendicolare
    var minU = double.infinity, maxU = -double.infinity;
    var minV = double.infinity, maxV = -double.infinity;
    for (final p in hull) {
      final u = p.x * ux + p.y * uy;
      final v = p.x * vx + p.y * vy;
      if (u < minU) minU = u;
      if (u > maxU) maxU = u;
      if (v < minV) minV = v;
      if (v > maxV) maxV = v;
    }
    final area = (maxU - minU) * (maxV - minV);
    if (area < bestArea) {
      bestArea = area;
      Point2 at(double u, double v) => Point2(u * ux + v * vx, u * uy + v * vy);
      best = RotatedRect(
        [at(minU, minV), at(maxU, minV), at(maxU, maxV), at(minU, maxV)],
        maxU - minU,
        maxV - minV,
      );
    }
  }
  return best;
}

/// Porta di RapidOCR `get_mini_boxes`: ordina i vertici in tl, tr, br, bl.
List<Point2> orderMiniBox(List<Point2> corners) {
  final p = [...corners]..sort((a, b) => a.x.compareTo(b.x));
  final int i1, i2, i3, i4;
  if (p[1].y > p[0].y) {
    i1 = 0;
    i4 = 1;
  } else {
    i1 = 1;
    i4 = 0;
  }
  if (p[3].y > p[2].y) {
    i2 = 2;
    i3 = 3;
  } else {
    i2 = 3;
    i3 = 2;
  }
  return [p[i1], p[i2], p[i3], p[i4]];
}

/// Porta di `order_points_clockwise` (imutils): tl, tr, br, bl.
List<Point2> orderPointsClockwise(List<Point2> pts) {
  final xs = [...pts]..sort((a, b) => a.x.compareTo(b.x));
  final left = [xs[0], xs[1]]..sort((a, b) => a.y.compareTo(b.y));
  final right = [xs[2], xs[3]]..sort((a, b) => a.y.compareTo(b.y));
  return [left[0], right[0], right[1], left[1]];
}

/// Arrotondamento di Clipper (metà lontano da zero).
int _clipperRound(double v) => v < 0 ? (v - 0.5).truncate() : (v + 0.5).truncate();

/// Offset di un poligono chiuso con giunzioni arrotondate, porta di
/// ClipperOffset (Clipper 6.4, JT_ROUND, ET_CLOSEDPOLYGON, ArcTolerance 0.25)
/// come lo usa pyclipper in `unclip` di RapidOCR. Le coordinate in ingresso
/// vengono troncate a intero come fa pyclipper; i punti restituiti sono interi.
/// Restituisce i vertici prima dell'unione finale di Clipper, che non cambia
/// l'inviluppo convesso (è tutto ciò che serve a minAreaRect).
List<Point2> clipperOffsetRound(List<Point2> polygon, double delta) {
  // AddPath: troncamento a intero e rimozione dei duplicati consecutivi.
  var src = <(int, int)>[];
  for (final p in polygon) {
    final q = (p.x.truncate(), p.y.truncate());
    if (src.isEmpty || src.last != q) src.add(q);
  }
  if (src.length > 1 && src.first == src.last) src.removeLast();
  if (src.length < 3) return [for (final p in src) Point2(p.$1.toDouble(), p.$2.toDouble())];

  // FixOrientations: Clipper vuole l'orientamento con area >= 0.
  var area = 0.0;
  for (var i = 0; i < src.length; i++) {
    final a = src[i], b = src[(i + 1) % src.length];
    area += (a.$1 * b.$2 - b.$1 * a.$2).toDouble();
  }
  if (area < 0) src = src.reversed.toList();

  const arcTolerance = 0.25;
  final y = arcTolerance > delta.abs() * arcTolerance ? delta.abs() * arcTolerance : arcTolerance;
  var steps = math.pi / math.acos(1 - y / delta.abs());
  if (steps > delta.abs() * math.pi) steps = delta.abs() * math.pi;
  final sinStep = math.sin(2 * math.pi / steps) * (delta < 0 ? -1 : 1);
  final cosStep = math.cos(2 * math.pi / steps);
  final stepsPerRad = steps / (2 * math.pi);

  final n = src.length;
  final normals = List.generate(n, (j) {
    final a = src[j], b = src[(j + 1) % n];
    final dx = (b.$1 - a.$1).toDouble(), dy = (b.$2 - a.$2).toDouble();
    if (dx == 0 && dy == 0) return const Point2(0, 0);
    final f = 1 / math.sqrt(dx * dx + dy * dy);
    return Point2(dy * f, -dx * f);
  });

  final out = <Point2>[];
  void push(double x, double y) => out.add(Point2(_clipperRound(x).toDouble(), _clipperRound(y).toDouble()));

  var k = n - 1;
  for (var j = 0; j < n; j++) {
    final sx = src[j].$1.toDouble(), sy = src[j].$2.toDouble();
    final nk = normals[k], nj = normals[j];
    var sinA = nk.x * nj.y - nj.x * nk.y;
    final cosA = nk.x * nj.x + nk.y * nj.y;
    if ((sinA * delta).abs() < 1.0) {
      if (cosA > 0) {
        push(sx + nk.x * delta, sy + nk.y * delta);
        k = j;
        continue;
      }
    } else if (sinA > 1.0) {
      sinA = 1.0;
    } else if (sinA < -1.0) {
      sinA = -1.0;
    }

    if (sinA * delta < 0) {
      push(sx + nk.x * delta, sy + nk.y * delta);
      push(sx, sy);
      push(sx + nj.x * delta, sy + nj.y * delta);
    } else {
      // DoRound
      final a = math.atan2(sinA, cosA);
      final count = math.max(_clipperRound(stepsPerRad * a.abs()), 1);
      var x = nk.x, yy = nk.y;
      for (var i = 0; i < count; i++) {
        push(sx + x * delta, sy + yy * delta);
        final x2 = x;
        x = x * cosStep - sinStep * yy;
        yy = x2 * sinStep + yy * cosStep;
      }
      push(sx + nj.x * delta, sy + nj.y * delta);
    }
    k = j;
  }
  return out;
}

double polygonArea(List<Point2> p) {
  var s = 0.0;
  for (var i = 0; i < p.length; i++) {
    final a = p[i], b = p[(i + 1) % p.length];
    s += a.x * b.y - b.x * a.y;
  }
  return s.abs() / 2;
}

double polygonPerimeter(List<Point2> p) {
  var s = 0.0;
  for (var i = 0; i < p.length; i++) {
    s += p[i].distanceTo(p[(i + 1) % p.length]);
  }
  return s;
}

/// Trasformazione prospettica che porta il rettangolo (0,0)-(w,h) sul
/// quadrilatero [quad] (tl, tr, br, bl). Serve a campionare l'immagine
/// sorgente per ogni pixel del ritaglio raddrizzato.
class Homography {
  final List<double> m; // 3x3 row-major, m[8] = 1
  const Homography(this.m);

  factory Homography.fromRectTo(double w, double h, List<Point2> quad) {
    final src = [const Point2(0, 0), Point2(w, 0), Point2(w, h), Point2(0, h)];
    // Sistema 8x8 per i coefficienti a..h.
    final a = List.generate(8, (_) => List<double>.filled(9, 0));
    for (var i = 0; i < 4; i++) {
      final x = src[i].x, y = src[i].y;
      final u = quad[i].x, v = quad[i].y;
      a[2 * i].setAll(0, [x, y, 1, 0, 0, 0, -x * u, -y * u, u]);
      a[2 * i + 1].setAll(0, [0, 0, 0, x, y, 1, -x * v, -y * v, v]);
    }
    final sol = _solve(a);
    return Homography([...sol, 1]);
  }

  Point2 apply(double x, double y) {
    final d = m[6] * x + m[7] * y + m[8];
    return Point2(
      (m[0] * x + m[1] * y + m[2]) / d,
      (m[3] * x + m[4] * y + m[5]) / d,
    );
  }

  static List<double> _solve(List<List<double>> a) {
    final n = a.length;
    for (var col = 0; col < n; col++) {
      var pivot = col;
      for (var r = col + 1; r < n; r++) {
        if (a[r][col].abs() > a[pivot][col].abs()) pivot = r;
      }
      final tmp = a[col];
      a[col] = a[pivot];
      a[pivot] = tmp;
      final pv = a[col][col];
      if (pv.abs() < 1e-12) continue; // quadrilatero degenere
      for (var r = 0; r < n; r++) {
        if (r == col) continue;
        final f = a[r][col] / pv;
        if (f == 0) continue;
        for (var c = col; c <= n; c++) {
          a[r][c] -= f * a[col][c];
        }
      }
    }
    return List.generate(n, (i) => a[i][i].abs() < 1e-12 ? 0.0 : a[i][n] / a[i][i]);
  }
}
