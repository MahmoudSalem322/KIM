import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/money.dart';
import '../../../shared/design_system/components.dart';
import '../../transactions/domain/financial_transaction.dart';
import '../../wallets/domain/wallet.dart';
import '../../wallets/presentation/wallet_copy.dart';
import '../../wallets/presentation/wallet_providers.dart';
import '../domain/savings_goal.dart';
import 'savings_copy.dart';
import 'savings_providers.dart';

Future<void> showGoalEditor(BuildContext context, {SavingsGoal? goal}) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => GoalEditor(goal: goal),
    );

class GoalEditor extends ConsumerStatefulWidget {
  const GoalEditor({super.key, this.goal});
  final SavingsGoal? goal;
  @override
  ConsumerState<GoalEditor> createState() => _GoalEditorState();
}

class _GoalEditorState extends ConsumerState<GoalEditor> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.goal?.draft.name ?? '');
  late final amount = TextEditingController(
    text: widget.goal?.draft.target.decimal ?? '',
  );
  late final date = TextEditingController(
    text:
        widget.goal?.draft.dueOn ??
        calendarDate(DateTime.now().add(const Duration(days: 90))),
  );
  late Currency currency =
      widget.goal?.draft.target.currency ?? Currency('ILS', 2);
  late String color = widget.goal?.draft.color ?? 'emerald',
      icon = widget.goal?.draft.icon ?? 'savings';
  bool busy = false;
  String? error, fingerprint;
  WalletOperation? op;
  Money? get parsed {
    try {
      return Money.parse(amount.text, currency);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    name.dispose();
    amount.dispose();
    date.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = SavingsCopy.of(context), w = WalletCopy.of(context);
    final liveWallets = ref.watch(walletsProvider);
    if (widget.goal != null) {
      final liveGoals = ref.watch(savingsGoalsProvider);
      final loading = liveWallets.isLoading || liveGoals.isLoading;
      final failed = liveWallets.hasError || liveGoals.hasError;
      final current = loading || failed
          ? null
          : liveGoals.requireValue
                .where((g) => g.goal.id == widget.goal!.id)
                .firstOrNull;
      final hidden =
          current != null && current.concealed(liveWallets.requireValue);
      if (loading ||
          failed ||
          hidden ||
          current?.goal.revision != widget.goal!.revision) {
        return AlertDialog(
          title: Text(s('edit')),
          content: loading
              ? const SizedBox(
                  height: 60,
                  child: Center(child: CircularProgressIndicator()),
                )
              : Text(
                  s(
                    failed
                        ? 'error'
                        : hidden
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
    }
    final currencies =
        {
          Currency('ILS', 2),
          Currency('USD', 2),
          Currency('JOD', 3),
          Currency('EUR', 2),
          currency,
          for (final w in liveWallets.value ?? <WalletSnapshot>[])
            w.wallet.currency,
        }.toList()..sort(
          (a, b) => '${a.code}/${a.scale}'.compareTo('${b.code}/${b.scale}'),
        );
    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        scrollable: true,
        title: Text(s(widget.goal == null ? 'add' : 'edit')),
        content: SizedBox(
          width: 520,
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WalletTextField(
                  key: const ValueKey('goal-name'),
                  label: s('name'),
                  controller: name,
                  enabled: !busy,
                  validator: (v) =>
                      v == null || v.trim().isEmpty || v.trim().length > 80
                      ? s('error-invalidGoal')
                      : null,
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<Currency>(
                  initialValue: currency,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: s('currency')),
                  items: [
                    for (final c in currencies)
                      DropdownMenuItem(
                        value: c,
                        child: Text('${c.code} · ${c.scale} ${s('scale')}'),
                      ),
                  ],
                  onChanged: busy || widget.goal != null
                      ? null
                      : (v) => setState(() {
                          currency = v!;
                          amount.clear();
                        }),
                ),
                const SizedBox(height: 18),
                WalletTextField(
                  key: const ValueKey('goal-target'),
                  label: '${s('target')} (${currency.code})',
                  controller: amount,
                  enabled: !busy,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (_) =>
                      parsed == null || parsed!.minorUnits <= BigInt.zero
                      ? s('error-invalidGoal')
                      : null,
                ),
                const SizedBox(height: 18),
                WalletTextField(
                  key: const ValueKey('goal-date'),
                  label: s('date'),
                  controller: date,
                  enabled: !busy,
                  validator: (v) => validTransactionDate(v?.trim() ?? '')
                      ? null
                      : s('error-invalidGoal'),
                ),
                TextButton.icon(
                  onPressed: busy
                      ? null
                      : () async {
                          final selected = await showDatePicker(
                            context: context,
                            initialDate: validTransactionDate(date.text.trim())
                                ? DateTime.parse(date.text.trim())
                                : DateTime.now(),
                            firstDate: DateTime(1900),
                            lastDate: DateTime(2100, 12, 31),
                          );
                          if (selected != null && mounted) {
                            date.text = calendarDate(selected);
                          }
                        },
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(s('pickDate')),
                ),
                const SizedBox(height: 12),
                Text(s('color')),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in walletColors)
                      ChoiceChip(
                        label: Text(w(c)),
                        avatar: CircleAvatar(
                          backgroundColor: walletColor(c),
                          radius: 7,
                        ),
                        selected: color == c,
                        onSelected: busy
                            ? null
                            : (_) => setState(() => color = c),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(s('icon')),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final i in goalIcons)
                      ChoiceChip(
                        label: Text(s(i)),
                        avatar: Icon(goalIcon(i), size: 18),
                        selected: icon == i,
                        onSelected: busy
                            ? null
                            : (_) => setState(() => icon = i),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  s('currencyHint'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
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
            key: const ValueKey('goal-save'),
            onPressed: busy
                ? null
                : () async {
                    if (!form.currentState!.validate()) {
                      return;
                    }
                    final d = GoalDraft(
                      name: name.text,
                      target: parsed!,
                      dueOn: date.text.trim(),
                      color: color,
                      icon: icon,
                    );
                    final next = jsonEncode(d.toJson());
                    if (fingerprint != next) {
                      fingerprint = next;
                      op = WalletOperation.generate();
                    }
                    setState(() {
                      busy = true;
                      error = null;
                    });
                    try {
                      final repo = ref.read(savingsRepositoryProvider),
                          g = widget.goal;
                      if (g == null) {
                        await repo.create(op!, d);
                      } else {
                        await repo.edit(op!, g.id, g.revision, d);
                      }
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
            child: Text(s('save')),
          ),
        ],
      ),
    );
  }
}
