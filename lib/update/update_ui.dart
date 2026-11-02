import 'dart:io';

import 'package:flutter/material.dart';

import '../app_services.dart';
import '../data/database.dart';
import '../ui/l10n.dart';
import 'release.dart';
import 'updater.dart';

/// Impostazione "controlla all'avvio": attiva se non è stata spenta.
Future<bool> updateCheckEnabled(AppDatabase db) async => await db.setting('update_check') != 'off';
Future<void> setUpdateCheckEnabled(AppDatabase db, bool on) => db.setSetting('update_check', on ? 'on' : 'off');

String formatMegabytes(int bytes) => '${(bytes / (1024 * 1024)).round()} MB';

/// All'apertura: se c'è una versione nuova mostra un banner. In silenzio se
/// il controllo è spento, se non c'è rete o se l'app è già aggiornata.
Future<void> checkForUpdatesOnStart(BuildContext context) async {
  final services = AppServices.of(context);
  final updater = services.updater;
  final messenger = ScaffoldMessenger.of(context);
  final AppRelease? release;
  try {
    await updater.cleanup(await updater.currentVersion());
    if (!await updateCheckEnabled(services.db)) return;
    release = await updater.check();
  } catch (_) {
    return;
  }
  if (release == null || !context.mounted) return;
  final l = context.l10n;
  messenger.showMaterialBanner(MaterialBanner(
    leading: const Icon(Icons.system_update_outlined),
    content: Text(l.updateAvailable(release.version, formatMegabytes(release.apkSize))),
    actions: [
      TextButton(onPressed: messenger.hideCurrentMaterialBanner, child: Text(l.updateLater)),
      FilledButton(
        onPressed: () {
          messenger.hideCurrentMaterialBanner();
          showUpdateDialog(context, release!);
        },
        child: Text(l.updateNow),
      ),
    ],
  ));
}

/// "Controlla ora" dalle impostazioni: dice sempre com'è andata.
Future<void> checkForUpdatesNow(BuildContext context) async {
  final updater = AppServices.of(context).updater;
  final messenger = ScaffoldMessenger.of(context);
  final l = context.l10n;
  try {
    final release = await updater.check(timeout: const Duration(seconds: 10));
    if (!context.mounted) return;
    if (release == null) {
      messenger.showSnackBar(SnackBar(content: Text(l.updateUpToDate)));
    } else {
      await showUpdateDialog(context, release);
    }
  } on UpdateException {
    messenger.showSnackBar(SnackBar(content: Text(l.updateCheckFailed)));
  }
}

Future<void> showUpdateDialog(BuildContext context, AppRelease release) => showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _UpdateDialog(release),
    );

enum _Step { downloading, permission, installing, error }

class _UpdateDialog extends StatefulWidget {
  final AppRelease release;
  const _UpdateDialog(this.release);

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  _Step _step = _Step.downloading;
  int _received = 0, _total = 0;
  UpdateError? _error;
  File? _apk;
  bool _closed = false;

  late final AppServices _services = AppServices.of(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _download());
  }

  Future<void> _download() async {
    setState(() {
      _step = _Step.downloading;
      _received = 0;
      _total = widget.release.apkSize;
    });
    try {
      _apk = await _services.updater.download(
        widget.release,
        cancelled: () => _closed,
        onProgress: (r, t) {
          if (mounted) {
            setState(() {
              _received = r;
              _total = t;
            });
          }
        },
      );
      await _install();
    } on UpdateException catch (e) {
      if (mounted && e.error != UpdateError.cancelled) {
        setState(() {
          _step = _Step.error;
          _error = e.error;
        });
      }
    }
  }

  Future<void> _install() async {
    final updater = _services.updater;
    if (!await updater.canInstall()) {
      if (mounted) setState(() => _step = _Step.permission);
      return;
    }
    if (!mounted) return;
    setState(() => _step = _Step.installing);
    await updater.install(_apk!);
  }

  Future<void> _allow() async {
    // Le impostazioni di Android portano fuori dall'app: niente blocco al ritorno.
    final ok = await _services.lock.whileAway(_services.updater.openInstallSettings);
    if (ok) await _install();
  }

  void _close() {
    _closed = true;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final Widget content;
    final actions = <Widget>[TextButton(onPressed: _close, child: Text(_step == _Step.downloading ? l.cancel : l.close))];
    switch (_step) {
      case _Step.downloading:
        content = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.updateDownloading),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: _total > 0 ? _received / _total : null),
            const SizedBox(height: 8),
            Text(l.updateProgress(formatMegabytes(_received), formatMegabytes(_total)),
                style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
        );
      case _Step.permission:
        content = Text(l.updatePermission);
        actions.add(FilledButton(onPressed: _allow, child: Text(l.updateAllow)));
      case _Step.installing:
        content = Text(l.updateInstalling);
        actions.add(FilledButton(onPressed: _install, child: Text(l.updateNow)));
      case _Step.error:
        content = Text(
          _error == UpdateError.corrupted ? l.updateErrorCorrupted : l.updateErrorNetwork,
          style: TextStyle(color: scheme.error),
        );
        actions.add(FilledButton(onPressed: _download, child: Text(l.retry)));
    }
    return AlertDialog(
      icon: const Icon(Icons.system_update_outlined),
      title: Text(l.updateTitle(widget.release.version)),
      content: content,
      actions: actions,
    );
  }
}
