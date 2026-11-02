import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:receipt_app/art/daily_art.dart';
import 'package:receipt_app/art/painting.dart';
import 'package:receipt_app/data/database.dart';

Map<String, dynamic> _json(int id, {String artist = 'Pittore'}) => {
  'id': id,
  'title': 'Quadro $id',
  'artist': artist,
  'artistBio': '',
  'date': '1880',
  'medium': 'Oil on canvas',
  'dimensions': '28 13/16 × 36 3/4 in. (73.2 × 93.4 cm)',
  'credit': 'Gift, 1900',
  'page': 'https://www.metmuseum.org/art/collection/search/$id',
  'image': 'https://upload.wikimedia.org/wikipedia/commons/thumb/x/xy/$id.jpg/1280px-$id.jpg',
  'imagePage': 'https://commons.wikimedia.org/wiki/File:$id.jpg',
  'imageLicense': 'CC0',
  'wikidata': 'http://www.wikidata.org/entity/Q$id',
  'texts': {
    'it': {'title': 'Il quadro $id', 'summary': 'dipinto di $artist'},
    'en': {
      'summary': 'painting by $artist',
      'wikipedia': {'title': 'Painting $id', 'url': 'https://en.wikipedia.org/wiki/Painting_$id', 'extract': 'About'},
    },
  },
};

