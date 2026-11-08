import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../security/vault.dart';
import 'database.dart';

/// Versione del formato dello zip (manifest.json → "format").
const backupFormat = 1;

/// Esporta tutto in un file .zip:
///   receipt.sqlite   copia coerente del database (VACUUM INTO)
///   receipts/…       le foto degli scontrini
///   manifest.json    versione e conteggi, per il ripristino
///
/// Il file non è cifrato (nel telefono i dati lo sono, vedi vault.dart):
/// chi lo apre vede spese e foto. Per questo l'app chiede la password prima
/// di esportare.
Future<File> exportBackup(AppDatabase db, DataKey key, {DateTime? now}) async =>
    exportBackupTo(db, (await getTemporaryDirectory()).path, key: key, now: now);

/// [key] è la chiave con cui sono cifrati database e foto; null se non lo
/// sono (nei test).
Future<File> exportBackupTo(AppDatabase db, String outDir, {DataKey? key, DateTime? now}) async {
  now ??= DateTime.now();
  final tmp = await Directory(outDir).createTemp('export');
  final sqlite = File(p.join(tmp.path, 'receipt.sqlite'));
  // La copia è cifrata come l'originale: nello zip va in chiaro.
  await db.customStatement('VACUUM INTO ?', [sqlite.path]);
  if (key != null && !await isPlainDatabase(sqlite)) await decryptDatabaseCopy(sqlite, key.databasePassphrase);

  final cipher = key == null ? null : PhotoCipher(key);
  final photosDir = await Directory(p.join(tmp.path, 'receipts')).create();
  final photos = <File>[];
  for (final path in await db.receiptPaths()) {
    final source = File(path);
    if (!await source.exists()) continue;
    final out = File(p.join(photosDir.path, p.basename(path)));
    if (cipher == null) {
      await source.copy(out.path);
    } else {
      final plain = await cipher.decrypt(await source.readAsBytes());
      if (plain == null) continue; // cifrata con un'altra chiave: illeggibile
      await out.writeAsBytes(plain);
    }
    photos.add(out);
  }
  final expenses = await db.select(db.expenses).get();
  final manifest = File(p.join(tmp.path, 'manifest.json'))
    ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
      'app': 'Receipt',
      'format': backupFormat,
      'schemaVersion': db.schemaVersion,
      'createdAt': now.toIso8601String(),
      'expenses': expenses.length,
      'photos': photos.length,
    }));

  final out = p.join(outDir, 'receipt-backup-${DateFormat('yyyy-MM-dd-HHmm').format(now)}.zip');
  final zip = ZipFileEncoder()..create(out);
  await zip.addFile(manifest, 'manifest.json');
  await zip.addFile(sqlite, 'receipt.sqlite');
  for (final f in photos) {
    // Le foto sono già JPEG: comprimerle di nuovo farebbe solo perdere tempo.
    await zip.addFile(f, 'receipts/${p.basename(f.path)}', ZipFileEncoder.store);
  }
  await zip.close();
  await tmp.delete(recursive: true);
  return File(out);
}

/// Cancella gli zip esportati le volte precedenti (sono in chiaro), anche la
/// copia che share_plus fa in cache/share_plus. Non subito dopo la
/// condivisione: l'app che li riceve può leggerli più tardi (es. un allegato
/// della mail).
Future<void> deleteOldExports(Directory cache) async {
  for (final dir in [cache, Directory(p.join(cache.path, 'share_plus'))]) {
    if (!await dir.exists()) continue;
    await for (final f in dir.list()) {
      final name = p.basename(f.path);
      if (f is File && name.startsWith('receipt-backup-') && name.endsWith('.zip')) await f.delete();
    }
  }
}

/// Perché un file non si può ripristinare. Il testo per l'utente è nella UI.
enum BackupError { notZip, notReceiptBackup, damaged, newerVersion }

class BackupException implements Exception {
  final BackupError error;

  /// Per [BackupError.notReceiptBackup]: i file del backup che mancano e cosa
  /// c'è invece nello zip (primo livello), da mostrare all'utente.
  final List<String> missing;
  final List<String> found;
  const BackupException(this.error, {this.missing = const [], this.found = const []});
  @override
  String toString() => 'BackupException: ${error.name}${missing.isEmpty ? '' : ' (manca $missing, c\'è $found)'}';
}

/// File dei sistemi operativi che finiscono negli zip rifatti a mano
/// (__MACOSX/, ._nome e .DS_Store del Mac): non contano.
bool _isJunk(String name) =>
    name.startsWith('__MACOSX/') || p.posix.basename(name).startsWith('._') || p.posix.basename(name) == '.DS_Store';

/// La cartella dello zip che contiene il backup: "" se manifest.json è in
/// cima, come lo crea [exportBackup], altrimenti quella più vicina alla cima.
/// Capita quando lo zip viene estratto e la cartella ricompressa (es. dopo
/// WhatsApp o Telegram). null se manifest.json non c'è.
String? _backupRoot(Iterable<String> names) {
  String? best;
  for (final n in names) {
    if (p.posix.basename(n) != 'manifest.json') continue;
    final prefix = n.substring(0, n.length - 'manifest.json'.length);
    if (best == null || '/'.allMatches(prefix).length < '/'.allMatches(best).length) best = prefix;
  }
  return best;
}

/// Un backup estratto e controllato, pronto per [restore].
class BackupPreview {
  final Directory _dir;
  final DateTime? createdAt;
  final int expenses, photos;
  BackupPreview._(this._dir, this.createdAt, this.expenses, this.photos);

  /// Cancella i file estratti (va chiamato anche se non si ripristina).
  Future<void> dispose() async {
    if (await _dir.exists()) await _dir.delete(recursive: true);
  }
}

