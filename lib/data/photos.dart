import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../security/vault.dart';

/// Le foto degli scontrini, cifrate nella cartella documenti/receipts.
///
/// Tutto aspetta la chiave dei dati, cioè lo sblocco dell'app.
class ReceiptPhotos {
  final Future<DataKey> _key;
  final Future<Directory> Function() _baseDir;
  ReceiptPhotos(this._key, {Future<Directory> Function()? baseDir})
      : _baseDir = baseDir ?? getApplicationDocumentsDirectory;

  Future<PhotoCipher>? _cipher;
  Future<PhotoCipher> get cipher => _cipher ??= _key.then(PhotoCipher.new);

  Future<Directory> directory() async => Directory(p.join((await _baseDir()).path, 'receipts'));

  /// Salva una nuova foto e ne restituisce il percorso (da mettere nella spesa).
  Future<String> save(Uint8List jpeg) async {
    final dir = await directory();
    await dir.create(recursive: true);
    final path = p.join(dir.path, 'scontrino_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await (await cipher).writeFile(path, jpeg);
    return path;
  }

  /// La foto in chiaro; null se non c'è o non si riesce a leggere.
  Future<Uint8List?> read(String path) async {
    try {
      return await (await cipher).readFile(path);
    } on FileSystemException {
      return null;
    }
  }

  /// Cifra le foto rimaste in chiaro (0.3.4 e prima). Si può interrompere:
  /// riprende al prossimo avvio.
  Future<int> encryptLeftovers() async => (await cipher).encryptFolder(await directory());
}
