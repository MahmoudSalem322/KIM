import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../backup/presentation/backup_panel.dart';
import 'security_controller.dart';
import 'security_copy.dart';

class MaintenanceOverlay extends ConsumerWidget {
  const MaintenanceOverlay({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Stack(
    fit: StackFit.expand,
    children: [
      child,
      if (ref.watch(workspaceMaintenanceProvider)) ...[
        const Positioned.fill(
          child: ModalBarrier(dismissible: false, color: Colors.black54),
        ),
        Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    SecurityCopy.of(context)(
                      ref.watch(restoreCommittedProvider)
                          ? 'restoredReload'
                          : 'busy',
                    ),
                  ),
                  if (ref.watch(restoreCommittedProvider))
                    TextButton(
                      onPressed: () async {
                        try {
                          await ref.read(reloadWorkspaceProvider)();
                        } catch (_) {
                          /* Recovery remains available after reopening. */
                        }
                      },
                      child: Text(SecurityCopy.of(context)('reopen')),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    ],
  );
}

/// A private navigator supplies the overlay required by editable text and
/// restore dialogs without mounting the financial router behind the lock.
class _LockNavigator extends StatefulWidget {
  const _LockNavigator({required this.child});
  final Widget child;
  @override
  State<_LockNavigator> createState() => _LockNavigatorState();
}

class _LockNavigatorState extends State<_LockNavigator> {
  late final content = ValueNotifier<Widget>(widget.child);
  @override
  void didUpdateWidget(covariant _LockNavigator oldWidget) {
    super.didUpdateWidget(oldWidget);
    content.value = widget.child;
  }

  @override
  void dispose() {
    content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Navigator(
    initialRoute: '/',
    onGenerateRoute: (_) => MaterialPageRoute<void>(
      builder: (_) => ValueListenableBuilder<Widget>(
        valueListenable: content,
        builder: (_, value, _) => value,
      ),
    ),
  );
}

class SecurityGate extends ConsumerStatefulWidget {
  const SecurityGate({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<SecurityGate> createState() => _SecurityGateState();
}

class _SecurityGateState extends ConsumerState<SecurityGate>
    with WidgetsBindingObserver {
  final pin = TextEditingController();
  bool busy = false, failed = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    pin.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // An OS-owned file dialog is part of this app's explicit backup action.
    if (ref.read(externalFileDialogProvider)) return;
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      pin.clear();
      ref.read(securityControllerProvider.notifier).lock();
    }
  }

  Future<void> unlock() async {
    setState(() => busy = true);
    try {
      final ok = await ref
          .read(securityControllerProvider.notifier)
          .unlock(pin.text);
      if (mounted) setState(() => failed = !ok);
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      pin.clear();
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(securityControllerProvider),
        s = SecurityCopy.of(context);
    if (state.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (state.value?.unlocked == true) return widget.child;
    return _LockNavigator(
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.lock_outline, size: 52),
                    const SizedBox(height: 20),
                    Text(
                      s('locked'),
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      key: const ValueKey('unlock-pin'),
                      controller: pin,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      enableSuggestions: false,
                      autocorrect: false,
                      enabled: !busy,
                      decoration: InputDecoration(
                        labelText: 'PIN',
                        errorText: failed ? s('wrong') : null,
                      ),
                      onSubmitted: busy ? null : (_) => unlock(),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      key: const ValueKey('unlock-button'),
                      onPressed: busy || state.hasError ? null : unlock,
                      child: Text(s('unlock')),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      s('limits'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    ExpansionTile(
                      title: Text(s('backup')),
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(12),
                          child: BackupPanel(restoreOnly: true),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showPinEditor(
  BuildContext context,
  WidgetRef ref, {
  bool remove = false,
}) async {
  final s = SecurityCopy.of(context),
      existing = ref.read(securityControllerProvider).value?.hasPin == true;
  final old = TextEditingController(),
      pin = TextEditingController(),
      confirm = TextEditingController();
  bool busy = false;
  String? error;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, update) => AlertDialog(
        title: Text(
          s(
            remove
                ? 'removePin'
                : existing
                ? 'changePin'
                : 'setPin',
          ),
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (existing)
                  TextField(
                    key: const ValueKey('pin-current'),
                    controller: old,
                    obscureText: true,
                    enabled: !busy,
                    decoration: InputDecoration(labelText: s('currentPin')),
                  ),
                if (!remove) ...[
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('pin-new'),
                    controller: pin,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    enabled: !busy,
                    decoration: InputDecoration(labelText: s('newPin')),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('pin-confirm'),
                    controller: confirm,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    enabled: !busy,
                    decoration: InputDecoration(labelText: s('confirmPin')),
                  ),
                ],
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(error!),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(ctx),
            child: Text(s('cancel')),
          ),
          FilledButton(
            key: const ValueKey('pin-save'),
            onPressed: busy
                ? null
                : () async {
                    if (!remove &&
                        (!RegExp(r'^\d{6,12}$').hasMatch(pin.text) ||
                            pin.text != confirm.text)) {
                      update(() => error = s('invalid'));
                      return;
                    }
                    update(() => busy = true);
                    try {
                      final controller = ref.read(
                        securityControllerProvider.notifier,
                      );
                      if (remove) {
                        await controller.remove(old.text);
                      } else {
                        await controller.configure(
                          pin.text,
                          existing ? old.text : null,
                        );
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (_) {
                      if (ctx.mounted) update(() => error = s('wrong'));
                    } finally {
                      if (ctx.mounted) update(() => busy = false);
                    }
                  },
            child: Text(s('save')),
          ),
        ],
      ),
    ),
  );
  // Dialog animations can still reference controllers until the next frame.
  await Future<void>.delayed(const Duration(milliseconds: 250));
  old.dispose();
  pin.dispose();
  confirm.dispose();
}