void main() {
  // Serve per AppLifecycleListener; il binding dei test però finge tutte le
  // connessioni HTTP, anche quelle al server locale qui sotto.
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  group('quadro del giorno', () {
    final paintings = [for (var i = 1; i <= 3; i++) Painting.fromJson(_json(i))];

    test('lo stesso per tutto il giorno, un altro il giorno dopo, poi da capo', () {
      final morning = paintingOfDay(paintings, DateTime(2026, 11, 2, 0, 1));
      expect(paintingOfDay(paintings, DateTime(2026, 11, 2, 23, 59)).id, morning.id);
      final ids = [for (var d = 0; d < 6; d++) paintingOfDay(paintings, DateTime(2026, 11, 2 + d)).id];
      expect(ids.sublist(0, 3).toSet(), hasLength(3));
      expect(ids.sublist(3), ids.sublist(0, 3));
      // Il giorno del cambio d'ora non salta né ripete un quadro.
      expect(
        paintingOfDay(paintings, DateTime(2026, 10, 25)).id,
        isNot(paintingOfDay(paintings, DateTime(2026, 10, 26)).id),
      );
    });

    test('titolo, testi e misure nella lingua dell\'app', () {
      final q = paintings.first;
      expect(q.titleIn('it'), 'Il quadro 1');
      expect(q.titleIn('en'), 'Quadro 1');
      expect(q.summaryIn('it'), 'dipinto di Pittore');
      expect(q.dimensionsIn('it'), '73,2 × 93,4 cm');
      expect(q.dimensionsIn('en'), '28 13/16 × 36 3/4 in. (73.2 × 93.4 cm)');
      // Senza voce in italiano si mostra quella inglese, con la sua lingua.
      expect(q.wikipediaIn('it')?.extract, 'About');
      expect(q.wikipediaIn('it')?.lang, 'en');
    });
  });

  test('l\'elenco in assets/art è valido', () {
    final file = File(DailyArt.catalogueAsset);
    final paintings = parsePaintings(jsonDecode(file.readAsStringSync()) as Map<String, dynamic>);
    expect(paintings.length, 600);
    expect(paintings.map((x) => x.id).toSet(), hasLength(paintings.length));
    for (final x in paintings) {
      expect(x.image.scheme, 'https', reason: '${x.id}');
      expect(x.image.host, endsWith('.wikimedia.org'), reason: '${x.id}');
      expect(x.page.host, 'www.metmuseum.org', reason: '${x.id}');
      expect(['CC0', 'Public domain'], contains(x.imageLicense), reason: '${x.id}');
      for (final w in [x.texts['it']?.wikipedia, x.texts['en']?.wikipedia].nonNulls) {
        expect(w.extract, isNotEmpty, reason: '${x.id}');
        expect(w.url.host, endsWith('.wikipedia.org'), reason: '${x.id}');
      }
    }
    for (var i = 1; i < paintings.length; i++) {
      expect(
        paintings[i].artist,
        isNot(paintings[i - 1].artist),
        reason: 'due quadri di fila di ${paintings[i].artist}',
      );
    }
  });

  group('DailyArt', () {
    late AppDatabase db;
    late HttpServer server;
    late Directory tmp;
    late DateTime now;
    late List<Painting> paintings;
    var fail = false;
    var hits = 0;

    DailyArt art() => DailyArt(db, dir: () async => tmp, catalogue: () async => paintings, clock: () => now);
    List<String> files() => Directory(p.join(tmp.path, 'art')).existsSync()
        ? [for (final f in Directory(p.join(tmp.path, 'art')).listSync()) p.basename(f.path)]
        : [];

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      tmp = await Directory.systemTemp.createTemp('daily_art_test');
      now = DateTime(2026, 11, 2, 9);
      fail = false;
      hits = 0;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) {
        hits++;
        if (fail) {
          req.response.statusCode = 503;
        } else {
          req.response.add(utf8.encode('jpeg ${req.uri.path}'));
        }
        req.response.close();
      });
      paintings = [
        for (var i = 1; i <= 3; i++)
          Painting.fromJson({..._json(i), 'image': 'http://127.0.0.1:${server.port}/$i.jpg'}),
      ];
    });

    tearDown(() async {
      await server.close(force: true);
      await tmp.delete(recursive: true);
      await db.close();
    });

    test('spento non scarica niente', () async {
      final a = art();
      await a.init();
      await a.refresh();
      expect(a.enabled, isFalse);
      expect(a.painting, isNull);
      expect(hits, 0);
    });

    test('acceso scarica il quadro di oggi una volta sola', () async {
      final a = art();
      await a.init();
      await a.setEnabled(true);
      final today = paintingOfDay(paintings, now);
      expect(a.painting?.id, today.id);
      expect(a.image?.readAsStringSync(), 'jpeg /${today.id}.jpg');
      await a.refresh();
      expect(hits, 1);
      expect(await db.setting('daily_art'), 'on');

      // Riaprendo l'app il quadro c'è subito, senza rete.
      fail = true;
      final again = art();
      await again.init();
      expect(again.painting?.id, today.id);
      await again.refresh();
      expect(hits, 1);
    });

    test('il giorno dopo cambia; senza rete resta quello di ieri', () async {
      final a = art();
      await a.init();
      await a.setEnabled(true);
      final yesterday = a.painting!.id;

      now = now.add(const Duration(days: 1));
      fail = true;
      await a.refresh();
      expect(a.failed, isTrue);
      expect(a.painting?.id, yesterday);

      fail = false;
      await a.refresh();
      expect(a.failed, isFalse);
      expect(a.painting?.id, isNot(yesterday));
      expect(files(), ['${a.painting!.id}.jpg']);
    });

    test('visibilità: 20% di base, salvata al rilascio, entro i limiti', () async {
      final a = art();
      await a.init();
      expect(a.visibility, DailyArt.defaultVisibility);
      await a.setVisibility(0.35, save: false);
      expect(a.visibility, 0.35);
      expect(await db.setting('daily_art_visibility'), isNull);
      await a.setVisibility(0.9);
      expect(a.visibility, DailyArt.maxVisibility);
      expect(await db.setting('daily_art_visibility'), '50');

      final again = art();
      await again.init();
      expect(again.visibility, 0.5);
    });

    test('spegnendolo toglie le immagini', () async {
      final a = art();
      await a.init();
      await a.setEnabled(true);
      expect(files(), hasLength(1));
      await a.setEnabled(false);
      expect(a.painting, isNull);
      expect(files(), isEmpty);
      expect(await db.setting('daily_art'), 'off');
    });
  });
}
