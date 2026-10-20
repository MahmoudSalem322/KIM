import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/design_system/components.dart';
import '../../../shared/widgets/operation_action.dart';
import '../../transactions/domain/financial_transaction.dart';
import '../../transactions/presentation/transaction_providers.dart';
import '../../wallets/presentation/wallet_providers.dart';
import '../domain/recurring_payment.dart';
import 'recurring_copy.dart';
import 'recurring_editor.dart';
import 'recurring_providers.dart';

class RecurringPage extends ConsumerStatefulWidget {
  const RecurringPage({super.key});
  @override
  ConsumerState<RecurringPage> createState() => _RecurringPageState();
}

class _RecurringPageState extends ConsumerState<RecurringPage> {
  late DateTime month = ref.read(appClockProvider)();
  String? selectedDate;
  RecurringStatus? filter;
  @override
  Widget build(BuildContext context) {
    final s = RecurringCopy.of(context),
        theme = Theme.of(context),
        plans = ref.watch(recurringPaymentsProvider),
        wallets = ref.watch(walletsProvider),
        occurrences = ref.watch(recurringOccurrencesProvider),
        transactions = ref.watch(transactionsProvider),
        processing = ref.watch(processingProvider),
        today = calendarDate(ref.watch(appClockProvider)());
    final loading =
            plans.isLoading ||
            wallets.isLoading ||
            occurrences.isLoading ||
            transactions.isLoading,
        error =
            plans.hasError ||
            wallets.hasError ||
            occurrences.hasError ||
            transactions.hasError;
    final all = loading || error ? <RecurringPayment>[] : plans.requireValue,
        ws = loading || error
            ? {}
            : {for (final w in wallets.requireValue) w.wallet.id: w};
    final from = calendarDate(DateTime(month.year, month.month)),
        to = calendarDate(DateTime(month.year, month.month + 1, 0));
    final forecast = <String, int>{};
    for (final p in all.where(
      (p) => ws[p.draft.walletId]?.wallet.hidden == false,
    )) {
      for (final date in p.datesIn(from, to)) {
        forecast[date] = (forecast[date] ?? 0) + 1;
      }
    }
    final visible = all
        .where(
          (p) =>
              (filter == null || p.status == filter) &&
              (selectedDate == null ||
                  p.datesIn(selectedDate!, selectedDate!).isNotEmpty),
        )
        .toList();
    return Column(
      key: const ValueKey('recurring-page'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s('title'), style: theme.textTheme.headlineLarge),
        const SizedBox(height: 8),
        Text(s('subtitle')),
        const SizedBox(height: 22),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              key: const ValueKey('recurring-add'),
              onPressed: () => showRecurringEditor(context),
              icon: const Icon(Icons.add),
              label: Text(s('add')),
            ),
            OutlinedButton.icon(
              onPressed: processing.isLoading
                  ? null
                  : () => ref.read(processingProvider.notifier).run(),
              icon: const Icon(Icons.sync),
              label: Text(s(processing.isLoading ? 'processing' : 'process')),
            ),
            TextButton.icon(
              onPressed: () => context.go('/notifications'),
              icon: const Icon(Icons.notifications_outlined),
              label: Text(s('notifications')),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(s('webHint'), style: theme.textTheme.bodySmall),
        if (processing.hasError)
          Text(s('error'), style: TextStyle(color: theme.colorScheme.error)),
        if (!processing.isLoading && processing.value != null) ...[
          const SizedBox(height: 12),
          Text(
            '${processing.value!.recorded} ${s('processed')} · ${processing.value!.blocked} ${s('blockedCount')}',
          ),
          if (processing.value!.more) Text(s('more')),
        ],
        const SizedBox(height: 24),
        if (loading)
          const Center(child: CircularProgressIndicator())
        else if (error)
          WalletCard(
            child: Column(
              children: [
                Text(s('error')),
                TextButton(
                  onPressed: () {
                    ref.invalidate(recurringPaymentsProvider);
                    ref.invalidate(recurringOccurrencesProvider);
                    ref.invalidate(walletsProvider);
                    ref.invalidate(transactionsProvider);
                  },
                  child: Text(s('retry')),
                ),
              ],
            ),
          )
        else ...[
          WalletCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s('calendar'), style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(s('calendarHint'), style: theme.textTheme.bodySmall),
                Row(
                  children: [
                    IconButton(
                      tooltip: s('previous'),
                      onPressed: month.year == 1900 && month.month == 1
                          ? null
                          : () => setState(
                              () =>
                                  month = DateTime(month.year, month.month - 1),
                            ),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Text(
                        MaterialLocalizations.of(context)
                            .formatMonthYear(month),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: s('nextMonth'),
                      onPressed: month.year == 2100 && month.month == 12
                          ? null
                          : () => setState(
                              () =>
                                  month = DateTime(month.year, month.month + 1),
                            ),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                Row(
                  children: [
                    for (final day in MaterialLocalizations.of(
                      context,
                    ).narrowWeekdays)
                      Expanded(child: Text(day, textAlign: TextAlign.center)),
                  ],
                ),
                const SizedBox(height: 6),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisExtent: 64,
                  ),
                  itemCount:
                      DateTime(month.year, month.month, 1).weekday % 7 +
                      DateTime(month.year, month.month + 1, 0).day,
                  itemBuilder: (context, i) {
                    final day =
                        i -
                        DateTime(month.year, month.month, 1).weekday % 7 +
                        1;
                    if (day < 1) return const SizedBox.shrink();
                    final date = calendarDate(
                          DateTime(month.year, month.month, day),
                        ),
                        count = forecast[date] ?? 0;
                    return Tooltip(
                      message: date,
                      child: TextButton(
                        key: ValueKey('calendar-$date'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          backgroundColor: selectedDate == date
                              ? theme.colorScheme.primaryContainer
                              : null,
                        ),
                        onPressed: () => setState(() => selectedDate = date),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('$day'),
                            if (count > 0)
                              Text(
                                '• $count',
                                style: theme.textTheme.labelSmall,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                if (selectedDate != null)
                  TextButton(
                    onPressed: () => setState(() => selectedDate = null),
                    child: Text('${s('clearDate')} · $selectedDate'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text(s('all')),
                selected: filter == null,
                onSelected: (_) => setState(() => filter = null),
              ),
              for (final status in RecurringStatus.values)
                ChoiceChip(
                  label: Text(s(status.name)),
                  selected: filter == status,
                  onSelected: (_) => setState(() => filter = status),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (visible.isEmpty)
            WalletCard(
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  children: [
                    Icon(
                      Icons.event_repeat_rounded,
                      size: 48,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(s('empty'), style: theme.textTheme.titleLarge),
                    const SizedBox(height: 10),
                    Text(s('emptyBody'), textAlign: TextAlign.center),
                  ],
                ),
              ),
            )
          else
            for (final p in visible) ...[
              Builder(
                builder: (context) {
                  final history =
                      occurrences.requireValue
                          .where((o) => o.scheduleId == p.id)
                          .toList()
                        ..sort((a, b) => b.date.compareTo(a.date));
                  final tx = {
                    for (final t in transactions.requireValue) t.id: t,
                  };
                  final hidden =
                      ws[p.draft.walletId]?.wallet.hidden != false ||
                      history.any(
                        (o) =>
                            tx[o.transactionId] != null &&
                            ws[tx[o.transactionId]!.walletId]?.wallet.hidden !=
                                false,
                      );
                  final mutable =
                      p.status == RecurringStatus.active ||
                      p.status == RecurringStatus.paused;
                  return WalletCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.event_repeat_rounded,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                p.draft.name,
                                style: theme.textTheme.titleLarge,
                              ),
                            ),
                            Chip(label: Text(s(p.status.name))),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (hidden)
                          Text(s('hidden'))
                        else ...[
                          Text(
                            '${p.draft.amount.decimal} ${p.draft.amount.currency.code}',
                            textDirection: TextDirection.ltr,
                            style: theme.textTheme.headlineMedium,
                          ),
                          Text(
                            '${ws[p.draft.walletId]?.wallet.name ?? '—'} · ${s(p.draft.cycle.name)}',
                          ),
                          Text('${s('next')}: ${p.draft.nextDate}'),
                          if (p.lastPaidDate.isNotEmpty)
                            Text('${s('lastPaid')}: ${p.lastPaidDate}'),
                          if (p.lastError.isNotEmpty)
                            Text(
                              s('error-${p.lastError}'),
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          s(p.draft.automatic ? 'automatic' : 'reminderOnly'),
                          style: theme.textTheme.bodySmall,
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (mutable)
                              TextButton(
                                onPressed: hidden
                                    ? null
                                    : () => showRecurringEditor(
                                        context,
                                        payment: p,
                                      ),
                                child: Text(s('edit')),
                              ),
                            if (mutable)
                              OperationAction(
                                key: ValueKey('status-${p.id}-${p.revision}'),
                                label: s(
                                  p.status == RecurringStatus.active
                                      ? 'pause'
                                      : 'resume',
                                ),
                                cancelLabel: s('cancel'),
                                confirm: p.status == RecurringStatus.paused
                                    ? s('resumeHint')
                                    : null,
                                errorText: s.error,
                                run: (op) => ref
                                    .read(recurringRepositoryProvider)
                                    .setStatus(
                                      op,
                                      p.id,
                                      p.revision,
                                      p.status == RecurringStatus.active
                                          ? RecurringStatus.paused
                                          : RecurringStatus.active,
                                    ),
                              ),
                            if (mutable)
                              OperationAction(
                                key: ValueKey('cancel-${p.id}-${p.revision}'),
                                label: s('cancelPlan'),
                                cancelLabel: s('cancel'),
                                confirm: s('cancelHint'),
                                errorText: s.error,
                                run: (op) => ref
                                    .read(recurringRepositoryProvider)
                                    .setStatus(
                                      op,
                                      p.id,
                                      p.revision,
                                      RecurringStatus.cancelled,
                                    ),
                              ),
                            if (p.status == RecurringStatus.active)
                              OperationAction(
                                key: ValueKey('pay-${p.id}-${p.revision}'),
                                enabled:
                                    !hidden &&
                                    p.draft.nextDate.compareTo(today) <= 0,
                                label: s('pay'),
                                cancelLabel: s('cancel'),
                                confirm: s('payHint'),
                                errorText: s.error,
                                run: (op) => ref
                                    .read(recurringRepositoryProvider)
                                    .payNext(
                                      op,
                                      p.id,
                                      p.revision,
                                      ref.read(appClockProvider)(),
                                    ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Semantics(
                          container: true,
                          explicitChildNodes: true,
                          child: ExpansionTile(
                            internalAddSemanticForOnTap: true,
                            tilePadding: EdgeInsets.zero,
                            title: Text(s('history')),
                            children: [
                              if (history.isEmpty) Text(s('historyEmpty')),
                              if (!hidden)
                                for (final o in history)
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(o.date),
                                    subtitle: Text(o.transactionId),
                                    trailing:
                                        tx[o.transactionId]?.deleted == true
                                        ? Text(s('cancelled'))
                                        : null,
                                  ),
                              TextButton(
                                onPressed: () => context.go('/transactions'),
                                child: Text(s('viewExpense')),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),
            ],
        ],
      ],
    );
  }
}
