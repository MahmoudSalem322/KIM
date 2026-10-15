import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/design_system/components.dart';
import '../../../shared/widgets/operation_action.dart';
import '../../wallets/domain/wallet.dart';
import '../../wallets/presentation/wallet_providers.dart';
import '../domain/debt.dart';
import 'debt_copy.dart';
import 'debt_editor.dart';
import 'debt_providers.dart';

class DebtsPage extends ConsumerStatefulWidget {
  const DebtsPage({super.key});
  @override
  ConsumerState<DebtsPage> createState() => _DebtsPageState();
}

class _DebtsPageState extends ConsumerState<DebtsPage> {
  DebtDirection direction = DebtDirection.lent;
  DebtStatus? status;
  @override
  Widget build(BuildContext context) {
    final s = DebtCopy.of(context),
        theme = Theme.of(context),
        debts = ref.watch(debtsProvider),
        wallets = ref.watch(walletsProvider);
    final loading = debts.isLoading || wallets.isLoading,
        error = debts.hasError || wallets.hasError;
    final all = loading || error ? <DebtSnapshot>[] : debts.requireValue,
        ws = loading || error ? <WalletSnapshot>[] : wallets.requireValue;
    final list = all
        .where(
          (d) =>
              d.debt.draft.direction == direction &&
              (status == null ||
                  !d.concealed(ws) && d.status(DateTime.now()) == status),
        )
        .toList();
    return Column(
      key: const ValueKey('debts-page'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s('title'), style: theme.textTheme.headlineLarge),
        const SizedBox(height: 8),
        Text(s('subtitle')),
        const SizedBox(height: 22),
        FilledButton.icon(
          key: const ValueKey('debt-add'),
          onPressed: () => showDebtEditor(context),
          icon: const Icon(Icons.add),
          label: Text(s('add')),
        ),
        const SizedBox(height: 18),
        Text(s('adminHint')),
        const SizedBox(height: 12),
        Text(s('totalsHint'), style: theme.textTheme.bodySmall),
        const SizedBox(height: 22),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final d in DebtDirection.values)
              ChoiceChip(
                label: Text(s(d.name)),
                selected: direction == d,
                onSelected: (_) => setState(() => direction = d),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: Text(s('all')),
              selected: status == null,
              onSelected: (_) => setState(() => status = null),
            ),
            for (final st in DebtStatus.values)
              ChoiceChip(
                label: Text(s(st.name)),
                selected: status == st,
                onSelected: (_) => setState(() => status = st),
              ),
          ],
        ),
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
                    ref.invalidate(debtsProvider);
                    ref.invalidate(walletsProvider);
                  },
                  child: Text(s('retry')),
                ),
              ],
            ),
          )
        else if (list.isEmpty)
          WalletCard(
            child: SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  Icon(
                    Icons.handshake_outlined,
                    size: 52,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(s('empty'), style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(s('emptyBody'), textAlign: TextAlign.center),
                ],
              ),
            ),
          )
        else
          for (final d in list) ...[
            _DebtCard(snapshot: d, wallets: ws),
            const SizedBox(height: 18),
          ],
      ],
    );
  }
}

