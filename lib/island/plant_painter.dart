/// Il disegno delle piante e dei premi: forme base fatte di cerchi, tracciati
/// e linee, con i colori veri della pianta e la stagione del mese. Il seme
/// (il mese in cui è stata piantata) dà le piccole differenze tra due piante
/// della stessa specie.
library;

import 'dart:math' as math;
import 'dart:ui';

import 'catalog.dart';

/// Colori del giorno o della notte: di notte tutto si scurisce verso il blu,
/// tranne le luci.
class IslandPalette {
  final bool night;
  const IslandPalette({required this.night});

  static const _nightTint = Color(0xFF16203B);

  Color of(Color c) => night ? Color.lerp(c, _nightTint, 0.48)! : c;
  Paint fill(Color c) => Paint()
    ..color = of(c)
    ..isAntiAlias = true;
  Paint stroke(Color c, double width) => Paint()
    ..color = of(c)
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;
}

Color darker(Color c, [double t = 0.22]) => Color.lerp(c, const Color(0xFF000000), t)!;
Color lighter(Color c, [double t = 0.25]) => Color.lerp(c, const Color(0xFFFFFFFF), t)!;

/// Stato delle foglie di un albero che le perde.
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

/// Colori delle foglie (estate, primavera, autunno) degli alberi che le perdono.
const _foliage = <String, (int, int, int)>{
  'oak': (0xFF4F7F3A, 0xFF8DBF5A, 0xFFB8732F),
  'maple': (0xFF5B8E3E, 0xFF9CCB5E, 0xFFD2452B),
  'birch': (0xFF8DBB55, 0xFFB5D985, 0xFFE2B42A),
  'willow': (0xFF9AB654, 0xFFC2D98A, 0xFFCBB24A),
  'apple': (0xFF6A9E3F, 0xFF9BC96A, 0xFFC9A23A),
  'cherry': (0xFF5E9A3E, 0xFF97C76A, 0xFFD2603A),
  'almond': (0xFF84A85A, 0xFFAFCB86, 0xFFC7B15A),
  'fig': (0xFF4E8A3A, 0xFF8CC067, 0xFFC2A53E),
  'hydrangea': (0xFF5C8F4A, 0xFF8DBE6E, 0xFF9C8F4A),
};

Color _leafColor(PlantSpecies s, _Leaf leaf, Color evergreen) {
  final f = _foliage[s.key];
  if (f == null) return evergreen;
  return Color(switch (leaf) {
    _Leaf.budding => f.$2,
    _Leaf.autumn || _Leaf.falling => f.$3,
    _ => f.$1,
  });
}

class _P {
  final Canvas c;
  final IslandPalette pal;
  final math.Random r;
  final Offset b;
  final double h;
  final int month;
  _P(this.c, this.pal, this.r, this.b, this.h, this.month);

  Offset at(double x, double y) => b + Offset(x * h, y * h);
  double rnd(double from, double to) => from + r.nextDouble() * (to - from);

  void shadow(double width) {
    c.drawOval(
      Rect.fromCenter(center: b + Offset(0, h * 0.01), width: width * h, height: width * h * 0.3),
      Paint()..color = const Color(0x30000000),
    );
  }

  /// Tronco da [from] a [to] (in unità di h), largo [w0] in basso e [w1] in
  /// alto, piegato di [bend].
  void trunk(Offset from, Offset to, double w0, double w1, Color color, {double bend = 0}) {
    final a = at(from.dx, from.dy), z = at(to.dx, to.dy);
    final mid = Offset((a.dx + z.dx) / 2 + bend * h, (a.dy + z.dy) / 2);
    final path = Path()
      ..moveTo(a.dx - w0 * h / 2, a.dy)
      ..quadraticBezierTo(mid.dx - (w0 + w1) * h / 4, mid.dy, z.dx - w1 * h / 2, z.dy)
      ..lineTo(z.dx + w1 * h / 2, z.dy)
      ..quadraticBezierTo(mid.dx + (w0 + w1) * h / 4, mid.dy, a.dx + w0 * h / 2, a.dy)
      ..close();
    c.drawPath(path, pal.fill(color));
    // Ombra sul lato destro.
    final side = Path()
      ..moveTo(a.dx + w0 * h * 0.1, a.dy)
      ..quadraticBezierTo(mid.dx + (w0 + w1) * h * 0.05, mid.dy, z.dx + w1 * h * 0.1, z.dy)
      ..lineTo(z.dx + w1 * h / 2, z.dy)
      ..quadraticBezierTo(mid.dx + (w0 + w1) * h / 4, mid.dy, a.dx + w0 * h / 2, a.dy)
      ..close();
    c.drawPath(side, pal.fill(darker(color, 0.25)));
  }

  /// Chioma a bolle dentro l'ellisse ([cx], [cy], [rx], [ry]): ombra, colore,
  /// luce in alto a sinistra. Restituisce i centri e i raggi delle bolle,
  /// per metterci sopra fiori e frutti.
  List<(Offset, double)> crown(double cx, double cy, double rx, double ry, Color color, {int n = 6, double size = 1}) {
    final center = at(cx, cy);
    final blobs = <(Offset, double)>[];
    for (var i = 0; i < n; i++) {
      final angle = i / n * 2 * math.pi + rnd(-0.3, 0.3);
      final dist = i == 0 ? 0.0 : rnd(0.35, 0.62);
      final o = center + Offset(math.cos(angle) * rx * h * dist, math.sin(angle) * ry * h * dist);
      final radius = (rx + ry) / 2 * h * rnd(0.42, 0.56) * size;
      blobs.add((o, radius));
    }
    final dark = pal.fill(darker(color, 0.28));
    for (final (o, rad) in blobs) {
      c.drawCircle(o + Offset(rad * 0.12, rad * 0.16), rad, dark);
    }
    final main = pal.fill(color);
    for (final (o, rad) in blobs) {
      c.drawCircle(o, rad * 0.94, main);
    }
    final light = pal.fill(lighter(color, 0.22));
    for (final (o, rad) in blobs) {
      if (o.dy < center.dy + ry * h * 0.2) c.drawCircle(o - Offset(rad * 0.28, rad * 0.32), rad * 0.42, light);
    }
    return blobs;
  }

  /// Puntini (fiori, frutti) sparsi sulle bolle di una chioma.
  void dots(List<(Offset, double)> blobs, Color color, int count, double radius, {double stretch = 1}) {
    final paint = pal.fill(color);
    final shine = pal.fill(lighter(color, 0.45));
    for (var i = 0; i < count; i++) {
      final (o, rad) = blobs[r.nextInt(blobs.length)];
      final a = rnd(0, 2 * math.pi), d = rnd(0.1, 0.85) * rad;
      final p = o + Offset(math.cos(a) * d, math.sin(a) * d);
      c.drawOval(Rect.fromCenter(center: p, width: radius * h * 2, height: radius * h * 2 * stretch), paint);
      c.drawCircle(p - Offset(radius * h * 0.35, radius * h * 0.4), radius * h * 0.35, shine);
    }
  }

