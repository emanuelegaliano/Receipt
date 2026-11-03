import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:receipt_app/data/backup.dart';
import 'package:receipt_app/data/database.dart';
import 'package:receipt_app/data/demo_data.dart';

void main() {
  late Directory tmp;
  setUp(() async => tmp = await Directory.systemTemp.createTemp('backup_test'));
  tearDown(() async => tmp.delete(recursive: true));

  Future<List<Object>> snapshot(AppDatabase db) async => [
        (await db.select(db.accounts).get()).map((a) => '${a.id} ${a.name} ${a.kind}').toList(),
        (await db.select(db.categories).get())
            .map((c) => '${c.id} ${c.name} ${c.color} ${c.monthlyLimitCents} ${c.keywords.length}')
            .toList(),
        (await db.select(db.expenses).get())
            .map((e) => '${e.id} ${e.amountCents} ${e.date} ${e.merchant} ${e.categoryId} ${e.accountId}')
            .toList(),
        (await db.loadMerchantRules()).toString(),
        await db.setting('receipt_lang') ?? '',
      ];

  test('esporta e ripristina su un telefono "nuovo": dati e foto uguali', () async {
    // Telefono di partenza: dati di prova, una regola, un'impostazione e una foto.
    final oldPhotos = await Directory(p.join(tmp.path, 'old', 'receipts')).create(recursive: true);
    final photo = File(p.join(oldPhotos.path, 'scontrino_1.jpg'))..writeAsBytesSync(List.filled(1000, 7));
    final src = AppDatabase(NativeDatabase.memory());
    await loadDemoData(src, DateTime(2026, 10));
    await src.learnMerchant('ESSELUNGA', (await src.allCategories()).first.id);
    await src.setSetting('receipt_lang', 'en');
    final withPhoto = (await src.select(src.expenses).get()).first;
    await src.saveExpense(ExpensesCompanion(id: Value(withPhoto.id), receiptPath: Value(photo.path)));
    final zip = await exportBackupTo(src, tmp.path, now: DateTime(2026, 11, 1, 12));

    // Telefono nuovo: database appena creato, con una spesa che verrà sostituita.
    final dst = AppDatabase(NativeDatabase.memory());
    final cat = (await dst.allCategories()).first;
    final acc = (await dst.watchAccounts().first).first;
    await dst.saveExpense(
        ExpensesCompanion.insert(amountCents: 999, date: DateTime(2026, 11, 1), categoryId: cat.id, accountId: acc.id));

    final preview = await openBackup(zip, tmpDir: tmp.path, currentSchema: dst.schemaVersion);
    expect((preview.expenses, preview.photos, preview.createdAt), (30, 1, DateTime(2026, 11, 1, 12)));
    final newReceipts = p.join(tmp.path, 'new', 'receipts');
    await restore(dst, preview, receiptsDir: newReceipts);
    await preview.dispose();

    expect(await snapshot(dst), await snapshot(src));
    final restoredPath = (await dst.expenseById(withPhoto.id))!.receiptPath!;
    expect(restoredPath, p.join(newReceipts, 'scontrino_1.jpg'));
    expect(File(restoredPath).readAsBytesSync(), photo.readAsBytesSync());
    await src.close();
    await dst.close();
  });

  test('rifiuta file che non sono backup o sono di una versione più nuova', () async {
    final db = AppDatabase(NativeDatabase.memory());
    Future<BackupError?> error(File f, {int schema = 2}) async {
      try {
        await openBackup(f, tmpDir: tmp.path, currentSchema: schema);
        return null;
      } on BackupException catch (e) {
        return e.error;
      }
    }

    final notZip = File(p.join(tmp.path, 'foto.zip'))..writeAsStringSync('non sono uno zip');
    expect(await error(notZip), BackupError.notZip);

    final otherZip = p.join(tmp.path, 'altro.zip');
    final enc = ZipFileEncoder()..create(otherZip);
    await enc.addFile(notZip, 'documento.txt');
    await enc.close();
    expect(await error(File(otherZip)), BackupError.notReceiptBackup);

    final zip = await exportBackupTo(db, tmp.path);
    expect(await error(zip, schema: 1), BackupError.newerVersion);
    // Nessuna cartella temporanea lasciata indietro dai tentativi falliti.
    expect(tmp.listSync().whereType<Directory>().where((d) => p.basename(d.path).startsWith('import')), isEmpty);
    await db.close();
  });

  /// Lo stesso backup rimpacchettato: [rename] cambia il nome di ogni file,
  /// [extra] aggiunge file con quel nome.
  Future<File> repack(File backup, String name, String Function(String) rename, {List<String> extra = const []}) async {
    final out = p.join(tmp.path, name);
    final archive = ZipDecoder().decodeBytes(backup.readAsBytesSync());
    final enc = ZipFileEncoder()..create(out);
    for (final e in archive) {
      if (e.isFile) enc.addArchiveFile(ArchiveFile.bytes(rename(e.name), e.readBytes()!));
    }
    for (final x in extra) {
      enc.addArchiveFile(ArchiveFile.bytes(x, [1, 2, 3]));
    }
    await enc.close();
    return File(out);
  }

  test('accetta il backup dentro una cartella (zip estratto e ricompresso), anche dal Mac o da Windows', () async {
    final db = AppDatabase(NativeDatabase.memory());
    await loadDemoData(db, DateTime(2026, 10));
    final zip = await exportBackupTo(db, tmp.path);
    for (final f in [
      await repack(zip, 'cartella.zip', (n) => 'DOC-20261101-WA0193/$n'),
      await repack(zip, 'mac.zip', (n) => n,
          extra: ['__MACOSX/._manifest.json', '__MACOSX/receipts/._a.jpg', '.DS_Store']),
      await repack(zip, 'windows.zip', (n) => 'backup\\${n.replaceAll('/', '\\')}'),
    ]) {
      final preview = await openBackup(f, tmpDir: tmp.path, currentSchema: db.schemaVersion);
      expect(preview.expenses, 30, reason: p.basename(f.path));
      await preview.dispose();
    }
    await db.close();
  });

  test('se non è un backup dice cosa manca e cosa c\'è', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final zip = await exportBackupTo(db, tmp.path);
    final noDb = await repack(zip, 'senza_db.zip', (n) => n == 'receipt.sqlite' ? 'altro/receipt.sqlite' : 'backup/$n');
    try {
      await openBackup(noDb, tmpDir: tmp.path, currentSchema: db.schemaVersion);
      fail('accettato');
    } on BackupException catch (e) {
      expect(e.error, BackupError.notReceiptBackup);
      expect(e.missing, ['backup/receipt.sqlite']);
      expect(e.found, ['altro/', 'backup/']);
    }
    await db.close();
  });
}
