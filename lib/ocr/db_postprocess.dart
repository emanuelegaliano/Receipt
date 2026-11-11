// Ported to Dart from RapidOCR 1.4.4 (https://github.com/RapidAI/RapidOCR),
// itself derived from PaddleOCR: Copyright (c) 2020 PaddlePaddle Authors.
// Licensed under the Apache License 2.0 (see NOTICES).
// Changed for Receipt: translated from Python to Dart and adapted to the app.

import 'dart:math' as math;
import 'dart:typed_data';

import 'geometry.dart';

class DetBox {
  final List<Point2> points; // tl, tr, br, bl in coordinate immagine
  final double score;
  const DetBox(this.points, this.score);
}

/// Post-processing del rilevatore DBNet, porta di `DBPostProcess` di RapidOCR
/// (score_mode "fast", use_dilation true) senza OpenCV.
class DbPostProcess {
  final double thresh;
  final double boxThresh;
  final int maxCandidates;
  final double unclipRatio;
  static const int minSize = 3;

  const DbPostProcess({
    this.thresh = 0.3,
    this.boxThresh = 0.5,
    this.maxCandidates = 1000,
    this.unclipRatio = 1.6,
  });

  /// [pred]: mappa di probabilità [height x width] in uscita dal modello.
  /// Restituisce i box riportati alle dimensioni [destW] x [destH].
  List<DetBox> call(Float32List pred, int width, int height, int destW, int destH) {
    final mask = _dilate(_threshold(pred), width, height);
    final components = _components(mask, width, height);

    final boxes = <DetBox>[];
    for (final hullPoints in components.take(maxCandidates)) {
      final rect = minAreaRect(hullPoints);
      if (rect.shortSide < minSize) continue;
      final box = orderMiniBox(rect.corners);

      final score = _boxScoreFast(pred, width, height, box);
      if (score < boxThresh) continue;

      final distance = polygonArea(box) * unclipRatio / polygonPerimeter(box);
      final expanded = minAreaRect(clipperOffsetRound(box, distance));
      if (expanded.shortSide < minSize + 2) continue;

      // np.round arrotonda le metà al pari.
      final scaled = orderMiniBox(expanded.corners)
          .map((p) => Point2(
                _roundHalfEven(p.x / width * destW).clamp(0, destW).toDouble(),
                _roundHalfEven(p.y / height * destH).clamp(0, destH).toDouble(),
              ))
          .toList();
      boxes.add(DetBox(scaled, score));
    }
    return boxes;
  }

  static int _roundHalfEven(double v) {
    final f = v.floor();
    final d = v - f;
    if (d > 0.5) return f + 1;
    if (d < 0.5) return f;
    return f.isEven ? f : f + 1;
  }

  Uint8List _threshold(Float32List pred) {
    final m = Uint8List(pred.length);
    for (var i = 0; i < pred.length; i++) {
      if (pred[i] > thresh) m[i] = 1;
    }
    return m;
  }