  /// Rami spogli, a ventaglio da [from] verso l'alto. Restituisce le punte.
  List<Offset> branches(
    Offset from,
    double length,
    double width,
    Color color, {
    int depth = 3,
    double angle = -math.pi / 2,
  }) {
    final tips = <Offset>[];
    void grow(Offset p, double a, double len, double w, int d) {
      final end = p + Offset(math.cos(a) * len, math.sin(a) * len);
      c.drawLine(p, end, pal.stroke(color, w));
      if (d == 0) {
        tips.add(end);
        return;
      }
      final n = d == depth ? 3 : 2;
      for (var i = 0; i < n; i++) {
        final spread = n == 3 ? (i - 1) * 0.55 : (i == 0 ? -0.45 : 0.45);
        grow(end, a + spread + rnd(-0.18, 0.18), len * rnd(0.62, 0.78), w * 0.62, d - 1);
      }
    }

    grow(from, angle, length * h, width * h, depth);
    return tips;
  }

  /// Foglie cadute ai piedi dell'albero.
  void fallen(Color color, int n, double spread) {
    final paint = pal.fill(color);
    for (var i = 0; i < n; i++) {
      c.drawOval(
        Rect.fromCenter(center: at(rnd(-spread, spread), rnd(-0.01, 0.025)), width: 0.025 * h, height: 0.012 * h),
        paint,
      );
    }
  }

  /// Foglia lunga e appuntita da [from] lunga [len] con angolo [a].
  void blade(Offset from, double a, double len, double width, Color color, {double bend = 0}) {
    final end = from + Offset(math.cos(a) * len * h, math.sin(a) * len * h);
    final normal = Offset(-math.sin(a), math.cos(a));
    final mid = Offset.lerp(from, end, 0.45)! + normal * bend * h;
    final path = Path()
      ..moveTo(from.dx + normal.dx * width * h / 2, from.dy + normal.dy * width * h / 2)
      ..quadraticBezierTo(mid.dx + normal.dx * width * h / 2, mid.dy + normal.dy * width * h / 2, end.dx, end.dy)
      ..quadraticBezierTo(
        mid.dx - normal.dx * width * h / 2,
        mid.dy - normal.dy * width * h / 2,
        from.dx - normal.dx * width * h / 2,
        from.dy - normal.dy * width * h / 2,
      )
      ..close();
    c.drawPath(path, pal.fill(color));
  }

  /// Un ciuffo basso di foglie (fiori fuori stagione).
  void tuft(Color color, {double width = 0.14, double height = 0.06, int n = 7}) {
    for (var i = 0; i < n; i++) {
      final a = -math.pi / 2 + (i / (n - 1) - 0.5) * 2.2;
      blade(
        at(rnd(-0.02, 0.02), 0),
        a,
        height * rnd(1.2, 1.8),
        0.025,
        i.isEven ? color : darker(color, 0.15),
        bend: rnd(-0.01, 0.01),
      );
    }
    c.drawOval(
      Rect.fromCenter(center: at(0, -0.005), width: width * h, height: 0.03 * h),
      pal.fill(darker(color, 0.2)),
    );
  }

  /// Fiore a corolla: [petals] petali di [color] attorno a un centro.
  void blossom(Offset p, double radius, int petals, Color color, Color center, {double rotation = 0}) {
    final paint = pal.fill(color);
    for (var i = 0; i < petals; i++) {
      final a = rotation + i / petals * 2 * math.pi;
      final o = p + Offset(math.cos(a), math.sin(a)) * radius * h * 0.55;
      c.save();
      c.translate(o.dx, o.dy);
      c.rotate(a);
      c.drawOval(Rect.fromCenter(center: Offset.zero, width: radius * h * 1.0, height: radius * h * 0.48), paint);
      c.restore();
    }
    c.drawCircle(p, radius * h * 0.38, pal.fill(center));
  }
}

/// Fiori, arbusti e piante grasse un po' più grandi del vero, se no accanto
/// agli alberi non si vedono.
double _displayScale(PlantSpecies s) => switch (s.shape) {
  PlantShape.flower => 1.5,
  PlantShape.shrub => 1.25,
  PlantShape.succulent => 1.15,
  _ => 1,
};

/// Altezza del disegno di [s] rispetto all'altezza di un albero: serve a
/// riempire le miniature del catalogo.
double plantHeightFactor(PlantSpecies s) =>
    _displayScale(s) *
    switch (s.key) {
      'cypress' => 1.15,
      'datePalm' => 1.25,
      'fanPalm' => 0.45,
      'stonePine' || 'birch' => 0.95,
      'willow' => 0.8,
      'sunflower' => 0.65,
      'poppy' || 'iris' => 0.38,
      'daisy' => 0.26,
      'tulip' => 0.32,
      'rose' || 'hydrangea' || 'rosemary' => 0.32,
      'lavender' => 0.36,
      'oleander' => 0.56,
      'bougainvillea' => 0.46,
      'pricklyPear' => 0.6,
      'agave' => 0.34,
      'aloe' => 0.55,
      'cactus' => 0.78,
      _ => 0.86,
    };

