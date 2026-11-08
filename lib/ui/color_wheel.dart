import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'l10n.dart';

/// Luminosità fissa dei colori del cerchio: il tema prende da lì solo tinta e
/// vivacità, i chiari e gli scuri li calcola Material da sé.
const _value = 0.85;

/// Il cerchio dei colori: l'angolo è la tinta, la distanza dal centro quanto
/// è vivace (al centro grigio, sul bordo pieno). Si tocca o si trascina.
class ColorWheel extends StatefulWidget {
  final Color initial;
  final ValueChanged<Color> onChanged;
  const ColorWheel({super.key, required this.initial, required this.onChanged});

  /// Il colore nel punto [p] di un cerchio di lato [size].
  static Color colorAt(Offset p, double size) {
    final c = Offset(size / 2, size / 2), d = p - c;
    final hue = (math.atan2(d.dy, d.dx) * 180 / math.pi + 360) % 360;
    final saturation = (d.distance / (size / 2)).clamp(0.0, 1.0);
    return HSVColor.fromAHSV(1, hue, saturation, _value).toColor();
  }

  @override
  State<ColorWheel> createState() => _ColorWheelState();
}

class _ColorWheelState extends State<ColorWheel> {
  late HSVColor _color = HSVColor.fromColor(widget.initial);

  void _pick(Offset p, double size) {
    final color = ColorWheel.colorAt(p, size);
    setState(() => _color = HSVColor.fromColor(color));
    widget.onChanged(color);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final size = math.min(box.maxWidth, box.maxHeight);
        return Semantics(
          label: context.l10n.customColorTitle,
          child: GestureDetector(
            onPanDown: (d) => _pick(d.localPosition, size),
            onPanUpdate: (d) => _pick(d.localPosition, size),
            child: CustomPaint(
              size: Size.square(size),
              painter: _WheelPainter(_color, Theme.of(context).colorScheme.onSurface),
            ),
          ),
        );
      },
    );
  }
}

class _WheelPainter extends CustomPainter {
  final HSVColor selected;
  final Color ink;
  _WheelPainter(this.selected, this.ink);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero), r = size.width / 2;
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = SweepGradient(
          colors: [for (var h = 0; h <= 360; h += 30) HSVColor.fromAHSV(1, h % 360, 1, _value).toColor()],
        ).createShader(rect),
    );
    final grey = HSVColor.fromAHSV(1, 0, 0, _value).toColor();
    canvas.drawCircle(
      c,
      r,
      Paint()..shader = RadialGradient(colors: [grey, grey.withValues(alpha: 0)]).createShader(rect),
    );
    // Il punto scelto: un anello col colore dentro.
    final a = selected.hue * math.pi / 180;
    final p = c + Offset(math.cos(a), math.sin(a)) * selected.saturation * r;
    canvas.drawCircle(p, 13, Paint()..color = Colors.white);
    canvas.drawCircle(
      p,
      13,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(p, 9, Paint()..color = selected.withValue(_value).toColor());
  }

  @override
  bool shouldRepaint(_WheelPainter old) => old.selected != selected || old.ink != ink;
}

/// Il cerchio in una finestra, con l'anteprima dei colori del tema che ne
/// verrebbe. Restituisce il colore scelto, null se si annulla.
Future<Color?> showColorWheel(BuildContext context, Color initial) {
  return showDialog<Color>(
    context: context,
    builder: (ctx) => _ColorWheelDialog(initial: initial),
  );
}

class _ColorWheelDialog extends StatefulWidget {
  final Color initial;
  const _ColorWheelDialog({required this.initial});

  @override
  State<_ColorWheelDialog> createState() => _ColorWheelDialogState();
}

class _ColorWheelDialogState extends State<_ColorWheelDialog> {
  late Color _color = widget.initial;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = ColorScheme.fromSeed(seedColor: _color, brightness: Theme.of(context).brightness);
    Widget swatch(Color c) => Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    );
    return AlertDialog(
      title: Text(l.customColorTitle),
      content: SizedBox(
        width: 260,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 240,
              height: 240,
              child: ColorWheel(initial: widget.initial, onChanged: (c) => setState(() => _color = c)),
            ),
            const SizedBox(height: 20),
            // Come verrebbe il tema: i colori principali che Material ricava.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                swatch(scheme.primary),
                swatch(scheme.primaryContainer),
                swatch(scheme.secondaryContainer),
                swatch(scheme.tertiary),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(onPressed: () => Navigator.pop(context, _color), child: Text(l.useColor)),
      ],
    );
  }
}