class _DebtCard extends ConsumerWidget {
  const _DebtCard({required this.snapshot, required this.wallets});
  final DebtSnapshot snapshot;
  final List<WalletSnapshot> wallets;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = DebtCopy.of(context),
        d = snapshot.debt,
        theme = Theme.of(context),
        hidden = snapshot.concealed(wallets),
        status = snapshot.status(DateTime.now());
    final color = status == DebtStatus.overdue
        ? theme.colorScheme.error
        : theme.colorScheme.primary;
    final byId = {for (final w in wallets) w.wallet.id: w};
    String money(String value) => '$value ${d.draft.principal.currency.code}';
    return WalletCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: .12),
                child: Icon(
                  d.draft.direction == DebtDirection.lent
                      ? Icons.call_made_rounded
                      : Icons.call_received_rounded,
                  color: color,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(d.draft.person, style: theme.textTheme.titleLarge),
              ),
              if (!hidden) Chip(label: Text(s(status.name))),
            ],
          ),
          const SizedBox(height: 12),
          Text('${s('due')}: ${d.draft.dueOn}'),
          if (d.draft.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(d.draft.notes),
          ],
          const SizedBox(height: 20),
          if (hidden)
            Text(s('privacy'))
          else ...[
            Wrap(
              spacing: 26,
              runSpacing: 12,
              children: [
                for (final item in [
                  (s('principal'), d.draft.principal.decimal),
                  (s('paid'), snapshot.paid.decimal),
                  (s('remaining'), snapshot.remaining.decimal),
                ])
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.$1, style: theme.textTheme.bodySmall),
                      Text(
                        money(item.$2),
                        textDirection: TextDirection.ltr,
                        style: theme.textTheme.titleLarge,
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Semantics(
              container: true,
              explicitChildNodes: true,
              child: LinearProgressIndicator(
                value: snapshot.progress,
                color: color,
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: hidden || status == DebtStatus.settled
                    ? null
                    : () => showDebtEditor(
                        context,
                        debt: snapshot,
                        kind: DebtEventKind.payment,
                        wallets: wallets,
                      ),
                icon: const Icon(Icons.payments_outlined),
                label: Text(s('payment')),
              ),
              TextButton(
                onPressed: hidden
                    ? null
                    : () => showDebtEditor(
                        context,
                        debt: snapshot,
                        wallets: wallets,
                      ),
                child: Text(s('edit')),
              ),
              OutlinedButton(
                onPressed: hidden || snapshot.principalRecorded
                    ? null
                    : () => showDebtEditor(
                        context,
                        debt: snapshot,
                        kind: DebtEventKind.principal,
                        wallets: wallets,
                      ),
                child: Text(
                  s(
                    snapshot.principalRecorded
                        ? 'principalRecorded'
                        : 'principalCash',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Semantics(
            container: true,
            explicitChildNodes: true,
            child: ExpansionTile(
              internalAddSemanticForOnTap: true,
              tilePadding: EdgeInsets.zero,
              title: Text(s('history')),
              children: [
                if (snapshot.events.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(s('historyEmpty')),
                  ),
                for (final e in snapshot.events)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${s(e.draft.kind == DebtEventKind.payment ? 'paymentEvent' : 'principalEvent')} · ${e.draft.date}${e.cancelled ? ' · ${s('cancelled')}' : ''}',
                          style: theme.textTheme.titleSmall,
                        ),
                        Text(byId[e.draft.walletId]?.wallet.name ?? '—'),
                        if (!hidden)
                          Text(
                            '${e.draft.effect(d.draft.direction).decimal} ${e.draft.amount.currency.code}',
                            textDirection: TextDirection.ltr,
                          ),
                        if (e.draft.note.isNotEmpty) Text(e.draft.note),
                        if (!e.cancelled)
                          Wrap(
                            spacing: 8,
                            children: [
                              TextButton(
                                onPressed: hidden
                                    ? null
                                    : () => showDebtEditor(
                                        context,
                                        debt: snapshot,
                                        kind: e.draft.kind,
                                        event: e,
                                        wallets: wallets,
                                      ),
                                child: Text(s('editCash')),
                              ),
                              OperationAction(
                                key: ValueKey(
                                  'debt-cancel-${e.id}-${e.revision}-${d.revision}',
                                ),
                                enabled: !hidden,
                                label: s('cancelCash'),
                                cancelLabel: s('cancel'),
                                confirm: s('cancelHint'),
                                errorText: s.error,
                                run: (op) =>
                                    ref.read(debtRepositoryProvider).cancelCash(
                                      op,
                                      e.id,
                                      e.revision,
                                      d.revision,
                                      {
                                        for (final w in wallets)
                                          w.wallet.id: w.wallet.revision,
                                      },
                                    ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
