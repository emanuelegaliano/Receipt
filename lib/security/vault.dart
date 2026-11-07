import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hash;
import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

/// La chiave dei dati: 32 byte casuali creati alla prima configurazione (o al
/// primo sblocco dopo l'aggiornamento alla 0.3.5).
///
/// Non è la password: la password (e l'impronta) servono solo ad aprire la
/// copia cifrata di questa chiave, salvata nel Keystore (vedi AppLock). Così
/// cambiare password vuol dire cifrare di nuovo 32 byte, non tutti i dati.
///
/// Dalla chiave si ricavano due sottochiavi indipendenti, una per il
/// database (SQLite3MultipleCiphers, `PRAGMA key`) e una per le foto
/// (AES-256-GCM, vedi [PhotoCipher]).
class DataKey {
  final Uint8List bytes;
  DataKey(List<int> bytes) : bytes = Uint8List.fromList(bytes) {
    if (bytes.length != 32) throw ArgumentError('La chiave dei dati deve essere di 32 byte');
  }

  factory DataKey.random() {
    final rnd = Random.secure();
    return DataKey(List.generate(32, (_) => rnd.nextInt(256)));
  }

  List<int> _derive(String label) => hash.Hmac(hash.sha256, bytes).convert(utf8.encode(label)).bytes;

  /// La passphrase del database, in esadecimale (64 caratteri).
  String get databasePassphrase => _hex(_derive('receipt/database'));

  /// La chiave delle foto.
  SecretKey get photoKey => SecretKey(_derive('receipt/photos'));
}