/// Disegna [species] con la base in [base]. [h] è l'altezza di un albero
/// intero: arbusti e fiori sono più bassi. [month] dà la stagione, [seed] le
/// differenze tra piante della stessa specie.
void paintPlant(
  Canvas canvas,
  PlantSpecies species,
  Offset base,
  double h, {
  required int month,
  required int seed,
  required IslandPalette pal,
}) {
  h *= _displayScale(species);
  final p = _P(canvas, pal, math.Random(seed * 31 + species.key.hashCode), base, h, month);
  final bloom = species.bloom.contains(month), fruit = species.fruit.contains(month);
  final leaf = _leafOf(species, month);
  switch (species.key) {
    case 'oak':
    case 'maple':
      p.shadow(0.5);
      final brown = Color(species.key == 'oak' ? 0xFF6D4C41 : 0xFF5D4037);
      final top = species.key == 'oak' ? -0.42 : -0.4;
      p.trunk(const Offset(0, 0), Offset(0, top), 0.1, 0.07, brown, bend: p.rnd(-0.03, 0.03));
      if (leaf == _Leaf.bare) {
        p.branches(p.at(0, top), 0.2, 0.05, brown);
      } else {
        final sparse = leaf == _Leaf.falling || leaf == _Leaf.budding;
        final color = _leafColor(species, leaf, const Color(0xFF4F7F3A));
        if (sparse) p.branches(p.at(0, top), 0.18, 0.045, brown);
        p.crown(
          0,
          top - 0.2,
          species.key == 'oak' ? 0.34 : 0.3,
          0.28,
          color,
          n: sparse ? 5 : 7,
          size: sparse ? 0.7 : 1,
        );
        if (leaf == _Leaf.falling) p.fallen(color, 7, 0.22);
      }
    case 'olive':
      p.shadow(0.55);
      const bark = Color(0xFF7D6E5D);
      p.trunk(const Offset(-0.02, 0), const Offset(0.03, -0.3), 0.13, 0.06, bark, bend: 0.06);
      p.trunk(const Offset(0.02, 0), const Offset(-0.06, -0.26), 0.07, 0.04, darker(bark, 0.1), bend: -0.04);
      final blobs = p.crown(0, -0.5, 0.4, 0.2, const Color(0xFF7F9467), n: 9, size: 0.75);
      p.dots(blobs, const Color(0xFFC5CCB0), 10, 0.018, stretch: 0.5);
      if (fruit) p.dots(blobs, const Color(0xFF4A2E4F), 14, 0.013);
    case 'birch':
      p.shadow(0.35);
      const bark = Color(0xFFF2EFE8);
      p.trunk(const Offset(0, 0), const Offset(0.01, -0.62), 0.055, 0.03, bark);
      for (var i = 0; i < 6; i++) {
        final y = p.rnd(-0.58, -0.04);
        canvas.drawLine(
          p.at(-0.02, y),
          p.at(p.rnd(-0.005, 0.015), y + 0.004),
          pal.stroke(const Color(0xFF3A3A3A), 0.012 * h),
        );
      }
      if (leaf == _Leaf.bare) {
        p.branches(p.at(0.01, -0.55), 0.16, 0.025, const Color(0xFF8D7B6A));
      } else {
        final color = _leafColor(species, leaf, const Color(0xFF8DBB55));
        p.crown(
          0.01,
          -0.7,
          0.19,
          0.27,
          color,
          n: leaf == _Leaf.falling ? 4 : 7,
          size: leaf == _Leaf.green ? 0.9 : 0.65,
        );
        if (leaf == _Leaf.falling) p.fallen(color, 6, 0.18);
      }
    case 'willow':
      p.shadow(0.6);
      const bark = Color(0xFF6D5A45);
      p.trunk(const Offset(0, 0), const Offset(0.01, -0.38), 0.11, 0.07, bark, bend: 0.03);
      final color = leaf == _Leaf.bare ? const Color(0xFF9C8B66) : _leafColor(species, leaf, const Color(0xFF9AB654));
      if (leaf != _Leaf.bare) p.crown(0.01, -0.6, 0.32, 0.17, color, n: 6, size: 0.9);
      final strands = leaf == _Leaf.bare ? 16 : (leaf == _Leaf.falling ? 12 : 20);
      for (var i = 0; i < strands; i++) {
        final x = -0.34 + i / (strands - 1) * 0.68;
        final from = p.at(x * 0.8 + 0.01, -0.62 + (x * x) * 1.1);
        final end = p.at(x + (x.sign * 0.04), p.rnd(-0.16, -0.08));
        final ctrl = Offset((from.dx + end.dx) / 2 + x.sign * 0.03 * h, from.dy + 0.05 * h);
        canvas.drawPath(
          Path()
            ..moveTo(from.dx, from.dy)
            ..quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy),
          pal.stroke(i.isEven ? color : darker(color, 0.15), (leaf == _Leaf.bare ? 0.008 : 0.032) * h),
        );
      }
    case 'stonePine':
      p.shadow(0.55);
      const bark = Color(0xFF8E5B3E);
      p.trunk(const Offset(0, 0), const Offset(0.06, -0.68), 0.075, 0.045, bark, bend: 0.05);
      p.trunk(const Offset(0.04, -0.5), const Offset(-0.12, -0.68), 0.03, 0.02, bark);
      p.crown(0.02, -0.72, 0.42, 0.1, const Color(0xFF3E6A3B), n: 8, size: 0.62);
    case 'lemon':
    case 'orange':
      p.shadow(0.45);
      p.trunk(const Offset(0, 0), const Offset(0, -0.3), 0.08, 0.055, const Color(0xFF6F5A48));
      final blobs = p.crown(0, -0.52, 0.28, 0.25, Color(species.key == 'lemon' ? 0xFF3F7D3B : 0xFF2F6B33), n: 7);
      if (bloom) p.dots(blobs, const Color(0xFFFFFFFF), 12, 0.011);
      if (fruit) {
        species.key == 'lemon'
            ? p.dots(blobs, const Color(0xFFF2D33B), 9, 0.022, stretch: 1.3)
            : p.dots(blobs, const Color(0xFFF28C1E), 11, 0.024);
      }
    case 'apple':
    case 'cherry':
    case 'fig':
      p.shadow(0.45);
      final bark = Color(species.key == 'fig' ? 0xFF9C9488 : 0xFF6A4E3E);
      p.trunk(const Offset(0, 0), const Offset(0, -0.3), 0.085, 0.06, bark, bend: p.rnd(-0.03, 0.03));
      final cherryBlossom = species.key == 'cherry' && bloom;
      if (leaf == _Leaf.bare && !cherryBlossom) {
        p.branches(p.at(0, -0.3), 0.17, 0.045, bark);
      } else if (cherryBlossom) {
        p.branches(p.at(0, -0.3), 0.15, 0.04, bark);
        final blobs = p.crown(0, -0.52, 0.29, 0.25, const Color(0xFFF6B3C8), n: 7);
        p.dots(blobs, const Color(0xFFFFF0F5), 18, 0.012);
      } else {
        final sparse = leaf == _Leaf.falling || leaf == _Leaf.budding;
        final color = _leafColor(species, leaf, const Color(0xFF6A9E3F));
        if (sparse) p.branches(p.at(0, -0.3), 0.15, 0.04, bark);
        final blobs = p.crown(
          0,
          -0.52,
          0.28,
          0.24,
          color,
          n: sparse ? 5 : (species.key == 'fig' ? 5 : 7),
          size: sparse ? 0.7 : (species.key == 'fig' ? 1.1 : 1),
        );
        if (species.key == 'apple' && bloom) p.dots(blobs, const Color(0xFFF9DDE5), 26, 0.016);
        if (fruit) {
          switch (species.key) {
            case 'apple':
              p.dots(blobs, const Color(0xFFD9342B), 9, 0.024);
            case 'cherry':
              p.dots(blobs, const Color(0xFFA4161A), 12, 0.014);
            case 'fig':
              p.dots(blobs, const Color(0xFF6D3B5C), 8, 0.02, stretch: 1.3);
          }
        }
        if (leaf == _Leaf.falling) p.fallen(color, 6, 0.2);
      }
    case 'almond':
      p.shadow(0.45);
      const bark = Color(0xFF5E4A3E);
      p.trunk(const Offset(0, 0), const Offset(0, -0.3), 0.08, 0.055, bark, bend: 0.03);
      if (bloom) {
        // Fiorisce sui rami ancora spogli.
        final tips = p.branches(p.at(0, -0.3), 0.18, 0.045, bark);
        final white = pal.fill(const Color(0xFFFCE8EE)), pink = pal.fill(const Color(0xFFF4B6C8));
        for (final t in tips) {
          for (var i = 0; i < 4; i++) {
            final o = t + Offset(p.rnd(-0.04, 0.04) * h, p.rnd(-0.03, 0.05) * h);
            canvas.drawCircle(o, 0.02 * h, i.isEven ? white : pink);
          }
        }
      } else if (leaf == _Leaf.bare) {
        p.branches(p.at(0, -0.3), 0.18, 0.045, bark);
      } else {
        final color = _leafColor(species, leaf, const Color(0xFF84A85A));
        p.branches(p.at(0, -0.3), 0.16, 0.04, bark);
        p.crown(0, -0.53, 0.27, 0.22, color, n: 7, size: leaf == _Leaf.green ? 0.85 : 0.6);
      }
    case 'fir':
      p.shadow(0.4);
      p.trunk(const Offset(0, 0), const Offset(0, -0.14), 0.06, 0.05, const Color(0xFF5D4037));
      for (var i = 0; i < 4; i++) {
        final bottom = -0.1 - i * 0.2, top = bottom - 0.34;
        final w = 0.5 * (1 - i * 0.2);
        final left = p.at(-w / 2, bottom), right = p.at(w / 2, bottom), tip = p.at(0, top);
        final mid = p.at(0, bottom + 0.03);
        canvas.drawPath(Path()..addPolygon([left, tip, mid], true), pal.fill(const Color(0xFF3F7550)));
        canvas.drawPath(Path()..addPolygon([mid, tip, right], true), pal.fill(const Color(0xFF2B5A3B)));
      }
    case 'cypress':
      p.shadow(0.25);
      final w = p.rnd(0.2, 0.24);
      final flame = Path()
        ..moveTo(p.at(-w * 0.35, 0).dx, p.at(0, -0.04).dy)
        ..cubicTo(
          p.at(-w * 0.6, 0).dx,
          p.at(0, -0.3).dy,
          p.at(-w * 0.45, 0).dx,
          p.at(0, -0.8).dy,
          p.at(0, 0).dx,
          p.at(0, -1.15).dy,
        )
        ..cubicTo(
          p.at(w * 0.45, 0).dx,
          p.at(0, -0.8).dy,
          p.at(w * 0.6, 0).dx,
          p.at(0, -0.3).dy,
          p.at(w * 0.35, 0).dx,
          p.at(0, -0.04).dy,
        )
        ..close();
      canvas.drawPath(flame, pal.fill(const Color(0xFF2F4F35)));
      canvas.save();
      canvas.clipPath(flame);
      canvas.drawRect(
        Rect.fromLTRB(p.at(-w, 0).dx, p.at(0, -1.2).dy, p.at(-0.02, 0).dx, base.dy),
        pal.fill(const Color(0xFF41664A)),
      );
      for (var i = 0; i < 12; i++) {
        final o = p.at(p.rnd(-w * 0.4, w * 0.4), p.rnd(-1.05, -0.08));
        canvas.drawLine(o, o + Offset(0.03 * h, 0.05 * h), pal.stroke(const Color(0xFF243D2A), 0.012 * h));
      }
      canvas.restore();
    case 'datePalm':
      p.shadow(0.5);
      final top = p.at(0.12, -0.9);
      for (var i = 0; i <= 10; i++) {
        final t = i / 10;
        final o = Offset.lerp(base, top, t)! + Offset(math.sin(t * math.pi) * -0.05 * h, 0);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: o, width: (0.08 - t * 0.02) * h, height: 0.1 * h),
            Radius.circular(0.03 * h),
          ),
          pal.fill(Color(i.isEven ? 0xFF8D6E4F : 0xFF7A5C41)),
        );
      }
      if (fruit) {
        final orange = pal.fill(const Color(0xFFD9822B));
        for (var i = 0; i < 14; i++) {
          canvas.drawCircle(top + Offset(p.rnd(-0.07, 0.07) * h, p.rnd(0.02, 0.1) * h), 0.016 * h, orange);
        }
      }
      for (var i = 0; i < 10; i++) {
        final a = -math.pi + i / 9 * math.pi + p.rnd(-0.1, 0.1);
        final droop = (math.cos(a).abs()) * 0.18;
        final len = p.rnd(0.34, 0.42) * h;
        final end = top + Offset(math.cos(a) * len, math.sin(a) * len * 0.55 + droop * h);
        final ctrl = top + Offset(math.cos(a) * len * 0.55, math.sin(a) * len * 0.6 - 0.04 * h);
        final green = i.isEven ? const Color(0xFF4D8B3C) : const Color(0xFF3E7832);
        final path = Path()
          ..moveTo(top.dx, top.dy)
          ..quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy);
        canvas.drawPath(path, pal.stroke(green, 0.018 * h));
        for (final metric in path.computeMetrics()) {
          for (var d = 0.12; d < 0.95; d += 0.09) {
            final tan = metric.getTangentForOffset(metric.length * d)!;
            final n = Offset(-tan.vector.dy, tan.vector.dx);
            final leafLen = (1 - d) * 0.07 * h + 0.015 * h;
            for (final side in [-1.0, 1.0]) {
              canvas.drawLine(
                tan.position,
                tan.position + (n * side + tan.vector * 0.6) * leafLen,
                pal.stroke(green, 0.01 * h),
              );
            }
          }
        }
      }
    case 'fanPalm':
      p.shadow(0.45);
      for (final (x, height) in [(-0.09, 0.16), (0.07, 0.24), (0.0, 0.12)]) {
        final top = p.at(x, -height);
        p.trunk(Offset(x * 0.4, 0), Offset(x, -height), 0.06, 0.05, const Color(0xFF6F5B44));
        for (var i = 0; i < 11; i++) {
          final a = -math.pi * 1.05 + i / 10 * math.pi * 1.1;
          p.blade(top, a, p.rnd(0.14, 0.18), 0.035, i.isEven ? const Color(0xFF5E8E52) : const Color(0xFF4C7A44));
        }
      }
    case 'lavender':
      p.shadow(0.35);
      final stem = pal.stroke(const Color(0xFF8DA08A), 0.008 * h);
      final tips = <Offset>[];
      for (var i = 0; i < 18; i++) {
        final a = -math.pi / 2 + (i / 17 - 0.5) * 1.3;
        final len = p.rnd(0.24, 0.33) * (bloom ? 1 : 0.7);
        final end = p.at(math.cos(a) * len, math.sin(a) * len);
        canvas.drawLine(p.at(0, -0.02), end, stem);
        tips.add(end);
      }
      p.crown(0, -0.06, 0.16, 0.06, const Color(0xFF91A88C), n: 5, size: 0.8);
      if (bloom) {
        for (final t in tips) {
          canvas.drawOval(
            Rect.fromCenter(center: t, width: 0.022 * h, height: 0.07 * h),
            pal.fill(const Color(0xFF8B6BC2)),
          );
          canvas.drawCircle(t + Offset(0.004 * h, 0.012 * h), 0.007 * h, pal.fill(const Color(0xFF6D4FA8)));
        }
      }
    case 'rosemary':
      p.shadow(0.38);
      final blobs = p.crown(0, -0.15, 0.2, 0.15, const Color(0xFF4F6E50), n: 6);
      final needle = pal.stroke(const Color(0xFF6E8E6B), 0.007 * h);
      for (var i = 0; i < 40; i++) {
        final (o, rad) = blobs[p.r.nextInt(blobs.length)];
        final s = o + Offset(p.rnd(-rad, rad) * 0.8, p.rnd(-rad, rad) * 0.8);
        canvas.drawLine(s, s + Offset(p.rnd(-0.015, 0.015) * h, -0.03 * h), needle);
      }
      if (bloom) p.dots(blobs, const Color(0xFFA9C4F0), 24, 0.009);
    case 'oleander':
      p.shadow(0.42);
      for (final x in [-0.05, 0.0, 0.05]) {
        canvas.drawLine(p.at(x * 0.5, 0), p.at(x, -0.18), pal.stroke(const Color(0xFF6B5A44), 0.018 * h));
      }
      final blobs = p.crown(0, -0.3, 0.22, 0.24, const Color(0xFF4C7D47), n: 7);
      if (bloom) {
        for (var i = 0; i < 12; i++) {
          final (o, rad) = blobs[p.r.nextInt(blobs.length)];
          final c = o + Offset(p.rnd(-0.7, 0.7) * rad, p.rnd(-0.8, 0.4) * rad);
          p.blossom(c, 0.026, 5, const Color(0xFFF07AA2), const Color(0xFFF9D5E2), rotation: p.rnd(0, 1));
        }
      }
    case 'hydrangea':
      p.shadow(0.45);
      if (leaf == _Leaf.bare) {
        final stem = pal.stroke(const Color(0xFF8C7A66), 0.012 * h);
        for (var i = 0; i < 6; i++) {
          final end = p.at(p.rnd(-0.16, 0.16), p.rnd(-0.26, -0.16));
          canvas.drawLine(p.at(0, 0), end, stem);
          canvas.drawCircle(end, 0.035 * h, pal.fill(const Color(0xFFA58C76)));
        }
      } else {
        final blobs = p.crown(0, -0.16, 0.22, 0.15, _leafColor(species, leaf, const Color(0xFF5C8F4A)), n: 6);
        if (bloom) {
          for (var i = 0; i < 6; i++) {
            final (o, rad) = blobs[i % blobs.length];
            final head = o + Offset(p.rnd(-0.4, 0.4) * rad, -rad * 0.35);
            for (var j = 0; j < 9; j++) {
              final a = j / 9 * 2 * math.pi;
              final color = (i + j).isEven ? const Color(0xFF7FA6E3) : const Color(0xFFA48FE2);
              canvas.drawCircle(head + Offset(math.cos(a), math.sin(a)) * 0.032 * h, 0.022 * h, pal.fill(color));
            }
            canvas.drawCircle(head, 0.026 * h, pal.fill(const Color(0xFF9AB8EC)));
          }
        }
      }
    case 'bougainvillea':
      p.shadow(0.48);
      for (final a in [-2.4, -1.9, -1.2, -0.75]) {
        canvas.drawLine(
          p.at(0, 0),
          p.at(math.cos(a) * 0.25, math.sin(a) * 0.3),
          pal.stroke(const Color(0xFF6B5A44), 0.014 * h),
        );
      }
      final blobs = p.crown(0, -0.24, 0.26, 0.2, const Color(0xFF4D873F), n: 7);
      if (bloom) {
        p.dots(blobs, const Color(0xFFD8268E), 38, 0.017);
        p.dots(blobs, const Color(0xFFEC5FAE), 16, 0.012);
      }
    case 'sunflower':
      p.shadow(0.25);
      if (bloom || month == 5 || month == 6) {
        for (final (x, height) in [(-0.05, 0.56), (0.06, 0.46)]) {
          final top = p.at(x, -height);
          canvas.drawLine(p.at(x * 0.6, 0), top, pal.stroke(const Color(0xFF5D8C3A), 0.018 * h));
          for (var i = 0; i < 3; i++) {
            final y = -height * (0.25 + i * 0.22);
            final side = i.isEven ? -1.0 : 1.0;
            p.blade(p.at(x, y), side < 0 ? math.pi * 1.15 : -math.pi * 0.15, 0.09, 0.05, const Color(0xFF5F9440));
          }
          if (bloom) {
            p.blossom(top, 0.065, 14, const Color(0xFFF7C51E), const Color(0xFF5A3A1E), rotation: p.rnd(0, 1));
            canvas.drawCircle(top, 0.03 * h, pal.fill(const Color(0xFF4A2E16)));
          } else {
            canvas.drawCircle(top, 0.025 * h, pal.fill(const Color(0xFF6E9E4A)));
          }
        }
      } else {
        p.tuft(const Color(0xFF6E9E4A), height: 0.05);
      }
    case 'poppy':
    case 'daisy':
      p.shadow(0.3);
      if (!bloom) {
        p.tuft(Color(species.key == 'poppy' ? 0xFF7E9A6A : 0xFF6C9E52));
        break;
      }
      p.tuft(const Color(0xFF6C9E52), height: 0.04);
      final n = species.key == 'poppy' ? 5 : 7;
      for (var i = 0; i < n; i++) {
        final x = (i / (n - 1) - 0.5) * 0.24 + p.rnd(-0.015, 0.015);
        final height = species.key == 'poppy' ? p.rnd(0.18, 0.3) : p.rnd(0.1, 0.2);
        final top = p.at(x + p.rnd(-0.03, 0.03), -height);
        canvas.drawPath(
          Path()
            ..moveTo(p.at(x * 0.5, 0).dx, base.dy)
            ..quadraticBezierTo(p.at(x, 0).dx + p.rnd(-0.03, 0.03) * h, (base.dy + top.dy) / 2, top.dx, top.dy),
          pal.stroke(const Color(0xFF5E8C47), 0.009 * h),
        );
        if (species.key == 'poppy') {
          canvas.drawCircle(top + Offset(-0.012 * h, 0), 0.03 * h, pal.fill(const Color(0xFFE3342F)));
          canvas.drawCircle(top + Offset(0.012 * h, 0), 0.03 * h, pal.fill(const Color(0xFFCB2A26)));
          canvas.drawCircle(top + Offset(0, -0.004 * h), 0.009 * h, pal.fill(const Color(0xFF231815)));
        } else {
          p.blossom(top, 0.032, 10, const Color(0xFFFFFFFF), const Color(0xFFF3C623), rotation: p.rnd(0, 1));
        }
      }
    case 'tulip':
      p.shadow(0.3);
      if (!bloom && month > 6 && month < 12 || month <= 2) {
        // Bulbi sotto terra.
        canvas.drawOval(
          Rect.fromCenter(center: p.at(0, -0.01), width: 0.18 * h, height: 0.05 * h),
          pal.fill(const Color(0xFF8B6B4A)),
        );
        break;
      }
      for (var i = 0; i < 5; i++) {
        final x = (i / 4 - 0.5) * 0.22;
        p.blade(p.at(x, 0), -math.pi / 2 + (x * 3), 0.12, 0.04, const Color(0xFF6C9A5A), bend: 0.01);
        if (!bloom) continue;
        final height = p.rnd(0.18, 0.26);
        final top = p.at(x, -height);
        canvas.drawLine(p.at(x, 0), top, pal.stroke(const Color(0xFF5E8C47), 0.01 * h));
        final color = Color((seed + i).isEven ? 0xFFE0322E : 0xFFF5C518);
        final w = 0.045 * h, hh = 0.06 * h;
        canvas.drawPath(
          Path()
            ..moveTo(top.dx - w / 2, top.dy - hh)
            ..lineTo(top.dx - w / 4, top.dy - hh * 0.7)
            ..lineTo(top.dx, top.dy - hh)
            ..lineTo(top.dx + w / 4, top.dy - hh * 0.7)
            ..lineTo(top.dx + w / 2, top.dy - hh)
            ..quadraticBezierTo(top.dx + w / 2, top.dy + hh * 0.1, top.dx, top.dy + hh * 0.05)
            ..quadraticBezierTo(top.dx - w / 2, top.dy + hh * 0.1, top.dx - w / 2, top.dy - hh)
            ..close(),
          pal.fill(color),
        );
      }
    case 'rose':
      p.shadow(0.36);
      if (month == 12 || month <= 2) {
        final cane = pal.stroke(const Color(0xFF6B5D3F), 0.012 * h);
        for (var i = 0; i < 6; i++) {
          canvas.drawLine(p.at(0, 0), p.at(p.rnd(-0.14, 0.14), p.rnd(-0.26, -0.16)), cane);
        }
        break;
      }
      final blobs = p.crown(0, -0.14, 0.18, 0.13, const Color(0xFF3E6B3A), n: 6);
      if (bloom) {
        for (var i = 0; i < 6; i++) {
          final (o, rad) = blobs[i % blobs.length];
          final c = o + Offset(p.rnd(-0.5, 0.5) * rad, p.rnd(-0.6, 0.2) * rad);
          canvas.drawCircle(c, 0.026 * h, pal.fill(const Color(0xFFC8213A)));
          canvas.drawArc(
            Rect.fromCircle(center: c, radius: 0.014 * h),
            0,
            4.5,
            false,
            pal.stroke(const Color(0xFFE85A6E), 0.006 * h),
          );
        }
      }
    case 'iris':
      p.shadow(0.3);
      for (var i = 0; i < 9; i++) {
        final x = (i / 8 - 0.5) * 0.16;
        p.blade(
          p.at(x, 0),
          -math.pi / 2 + x * 2.5 + p.rnd(-0.08, 0.08),
          p.rnd(0.2, 0.3),
          0.03,
          i.isEven ? const Color(0xFF5D8E6B) : const Color(0xFF4E7D5C),
        );
      }
      if (bloom) {
        for (final x in [-0.06, 0.01, 0.07]) {
          final top = p.at(x, -p.rnd(0.32, 0.38));
          canvas.drawLine(p.at(x * 0.5, 0), top, pal.stroke(const Color(0xFF4E7D5C), 0.01 * h));
          const purple = Color(0xFF6B4FC8);
          for (final a in [-2.2, -1.57, -0.9]) {
            p.blade(top, a, 0.05, 0.03, lighter(purple, 0.15));
          }
          for (final a in [2.5, 1.57, 0.6]) {
            p.blade(top, a, 0.045, 0.032, purple);
          }
          canvas.drawCircle(top + Offset(0, 0.012 * h), 0.008 * h, pal.fill(const Color(0xFFF2C94C)));
        }
      }
    case 'pricklyPear':
      p.shadow(0.4);
      final pads = <(Offset, double, double)>[];
      void pad(Offset bottom, double angle, double size, int depth) {
        final center = bottom + Offset(math.cos(angle), math.sin(angle)) * size * h * 0.5;
        pads.add((center, angle, size));
        if (depth == 0) return;
        final tip = bottom + Offset(math.cos(angle), math.sin(angle)) * size * h * 0.9;
        pad(tip, angle - p.rnd(0.35, 0.6), size * 0.82, depth - 1);
        if (depth == 2 || p.r.nextBool()) pad(tip, angle + p.rnd(0.35, 0.6), size * 0.8, depth - 1);
      }

      pad(p.at(0, 0), -math.pi / 2, 0.22, 2);
      for (final (center, angle, size) in pads) {
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(angle + math.pi / 2);
        final rect = Rect.fromCenter(center: Offset.zero, width: size * h * 0.7, height: size * h);
        canvas.drawOval(rect.translate(size * h * 0.05, size * h * 0.04), pal.fill(const Color(0xFF55803A)));
        canvas.drawOval(rect, pal.fill(const Color(0xFF6E9B4C)));
        final spine = pal.fill(const Color(0xFFE8E3C0));
        for (var i = 0; i < 5; i++) {
          canvas.drawCircle(Offset(p.rnd(-0.25, 0.25) * size * h, p.rnd(-0.35, 0.35) * size * h), 0.006 * h, spine);
        }
        canvas.restore();
        final top = center + Offset(math.cos(angle), math.sin(angle)) * size * h * 0.48;
        if (bloom && size < 0.2) {
          p.blossom(top, 0.022, 6, const Color(0xFFF5CF3B), const Color(0xFFE0A526));
        } else if (fruit && size < 0.2) {
          for (final dx in [-0.03, 0.0, 0.03]) {
            canvas.drawOval(
              Rect.fromCenter(center: top + Offset(dx * h, 0), width: 0.022 * h, height: 0.03 * h),
              pal.fill(const Color(0xFFE1573A)),
            );
          }
        }
      }
    case 'agave':
    case 'aloe':
      final agave = species.key == 'agave';
      p.shadow(agave ? 0.5 : 0.35);
      if (!agave && bloom) {
        for (final x in [-0.04, 0.05]) {
          final top = p.at(x, -0.5);
          canvas.drawLine(p.at(x * 0.3, -0.05), top, pal.stroke(const Color(0xFF6F7F4A), 0.012 * h));
          canvas.drawPath(
            Path()
              ..moveTo(top.dx - 0.025 * h, top.dy + 0.12 * h)
              ..lineTo(top.dx, top.dy - 0.01 * h)
              ..lineTo(top.dx + 0.025 * h, top.dy + 0.12 * h)
              ..close(),
            pal.fill(const Color(0xFFE85A2C)),
          );
          canvas.drawCircle(top, 0.01 * h, pal.fill(const Color(0xFFF2C94C)));
        }
      }
      final n = agave ? 13 : 10;
      final color = Color(agave ? 0xFF7EA295 : 0xFF6F9A58);
      // Prima le foglie esterne, poi quelle al centro, davanti.
      final order = [for (var i = 0; i < n; i++) i]
        ..sort((a, b) => (b - (n - 1) / 2).abs().compareTo((a - (n - 1) / 2).abs()));
      for (final i in order) {
        final a = -math.pi + (i + 0.5) / n * math.pi;
        final len = (agave ? 0.3 : 0.18) * (1 - (math.cos(a).abs()) * 0.35) * p.rnd(0.9, 1.1);
        p.blade(
          p.at(0, -0.02),
          a,
          len,
          agave ? 0.06 : 0.045,
          (i.isEven ? color : darker(color, 0.12)),
          bend: math.cos(a) * 0.015,
        );
      }
    case 'cactus':
      p.shadow(0.3);
      const green = Color(0xFF4E8B4A);
      void column(Rect r) {
        final rr = RRect.fromRectAndRadius(r, Radius.circular(r.width / 2));
        canvas.drawRRect(rr, pal.fill(green));
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(r.left, r.top, r.left + r.width * 0.35, r.bottom),
            Radius.circular(r.width / 2),
          ),
          pal.fill(const Color(0xFF6AA864)),
        );
        for (var i = 1; i < 3; i++) {
          final x = r.left + r.width * i / 3;
          canvas.drawLine(
            Offset(x, r.top + r.width * 0.4),
            Offset(x, r.bottom - 2),
            pal.stroke(const Color(0xFF3D7039), 0.006 * h),
          );
        }
      }

      final body = Rect.fromLTRB(p.at(-0.065, 0).dx, p.at(0, -0.72).dy, p.at(0.065, 0).dx, base.dy);
      // Braccia: un tratto orizzontale e uno che sale.
      final leftArm = Rect.fromLTRB(p.at(-0.2, 0).dx, p.at(0, -0.52).dy, p.at(-0.12, 0).dx, p.at(0, -0.3).dy);
      final rightArm = Rect.fromLTRB(p.at(0.12, 0).dx, p.at(0, -0.62).dy, p.at(0.2, 0).dx, p.at(0, -0.4).dy);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(leftArm.left, p.at(0, -0.36).dy, body.center.dx, p.at(0, -0.28).dy),
          Radius.circular(0.04 * h),
        ),
        pal.fill(green),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(body.center.dx, p.at(0, -0.46).dy, rightArm.right, p.at(0, -0.38).dy),
          Radius.circular(0.04 * h),
        ),
        pal.fill(green),
      );
      column(leftArm);
      column(rightArm);
      column(body);
      if (bloom) {
        for (final o in [
          Offset(body.center.dx, body.top),
          Offset(leftArm.center.dx, leftArm.top),
          Offset(rightArm.center.dx, rightArm.top),
        ]) {
          p.blossom(o, 0.026, 7, const Color(0xFFF0679A), const Color(0xFFF7C1D5));
        }
      }
  }
}

