import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_services.dart';
import '../ui/format.dart';
import '../ui/l10n.dart';
import '../update/update_ui.dart';
import 'painting.dart';

/// Il quadro del giorno dietro [child], coperto da un velo del colore di
/// sfondo (opaco quanto basta per leggere i testi sopra, vedi
/// [DailyArt.visibility]); sotto, Scaffold e AppBar diventano trasparenti. Senza quadro
/// [child] resta com'è. L'albero è lo stesso nei due casi, così accendendo
/// o spegnendo lo sfondo le schermate non perdono il loro stato.
class ArtBackground extends StatelessWidget {
  final Widget child;
  const ArtBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final art = AppServices.of(context).art;
    return ListenableBuilder(
      listenable: art,
      builder: (context, _) {
        final file = art.enabled ? art.image : null;
        final theme = Theme.of(context);
        return Stack(
          fit: StackFit.expand,
          children: [
            if (file != null) ...[
              ColoredBox(color: theme.colorScheme.surface),
              Image(
                image: _screenImage(context, file),
                fit: BoxFit.cover,
                gaplessPlayback: true,
                // Immagine rovinata: resta lo sfondo normale.
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
              ColoredBox(color: theme.colorScheme.surface.withValues(alpha: 1 - art.visibility)),
            ],
            Theme(
              data: file == null
                  ? theme
                  : theme.copyWith(
                      scaffoldBackgroundColor: Colors.transparent,
                      appBarTheme: theme.appBarTheme.copyWith(
                        backgroundColor: Colors.transparent,
                        scrolledUnderElevation: 0,
                      ),
                    ),
              child: child,
            ),
          ],
        );
      },
    );
  }
}

/// [file] decodificata all'altezza dello schermo (al massimo a 2x): basta per
/// uno sfondo velato e tiene bassa la memoria, gli originali del Met arrivano
/// a 4000 px.
ImageProvider _screenImage(BuildContext context, File file, {double scale = 1}) {
  final size = MediaQuery.sizeOf(context);
  final dpr = math.min(MediaQuery.devicePixelRatioOf(context), 2.0);
  return ResizeImage(FileImage(file), height: (size.height * dpr * scale).round());
}

/// Anteprima dello sfondo per lo slider delle impostazioni, che hanno un
/// fondo pieno: il quadro col velo e un testo sopra.
class PaintingPreview extends StatelessWidget {
  final File file;
  final double visibility;
  const PaintingPreview({super.key, required this.file, required this.visibility});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 56,
        height: 100,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: theme.colorScheme.surface),
            Image(image: ResizeImage(FileImage(file), height: 300), fit: BoxFit.cover),
            ColoredBox(color: theme.colorScheme.surface.withValues(alpha: 1 - visibility)),
            Center(child: Text('Aa', style: theme.textTheme.titleMedium)),
          ],
        ),
      ),
    );
  }
}

/// La "i" nella barra in alto: apre la scheda del quadro di oggi. Non c'è se
/// lo sfondo è spento o il quadro non è ancora arrivato.
class PaintingInfoButton extends StatelessWidget {
  const PaintingInfoButton({super.key});

  @override
  Widget build(BuildContext context) {
    final art = AppServices.of(context).art;
    return ListenableBuilder(
      listenable: art,
      builder: (context, _) {
        final painting = art.painting, file = art.image;
        if (!art.enabled || painting == null || file == null) return const SizedBox.shrink();
        return IconButton(
          tooltip: context.l10n.paintingOfTheDay,
          icon: const Icon(Icons.info_outline),
          onPressed: () => showPaintingInfo(context, painting, file),
        );
      },
    );
  }
}

const _links = MethodChannel('receipt/links');

