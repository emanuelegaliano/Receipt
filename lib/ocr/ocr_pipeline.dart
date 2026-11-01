import 'dart:math' as math;
import 'dart:typed_data';

import 'db_postprocess.dart';
import 'geometry.dart';
import 'image_ops.dart';

/// Parametri di RapidOCR 1.4.4 (config.yaml), quelli usati da PyReceipt.
class OcrConfig {
  static const maxSideLen = 2000;
  static const minSideLen = 30;
  static const detLimitSideLen = 736; // limit_type: min
  static const clsShape = (h: 48, w: 192);
  static const clsBatch = 6;
  static const clsThresh = 0.9;
  static const recShape = (h: 48, w: 320);
  static const recBatch = 6;
  static const textScore = 0.5;
}

class OcrLine {
  final List<Point2> box; // tl, tr, br, bl nell'immagine originale
  final String text;
  final double score;
  const OcrLine(this.box, this.text, this.score);

  /// Formato usato da PyReceipt: {"text", "box": [x0, y0, x1, y1], "conf"}.
  ({String text, List<int> box, double conf}) toPyReceiptBox() {
    final xs = box.map((p) => p.x.toInt());
    final ys = box.map((p) => p.y.toInt());
    return (
      text: text,
      box: [xs.reduce(math.min), ys.reduce(math.min), xs.reduce(math.max), ys.reduce(math.max)],
      conf: score,
    );
  }
}

/// round() di Python 3 (arrotondamento bancario), usato nei resize di RapidOCR.
int pyRound(double v) {
  final f = v.floorToDouble();
  final diff = v - f;
  if (diff > 0.5) return f.toInt() + 1;
  if (diff < 0.5) return f.toInt();
  return f.toInt().isEven ? f.toInt() : f.toInt() + 1;
}

/// Tensore float pronto per ONNX.
class Tensor {
  final Float32List data;
  final List<int> shape;
  const Tensor(this.data, this.shape);
}

/// Immagine preparata per il rilevatore, con i fattori per tornare
/// alle coordinate originali.
class DetInput {
  final BgrImage image; // immagine dopo il limite max/min lato
  final double ratioW, ratioH;
  final int rawW, rawH;
  final Tensor tensor;
  const DetInput(this.image, this.ratioW, this.ratioH, this.rawW, this.rawH, this.tensor);
}

/// Passi sincroni della pipeline di RapidOCR. Sono separati dall'inferenza
/// così possono girare in un isolate e i test non dipendono dal plugin ONNX.
class OcrPipeline {
  static DetInput prepareDetection(BgrImage raw) {
    var image = raw;
    var ratioW = 1.0, ratioH = 1.0;

    // preprocess(): lato massimo <= 2000, lato minimo >= 30 (multipli di 32).
    if (math.max(image.width, image.height) > OcrConfig.maxSideLen) {
      final r = image.height > image.width
          ? OcrConfig.maxSideLen / image.height
          : OcrConfig.maxSideLen / image.width;
      final w = pyRound((image.width * r).truncate() / 32) * 32;
      final h = pyRound((image.height * r).truncate() / 32) * 32;
      ratioW = image.width / w;
      ratioH = image.height / h;
      image = image.resize(w, h);
    }
    if (math.min(image.width, image.height) < OcrConfig.minSideLen) {
      final r = image.height < image.width
          ? OcrConfig.minSideLen / image.height
          : OcrConfig.minSideLen / image.width;
      final w = pyRound((image.width * r).truncate() / 32) * 32;
      final h = pyRound((image.height * r).truncate() / 32) * 32;
      ratioW = image.width / w;
      ratioH = image.height / h;
      image = image.resize(w, h);
    }
    // Nota: il letterbox di RapidOCR scatta solo per immagini alte <= 30 px o
    // con rapporto w/h > 8, mai per una foto di scontrino: non è portato.

    // DetPreProcess: lato minimo portato a 736, dimensioni multiple di 32.
    final h = image.height, w = image.width;
    var ratio = 1.0;
    if (math.min(h, w) < OcrConfig.detLimitSideLen) {
      ratio = h < w ? OcrConfig.detLimitSideLen / h : OcrConfig.detLimitSideLen / w;
    }
    final rh = math.max(pyRound((h * ratio).truncate() / 32) * 32, 32);
    final rw = math.max(pyRound((w * ratio).truncate() / 32) * 32, 32);
    final resized = image.resize(rw, rh);
    final data = Float32List(3 * rh * rw);
    resized.writeNormalizedChw(data, 0, rw);

    return DetInput(image, ratioW, ratioH, raw.width, raw.height, Tensor(data, [1, 3, rh, rw]));
  }

