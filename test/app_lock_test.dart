import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receipt_app/security/app_lock.dart';

class _MemoryStore implements SecretStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
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
    final lock = AppLock(store: store);
    await lock.init();
    expect(lock.state, AppLockState.needsSetup);

    await lock.setPassword('segreta');
    expect(lock.state, AppLockState.unlocked);
    expect(store.values.values.join(), isNot(contains('segreta')));

    final again = AppLock(store: store);
    await again.init();
    expect(again.state, AppLockState.locked);
    expect(await again.unlockWithPassword('sbagliata'), isFalse);
    expect(await again.unlockWithPassword('segreta'), isTrue);
    expect(again.state, AppLockState.unlocked);

    final third = AppLock(store: store);
    await third.init();
    for (var i = 0; i < 5; i++) {
      await third.unlockWithPassword('no');
    }
    expect(third.waitBeforeRetry, greaterThan(Duration.zero));
    expect(await third.unlockWithPassword('segreta'), isFalse, reason: 'durante l\'attesa nemmeno quella giusta');
  });

  test('si blocca tornando dal sottofondo, ma non durante la fotocamera', () async {
    var now = DateTime(2026, 11, 1, 12);
    final lock = AppLock(store: _MemoryStore(), clock: () => now);
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
}
