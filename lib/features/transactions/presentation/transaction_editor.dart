import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/money.dart';
import '../../../shared/design_system/components.dart';
import '../../wallets/domain/wallet.dart';
import '../../wallets/presentation/wallet_providers.dart';
import '../domain/financial_transaction.dart';
import 'transaction_copy.dart';
import 'transaction_providers.dart';

Future<void> showTransactionEditor(
  BuildContext context,
  List<WalletSnapshot> wallets, {
  FinancialTransaction? transaction,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => TransactionEditor(wallets: wallets, transaction: transaction),
);

class TransactionEditor extends ConsumerStatefulWidget {
  const TransactionEditor({super.key, required this.wallets, this.transaction});
  final List<WalletSnapshot> wallets;
  final FinancialTransaction? transaction;
  @override
  ConsumerState<TransactionEditor> createState() => _TransactionEditorState();
}

class _TransactionEditorState extends ConsumerState<TransactionEditor> {
  final form = GlobalKey<FormState>();
  late final choices = widget.wallets.where((w) => !w.wallet.archived).toList();
  late String walletId =
      widget.transaction?.walletId ?? choices.first.wallet.id;
  late TransactionKind kind =
      widget.transaction?.draft.kind ?? TransactionKind.expense;
  late String category =
      widget.transaction?.draft.category ?? categoriesFor(kind).first;
  late final amount = TextEditingController(
    text: initialWallet.wallet.hidden
        ? ''
        : widget.transaction?.draft.amount.decimal ?? '',
  );
  late final date = TextEditingController(
    text: widget.transaction?.date ?? calendarDate(DateTime.now()),
  );
  late final notes = TextEditingController(
    text: widget.transaction?.draft.notes ?? '',
  );
  late final revisions = {
    for (final w in widget.wallets) w.wallet.id: w.wallet.revision,
  };
  WalletSnapshot get initialWallet =>
      widget.wallets.singleWhere((w) => w.wallet.id == walletId);
  late bool lastHidden = initialWallet.wallet.hidden;
  bool busy = false;
  String? error, fingerprint;
  WalletOperation? operation;
  @override
  void dispose() {
    amount.dispose();
    date.dispose();
    notes.dispose();
    super.dispose();
  }

  Money? get parsed {
    try {
      return Money.parse(amount.text, initialWallet.wallet.currency);
    } catch (_) {
      return null;
    }
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    final draft = TransactionDraft(
      walletId: walletId,
      kind: kind,
      amount: parsed!,
      category: category,
      date: date.text.trim(),
      notes: notes.text,
    );
    final payload = jsonEncode(draft.toJson());
    if (payload != fingerprint) {
      fingerprint = payload;
      operation = WalletOperation.generate();
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final repo = ref.read(transactionRepositoryProvider);
      final current = widget.transaction;
      if (current == null) {
        await repo.create(operation!, draft, revisions);
      } else {
        await repo.edit(
          operation!,
          current.id,
          current.revision,
          draft,
          revisions,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = TransactionCopy.of(context).error(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = TransactionCopy.of(context);
    final live = ref
        .watch(walletsProvider)
        .asData
        ?.value
        .where((w) => w.wallet.id == walletId)
        .firstOrNull;
    final hidden = live?.wallet.hidden ?? true;
    if (hidden && !lastHidden) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(amount.clear);
      });
    }
    lastHidden = hidden;
    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        title: Text(s(widget.transaction == null ? 'add' : 'edit')),
        scrollable: true,
        content: SizedBox(
          width: 560,
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<TransactionKind>(
                  segments: [
                    for (final k in TransactionKind.values)
                      ButtonSegment(
                        value: k,
                        label: Text(s(k.name)),
                        icon: Icon(
                          k == TransactionKind.income
                              ? Icons.south_west
                              : Icons.north_east,
                        ),
                      ),
                  ],
                  selected: {kind},
                  onSelectionChanged: busy
                      ? null
                      : (value) => setState(() {
                          kind = value.single;
                          category = categoriesFor(kind).first;
                        }),
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<String>(
                  key: const ValueKey('transaction-wallet'),
                  initialValue: walletId,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: s('wallet')),
                  items: [
                    for (final w in choices)
                      DropdownMenuItem(
                        value: w.wallet.id,
                        child: Text(
                          '${w.wallet.name} · ${w.wallet.currency.code}',
                        ),
                      ),
                  ],
                  onChanged: busy
                      ? null
                      : (value) => setState(() {
                          final previous = initialWallet.wallet.currency;
                          walletId = value!;
                          if (previous != initialWallet.wallet.currency) {
                            amount.clear();
                          }
                          lastHidden = false;
                        }),
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<String>(
                  key: ValueKey('transaction-category-${kind.name}'),
                  initialValue: category,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: s('category')),
                  items: [
                    for (final c in categoriesFor(kind))
                      DropdownMenuItem(value: c, child: Text(s(c))),
                  ],
                  onChanged: busy
                      ? null
                      : (value) => setState(() => category = value!),
                ),
                const SizedBox(height: 18),
                WalletTextField(
                  key: const ValueKey('transaction-amount'),
                  label:
                      '${s('amount')} (${initialWallet.wallet.currency.code})',
                  controller: amount,
                  enabled: !busy,
                  obscureText: hidden,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (_) =>
                      parsed == null || parsed!.minorUnits <= BigInt.zero
                      ? s('error-amount')
                      : null,
                ),
                const SizedBox(height: 8),
                Text(
                  s('currencyHelp'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: WalletTextField(
                        key: const ValueKey('transaction-date'),
                        label: s('date'),
                        controller: date,
                        enabled: !busy,
                        validator: (v) => validTransactionDate(v?.trim() ?? '')
                            ? null
                            : s('error-date'),
                      ),
                    ),
                    IconButton(
                      tooltip: s('pickDate'),
                      onPressed: busy
                          ? null
                          : () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: validTransactionDate(date.text)
                                    ? DateTime.parse(date.text)
                                    : DateTime.now(),
                                firstDate: DateTime(1900),
                                lastDate: DateTime(2100, 12, 31),
                              );
                              if (picked != null && mounted) {
                                setState(
                                  () => date.text = calendarDate(picked),
                                );
                              }
                            },
                      icon: const Icon(Icons.calendar_month_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  s('dateHelp'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 18),
                WalletTextField(
                  key: const ValueKey('transaction-notes'),
                  label: s('notes'),
                  controller: notes,
                  enabled: !busy,
                  validator: (v) =>
                      (v?.trim().length ?? 0) > 1000 ? s('error-notes') : null,
                ),
                if (widget.transaction != null) ...[
                  const SizedBox(height: 18),
                  Text(s('editHelp')),
                ],
                if (error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    error!,
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
            key: const ValueKey('transaction-save'),
            onPressed: busy ? null : save,
            child: Text(s(busy ? 'saving' : 'save')),
          ),
        ],
      ),
    );
  }
}
