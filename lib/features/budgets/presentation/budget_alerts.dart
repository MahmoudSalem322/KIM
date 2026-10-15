import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/design_system/components.dart';
import '../../categories/presentation/planning_copy.dart';
import '../../transactions/presentation/transaction_providers.dart';
import '../../wallets/presentation/wallet_providers.dart';
import '../domain/budget.dart';
import 'budget_providers.dart';

/// One derived alert per budget and period; no repeated writes or popups.
class BudgetAlerts extends ConsumerWidget {
  const BudgetAlerts({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = ref.watch(budgetsProvider),
        t = ref.watch(transactionsProvider),
        w = ref.watch(walletsProvider),
        s = PlanningCopy.of(context);
    if (b.isLoading || t.isLoading || w.isLoading) {
      return const SizedBox.shrink();
    }
    if (b.hasError || t.hasError || w.hasError) {
      return WalletCard(child: Text(s('error')));
    }
    final alerts = [
      for (final item in b.requireValue.where((b) => !b.archived))
        BudgetUsage(item, DateTime.now(), t.requireValue, w.requireValue),
    ].where((u) => !u.concealed && u.crossed != null).toList();
    if (alerts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: WalletCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s('alert'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            for (final u in alerts)
              Text(
                '${u.budget.draft.name} · ${u.crossed}% · ${u.period.from} — ${u.period.to}',
              ),
            TextButton(
              onPressed: () => context.go('/budgets'),
              child: Text(s('budgets')),
            ),
          ],
        ),
      ),
    );
  }
}
