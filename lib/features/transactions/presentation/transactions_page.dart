import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/design_system/components.dart';
import '../../wallets/presentation/wallet_widgets.dart';
import '../domain/financial_transaction.dart';
import 'transaction_copy.dart';
import 'transaction_editor.dart';
import 'transaction_providers.dart';
import 'transaction_row.dart';

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});
  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  final search = TextEditingController(),
      from = TextEditingController(),
      to = TextEditingController();
  String type = 'all', walletId = 'all', category = 'all', status = 'active';
  @override
  void dispose() {
    search.dispose();
    from.dispose();
    to.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = TransactionCopy.of(context), theme = Theme.of(context);
    return WalletDataView(
      builder: (wallets) {
        final data = ref.watch(transactionsProvider);
        return data.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Column(
            children: [
              Text(s.error(e)),
              TextButton(
                onPressed: () => ref.invalidate(transactionsProvider),
                child: Text(s('retry')),
              ),
            ],
          ),
          data: (all) {
            final byId = {for (final w in wallets) w.wallet.id: w};
            final invalidDate =
                (from.text.isNotEmpty && !validTransactionDate(from.text)) ||
                (to.text.isNotEmpty && !validTransactionDate(to.text));
            final invalidRange =
                !invalidDate &&
                from.text.isNotEmpty &&
                to.text.isNotEmpty &&
                from.text.compareTo(to.text) > 0;
            final query = TransactionQuery(
              search: search.text,
              kind: type == 'all' ? null : TransactionKind.values.byName(type),
              walletId: walletId == 'all' ? null : walletId,
              category: category == 'all' ? null : category,
              from: from.text.isEmpty ? null : from.text,
              to: to.text.isEmpty ? null : to.text,
              deleted: status == 'all' ? null : status == 'cancelled',
            );
            final visible = invalidDate || invalidRange
                ? <FinancialTransaction>[]
                : all
                      .where(
                        (t) => query.matches(
                          t,
                          walletName: byId[t.walletId]?.wallet.name ?? '',
                          categoryName: s(t.draft.category),
                        ),
                      )
                      .toList();
            Widget dropdown(
              String label,
              String value,
              List<(String, String)> choices,
              void Function(String) changed,
            ) => SizedBox(
              width: 210,
              child: DropdownButtonFormField<String>(
                key: ValueKey('$label/$value'),
                initialValue: value,
                isExpanded: true,
                decoration: InputDecoration(labelText: label),
                items: [
                  for (final c in choices)
                    DropdownMenuItem(value: c.$1, child: Text(c.$2)),
                ],
                onChanged: (v) => setState(() => changed(v!)),
              ),
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s('title'), style: theme.textTheme.headlineLarge),
                const SizedBox(height: 8),
                Text(s('subtitle')),
                const SizedBox(height: 24),
                WalletButton(
                  key: const ValueKey('transaction-add'),
                  label: s('add'),
                  icon: Icons.add,
                  onPressed: wallets.any((w) => !w.wallet.archived)
                      ? () => showTransactionEditor(context, wallets)
                      : null,
                ),
                if (!wallets.any((w) => !w.wallet.archived)) ...[
                  const SizedBox(height: 12),
                  Text(s('needWallet')),
                  TextButton(
                    onPressed: () => context.go('/wallets'),
                    child: Text(s('openWallets')),
                  ),
                ],
                const SizedBox(height: 24),
                WalletTextField(
                  key: const ValueKey('transaction-search'),
                  label: s('search'),
                  controller: search,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    dropdown(s('allTypes'), type, [
                      ('all', s('allTypes')),
                      for (final k in TransactionKind.values)
                        (k.name, s(k.name)),
                    ], (v) => type = v),
                    dropdown(s('allWallets'), walletId, [
                      ('all', s('allWallets')),
                      for (final w in wallets) (w.wallet.id, w.wallet.name),
                    ], (v) => walletId = v),
                    dropdown(s('allCategories'), category, [
                      ('all', s('allCategories')),
                      for (final c in [
                        ...incomeCategories,
                        ...expenseCategories,
                      ])
                        (c, s(c)),
                    ], (v) => category = v),
                    dropdown(s('allStatus'), status, [
                      ('active', s('active')),
                      ('cancelled', s('deleted')),
                      ('all', s('allStatus')),
                    ], (v) => status = v),
                    SizedBox(
                      width: 210,
                      child: WalletTextField(
                        label: '${s('from')} (YYYY-MM-DD)',
                        controller: from,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    SizedBox(
                      width: 210,
                      child: WalletTextField(
                        label: '${s('to')} (YYYY-MM-DD)',
                        controller: to,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(() {
                        search.clear();
                        from.clear();
                        to.clear();
                        type = walletId = category = 'all';
                        status = 'active';
                      }),
                      icon: const Icon(Icons.filter_alt_off_outlined),
                      label: Text(s('reset')),
                    ),
                  ],
                ),
                if (invalidDate || invalidRange) ...[
                  const SizedBox(height: 12),
                  Text(
                    s(invalidDate ? 'error-date' : 'error-range'),
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
                const SizedBox(height: 24),
                if (visible.isEmpty)
                  WalletCard(
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 40,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            s(all.isEmpty ? 'empty' : 'noResults'),
                            style: theme.textTheme.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                          if (all.isEmpty) ...[
                            const SizedBox(height: 8),
                            Text(s('emptyBody'), textAlign: TextAlign.center),
                          ],
                        ],
                      ),
                    ),
                  ),
                for (final t in visible) ...[
                  TransactionRow(
                    key: ValueKey(t.id),
                    transaction: t,
                    wallets: wallets,
                  ),
                  const SizedBox(height: 14),
                ],
              ],
            );
          },
        );
      },
    );
  }
}