  /// Box del rilevatore -> ritagli raddrizzati delle righe di testo.
  static List<DetBox> detectBoxes(DetInput input, Float32List pred) {
    final mapH = input.tensor.shape[2], mapW = input.tensor.shape[3];
    final imgW = input.image.width, imgH = input.image.height;
    final raw = const DbPostProcess().call(pred, mapW, mapH, imgW, imgH);

    // filter_tag_det_res: ordina i vertici, clippa, scarta box minuscoli.
    final filtered = <DetBox>[];
    for (final b in raw) {
      final pts = orderPointsClockwise(b.points)
          .map((p) => Point2(
                p.x.clamp(0, imgW - 1).truncateToDouble(),
                p.y.clamp(0, imgH - 1).truncateToDouble(),
              ))
          .toList();
      if (pts[0].distanceTo(pts[1]).toInt() <= 3 || pts[0].distanceTo(pts[3]).toInt() <= 3) {
        continue;
      }
      filtered.add(DetBox(pts, b.score));
    }
    return sortBoxes(filtered);
  }

  static List<BgrImage> cropLines(BgrImage image, List<DetBox> boxes) {
    return [
      for (final b in boxes)
        () {
          final p = b.points;
          final w = math.max(p[0].distanceTo(p[1]), p[2].distanceTo(p[3])).toInt();
          final h = math.max(p[0].distanceTo(p[3]), p[1].distanceTo(p[2])).toInt();
          final crop = image.warpQuad(p, math.max(w, 1), math.max(h, 1));
          return crop.height / crop.width >= 1.5 ? crop.rot90() : crop;
        }()
    ];
  }

  /// Indici delle righe ordinati per rapporto larghezza/altezza (come
  /// np.argsort in RapidOCR), poi divisi in batch.
  static List<List<int>> batches(List<BgrImage> crops, int batchSize) {
    final idx = List.generate(crops.length, (i) => i)
      ..sort((a, b) => (crops[a].width / crops[a].height).compareTo(crops[b].width / crops[b].height));
    return [
      for (var i = 0; i < idx.length; i += batchSize) idx.sublist(i, math.min(i + batchSize, idx.length))
    ];
  }

  static Tensor clsTensor(List<BgrImage> crops, List<int> batch) {
    const ch = OcrConfig.clsShape;
    final data = Float32List(batch.length * 3 * ch.h * ch.w);
    for (var n = 0; n < batch.length; n++) {
      final c = crops[batch[n]];
      final rw = math.min((ch.h * c.width / c.height).ceil(), ch.w);
      c.resize(math.max(rw, 1), ch.h).writeNormalizedChw(data, n * 3 * ch.h * ch.w, ch.w);
    }
    return Tensor(data, [batch.length, 3, ch.h, ch.w]);
  }

  /// Applica il classificatore: ruota di 180° le righe capovolte.
  static void applyCls(List<BgrImage> crops, List<int> batch, List<double> probs) {
    for (var n = 0; n < batch.length; n++) {
      final p0 = probs[2 * n], p180 = probs[2 * n + 1];
      if (p180 > p0 && p180 > OcrConfig.clsThresh) {
        crops[batch[n]] = crops[batch[n]].rot180();
      }
    }
  }

  static Tensor recTensor(List<BgrImage> crops, List<int> batch) {
    const rs = OcrConfig.recShape;
    var maxRatio = rs.w / rs.h;
    for (final i in batch) {
      maxRatio = math.max(maxRatio, crops[i].width / crops[i].height);
    }
    final canvasW = (rs.h * maxRatio).toInt();
    final data = Float32List(batch.length * 3 * rs.h * canvasW);
    for (var n = 0; n < batch.length; n++) {
      final c = crops[batch[n]];
      final rw = math.min((rs.h * c.width / c.height).ceil(), canvasW);
      c.resize(math.max(rw, 1), rs.h).writeNormalizedChw(data, n * 3 * rs.h * canvasW, canvasW);
    }
    return Tensor(data, [batch.length, 3, rs.h, canvasW]);
  }

  /// Decodifica CTC: toglie i duplicati consecutivi e il "blank" (indice 0).
  /// [chars] = ['blank', ...dizionario, ' '].
  static List<({String text, double score})> ctcDecode(
      List<int> indices, List<double> scores, int n, int t, List<String> chars) {
    final out = <({String text, double score})>[];
    for (var b = 0; b < n; b++) {
      final buf = StringBuffer();
      var sum = 0.0;
      var count = 0;
      for (var i = 0; i < t; i++) {
        final k = indices[b * t + i];
        if (k == 0) continue;
        if (i > 0 && indices[b * t + i - 1] == k) continue;
        buf.write(chars[k]);
        sum += scores[b * t + i];
        count++;
      }
      out.add((text: buf.toString(), score: count == 0 ? 0.0 : sum / count));
    }
    return out;
  }

  /// Riporta i box alle coordinate dell'immagine originale.
  static List<Point2> toOriginal(DetInput input, List<Point2> pts) => [
        for (final p in pts)
          Point2(
            (p.x * input.ratioW).clamp(0, input.rawW.toDouble()),
            (p.y * input.ratioH).clamp(0, input.rawH.toDouble()),
          )
      ];
}
