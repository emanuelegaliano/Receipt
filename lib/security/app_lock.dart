import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'vault.dart';

/// PBKDF2-HMAC-SHA256 con un solo blocco di uscita (32 byte).
Uint8List pbkdf2(String password, List<int> salt, int iterations) {
  final hmac = Hmac(sha256, utf8.encode(password));
  var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
  final out = Uint8List.fromList(u);
  for (var i = 1; i < iterations; i++) {
    u = hmac.convert(u).bytes;
    for (var j = 0; j < out.length; j++) {
      out[j] ^= u[j];
    }
  }
  return out;
}

/// Confronto a tempo costante, per non rivelare quanti byte coincidono.
bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

/// Dove salvare i segreti: il Keystore di Android tramite flutter_secure_storage.
/// Astratto per poterlo sostituire nei test.
abstract class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureSecretStore implements SecretStore {
  final _storage = const FlutterSecureStorage();
  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

enum BiometricResult { ok, cancelled, invalidated, failed }

/// Una chiave del Keystore di Android che si può usare solo dopo
/// l'impronta (BiometricPrompt con CryptoObject, vedi MainActivity.kt): con
/// quella si cifra la chiave dei dati per lo sblocco con l'impronta.
/// Astratta per poterla sostituire nei test.
abstract class BiometricKeystore {
  /// C'è un'impronta (biometria "forte") registrata sul telefono?
  Future<bool> available();

  /// Crea una nuova chiave, chiede l'impronta e cifra [secret].
  Future<(BiometricResult, String?)> seal(Uint8List secret, {required String reason, required String cancel});

  /// Chiede l'impronta e decifra ciò che ha prodotto [seal].
  Future<(BiometricResult, Uint8List?)> unseal(String sealed, {required String reason, required String cancel});

  /// Cancella la chiave.
  Future<void> forget();
}

class AndroidBiometricKeystore implements BiometricKeystore {
  static const _channel = MethodChannel('receipt/biometric');

  static BiometricResult _error(PlatformException e) =>
      e.code == 'invalidated' ? BiometricResult.invalidated : BiometricResult.failed;

