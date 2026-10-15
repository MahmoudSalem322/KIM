import 'package:flutter/material.dart';

import '../../features/wallets/domain/wallet.dart';

/// Keeps one operation ID across retries; recreated for a new entity revision.
class OperationAction extends StatefulWidget {
  const OperationAction({
    super.key,
    required this.label,
    required this.run,
    required this.errorText,
    required this.cancelLabel,
    this.confirm,
    this.enabled = true,
  });
  final String label, cancelLabel;
  final Future<void> Function(WalletOperation) run;
  final String Function(Object) errorText;
  final String? confirm;
  final bool enabled;
  @override
  State<OperationAction> createState() => _OperationActionState();
}

class _OperationActionState extends State<OperationAction> {
  WalletOperation? op;
  bool busy = false;
  Future<void> run() async {
    if (busy) return;
    if (widget.confirm != null) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(widget.label),
          content: Text(widget.confirm!),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(widget.cancelLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(widget.label),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted) return;
    }
    if (busy) return;
    setState(() => busy = true);
    op ??= WalletOperation.generate();
    try {
      await widget.run(op!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(widget.errorText(e))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: busy || !widget.enabled ? null : run,
    child: busy
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(widget.label),
  );
}
