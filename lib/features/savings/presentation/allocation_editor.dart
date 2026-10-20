import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/money.dart';
import '../../../shared/design_system/components.dart';
import '../../wallets/domain/wallet.dart';
import '../../wallets/presentation/wallet_providers.dart';
import '../domain/savings_goal.dart';
import 'savings_copy.dart';
import 'savings_providers.dart';

Future<void> showAllocationEditor(
  BuildContext context,
  GoalSnapshot goal,
  List<GoalSnapshot> goals,
  List<WalletSnapshot> wallets,
) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => AllocationEditor(goal: goal, goals: goals, wallets: wallets),
);

class AllocationEditor extends ConsumerStatefulWidget {
  const AllocationEditor({
    super.key,
    required this.goal,
    required this.goals,
    required this.wallets,
  });
  final GoalSnapshot goal;
  final List<GoalSnapshot> goals;
  final List<WalletSnapshot> wallets;
  @override
  ConsumerState<AllocationEditor> createState() => _AllocationEditorState();
}

class _AllocationEditorState extends ConsumerState<AllocationEditor> {
  final form = GlobalKey<FormState>(),
      amount = TextEditingController(),
      note = TextEditingController();
  late final choices = widget.wallets
      .where(
        (w) =>
            !w.wallet.archived &&
            !w.wallet.hidden &&
            w.wallet.currency == widget.goal.goal.draft.target.currency,
      )
      .toList();
  String? walletId, error, fingerprint;
  WalletOperation? op;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    if (choices.isNotEmpty) {
      select(choices.first.wallet.id);
    }
  }

  void select(String id) {
    walletId = id;
    amount.text =
        (widget.goal.byWallet[id] ??
                Money(BigInt.zero, widget.goal.goal.draft.target.currency))
            .decimal;
  }

  Money? get parsed {
    try {
      return Money.parse(amount.text, widget.goal.goal.draft.target.currency);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = SavingsCopy.of(context),
        currency = widget.goal.goal.draft.target.currency;
    final w = choices.where((w) => w.wallet.id == walletId).firstOrNull;
    final liveWallets = ref.watch(walletsProvider),
        liveGoals = ref.watch(savingsGoalsProvider);
    final loading = liveWallets.isLoading || liveGoals.isLoading;
    final failed = liveWallets.hasError || liveGoals.hasError;
    final current = loading || failed
        ? null
        : liveWallets.requireValue
              .where((x) => x.wallet.id == walletId)
              .firstOrNull;
    final goal = loading || failed
        ? null
        : liveGoals.requireValue
              .where((x) => x.goal.id == widget.goal.goal.id)
              .firstOrNull;
    if (loading ||
        failed ||
        (w != null &&
            (current == null ||
                current.wallet.hidden ||
                current.wallet.revision != w.wallet.revision)) ||
        goal?.goal.revision != widget.goal.goal.revision) {
      return AlertDialog(
        title: Text(s('allocate')),
        content: loading
            ? const SizedBox(
                height: 60,
                child: Center(child: CircularProgressIndicator()),
              )
            : Text(
                s(
                  failed
                      ? 'error'
                      : current?.wallet.hidden == true
                      ? 'hidden'
                      : 'error-conflict',
                ),
              ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            child: Text(s('cancel')),
          ),
        ],
      );
    }
    String money(Money m) => '${m.decimal} ${m.currency.code}';
    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        scrollable: true,
        title: Text(s('allocate')),
        content: SizedBox(
          width: 520,
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.goal.goal.draft.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(s('reservationHint')),
                const SizedBox(height: 18),
                if (w == null)
                  Text(s('noWallet'))
                else ...[
                  DropdownButtonFormField<String>(
                    initialValue: walletId,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: s('wallet')),
                    items: [
                      for (final w in choices)
                        DropdownMenuItem(
                          value: w.wallet.id,
                          child: Text('${w.wallet.name} · ${currency.code}'),
                        ),
                    ],
                    onChanged: busy ? null : (v) => setState(() => select(v!)),
                  ),
                  const SizedBox(height: 14),
                  Text('${s('balance')}: ${money(w.balance)}'),
                  Text(
                    '${s('reserved')}: ${money(walletReservation(w.wallet.id, currency, widget.goals))}',
                  ),
                  Text(
                    '${s('available')}: ${money(w.balance - walletReservation(w.wallet.id, currency, widget.goals))}',
                  ),
                  Text(
                    '${s('current')}: ${money(widget.goal.byWallet[w.wallet.id] ?? Money(BigInt.zero, currency))}',
                  ),
                  const SizedBox(height: 18),
                  WalletTextField(
                    key: const ValueKey('allocation-amount'),
                    label: '${s('allocation')} (${currency.code})',
                    controller: amount,
                    enabled: !busy,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (_) =>
                        parsed == null || parsed!.minorUnits.isNegative
                        ? s('error-invalidAllocation')
                        : null,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    s('allocationHint'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 18),
                  WalletTextField(
                    label: s('note'),
                    controller: note,
                    enabled: !busy,
                    validator: (v) => (v?.trim().length ?? 0) > 500
                        ? s('error-invalidAllocation')
                        : null,
                  ),
                ],
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
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
            key: const ValueKey('allocation-save'),
            onPressed: busy || w == null
                ? null
                : () async {
                    if (!form.currentState!.validate()) {
                      return;
                    }
                    final next = jsonEncode([
                      walletId,
                      parsed!.toJson(),
                      note.text.trim(),
                    ]);
                    if (fingerprint != next) {
                      fingerprint = next;
                      op = WalletOperation.generate();
                    }
                    setState(() {
                      busy = true;
                      error = null;
                    });
                    try {
                      await ref
                          .read(savingsRepositoryProvider)
                          .allocate(
                            op!,
                            widget.goal.goal.id,
                            widget.goal.goal.revision,
                            w.wallet.id,
                            w.wallet.revision,
                            parsed!,
                            note.text,
                          );
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    } catch (e) {
                      if (mounted) {
                        setState(() => error = s.error(e));
                      }
                    } finally {
                      if (mounted) {
                        setState(() => busy = false);
                      }
                    }
                  },
            child: Text(s('allocationSave')),
          ),
        ],
      ),
    );
  }
}
