import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/money.dart';
import '../../../shared/design_system/components.dart';
import '../../wallets/domain/wallet.dart';
import '../../wallets/presentation/wallet_providers.dart';
import '../domain/exchange_rate.dart';
import '../domain/wallet_transfer.dart';
import 'transfer_copy.dart';
import 'transfer_providers.dart';

Future<void> showTransferEditor(
  BuildContext context,
  List<WalletSnapshot> wallets, {
  WalletTransfer? transfer,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => TransferEditor(wallets: wallets, transfer: transfer),
);

class TransferEditor extends ConsumerStatefulWidget {
  const TransferEditor({super.key, required this.wallets, this.transfer});
  final List<WalletSnapshot> wallets;
  final WalletTransfer? transfer;
  @override
  ConsumerState<TransferEditor> createState() => _TransferEditorState();
}

class _TransferEditorState extends ConsumerState<TransferEditor> {
  final form = GlobalKey<FormState>();
  late final choices = widget.wallets.where((w) => !w.wallet.archived).toList();
  late String sourceId =
      widget.transfer?.draft.sourceId ?? choices.first.wallet.id;
  late String destinationId =
      widget.transfer?.draft.destinationId ??
      choices.firstWhere((w) => w.wallet.id != sourceId).wallet.id;
  Wallet get source =>
      choices.singleWhere((w) => w.wallet.id == sourceId).wallet;
  Wallet get destination =>
      choices.singleWhere((w) => w.wallet.id == destinationId).wallet;
  late bool lastHidden = source.hidden || destination.hidden;
  late final amount = TextEditingController(
    text: lastHidden ? '' : widget.transfer?.draft.amount.decimal ?? '',
  );
  late final fee = TextEditingController(
    text: lastHidden ? '' : widget.transfer?.draft.fee.decimal ?? '0',
  );
  late final rate = TextEditingController(
    text:
        widget.transfer?.draft.rate.decimal ??
        (source.currency.code == destination.currency.code ? '1' : ''),
  );
  late final notes = TextEditingController(
    text: widget.transfer?.draft.notes ?? '',
  );
  late final revisions = {
    for (final w in widget.wallets) w.wallet.id: w.wallet.revision,
  };
  bool busy = false;
  String? error, fingerprint;
  WalletOperation? operation;
  TransferDraft get draft => TransferDraft(
    sourceId: sourceId,
    destinationId: destinationId,
    amount: Money.parse(amount.text, source.currency),
    fee: Money.parse(fee.text, source.currency),
    rate: ExchangeRate.parse(rate.text),
    notes: notes.text,
  );
  Money? get quote {
    try {
      return draft.quote(destination.currency);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    amount.dispose();
    fee.dispose();
    rate.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    TransferDraft payload;
    try {
      payload = draft;
      payload.quote(destination.currency);
    } catch (e) {
      setState(() => error = TransferCopy.of(context).error(e));
      return;
    }
    final key = jsonEncode(payload.toJson());
    if (key != fingerprint) {
      fingerprint = key;
      operation = WalletOperation.generate();
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final repo = ref.read(transferRepositoryProvider), t = widget.transfer;
      if (t == null) {
        await repo.create(operation!, payload, revisions);
      } else {
        await repo.edit(operation!, t.id, t.revision, payload, revisions);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = TransferCopy.of(context).error(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void changeWallet(bool from, String id) {
    setState(() {
      final previous = source.currency;
      if (from) {
        sourceId = id;
      } else {
        destinationId = id;
      }
      if (previous != source.currency) {
        amount.clear();
        fee.text = '0';
      }
      rate.text = source.currency.code == destination.currency.code ? '1' : '';
    });
  }

  void swapWallets() {
    setState(() {
      final previousCurrency = source.currency, oldSource = sourceId;
      sourceId = destinationId;
      destinationId = oldSource;
      if (previousCurrency != source.currency) {
        amount.clear();
        fee.text = '0';
      }
      rate.text = source.currency.code == destination.currency.code ? '1' : '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = TransferCopy.of(context), live = ref.watch(walletsProvider);
    final data = live.isLoading || live.hasError ? null : live.asData?.value;
    final from = data?.where((w) => w.wallet.id == sourceId).firstOrNull;
    final to = data?.where((w) => w.wallet.id == destinationId).firstOrNull;
    final hidden = (from?.wallet.hidden ?? true) || (to?.wallet.hidden ?? true);
    if (hidden && !lastHidden) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            amount.clear();
            fee.clear();
          });
        }
      });
    }
    lastHidden = hidden;
    final received = quote;
    String? checkMoney(String? value, bool fees) {
      try {
        final m = Money.parse(value ?? '', source.currency);
        return (fees ? m.minorUnits < BigInt.zero : m.minorUnits <= BigInt.zero)
            ? s('error-amount')
            : null;
      } catch (_) {
        return s('error-amount');
      }
    }

    Widget choose(bool from) => DropdownButtonFormField<String>(
      key: ValueKey(
        '${from ? 'from' : 'to'}-${from ? sourceId : destinationId}',
      ),
      initialValue: from ? sourceId : destinationId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: s(from ? 'source' : 'destination'),
      ),
      items: [
        for (final w in choices.where(
          (w) => w.wallet.id != (from ? destinationId : sourceId),
        ))
          DropdownMenuItem(
            value: w.wallet.id,
            child: Text(
              '${w.wallet.name} · ${w.wallet.currency.code}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: busy
          ? null
          : (v) {
              if (v != null) changeWallet(from, v);
            },
    );
    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        scrollable: true,
        title: Text(s(widget.transfer == null ? 'add' : 'edit')),
        content: SizedBox(
          width: 520,
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                choose(true),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    key: const ValueKey('transfer-swap'),
                    onPressed: busy ? null : swapWallets,
                    icon: const Icon(Icons.swap_vert_rounded),
                    label: Text(s('swap')),
                  ),
                ),
                const SizedBox(height: 18),
                choose(false),
                const SizedBox(height: 20),
                WalletTextField(
                  key: const ValueKey('transfer-amount'),
                  label: '${s('amount')} (${source.currency.code})',
                  controller: amount,
                  enabled: !busy,
                  obscureText: hidden,
                  onChanged: (_) => setState(() {}),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) => checkMoney(v, false),
                ),
                const SizedBox(height: 18),
                WalletTextField(
                  key: const ValueKey('transfer-fee'),
                  label: '${s('fee')} (${source.currency.code})',
                  controller: fee,
                  enabled: !busy,
                  obscureText: hidden,
                  onChanged: (_) => setState(() {}),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) => checkMoney(v, true),
                ),
                const SizedBox(height: 8),
                Text(
                  s('feeHelp'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 18),
                WalletTextField(
                  key: const ValueKey('transfer-rate'),
                  label:
                      '${s('rate')} (${source.currency.code} / ${destination.currency.code})',
                  controller: rate,
                  enabled:
                      !busy &&
                      source.currency.code != destination.currency.code,
                  onChanged: (_) => setState(() {}),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) {
                    try {
                      ExchangeRate.parse(v ?? '');
                      return null;
                    } catch (_) {
                      return s('error-rate');
                    }
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  s('quoteHelp'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 20),
                WalletCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s('received'),
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        hidden
                            ? s('hidden')
                            : received == null
                            ? '—'
                            : '${received.decimal} ${destination.currency.code}',
                        style: Theme.of(context).textTheme.titleLarge,
                        textDirection: hidden ? null : TextDirection.ltr,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${s('total')}: ${hidden
                            ? s('hidden')
                            : received == null
                            ? '—'
                            : '${(draft.amount + draft.fee).decimal} ${source.currency.code}'}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                WalletTextField(
                  key: const ValueKey('transfer-notes'),
                  label: s('notes'),
                  controller: notes,
                  enabled: !busy,
                  validator: (v) =>
                      (v?.trim().length ?? 0) > 1000 ? s('error-notes') : null,
                ),
                if (widget.transfer != null) ...[
                  const SizedBox(height: 16),
                  Text(s('editHelp')),
                ],
                if (error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            child: Text(s('close')),
          ),
          FilledButton(
            key: const ValueKey('transfer-save'),
            onPressed: busy ? null : save,
            child: Text(s(busy ? 'saving' : 'save')),
          ),
        ],
      ),
    );
  }
}
