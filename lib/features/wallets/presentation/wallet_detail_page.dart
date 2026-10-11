import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/money.dart';
import '../../../shared/design_system/components.dart';
import '../domain/wallet.dart';
import 'wallet_copy.dart';
import 'wallet_editor.dart';
import 'wallet_adjustment.dart';
import 'wallet_widgets.dart';
import '../../transactions/presentation/transaction_copy.dart';
import '../../transfers/presentation/transfer_copy.dart';

class WalletDetailPage extends StatelessWidget {
  const WalletDetailPage({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) => WalletDataView(
    builder: (all) {
      final matches = all.where((s) => s.wallet.id == id);
      final s = WalletCopy.of(context), theme = Theme.of(context);
      final ts = TransactionCopy.of(context);
      final fs = TransferCopy.of(context);
      if (matches.isEmpty) {
        return Column(
          children: [
            Text(s('notFound')),
            TextButton(
              onPressed: () => context.go('/wallets'),
              child: Text(s('back')),
            ),
          ],
        );
      }
      final snapshot = matches.single, w = snapshot.wallet;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: () => context.go('/wallets'),
            icon: const Icon(Icons.arrow_back_rounded),
            label: Text(s('back')),
          ),
          const SizedBox(height: 12),
          Text(w.name, style: theme.textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(
            '${s(w.type)} · ${w.currency.code} · ${s('created')}: ${entryDate(context, w.createdAt)}',
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: [
                  walletColor(w.color),
                  Color.lerp(walletColor(w.color), Colors.black, .35)!,
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(walletIcon(w.icon), color: Colors.white, size: 32),
                const SizedBox(height: 16),
                Text(
                  s('balance'),
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      w.hidden
                          ? '••••••'
                          : '${snapshot.balance.decimal} ${w.currency.code}',
                      textDirection: TextDirection.ltr,
                      style: theme.textTheme.headlineLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              WalletButton(
                key: const ValueKey('wallet-edit'),
                label: s('edit'),
                icon: Icons.edit_outlined,
                onPressed: w.archived
                    ? null
                    : () => showWalletEditor(context, wallet: snapshot),
              ),
              WalletButton(
                key: const ValueKey('wallet-adjust'),
                label: s('adjust'),
                icon: Icons.balance_outlined,
                secondary: true,
                onPressed: w.archived
                    ? null
                    : () => showWalletAdjustment(context, snapshot),
              ),
              WalletActionButton(
                key: const ValueKey('wallet-hide'),
                label: s(w.hidden ? 'show' : 'hide'),
                icon: w.hidden
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                requestKey: 'hide-${w.id}-${w.revision}-${w.hidden}',
                action: (repo, op) =>
                    repo.setHidden(op, w.id, w.revision, !w.hidden),
              ),
              WalletActionButton(
                key: const ValueKey('wallet-archive'),
                label: s(w.archived ? 'restore' : 'archive'),
                icon: w.archived
                    ? Icons.unarchive_outlined
                    : Icons.inventory_2_outlined,
                confirmation: s(w.archived ? 'restoreBody' : 'archiveBody'),
                requestKey: 'archive-${w.id}-${w.revision}-${w.archived}',
                action: (repo, op) =>
                    repo.setArchived(op, w.id, w.revision, !w.archived),
              ),
            ],
          ),
          if (w.archived) ...[const SizedBox(height: 18), Text(s('readonly'))],
          const SizedBox(height: 36),
          Text(s('history'), style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          for (final entry in snapshot.entries.reversed) ...[
            WalletCard(
              key: ValueKey('entry-${entry.operationId}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        entry.kind == WalletEntryKind.opening
                            ? Icons.flag_outlined
                            : Icons.balance_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(switch (entry.kind) {
                          WalletEntryKind.opening => s('opening'),
                          WalletEntryKind.adjustment => s('adjustment'),
                          WalletEntryKind.income => ts('incomeLedger'),
                          WalletEntryKind.expense => ts('expenseLedger'),
                          WalletEntryKind.reversal => ts('reversalLedger'),
                          WalletEntryKind.transferOut => fs('out'),
                          WalletEntryKind.transferIn => fs('in'),
                          WalletEntryKind.transferReversal => fs('reverse'),
                        }, style: theme.textTheme.titleMedium),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(entryDate(context, entry.at)),
                  if (entry.reason.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      entry.transferId.isNotEmpty
                          ? fs(
                              entry.kind == WalletEntryKind.transferOut
                                  ? 'out'
                                  : entry.kind == WalletEntryKind.transferIn
                                  ? 'in'
                                  : entry.kind == WalletEntryKind.expense
                                  ? 'fee'
                                  : 'reverse',
                            )
                          : entry.transactionId.isEmpty
                          ? entry.reason
                          : ts(
                              entry.kind == WalletEntryKind.reversal
                                  ? (entry.reason == 'edit'
                                        ? 'editReversal'
                                        : 'cancelReversal')
                                  : entry.reason,
                            ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  _HistoryAmount(
                    label: entry.transactionId.isEmpty
                        ? s('difference')
                        : ts('amount'),
                    amount: entry.delta,
                    hidden: w.hidden,
                  ),
                  const SizedBox(height: 6),
                  _HistoryAmount(
                    label: s('before'),
                    amount: entry.before,
                    hidden: w.hidden,
                  ),
                  const SizedBox(height: 6),
                  _HistoryAmount(
                    label: s('after'),
                    amount: entry.after,
                    hidden: w.hidden,
                  ),
                  const SizedBox(height: 14),
                  Text(s('operation'), style: theme.textTheme.labelSmall),
                  const SizedBox(height: 4),
                  Semantics(
                    label: entry.operationId,
                    child: ExcludeSemantics(
                      child: SelectableText(
                        entry.operationId,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ),
                  if (entry.transactionId.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('${ts('transactionId')}: ${entry.transactionId}'),
                    TextButton(
                      onPressed: () => context.go('/transactions'),
                      child: Text(ts('viewAll')),
                    ),
                  ],
                  if (entry.transferId.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('${fs('id')}: ${entry.transferId}'),
                    TextButton(
                      onPressed: () => context.go('/transfers'),
                      child: Text(fs('navigation')),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
        ],
      );
    },
  );
}

class _HistoryAmount extends StatelessWidget {
  const _HistoryAmount({
    required this.label,
    required this.amount,
    required this.hidden,
  });
  final String label;
  final Money amount;
  final bool hidden;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 4,
    children: [
      Text('$label:'),
      Text(
        hidden ? '••••••' : '${amount.decimal} ${amount.currency.code}',
        textDirection: TextDirection.ltr,
      ),
    ],
  );
}
