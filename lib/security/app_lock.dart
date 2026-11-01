import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

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
}

class SecureSecretStore implements SecretStore {
  final _storage = const FlutterSecureStorage();
  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);
}

enum AppLockState { loading, needsSetup, locked, unlocked }

/// Blocco dell'app: password scelta al primo avvio, impronta facoltativa.
///
/// Della password si salva solo l'hash PBKDF2 con sale casuale. L'app si
/// blocca all'avvio e quando torna in primo piano dopo [relockAfter] in
/// sottofondo, tranne mentre è aperta un'attività esterna voluta
/// (fotocamera, galleria, condivisione): vedi [whileAway].
class AppLock extends ChangeNotifier with WidgetsBindingObserver {
  static const iterations = 120000;
  static const relockAfter = Duration(seconds: 30);

  final SecretStore _store;
  final LocalAuthentication _auth;
  final DateTime Function() _now;
  AppLock({SecretStore? store, LocalAuthentication? auth, DateTime Function()? clock})
      : _store = store ?? SecureSecretStore(),
        _auth = auth ?? LocalAuthentication(),
        _now = clock ?? DateTime.now;

  AppLockState _state = AppLockState.loading;
  AppLockState get state => _state;
  bool _biometric = false;
  bool get biometricEnabled => _biometric;

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
    final hash = await _store.read('lock_hash');
    _biometric = await _store.read('lock_biometric') == '1';
    _set(hash == null ? AppLockState.needsSetup : AppLockState.locked);
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

  static Future<String> _hash(String password, String salt) => Isolate.run(
        () => base64.encode(pbkdf2(password, base64.decode(salt), iterations)),
      );

  Future<void> setPassword(String password) async {
    final rnd = Random.secure();
    final salt = base64.encode(List.generate(16, (_) => rnd.nextInt(256)));
    await _store.write('lock_salt', salt);
    await _store.write('lock_hash', await _hash(password, salt));
    if (_state != AppLockState.unlocked) _set(AppLockState.unlocked);
  }

  Future<bool> checkPassword(String password) async {
    final salt = await _store.read('lock_salt');
    final hash = await _store.read('lock_hash');
    if (salt == null || hash == null) return false;
    return _sameBytes(base64.decode(await _hash(password, salt)), base64.decode(hash));
  }

  /// Sblocca con la password. Dopo 5 errori di fila impone un'attesa che
  /// raddoppia a ogni nuovo errore (30 s, 1 min, 2 min…).
  Future<bool> unlockWithPassword(String password) async {
    if (waitBeforeRetry > Duration.zero) return false;
    if (await checkPassword(password)) {
      _failures = 0;
      _retryAt = null;
      _set(AppLockState.unlocked);
      return true;
    }
    _failures++;
    if (_failures >= 5) {
      _retryAt = _now().add(Duration(seconds: 30 << min(_failures - 5, 6)));
    }
    notifyListeners();
    return false;
  }

  /// C'è almeno un'impronta (o un volto) registrata sul telefono?
  Future<bool> biometricAvailable() async {
    try {
      return await _auth.isDeviceSupported() && (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _authenticate(String reason) async {
    _authenticating = true;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        authMessages: const [
          AndroidAuthMessages(signInTitle: 'Receipt', cancelButton: 'Usa la password'),
        ],
      );
    } catch (_) {
      return false;
    } finally {
      _authenticating = false;
    }
  }

  Future<bool> unlockWithBiometric() async {
    if (!_biometric) return false;
    final ok = await _authenticate('Sblocca Receipt');
    if (ok) {
      _failures = 0;
      _retryAt = null;
      _set(AppLockState.unlocked);
    }
    return ok;
  }

  /// Attiva l'impronta solo dopo averla verificata una volta.
  Future<bool> setBiometric(bool enabled) async {
    if (enabled && !await _authenticate('Conferma l\'impronta per sbloccare Receipt')) return false;
    _biometric = enabled;
    await _store.write('lock_biometric', enabled ? '1' : '0');
    notifyListeners();
    return true;
  }
}
