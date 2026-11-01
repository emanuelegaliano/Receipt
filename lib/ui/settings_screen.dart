import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../app_services.dart';
import '../data/backup.dart';
import '../data/database.dart';
import '../data/demo_data.dart';
import '../screens/ocr_screen.dart';
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
      final docs = (await getApplicationDocumentsDirectory()).path;
      await restore(services.db, b, receiptsDir: p.join(docs, 'receipts'));
      // Il tema fa parte delle impostazioni ripristinate.
      services.appearance.value = await AppearanceSettings.load(services.db);
      messenger.showSnackBar(SnackBar(content: Text(l.restoreDone(b.expenses))));
    } on BackupException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(backupErrorText(e.error, l))));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.restoreFailed('$e'))));
    } finally {
      await backup?.dispose();
      if (copy != null && await copy.exists()) await copy.delete();
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _export() async {
    final services = AppServices.of(context);
    final l = context.l10n;
    setState(() => _exporting = true);
    try {
      final file = await exportBackup(services.db);
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
    AppServices.of(context).db.setting('receipt_lang').then((v) {
      if (mounted && v != null) setState(() => _lang = v);
    });
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
