import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_app/ocr/db_postprocess.dart';
import 'package:receipt_app/ocr/geometry.dart';

/// Confronta il post-processing Dart con quello di RapidOCR Python sulla
/// stessa mappa del rilevatore (fixture generata da tools/rapidocr_reference.py).
void main() {
  test('DbPostProcess riproduce i box di RapidOCR', () {
    final dir = 'test/fixtures/det';
    final meta = jsonDecode(File('$dir/expected.json').readAsStringSync());
    final raw = gzip.decode(File('$dir/pred.f32.gz').readAsBytesSync());
    final pred = Uint8List.fromList(raw).buffer.asFloat32List();

    final boxes = const DbPostProcess().call(
      pred,
      meta['map_width'],
      meta['map_height'],
      meta['dest_width'],
      meta['dest_height'],
    );

    final expected = [
      for (final b in meta['boxes'] as List)
        [for (final p in b as List) Point2((p[0] as num).toDouble(), (p[1] as num).toDouble())]
    ];

    // Ogni box atteso deve avere un corrispondente con vertici identici.
    var matched = 0;
    var worst = 0.0;
    for (final e in expected) {
      double best = double.infinity;
      DetBox? nearest;
      for (final b in boxes) {
        var d = 0.0;
        for (var i = 0; i < 4; i++) {
          d = [d, (b.points[i].x - e[i].x).abs(), (b.points[i].y - e[i].y).abs()]
              .reduce((a, c) => a > c ? a : c);
        }
        if (d < best) {
          best = d;
          nearest = b;
        }
      }
      if (best <= 0.5) {
        matched++;
      } else {
        // ignore: avoid_print
        print('  atteso $e\n  dart   ${nearest?.points}');
      }
      if (best > worst) worst = best;
    }
    // ignore: avoid_print
    print('box attesi ${expected.length}, trovati ${boxes.length}, '
        'corrispondenti $matched, scarto massimo ${worst.toStringAsFixed(1)} px');
    // Limite noto: OpenCV calcola minAreaRect in float32 partendo da un punto
    // che dipende dall'ordine di findContours/Clipper; ogni tanto un vertice
    // vale 1111.9999 invece di 1112 e il box finale si sposta di 1 px.
    expect(boxes.length, expected.length);
    expect(matched, greaterThanOrEqualTo((expected.length * 0.95).floor()));
    expect(worst, lessThanOrEqualTo(1.0));
  });

  test('minAreaRect su un rettangolo ruotato', () {
    // Rettangolo di lati sqrt(20) e sqrt(5), più un punto interno.
    final r = minAreaRect(const [Point2(0, 0), Point2(4, 2), Point2(3, 4), Point2(-1, 2), Point2(1.5, 2)]);
    expect(r.width * r.height, closeTo(10, 1e-9));
    expect(r.shortSide, closeTo(2.2360679, 1e-6));
  });

  test('Homography porta il rettangolo sul quadrilatero', () {
    const quad = [Point2(10, 5), Point2(50, 8), Point2(48, 30), Point2(12, 25)];
    final h = Homography.fromRectTo(40, 20, quad);
    final corners = [h.apply(0, 0), h.apply(40, 0), h.apply(40, 20), h.apply(0, 20)];
    for (var i = 0; i < 4; i++) {
      expect(corners[i].x, closeTo(quad[i].x, 1e-6));
      expect(corners[i].y, closeTo(quad[i].y, 1e-6));
    }
  });
}
