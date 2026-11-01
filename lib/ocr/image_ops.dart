import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'geometry.dart';

/// Immagine a 3 canali in ordine BGR (come cv2), 8 bit per canale.
///
/// RapidOCR lavora su array OpenCV in BGR: tenere lo stesso ordine evita
/// sorprese quando si normalizza l'input per i modelli.
class BgrImage {
  final int width;
  final int height;
  final Uint8List data; // width * height * 3, row-major, BGR

  BgrImage(this.width, this.height, this.data)
      : assert(data.length == width * height * 3);

  factory BgrImage.zeros(int width, int height) =>
      BgrImage(width, height, Uint8List(width * height * 3));

  /// Decodifica in Dart puro (pacchetto `image`), applica l'orientamento EXIF
  /// e converte in BGR. Usata nei test: nell'app si usa il decoder nativo
  /// (vedi RapidOcr), perché questo differisce da libjpeg-turbo fino a ~36
  /// livelli sui bordi di colore e cambia leggermente il testo riconosciuto.
  static BgrImage decode(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Immagine non decodificabile');
    }
    return fromImage(img.bakeOrientation(decoded));
  }

  /// Da pixel RGBA (es. `ui.Image.toByteData(rawRgba)`), alpha su bianco.
  static BgrImage fromRgba(int width, int height, Uint8List rgba) {
    final out = BgrImage.zeros(width, height);
    final n = width * height;
    for (var p = 0; p < n; p++) {
      final i = p * 4, o = p * 3;
      final a = rgba[i + 3];
      if (a == 255) {
        out.data[o] = rgba[i + 2];
        out.data[o + 1] = rgba[i + 1];
        out.data[o + 2] = rgba[i];
      } else {
        final k = a / 255;
        out.data[o] = (rgba[i + 2] * k + 255 * (1 - k)).round();
        out.data[o + 1] = (rgba[i + 1] * k + 255 * (1 - k)).round();
        out.data[o + 2] = (rgba[i] * k + 255 * (1 - k)).round();
      }
    }
    return out;
  }

  static BgrImage fromImage(img.Image src) {
    final out = BgrImage.zeros(src.width, src.height);
    var i = 0;
    for (final p in src) {
      // Le immagini con alpha vengono appiattite su bianco.
      final a = src.hasAlpha ? p.aNormalized : 1.0;
      final r = (p.r * a + 255 * (1 - a)).round();
      final g = (p.g * a + 255 * (1 - a)).round();
      final b = (p.b * a + 255 * (1 - a)).round();
      if (src.numChannels == 1 || (src.numChannels == 2)) {
        out.data[i] = out.data[i + 1] = out.data[i + 2] = r;
      } else {
        out.data[i] = b;
        out.data[i + 1] = g;
        out.data[i + 2] = r;
      }
      i += 3;
    }
    return out;
  }

  /// Ridimensionamento bilineare come cv2.resize(INTER_LINEAR) su uint8:
  /// centri pixel a metà e pesi in virgola fissa a 11 bit.
  BgrImage resize(int newW, int newH) {
    const scale = 2048; // INTER_RESIZE_COEF_SCALE
    List<(int, int, int)> taps(int dst, int src) {
      final s = src / dst;
      return List.generate(dst, (d) {
        var f = (d + 0.5) * s - 0.5;
        var i = f.floor();
        f -= i;
        if (i < 0) {
          f = 0;
          i = 0;
        }
        if (i >= src - 1) {
          f = 0;
          i = src - 1;
        }
        final a1 = (f * scale).round();
        return (i, scale - a1, a1);
      });
    }

    final xt = taps(newW, width);
    final yt = taps(newH, height);
    final out = BgrImage.zeros(newW, newH);
    final row0 = Int32List(newW * 3), row1 = Int32List(newW * 3);
    void hpass(int sy, Int32List dst) {
      final base = sy * width * 3;
      for (var x = 0; x < newW; x++) {
        final (sx, a0, a1) = xt[x];
        final i0 = base + sx * 3;
        final i1 = base + math.min(sx + 1, width - 1) * 3;
        for (var c = 0; c < 3; c++) {
          dst[x * 3 + c] = data[i0 + c] * a0 + data[i1 + c] * a1;
        }
      }
    }

    for (var y = 0; y < newH; y++) {
      final (sy, b0, b1) = yt[y];
      hpass(sy, row0);
      hpass(math.min(sy + 1, height - 1), row1);
      final o = y * newW * 3;
      for (var k = 0; k < newW * 3; k++) {
        final v = (b0 * row0[k] + b1 * row1[k] + (1 << 21)) >> 22;
        out.data[o + k] = v > 255 ? 255 : v;
      }
    }
    return out;
  }

  /// Ritaglia il quadrilatero [quad] (tl, tr, br, bl) raddrizzandolo in un
  /// rettangolo outW x outH, come cv2.warpPerspective con INTER_CUBIC e
  /// BORDER_REPLICATE.
  BgrImage warpQuad(List<Point2> quad, int outW, int outH) {
    final h = Homography.fromRectTo(outW.toDouble(), outH.toDouble(), quad);
    final out = BgrImage.zeros(outW, outH);
    for (var y = 0; y < outH; y++) {
      for (var x = 0; x < outW; x++) {
        final p = h.apply(x.toDouble(), y.toDouble());
        _sampleCubicInto(p.x, p.y, out.data, (y * outW + x) * 3);
      }
    }
    return out;
  }

  static List<double> _cubicWeights(double t) {
    const a = -0.75;
    final w0 = ((a * (t + 1) - 5 * a) * (t + 1) + 8 * a) * (t + 1) - 4 * a;
    final w1 = ((a + 2) * t - (a + 3)) * t * t + 1;
    final w2 = ((a + 2) * (1 - t) - (a + 3)) * (1 - t) * (1 - t) + 1;
    return [w0, w1, w2, 1 - w0 - w1 - w2];
  }

  void _sampleCubicInto(double fx, double fy, Uint8List dst, int o) {
    // OpenCV 5 interpola alla coordinata esatta (la 4.x la quantizzava a 1/32).
    final x0 = fx.floor(), y0 = fy.floor();
    final wx = _cubicWeights(fx - x0);
    final wy = _cubicWeights(fy - y0);
    for (var c = 0; c < 3; c++) {
      var acc = 0.0;
      for (var j = 0; j < 4; j++) {
        final yy = (y0 - 1 + j).clamp(0, height - 1);
        var rowAcc = 0.0;
        for (var i = 0; i < 4; i++) {
          final xx = (x0 - 1 + i).clamp(0, width - 1);
          rowAcc += data[(yy * width + xx) * 3 + c] * wx[i];
        }
        acc += rowAcc * wy[j];
      }
      dst[o + c] = acc.round().clamp(0, 255);
    }
  }

  /// Rotazione di 90° antioraria (np.rot90).
  BgrImage rot90() {
    final out = BgrImage.zeros(height, width);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        // np.rot90: out[width-1-x][y] = in[y][x]
        final o = ((width - 1 - x) * height + y) * 3;
        final i = (y * width + x) * 3;
        out.data[o] = data[i];
        out.data[o + 1] = data[i + 1];
        out.data[o + 2] = data[i + 2];
      }
    }
    return out;
  }

  /// Rotazione di 180° (cv2.rotate(img, cv2.ROTATE_180)).
  BgrImage rot180() {
    final out = BgrImage.zeros(width, height);
    final n = width * height;
    for (var p = 0; p < n; p++) {
      final i = p * 3;
      final o = (n - 1 - p) * 3;
      out.data[o] = data[i];
      out.data[o + 1] = data[i + 1];
      out.data[o + 2] = data[i + 2];
    }
    return out;
  }

  /// Scrive l'immagine normalizzata ((x/255 - 0.5) / 0.5) in formato CHW
  /// dentro [dst] a partire da [offset], su un canvas largo [canvasW]
  /// (le colonne oltre [width] restano a 0, come il padding di RapidOCR).
  void writeNormalizedChw(Float32List dst, int offset, int canvasW) {
    final plane = height * canvasW;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final i = (y * width + x) * 3;
        final o = offset + y * canvasW + x;
        dst[o] = data[i] / 127.5 - 1.0;
        dst[o + plane] = data[i + 1] / 127.5 - 1.0;
        dst[o + 2 * plane] = data[i + 2] / 127.5 - 1.0;
      }
    }
  }
}
