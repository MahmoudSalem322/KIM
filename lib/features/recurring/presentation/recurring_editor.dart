import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/money.dart';
import '../../../shared/design_system/components.dart';
import '../../categories/presentation/category_providers.dart';
import '../../categories/presentation/category_widgets.dart';
import '../../transactions/domain/financial_transaction.dart';
import '../../wallets/domain/wallet.dart';
import '../../wallets/presentation/wallet_providers.dart';
import '../domain/recurring_payment.dart';
import 'recurring_copy.dart';
import 'recurring_providers.dart';

Future<void> showRecurringEditor(
  BuildContext context, {
  RecurringPayment? payment,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => RecurringEditor(payment: payment),
);

class RecurringEditor extends ConsumerStatefulWidget {
  const RecurringEditor({super.key, this.payment});
  final RecurringPayment? payment;
  @override
  ConsumerState<RecurringEditor> createState() => _RecurringEditorState();
}

class _RecurringEditorState extends ConsumerState<RecurringEditor> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(
        text: widget.payment?.draft.name ?? '',
      ),
      amount = TextEditingController(
        text: widget.payment?.draft.amount.decimal ?? '',
      ),
      date = TextEditingController(
        text:
            widget.payment?.draft.nextDate ??
            calendarDate(ref.read(appClockProvider)()),
      );
  late RecurringCycle cycle =
      widget.payment?.draft.cycle ?? RecurringCycle.monthly;
  late bool automatic = widget.payment?.draft.automatic ?? false;
  String? walletId, category, fingerprint, error;
  WalletOperation? op;
  bool busy = false, initialized = false;
  @override
  void dispose() {
    name.dispose();
    amount.dispose();
    date.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = RecurringCopy.of(context),
        ws = ref.watch(walletsProvider),
        cs = ref.watch(categoriesProvider),
        ps = ref.watch(recurringPaymentsProvider);
    final loading = ws.isLoading || cs.isLoading || ps.isLoading,
        failed = ws.hasError || cs.hasError || ps.hasError;
    if (loading || failed) {
      return AlertDialog(
        title: Text(s('add')),
        content: loading
            ? const SizedBox(
                height: 60,
                child: Center(child: CircularProgressIndicator()),
              )
            : Text(s('error')),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            child: Text(s('cancel')),
          ),
        ],
      );
    }
    final wallets = ws.requireValue
            .where((w) => !w.wallet.archived && !w.wallet.hidden)
            .toList(),
        categories = cs.requireValue
            .where(
              (c) => !c.archived && c.draft.kind == TransactionKind.expense,
            )
            .toList();
    if (!initialized) {
      walletId =
          widget.payment?.draft.walletId ?? wallets.firstOrNull?.wallet.id;
      category = widget.payment?.draft.category ?? 'otherExpense';
      initialized = true;
    }
    final current = widget.payment == null
        ? null
        : ps.requireValue.where((p) => p.id == widget.payment!.id).firstOrNull;
    final w = wallets.where((w) => w.wallet.id == walletId).firstOrNull;
    if (widget.payment != null &&
        (current?.revision != widget.payment!.revision ||
            ws.requireValue.any(
              (w) =>
                  w.wallet.id == widget.payment!.draft.walletId &&
                  w.wallet.hidden,
            ))) {
      return AlertDialog(
        title: Text(s('edit')),
        content: Text(s('error-conflict')),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            child: Text(s('cancel')),
          ),
        ],
      );
    }
    Money? parsed() {
      try {
        return w == null ? null : Money.parse(amount.text, w.wallet.currency);
      } catch (_) {
        return null;
      }
    }

    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        scrollable: true,
        title: Text(s(widget.payment == null ? 'add' : 'edit')),
        content: SizedBox(
          width: 520,
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WalletTextField(
                  key: const ValueKey('recurring-name'),
                  label: s('name'),
                  controller: name,
                  enabled: !busy,
                  validator: (v) =>
                      v == null || v.trim().isEmpty || v.trim().length > 80
                      ? s('error-invalidRecurring')
                      : null,
                ),
                const SizedBox(height: 18),
                if (wallets.isEmpty)
                  Text(s('noWallet'))
                else
                  DropdownButtonFormField<String>(
                    initialValue: w?.wallet.id,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: s('wallet')),
                    items: [
                      for (final w in wallets)
                        DropdownMenuItem(
                          value: w.wallet.id,
                          child: Text(
                            '${w.wallet.name} · ${w.wallet.currency.code} / ${w.wallet.currency.scale}',
                          ),
                        ),
                    ],
                    onChanged: busy
                        ? null
                        : (v) => setState(() {
                            final previous = w?.wallet.currency;
                            walletId = v;
                            final next = wallets
                                .singleWhere((w) => w.wallet.id == v)
                                .wallet
                                .currency;
                            if (previous != next) amount.clear();
                          }),
                  ),
                const SizedBox(height: 18),
                WalletTextField(
                  key: const ValueKey('recurring-amount'),
                  label: '${s('amount')} (${w?.wallet.currency.code ?? '—'})',
                  controller: amount,
                  enabled: !busy && w != null,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (_) =>
                      parsed() == null || parsed()!.minorUnits <= BigInt.zero
                      ? s('error-invalidRecurring')
                      : null,
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<String>(
                  initialValue: categories.any((c) => c.id == category)
                      ? category
                      : null,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: s('category')),
                  items: [
                    for (final c in categories)
                      DropdownMenuItem(
                        value: c.id,
                        child: Text(categoryLabel(context, ref, c.id)),
                      ),
                  ],
                  onChanged: busy ? null : (v) => setState(() => category = v),
                  validator: (_) => !categories.any((c) => c.id == category)
                      ? s('error-category')
                      : null,
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<RecurringCycle>(
                  initialValue: cycle,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: s('cycle')),
                  items: [
                    for (final c in RecurringCycle.values)
                      DropdownMenuItem(value: c, child: Text(s(c.name))),
                  ],
                  onChanged: busy ? null : (v) => setState(() => cycle = v!),
                ),
                const SizedBox(height: 18),
                WalletTextField(
                  key: const ValueKey('recurring-date'),
                  label: s('next'),
                  controller: date,
                  enabled: !busy,
                  validator: (v) => validTransactionDate(v?.trim() ?? '')
                      ? null
                      : s('error-invalidRecurring'),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s('automatic')),
                  value: automatic,
                  onChanged: busy
                      ? null
                      : (v) => setState(() => automatic = v!),
                ),
                Text(
                  s('autoHint'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                Text(
                  s('editHint'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
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
            key: const ValueKey('recurring-save'),
            onPressed: busy || w == null
                ? null
                : () async {
                    if (!form.currentState!.validate()) return;
                    final draft = RecurringDraft(
                      name: name.text,
                      amount: parsed()!,
                      walletId: walletId!,
                      cycle: cycle,
                      nextDate: date.text.trim(),
                      category: category!,
                      automatic: automatic,
                    );
                    final next = jsonEncode(draft.toJson());
                    if (fingerprint != next) {
                      fingerprint = next;
                      op = WalletOperation.generate();
                    }
                    setState(() {
                      busy = true;
                      error = null;
                    });
                    try {
                      final repo = ref.read(recurringRepositoryProvider),
                          p = widget.payment;
                      if (p == null) {
                        await repo.create(op!, draft);
                      } else {
                        await repo.edit(op!, p.id, p.revision, draft);
                      }
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (mounted) setState(() => error = s.error(e));
                    } finally {
                      if (mounted) setState(() => busy = false);
                    }
                  },
            child: Text(s('save')),
          ),
        ],
      ),
    );
  }
}
