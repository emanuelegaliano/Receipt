import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../app_services.dart';
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
          const ListTile(
            enabled: false,
            leading: Icon(Icons.backup_outlined),
            title: Text('Backup cifrato'),
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