/// Estrae lo zip in una cartella temporanea e controlla che sia un backup di
/// Receipt utilizzabile da questa versione dell'app.
Future<BackupPreview> openBackup(File zip, {required String tmpDir, required int currentSchema}) async {
  final dir = await Directory(tmpDir).createTemp('import');
  try {
    final input = InputFileStream(zip.path);
    final Archive archive;
    try {
      archive = ZipDecoder().decodeStream(input);
    } catch (_) {
      throw const BackupException(BackupError.notZip);
    }
    // Un file qualsiasi non fa fallire il decoder: risulta solo vuoto.
    if (archive.isEmpty) throw const BackupException(BackupError.notZip);
    // Alcuni zip fatti su Windows separano le cartelle con "\".
    String name(ArchiveFile e) => e.name.replaceAll(r'\', '/');
    final names = [for (final e in archive) if (e.isFile && !_isJunk(name(e))) name(e)];
    final root = _backupRoot(names) ?? '';
    final missing = [
      for (final n in ['manifest.json', 'receipt.sqlite'])
        if (!names.contains('$root$n')) '$root$n',
    ];
    if (missing.isNotEmpty) {
      await input.close();
      final found = {for (final n in names) n.contains('/') ? '${n.split('/').first}/' : n}.toList()..sort();
      throw BackupException(BackupError.notReceiptBackup, missing: missing, found: found.take(8).toList());
    }
    for (final entry in archive) {
      final full = name(entry);
      if (!entry.isFile || _isJunk(full) || !full.startsWith(root)) continue;
      // Solo i nomi attesi, e mai percorsi che escono dalla cartella.
      final rel = full.substring(root.length);
      final String target;
      if (rel == 'manifest.json' || rel == 'receipt.sqlite') {
        target = p.join(dir.path, rel);
      } else if (rel.startsWith('receipts/') && p.posix.basename(rel) == rel.substring(9)) {
        await Directory(p.join(dir.path, 'receipts')).create();
        target = p.join(dir.path, 'receipts', p.posix.basename(rel));
      } else {
        continue;
      }
      final out = OutputFileStream(target);
      entry.writeContent(out);
      await out.close();
    }
    await input.close();

    final manifestFile = File(p.join(dir.path, 'manifest.json'));
    if (!await manifestFile.exists() || !await File(p.join(dir.path, 'receipt.sqlite')).exists()) {
      throw const BackupException(BackupError.notReceiptBackup);
    }
    final Map<String, dynamic> m;
    try {
      m = jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      throw const BackupException(BackupError.damaged);
    }
    if (m['app'] != 'Receipt') throw const BackupException(BackupError.notReceiptBackup);
    if ((m['format'] as num? ?? 0) > backupFormat || (m['schemaVersion'] as num? ?? 0) > currentSchema) {
      throw const BackupException(BackupError.newerVersion);
    }
    return BackupPreview._(
      dir,
      DateTime.tryParse('${m['createdAt']}'),
      (m['expenses'] as num?)?.toInt() ?? 0,
      (m['photos'] as num?)?.toInt() ?? 0,
    );
  } catch (_) {
    await dir.delete(recursive: true);
    rethrow;
  }
}

/// Sostituisce tutti i dati di [db] con quelli del backup e copia le foto in
/// [receiptsDir], cifrandole con [key] (null nei test: copiate così come
/// sono). Un backup di una versione precedente viene prima aggiornato con le
/// stesse migrazioni dell'avvio.
Future<void> restore(AppDatabase db, BackupPreview backup, {required String receiptsDir, DataKey? key}) async {
  final source = AppDatabase(NativeDatabase(File(p.join(backup._dir.path, 'receipt.sqlite'))));
  try {
    final accounts = await source.select(source.accounts).get();
    final categories = await source.select(source.categories).get();
    final expenses = await source.select(source.expenses).get();
    final rules = await source.select(source.merchantRules).get();
    final settings = await source.select(source.settings).get();
    final plantings = await source.select(source.plantings).get();
    final snapshots = await source.select(source.limitSnapshots).get();

    // Prima le foto: se qualcosa va storto qui, il database è ancora intatto.
    await Directory(receiptsDir).create(recursive: true);
    final photosDir = Directory(p.join(backup._dir.path, 'receipts'));
    final restored = <String>{};
    final cipher = key == null ? null : PhotoCipher(key);
    if (await photosDir.exists()) {
      await for (final f in photosDir.list()) {
        if (f is File) {
          final target = p.join(receiptsDir, p.basename(f.path));
          if (cipher == null) {
            await f.copy(target);
          } else {
            await cipher.writeFile(target, await f.readAsBytes());
          }
          restored.add(p.basename(f.path));
        }
      }
    }
    // I percorsi nel database sono quelli del telefono di origine.
    String? relocate(String? path) {
      if (path == null) return null;
      final name = p.basename(path);
      return restored.contains(name) ? p.join(receiptsDir, name) : null;
    }

    await db.transaction(() async {
      await db.delete(db.expenses).go();
      await db.delete(db.merchantRules).go();
      await db.delete(db.categories).go();
      await db.delete(db.accounts).go();
      await db.delete(db.settings).go();
      await db.delete(db.plantings).go();
      await db.delete(db.limitSnapshots).go();
      await db.batch((b) {
        b.insertAll(db.accounts, accounts);
        b.insertAll(db.categories, categories);
        b.insertAll(db.expenses, [for (final e in expenses) e.copyWith(receiptPath: Value(relocate(e.receiptPath)))]);
        b.insertAll(db.merchantRules, rules);
        b.insertAll(db.settings, settings);
        b.insertAll(db.plantings, plantings);
        b.insertAll(db.limitSnapshots, snapshots);
      });
    });
  } finally {
    await source.close();
  }
}
