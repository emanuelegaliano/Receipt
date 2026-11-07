import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../app_services.dart';
import '../art/art_ui.dart';
import '../art/daily_art.dart';
import '../data/backup.dart';
import '../data/database.dart';
import '../data/demo_data.dart';
import '../screens/ocr_screen.dart';
import '../security/lock_screens.dart';
import '../update/update_ui.dart';
import 'format.dart';
import 'l10n.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _lang = 'it';
  bool _biometricAvailable = false;
  bool _exporting = false;
  bool _importing = false;
  bool? _checkUpdates;
  String? _version;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ok = await AppServices.of(context).lock.biometricAvailable();
      if (mounted) setState(() => _biometricAvailable = ok);
    });
  }

  /// Ripristina da uno zip di "Esporta i dati", sostituendo i dati attuali.
  Future<void> _import() async {
    final services = AppServices.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    final picked = await services.lock.whileAway(() => FilePicker.pickFile(dialogTitle: l.chooseBackup));
    if (picked == null || !mounted) return;
    setState(() => _importing = true);
    BackupPreview? backup;
    File? copy;
    try {
      // Il file può arrivare da Drive o da un'altra app: prima lo copiamo qui.
      final tmp = (await getTemporaryDirectory()).path;
      copy = File(p.join(tmp, 'import-${DateTime.now().millisecondsSinceEpoch}.zip'));
      final sink = copy.openWrite();
      await sink.addStream(picked.readAsByteStream());
      await sink.close();
      backup = await openBackup(copy, tmpDir: tmp, currentSchema: services.db.schemaVersion);
      final current = (await services.db.select(services.db.expenses).get()).length;
      if (!mounted) return;
      final b = backup;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.settings_backup_restore),
          title: Text(l.restoreTitle),
          content: Text(
            '${b.createdAt == null ? l.restoreSummary(b.expenses, b.photos) : l.restoreSummaryDated(b.createdAt!, b.expenses, b.photos)}'
            '\n\n${l.restoreReplaceWarning(current)}',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.replace)),
          ],
        ),
      );
      if (ok != true) return;
      final receipts = (await services.photos.directory()).path;
      await restore(services.db, b, receiptsDir: receipts, key: await services.lock.dataKey);
      // Il tema fa parte delle impostazioni ripristinate.
      services.appearance.value = await AppearanceSettings.load(services.db);
      await services.appearance.value.cache();
      await services.art.reload();
      messenger.showSnackBar(SnackBar(content: Text(l.restoreDone(b.expenses))));
    } on BackupException catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(backupErrorText(e, l, file: picked.name)),
        duration: const Duration(seconds: 12),
        showCloseIcon: true,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.restoreFailed('$e'))));
    } finally {
      await backup?.dispose();
      if (copy != null && await copy.exists()) await copy.delete();
      // file_picker tiene un'altra copia (in chiaro) in cache/file_picker.
      try {
        await FilePicker.clearTemporaryFiles();
      } catch (_) {
        // Resta nella cache, che Android svuota quando serve spazio.
      }
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _export() async {
    final services = AppServices.of(context);
    final l = context.l10n;
    // Lo zip è in chiaro: serve la password, l'impronta non basta (chi ha il
    // telefono in mano e un dito "prestato" non deve poter portarsi via tutto).
    final ok = await askPassword(context, services.lock,
        title: l.exportPasswordTitle, message: l.exportPasswordMessage, confirm: l.exportAction);
    if (!ok || !mounted) return;
    setState(() => _exporting = true);
    try {
      final file = await exportBackup(services.db, await services.lock.dataKey);
      // Il foglio di condivisione porta fuori dall'app: niente blocco al ritorno.
      await services.lock.whileAway(() => SharePlus.instance.share(ShareParams(
            files: [XFile(file.path, mimeType: 'application/zip')],
            title: l.exportShareTitle,
          )));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.exportFailed('$e'))));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _changePassword() async {
    final lock = AppServices.of(context).lock;
    final l = context.l10n;
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    String? error;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(l.changePassword),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: current,
                obscureText: true,
                autofocus: true,
                decoration: InputDecoration(labelText: l.currentPassword),
              ),
              const SizedBox(height: 12),
              TextField(controller: next, obscureText: true, decoration: InputDecoration(labelText: l.newPassword)),
              const SizedBox(height: 12),
              TextField(
                  controller: confirm,
                  obscureText: true,
                  decoration: InputDecoration(labelText: l.repeatNewPassword)),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!, style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
            FilledButton(
              onPressed: () async {
                String? e;
                if (next.text.length < 4) {
                  e = l.newPasswordTooShort;
                } else if (next.text != confirm.text) {
                  e = l.newPasswordsMismatch;
                } else if (!await lock.checkPassword(current.text)) {
                  e = l.currentPasswordWrong;
                }
                if (e != null) return setDialog(() => error = e);
                await lock.setPassword(next.text);
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
              child: Text(l.save),
            ),
          ],
        ),
      ),
    );
    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.passwordChanged)));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final services = AppServices.of(context);
    services.db.setting('receipt_lang').then((v) {
      if (mounted && v != null) setState(() => _lang = v);
    });
    updateCheckEnabled(services.db).then((v) {
      if (mounted) setState(() => _checkUpdates = v);
    });
    services.updater.currentVersion().then((v) {
      if (mounted) setState(() => _version = v);
    }, onError: (_) {});
  }

  Future<void> _checkNow() async {
    setState(() => _checking = true);
    try {
      await checkForUpdatesNow(context);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _editAccount(Account? account) async {
    final db = AppServices.of(context).db;
    final l = context.l10n;
    // I conti predefiniti si aprono col nome nella lingua dell'app.
    final shown = account == null ? '' : accountLabel(account, l);
    final name = TextEditingController(text: shown);
    var kind = account?.kind ?? AccountKind.other;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(account == null ? l.newAccount : l.editAccount),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: l.name, hintText: l.accountNameHint),
              ),
              const SizedBox(height: 16),
              SegmentedButton<AccountKind>(
                segments: [
                  ButtonSegment(value: AccountKind.card, label: Text(l.accountCard)),
                  ButtonSegment(value: AccountKind.cash, label: Text(l.accountCash)),
                  ButtonSegment(value: AccountKind.other, label: Text(l.accountOther)),
                ],
                selected: {kind},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setDialog(() => kind = s.first),
              ),
            ],
          ),
          actions: [
            if (account != null)
              TextButton(
                onPressed: () async {
                  await db.saveAccount(AccountsCompanion(id: Value(account.id), archived: const Value(true)));
                  if (ctx.mounted) Navigator.pop(ctx, false);
                },
                child: Text(l.archive),
              ),
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.save)),
          ],
        ),
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      // Nome predefinito non toccato: resta quello salvato, che segue la lingua.
      final newName = account != null && name.text.trim() == shown ? account.name : name.text.trim();
      await db.saveAccount(AccountsCompanion(
        id: account == null ? const Value.absent() : Value(account.id),
        name: Value(newName),
        kind: Value(kind),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = AppServices.of(context).db;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: ListView(
        children: [
          ListTile(title: Text(l.sectionAppearance, style: text.titleSmall?.copyWith(color: scheme.primary))),
          const _AppearancePicker(),
          const _DailyArtTile(),
          const Divider(),
          ListTile(title: Text(l.sectionSecurity, style: text.titleSmall?.copyWith(color: scheme.primary))),
          ListTile(
            leading: const Icon(Icons.password),
            title: Text(l.changePassword),
            onTap: _changePassword,
          ),
          ListenableBuilder(
            listenable: AppServices.of(context).lock,
            builder: (context, _) {
              final lock = AppServices.of(context).lock;
              return SwitchListTile(
                secondary: const Icon(Icons.fingerprint),
                title: Text(l.biometricUnlock),
                subtitle: Text(_biometricAvailable ? l.biometricKeepsPassword : l.biometricNone),
                value: lock.biometricEnabled,
                onChanged: _biometricAvailable || lock.biometricEnabled
                    ? (v) => lock.setBiometric(v, reason: l.biometricPromptConfirm, cancel: l.biometricUsePassword)
                    : null,
              );
            },
          ),
          const Divider(),
          ListTile(title: Text(l.sectionReceipts, style: text.titleSmall?.copyWith(color: scheme.primary))),
          ListTile(
            title: Text(l.receiptLanguage),
            subtitle: Text(l.receiptLanguageHint),
            isThreeLine: true,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'it', label: Text(l.receiptLangItalian)),
                ButtonSegment(value: 'en', label: Text(l.receiptLangEnglish)),
              ],
              selected: {_lang},
              onSelectionChanged: (s) {
                setState(() => _lang = s.first);
                db.setSetting('receipt_lang', s.first);
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.document_scanner_outlined),
            title: Text(l.tryReader),
            subtitle: Text(l.tryReaderHint),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OcrScreen())),
          ),
          const Divider(),
          ListTile(title: Text(l.sectionAccounts, style: text.titleSmall?.copyWith(color: scheme.primary))),
          StreamBuilder<List<Account>>(
            stream: db.watchAccounts(),
            builder: (context, snap) => Column(
              children: [
                for (final a in snap.data ?? const <Account>[])
                  ListTile(
                    leading: Icon(accountIcon(a.kind)),
                    title: Text(accountLabel(a, l)),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () => _editAccount(a),
                  ),
                ListTile(
                  leading: const Icon(Icons.add),
                  title: Text(l.addAccount),
                  onTap: () => _editAccount(null),
                ),
              ],
            ),
          ),
          const Divider(),
          ListTile(title: Text(l.sectionData, style: text.titleSmall?.copyWith(color: scheme.primary))),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: Text(l.dataStaysOnPhone),
            subtitle: Text(l.dataStaysOnPhoneHint),
          ),
          ListTile(
            leading: _exporting
                ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.ios_share),
            title: Text(l.exportData),
            subtitle: Text(l.exportDataHint),
            isThreeLine: true,
            enabled: !_exporting,
            onTap: _export,
          ),
          ListTile(
            leading: _importing
                ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.settings_backup_restore),
            title: Text(l.importBackup),
            subtitle: Text(l.importBackupHint),
            enabled: !_importing,
            onTap: _import,
          ),
          ListTile(
            enabled: false,
            leading: const Icon(Icons.backup_outlined),
            title: Text(l.autoBackup),
            subtitle: Text(l.comingSoon),
          ),
          const Divider(),
          ListTile(title: Text(l.sectionUpdates, style: text.titleSmall?.copyWith(color: scheme.primary))),
          SwitchListTile(
            secondary: const Icon(Icons.system_update_outlined),
            title: Text(l.updateCheckOnStart),
            subtitle: Text(l.updateCheckOnStartHint),
            value: _checkUpdates ?? false,
            onChanged: _checkUpdates == null
                ? null
                : (v) {
                    setState(() => _checkUpdates = v);
                    setUpdateCheckEnabled(db, v);
                  },
          ),
          ListTile(
            leading: _checking
                ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            title: Text(l.updateCheckNow),
            subtitle: _version == null ? null : Text(l.updateInstalledVersion(_version!)),
            enabled: !_checking,
            onTap: _checkNow,
          ),
          if (demoEnabled)
            ListTile(
              leading: const Icon(Icons.science_outlined),
              title: Text(l.loadDemo),
              subtitle: Text(l.loadDemoHint),
              onTap: () async {
                final month = AppServices.of(context).month;
                await loadDemoData(db, DateTime(2026, 10));
                month.value = DateTime(2026, 10);
                if (context.mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }
}

/// Il quadro del giorno come sfondo: spento finché l'utente non lo accende,
/// perché scarica un'immagine al giorno da internet.
class _DailyArtTile extends StatelessWidget {
  const _DailyArtTile();

  @override
  Widget build(BuildContext context) {
    final art = AppServices.of(context).art;
    final l = context.l10n;
    final lang = Localizations.localeOf(context).languageCode;
    return ListenableBuilder(
      listenable: art,
      builder: (context, _) {
        final painting = art.painting;
        final status = !art.enabled
            ? l.dailyArtHint
            : art.downloading
                ? l.dailyArtDownloading
                : art.failed && painting == null
                    ? l.dailyArtFailed
                    : painting != null
                        ? l.dailyArtToday(painting.titleIn(lang), painting.artist)
                        : l.dailyArtHint;
        final image = art.image;
        final percent = (art.visibility * 100).round();
        return Column(
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.palette_outlined),
              title: Text(l.dailyArt),
              subtitle: Text(status),
              isThreeLine: true,
              value: art.enabled,
              onChanged: art.setEnabled,
            ),
            if (art.enabled)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    if (image != null) ...[
                      PaintingPreview(file: image, visibility: art.visibility),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(l.dailyArtVisibility('$percent')),
                          ),
                          // Mentre si trascina cambia solo lo schermo; si salva al rilascio.
                          Slider(
                            value: percent.toDouble(),
                            min: DailyArt.minVisibility * 100,
                            max: DailyArt.maxVisibility * 100,
                            divisions: 9,
                            label: '$percent%',
                            onChanged: (v) => art.setVisibility(v / 100, save: false),
                            onChangeEnd: (v) => art.setVisibility(v / 100),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AppearancePicker extends StatelessWidget {
  const _AppearancePicker();

  @override
  Widget build(BuildContext context) {
    final services = AppServices.of(context);
    final scheme = Theme.of(context).colorScheme;
    final l = context.l10n;
    final accentNames = [
      l.accentGreen,
      l.accentBlue,
      l.accentPurple,
      l.accentPink,
      l.accentOrange,
      l.accentGraphite,
    ];
    return ValueListenableBuilder(
      valueListenable: services.appearance,
      builder: (context, appearance, _) {
        void update(AppearanceSettings next) {
          services.appearance.value = next;
          next.save(services.db);
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<ThemeMode>(
                segments: [
                  ButtonSegment(
                      value: ThemeMode.system, icon: const Icon(Icons.brightness_auto_outlined), label: Text(l.themeSystem)),
                  ButtonSegment(value: ThemeMode.light, icon: const Icon(Icons.light_mode_outlined), label: Text(l.themeLight)),
                  ButtonSegment(value: ThemeMode.dark, icon: const Icon(Icons.dark_mode_outlined), label: Text(l.themeDark)),
                ],
                selected: {appearance.mode},
                showSelectedIcon: false,
                onSelectionChanged: (s) => update(appearance.copyWith(mode: s.first)),
              ),
              const SizedBox(height: 16),
              Text(l.appLanguage, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'system', icon: const Icon(Icons.language), label: Text(l.languageSystem)),
                  ButtonSegment(value: 'it', label: Text(l.languageItalian)),
                  ButtonSegment(value: 'en', label: Text(l.languageEnglish)),
                ],
                selected: {appearance.language},
                showSelectedIcon: false,
                onSelectionChanged: (s) => update(appearance.copyWith(language: s.first)),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (var i = 0; i < accentColors.length; i++)
                    Tooltip(
                      message: accentNames[i],
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => update(appearance.copyWith(accent: i)),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: accentColors[i],
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: i == appearance.accent ? scheme.onSurface : Colors.transparent,
                              width: 3,
                            ),
                          ),
                          child: i == appearance.accent ? const Icon(Icons.check, color: Colors.white) : null,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
