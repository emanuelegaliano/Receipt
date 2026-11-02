import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:receipt_app/update/release.dart';
import 'package:receipt_app/update/updater.dart';

void main() {
  group('versioni', () {
    test('confronto numerico, non alfabetico', () {
      expect(compareVersions('0.10.0', '0.9.9'), greaterThan(0));
      expect(compareVersions('1.0.0', '1.0.0+7'), 0);
      expect(compareVersions('v0.2.0', '0.1.0'), greaterThan(0));
      expect(compareVersions('0.1.0', '0.1.1'), lessThan(0));
      expect(compareVersions('rotta', '0.0.1'), lessThan(0));
    });

    test('version.json valido e non valido', () {
      final sha = 'a' * 64;
      final ok = AppRelease.fromJson({
        'version': '0.2.0',
        'apk': {'url': 'https://example.com/receipt.apk', 'size': 10, 'sha256': 'sha256:${sha.toUpperCase()}'},
      });
      expect(ok.sha256, sha);
      expect(ok.apkSize, 10);
      for (final bad in [
        {'version': '0.2.0'},
        {'apk': {'url': 'https://x/a.apk', 'size': 1, 'sha256': sha}},
        {'version': '0.2.0', 'apk': {'url': 'http://x/a.apk', 'size': 1, 'sha256': sha}},
        {'version': '0.2.0', 'apk': {'url': 'https://x/a.apk', 'size': 1, 'sha256': 'abc'}},
      ]) {
        expect(() => AppRelease.fromJson(bad), throwsFormatException, reason: '$bad');
      }
    });
  });

  group('Updater', () {
    late HttpServer server;
    late Directory tmp;
    late List<int> apk;
    late Map<String, dynamic> manifest;
    var apkHits = 0;

    Updater updater({String current = '0.1.0'}) => Updater(
          manifestUrl: Uri.parse('http://127.0.0.1:${server.port}/version.json'),
          cacheDir: () async => tmp,
          currentVersion: () async => current,
        );

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('update_test');
      apk = List.generate(300000, (i) => i * 7 % 256);
      apkHits = 0;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      manifest = {
        'version': '0.2.0',
        // Il manifest vero punta a https; qui il controllo dello schema si
        // aggira costruendo la release a mano nei test di download.
        'apk': {'url': 'https://example.com/receipt.apk', 'size': apk.length, 'sha256': '${sha256.convert(apk)}'},
      };
      server.listen((req) {
        if (req.uri.path == '/version.json') {
          req.response.write(jsonEncode(manifest));
        } else if (req.uri.path == '/receipt.apk') {
          apkHits++;
          req.response.add(apk);
        } else {
          req.response.statusCode = 404;
        }
        req.response.close();
      });
    });

    tearDown(() async {
      await server.close(force: true);
      await tmp.delete(recursive: true);
    });

    AppRelease local({String? sha}) => AppRelease(
          version: '0.2.0',
          apkUrl: Uri.parse('http://127.0.0.1:${server.port}/receipt.apk'),
          apkSize: apk.length,
          sha256: sha ?? '${sha256.convert(apk)}',
        );

    test('propone solo versioni più nuove', () async {
      expect((await updater().check())?.version, '0.2.0');
      expect(await updater(current: '0.2.0').check(), isNull);
      expect(await updater(current: '0.3.0').check(), isNull);
    });

    test('sito irraggiungibile o manifest rotto: errore di rete', () async {
      manifest = {'version': 'boh'};
      await expectLater(updater().check(), throwsA(isA<UpdateException>()));
      final closed = updater();
      await server.close(force: true);
      await expectLater(closed.check(), throwsA(isA<UpdateException>()));
    });

    test('scarica, verifica e riusa il file già scaricato', () async {
      final progress = <int>[];
      final file = await updater().download(local(), onProgress: (r, _) => progress.add(r));
      expect(await file.readAsBytes(), apk);
      expect(progress.last, apk.length);
      expect(p.basename(file.path), 'receipt-0.2.0.apk');
      await updater().download(local());
      expect(apkHits, 1);
    });

    test('hash sbagliato: file scartato', () async {
      await expectLater(
        updater().download(local(sha: 'b' * 64)),
        throwsA(isA<UpdateException>().having((e) => e.error, 'error', UpdateError.corrupted)),
      );
      expect(tmp.listSync(recursive: true).whereType<File>(), isEmpty);
    });

    test('annullato a metà: niente file parziali', () async {
      await expectLater(
        updater().download(local(), cancelled: () => true),
        throwsA(isA<UpdateException>().having((e) => e.error, 'error', UpdateError.cancelled)),
      );
      expect(tmp.listSync(recursive: true).whereType<File>(), isEmpty);
    });

    test('pulizia: via gli APK già installati, resta quello nuovo', () async {
      final dir = Directory(p.join(tmp.path, 'updates'))..createSync();
      for (final n in ['receipt-0.1.0.apk', 'receipt-0.2.0.apk', 'receipt-0.3.0.apk', 'receipt-0.3.0.apk.part']) {
        File(p.join(dir.path, n)).writeAsStringSync('x');
      }
      await updater().cleanup('0.2.0');
      expect(dir.listSync().map((f) => p.basename(f.path)), ['receipt-0.3.0.apk']);
    });
  });
}