  /// Dilatazione con kernel 2x2 e ancora (1,1), come cv2.dilate.
  static Uint8List _dilate(Uint8List src, int w, int h) {
    final out = Uint8List(src.length);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = y * w + x;
        if (src[i] == 1 ||
            (x > 0 && src[i - 1] == 1) ||
            (y > 0 && src[i - w] == 1) ||
            (x > 0 && y > 0 && src[i - w - 1] == 1)) {
          out[i] = 1;
        }
      }
    }
    return out;
  }

  /// Componenti connesse (8-connettività). Per ciascuna restituisce solo gli
  /// estremi sinistro e destro di ogni riga: hanno lo stesso inviluppo
  /// convesso di tutti i pixel, quindi lo stesso minAreaRect del contorno.
  static List<List<Point2>> _components(Uint8List mask, int w, int h) {
    final visited = Uint8List(mask.length);
    final stack = Int32List(mask.length);
    final result = <List<Point2>>[];

    for (var start = 0; start < mask.length; start++) {
      if (mask[start] == 0 || visited[start] == 1) continue;
      final rowMin = <int, int>{};
      final rowMax = <int, int>{};
      var top = 0;
      stack[top++] = start;
      visited[start] = 1;
      while (top > 0) {
        final p = stack[--top];
        final x = p % w, y = p ~/ w;
        final mn = rowMin[y];
        if (mn == null || x < mn) rowMin[y] = x;
        final mx = rowMax[y];
        if (mx == null || x > mx) rowMax[y] = x;
        for (var dy = -1; dy <= 1; dy++) {
          final ny = y + dy;
          if (ny < 0 || ny >= h) continue;
          for (var dx = -1; dx <= 1; dx++) {
            final nx = x + dx;
            if (nx < 0 || nx >= w) continue;
            final q = ny * w + nx;
            if (mask[q] == 1 && visited[q] == 0) {
              visited[q] = 1;
              stack[top++] = q;
            }
          }
        }
      }
      final pts = <Point2>[];
      rowMin.forEach((y, x) {
        pts.add(Point2(x.toDouble(), y.toDouble()));
        final x2 = rowMax[y]!;
        if (x2 != x) pts.add(Point2(x2.toDouble(), y.toDouble()));
      });
      result.add(pts);
    }
    return result;
  }

  /// Media della probabilità dentro al box (come `box_score_fast`).
  static double _boxScoreFast(Float32List pred, int w, int h, List<Point2> box) {
    final xmin = box.map((p) => p.x).reduce(math.min).floor().clamp(0, w - 1);
    final xmax = box.map((p) => p.x).reduce(math.max).ceil().clamp(0, w - 1);
    final ymin = box.map((p) => p.y).reduce(math.min).floor().clamp(0, h - 1);
    final ymax = box.map((p) => p.y).reduce(math.max).ceil().clamp(0, h - 1);
    // cv2.fillPoly riceve coordinate troncate a intero.
    final poly = box.map((p) => Point2(p.x.truncateToDouble(), p.y.truncateToDouble())).toList();

    var sum = 0.0;
    var count = 0;
    for (var y = ymin; y <= ymax; y++) {
      for (var x = xmin; x <= xmax; x++) {
        if (_insideConvex(poly, x.toDouble(), y.toDouble())) {
          sum += pred[y * w + x];
          count++;
        }
      }
    }
    return count == 0 ? 0 : sum / count;
  }

  /// Punto dentro al poligono convesso, bordo incluso con mezzo pixel di
  /// tolleranza (fillPoly disegna anche i lati).
  static bool _insideConvex(List<Point2> poly, double x, double y) {
    var sign = 0;
    for (var i = 0; i < poly.length; i++) {
      final a = poly[i], b = poly[(i + 1) % poly.length];
      final ex = b.x - a.x, ey = b.y - a.y;
      final len = math.sqrt(ex * ex + ey * ey);
      if (len == 0) continue;
      final dist = (ex * (y - a.y) - ey * (x - a.x)) / len;
      if (dist.abs() <= 0.5) continue;
      final s = dist > 0 ? 1 : -1;
      if (sign == 0) {
        sign = s;
      } else if (s != sign) {
        return false;
      }
    }
    return true;
  }
}

/// Ordina i box dall'alto in basso e da sinistra a destra (`sorted_boxes`).
List<DetBox> sortBoxes(List<DetBox> boxes) {
  final b = [...boxes]
    ..sort((p, q) {
      final c = p.points[0].y.compareTo(q.points[0].y);
      return c != 0 ? c : p.points[0].x.compareTo(q.points[0].x);
    });
  for (var i = 0; i < b.length - 1; i++) {
    for (var j = i; j >= 0; j--) {
      if ((b[j + 1].points[0].y - b[j].points[0].y).abs() < 10 &&
          b[j + 1].points[0].x < b[j].points[0].x) {
        final t = b[j];
        b[j] = b[j + 1];
        b[j + 1] = t;
      } else {
        break;
      }
    }
  }
  return b;
}
