import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/money.dart';
import '../../../shared/design_system/components.dart';
import '../../transactions/domain/financial_transaction.dart';
import '../../wallets/domain/wallet.dart';
import '../../wallets/presentation/wallet_providers.dart';
import '../domain/debt.dart';
import 'debt_copy.dart';
import 'debt_providers.dart';

Future<void> showDebtEditor(
  BuildContext context, {
  DebtSnapshot? debt,
  DebtEventKind? kind,
  DebtCashEvent? event,
  List<WalletSnapshot> wallets = const [],
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) =>
      DebtEditor(debt: debt, kind: kind, event: event, wallets: wallets),
);

class DebtEditor extends ConsumerStatefulWidget {
  const DebtEditor({
    super.key,
    this.debt,
    this.kind,
    this.event,
    this.wallets = const [],
  });
  final DebtSnapshot? debt;
  final DebtEventKind? kind;
  final DebtCashEvent? event;
  final List<WalletSnapshot> wallets;
  @override
  ConsumerState<DebtEditor> createState() => _DebtEditorState();
}

class _DebtEditorState extends ConsumerState<DebtEditor> {
  final form = GlobalKey<FormState>();
  late final person = TextEditingController(
    text: widget.debt?.debt.draft.person ?? '',
  );
  late final amount = TextEditingController(
    text:
        widget.event?.draft.amount.decimal ??
        (cash
            ? widget.kind == DebtEventKind.principal
                  ? widget.debt!.debt.draft.principal.decimal
                  : widget.debt!.remaining.decimal
            : widget.debt?.debt.draft.principal.decimal) ??
        '',
  );
  late final date = TextEditingController(
    text: cash
        ? widget.event?.draft.date ?? calendarDate(DateTime.now())
        : widget.debt?.debt.draft.dueOn ??
              calendarDate(DateTime.now().add(const Duration(days: 30))),
  );
  late final note = TextEditingController(
    text: cash
        ? widget.event?.draft.note ?? ''
        : widget.debt?.debt.draft.notes ?? '',
  );
  late Currency currency =
      widget.debt?.debt.draft.principal.currency ?? Currency('ILS', 2);
  late DebtDirection direction =
      widget.debt?.debt.draft.direction ?? DebtDirection.lent;
  late final choices = widget.wallets
      .where(
        (w) =>
            !w.wallet.archived &&
            !w.wallet.hidden &&
            w.wallet.currency == currency,
      )
      .toList();
  late String? walletId =
      widget.event?.draft.walletId ?? choices.firstOrNull?.wallet.id;
  bool get cash => widget.kind != null;
  bool get locked => widget.debt?.events.isNotEmpty ?? false;
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
    person.dispose();
    amount.dispose();
    date.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = DebtCopy.of(context), ws = ref.watch(walletsProvider);
    if (widget.debt != null) {
      final live = ref.watch(debtsProvider),
          loading = ws.isLoading || live.isLoading,
          failed = ws.hasError || live.hasError;
      final current = loading || failed
          ? null
          : live.requireValue
                .where((d) => d.debt.id == widget.debt!.debt.id)
                .firstOrNull;
      final hidden = current != null && current.concealed(ws.requireValue);
      final staleWallet =
          cash &&
          !loading &&
          !failed &&
          widget.wallets
              .where(
                (w) =>
                    w.wallet.id == walletId ||
                    w.wallet.id == widget.event?.draft.walletId,
              )
              .any(
                (old) => !ws.requireValue.any(
                  (w) =>
                      w.wallet.id == old.wallet.id &&
                      w.wallet.revision == old.wallet.revision &&
                      !w.wallet.hidden,
                ),
              );
      if (loading ||
          failed ||
          hidden ||
          staleWallet ||
          current?.debt.revision != widget.debt!.debt.revision) {
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
                        ? 'privacy'
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
          for (final w in ws.value ?? <WalletSnapshot>[]) w.wallet.currency,
        }.toList()..sort(
          (a, b) => '${a.code}/${a.scale}'.compareTo('${b.code}/${b.scale}'),
        );
    final selected = choices.where((w) => w.wallet.id == walletId).firstOrNull;
    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        scrollable: true,
        title: Text(
          s(
            cash
                ? widget.event != null
                      ? 'editCash'
                      : widget.kind == DebtEventKind.principal
                      ? 'principalCash'
                      : 'payment'
                : widget.debt == null
                ? 'add'
                : 'edit',
          ),
        ),
        content: SizedBox(
          width: 520,
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s(cash ? 'cashHint' : 'adminHint')),
                const SizedBox(height: 18),
                if (!cash) ...[
                  WalletTextField(
                    key: const ValueKey('debt-person'),
                    label: s('person'),
                    controller: person,
                    enabled: !busy,
                    validator: (v) =>
                        v == null || v.trim().isEmpty || v.trim().length > 80
                        ? s('error-invalidDebt')
                        : null,
                  ),
                  const SizedBox(height: 18),
                  DropdownButtonFormField<DebtDirection>(
                    initialValue: direction,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: s('direction')),
                    items: [
                      for (final d in DebtDirection.values)
                        DropdownMenuItem(value: d, child: Text(s(d.name))),
                    ],
                    onChanged: busy || locked
                        ? null
                        : (v) => setState(() => direction = v!),
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
                          child: Text('${c.code} / ${c.scale}'),
                        ),
                    ],
                    onChanged: busy || locked
                        ? null
                        : (v) => setState(() {
                            currency = v!;
                            amount.clear();
                          }),
                  ),
                  const SizedBox(height: 18),
                ] else ...[
                  Text(
                    widget.debt!.debt.draft.person,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  if (widget.kind == DebtEventKind.principal)
                    Text(s('originalHint')),
                  if (selected == null)
                    Text(s('noWallet'))
                  else
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
                      onChanged: busy
                          ? null
                          : (v) => setState(() => walletId = v),
                    ),
                  const SizedBox(height: 18),
                ],
                WalletTextField(
                  key: const ValueKey('debt-amount'),
                  label:
                      '${s(cash ? 'amount' : 'principal')} (${currency.code})',
                  controller: amount,
                  enabled:
                      !busy &&
                      !(cash ? widget.kind == DebtEventKind.principal : locked),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (_) =>
                      parsed == null || parsed!.minorUnits <= BigInt.zero
                      ? s(cash ? 'error-invalidPayment' : 'error-invalidDebt')
                      : null,
                ),
                const SizedBox(height: 18),
                WalletTextField(
                  key: const ValueKey('debt-date'),
                  label: s(cash ? 'date' : 'due'),
                  controller: date,
                  enabled: !busy,
                  validator: (v) => validTransactionDate(v?.trim() ?? '')
                      ? null
                      : s(cash ? 'error-invalidPayment' : 'error-invalidDebt'),
                ),
                const SizedBox(height: 18),
                WalletTextField(
                  key: const ValueKey('debt-notes'),
                  label: s('notes'),
                  controller: note,
                  enabled: !busy,
                  validator: (v) =>
                      (v?.trim().length ?? 0) > (cash ? 500 : 1000)
                      ? s(cash ? 'error-invalidPayment' : 'error-invalidDebt')
                      : null,
                ),
                const SizedBox(height: 16),
                if (!cash && locked)
                  Text(
                    s('editHint'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (cash && parsed != null)
                  Text(
                    '${s(DebtCashDraft(kind: widget.kind!, walletId: walletId ?? '', amount: parsed!, date: date.text).effect(direction).minorUnits.isNegative ? 'out' : 'in')}: ${parsed!.decimal} ${currency.code}',
                    style: Theme.of(context).textTheme.titleMedium,
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
            key: const ValueKey('debt-save'),
            onPressed: busy || (cash && selected == null)
                ? null
                : () async {
                    if (!form.currentState!.validate()) {
                      return;
                    }
                    final debt = DebtDraft(
                      direction: direction,
                      person: person.text,
                      principal: parsed!,
                      dueOn: date.text.trim(),
                      notes: note.text,
                    );
                    final draft = cash
                        ? DebtCashDraft(
                            kind: widget.kind!,
                            walletId: walletId!,
                            amount: parsed!,
                            date: date.text.trim(),
                            note: note.text,
                          )
                        : null;
                    final next = jsonEncode(
                      cash ? draft!.toJson() : debt.toJson(),
                    );
                    if (next != fingerprint) {
                      fingerprint = next;
                      op = WalletOperation.generate();
                    }
                    setState(() {
                      busy = true;
                      error = null;
                    });
                    try {
                      final repo = ref.read(debtRepositoryProvider),
                          d = widget.debt;
                      if (!cash) {
                        if (d == null) {
                          await repo.create(op!, debt);
                        } else {
                          await repo.edit(
                            op!,
                            d.debt.id,
                            d.debt.revision,
                            debt,
                          );
                        }
                      } else {
                        final revisions = {
                              for (final w in widget.wallets)
                                w.wallet.id: w.wallet.revision,
                            },
                            e = widget.event;
                        if (e == null) {
                          await repo.record(
                            op!,
                            d!.debt.id,
                            d.debt.revision,
                            draft!,
                            revisions,
                          );
                        } else {
                          await repo.editCash(
                            op!,
                            e.id,
                            e.revision,
                            d!.debt.revision,
                            draft!,
                            revisions,
                          );
                        }
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
            child: Text(s(cash ? 'cashSave' : 'save')),
          ),
        ],
      ),
    );
  }
}
