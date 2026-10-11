import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/money.dart';
import '../../../shared/design_system/components.dart';
import '../../wallets/domain/wallet.dart';
import '../domain/wallet_transfer.dart';
import 'transfer_copy.dart';
import 'transfer_editor.dart';
import 'transfer_providers.dart';

class TransferRow extends ConsumerStatefulWidget {
  const TransferRow({super.key, required this.transfer, required this.wallets});
  final WalletTransfer transfer;
  final List<WalletSnapshot> wallets;
  @override
  ConsumerState<TransferRow> createState() => _TransferRowState();
}

class _TransferRowState extends ConsumerState<TransferRow> {
  bool busy = false;
  String? fingerprint;
  WalletOperation? operation;
  Future<void> cancel() async {
    if (busy) return;
    final s = TransferCopy.of(context), t = widget.transfer;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s('cancel')),
        content: Text(s('cancelBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s('close')),
          ),
          FilledButton(
            key: const ValueKey('transfer-cancel-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(s('cancel')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || busy) return;
    final revisions = {
      for (final w in widget.wallets) w.wallet.id: w.wallet.revision,
    };
    final key =
        '${t.id}/${t.revision}/${revisions[t.draft.sourceId]}/${revisions[t.draft.destinationId]}';
    if (key != fingerprint) {
      fingerprint = key;
      operation = WalletOperation.generate();
    }
    setState(() => busy = true);
    try {
      await ref
          .read(transferRepositoryProvider)
          .cancel(operation!, t.id, t.revision, revisions);
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
    final s = TransferCopy.of(context),
        t = widget.transfer,
        d = t.draft,
        theme = Theme.of(context);
    final from = widget.wallets
        .where((w) => w.wallet.id == d.sourceId)
        .firstOrNull;
    final to = widget.wallets
        .where((w) => w.wallet.id == d.destinationId)
        .firstOrNull;
    final enabled =
        !busy &&
        !t.cancelled &&
        from != null &&
        to != null &&
        !from.wallet.archived &&
        !to.wallet.archived;
    String money(Money m, bool hidden) =>
        hidden ? s('hidden') : '${m.decimal} ${m.currency.code}';
    final sourceHidden = from?.wallet.hidden ?? true,
        destinationHidden = to?.wallet.hidden ?? true;
    // Either leg can reveal the other through the public quote, so mask together.
    final hidden = sourceHidden || destinationHidden;
    return WalletCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.swap_horiz_rounded,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${from?.wallet.name ?? '—'} → ${to?.wallet.name ?? '—'}',
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          StatusPill(
            label: s(t.cancelled ? 'cancelled' : 'active'),
            icon: t.cancelled ? Icons.undo_rounded : Icons.check_circle_outline,
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 32,
            runSpacing: 18,
            children: [
              _Amount(label: s('amount'), value: money(d.amount, hidden)),
              _Amount(label: s('received'), value: money(t.received, hidden)),
              _Amount(label: s('fee'), value: money(d.fee, hidden)),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '${s('rate')}: 1 ${d.amount.currency.code} = ${d.rate.decimal} ${t.received.currency.code}',
            textDirection: TextDirection.ltr,
          ),
          Text('${s('recorded')}: ${t.createdAt.toLocal().toIso8601String()}'),
          if (d.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(d.notes),
          ],
          const SizedBox(height: 16),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(s('id')),
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Semantics(
                  label: t.id,
                  child: ExcludeSemantics(child: SelectableText(t.id)),
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton.icon(
                key: const ValueKey('transfer-edit'),
                onPressed: enabled
                    ? () => showTransferEditor(
                        context,
                        widget.wallets,
                        transfer: t,
                      )
                    : null,
                icon: const Icon(Icons.edit_outlined),
                label: Text(s('edit')),
              ),
              TextButton.icon(
                key: const ValueKey('transfer-cancel'),
                onPressed: enabled ? cancel : null,
                icon: const Icon(Icons.undo_rounded),
                label: Text(s(busy ? 'saving' : 'cancel')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Amount extends StatelessWidget {
  const _Amount({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 6),
      Text(value, style: Theme.of(context).textTheme.titleMedium),
    ],
  );
}
