import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/money.dart';
import '../../../shared/design_system/components.dart';
import '../domain/wallet.dart';
import 'wallet_copy.dart';
import 'wallet_providers.dart';

Future<void> showWalletAdjustment(
  BuildContext context,
  WalletSnapshot snapshot,
) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => WalletAdjustment(snapshot: snapshot),
);

class WalletAdjustment extends ConsumerStatefulWidget {
  const WalletAdjustment({super.key, required this.snapshot});
  final WalletSnapshot snapshot;
  @override
  ConsumerState<WalletAdjustment> createState() => _WalletAdjustmentState();
}

class _WalletAdjustmentState extends ConsumerState<WalletAdjustment> {
  final form = GlobalKey<FormState>();
  late final target = TextEditingController(
    text: widget.snapshot.wallet.hidden ? '' : widget.snapshot.balance.decimal,
  );
  final reason = TextEditingController();
  bool busy = false;
  String? error, fingerprint;
  WalletOperation? operation;
  @override
  void dispose() {
    target.dispose();
    reason.dispose();
    super.dispose();
  }

  Money? get amount {
    try {
      return Money.parse(target.text, widget.snapshot.wallet.currency);
    } catch (_) {
      return null;
    }
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    final payload = jsonEncode([amount!.toJson(), reason.text.trim()]);
    if (fingerprint != payload) {
      fingerprint = payload;
      operation = WalletOperation.generate();
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref
          .read(walletRepositoryProvider)
          .adjust(
            operation!,
            widget.snapshot.wallet.id,
            widget.snapshot.wallet.revision,
            amount!,
            reason.text,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = WalletCopy.of(context).error(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = WalletCopy.of(context);
    final hidden = widget.snapshot.wallet.hidden;
    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        title: Text(s('adjust')),
        scrollable: true,
        content: SizedBox(
          width: 520,
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s('adjustHelp')),
                const SizedBox(height: 18),
                Text(
                  '${s('balance')}: ${hidden ? s('hidden') : widget.snapshot.balance.decimal} ${widget.snapshot.wallet.currency.code}',
                ),
                const SizedBox(height: 18),
                WalletTextField(
                  key: const ValueKey('adjust-target'),
                  label: s('target'),
                  controller: target,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (_) => amount == null ? s('moneyInvalid') : null,
                ),
                const SizedBox(height: 18),
                WalletTextField(
                  key: const ValueKey('adjust-reason'),
                  label: s('reason'),
                  controller: reason,
                  validator: (v) =>
                      v == null || v.trim().isEmpty || v.trim().length > 500
                      ? s('reasonInvalid')
                      : null,
                ),
                const SizedBox(height: 18),
                if (amount != null && !hidden)
                  Text(
                    '${s('difference')}: ${(amount! - widget.snapshot.balance).decimal} ${widget.snapshot.wallet.currency.code}',
                  ),
                if (error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    error!,
                    key: const ValueKey('wallet-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            child: Text(s('cancel')),
          ),
          FilledButton(
            key: const ValueKey('adjust-save'),
            onPressed: busy ? null : save,
            child: Text(s(busy ? 'saving' : 'adjustSave')),
          ),
        ],
      ),
    );
  }
}
