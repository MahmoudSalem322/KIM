import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/design_system/components.dart';
import '../../wallets/presentation/wallet_widgets.dart';
import '../../transactions/presentation/transaction_copy.dart';
import '../../transactions/presentation/transaction_providers.dart';
import '../../transactions/presentation/transaction_editor.dart';
import '../../transactions/presentation/transaction_row.dart';

class DashboardTransactions extends ConsumerWidget {
  const DashboardTransactions({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = TransactionCopy.of(context);
    return WalletDataView(
      builder: (wallets) => ref
          .watch(transactionsProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => WalletCard(
              child: Column(
                children: [
                  Text(s.error(e)),
                  TextButton(
                    onPressed: () => ref.invalidate(transactionsProvider),
                    child: Text(s('retry')),
                  ),
                ],
              ),
            ),
            data: (all) {
              final recent = all.where((t) => !t.deleted).take(3);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        s('history'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      TextButton(
                        onPressed: () => context.go('/transactions'),
                        child: Text(s('viewAll')),
                      ),
                      FilledButton.icon(
                        onPressed: wallets.any((w) => !w.wallet.archived)
                            ? () => showTransactionEditor(context, wallets)
                            : null,
                        icon: const Icon(Icons.add),
                        label: Text(s('add')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (recent.isEmpty)
                    WalletCard(
                      child: SizedBox(
                        width: double.infinity,
                        child: Column(
                          children: [
                            const Icon(Icons.receipt_long_outlined, size: 36),
                            const SizedBox(height: 12),
                            Text(s('empty')),
                            const SizedBox(height: 8),
                            Text(s('emptyBody'), textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    ),
                  for (final t in recent) ...[
                    TransactionRow(
                      key: ValueKey(t.id),
                      transaction: t,
                      wallets: wallets,
                      editable: false,
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            },
          ),
    );
  }
}
