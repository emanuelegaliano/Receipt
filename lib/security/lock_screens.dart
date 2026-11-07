import 'dart:async';

import 'package:flutter/material.dart';

import '../ui/l10n.dart';
import 'app_lock.dart';

/// Copre l'app con la schermata di blocco (o di prima configurazione)
/// finché serve. L'app sotto resta viva ma nascosta, così sbloccando si
/// torna esattamente dov'eri.
class LockGate extends StatelessWidget {
  final AppLock lock;
  final Widget child;
  const LockGate({super.key, required this.lock, required this.child});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: lock,
      builder: (context, _) {
        final state = lock.state;
        final cover = switch (state) {
          AppLockState.unlocked => null,
          AppLockState.loading => const Scaffold(),
          AppLockState.needsSetup => _SetupScreen(lock),
          AppLockState.locked => _LockScreen(lock),
          AppLockState.confirmBiometric => _ConfirmBiometricScreen(lock),
        };
        return Stack(
          fit: StackFit.expand,
          children: [
            Offstage(offstage: cover != null, child: child),
            // Overlay proprio: i campi di testo ne hanno bisogno e il
            // Navigator dell'app è nascosto qui sotto.
            if (cover != null)
              Overlay(
                key: ValueKey(state),
                initialEntries: [OverlayEntry(builder: (_) => cover)],
              ),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _Header(this.icon, this.title, this.subtitle);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        CircleAvatar(
          radius: 36,
          backgroundColor: scheme.primaryContainer,
          child: Icon(icon, size: 36, color: scheme.onPrimaryContainer),
        ),
        const SizedBox(height: 20),
        Text(title, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String label;
  final String? error;
  final bool autofocus;
  final TextInputAction action;
  final VoidCallback? onSubmitted;
  const _PasswordField({
    required this.controller,
    this.focusNode,
    required this.label,
    this.error,
    this.autofocus = false,
    this.action = TextInputAction.done,
    this.onSubmitted,
  });

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      obscureText: !_visible,
      enableSuggestions: false,
      autocorrect: false,
      textInputAction: widget.action,
      onSubmitted: (_) => widget.onSubmitted?.call(),
      decoration: InputDecoration(
        labelText: widget.label,
        errorText: widget.error,
        // Fuori dall'ordine del focus: "Avanti" sulla tastiera deve passare
        // al campo successivo, non all'occhio.
        suffixIcon: ExcludeFocus(
          child: IconButton(
            tooltip: _visible ? context.l10n.hidePassword : context.l10n.showPassword,
            icon: Icon(_visible ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            onPressed: () => setState(() => _visible = !_visible),
          ),
        ),
      ),
    );
  }
}

Widget _page(BuildContext context, List<Widget> children) => Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
            ),
          ),
        ),
      ),
    );

/// Primo avvio: scelta della password, poi proposta dell'impronta.
class _SetupScreen extends StatefulWidget {
  final AppLock lock;
  const _SetupScreen(this.lock);

  @override
  State<_SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<_SetupScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _error, _confirmError;
  bool _busy = false;
  bool _askBiometric = false;

  Future<void> _save() async {
    final p = _password.text;
    setState(() {
      _error = p.length < 4 ? context.l10n.passwordTooShort : null;
      _confirmError = _error == null && _confirm.text != p ? context.l10n.passwordsMismatch : null;
    });
    if (_error != null || _confirmError != null) return;
    setState(() => _busy = true);
    // Crea la chiave dei dati; si entra dopo, così c'è tempo per l'impronta.
    await widget.lock.setPassword(p, unlock: false);
    // Se c'è un'impronta registrata la proponiamo prima di entrare.
    if (await widget.lock.biometricAvailable()) {
      if (mounted) {
        setState(() {
          _askBiometric = true;
          _busy = false;
        });
      }
      return;
    }
    widget.lock.enter();
  }

  Future<void> _finish({required bool biometric}) async {
    setState(() => _busy = true);
    final l = context.l10n;
    if (biometric &&
        !await widget.lock.setBiometric(true, reason: l.biometricPromptConfirm, cancel: l.biometricUsePassword)) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    widget.lock.enter();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (_askBiometric) {
      return _page(context, [
        _Header(Icons.fingerprint, l.useBiometricTitle, l.useBiometricMessage),
        FilledButton.icon(
          onPressed: _busy ? null : () => _finish(biometric: true),
          icon: const Icon(Icons.fingerprint),
          label: Text(l.useBiometric),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _busy ? null : () => _finish(biometric: false),
          child: Text(l.notNow),
        ),
      ]);
    }
    return _page(context, [
      _Header(Icons.lock_outline, l.setupTitle, l.setupMessage),
      _PasswordField(
        controller: _password,
        label: l.password,
        error: _error,
        autofocus: true,
        action: TextInputAction.next,
      ),
      const SizedBox(height: 16),
      _PasswordField(controller: _confirm, label: l.repeatPassword, error: _confirmError, onSubmitted: _save),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: _busy ? null : _save,
        child: _busy
            ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(l.continueLabel),
      ),
    ]);
  }
}

class _LockScreen extends StatefulWidget {
  final AppLock lock;
  const _LockScreen(this.lock);

