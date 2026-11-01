import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import 'db_postprocess.dart';
import 'image_ops.dart';
import 'ocr_pipeline.dart';

class OcrResult {
  final List<OcrLine> lines;
  final Map<String, int> timingsMs;
  final int imageWidth, imageHeight;
  const OcrResult(this.lines, this.timingsMs, this.imageWidth, this.imageHeight);

  String get text => lines.map((l) => l.text).join('\n');
}

/// RapidOCR (PP-OCRv4 det + cls + rec) on-device via ONNX Runtime.
///
/// L'inferenza passa dal plugin; tutto il resto (decodifica, resize,
/// post-processing, ritagli) gira in isolate separati per non bloccare la UI.
class RapidOcr {
  final OrtSession _det;
  final OrtSession _cls;
  final OrtSession _rec;
  final List<String> _chars;

  RapidOcr._(this._det, this._cls, this._rec, this._chars);

  static Future<RapidOcr> load() async {
    final ort = OnnxRuntime();
    final det = await ort.createSessionFromAsset('assets/models/det.onnx');
    final cls = await ort.createSessionFromAsset('assets/models/cls.onnx');
    final rec = await ort.createSessionFromAsset('assets/models/rec.onnx');
    final keys = await rootBundle.loadString('assets/models/keys.txt');
    return RapidOcr._(det, cls, rec, ['blank', ...keys.split('\n'), ' ']);
  }

  /// Prima inferenza "a vuoto" su tensori piccoli: ONNX Runtime alloca la
  /// memoria e prepara i kernel alla prima esecuzione, che altrimenti
  /// renderebbe lentissima la prima scansione vera.
  Future<void> warmUp() async {
    for (final (session, shape) in [
      (_det, [1, 3, 96, 96]),
      (_cls, [1, 3, 48, 192]),
      (_rec, [1, 3, 48, 320]),
    ]) {
      final input = await OrtValue.fromList(Float32List(shape.reduce((a, b) => a * b)), shape);
      final out = await session.run({'x': input});
      await input.dispose();
      for (final v in out.values) {
        await v.dispose();
      }
    }
  }

  Future<void> close() async {
    await _det.close();
    await _cls.close();
    await _rec.close();
  }

  Future<OcrResult> recognize(Uint8List imageBytes) async {
    final timings = <String, int>{};
    final sw = Stopwatch()..start();
    void lap(String name) {
      timings[name] = sw.elapsedMilliseconds;
      sw.reset();
    }

    // Decoder nativo (libjpeg-turbo via Skia, con orientamento EXIF): gli
    // stessi pixel che PIL/OpenCV danno a RapidOCR in Python.
    final codec = await ui.instantiateImageCodec(imageBytes);
    final frame = (await codec.getNextFrame()).image;
    final rgba = (await frame.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
    final (w, h) = (frame.width, frame.height);
    frame.dispose();
    codec.dispose();
    final detInput = await _prepareInIsolate(w, h, rgba);
    lap('decodifica');

    final pred = await _runFloat(_det, detInput.tensor);
    lap('rilevamento');

    final (boxes, crops) = await _cropInIsolate(detInput, pred);
    lap('ritagli');
    if (boxes.isEmpty) return OcrResult(const [], timings, detInput.rawW, detInput.rawH);

    for (final batch in OcrPipeline.batches(crops, OcrConfig.clsBatch)) {
      final t = OcrPipeline.clsTensor(crops, batch);
      final probs = await _runFloat(_cls, t);
      OcrPipeline.applyCls(crops, batch, probs);
    }
    lap('orientamento');

    final texts = List<({String text, double score})>.filled(crops.length, (text: '', score: 0.0));
    for (final batch in OcrPipeline.batches(crops, OcrConfig.recBatch)) {
      final t = OcrPipeline.recTensor(crops, batch);
      final input = await OrtValue.fromList(t.data, t.shape);
      final out = await _rec.run({'x': input});
      final idxValue = out['indices']!, scoreValue = out['scores']!;
      final indices = (await idxValue.asFlattenedList()).cast<int>();
      final scores = (await scoreValue.asFlattenedList()).map((e) => (e as num).toDouble()).toList();
      final n = idxValue.shape[0], steps = idxValue.shape[1];
      final decoded = OcrPipeline.ctcDecode(indices, scores, n, steps, _chars);
      for (var k = 0; k < batch.length; k++) {
        texts[batch[k]] = decoded[k];
      }
      await input.dispose();
      for (final v in out.values) {
        await v.dispose();
      }
    }
    lap('riconoscimento');

    final lines = <OcrLine>[
      for (var i = 0; i < boxes.length; i++)
        if (texts[i].score >= OcrConfig.textScore)
          OcrLine(OcrPipeline.toOriginal(detInput, boxes[i].points), texts[i].text, texts[i].score),
    ];
    return OcrResult(lines, timings, detInput.rawW, detInput.rawH);
  }

  // Funzioni statiche: la closure passata all'isolate cattura solo gli argomenti.
  static Future<DetInput> _prepareInIsolate(int w, int h, Uint8List rgba) =>
      Isolate.run(() => OcrPipeline.prepareDetection(BgrImage.fromRgba(w, h, rgba)));

  static Future<(List<DetBox>, List<BgrImage>)> _cropInIsolate(DetInput input, Float32List pred) =>
      Isolate.run(() {
        final boxes = OcrPipeline.detectBoxes(input, pred);
        return (boxes, OcrPipeline.cropLines(input.image, boxes));
      });

  /// Esegue un modello con un solo input "x" e un solo output float.
  static Future<Float32List> _runFloat(OrtSession session, Tensor t) async {
    final input = await OrtValue.fromList(t.data, t.shape);
    final out = await session.run({'x': input});
    final value = out.values.first;
    final list = await value.asFlattenedList();
    await input.dispose();
    for (final v in out.values) {
      await v.dispose();
    }
    return list is Float32List ? list : Float32List.fromList([for (final e in list) (e as num).toDouble()]);
  }
}
