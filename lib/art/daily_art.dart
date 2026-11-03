import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/database.dart';
import 'painting.dart';

/// Il quadro del giorno come sfondo (Impostazioni → Aspetto).
///
/// Spento finché l'utente non lo accende. Acceso, scarica una volta al giorno
/// l'immagine del dipinto di oggi da Wikimedia Commons (una miniatura di
/// circa 0,7 MB della foto Open Access del Met; nessun dato dell'utente nella
/// richiesta) e la tiene in support/art; quella del giorno
/// prima resta sullo sfondo finché la nuova non è arrivata, o se manca la
/// rete.
class DailyArt extends ChangeNotifier {
  static const catalogueAsset = 'assets/art/paintings.json';

  final AppDatabase db;
  final HttpClient Function() _http;
  final Future<Directory> Function() _baseDir;
  final Future<List<Painting>> Function() _catalogue;
  final DateTime Function() _now;

  DailyArt(
    this.db, {
    HttpClient Function()? http,
    Future<Directory> Function()? dir,
    Future<List<Painting>> Function()? catalogue,
    DateTime Function()? clock,
  }) : _http = http ?? HttpClient.new,
       _baseDir = dir ?? getApplicationSupportDirectory,
       _catalogue = catalogue ?? _loadCatalogue,
       _now = clock ?? DateTime.now;

  bool _enabled = false;
  bool get enabled => _enabled;

  /// Quanto si vede il quadro sotto il velo, da 0,05 a 0,5: lo slider in
  /// Impostazioni → Aspetto. Basso di proposito, i testi devono restare
  /// leggibili.
  static const minVisibility = 0.05, maxVisibility = 0.5, defaultVisibility = 0.2;
  double _visibility = defaultVisibility;
  double get visibility => _visibility;

  /// Il dipinto sullo sfondo e la sua immagine; null finché non ce n'è uno
  /// scaricato.
  Painting? get painting => _shown?.$1;
  File? get image => _shown?.$2;
  (Painting, File)? _shown;

  bool _downloading = false;
  bool get downloading => _downloading;

  /// L'ultimo download non è riuscito (si riprova al prossimo ritorno
  /// nell'app).
  bool _failed = false;
  bool get failed => _failed;

  List<Painting>? _paintings;
  Future<void>? _refreshing;
  AppLifecycleListener? _lifecycle;

  static Future<List<Painting>> _loadCatalogue() async =>
      parsePaintings(jsonDecode(await rootBundle.loadString(catalogueAsset)) as Map<String, dynamic>);

  Future<Directory> _dir() async => Directory(p.join((await _baseDir()).path, 'art'));

  /// All'avvio: legge l'impostazione, mostra subito l'immagine già scaricata
  /// e poi controlla se è cambiato il giorno. Anche a ogni ritorno nell'app,
  /// che può restare aperta in sottofondo per giorni.
  Future<void> init() async {
    _enabled = await db.setting('daily_art') == 'on';
    await _loadVisibility();
    _lifecycle ??= AppLifecycleListener(onResume: () => refresh());
    if (!_enabled) return;
    await _showCached();
    notifyListeners();
    unawaited(refresh());
  }

  Future<void> _loadVisibility() async {
    final percent = int.tryParse(await db.setting('daily_art_visibility') ?? '');
    _visibility = percent == null ? defaultVisibility : (percent / 100).clamp(minVisibility, maxVisibility);
  }

  /// Cambia la visibilità del quadro; con [save] false solo sullo schermo
  /// (mentre si trascina lo slider), senza scrivere nel database.
  Future<void> setVisibility(double v, {bool save = true}) async {
    _visibility = v.clamp(minVisibility, maxVisibility);
    notifyListeners();
    if (save) await db.setSetting('daily_art_visibility', '${(_visibility * 100).round()}');
  }

  /// Dopo il ripristino di un backup: impostazioni come nel backup. Un
  /// backup di prima della 0.3.2 non ha la scelta: il quadro resta spento
  /// senza salvare "off", così al prossimo avvio la domanda torna.
  Future<void> reload() async {
    await _loadVisibility();
    final saved = await db.setting('daily_art');
    await setEnabled(saved == 'on', save: saved != null);
  }

  Future<void> setEnabled(bool on, {bool save = true}) async {
    if (save) await db.setSetting('daily_art', on ? 'on' : 'off');
    _enabled = on;
    _failed = false;
    if (!on) {
      // Spento: niente immagini lasciate sul telefono.
      _shown = null;
      final dir = await _dir();
      if (await dir.exists()) await dir.delete(recursive: true);
    }
    notifyListeners();
    if (on) await refresh();
  }

  /// Scarica il dipinto di oggi se non c'è già. Le chiamate mentre un
  /// download è in corso aspettano quello.
  Future<void> refresh() {
    if (!_enabled) return Future.value();
    return _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  }

  Future<void> _refresh() async {
    final today = paintingOfDay(_paintings ??= await _catalogue(), _now());
    final dir = await _dir();
    final file = File(p.join(dir.path, '${today.id}.jpg'));
    if (!await file.exists()) {
      _downloading = true;
      _failed = false;
      notifyListeners();
      try {
        await dir.create(recursive: true);
        await _download(today.image, file);
      } catch (_) {
        _failed = true;
        return;
      } finally {
        _downloading = false;
        notifyListeners();
      }
    }
    if (!_enabled) return; // spento durante il download
    _shown = (today, file);
    notifyListeners();
    // Resta solo l'immagine di oggi; se la pulizia salta, riprova domani.
    try {
      await for (final f in dir.list()) {
        if (f.path != file.path) await f.delete();
      }
    } on FileSystemException {
      // niente
    }
  }

  Future<void> _download(Uri url, File file) async {
    final part = File('${file.path}.part');
    // Wikimedia chiede a chi scarica di presentarsi.
    final client = _http()
      ..connectionTimeout = const Duration(seconds: 10)
      ..userAgent = 'Receipt (https://github.com/emanuelegaliano/Receipt)';
    try {
      final res = await (await client.getUrl(url)).close();
      if (res.statusCode != HttpStatus.ok) throw HttpException('HTTP ${res.statusCode}', uri: url);
      final sink = part.openWrite();
      try {
        await sink.addStream(res.timeout(const Duration(seconds: 30)));
      } finally {
        await sink.close();
      }
      await part.rename(file.path);
    } finally {
      client.close(force: true);
      if (await part.exists()) await part.delete();
    }
  }

  /// L'immagine già scaricata (di oggi o, senza rete, di un giorno prima).
  Future<void> _showCached() async {
    final dir = await _dir();
    if (!await dir.exists()) return;
    final paintings = _paintings ??= await _catalogue();
    await for (final f in dir.list()) {
      final id = int.tryParse(p.basenameWithoutExtension(f.path));
      final match = paintings.where((x) => x.id == id);
      if (f is File && f.path.endsWith('.jpg') && match.isNotEmpty) {
        _shown = (match.first, f);
        return;
      }
    }
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }
}
