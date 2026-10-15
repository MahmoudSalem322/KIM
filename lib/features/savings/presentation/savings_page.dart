import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/money.dart';
import '../../../shared/design_system/components.dart';
import '../../../shared/widgets/operation_action.dart';
import '../../wallets/domain/wallet.dart';
import '../../wallets/presentation/wallet_copy.dart';
import '../../wallets/presentation/wallet_providers.dart';
import '../domain/savings_goal.dart';
import 'allocation_editor.dart';
import 'goal_editor.dart';
import 'savings_copy.dart';
import 'savings_providers.dart';

class SavingsPage extends ConsumerStatefulWidget {
  const SavingsPage({super.key});
  @override
  ConsumerState<SavingsPage> createState() => _SavingsPageState();
}

class _SavingsPageState extends ConsumerState<SavingsPage> {
  bool closed = false;
  @override
  Widget build(BuildContext context) {
    final s = SavingsCopy.of(context),
        theme = Theme.of(context),
        goals = ref.watch(savingsGoalsProvider),
        wallets = ref.watch(walletsProvider);
    final loading = goals.isLoading || wallets.isLoading,
        error = goals.hasError || wallets.hasError;
    final all = loading || error ? <GoalSnapshot>[] : goals.requireValue;
    final ws = loading || error ? <WalletSnapshot>[] : wallets.requireValue;
    final visible = all.where((g) => g.goal.closed == closed).toList();
    return Column(
      key: const ValueKey('savings-page'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF122C36), Color(0xFF155848)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.auto_awesome_outlined,
                color: Color(0xFF89D5BD),
                size: 32,
              ),
              const SizedBox(height: 16),
              Text(
                s('title'),
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                s('subtitle'),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: .8),
                ),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                key: const ValueKey('goal-add'),
                onPressed: () => showGoalEditor(context),
                icon: const Icon(Icons.add),
                label: Text(s('add')),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Text(s('reservationHint')),
        const SizedBox(height: 12),
        Text(s('transferHint'), style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => context.go('/transfers'),
          icon: const Icon(Icons.swap_horiz_rounded),
          label: Text(s('transfer')),
        ),
        const SizedBox(height: 20),
        if (loading)
          const Center(child: CircularProgressIndicator())
        else if (error)
          WalletCard(
            child: Column(
              children: [
                Text(s('error')),
                TextButton(
                  onPressed: () {
                    ref.invalidate(savingsGoalsProvider);
                    ref.invalidate(walletsProvider);
                  },
                  child: Text(s('retry')),
                ),
              ],
            ),
          )
        else ...[
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final item in [
                (
                  Icons.flag_outlined,
                  s('active'),
                  all.where((g) => !g.goal.closed).length,
                ),
                (
                  Icons.verified_outlined,
                  s('achieved'),
                  all.where((g) => g.achieved && !g.concealed(ws)).length,
                ),
                (
                  Icons.inventory_2_outlined,
                  s('closed'),
                  all.where((g) => g.goal.closed).length,
                ),
              ])
                SizedBox(
                  width: 210,
                  child: WalletCard(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Icon(item.$1, color: theme.colorScheme.primary),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.$2, style: theme.textTheme.labelLarge),
                              Text(
                                item.$2 == s('achieved') &&
                                        all.any((g) => g.concealed(ws))
                                    ? '••••'
                                    : '${item.$3}',
                                style: theme.textTheme.headlineMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          FilterChip(
            label: Text(s('showClosed')),
            selected: closed,
            onSelected: (v) => setState(() => closed = v),
          ),
          const SizedBox(height: 18),
          if (visible.isEmpty)
            WalletCard(
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  children: [
                    Icon(
                      Icons.savings_outlined,
                      size: 64,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      s(closed ? 'emptyClosed' : 'empty'),
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    if (!closed)
                      Text(s('emptyBody'), textAlign: TextAlign.center),
                  ],
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, box) {
                final width = box.maxWidth >= 850
                    ? (box.maxWidth - 20) / 2
                    : box.maxWidth;
                return Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  children: [
                    for (final g in visible)
                      SizedBox(
                        width: width,
                        child: _GoalCard(snapshot: g, all: all, wallets: ws),
                      ),
                  ],
                );
              },
            ),
          const SizedBox(height: 30),
          Text(s('availability'), style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(s('totalsHint'), style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),
          for (final w in ws.where((w) => !w.wallet.archived)) ...[
            WalletCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${w.wallet.name} · ${w.wallet.currency.code} / ${w.wallet.currency.scale}',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  if (w.wallet.hidden)
                    Text(s('hidden'))
                  else
                    Wrap(
                      spacing: 28,
                      runSpacing: 10,
                      children: [
                        _Amount(label: s('balance'), amount: w.balance),
                        _Amount(
                          label: s('reserved'),
                          amount: walletReservation(
                            w.wallet.id,
                            w.wallet.currency,
                            all,
                          ),
                        ),
                        _Amount(
                          label: s('available'),
                          amount:
                              w.balance -
                              walletReservation(
                                w.wallet.id,
                                w.wallet.currency,
                                all,
                              ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }
}

class _Amount extends StatelessWidget {
  const _Amount({required this.label, required this.amount});
  final String label;
  final Money amount;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 4),
      Text(
        '${amount.decimal} ${amount.currency.code}',
        textDirection: TextDirection.ltr,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    ],
  );
}

class _GoalCard extends ConsumerWidget {
  const _GoalCard({
    required this.snapshot,
    required this.all,
    required this.wallets,
  });
  final GoalSnapshot snapshot;
  final List<GoalSnapshot> all;
  final List<WalletSnapshot> wallets;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = snapshot.goal,
        d = g.draft,
        s = SavingsCopy.of(context),
        theme = Theme.of(context),
        color = walletColor(d.color);
    final hidden = snapshot.concealed(wallets),
        days = snapshot.daysRemaining(DateTime.now());
    return WalletCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(goalIcon(d.icon), color: color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.name, style: theme.textTheme.titleLarge),
                    Text(
                      d.dueOn,
                      style: theme.textTheme.bodySmall,
                      textDirection: TextDirection.ltr,
                    ),
                  ],
                ),
              ),
              if (!hidden && snapshot.achieved)
                Icon(Icons.verified_rounded, color: color),
            ],
          ),
          const SizedBox(height: 24),
          if (hidden)
            Text(s('hidden'))
          else ...[
            Text(
              snapshot.percentage,
              style: theme.textTheme.headlineLarge?.copyWith(color: color),
            ),
            const SizedBox(height: 12),
            Semantics(
              container: true,
              explicitChildNodes: true,
              child: LinearProgressIndicator(
                value: snapshot.progress,
                minHeight: 10,
                borderRadius: BorderRadius.circular(8),
                color: color,
                backgroundColor: color.withValues(alpha: .12),
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 28,
              runSpacing: 12,
              children: [
                _Amount(
                  label: s(g.closed ? 'closedSnapshot' : 'saved'),
                  amount: snapshot.displayed,
                ),
                _Amount(label: s('target'), amount: d.target),
                if (!g.closed)
                  _Amount(label: s('remaining'), amount: snapshot.remaining),
              ],
            ),
            const SizedBox(height: 16),
          ],
          Text(
            g.closed
                ? s('closed')
                : !hidden && snapshot.achieved
                ? s('funded')
                : days == 0
                ? s('today')
                : '${days.abs()} ${s(days < 0 ? 'overdue' : 'days')}',
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!g.closed)
                FilledButton.tonalIcon(
                  onPressed: hidden
                      ? null
                      : () => showAllocationEditor(
                          context,
                          snapshot,
                          all,
                          wallets,
                        ),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(s('allocate')),
                ),
              if (!g.closed)
                TextButton(
                  onPressed: hidden
                      ? null
                      : () => showGoalEditor(context, goal: g),
                  child: Text(s('edit')),
                ),
              TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => _History(id: g.id),
                ),
                child: Text(s('history')),
              ),
              if (!g.closed)
                OperationAction(
                  key: ValueKey('close-${g.id}-${g.revision}'),
                  label: s('closeGoal'),
                  cancelLabel: s('cancel'),
                  confirm: s('closeHint'),
                  errorText: s.error,
                  run: (op) => ref
                      .read(savingsRepositoryProvider)
                      .close(op, g.id, g.revision),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _History extends ConsumerWidget {
  const _History({required this.id});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = SavingsCopy.of(context),
        goals = ref.watch(savingsGoalsProvider),
        wallets = ref.watch(walletsProvider);
    final loading = goals.isLoading || wallets.isLoading,
        error = goals.hasError || wallets.hasError;
    final snapshot = loading || error
        ? null
        : goals.requireValue.where((g) => g.goal.id == id).firstOrNull;
    final ws = loading || error
        ? <String, WalletSnapshot>{}
        : {for (final w in wallets.requireValue) w.wallet.id: w};
    return AlertDialog(
      scrollable: true,
      title: Text(s('history')),
      content: SizedBox(
        width: 580,
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : error || snapshot == null
            ? Text(s('error'))
            : snapshot.events.isEmpty
            ? Text(s('historyEmpty'))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    snapshot.goal.draft.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  for (final e in snapshot.events)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${s(e.closing
                                ? 'closingEvent'
                                : e.delta.minorUnits.isNegative
                                ? 'releasedEvent'
                                : 'allocatedEvent')} · ${ws[e.walletId]?.wallet.name ?? '—'}',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Text(
                            ws[e.walletId]?.wallet.hidden != false
                                ? s('hidden')
                                : '${e.delta.decimal} ${e.delta.currency.code}',
                            textDirection: TextDirection.ltr,
                          ),
                          Text(
                            entryDate(context, e.at),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (e.note.isNotEmpty) Text(e.note),
                        ],
                      ),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s('done')),
        ),
      ],
    );
  }
}
