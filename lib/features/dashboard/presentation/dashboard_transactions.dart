import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/money.dart';
import '../../../shared/design_system/components.dart';
import '../../wallets/domain/wallet.dart';
import '../../transactions/domain/financial_transaction.dart';
import '../../transactions/presentation/transaction_row.dart';
import '../../transfers/domain/wallet_transfer.dart';
import '../domain/dashboard_summary.dart';
import 'dashboard_charts.dart';
import 'dashboard_copy.dart';

class DashboardTransactions extends StatelessWidget {
  const DashboardTransactions({
    super.key,
    required this.wallets,
    required this.transactions,
    required this.transfers,
    required this.period,
    required this.currency,
  });
  final List<WalletSnapshot> wallets;
  final List<FinancialTransaction> transactions;
  final List<WalletTransfer> transfers;
  final DashboardPeriod period;
  final Currency currency;
  @override
  Widget build(BuildContext context) {
    final s = DashboardCopy.of(context);
    final activity =
        <(String, DateTime, String, Object)>[
          for (final t in transactions)
            if (!t.deleted &&
                period.contains(t.date) &&
                t.draft.amount.currency == currency)
              (t.date, t.createdAt, t.id, t),
          for (final t in transfers)
            if (!t.cancelled &&
                period.contains(calendarDate(t.createdAt.toLocal())) &&
                (t.draft.amount.currency == currency ||
                    t.received.currency == currency))
              (calendarDate(t.createdAt.toLocal()), t.createdAt, t.id, t),
        ]..sort((a, b) {
          final date = b.$1.compareTo(a.$1);
          if (date != 0) return date;
          final at = b.$2.compareTo(a.$2);
          return at == 0 ? b.$3.compareTo(a.$3) : at;
        });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(s('recent'), style: Theme.of(context).textTheme.titleLarge),
            TextButton(
              onPressed: () => context.go('/transactions'),
              child: Text(s('all')),
            ),
            TextButton(
              onPressed: () => context.go('/transfers'),
              child: Text(s('transferHistory')),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (activity.isEmpty)
          WalletCard(
            child: ChartEmpty(
              icon: Icons.receipt_long_outlined,
              title: s('noActivity'),
              body: s('noActivityBody'),
            ),
          ),
        for (final item in activity.take(5)) ...[
          if (item.$4 case final FinancialTransaction t)
            TransactionRow(
              key: ValueKey('dashboard-${t.id}'),
              transaction: t,
              wallets: wallets,
              editable: false,
            )
          else if (item.$4 case final WalletTransfer t)
            _TransferActivity(transfer: t, wallets: wallets),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _TransferActivity extends StatelessWidget {
  const _TransferActivity({required this.transfer, required this.wallets});
  final WalletTransfer transfer;
  final List<WalletSnapshot> wallets;
  @override
  Widget build(BuildContext context) {
    final source = wallets
        .where((w) => w.wallet.id == transfer.draft.sourceId)
        .firstOrNull;
    final destination = wallets
        .where((w) => w.wallet.id == transfer.draft.destinationId)
        .firstOrNull;
    final hidden =
        (source?.wallet.hidden ?? true) || (destination?.wallet.hidden ?? true);
    final s = DashboardCopy.of(context);
    return WalletCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.swap_horiz_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${s('transfer')} · ${source?.wallet.name ?? ''} / ${destination?.wallet.name ?? ''}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(calendarDate(transfer.createdAt.toLocal())),
          const SizedBox(height: 8),
          Text(
            hidden
                ? '••••••'
                : '${dashboardAmount(transfer.draft.amount)} / ${dashboardAmount(transfer.received)}',
            textDirection: TextDirection.ltr,
          ),
          TextButton(
            onPressed: () => context.go('/transfers'),
            child: Text(s('transferHistory')),
          ),
        ],
      ),
    );
  }
}
