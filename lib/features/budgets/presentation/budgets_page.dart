import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/design_system/components.dart';
import '../../savings/presentation/savings_copy.dart';
import '../../../shared/widgets/operation_action.dart';
import '../../categories/presentation/category_providers.dart';
import '../../categories/presentation/category_widgets.dart';
import '../../categories/presentation/planning_copy.dart';
import '../../transactions/domain/financial_transaction.dart';
import '../../transactions/presentation/transaction_providers.dart';
import '../../wallets/presentation/wallet_providers.dart';
import '../domain/budget.dart';
import 'budget_editor.dart';
import 'budget_providers.dart';

class BudgetsPage extends ConsumerStatefulWidget {
  const BudgetsPage({super.key});
  @override
  ConsumerState<BudgetsPage> createState() => _BudgetsPageState();
}

class _BudgetsPageState extends ConsumerState<BudgetsPage> {
  DateTime date = DateTime.now();
  BudgetCycle cycle = BudgetCycle.monthly;
  bool archived = false;
  @override
  Widget build(BuildContext context) {
    final s = PlanningCopy.of(context), theme = Theme.of(context);
    final budgets = ref.watch(budgetsProvider),
        tx = ref.watch(transactionsProvider),
        wallets = ref.watch(walletsProvider),
        categories = ref.watch(categoriesProvider);
    final loading =
        budgets.isLoading ||
        tx.isLoading ||
        wallets.isLoading ||
        categories.isLoading;
    final error =
        budgets.hasError ||
        tx.hasError ||
        wallets.hasError ||
        categories.hasError;
    final all = loading || error
        ? <Budget>[]
        : budgets.requireValue
              .where((b) => b.archived == archived && b.draft.cycle == cycle)
              .toList();
    final period = BudgetPeriod.containing(cycle, date);
    void move(int direction) => setState(() {
      final next = cycle == BudgetCycle.monthly
          ? DateTime(date.year, date.month + direction)
          : DateTime(date.year, date.month, date.day + 7 * direction);
      if (next.year >= 1900 && next.year <= 2100) date = next;
    });
    return Column(
      key: const ValueKey('budgets-page'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s('budgets'), style: theme.textTheme.headlineLarge),
        const SizedBox(height: 8),
        Text(s('budgetsSub')),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: () => context.go('/goals'),
              icon: const Icon(Icons.savings_outlined),
              label: Text(SavingsCopy.of(context)('navigation')),
            ),
            FilledButton.icon(
              key: const ValueKey('budget-add'),
              onPressed: () => showBudgetEditor(context),
              icon: const Icon(Icons.add),
              label: Text(s('addBudget')),
            ),
            OutlinedButton.icon(
              onPressed: () => context.go('/categories'),
              icon: const Icon(Icons.category_outlined),
              label: Text(s('manageCategories')),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<BudgetCycle>(
              segments: [
                for (final c in BudgetCycle.values)
                  ButtonSegment(value: c, label: Text(s(c.name))),
              ],
              selected: {cycle},
              onSelectionChanged: (v) => setState(() => cycle = v.single),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: const ValueKey('budget-previous'),
                  tooltip: s('previous'),
                  onPressed: () => move(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime(1900),
                      lastDate: DateTime(2100, 12, 31),
                    );
                    if (picked != null && mounted) {
                      setState(() => date = picked);
                    }
                  },
                  child: Text(
                    calendarDate(date),
                    textDirection: TextDirection.ltr,
                  ),
                ),
                IconButton(
                  key: const ValueKey('budget-next'),
                  tooltip: s('next'),
                  onPressed: () => move(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            FilterChip(
              label: Text(s('showArchived')),
              selected: archived,
              onSelected: (v) => setState(() => archived = v),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text('${period.from} — ${period.to}', textDirection: TextDirection.ltr),
        const SizedBox(height: 16),
        Text(s('scopeNote'), style: theme.textTheme.bodySmall),
        const SizedBox(height: 22),
        if (loading)
          const Center(child: CircularProgressIndicator())
        else if (error)
          WalletCard(
            child: Column(
              children: [
                Text(s('error')),
                TextButton(
                  onPressed: () {
                    ref.invalidate(budgetsProvider);
                    ref.invalidate(transactionsProvider);
                    ref.invalidate(walletsProvider);
                    ref.invalidate(categoriesProvider);
                  },
                  child: Text(s('retry')),
                ),
              ],
            ),
          )
        else if (all.isEmpty)
          WalletCard(
            child: SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  Icon(
                    Icons.donut_large_rounded,
                    size: 42,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 14),
                  Text(s('empty'), style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(s('emptyBody'), textAlign: TextAlign.center),
                ],
              ),
            ),
          )
        else
          for (final b in all) ...[
            BudgetCard(
              usage: BudgetUsage(
                b,
                date,
                tx.requireValue,
                wallets.requireValue,
              ),
            ),
            const SizedBox(height: 18),
          ],
      ],
    );
  }
}

