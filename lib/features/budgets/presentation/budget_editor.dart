import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/money.dart';
import '../../../shared/design_system/components.dart';
import '../../categories/presentation/category_providers.dart';
import '../../categories/presentation/category_widgets.dart';
import '../../categories/presentation/planning_copy.dart';
import '../../transactions/domain/financial_transaction.dart';
import '../../wallets/domain/wallet.dart';
import '../../wallets/presentation/wallet_providers.dart';
import '../domain/budget.dart';
import 'budget_providers.dart';

Future<void> showBudgetEditor(BuildContext context, {Budget? budget}) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BudgetEditor(budget: budget),
    );

class BudgetEditor extends ConsumerStatefulWidget {
  const BudgetEditor({super.key, this.budget});
  final Budget? budget;
  @override
  ConsumerState<BudgetEditor> createState() => _BudgetEditorState();
}

class _BudgetEditorState extends ConsumerState<BudgetEditor> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(
    text: widget.budget?.draft.name ?? '',
  );
  late final amount = TextEditingController(
    text: widget.budget?.draft.limit.decimal ?? '',
  );
  late final startsOn = TextEditingController(
    text: widget.budget?.draft.startsOn ?? calendarDate(DateTime.now()),
  );
  late Currency currency =
      widget.budget?.draft.limit.currency ?? Currency('ILS', 2);
  late BudgetCycle cycle = widget.budget?.draft.cycle ?? BudgetCycle.monthly;
  late String category = widget.budget?.draft.category ?? '';
  late Set<int> thresholds = {
    ...widget.budget?.draft.thresholds ?? [50, 80, 100],
  };
  bool busy = false;
  String? error, fingerprint;
  WalletOperation? op;
  @override
  void dispose() {
    name.dispose();
    amount.dispose();
    startsOn.dispose();
    super.dispose();
  }

  Money? get parsed {
    try {
      return Money.parse(amount.text, currency);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = PlanningCopy.of(context), state = ref.watch(categoriesProvider);
    final choices = (state.value ?? [])
        .where(
          (c) =>
              c.draft.kind == TransactionKind.expense &&
              (!c.archived || c.id == widget.budget?.draft.category),
        )
        .toList();
    final currencies =
        {
          Currency('ILS', 2),
          Currency('USD', 2),
          Currency('JOD', 3),
          Currency('EUR', 2),
          currency,
          for (final w
              in ref.watch(walletsProvider).value ?? <WalletSnapshot>[])
            w.wallet.currency,
        }.toList()..sort(
          (a, b) => '${a.code}/${a.scale}'.compareTo('${b.code}/${b.scale}'),
        );
    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        title: Text(s(widget.budget == null ? 'addBudget' : 'editBudget')),
        scrollable: true,
        content: SizedBox(
          width: 520,
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WalletTextField(
                  key: const ValueKey('budget-name'),
                  label: s('name'),
                  controller: name,
                  enabled: !busy,
                  validator: (v) =>
                      v == null || v.trim().isEmpty || v.trim().length > 80
                      ? s('invalidBudget')
                      : null,
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<BudgetCycle>(
                  initialValue: cycle,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: s('cycle')),
                  items: [
                    for (final c in BudgetCycle.values)
                      DropdownMenuItem(value: c, child: Text(s(c.name))),
                  ],
                  onChanged: busy ? null : (v) => setState(() => cycle = v!),
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
                  onChanged: busy
                      ? null
                      : (v) => setState(() {
                          currency = v!;
                          amount.clear();
                        }),
                ),
                const SizedBox(height: 18),
                WalletTextField(
                  key: const ValueKey('budget-limit'),
                  label: '${s('limit')} (${currency.code})',
                  controller: amount,
                  enabled: !busy,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (_) =>
                      parsed == null || parsed!.minorUnits <= BigInt.zero
                      ? s('invalidBudget')
                      : null,
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<String>(
                  key: ValueKey('budget-category-$category-${choices.length}'),
                  initialValue: category,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: s('category')),
                  items: [
                    DropdownMenuItem(value: '', child: Text(s('general'))),
                    for (final c in choices)
                      DropdownMenuItem(
                        value: c.id,
                        child: Text(categoryLabel(context, ref, c.id)),
                      ),
                    if (category.isNotEmpty &&
                        !choices.any((c) => c.id == category))
                      DropdownMenuItem(
                        value: category,
                        child: Text(categoryLabel(context, ref, category)),
                      ),
                  ],
                  onChanged: busy || state.isLoading || state.hasError
                      ? null
                      : (v) => setState(() => category = v!),
                ),
                const SizedBox(height: 18),
                WalletTextField(
                  key: const ValueKey('budget-start'),
                  label: s('firstPeriod'),
                  controller: startsOn,
                  enabled: !busy,
                  validator: (v) => validTransactionDate(v?.trim() ?? '')
                      ? null
                      : s('invalidBudget'),
                ),
                const SizedBox(height: 12),
                Text(
                  s('periodHint'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 18),
                Text(s('alerts')),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    for (final p in [50, 80, 100])
                      FilterChip(
                        label: Text('$p%'),
                        selected: thresholds.contains(p),
                        onSelected: busy
                            ? null
                            : (selected) => setState(() {
                                if (selected) {
                                  thresholds.add(p);
                                } else {
                                  thresholds.remove(p);
                                }
                              }),
                      ),
                  ],
                ),
                if (widget.budget != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    s('editNote'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (state.hasError) Text(s('error')),
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
            key: const ValueKey('budget-save'),
            onPressed: busy || state.isLoading || state.hasError
                ? null
                : () async {
                    if (!form.currentState!.validate()) return;
                    final draft = BudgetDraft(
                      name: name.text,
                      limit: parsed!,
                      cycle: cycle,
                      startsOn: BudgetPeriod.containing(
                        cycle,
                        DateTime.parse(startsOn.text.trim()),
                      ).from,
                      category: category,
                      thresholds: thresholds.toList(),
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
                      final repo = ref.read(budgetRepositoryProvider),
                          b = widget.budget;
                      if (b == null) {
                        await repo.create(op!, draft);
                      } else {
                        await repo.edit(op!, b.id, b.revision, draft);
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
