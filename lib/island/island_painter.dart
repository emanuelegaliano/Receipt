/// L'isola di un anno vista dall'alto e un po' di lato: cielo (giorno o
/// notte, con la luna vera), mare, spiaggia, prato, lanterne, le piante nei
/// loro posti e, a fine anno, il premio al centro.
library;

import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import 'catalog.dart';
import 'plant_painter.dart';
import 'rules.dart';

/// Dove stanno le cose sull'isola, per disegnarla e per capire quale posto
/// è stato toccato.
class IslandLayout {
  final Size size;
  final int slots;
  IslandLayout(this.size, this.slots);

  /// Larghezza / altezza del disegno.
  static const aspectRatio = 1 / 1.05;

  /// I posti in coordinate dell'ellisse (-1..1), in un ordine che sta bene
  /// anche preso a metà: un'isola di 3 usa i primi 3.
  static const _spots = [
    (0.0, -0.8), (-0.61, 0.51), (0.61, 0.51), (-0.8, -0.07), (0.8, -0.07), (-0.57, -0.57), //
    (0.57, -0.57), (0.0, 0.8), (-0.27, -0.33), (0.27, -0.33), (-0.41, 0.11), (0.41, 0.11),
  ];

  static const _lanterns = [(-0.3, 0.86), (0.3, 0.86), (-0.9, 0.3), (0.9, 0.3)];

  double get horizon => size.height * 0.3;
  Offset get center => Offset(size.width / 2, size.height * 0.63);

  /// Raggi dell'isola: più piccola se ha pochi posti (la prima, di solito).
  double get rx => size.width * 0.44 * (0.62 + 0.38 * math.min(slots, 12) / 12);
  double get ry => rx * 0.5;

  /// Altezza di un albero.
  double get plantHeight => size.width * 0.2;

  Offset _at(double u, double v) => center + Offset(u * rx, v * ry);

  Offset slot(int i) {
    final (u, v) = _spots[i % _spots.length];
    return _at(u, v);
  }

  Iterable<Offset> get lanterns => _lanterns.map((l) => _at(l.$1, l.$2));

  /// Il posto più vicino a [p], se è abbastanza vicino.
  int? slotAt(Offset p) {
    int? best;
    var bestDistance = double.infinity;
    for (var i = 0; i < slots; i++) {
      final s = slot(i);
      // La pianta sta sopra la sua base: conta anche toccare la chioma.
      final d = (Offset(p.dx, math.min(p.dy + plantHeight * 0.3, s.dy)) - s).distance;
      if (d < bestDistance) {
        bestDistance = d;
        best = i;
      }
    }
    return bestDistance < plantHeight * 0.45 ? best : null;
  }
}

class IslandPainter extends CustomPainter {
  final int slots;

  /// Posto → (specie, mese in cui è stata piantata).
  final Map<int, (String, int)> plants;

  /// Il premio da disegnare al centro, se c'è.
  final String? centerpiece;
  final DateTime now;
  final bool night;

  /// Posti liberi da mettere in evidenza (si sta scegliendo dove piantare),
  /// e a che punto è il battito (0..1).
  final Set<int> highlight;
  final double pulse;
  final Color highlightColor;

  /// Seme per stelle, nuvole e ciuffi: lo stesso ogni volta per la stessa isola.
  final int seed;