/// Il premio al centro dell'isola, alto circa [h].
void paintCenterpiece(Canvas canvas, String key, Offset base, double h, {required IslandPalette pal}) {
  final p = _P(canvas, pal, math.Random(key.hashCode), base, h, 6);
  const stone = Color(0xFFBDB6A8), marble = Color(0xFFF1EDE4);
  switch (key) {
    case 'lighthouse':
      p.shadow(0.4);
      p.crown(0, -0.04, 0.18, 0.06, const Color(0xFF8D8D8D), n: 5, size: 0.8);
      final towerBottom = -0.06, towerTop = -0.8;
      Path band(double y0, double y1) {
        double w(double y) => 0.12 - (y - towerBottom) / (towerTop - towerBottom) * 0.04;
        return Path()..addPolygon([p.at(-w(y0), y0), p.at(-w(y1), y1), p.at(w(y1), y1), p.at(w(y0), y0)], true);
      }

      canvas.drawPath(band(towerBottom, towerTop), pal.fill(const Color(0xFFF5F2EA)));
      for (var i = 0; i < 3; i++) {
        final y0 = towerBottom - 0.1 - i * 0.22;
        canvas.drawPath(band(y0, y0 - 0.1), pal.fill(const Color(0xFFC0392B)));
      }
      canvas.drawRect(
        Rect.fromLTRB(p.at(0.02, 0).dx, p.at(0, towerTop).dy, p.at(0.12, 0).dx, p.at(0, towerBottom).dy),
        Paint()..color = const Color(0x18000000),
      );
      canvas.drawRect(
        Rect.fromLTRB(p.at(-0.11, 0).dx, p.at(0, -0.83).dy, p.at(0.11, 0).dx, p.at(0, -0.8).dy),
        pal.fill(const Color(0xFF37474F)),
      );
      final glass = Rect.fromLTRB(p.at(-0.06, 0).dx, p.at(0, -0.94).dy, p.at(0.06, 0).dx, p.at(0, -0.83).dy);
      canvas.drawRect(
        glass,
        pal.night ? (Paint()..color = const Color(0xFFFFE08A)) : pal.fill(const Color(0xFFBFE3F2)),
      );
      canvas.drawPath(
        Path()..addPolygon([p.at(-0.08, -0.94), p.at(0, -1.03), p.at(0.08, -0.94)], true),
        pal.fill(const Color(0xFFA93226)),
      );
      if (pal.night) {
        final c = glass.center;
        final beam = Paint()..shader = Gradient.radial(c, 1.2 * h, [const Color(0x66FFE08A), const Color(0x00FFE08A)]);
        canvas.drawPath(
          Path()..addPolygon([c, c + Offset(-1.2 * h, -0.12 * h), c + Offset(-1.2 * h, 0.1 * h)], true),
          beam,
        );
        canvas.drawPath(
          Path()..addPolygon([c, c + Offset(1.2 * h, -0.1 * h), c + Offset(1.2 * h, 0.12 * h)], true),
          beam,
        );
        canvas.drawCircle(
          c,
          0.12 * h,
          Paint()..shader = Gradient.radial(c, 0.12 * h, [const Color(0x99FFE08A), const Color(0x00FFE08A)]),
        );
      }
    case 'fountain':
      p.shadow(0.55);
      final basin = Rect.fromCenter(center: p.at(0, -0.05), width: 0.5 * h, height: 0.16 * h);
      canvas.drawRect(
        Rect.fromLTRB(basin.left, basin.center.dy, basin.right, basin.center.dy + 0.07 * h),
        pal.fill(darker(stone, 0.1)),
      );
      canvas.drawOval(basin.translate(0, 0.07 * h), pal.fill(darker(stone, 0.1)));
      canvas.drawOval(basin, pal.fill(stone));
      canvas.drawOval(basin.deflate(0.025 * h), pal.fill(const Color(0xFF7CC4E4)));
      canvas.drawRect(Rect.fromCenter(center: p.at(0, -0.2), width: 0.06 * h, height: 0.3 * h), pal.fill(stone));
      final bowl = Rect.fromCenter(center: p.at(0, -0.36), width: 0.24 * h, height: 0.07 * h);
      canvas.drawArc(bowl.translate(0, 0.01 * h), 0, math.pi, true, pal.fill(darker(stone, 0.1)));
      canvas.drawOval(bowl, pal.fill(stone));
      canvas.drawOval(bowl.deflate(0.015 * h), pal.fill(const Color(0xFF8FD0EC)));
      final water = pal.stroke(const Color(0xFFBDE7F7), 0.012 * h);
      final top = p.at(0, -0.52);
      canvas.drawLine(p.at(0, -0.38), top, water);
      for (final side in [-1.0, 1.0]) {
        canvas.drawPath(
          Path()
            ..moveTo(top.dx, top.dy)
            ..quadraticBezierTo(top.dx + side * 0.12 * h, top.dy - 0.06 * h, top.dx + side * 0.13 * h, bowl.center.dy),
          water,
        );
        canvas.drawPath(
          Path()
            ..moveTo(bowl.center.dx + side * 0.12 * h, bowl.center.dy)
            ..quadraticBezierTo(
              bowl.center.dx + side * 0.2 * h,
              bowl.center.dy,
              bowl.center.dx + side * 0.21 * h,
              basin.center.dy - 0.01 * h,
            ),
          water,
        );
      }
    case 'temple':
      p.shadow(0.6);
      for (var i = 0; i < 3; i++) {
        final w = 0.56 - i * 0.04;
        canvas.drawRect(
          Rect.fromLTRB(p.at(-w / 2, 0).dx, p.at(0, -0.04 - i * 0.04).dy, p.at(w / 2, 0).dx, p.at(0, -i * 0.04).dy),
          pal.fill(i.isEven ? const Color(0xFFE6E0D3) : const Color(0xFFD8D1C2)),
        );
      }
      canvas.drawRect(
        Rect.fromLTRB(p.at(-0.22, 0).dx, p.at(0, -0.56).dy, p.at(0.22, 0).dx, p.at(0, -0.12).dy),
        pal.fill(const Color(0xFF8A8172)),
      );
      for (var i = 0; i < 4; i++) {
        final x = -0.2 + i * 0.4 / 3;
        canvas.drawRect(Rect.fromCenter(center: p.at(x, -0.34), width: 0.055 * h, height: 0.44 * h), pal.fill(marble));
        canvas.drawRect(
          Rect.fromLTRB(p.at(x + 0.008, 0).dx, p.at(0, -0.56).dy, p.at(x + 0.028, 0).dx, p.at(0, -0.12).dy),
          pal.fill(darker(marble, 0.08)),
        );
        canvas.drawRect(Rect.fromCenter(center: p.at(x, -0.565), width: 0.08 * h, height: 0.025 * h), pal.fill(marble));
      }
      canvas.drawRect(
        Rect.fromLTRB(p.at(-0.26, 0).dx, p.at(0, -0.64).dy, p.at(0.26, 0).dx, p.at(0, -0.575).dy),
        pal.fill(const Color(0xFFE6E0D3)),
      );
      canvas.drawPath(
        Path()..addPolygon([p.at(-0.28, -0.64), p.at(0, -0.8), p.at(0.28, -0.64)], true),
        pal.fill(marble),
      );
      canvas.drawPath(
        Path()..addPolygon([p.at(-0.2, -0.655), p.at(0, -0.76), p.at(0.2, -0.655)], true),
        pal.fill(darker(marble, 0.1)),
      );
    case 'statue':
      p.shadow(0.4);
      canvas.drawRect(Rect.fromLTRB(p.at(-0.14, 0).dx, p.at(0, -0.36).dy, p.at(0.14, 0).dx, base.dy), pal.fill(stone));
      canvas.drawRect(
        Rect.fromLTRB(p.at(-0.17, 0).dx, p.at(0, -0.4).dy, p.at(0.17, 0).dx, p.at(0, -0.35).dy),
        pal.fill(lighter(stone, 0.2)),
      );
      canvas.drawRect(
        Rect.fromLTRB(p.at(0.04, 0).dx, p.at(0, -0.35).dy, p.at(0.14, 0).dx, base.dy),
        Paint()..color = const Color(0x18000000),
      );
      // Una figura con la veste lunga e una corona d'alloro alzata.
      final robe = Path()
        ..moveTo(p.at(-0.1, -0.4).dx, p.at(0, -0.4).dy)
        ..quadraticBezierTo(p.at(-0.09, -0.6).dx, p.at(0, -0.6).dy, p.at(-0.05, -0.78).dx, p.at(0, -0.78).dy)
        ..lineTo(p.at(0.05, -0.78).dx, p.at(0, -0.78).dy)
        ..quadraticBezierTo(p.at(0.09, -0.6).dx, p.at(0, -0.6).dy, p.at(0.1, -0.4).dx, p.at(0, -0.4).dy)
        ..close();
      canvas.drawPath(robe, pal.fill(marble));
      for (final x in [-0.04, 0.0, 0.04]) {
        canvas.drawLine(p.at(x, -0.75), p.at(x * 1.6, -0.42), pal.stroke(darker(marble, 0.12), 0.008 * h));
      }
      canvas.drawLine(p.at(0.04, -0.76), p.at(0.1, -0.95), pal.stroke(marble, 0.035 * h));
      canvas.drawLine(p.at(-0.04, -0.76), p.at(-0.08, -0.6), pal.stroke(marble, 0.035 * h));
      canvas.drawCircle(p.at(0, -0.84), 0.05 * h, pal.fill(marble));
      canvas.drawCircle(p.at(0.1, -1.0), 0.045 * h, pal.stroke(const Color(0xFF7C9A4E), 0.016 * h));
    case 'obelisk':
      p.shadow(0.35);
      const sand = Color(0xFFD8C39B);
      canvas.drawRect(
        Rect.fromLTRB(p.at(-0.14, 0).dx, p.at(0, -0.1).dy, p.at(0.14, 0).dx, base.dy),
        pal.fill(darker(sand, 0.08)),
      );
      canvas.drawPath(
        Path()..addPolygon([p.at(-0.075, -0.1), p.at(-0.05, -0.95), p.at(0.05, -0.95), p.at(0.075, -0.1)], true),
        pal.fill(sand),
      );
      canvas.drawPath(
        Path()..addPolygon([p.at(0.01, -0.1), p.at(0.005, -0.95), p.at(0.05, -0.95), p.at(0.075, -0.1)], true),
        pal.fill(darker(sand, 0.12)),
      );
      canvas.drawPath(
        Path()..addPolygon([p.at(-0.05, -0.95), p.at(0, -1.04), p.at(0.05, -0.95)], true),
        pal.fill(const Color(0xFFE2B84F)),
      );
      final mark = pal.stroke(darker(sand, 0.3), 0.008 * h);
      for (var i = 0; i < 6; i++) {
        final y = -0.25 - i * 0.11;
        canvas.drawLine(p.at(-0.02, y), p.at(0.0, y), mark);
        canvas.drawCircle(p.at(-0.01, y - 0.04), 0.008 * h, mark);
      }
  }
}
