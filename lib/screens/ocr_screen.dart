import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../app_services.dart';
import '../ocr/rapid_ocr.dart';
import '../ui/l10n.dart';

/// Prototipo: scatta o scegli uno scontrino e mostra cosa legge RapidOCR.
class OcrScreen extends StatefulWidget {
  const OcrScreen({super.key});

  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen> {
  final _picker = ImagePicker();
  late final Future<RapidOcr> _engine = RapidOcr.load();

  Uint8List? _image;
  OcrResult? _result;
  String? _error;
  bool _busy = false;
  bool _showBoxes = true;

  Future<void> _pick(ImageSource source) async {
    final file = await AppServices.of(context).lock.whileAway(() => _picker.pickImage(source: source));
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _image = bytes;
      _result = null;
      _error = null;
      _busy = true;
    });
    try {
      final engine = await _engine;
      final result = await engine.recognize(bytes);
      if (mounted) setState(() => _result = result);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.ocrTitle),
        actions: [
          if (_result != null)
            IconButton(
              tooltip: l.copyText,
              icon: const Icon(Icons.copy_all_outlined),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _result!.text));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.textCopied)));
              },
            ),
        ],
      ),
      body: _image == null ? _empty(scheme) : _content(scheme),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(l.takePhoto),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _busy ? null : () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(l.gallery),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty(ColorScheme scheme) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.receipt_long_outlined, size: 72, color: scheme.primary),
              const SizedBox(height: 16),
              Text(context.l10n.addScanTitle, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                context.l10n.ocrIntro,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );

  Widget _content(ColorScheme scheme) {
    final result = _result;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ColoredBox(
            color: scheme.surfaceContainerHighest,
            child: SizedBox(
              height: 420,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (result != null && _showBoxes)
                    FittedBox(
                      child: SizedBox(
                        width: result.imageWidth.toDouble(),
                        height: result.imageHeight.toDouble(),
                        child: Stack(children: [
                          Positioned.fill(child: Image.memory(_image!, fit: BoxFit.fill)),
                          Positioned.fill(child: CustomPaint(painter: _BoxPainter(result, scheme.primary))),
                        ]),
                      ),
                    )
                  else
                    Image.memory(_image!, fit: BoxFit.contain),
                  if (_busy)
                    Positioned.fill(
                      child: ColoredBox(
                        color: scheme.surface.withValues(alpha: 0.6),
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_error != null)
          Card(
            color: scheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, style: TextStyle(color: scheme.onErrorContainer)),
            ),
          ),
        if (result != null) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                avatar: const Icon(Icons.timer_outlined, size: 18),
                label: Text('${result.timingsMs.values.fold(0, (a, b) => a + b)} ms'),
              ),
              Chip(
                avatar: const Icon(Icons.notes, size: 18),
                label: Text(context.l10n.ocrLines(result.lines.length)),
              ),
              FilterChip(
                label: Text(context.l10n.ocrBoxes),
                selected: _showBoxes,
                onSelected: (v) => setState(() => _showBoxes = v),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            result.timingsMs.entries.map((e) => '${e.key} ${e.value} ms').join(' · '),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Card.outlined(
            child: Column(
              children: [
                for (final line in result.lines)
                  ListTile(
                    dense: true,
                    title: Text(line.text, style: const TextStyle(fontFamily: 'monospace')),
                    trailing: Text(
                      '${(line.score * 100).toStringAsFixed(0)}%',
                      style: TextStyle(color: line.score < 0.8 ? scheme.error : scheme.onSurfaceVariant),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _BoxPainter extends CustomPainter {
  final OcrResult result;
  final Color color;
  _BoxPainter(this.result, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width / 300;
    final fill = Paint()..color = color.withValues(alpha: 0.12);
    for (final line in result.lines) {
      final path = Path()..moveTo(line.box[0].x, line.box[0].y);
      for (final p in line.box.skip(1)) {
        path.lineTo(p.x, p.y);
      }
      path.close();
      canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
    }
  }

  @override
  bool shouldRepaint(_BoxPainter old) => old.result != result;
}
