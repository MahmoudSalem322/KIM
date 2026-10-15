import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/money.dart';
import '../../savings/presentation/savings_copy.dart';
import '../../../shared/design_system/components.dart';
import '../../budgets/presentation/budget_alerts.dart';
import '../../transactions/domain/financial_transaction.dart';
import '../../transactions/presentation/transaction_editor.dart';
import '../../transactions/presentation/transaction_providers.dart';
import '../../transfers/domain/wallet_transfer.dart';
import '../../transfers/presentation/transfer_editor.dart';
import '../../transfers/presentation/transfer_providers.dart';
import '../../wallets/domain/wallet.dart';
import '../../wallets/presentation/wallet_providers.dart';
import '../domain/dashboard_summary.dart';
import 'dashboard_charts.dart';
import 'dashboard_copy.dart';
import 'dashboard_wallet_overview.dart';
import 'dashboard_transactions.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});
  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  String preset = 'month';
  DashboardPeriod? custom;
  Currency? selectedCurrency;
  final periodField = GlobalKey<FormFieldState<String>>();

  @override
  Widget build(BuildContext context) {
    final wallets = ref.watch(walletsProvider);
    final transactions = ref.watch(transactionsProvider);
    final transfers = ref.watch(transfersProvider);
    final s = DashboardCopy.of(context);
    // Never use retained snapshots while privacy flags are reloading.
    if (wallets.isLoading || transactions.isLoading || transfers.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (wallets.hasError || transactions.hasError || transfers.hasError) {
      return WalletCard(
        child: Column(
          children: [
            Text(s('error')),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                ref.invalidate(walletsProvider);
                ref.invalidate(transactionsProvider);
                ref.invalidate(transfersProvider);
              },
              child: Text(s('retry')),
            ),
          ],
        ),
      );
    }
    return overview(
      wallets.requireValue,
      transactions.requireValue,
      transfers.requireValue,
    );
  }

  Widget overview(
    List<WalletSnapshot> wallets,
    List<FinancialTransaction> transactions,
    List<WalletTransfer> transfers,
  ) {
    final s = DashboardCopy.of(context), theme = Theme.of(context);
    final currencies = {for (final w in wallets) w.wallet.currency}.toList()
      ..sort(
        (a, b) => '${a.code}/${a.scale}'.compareTo('${b.code}/${b.scale}'),
      );
    final currency = currencies.contains(selectedCurrency)
        ? selectedCurrency!
        : currencies.firstOrNull ?? Currency('ILS', 2);
    final period = preset == 'custom' && custom != null
        ? custom!
        : DashboardPeriod.preset(preset, DateTime.now());
    final data = DashboardSummary(
      wallets: wallets,
      transactions: transactions,
      currency: currency,
      period: period,
    );
    final active = wallets.where((w) => !w.wallet.archived).toList();
    return Column(
      key: const ValueKey('dashboard-page'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s('title'), style: theme.textTheme.headlineLarge),
        const SizedBox(height: 8),
        Text(
          s('subtitle'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
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
              key: const ValueKey('dashboard-income'),
              onPressed: active.isEmpty
                  ? null
                  : () => showTransactionEditor(
                      context,
                      wallets,
                      initialKind: TransactionKind.income,
                    ),
              icon: const Icon(Icons.south_west_rounded),
              label: Text(s('addIncome')),
            ),
            OutlinedButton.icon(
              key: const ValueKey('dashboard-expense'),
              onPressed: active.isEmpty
                  ? null
                  : () => showTransactionEditor(context, wallets),
              icon: const Icon(Icons.north_east_rounded),
              label: Text(s('addExpense')),
            ),
            OutlinedButton.icon(
              key: const ValueKey('dashboard-transfer'),
              onPressed: active.length < 2
                  ? null
                  : () => showTransferEditor(context, wallets),
              icon: const Icon(Icons.swap_horiz_rounded),
              label: Text(s('transfer')),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (wallets.isEmpty)
          WalletCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ChartEmpty(
                  icon: Icons.account_balance_wallet_outlined,
                  title: s('emptyTitle'),
                  body: s('emptyBody'),
                ),
                FilledButton.icon(
                  onPressed: () => context.go('/wallets'),
                  icon: const Icon(Icons.add),
                  label: Text(s('create')),
                ),
              ],
            ),
          ),
        if (wallets.isNotEmpty) ...[
          Wrap(
            spacing: 16,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                key: ValueKey('dashboard-period-$preset'),
                width: 210,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  key: periodField,
                  initialValue: preset,
                  decoration: InputDecoration(labelText: s('period')),
                  items: [
                    for (final p in [
                      'month',
                      'lastMonth',
                      'week',
                      'year',
                      'custom',
                    ])
                      DropdownMenuItem(value: p, child: Text(s(p))),
                  ],
                  onChanged: (value) async {
                    if (value == null) return;
                    if (value == 'custom') {
                      final range = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(1900),
                        lastDate: DateTime(2100, 12, 31),
                        initialDateRange: DateTimeRange(
                          start: period.start,
                          end: period.end,
                        ),
                        helpText: s('range'),
                      );
                      if (!mounted) return;
                      if (range == null) {
                        periodField.currentState?.didChange(preset);
                        return;
                      }
                      setState(() {
                        preset = 'custom';
                        custom = DashboardPeriod(range.start, range.end);
                      });
                    } else {
                      setState(() => preset = value);
                    }
                  },
                ),
              ),
              SizedBox(
                width: 240,
                child: DropdownButtonFormField<Currency>(
                  isExpanded: true,
                  key: ValueKey(
                    'dashboard-currency-${currency.code}-${currency.scale}',
                  ),
                  initialValue: currency,
                  decoration: InputDecoration(labelText: s('currency')),
                  items: [
                    for (final c in currencies)
                      DropdownMenuItem(
                        value: c,
                        child: Text(
                          '${c.code} · ${c.scale} ${s('precision')}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => selectedCurrency = value),
                ),
              ),
              Text(
                '${period.from} — ${period.to}',
                textDirection: TextDirection.ltr,
                style: theme.textTheme.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(s('scope'), style: theme.textTheme.bodySmall),
          if (data.excludedCurrencies.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              key: const ValueKey('dashboard-incomplete'),
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                '${s('partial')} (${data.excludedCurrencies.map((c) => '${c.code}/${c.scale}').join(', ')})',
                style: TextStyle(color: theme.colorScheme.onTertiaryContainer),
              ),
            ),
          ],
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, bounds) {
              final columns = bounds.maxWidth >= 1050
                  ? 4
                  : bounds.maxWidth >= 560
                  ? 2
                  : 1;
              final width = (bounds.maxWidth - (columns - 1) * 16) / columns;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final item in [
                    (
                      'balance',
                      data.balance,
                      Icons.account_balance_wallet_outlined,
                      theme.colorScheme.primary,
                    ),
                    (
                      'income',
                      data.income,
                      Icons.south_west_rounded,
                      dashboardIncomeColor,
                    ),
                    (
                      'expense',
                      data.expense,
                      Icons.north_east_rounded,
                      dashboardExpenseColor,
                    ),
                    (
                      'net',
                      data.net,
                      Icons.waterfall_chart_rounded,
                      theme.colorScheme.primary,
                    ),
                  ])
                    SizedBox(
                      width: width,
                      child: _Metric(
                        label: s(item.$1),
                        value: data.concealed
                            ? '••••••'
                            : dashboardAmount(item.$2),
                        note: s(
                          item.$1 == 'balance' ? 'balanceNote' : 'flowNote',
                        ),
                        icon: item.$3,
                        color: item.$4,
                        hero: item.$1 == 'balance',
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 22),
          const BudgetAlerts(),
          if (data.concealed)
            WalletCard(
              child: ChartEmpty(
                icon: Icons.visibility_off_outlined,
                title: s('hidden'),
                body: '',
              ),
            )
          else
            DashboardCharts(summary: data),
          const SizedBox(height: 28),
          DashboardWalletOverview(wallets: active),
          const SizedBox(height: 28),
          DashboardTransactions(
            wallets: wallets,
            transactions: transactions,
            transfers: transfers,
            period: period,
            currency: currency,
          ),
        ],
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.note,
    required this.icon,
    required this.color,
    required this.hero,
  });
  final String label, value, note;
  final IconData icon;
  final Color color;
  final bool hero;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 210),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: hero ? null : theme.colorScheme.surface,
        border: hero
            ? null
            : Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: .4),
              ),
        gradient: hero
            ? const LinearGradient(
                colors: [Color(0xFF183B43), Color(0xFF0C252D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: hero ? const Color(0xFF9AEACD) : color, size: 25),
          const SizedBox(height: 20),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: hero ? Colors.white70 : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                value,
                textDirection: TextDirection.ltr,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: hero ? Colors.white : null,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            note,
            style: theme.textTheme.bodySmall?.copyWith(
              color: hero ? Colors.white70 : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
