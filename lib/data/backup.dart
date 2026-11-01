import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'database.dart';

/// Esporta tutto in un file .zip:
///   receipt.sqlite   copia coerente del database (VACUUM INTO)
///   receipts/…       le foto degli scontrini
///   manifest.json    versione e conteggi, per un futuro ripristino
///
/// Il file non è cifrato: chi lo apre vede spese e foto.
Future<File> exportBackup(AppDatabase db, {DateTime? now}) async {
  now ??= DateTime.now();
  final tmp = await Directory((await getTemporaryDirectory()).path).createTemp('export');
  final sqlite = File(p.join(tmp.path, 'receipt.sqlite'));
  await db.customStatement('VACUUM INTO ?', [sqlite.path]);

  final photos = [
    for (final path in await db.receiptPaths())
      if (await File(path).exists()) File(path),
  ];
  final expenses = await db.select(db.expenses).get();
  final manifest = File(p.join(tmp.path, 'manifest.json'))
    ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
      'app': 'Receipt',
      'format': 1,
      'schemaVersion': db.schemaVersion,
      'createdAt': now.toIso8601String(),
      'expenses': expenses.length,
      'photos': photos.length,
    }));

  final out = p.join((await getTemporaryDirectory()).path,
      'receipt-backup-${DateFormat('yyyy-MM-dd-HHmm').format(now)}.zip');
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
