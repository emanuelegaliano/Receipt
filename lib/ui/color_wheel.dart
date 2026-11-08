import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'l10n.dart';

/// Il cerchio dei colori: l'angolo è la tinta, la distanza dal centro quanto
/// è vivace (al centro grigio, sul bordo pieno). Si tocca o si trascina; la
/// luminosità (dal nero al chiaro) si sceglie a parte, col cursore sotto, e il
/// cerchio la mostra.
class ColorWheel extends StatelessWidget {
  final HSVColor color;
  final ValueChanged<HSVColor> onChanged;
  const ColorWheel({super.key, required this.color, required this.onChanged});

  /// Il colore nel punto [p] di un cerchio di lato [size], con luminosità [value].
  static HSVColor colorAt(Offset p, double size, double value) {
    final c = Offset(size / 2, size / 2), d = p - c;
    final hue = (math.atan2(d.dy, d.dx) * 180 / math.pi + 360) % 360;
    final saturation = (d.distance / (size / 2)).clamp(0.0, 1.0);
    return HSVColor.fromAHSV(1, hue, saturation, value);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final size = math.min(box.maxWidth, box.maxHeight);
        void pick(Offset p) => onChanged(colorAt(p, size, color.value));
        return Semantics(
          label: context.l10n.customColorTitle,
          child: GestureDetector(
            onPanDown: (d) => pick(d.localPosition),
            onPanUpdate: (d) => pick(d.localPosition),
            child: CustomPaint(
              size: Size.square(size),
              painter: _WheelPainter(color, Theme.of(context).colorScheme.onSurface),
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
    final v = selected.value;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = SweepGradient(
          colors: [for (var h = 0; h <= 360; h += 30) HSVColor.fromAHSV(1, h % 360, 1, v).toColor()],
        ).createShader(rect),
    );
    final grey = HSVColor.fromAHSV(1, 0, 0, v).toColor();
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
    canvas.drawCircle(p, 9, Paint()..color = selected.toColor());
  }

  @override
  bool shouldRepaint(_WheelPainter old) => old.selected != selected || old.ink != ink;
}

/// Il cerchio in una finestra, con il cursore della luminosità. Con
/// [themePreview] sotto si vedono i colori del tema che ne verrebbe, se no il
/// colore da solo (es. per una categoria). Restituisce il colore scelto, null
/// se si annulla.
Future<Color?> showColorWheel(BuildContext context, Color initial, {bool themePreview = true}) {
  return showDialog<Color>(
    context: context,
    builder: (ctx) => _ColorWheelDialog(initial: initial, themePreview: themePreview),
  );
}

class _ColorWheelDialog extends StatefulWidget {
  final Color initial;
  final bool themePreview;
  const _ColorWheelDialog({required this.initial, required this.themePreview});

  @override
  State<_ColorWheelDialog> createState() => _ColorWheelDialogState();
}

class _ColorWheelDialogState extends State<_ColorWheelDialog> {
  // Il cursore parte da 0,1: un colore quasi nero ci arriva.
  late HSVColor _color = () {
    final c = HSVColor.fromColor(widget.initial);
    return c.value < 0.1 ? c.withValue(0.1) : c;
  }();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final color = _color.toColor();
    Widget swatch(Color c, {double size = 36}) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    );
    final scheme = ColorScheme.fromSeed(seedColor: color, brightness: Theme.of(context).brightness);
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
              child: ColorWheel(color: _color, onChanged: (c) => setState(() => _color = c)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.brightness_6_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant),
                Expanded(
                  child: Slider(
                    value: _color.value,
                    min: 0.1,
                    semanticFormatterCallback: (v) => '${l.colorBrightness} ${(v * 100).round()}%',
                    onChanged: (v) => setState(() => _color = _color.withValue(v)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (widget.themePreview)
              // Come verrebbe il tema: i colori principali che Material ricava.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  swatch(scheme.primary),
                  swatch(scheme.primaryContainer),
                  swatch(scheme.secondaryContainer),
                  swatch(scheme.tertiary),
                ],
              )
            else
              swatch(color, size: 44),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(onPressed: () => Navigator.pop(context, color), child: Text(l.useColor)),
      ],
    );
  }
}
