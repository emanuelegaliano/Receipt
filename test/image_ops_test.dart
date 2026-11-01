import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_app/ocr/geometry.dart';
import 'package:receipt_app/ocr/image_ops.dart';

/// Confronto con cv2.resize / cv2.warpPerspective (fixture generate in Python).
BgrImage _fromNested(List rows) {
  final h = rows.length, w = (rows[0] as List).length;
  final data = Uint8List(w * h * 3);
  var i = 0;
  for (final r in rows) {
    for (final px in r as List) {
      for (final c in px as List) {
        data[i++] = c as int;
      }
    }
  }
  return BgrImage(w, h, data);
}

({int maxDiff, double mismatched}) _compare(BgrImage a, BgrImage b) {
  expect(a.width, b.width);
  expect(a.height, b.height);
  var maxDiff = 0, bad = 0;
  for (var i = 0; i < a.data.length; i++) {
    final d = (a.data[i] - b.data[i]).abs();
    if (d > maxDiff) maxDiff = d;
    if (d > 0) bad++;
  }
  return (maxDiff: maxDiff, mismatched: bad / a.data.length);
}

void main() {
  test('resize come cv2.INTER_LINEAR', () {
    final f = jsonDecode(File('test/fixtures/resize.json').readAsStringSync());
    final src = _fromNested(f['src']);
    final expected = _fromNested(f['dst']);
    final r = _compare(src.resize(expected.width, expected.height), expected);
    // ignore: avoid_print
    print('resize: scarto massimo ${r.maxDiff}, valori diversi ${(r.mismatched * 100).toStringAsFixed(1)}%');
    expect(r.maxDiff, lessThanOrEqualTo(1));
  });

  test('warpQuad come cv2.warpPerspective INTER_CUBIC', () {
    final f = jsonDecode(File('test/fixtures/warp.json').readAsStringSync());
    final src = _fromNested(jsonDecode(File('test/fixtures/resize.json').readAsStringSync())['src']);
    final quad = [for (final p in f['quad'] as List) Point2((p[0] as num).toDouble(), (p[1] as num).toDouble())];
    final expected = _fromNested(f['dst']);
    final r = _compare(src.warpQuad(quad, f['w'], f['h']), expected);
    // ignore: avoid_print
    print('warp: scarto massimo ${r.maxDiff}, valori diversi ${(r.mismatched * 100).toStringAsFixed(1)}%');
    expect(r.maxDiff, lessThanOrEqualTo(1));
  });
}