class BudgetCard extends ConsumerWidget {
  const BudgetCard({super.key, required this.usage});
  final BudgetUsage usage;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = usage.budget,
        d = b.draft,
        s = PlanningCopy.of(context),
        theme = Theme.of(context);
    final color = usage.remaining.minorUnits.isNegative
        ? theme.colorScheme.error
        : theme.colorScheme.primary;
    String money(String decimal) => '$decimal ${d.limit.currency.code}';
    return WalletCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(d.name, style: theme.textTheme.titleLarge),
              StatusPill(
                label: d.category.isEmpty
                    ? s('general')
                    : categoryLabel(context, ref, d.category),
                icon: Icons.category_outlined,
              ),
              if (b.archived) Text(s('archived')),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${usage.period.from} — ${usage.period.to} · ${d.limit.currency.code}/${d.limit.currency.scale}',
            textDirection: TextDirection.ltr,
          ),
          const SizedBox(height: 18),
          if (usage.concealed)
            Text(s('hidden'))
          else ...[
            Wrap(
              spacing: 28,
              runSpacing: 14,
              children: [
                for (final m in [
                  (s('limit'), d.limit),
                  (s('spent'), usage.spent),
                  (s('remaining'), usage.remaining),
                ])
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.$1, style: theme.textTheme.labelMedium),
                      const SizedBox(height: 6),
                      Text(
                        money(m.$2.decimal),
                        textDirection: TextDirection.ltr,
                        style: theme.textTheme.titleLarge,
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Semantics(
              container: true,
              explicitChildNodes: true,
              child: LinearProgressIndicator(
                value: usage.progress,
                minHeight: 10,
                borderRadius: BorderRadius.circular(10),
                color: color,
                backgroundColor: color.withValues(alpha: .12),
                semanticsLabel: s('spent'),
                semanticsValue: usage.percentage,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              usage.percentage,
              textDirection: TextDirection.ltr,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
            if (!usage.started) Text(s('notStarted')),
            if (!b.archived && usage.crossed != null)
              Container(
                key: ValueKey('budget-alert-${b.id}'),
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.notifications_active_outlined, color: color),
                    const SizedBox(width: 10),
                    Expanded(child: Text('${s('alert')} · ${usage.crossed}%')),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton(
                onPressed: () => showBudgetEditor(context, budget: b),
                child: Text(s('edit')),
              ),
              OperationAction(
                key: ValueKey('budget-archive-${b.id}-${b.revision}'),
                label: s(b.archived ? 'restore' : 'archive'),
                errorText: s.error,
                cancelLabel: s('cancel'),
                run: (op) => ref
                    .read(budgetRepositoryProvider)
                    .setArchived(op, b.id, b.revision, !b.archived),
              ),
              OperationAction(
                key: ValueKey('budget-delete-${b.id}-${b.revision}'),
                label: s('delete'),
                confirm: s('deleteConfirm'),
                errorText: s.error,
                cancelLabel: s('cancel'),
                run: (op) => ref
                    .read(budgetRepositoryProvider)
                    .delete(op, b.id, b.revision),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
