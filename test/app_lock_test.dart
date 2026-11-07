import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_app/security/app_lock.dart';

class _MemoryStore implements SecretStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

/// Al posto del Keystore: "cifra" invertendo i byte. [next] decide cosa fa
/// il prossimo dito (riconosciuto, annullato, impronte cambiate).
class _FakeBiometric implements BiometricKeystore {
  BiometricResult next = BiometricResult.ok;
  int prompts = 0;
  bool forgotten = false;

  @override
  Future<bool> available() async => true;

  @override
  Future<(BiometricResult, String?)> seal(Uint8List secret, {required String reason, required String cancel}) async {
    prompts++;
    if (next != BiometricResult.ok) return (next, null);
    return (BiometricResult.ok, base64.encode(secret.reversed.toList()));
  }

  @override
  Future<(BiometricResult, Uint8List?)> unseal(String sealed, {required String reason, required String cancel}) async {
    prompts++;
    if (next != BiometricResult.ok) return (next, null);
    return (BiometricResult.ok, Uint8List.fromList(base64.decode(sealed).reversed.toList()));
  }

  @override
  Future<void> forget() async => forgotten = true;
}

/// Come lo lasciava la 0.3.4: solo sale e hash PBKDF2 della password.
Map<String, String> _legacyStore(String password, {bool biometric = false}) {
  final salt = base64.encode(List.generate(16, (i) => i));
  return {
    'lock_salt': salt,
    'lock_hash': base64.encode(pbkdf2(password, base64.decode(salt), AppLock.iterations)),
    if (biometric) 'lock_biometric': '1',
  };
}