/// La prima volta (anche dopo l'aggiornamento dalla 0.3.1) chiede se
/// attivare il quadro del giorno: senza risposta resta spento. Chi ha detto
/// di no a internet per gli aggiornamenti viene avvisato che il quadro lo usa.
Future<void> askDailyArtOnStart(BuildContext context) async {
  final services = AppServices.of(context);
  if (await services.db.setting('daily_art') != null) return;
  await untilUnlocked(services.lock);
  final internet = await updateCheckEnabled(services.db);
  if (!context.mounted) return;
  final l = context.l10n;
  final yes = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.palette_outlined),
      title: Text(l.dailyArt),
      content: Text(
        internet ? l.dailyArtConsentMessage : '${l.dailyArtConsentMessage}\n\n${l.dailyArtConsentInternet}',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.updateConsentNo)),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.dailyArtConsentYes)),
      ],
    ),
  );
  await services.art.setEnabled(yes ?? false);
}

Future<void> showPaintingInfo(BuildContext context, Painting painting, File file) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 1,
      builder: (context, controller) => _PaintingSheet(painting: painting, file: file, controller: controller),
    ),
  );
}

class _PaintingSheet extends StatelessWidget {
  final Painting painting;
  final File file;
  final ScrollController controller;
  const _PaintingSheet({required this.painting, required this.file, required this.controller});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final lang = Localizations.localeOf(context).languageCode;
    final muted = text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    final wiki = painting.wikipediaIn(lang);
    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      children: [
        // Il quadro intero, senza i tagli dello sfondo: toccandolo si ingrandisce.
        Center(
          child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _PaintingViewer(painting: painting, file: file),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.45),
                child: Image(image: _screenImage(context, file, scale: 0.5), fit: BoxFit.contain),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(l.paintingOfTheDay, style: text.labelLarge?.copyWith(color: scheme.primary)),
        const SizedBox(height: 4),
        Text(painting.titleIn(lang), style: text.headlineSmall),
        const SizedBox(height: 8),
        Text(painting.artist, style: text.titleMedium),
        if (painting.artistBio.isNotEmpty) Text(painting.artistBio, style: muted),
        if (wiki != null) ...[
          const SizedBox(height: 16),
          Text(wiki.extract, style: text.bodyLarge?.copyWith(height: 1.45)),
          const SizedBox(height: 4),
          Text(l.paintingFromWikipedia(wiki.title), style: muted),
        ] else if (painting.summaryIn(lang) != null) ...[
          const SizedBox(height: 12),
          Text(capitalized(painting.summaryIn(lang)!), style: text.bodyLarge),
          Text(l.paintingFromWikidata, style: muted),
        ],
        const SizedBox(height: 16),
        _Fact(l.paintingDate, painting.date),
        _Fact(l.paintingMedium, painting.medium),
        _Fact(l.paintingDimensions, painting.dimensionsIn(lang)),
        const Divider(height: 32),
        Text(l.paintingCredit(painting.credit), style: muted),
        const SizedBox(height: 8),
        Text(l.paintingSources(painting.imageLicense), style: muted),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _LinkButton(label: l.paintingOpenMet, url: painting.page),
            if (wiki != null) _LinkButton(label: l.paintingOpenWikipedia, url: wiki.url),
            _LinkButton(label: l.paintingOpenCommons, url: painting.imagePage),
          ],
        ),
      ],
    );
  }
}

/// Apre [url] nel browser; senza browser mostra l'indirizzo.
class _LinkButton extends StatelessWidget {
  final String label;
  final Uri url;
  const _LinkButton({required this.label, required this.url});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.open_in_new, size: 18),
      label: Text(label),
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        try {
          await AppServices.of(context).lock.whileAway(() => _links.invokeMethod<void>('open', {'url': '$url'}));
        } on PlatformException {
          messenger.showSnackBar(SnackBar(content: Text('$url')));
        }
      },
    );
  }
}

class _Fact extends StatelessWidget {
  final String label;
  final String value;
  const _Fact(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: text.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          Expanded(child: Text(value, style: text.bodyMedium)),
        ],
      ),
    );
  }
}

/// Il quadro a schermo intero, da ingrandire con due dita.
class _PaintingViewer extends StatelessWidget {
  final Painting painting;
  final File file;
  const _PaintingViewer({required this.painting, required this.file});

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(painting.titleIn(lang), maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: InteractiveViewer(
        maxScale: 6,
        child: Center(
          child: Image(image: _screenImage(context, file, scale: 2), fit: BoxFit.contain),
        ),
      ),
    );
  }
}
