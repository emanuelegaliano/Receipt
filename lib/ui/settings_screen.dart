import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../app_services.dart';
import '../data/backup.dart';
import '../data/database.dart';
import '../screens/ocr_screen.dart';
import 'format.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _lang = 'it';
  bool _biometricAvailable = false;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ok = await AppServices.of(context).lock.biometricAvailable();
      if (mounted) setState(() => _biometricAvailable = ok);
    });
  }

  Future<void> _export() async {
    final services = AppServices.of(context);
    setState(() => _exporting = true);
    try {
      final file = await exportBackup(services.db);
      // Il foglio di condivisione porta fuori dall'app: niente blocco al ritorno.
      await services.lock.whileAway(() => SharePlus.instance.share(ShareParams(
            files: [XFile(file.path, mimeType: 'application/zip')],
            title: 'Esporta i dati di Receipt',
          )));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Esportazione non riuscita: $e')));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _changePassword() async {
    final lock = AppServices.of(context).lock;
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    String? error;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Cambia password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: current,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Password attuale'),
              ),
              const SizedBox(height: 12),
              TextField(controller: next, obscureText: true, decoration: const InputDecoration(labelText: 'Nuova password')),
              const SizedBox(height: 12),
              TextField(controller: confirm, obscureText: true, decoration: const InputDecoration(labelText: 'Ripeti la nuova password')),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!, style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
            FilledButton(
              onPressed: () async {
                String? e;
                if (next.text.length < 4) {
                  e = 'La nuova password deve avere almeno 4 caratteri';
                } else if (next.text != confirm.text) {
                  e = 'Le nuove password non coincidono';
                } else if (!await lock.checkPassword(current.text)) {
                  e = 'La password attuale è sbagliata';
                }
                if (e != null) return setDialog(() => error = e);
                await lock.setPassword(next.text);
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password cambiata')));
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
    final name = TextEditingController(text: account?.name ?? '');
    var kind = account?.kind ?? AccountKind.other;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(account == null ? 'Nuovo conto' : 'Modifica conto'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Nome', hintText: 'Es. Carta prepagata'),
              ),
              const SizedBox(height: 16),
              SegmentedButton<AccountKind>(
                segments: const [
                  ButtonSegment(value: AccountKind.card, label: Text('Carta')),
                  ButtonSegment(value: AccountKind.cash, label: Text('Contanti')),
                  ButtonSegment(value: AccountKind.other, label: Text('Altro')),
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
                child: const Text('Archivia'),
              ),
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salva')),
          ],
        ),
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      await db.saveAccount(AccountsCompanion(
        id: account == null ? const Value.absent() : Value(account.id),
        name: Value(name.text.trim()),
        kind: Value(kind),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = AppServices.of(context).db;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Impostazioni')),
      body: ListView(
        children: [
          ListTile(title: Text('Aspetto', style: text.titleSmall?.copyWith(color: scheme.primary))),
          const _AppearancePicker(),
          const Divider(),
          ListTile(title: Text('Sicurezza', style: text.titleSmall?.copyWith(color: scheme.primary))),
          ListTile(
            leading: const Icon(Icons.password),
            title: const Text('Cambia password'),
            onTap: _changePassword,
          ),
          ListenableBuilder(
            listenable: AppServices.of(context).lock,
            builder: (context, _) {
              final lock = AppServices.of(context).lock;
              return SwitchListTile(
                secondary: const Icon(Icons.fingerprint),
                title: const Text('Sblocca con l\'impronta'),
                subtitle: Text(_biometricAvailable
                    ? 'La password resta sempre valida'
                    : 'Nessuna impronta registrata sul telefono'),
                value: lock.biometricEnabled,
                onChanged: _biometricAvailable || lock.biometricEnabled ? (v) => lock.setBiometric(v) : null,
              );
            },
          ),
          const Divider(),
          ListTile(title: Text('Scontrini', style: text.titleSmall?.copyWith(color: scheme.primary))),
          ListTile(
            title: const Text('Lingua degli scontrini'),
            subtitle: const Text('Cambia le parole che il lettore cerca per trovare totale e data'),
            isThreeLine: true,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'it', label: Text('Italiano')),
                ButtonSegment(value: 'en', label: Text('Inglese')),
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
            title: const Text('Prova il lettore'),
            subtitle: const Text('Mostra il testo letto e i riquadri, senza salvare nulla'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OcrScreen())),
          ),
          const Divider(),
          ListTile(title: Text('Conti', style: text.titleSmall?.copyWith(color: scheme.primary))),
          StreamBuilder<List<Account>>(
            stream: db.watchAccounts(),
            builder: (context, snap) => Column(
              children: [
                for (final a in snap.data ?? const <Account>[])
                  ListTile(
                    leading: Icon(accountIcon(a.kind)),
                    title: Text(a.name),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () => _editAccount(a),
                  ),
                ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text('Aggiungi conto'),
                  onTap: () => _editAccount(null),
                ),
              ],
            ),
          ),
          const Divider(),
          ListTile(title: Text('Dati', style: text.titleSmall?.copyWith(color: scheme.primary))),
          const ListTile(
            leading: Icon(Icons.lock_outline),
            title: Text('Tutto resta sul telefono'),
            subtitle: Text('Spese, foto e lettura degli scontrini non lasciano mai il dispositivo.'),
          ),
          ListTile(
            leading: _exporting
                ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.ios_share),
            title: const Text('Esporta i dati'),
            subtitle: const Text('Database e foto in un file .zip da salvare dove vuoi, es. su Drive. '
                'Il file non è cifrato.'),
            isThreeLine: true,
            enabled: !_exporting,
            onTap: _export,
          ),
          const ListTile(
            enabled: false,
            leading: Icon(Icons.backup_outlined),
            title: Text('Backup automatico cifrato'),
            subtitle: Text('In arrivo'),
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
                segments: const [
                  ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_outlined), label: Text('Sistema')),
                  ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('Chiaro')),
                  ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Scuro')),
                ],
                selected: {appearance.mode},
                showSelectedIcon: false,
                onSelectionChanged: (s) => update(appearance.copyWith(mode: s.first)),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (var i = 0; i < accentColors.length; i++)
                    Tooltip(
                      message: accentColors[i].$1,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => update(appearance.copyWith(accent: i)),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: accentColors[i].$2,
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
