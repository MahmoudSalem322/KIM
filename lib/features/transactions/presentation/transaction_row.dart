import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../transfers/presentation/transfer_copy.dart';
import '../../categories/presentation/category_widgets.dart';

import '../../../shared/design_system/components.dart';
import '../../wallets/domain/wallet.dart';
import '../domain/financial_transaction.dart';
import 'transaction_copy.dart';
import 'transaction_editor.dart';
import 'transaction_providers.dart';

class TransactionRow extends ConsumerStatefulWidget {
  const TransactionRow({
    super.key,
    required this.transaction,
    required this.wallets,
    this.editable = true,
  });
  final FinancialTransaction transaction;
  final List<WalletSnapshot> wallets;
  final bool editable;
  @override
  ConsumerState<TransactionRow> createState() => _TransactionRowState();
}

class _TransactionRowState extends ConsumerState<TransactionRow> {
  bool busy = false;
  WalletOperation? operation;
  String? fingerprint;
  Future<void> remove() async {
    if (busy) return;
    final s = TransactionCopy.of(context), t = widget.transaction;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s('delete')),
        content: Text(s('deleteBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s('cancel')),
          ),
          FilledButton(
            key: const ValueKey('transaction-delete-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(s('delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || busy) return;
    final revisions = {
      for (final w in widget.wallets) w.wallet.id: w.wallet.revision,
    };
    final key = '${t.id}/${t.revision}/${revisions[t.walletId]}';
    if (key != fingerprint) {
      fingerprint = key;
      operation = WalletOperation.generate();
    }
    setState(() => busy = true);
    try {
      await ref
          .read(transactionRepositoryProvider)
          .delete(operation!, t.id, t.revision, revisions);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(s.error(e))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = TransactionCopy.of(context), t = widget.transaction, d = t.draft;
    final wallet = widget.wallets
        .where((w) => w.wallet.id == t.walletId)
        .firstOrNull;
    final enabled =
        widget.editable &&
        !busy &&
        !t.deleted &&
        t.linkedTransferId.isEmpty &&
        wallet != null &&
        !wallet.wallet.archived;
    final hidden = wallet?.wallet.hidden ?? true;
    final theme = Theme.of(context),
        color = d.kind == TransactionKind.income
            ? theme.colorScheme.primary
            : theme.colorScheme.error;
    return WalletCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  d.kind == TransactionKind.income
                      ? Icons.south_west
                      : Icons.north_east,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${s(d.kind.name)} · ${categoryLabel(context, ref, d.category)}',
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      '${wallet?.wallet.name ?? s('error-notFound')} · ${t.date}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (t.deleted) Chip(label: Text(s('deleted'))),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            hidden
                ? s('hidden')
                : '${d.kind == TransactionKind.income ? '+' : '−'}${d.amount.decimal} ${d.amount.currency.code}',
            textDirection: hidden ? null : TextDirection.ltr,
            style: theme.textTheme.titleLarge?.copyWith(color: color),
          ),
          if (d.notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(d.notes),
          ],
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(s('transactionId'), style: theme.textTheme.bodySmall),
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(t.id),
                    Text(
                      '${s('recorded')}: ${t.createdAt.toLocal().toIso8601String()}',
                    ),
                    Text('${s('date')}: ${t.date}'),
                  ],
                ),
              ),
            ],
          ),
          if (widget.editable)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  key: const ValueKey('transaction-edit'),
                  onPressed: enabled
                      ? () => showTransactionEditor(
                          context,
                          widget.wallets,
                          transaction: t,
                        )
                      : null,
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(s('edit')),
                ),
                TextButton.icon(
                  key: const ValueKey('transaction-delete'),
                  onPressed: enabled ? remove : null,
                  icon: const Icon(Icons.delete_outline),
                  label: Text(s(busy ? 'saving' : 'delete')),
                ),
              ],
            ),
          if (t.linkedTransferId.isNotEmpty)
            TextButton.icon(
              onPressed: () => context.go('/transfers'),
              icon: const Icon(Icons.swap_horiz_rounded),
              label: Text(
                '${TransferCopy.of(context)('linked')}: ${t.linkedTransferId}',
              ),
            ),
        ],
      ),
    );
  }
}