  @override
  State<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<_LockScreen> {
  final _password = TextEditingController();
  final _focus = FocusNode();
  String? _error;
  bool _busy = false;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // La schermata sta in un Overlay che LockGate non ricostruisce: segue da
    // sola il blocco (es. impronte cambiate mentre è aperta).
    widget.lock.addListener(_lockChanged);
    // Con l'impronta attiva la chiediamo subito, appena la schermata compare.
    if (widget.lock.biometricEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _biometric());
    }
  }

  void _lockChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.lock.removeListener(_lockChanged);
    _tick?.cancel();
    _focus.dispose();
    super.dispose();
  }

  void _biometric() {
    if (!mounted) return;
    final l = context.l10n;
    widget.lock.unlockWithBiometric(reason: l.biometricPromptUnlock, cancel: l.biometricUsePassword);
  }

  Future<void> _unlock() async {
    if (_password.text.isEmpty || _busy) return;
    setState(() => _busy = true);
    final ok = await widget.lock.unlockWithPassword(_password.text);
    if (!mounted || ok) return;
    _password.clear();
    setState(() {
      _busy = false;
      _error = context.l10n.wrongPassword;
    });
    _focus.requestFocus();
    if (widget.lock.waitBeforeRetry > Duration.zero) {
      _tick?.cancel();
      _tick = Timer.periodic(const Duration(seconds: 1), (t) {
        if (widget.lock.waitBeforeRetry == Duration.zero) t.cancel();
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final wait = widget.lock.waitBeforeRetry;
    final scheme = Theme.of(context).colorScheme;
    // Prima apertura dopo l'aggiornamento alla 0.3.5, o impronte cambiate:
    // spiega perché stavolta serve la password.
    final note = widget.lock.needsPasswordOnce
        ? l.lockedUpgradeMessage
        : widget.lock.biometricChanged
            ? l.biometricChangedMessage
            : null;
    return _page(context, [
      _Header(Icons.lock_outline, l.lockedTitle, l.lockedMessage),
      if (note != null) ...[
        Card.filled(
          color: scheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, color: scheme.onSecondaryContainer),
                const SizedBox(width: 12),
                Expanded(child: Text(note, style: TextStyle(color: scheme.onSecondaryContainer))),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
      _PasswordField(
        controller: _password,
        focusNode: _focus,
        label: l.password,
        error: wait > Duration.zero ? l.tooManyAttempts(wait.inSeconds + 1) : _error,
        autofocus: !widget.lock.biometricEnabled,
        onSubmitted: _unlock,
      ),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: _busy || wait > Duration.zero ? null : _unlock,
        child: _busy
            ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(l.unlock),
      ),
      if (widget.lock.biometricEnabled) ...[
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _biometric,
          icon: const Icon(Icons.fingerprint),
          label: Text(l.useBiometric),
        ),
      ],
    ]);
  }
}

/// Password giusta, ma l'impronta era attiva e non apre più la chiave dei
/// dati (dopo l'aggiornamento alla 0.3.5, o se sono cambiate le impronte del
/// telefono): si chiede di confermarla una volta.
class _ConfirmBiometricScreen extends StatefulWidget {
  final AppLock lock;
  const _ConfirmBiometricScreen(this.lock);

  @override
  State<_ConfirmBiometricScreen> createState() => _ConfirmBiometricScreenState();
}

class _ConfirmBiometricScreenState extends State<_ConfirmBiometricScreen> {
  bool _busy = false;

  Future<void> _choose(bool use) async {
    final l = context.l10n;
    setState(() => _busy = true);
    await widget.lock.confirmBiometric(use: use, reason: l.biometricPromptConfirm, cancel: l.cancel);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return _page(context, [
      _Header(Icons.fingerprint, l.biometricConfirmTitle, l.biometricConfirmMessage),
      FilledButton.icon(
        onPressed: _busy ? null : () => _choose(true),
        icon: const Icon(Icons.fingerprint),
        label: Text(l.useBiometric),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: _busy ? null : () => _choose(false),
        child: Text(l.notNow),
      ),
    ]);
  }
}

/// Chiede la password (non l'impronta) prima di un'azione delicata, come
/// esportare i dati in chiaro. true se è giusta.
Future<bool> askPassword(
  BuildContext context,
  AppLock lock, {
  required String title,
  required String message,
  required String confirm,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => _PasswordDialog(lock: lock, title: title, message: message, confirm: confirm),
  );
  return ok ?? false;
}

class _PasswordDialog extends StatefulWidget {
  final AppLock lock;
  final String title, message, confirm;
  const _PasswordDialog({required this.lock, required this.title, required this.message, required this.confirm});

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _password = TextEditingController();
  final _focus = FocusNode();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    if (_password.text.isEmpty || _busy) return;
    setState(() => _busy = true);
    final ok = await widget.lock.checkPassword(_password.text);
    if (!mounted) return;
    if (ok) return Navigator.pop(context, true);
    _password.clear();
    setState(() {
      _busy = false;
      _error = context.l10n.wrongPassword;
    });
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      icon: const Icon(Icons.lock_outline),
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.message),
          const SizedBox(height: 16),
          _PasswordField(
            controller: _password,
            focusNode: _focus,
            label: l.password,
            error: _error,
            autofocus: true,
            onSubmitted: _check,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: Text(l.cancel)),
        FilledButton(
          onPressed: _busy ? null : _check,
          child: _busy
              ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(widget.confirm),
        ),
      ],
    );
  }
}