String _hex(List<int> b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

final _aes = AesGcm.with256bits();

/// AES-256-GCM: nonce (12 byte) + testo cifrato + tag (16 byte).
Future<Uint8List> _seal(List<int> plain, SecretKey key) async {
  final box = await _aes.encrypt(plain, secretKey: key);
  return Uint8List.fromList(box.concatenation());
}

/// null se la chiave è sbagliata o i dati sono stati alterati.
Future<Uint8List?> _open(List<int> sealed, SecretKey key) async {
  try {
    final box = SecretBox.fromConcatenation(sealed, nonceLength: _aes.nonceLength, macLength: _aes.macAlgorithm.macLength);
    return Uint8List.fromList(await _aes.decrypt(box, secretKey: key));
  } on SecretBoxAuthenticationError {
    return null;
  } on ArgumentError {
    return null;
  }
}

/// Cifra la chiave dei dati con una chiave ricavata dalla password.
Future<String> wrapDataKey(DataKey key, List<int> wrappingKey) async =>
    base64.encode(await _seal(key.bytes, SecretKey(wrappingKey)));

/// null se [wrappingKey] non è quella giusta (cioè la password è sbagliata).
Future<DataKey?> unwrapDataKey(String wrapped, List<int> wrappingKey) async {
  final List<int> sealed;
  try {
    sealed = base64.decode(wrapped);
  } on FormatException {
    return null;
  }
  final plain = await _open(sealed, SecretKey(wrappingKey));
  return plain == null || plain.length != 32 ? null : DataKey(plain);
}

// --- Foto ------------------------------------------------------------------

/// Le foto cifrate cominciano con questi 8 byte; quelle senza sono ancora in
/// chiaro (salvate prima della 0.3.5, o arrivate da un backup).
final photoMagic = ascii.encode('RCPTENC1');

bool _startsWithMagic(List<int> head) {
  if (head.length < photoMagic.length) return false;
  for (var i = 0; i < photoMagic.length; i++) {
    if (head[i] != photoMagic[i]) return false;
  }
  return true;
}

/// Cifra e decifra le foto degli scontrini.
///
/// Il nome del file non cambia: una foto si riconosce come cifrata da
/// [photoMagic]. Così la cifratura delle foto vecchie si può interrompere e
/// riprendere quando si vuole, e i percorsi nel database restano validi.
class PhotoCipher {
  final SecretKey _key;
  PhotoCipher(DataKey key) : _key = key.photoKey;

  Future<Uint8List> encrypt(List<int> plain) async =>
      Uint8List.fromList([...photoMagic, ...await _seal(plain, _key)]);

  /// I byte dell'immagine; una foto ancora in chiaro torna così com'è.
  /// null se la foto è cifrata con un'altra chiave o è rovinata.
  Future<Uint8List?> decrypt(Uint8List data) async =>
      _startsWithMagic(data) ? _open(Uint8List.sublistView(data, photoMagic.length), _key) : data;

  static Future<bool> isEncrypted(File f) async {
    final raf = await f.open();
    try {
      return _startsWithMagic(await raf.read(photoMagic.length));
    } finally {
      await raf.close();
    }
  }

  /// Scrive [plain] cifrata in [path]: prima in un file a parte, poi lo
  /// rinomina, così un'interruzione non lascia mai una foto a metà.
  Future<void> writeFile(String path, List<int> plain) async {
    final part = File('$path.part');
    await part.writeAsBytes(await encrypt(plain), flush: true);
    await part.rename(path);
  }

  /// I byte in chiaro della foto in [path]; null se non c'è o non si legge.
  Future<Uint8List?> readFile(String path) async {
    final f = File(path);
    if (!await f.exists()) return null;
    return decrypt(await f.readAsBytes());
  }

  /// Cifra le foto di [dir] ancora in chiaro. Restituisce quante.
  Future<int> encryptFolder(Directory dir) async {
    if (!await dir.exists()) return 0;
    var n = 0;
    await for (final f in dir.list()) {
      if (f is! File) continue;
      if (f.path.endsWith('.part')) {
        // Rimasto da una scrittura interrotta: l'originale c'è ancora.
        await f.delete();
        continue;
      }
      if (await isEncrypted(f)) continue;
      await writeFile(f.path, await f.readAsBytes());
      n++;
    }
    return n;
  }
}

// --- Database --------------------------------------------------------------

/// Il comando che apre il database cifrato. La passphrase è esadecimale, quindi
/// non contiene apici.
String pragmaKey(String passphrase) => "PRAGMA key = '$passphrase';";

const _sqliteHeader = 'SQLite format 3\u0000';

/// true se [file] è un database SQLite in chiaro (com'era prima della 0.3.5).
Future<bool> isPlainDatabase(File file) async {
  if (!await file.exists() || await file.length() < 16) return false;
  final raf = await file.open();
  try {
    return ascii.decode(await raf.read(16), allowInvalid: true) == _sqliteHeader;
  } finally {
    await raf.close();
  }
}

/// Cifra sul posto un database ancora in chiaro (PRAGMA rekey di
/// SQLite3MultipleCiphers, dentro una transazione: se si interrompe resta
/// quello di prima). Non fa niente se è già cifrato o non c'è.
Future<bool> encryptDatabaseInPlace(File file, String passphrase, {String? tempDirectory}) async {
  if (!await isPlainDatabase(file)) return false;
  final path = file.path;
  await Isolate.run(() {
    if (tempDirectory != null) sqlite3.tempDirectory = tempDirectory;
    final db = sqlite3.open(path);
    try {
      // rekey non funziona in modalità WAL; Receipt non la usa, ma meglio
      // esserne sicuri.
      db.execute('PRAGMA journal_mode = DELETE;');
      db.execute("PRAGMA rekey = '$passphrase';");
    } finally {
      db.close();
    }
  });
  return true;
}

/// Toglie la cifratura da una copia del database (per l'esportazione, che
/// resta leggibile anche fuori dall'app).
Future<void> decryptDatabaseCopy(File file, String passphrase) async {
  final path = file.path;
  await Isolate.run(() {
    final db = sqlite3.open(path);
    try {
      db.execute(pragmaKey(passphrase));
      db.execute("PRAGMA rekey = '';");
    } finally {
      db.close();
    }
  });
}

/// Se il database c'è ma questa chiave non lo apre (es. dati rimasti da
/// un'installazione precedente di cui non c'è più la chiave), lo sposta da
/// parte invece di cancellarlo. true se l'ha spostato.
Future<bool> moveAsideIfUnreadable(File file, String passphrase) async {
  if (!await file.exists() || await isPlainDatabase(file)) return false;
  final path = file.path;
  final readable = await Isolate.run(() {
    final db = sqlite3.open(path);
    try {
      db.execute(pragmaKey(passphrase));
      db.select('SELECT count(*) FROM sqlite_master');
      return true;
    } on SqliteException {
      return false;
    } finally {
      db.close();
    }
  });
  if (readable) return false;
  await file.rename(p.join(file.parent.path, '${p.basename(path)}.unreadable-${DateTime.now().millisecondsSinceEpoch}'));
  return true;
}