  @override
  Future<bool> available() async {
    try {
      return await _channel.invokeMethod<bool>('available') ?? false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<(BiometricResult, String?)> seal(Uint8List secret, {required String reason, required String cancel}) async {
    try {
      final out = await _channel.invokeMethod<Uint8List>('seal', {'data': secret, 'reason': reason, 'cancel': cancel});
      return out == null ? (BiometricResult.cancelled, null) : (BiometricResult.ok, base64.encode(out));
    } on PlatformException catch (e) {
      return (_error(e), null);
    }
  }

  @override
  Future<(BiometricResult, Uint8List?)> unseal(String sealed, {required String reason, required String cancel}) async {
    try {
      final out = await _channel
          .invokeMethod<Uint8List>('unseal', {'data': base64.decode(sealed), 'reason': reason, 'cancel': cancel});
      return out == null ? (BiometricResult.cancelled, null) : (BiometricResult.ok, out);
    } on PlatformException catch (e) {
      return (_error(e), null);
    } on FormatException {
      return (BiometricResult.invalidated, null);
    }
  }

  @override
  Future<void> forget() async {
    try {
      await _channel.invokeMethod('forget');
    } on PlatformException {
      // Se non si riesce a cancellarla resta una chiave inutile: la prossima
      // attivazione la sostituisce.
    }
  }
}

enum AppLockState {
  loading,
  needsSetup,
  locked,

  /// Password giusta, ma l'impronta era attiva e va confermata (dopo
  /// l'aggiornamento alla 0.3.5, o se sul telefono è cambiata l'impronta).
  confirmBiometric,
  unlocked,
}

/// Blocco dell'app e chiave dei dati: password scelta al primo avvio,
/// impronta facoltativa.
///
/// I dati (database e foto) sono cifrati con una chiave casuale, [DataKey].
/// Nel Keystore ce ne sono due copie cifrate:
///   vault_key  con una chiave ricavata dalla password (PBKDF2, sale casuale);
///   vault_bio  con una chiave del Keystore che si apre solo con l'impronta.
/// La password non è salvata da nessuna parte: è giusta se apre vault_key.
///
/// Fino alla 0.3.4 c'era solo l'hash della password (lock_hash) e i dati
/// erano in chiaro: al primo sblocco con la password si crea la chiave e i
/// dati vengono cifrati (vedi main.dart).
///
/// L'app si blocca all'avvio e quando torna in primo piano dopo
/// [relockAfter] in sottofondo, tranne mentre è aperta un'attività esterna
/// voluta (fotocamera, galleria, condivisione): vedi [whileAway].
class AppLock extends ChangeNotifier with WidgetsBindingObserver {
  static const iterations = 120000;
  static const relockAfter = Duration(seconds: 30);

  final SecretStore _store;
  final BiometricKeystore _biometricStore;
  final DateTime Function() _now;
  AppLock({SecretStore? store, BiometricKeystore? biometric, DateTime Function()? clock})
      : _store = store ?? SecureSecretStore(),
        _biometricStore = biometric ?? AndroidBiometricKeystore(),
        _now = clock ?? DateTime.now;

  AppLockState _state = AppLockState.loading;
  AppLockState get state => _state;

  DataKey? _key;
  final _keyReady = Completer<DataKey>();

  /// La chiave dei dati, appena l'utente ha sbloccato l'app (o scelto la
  /// password al primo avvio). Chi legge i dati prima aspetta.
  Future<DataKey> get dataKey => _keyReady.future;

  bool _newKey = false;

  /// La chiave è stata creata adesso, alla prima configurazione: non può
  /// esserci niente di cifrato con un'altra chiave che valga la pena tenere.
  bool get keyIsNew => _newKey;

  /// L'utente vuole l'impronta (lock_biometric)...
  bool _biometric = false;

  /// ...e la chiave dei dati è davvero apribile con l'impronta (vault_bio).
  bool _biometricSealed = false;
  bool get biometricEnabled => _biometric && _biometricSealed;

  bool _biometricChanged = false;

  /// Le impronte del telefono sono cambiate: la chiave del Keystore non vale
  /// più e bisogna entrare con la password.
  bool get biometricChanged => _biometricChanged;

  bool _upgrading = false;

  /// Prima volta dopo l'aggiornamento dalla 0.3.4: serve la password (non
  /// basta l'impronta) per creare la chiave e cifrare i dati.
  bool get needsPasswordOnce => _upgrading;

  int _failures = 0;
  DateTime? _retryAt;
  DateTime? _pausedAt;
  int _away = 0;
  bool _authenticating = false;

  /// Dopo troppi errori bisogna aspettare prima di riprovare.
  Duration get waitBeforeRetry {
    final at = _retryAt;
    if (at == null) return Duration.zero;
    final left = at.difference(_now());
    return left.isNegative ? Duration.zero : left;
  }

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    final vault = await _store.read('vault_key');
    final legacy = await _store.read('lock_hash');
    _biometric = await _store.read('lock_biometric') == '1';
    _biometricSealed = await _store.read('vault_bio') != null;
    _upgrading = vault == null && legacy != null;
    _set(vault == null && legacy == null ? AppLockState.needsSetup : AppLockState.locked);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _set(AppLockState s) {
    _state = s;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = _now();
    } else if (state == AppLifecycleState.resumed) {
      final since = _pausedAt;
      _pausedAt = null;
      if (_state == AppLockState.unlocked && _away == 0 && !_authenticating && since != null &&
          _now().difference(since) >= relockAfter) {
        _set(AppLockState.locked);
      }
    }
  }

  /// Esegue [action] (che porta l'utente fuori dall'app, es. la fotocamera)
  /// senza bloccare l'app al ritorno.
  Future<T> whileAway<T>(Future<T> Function() action) async {
    _away++;
    try {
      return await action();
    } finally {
      _away--;
    }
  }

  static Future<Uint8List> _derive(String password, String salt) =>
      Isolate.run(() => pbkdf2(password, base64.decode(salt), iterations));

  static String _randomSalt() {
    final rnd = Random.secure();
    return base64.encode(List.generate(16, (_) => rnd.nextInt(256)));
  }

  /// Sale e chiave cifrata in un solo valore, così un'interruzione a metà
  /// del cambio password non li separa mai.
  Future<void> _storeWithPassword(DataKey key, String password) async {
    final salt = _randomSalt();
    final wrapped = await wrapDataKey(key, await _derive(password, salt));
    await _store.write('vault_key', '$salt:$wrapped');
  }

  /// La chiave dei dati aperta con [password]; null se è sbagliata.
  Future<DataKey?> _openWithPassword(String password) async {
    final vault = await _store.read('vault_key');
    if (vault == null) return null;
    final i = vault.indexOf(':');
    if (i < 0) return null;
    return unwrapDataKey(vault.substring(i + 1), await _derive(password, vault.substring(0, i)));
  }

  /// 0.3.4 e prima: controlla [password] con l'hash e, se è giusta, crea la
  /// chiave dei dati al posto dell'hash.
  Future<DataKey?> _upgradeFromHash(String password) async {
    final salt = await _store.read('lock_salt');
    final hash = await _store.read('lock_hash');
    if (salt == null || hash == null) return null;
    if (!_sameBytes(await _derive(password, salt), base64.decode(hash))) return null;
    final key = DataKey.random();
    await _storeWithPassword(key, password);
    // L'hash si toglie solo dopo: se l'app si chiude in mezzo, al prossimo
    // avvio c'è vault_key e si usa quella.
    await _store.delete('lock_hash');
    await _store.delete('lock_salt');
    // La vecchia impronta non apre la nuova chiave.
    await _store.delete('vault_bio');
    _biometricSealed = false;
    _upgrading = false;
    return key;
  }

  void _provide(DataKey key) {
    _key = key;
    if (!_keyReady.isCompleted) _keyReady.complete(key);
  }

  /// Prima configurazione (crea la chiave dei dati) o cambio password (la
  /// stessa chiave, cifrata con la nuova password). Con [unlock] false la
  /// schermata resta finché non si chiama [enter] (es. per proporre prima
  /// l'impronta).
  Future<void> setPassword(String password, {bool unlock = true}) async {
    var key = _key;
    if (key == null) {
      key = DataKey.random();
      _newKey = true;
    }
    await _storeWithPassword(key, password);
    _provide(key);
    if (unlock) enter();
  }

  /// Entra nell'app, se la chiave dei dati è già disponibile.
  void enter() {
    if (_key != null && _state != AppLockState.unlocked) _set(AppLockState.unlocked);
  }

  /// La password è giusta? (Per il cambio password e per l'esportazione.)
  Future<bool> checkPassword(String password) async => await _openWithPassword(password) != null;

  /// Sblocca con la password. Dopo 5 errori di fila impone un'attesa che
  /// raddoppia a ogni nuovo errore (30 s, 1 min, 2 min…).
  Future<bool> unlockWithPassword(String password) async {
    if (waitBeforeRetry > Duration.zero) return false;
    final key = await _openWithPassword(password) ?? (_upgrading ? await _upgradeFromHash(password) : null);
    if (key != null) {
      _failures = 0;
      _retryAt = null;
      _biometricChanged = false;
      _provide(key);
      // L'impronta era attiva ma non apre (più) la chiave: si chiede se
      // riattivarla prima di entrare.
      _set(_biometric && !_biometricSealed ? AppLockState.confirmBiometric : AppLockState.unlocked);
      return true;
    }
    _failures++;
    if (_failures >= 5) {
      _retryAt = _now().add(Duration(seconds: 30 << min(_failures - 5, 6)));
    }
    notifyListeners();
    return false;
  }

  /// C'è almeno un'impronta registrata sul telefono?
  Future<bool> biometricAvailable() => _biometricStore.available();

  /// [reason] e [cancel] sono i testi del dialogo di sistema, già tradotti.
  Future<bool> unlockWithBiometric({required String reason, required String cancel}) async {
    if (!biometricEnabled || _authenticating) return false;
    final sealed = await _store.read('vault_bio');
    if (sealed == null) return false;
    _authenticating = true;
    try {
      final (result, bytes) = await _biometricStore.unseal(sealed, reason: reason, cancel: cancel);
      if (result == BiometricResult.ok && bytes != null && bytes.length == 32) {
        _failures = 0;
        _retryAt = null;
        _provide(DataKey(bytes));
        _set(AppLockState.unlocked);
        return true;
      }
      if (result == BiometricResult.invalidated) {
        // Aggiunta o tolta un'impronta: Android ha cancellato la chiave. Si
        // entra con la password e poi si chiede se riattivarla.
        await _store.delete('vault_bio');
        _biometricSealed = false;
        _biometricChanged = true;
        notifyListeners();
      }
      return false;
    } finally {
      _authenticating = false;
    }
  }

  /// Attiva l'impronta (chiede di appoggiare il dito una volta, per cifrare
  /// la chiave dei dati) o la disattiva. Serve la chiave dei dati, quindi
  /// l'app deve essere sbloccata.
  Future<bool> setBiometric(bool enabled, {required String reason, required String cancel}) async {
    if (enabled) {
      final key = _key;
      if (key == null || _authenticating) return false;
      _authenticating = true;
      final (BiometricResult, String?) sealed;
      try {
        sealed = await _biometricStore.seal(key.bytes, reason: reason, cancel: cancel);
      } finally {
        _authenticating = false;
      }
      if (sealed.$1 != BiometricResult.ok || sealed.$2 == null) return false;
      await _store.write('vault_bio', sealed.$2!);
      _biometricSealed = true;
    } else {
      await _store.delete('vault_bio');
      await _biometricStore.forget();
      _biometricSealed = false;
    }
    _biometric = enabled;
    await _store.write('lock_biometric', enabled ? '1' : '0');
    notifyListeners();
    return true;
  }

  /// Dalla schermata [AppLockState.confirmBiometric]: riattiva l'impronta
  /// (se [use]) e poi entra. false se l'impronta non è stata confermata.
  Future<bool> confirmBiometric({required bool use, required String reason, required String cancel}) async {
    if (!await setBiometric(use, reason: reason, cancel: cancel)) return false;
    enter();
    return true;
  }
}
