import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'release.dart';

enum UpdateError { network, corrupted, cancelled }

class UpdateException implements Exception {
  final UpdateError error;
  const UpdateException(this.error);
  @override
  String toString() => 'UpdateException($error)';
}

/// Controllo, download e installazione degli aggiornamenti.
///
/// La versione pubblicata sta in version.json sul sito; l'APK si scarica in
/// cache/updates, si verifica con lo SHA-256 del manifest e si passa
/// all'installer di Android (MainActivity.kt), che chiede conferma
/// all'utente: un'app installata fuori dal Play Store non può aggiornarsi da
/// sola in silenzio.
class Updater {
  /// Con --dart-define=UPDATE_MANIFEST=... si prova il flusso con un
  /// version.json locale (vedi integration_test).
  static final defaultManifest = Uri.parse(const String.fromEnvironment('UPDATE_MANIFEST',
      defaultValue: 'https://emanuelegaliano.github.io/Receipt/version.json'));
  static const _channel = MethodChannel('receipt/update');

  final Uri manifestUrl;
  final HttpClient Function() _http;
  final Future<Directory> Function() _cacheDir;
  final Future<String> Function() _currentVersion;

  Updater({
    Uri? manifestUrl,
    HttpClient Function()? http,
    Future<Directory> Function()? cacheDir,
    Future<String> Function()? currentVersion,
  })  : manifestUrl = manifestUrl ?? defaultManifest,
        _http = http ?? HttpClient.new,
        _cacheDir = cacheDir ?? getTemporaryDirectory,
        _currentVersion = currentVersion ?? (() async => await _channel.invokeMethod<String>('version') ?? '');

  Future<String> currentVersion() => _currentVersion();

  /// La release pubblicata se è più nuova di quella installata, null se
  /// l'app è aggiornata. [UpdateException] se il sito non risponde.
  Future<AppRelease?> check({Duration timeout = const Duration(seconds: 5)}) async {
    final client = _http()..connectionTimeout = timeout;
    try {
      final res = await (await client.getUrl(manifestUrl)).close().timeout(timeout);
      if (res.statusCode != HttpStatus.ok) throw const UpdateException(UpdateError.network);
      final body = await res.transform(utf8.decoder).join().timeout(timeout);
      final release = AppRelease.fromJson(jsonDecode(body) as Map<String, dynamic>);
      return compareVersions(release.version, await _currentVersion()) > 0 ? release : null;
    } on UpdateException {
      rethrow;
    } catch (_) {
      // Rete assente, timeout, JSON rotto: per l'utente è sempre "non ci riesco".
      throw const UpdateException(UpdateError.network);
    } finally {
      client.close(force: true);
    }
  }

  Future<Directory> _updatesDir() async => Directory(p.join((await _cacheDir()).path, 'updates'));

  /// Scarica l'APK di [release] e ne verifica lo SHA-256. Se è già stato
  /// scaricato (es. installazione annullata) riusa il file.
  Future<File> download(
    AppRelease release, {
    void Function(int received, int total)? onProgress,
    bool Function()? cancelled,
  }) async {
    final dir = await _updatesDir();
    await dir.create(recursive: true);
    final file = File(p.join(dir.path, 'receipt-${release.version}.apk'));
    if (await file.exists() && await _sha256Of(file) == release.sha256) return file;

    final part = File('${file.path}.part');
    final client = _http();
    try {
      final res = await (await client.getUrl(release.apkUrl)).close();
      if (res.statusCode != HttpStatus.ok) throw const UpdateException(UpdateError.network);
      final total = res.contentLength > 0 ? res.contentLength : release.apkSize;
      final digest = _DigestSink();
      final hasher = sha256.startChunkedConversion(digest);
      final sink = part.openWrite();
      var received = 0;
      try {
        await for (final chunk in res) {
          if (cancelled?.call() ?? false) throw const UpdateException(UpdateError.cancelled);
          sink.add(chunk);
          hasher.add(chunk);
          received += chunk.length;
          onProgress?.call(received, total);
        }
      } finally {
        await sink.close();
      }
      hasher.close();
      if ('${digest.value}' != release.sha256) throw const UpdateException(UpdateError.corrupted);
      return await part.rename(file.path);
    } on UpdateException {
      rethrow;
    } catch (_) {
      throw const UpdateException(UpdateError.network);
    } finally {
      client.close(force: true);
      if (await part.exists()) await part.delete();
    }
  }

  /// Toglie gli APK già installati (versione <= [current]) e i download a metà.
  Future<void> cleanup(String current) async {
    final dir = await _updatesDir();
    if (!await dir.exists()) return;
    await for (final f in dir.list()) {
      final m = RegExp(r'^receipt-(.+)\.apk$').firstMatch(p.basename(f.path));
      if (m == null || compareVersions(m[1]!, current) <= 0) await f.delete();
    }
  }

  /// Android 8+: l'utente deve permettere a Receipt di installare app.
  Future<bool> canInstall() async => await _channel.invokeMethod<bool>('canInstall') ?? false;

  /// Apre "Installa app sconosciute" e restituisce il permesso al ritorno.
  Future<bool> openInstallSettings() async => await _channel.invokeMethod<bool>('openInstallSettings') ?? false;

  /// Apre l'installer di Android; l'utente conferma con "Aggiorna".
  Future<void> install(File apk) => _channel.invokeMethod('install', {'path': apk.path});

  static Future<String> _sha256Of(File f) async => '${await sha256.bind(f.openRead()).first}';
}

class _DigestSink implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}