String _hex(List<int> b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PBKDF2-HMAC-SHA256 coincide con i vettori noti', () {
    expect(_hex(pbkdf2('password', 'salt'.codeUnits, 1)),
        '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b');
    expect(_hex(pbkdf2('password', 'salt'.codeUnits, 4096)),
        'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a');
  });

  test('primo avvio, password, blocco e attesa dopo troppi errori', () async {
    final store = _MemoryStore();
    final lock = AppLock(store: store, biometric: _FakeBiometric());
    await lock.init();
    expect(lock.state, AppLockState.needsSetup);

    await lock.setPassword('segreta');
    expect(lock.state, AppLockState.unlocked);
    expect(store.values.values.join(), isNot(contains('segreta')));

    final again = AppLock(store: store, biometric: _FakeBiometric());
    await again.init();
    expect(again.state, AppLockState.locked);
    expect(await again.unlockWithPassword('sbagliata'), isFalse);
    expect(await again.unlockWithPassword('segreta'), isTrue);
    expect(again.state, AppLockState.unlocked);

    final third = AppLock(store: store, biometric: _FakeBiometric());
    await third.init();
    for (var i = 0; i < 5; i++) {
      await third.unlockWithPassword('no');
    }
    expect(third.waitBeforeRetry, greaterThan(Duration.zero));
    expect(await third.unlockWithPassword('segreta'), isFalse, reason: 'durante l\'attesa nemmeno quella giusta');
  });

  test('si blocca tornando dal sottofondo, ma non durante la fotocamera', () async {
    var now = DateTime(2026, 11, 1, 12);
    final lock = AppLock(store: _MemoryStore(), biometric: _FakeBiometric(), clock: () => now);
    await lock.init();
    await lock.setPassword('segreta');

    void background(Duration d) {
      lock.didChangeAppLifecycleState(AppLifecycleState.paused);
      now = now.add(d);
      lock.didChangeAppLifecycleState(AppLifecycleState.resumed);
    }

    background(const Duration(seconds: 10));
    expect(lock.state, AppLockState.unlocked, reason: 'pausa breve');

    await lock.whileAway(() async => background(const Duration(minutes: 3)));
    expect(lock.state, AppLockState.unlocked, reason: 'fotocamera o condivisione');

    background(const Duration(minutes: 1));
    expect(lock.state, AppLockState.locked);
  });

  test('la password apre la chiave dei dati; cambiarla non cambia la chiave', () async {
    final store = _MemoryStore();
    final lock = AppLock(store: store, biometric: _FakeBiometric());
    await lock.init();
    await lock.setPassword('segreta');
    expect(lock.keyIsNew, isTrue);
    final key = await lock.dataKey;
    expect(store.values.keys, isNot(contains('lock_hash')), reason: 'nessun hash della password');
    expect(store.values.values.join(), isNot(contains(base64.encode(key.bytes))), reason: 'chiave mai in chiaro');

    await lock.setPassword('nuova');
    expect(await lock.checkPassword('segreta'), isFalse);
    expect(await lock.checkPassword('nuova'), isTrue);

    final again = AppLock(store: store, biometric: _FakeBiometric());
    await again.init();
    expect(again.state, AppLockState.locked);
    expect(again.keyIsNew, isFalse);
    expect(await again.unlockWithPassword('nuova'), isTrue);
    expect((await again.dataKey).bytes, key.bytes);
  });

  test('dalla 0.3.4: la password giusta crea la chiave e toglie l\'hash', () async {
    final store = _MemoryStore()..values.addAll(_legacyStore('vecchia'));
    final lock = AppLock(store: store, biometric: _FakeBiometric());
    await lock.init();
    expect((lock.state, lock.needsPasswordOnce), (AppLockState.locked, true));

    expect(await lock.unlockWithPassword('sbagliata'), isFalse);
    expect(store.values, contains('lock_hash'));
    expect(await lock.unlockWithPassword('vecchia'), isTrue);
    expect(lock.state, AppLockState.unlocked);
    expect(lock.needsPasswordOnce, isFalse);
    expect(lock.keyIsNew, isFalse, reason: 'i dati vecchi vanno cifrati, non spostati');
    expect(store.values.keys, containsAll(['vault_key']));
    expect(store.values.keys, isNot(contains('lock_hash')));
    final key = await lock.dataKey;

    final again = AppLock(store: store, biometric: _FakeBiometric());
    await again.init();
    expect(await again.unlockWithPassword('vecchia'), isTrue);
    expect((await again.dataKey).bytes, key.bytes);
  });

  test('dalla 0.3.4 con l\'impronta: password, poi conferma dell\'impronta', () async {
    final store = _MemoryStore()..values.addAll(_legacyStore('vecchia', biometric: true));
    final bio = _FakeBiometric();
    final lock = AppLock(store: store, biometric: bio);
    await lock.init();
    expect(lock.biometricEnabled, isFalse, reason: 'la vecchia impronta non apre la chiave');
    expect(await lock.unlockWithBiometric(reason: '', cancel: ''), isFalse);
    expect(bio.prompts, 0);

    expect(await lock.unlockWithPassword('vecchia'), isTrue);
    expect(lock.state, AppLockState.confirmBiometric);
    bio.next = BiometricResult.cancelled;
    expect(await lock.confirmBiometric(use: true, reason: '', cancel: ''), isFalse);
    expect(lock.state, AppLockState.confirmBiometric);
    bio.next = BiometricResult.ok;
    expect(await lock.confirmBiometric(use: true, reason: '', cancel: ''), isTrue);
    expect((lock.state, lock.biometricEnabled), (AppLockState.unlocked, true));

    final again = AppLock(store: store, biometric: bio);
    await again.init();
    expect(await again.unlockWithBiometric(reason: '', cancel: ''), isTrue);
    expect((await again.dataKey).bytes, (await lock.dataKey).bytes);
  });

  test('impronta: sblocca con la stessa chiave; se cambiano le impronte serve la password', () async {
    final store = _MemoryStore();
    final bio = _FakeBiometric();
    final lock = AppLock(store: store, biometric: bio);
    await lock.init();
    await lock.setPassword('segreta', unlock: false);
    expect(lock.state, AppLockState.needsSetup);
    expect(await lock.setBiometric(true, reason: '', cancel: ''), isTrue);
    lock.enter();
    expect(lock.state, AppLockState.unlocked);

    final again = AppLock(store: store, biometric: bio);
    await again.init();
    bio.next = BiometricResult.cancelled;
    expect(await again.unlockWithBiometric(reason: '', cancel: ''), isFalse);
    expect(again.biometricEnabled, isTrue, reason: 'annullare non la disattiva');
    bio.next = BiometricResult.invalidated;
    expect(await again.unlockWithBiometric(reason: '', cancel: ''), isFalse);
    expect((again.biometricEnabled, again.biometricChanged), (false, true));
    expect(store.values, isNot(contains('vault_bio')));

    bio.next = BiometricResult.ok;
    expect(await again.unlockWithPassword('segreta'), isTrue);
    expect(again.state, AppLockState.confirmBiometric);
    expect(await again.confirmBiometric(use: false, reason: '', cancel: ''), isTrue);
    expect((again.state, again.biometricEnabled, bio.forgotten), (AppLockState.unlocked, false, true));
    expect(store.values['lock_biometric'], '0');
  });
}