  IslandPainter({
    required this.slots,
    required this.plants,
    required this.centerpiece,
    required this.now,
    required this.night,
    required this.seed,
    this.highlight = const {},
    this.pulse = 0,
    this.highlightColor = const Color(0xFF2E7D5B),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final l = IslandLayout(size, slots);
    final pal = IslandPalette(night: night);
    final r = math.Random(seed);
    canvas.clipRect(Offset.zero & size);
    _sky(canvas, l, r);
    _sea(canvas, l, r);
    _island(canvas, l, pal, r);

    // Le cose sull'isola dalla più lontana alla più vicina.
    final things = <(double, void Function())>[];
    for (var i = 0; i < slots; i++) {
      final s = l.slot(i);
      final plant = plants[i];
      final species = plant == null ? null : speciesByKey(plant.$1);
      if (species == null) {
        things.add((s.dy - 1000, () => _emptySlot(canvas, l, s, pal, math.Random(seed + i))));
      } else {
        things.add((
          s.dy,
          () => paintPlant(canvas, species, s, l.plantHeight, month: now.month, seed: plant!.$2, pal: pal),
        ));
      }
    }
    for (final o in l.lanterns) {
      things.add((o.dy, () => _lantern(canvas, l, o, pal)));
    }
    final c = l.center + Offset(0, l.ry * 0.05);
    if (centerpiece != null) {
      things.add((c.dy, () => paintCenterpiece(canvas, centerpiece!, c, l.plantHeight * 1.15, pal: pal)));
    } else {
      things.add((c.dy - 1000, () => _rewardSpot(canvas, l, c, pal)));
    }
    things.sort((a, b) => a.$1.compareTo(b.$1));
    for (final t in things) {
      t.$2();
    }

    if (night) {
      for (final o in l.lanterns) {
        _glow(canvas, o - Offset(0, l.plantHeight * 0.36), l.plantHeight * 0.5);
      }
    }
    for (final i in highlight) {
      _highlight(canvas, l, l.slot(i));
    }
  }

  void _sky(Canvas canvas, IslandLayout l, math.Random r) {
    final rect = Rect.fromLTWH(0, 0, l.size.width, l.horizon + 1);
    final winter = seasonOf(now.month) == Season.winter;
    final colors = night
        ? const [Color(0xFF0B1330), Color(0xFF27365E)]
        : (winter ? const [Color(0xFF9CC3DE), Color(0xFFE3EEF4)] : const [Color(0xFF7FC2EE), Color(0xFFDDF0FA)]);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ).createShader(rect),
    );
    final w = l.size.width;
    if (night) {
      for (var i = 0; i < 45; i++) {
        final o = Offset(r.nextDouble() * w, r.nextDouble() * l.horizon * 0.95);
        canvas.drawCircle(
          o,
          r.nextDouble() * 1.1 + 0.4,
          Paint()..color = Color.fromRGBO(255, 255, 255, 0.35 + r.nextDouble() * 0.6),
        );
      }
      _moon(canvas, Offset(w * 0.8, l.horizon * 0.38), w * 0.045);
    } else {
      final sun = Offset(w * 0.82, l.horizon * 0.36);
      canvas.drawCircle(
        sun,
        w * 0.12,
        Paint()
          ..shader = RadialGradient(colors: const [Color(0x66FFF3B0), Color(0x00FFF3B0)])
              .createShader(Rect.fromCircle(center: sun, radius: w * 0.12)),
      );
      canvas.drawCircle(sun, w * 0.045, Paint()..color = const Color(0xFFFFE17A));
      for (final (x, y, s) in [(0.18, 0.35, 1.0), (0.5, 0.18, 0.7), (0.62, 0.62, 0.55)]) {
        _cloud(canvas, Offset(w * (x + r.nextDouble() * 0.06), l.horizon * y), w * 0.05 * s);
      }
    }
  }

  void _cloud(Canvas canvas, Offset o, double s) {
    final white = Paint()..color = const Color(0xF0FFFFFF);
    for (final (dx, dy, rad) in [(-1.4, 0.2, 0.8), (-0.5, -0.3, 1.1), (0.6, -0.1, 0.95), (1.4, 0.25, 0.7)]) {
      canvas.drawCircle(o + Offset(dx * s, dy * s), rad * s, white);
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(o.dx - 2 * s, o.dy, o.dx + 2 * s, o.dy + 0.9 * s),
        Radius.circular(0.45 * s),
      ),
      white,
    );
  }

  /// La luna di stanotte: la parte illuminata (a destra quando cresce, a
  /// sinistra quando cala, emisfero nord) delimitata dal terminatore, una
  /// mezza ellisse larga |cos(2π·età)|.
  void _moon(Canvas canvas, Offset c, double radius) {
    final age = moonAge(now);
    canvas.drawCircle(
      c,
      radius * 2.6,
      Paint()
        ..shader = RadialGradient(
          colors: [Color.fromRGBO(255, 248, 220, 0.25 * moonIllumination(age)), const Color(0x00FFF8DC)],
        ).createShader(Rect.fromCircle(center: c, radius: radius * 2.6)),
    );
    canvas.drawCircle(c, radius, Paint()..color = const Color(0xFF2A3354));
    final waxing = age < 0.5;
    final tx = radius * math.cos(2 * math.pi * age);
    final disc = Rect.fromCircle(center: c, radius: radius);
    final lit = Path()
      ..moveTo(c.dx, c.dy - radius)
      ..arcTo(disc, -math.pi / 2, waxing ? math.pi : -math.pi, false)
      ..arcTo(
        Rect.fromCenter(center: c, width: 2 * tx.abs() + 0.001, height: 2 * radius),
        math.pi / 2,
        waxing == (tx > 0) ? -math.pi : math.pi,
        false,
      )
      ..close();
    canvas.drawPath(lit, Paint()..color = const Color(0xFFF6F1DC));
    final crater = Paint()..color = const Color(0x22000000);
    canvas.save();
    canvas.clipPath(lit);
    canvas.drawCircle(c + Offset(-radius * 0.3, -radius * 0.2), radius * 0.22, crater);
    canvas.drawCircle(c + Offset(radius * 0.25, radius * 0.35), radius * 0.15, crater);
    canvas.drawCircle(c + Offset(radius * 0.35, -radius * 0.3), radius * 0.1, crater);
    canvas.restore();
  }

  void _sea(Canvas canvas, IslandLayout l, math.Random r) {
    final rect = Rect.fromLTRB(0, l.horizon, l.size.width, l.size.height);
    final colors = night ? const [Color(0xFF1C3358), Color(0xFF0F1E3A)] : const [Color(0xFF6FB7D9), Color(0xFF3E8FC0)];
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ).createShader(rect),
    );
    final wave = Paint()
      ..color = night ? const Color(0x30FFFFFF) : const Color(0x60FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 18; i++) {
      final y = l.horizon + 8 + r.nextDouble() * (l.size.height - l.horizon - 12);
      final x = r.nextDouble() * l.size.width;
      final s = 5 + (y - l.horizon) / l.size.height * 14;
      canvas.drawArc(
        Rect.fromCenter(center: Offset(x, y), width: s * 2, height: s * 0.8),
        math.pi * 1.15,
        math.pi * 0.7,
        false,
        wave,
      );
    }
    if (night) {
      // Il riflesso della luna.
      final x = l.size.width * 0.8;
      final shine = Paint()..color = Color.fromRGBO(255, 248, 220, 0.18 * moonIllumination(moonAge(now)) + 0.04);
      for (var i = 0; i < 6; i++) {
        final y = l.horizon + 6 + i * 7.0;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(x + r.nextDouble() * 6 - 3, y), width: 26 - i * 2.5, height: 2),
            const Radius.circular(1),
          ),
          shine,
        );
      }
    }
  }

  void _island(Canvas canvas, IslandLayout l, IslandPalette pal, math.Random r) {
    final c = l.center, rx = l.rx, ry = l.ry;
    canvas.drawOval(
      Rect.fromCenter(center: c + Offset(0, ry * 0.2), width: rx * 2.2, height: ry * 2.3),
      Paint()..color = night ? const Color(0x22FFFFFF) : const Color(0x55FFFFFF),
    );
    canvas.drawOval(
      Rect.fromCenter(center: c + Offset(0, ry * 0.16), width: rx * 2, height: ry * 2),
      pal.fill(const Color(0xFFB8935A)),
    );
    canvas.drawOval(Rect.fromCenter(center: c, width: rx * 2, height: ry * 2), pal.fill(const Color(0xFFEBD6A0)));
    final grassColor = Color(switch (seasonOf(now.month)) {
      Season.spring => 0xFF86C05E,
      Season.summer => 0xFF9DBA58,
      Season.autumn => 0xFFA3B562,
      Season.winter => 0xFF84A66C,
    });
    final grass = Rect.fromCenter(center: c - Offset(0, ry * 0.05), width: rx * 1.78, height: ry * 1.66);
    canvas.drawOval(grass.translate(0, ry * 0.04), pal.fill(darker(grassColor, 0.18)));
    canvas.drawOval(grass, pal.fill(grassColor));
    final blade = pal.stroke(darker(grassColor, 0.15), 1.2);
    for (var i = 0; i < 70; i++) {
      final a = r.nextDouble() * 2 * math.pi, d = math.sqrt(r.nextDouble()) * 0.9;
      final o = grass.center + Offset(math.cos(a) * d * grass.width / 2, math.sin(a) * d * grass.height / 2);
      canvas.drawLine(o, o + const Offset(1, -3.5), blade);
    }
    // Qualche sasso sulla spiaggia.
    final rock = pal.fill(const Color(0xFF9E9A92));
    final rockDark = pal.fill(const Color(0xFF7D7970));
    for (final (u, v, s) in [(0.93, 0.33, 1.0), (-0.95, -0.2, 0.8), (0.72, 0.7, 0.6), (-0.5, 0.88, 0.7)]) {
      final o = c + Offset(u * rx, v * ry);
      final w = l.plantHeight * 0.13 * s;
      canvas.drawOval(Rect.fromCenter(center: o + Offset(w * 0.1, w * 0.1), width: w * 1.6, height: w), rockDark);
      canvas.drawOval(Rect.fromCenter(center: o, width: w * 1.5, height: w * 0.9), rock);
    }
  }

  /// Un posto vuoto è prato: un ciuffo e a volte un sassolino.
  void _emptySlot(Canvas canvas, IslandLayout l, Offset o, IslandPalette pal, math.Random r) {
    final h = l.plantHeight;
    final green = pal.stroke(const Color(0xFF5E8F45), h * 0.012);
    for (var i = 0; i < 5; i++) {
      final x = (i - 2) * h * 0.025;
      canvas.drawLine(o + Offset(x, 0), o + Offset(x * 1.6, -h * (0.05 + r.nextDouble() * 0.04)), green);
    }
    if (r.nextBool()) {
      canvas.drawOval(
        Rect.fromCenter(center: o + Offset(h * 0.1, h * 0.01), width: h * 0.07, height: h * 0.04),
        pal.fill(const Color(0xFFA9A49A)),
      );
    }
  }

  /// Il posto del premio prima della fine dell'anno: un cerchio di sassi.
  void _rewardSpot(Canvas canvas, IslandLayout l, Offset c, IslandPalette pal) {
    final h = l.plantHeight;
    canvas.drawOval(Rect.fromCenter(center: c, width: h * 0.5, height: h * 0.2), pal.fill(const Color(0xFFD9C79A)));
    final stone = pal.fill(const Color(0xFFA9A49A));
    for (var i = 0; i < 10; i++) {
      final a = i / 10 * 2 * math.pi;
      canvas.drawOval(
        Rect.fromCenter(
          center: c + Offset(math.cos(a) * h * 0.25, math.sin(a) * h * 0.1),
          width: h * 0.06,
          height: h * 0.035,
        ),
        stone,
      );
    }
  }

  void _lantern(Canvas canvas, IslandLayout l, Offset o, IslandPalette pal) {
    final h = l.plantHeight;
    canvas.drawOval(
      Rect.fromCenter(center: o, width: h * 0.1, height: h * 0.03),
      Paint()..color = const Color(0x30000000),
    );
    canvas.drawRect(
      Rect.fromLTRB(o.dx - h * 0.008, o.dy - h * 0.32, o.dx + h * 0.008, o.dy),
      pal.fill(const Color(0xFF3E3A36)),
    );
    final lamp = Rect.fromCenter(center: o - Offset(0, h * 0.36), width: h * 0.06, height: h * 0.08);
    canvas.drawRRect(
      RRect.fromRectAndRadius(lamp.inflate(h * 0.008), Radius.circular(h * 0.01)),
      pal.fill(const Color(0xFF3E3A36)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(lamp, Radius.circular(h * 0.008)),
      night ? (Paint()..color = const Color(0xFFFFD27A)) : pal.fill(const Color(0xFFF3EBD3)),
    );
    canvas.drawPath(
      Path()..addPolygon([
        lamp.topLeft - Offset(h * 0.015, 0),
        Offset(lamp.center.dx, lamp.top - h * 0.04),
        lamp.topRight + Offset(h * 0.015, 0),
      ], true),
      pal.fill(const Color(0xFF3E3A36)),
    );
  }

  void _glow(Canvas canvas, Offset o, double radius) {
    canvas.drawCircle(
      o,
      radius,
      Paint()
        ..shader = RadialGradient(colors: const [Color(0x88FFC870), Color(0x00FFC870)])
            .createShader(Rect.fromCircle(center: o, radius: radius)),
    );
    final ground = Rect.fromCenter(center: o + Offset(0, radius * 0.72), width: radius * 1.6, height: radius * 0.45);
    canvas.drawOval(
      ground,
      Paint()..shader = RadialGradient(colors: const [Color(0x44FFC870), Color(0x00FFC870)]).createShader(ground),
    );
  }

  void _highlight(Canvas canvas, IslandLayout l, Offset o) {
    final h = l.plantHeight;
    final grow = 1 + pulse * 0.25;
    final ring = Rect.fromCenter(center: o, width: h * 0.42 * grow, height: h * 0.17 * grow);
    canvas.drawOval(ring, Paint()..color = highlightColor.withValues(alpha: 0.18 + 0.12 * (1 - pulse)));
    canvas.drawOval(
      ring,
      Paint()
        ..color = highlightColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );
    final plus = Paint()
      ..color = highlightColor
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    final top = o - Offset(0, h * 0.2);
    canvas.drawCircle(top, h * 0.085, Paint()..color = const Color(0xF0FFFFFF));
    canvas.drawLine(top - Offset(h * 0.04, 0), top + Offset(h * 0.04, 0), plus);
    canvas.drawLine(top - Offset(0, h * 0.04), top + Offset(0, h * 0.04), plus);
  }

  @override
  bool shouldRepaint(IslandPainter old) =>
      old.slots != slots ||
      !mapEquals(old.plants, plants) ||
      old.centerpiece != centerpiece ||
      old.now != now ||
      old.night != night ||
      old.pulse != pulse ||
      !setEquals(old.highlight, highlight) ||
      old.highlightColor != highlightColor;
}

/// Una pianta da sola, per il catalogo: nel mese in cui è più bella, di giorno.
class PlantThumbnailPainter extends CustomPainter {
  final PlantSpecies species;
  final bool night;
  PlantThumbnailPainter(this.species, {this.night = false});

  @override
  void paint(Canvas canvas, Size size) {
    final h = math.min(size.height * 0.8 / plantHeightFactor(species), size.height * 1.5);
    paintPlant(
      canvas,
      species,
      Offset(size.width / 2, size.height * 0.92),
      h,
      month: species.best,
      seed: 7,
      pal: IslandPalette(night: night),
    );
  }

  @override
  bool shouldRepaint(PlantThumbnailPainter old) => old.species != species || old.night != night;
}

bool mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
  if (a.length != b.length) return false;
  for (final e in a.entries) {
    if (!b.containsKey(e.key) || b[e.key] != e.value) return false;
  }
  return true;
}

bool setEquals<T>(Set<T> a, Set<T> b) => a.length == b.length && a.containsAll(b);
