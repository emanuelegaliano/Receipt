import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:receipt_app/data/backup.dart';
import 'package:receipt_app/data/database.dart';
import 'package:receipt_app/data/demo_data.dart';
import 'package:receipt_app/data/photos.dart';
import 'package:receipt_app/security/vault.dart';
import 'package:receipt_app/ui/scan_flow.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory tmp;
  setUp(() async => tmp = await Directory.systemTemp.createTemp('vault_test'));
  tearDown(() async => tmp.delete(recursive: true));

  Uint8List bytes(int n, int seed) => Uint8List.fromList(List.generate(n, (i) => (i * 31 + seed) % 256));

  test('chiave dei dati: si apre solo con la chiave giusta', () async {
    final key = DataKey.random();
    final wrapped = await wrapDataKey(key, List.filled(32, 1));
    expect((await unwrapDataKey(wrapped, List.filled(32, 1)))!.bytes, key.bytes);
    expect(await unwrapDataKey(wrapped, List.filled(32, 2)), isNull);
    expect(await unwrapDataKey('non base64!', List.filled(32, 1)), isNull);
    expect(key.databasePassphrase, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(DataKey.random().databasePassphrase, isNot(key.databasePassphrase));
  });

  test('foto: cifrate, leggibili solo con la chiave, quelle vecchie si convertono', () async {
    final key = DataKey.random();
    final photos = ReceiptPhotos(Future.value(key), baseDir: () async => tmp);
    final jpeg = bytes(50000, 3);
    final path = await photos.save(jpeg);
    final onDisk = File(path).readAsBytesSync();
    expect(onDisk.take(8), photoMagic);
    expect(String.fromCharCodes(onDisk), isNot(contains(String.fromCharCodes(jpeg.sublist(100, 200)))));
    expect(await photos.read(path), jpeg);
    expect(await ReceiptPhotos(Future.value(DataKey.random()), baseDir: () async => tmp).read(path), isNull,
        reason: 'altra chiave');

    // Una foto della 0.3.4 (in chiaro) e una scrittura interrotta.
    final old = File(p.join((await photos.directory()).path, 'scontrino_1.jpg'))..writeAsBytesSync(bytes(2000, 9));
    File('${old.path}.part').writeAsBytesSync([1, 2, 3]);
    expect(await photos.read(old.path), bytes(2000, 9), reason: 'in chiaro si legge lo stesso');
    expect(await photos.encryptLeftovers(), 1);
    expect(await PhotoCipher.isEncrypted(old), isTrue);
    expect(await photos.read(old.path), bytes(2000, 9));
    expect(File('${old.path}.part').existsSync(), isFalse);
    expect(await photos.encryptLeftovers(), 0, reason: 'già fatto');
    expect(await photos.read(p.join(tmp.path, 'non_esiste.jpg')), isNull);
  });

  test('database della 0.3.4: cifrato sul posto, i dati restano', () async {
    final file = File(p.join(tmp.path, 'spese.sqlite'));
    final old = AppDatabase(NativeDatabase(file));
    await loadDemoData(old, DateTime(2026, 10));
    await old.setSetting('receipt_lang', 'en');
    final count = (await old.select(old.expenses).get()).length;
    await old.close();
    expect(await isPlainDatabase(file), isTrue);

    final key = DataKey.random();
    expect(await encryptDatabaseInPlace(file, key.databasePassphrase), isTrue);
    expect(await isPlainDatabase(file), isFalse);
    expect(await encryptDatabaseInPlace(file, key.databasePassphrase), isFalse, reason: 'già cifrato');
    expect(String.fromCharCodes(file.readAsBytesSync()), isNot(contains('Esselunga')));

    // Senza chiave non si apre.
    final raw = sqlite3.open(file.path);
    expect(() => raw.select('SELECT count(*) FROM expenses'), throwsA(isA<SqliteException>()));
    raw.close();
    // Con la chiave sì, come la apre l'app.
    final db = AppDatabase(NativeDatabase(file, setup: (d) => d.execute(pragmaKey(key.databasePassphrase))));
    expect((await db.select(db.expenses).get()).length, count);
    expect(await db.setting('receipt_lang'), 'en');

    // L'esportazione resta in chiaro, foto comprese.
    final photoDir = await Directory(p.join(tmp.path, 'receipts')).create();
    final photo = p.join(photoDir.path, 'scontrino_7.jpg');
    await PhotoCipher(key).writeFile(photo, bytes(3000, 1));
    final first = (await db.select(db.expenses).get()).first;
    await db.saveExpense(ExpensesCompanion(id: Value(first.id), receiptPath: Value(photo)));
    final out = await Directory(p.join(tmp.path, 'out')).create();
    final zip = await exportBackupTo(db, out.path, key: key, now: DateTime(2026, 11, 7));
    final preview = await openBackup(zip, tmpDir: tmp.path, currentSchema: db.schemaVersion);
    expect(preview.expenses, count);
    final extracted = Directory(p.join(tmp.path)).listSync(recursive: true).whereType<File>();
    final plainDb = extracted.firstWhere((f) => p.basename(f.path) == 'receipt.sqlite');
    expect(await isPlainDatabase(plainDb), isTrue);
    final plainPhoto = extracted.firstWhere((f) => f.path.contains('import') && p.basename(f.path) == 'scontrino_7.jpg');
    expect(plainPhoto.readAsBytesSync(), bytes(3000, 1));

    // Ripristino su un telefono con un'altra chiave: foto cifrate con quella.
    final key2 = DataKey.random();
    final dst = AppDatabase(NativeDatabase.memory());
    final newPhotos = p.join(tmp.path, 'new', 'receipts');
    await restore(dst, preview, receiptsDir: newPhotos, key: key2);
    await preview.dispose();
    final restored = (await dst.expenseById(first.id))!.receiptPath!;
    expect(await PhotoCipher.isEncrypted(File(restored)), isTrue);
    expect(await PhotoCipher(key2).readFile(restored), bytes(3000, 1));
    await db.close();
    await dst.close();
  });

  test('database che la chiave nuova non apre: spostato da parte, non cancellato', () async {
    final file = File(p.join(tmp.path, 'spese.sqlite'));
    final db = sqlite3.open(file.path)..execute("PRAGMA key = 'vecchia'; CREATE TABLE t(x);");
    db.close();
    final key = DataKey.random();
    expect(await moveAsideIfUnreadable(file, key.databasePassphrase), isTrue);
    expect(file.existsSync(), isFalse);
    expect(tmp.listSync().map((e) => p.basename(e.path)), contains(startsWith('spese.sqlite.unreadable-')));
  });

  test('copie di image_picker nella cache: cancellate, il resto no', () async {
    Directory(p.join(tmp.path, '9f116085-318a-49c0-acb2-48c08977ebb7')).createSync();
    File(p.join(tmp.path, '9f116085-318a-49c0-acb2-48c08977ebb7', '30.jpg')).writeAsBytesSync([1]);
    File(p.join(tmp.path, 'scaled_30.jpg')).writeAsBytesSync([1]);
    File(p.join(tmp.path, 'image_picker_123.jpg')).writeAsBytesSync([1]);
    File(p.join(tmp.path, 'det.onnx')).writeAsBytesSync([1]);
    Directory(p.join(tmp.path, 'updates')).createSync();
    await deletePickerCopies(tmp, olderThan: const Duration(minutes: 10));
    expect(tmp.listSync().length, 5, reason: 'appena create: restano');
    await deletePickerCopies(tmp);
    expect(tmp.listSync().map((e) => p.basename(e.path)).toSet(), {'det.onnx', 'updates'});
  });

  test('zip esportati delle volte precedenti: via, anche la copia di share_plus', () async {
    File(p.join(tmp.path, 'receipt-backup-2026-11-07-1259.zip')).writeAsBytesSync([1]);
    Directory(p.join(tmp.path, 'share_plus')).createSync();
    File(p.join(tmp.path, 'share_plus', 'receipt-backup-2026-11-07-1259.zip')).writeAsBytesSync([1]);
    File(p.join(tmp.path, 'det.onnx')).writeAsBytesSync([1]);
    await deleteOldExports(tmp);
    expect(tmp.listSync(recursive: true).map((e) => p.relative(e.path, from: tmp.path)).toSet(), {'det.onnx', 'share_plus'});
  });
}
