import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/money.dart';
import '../../../shared/design_system/components.dart';
import '../domain/wallet.dart';
import 'wallet_copy.dart';
import 'wallet_providers.dart';

Future<String?> showWalletEditor(
  BuildContext context, {
  WalletSnapshot? wallet,
}) => showDialog<String>(
  context: context,
  barrierDismissible: false,
  builder: (_) => WalletEditor(wallet: wallet),
);

class WalletEditor extends ConsumerStatefulWidget {
  const WalletEditor({super.key, this.wallet});
  final WalletSnapshot? wallet;
  @override
  ConsumerState<WalletEditor> createState() => _WalletEditorState();
}

class _WalletEditorState extends ConsumerState<WalletEditor> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(
    text: widget.wallet?.wallet.name ?? '',
  );
  final opening = TextEditingController(text: '0');
  final code = TextEditingController();
  late String color = widget.wallet?.wallet.color ?? 'emerald';
  late String icon = widget.wallet?.wallet.icon ?? 'wallet';
  late String type = widget.wallet?.wallet.type ?? 'cash';
  String selectedCurrency = 'ILS';
  int customScale = 2;
  bool busy = false;
  String? error, fingerprint;
  WalletOperation? operation;
  static const currencies = {
    'ILS': 2,
    'USD': 2,
    'EUR': 2,
    'GBP': 2,
    'JOD': 3,
    'KWD': 3,
    'SAR': 2,
    'AED': 2,
    'JPY': 0,
  };
  Currency get currency =>
      widget.wallet?.wallet.currency ??
      Currency(
        selectedCurrency == 'custom'
            ? code.text.trim().toUpperCase()
            : selectedCurrency,
        selectedCurrency == 'custom'
            ? customScale
            : currencies[selectedCurrency]!,
      );
  @override
  void dispose() {
    name.dispose();
    opening.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    final draft = WalletDraft(
      name: name.text,
      color: color,
      icon: icon,
      type: type,
      currency: currency,
    );
    final amount = widget.wallet == null
        ? Money.parse(opening.text, currency)
        : null;
    final payload = jsonEncode([draft.toJson(), amount?.toJson()]);
    if (fingerprint != payload) {
      operation = WalletOperation.generate();
      fingerprint = payload;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final repo = ref.read(walletRepositoryProvider);
      String id;
      if (widget.wallet == null) {
        id = await repo.create(operation!, draft, amount!);
      } else {
        id = widget.wallet!.wallet.id;
        await repo.edit(operation!, id, widget.wallet!.wallet.revision, draft);
      }
      if (mounted) Navigator.pop(context, id);
    } catch (e) {
      if (mounted) setState(() => error = WalletCopy.of(context).error(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = WalletCopy.of(context);
    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        title: Text(s(widget.wallet == null ? 'create' : 'edit')),
        scrollable: true,
        content: SizedBox(
          width: 560,
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WalletTextField(
                  key: const ValueKey('wallet-name'),
                  label: s('name'),
                  controller: name,
                  validator: (v) =>
                      v == null || v.trim().isEmpty || v.trim().length > 80
                      ? s('nameInvalid')
                      : null,
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<String>(
                  key: const ValueKey('wallet-type'),
                  initialValue: type,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: s('type')),
                  items: [
                    for (final t in walletTypes)
                      DropdownMenuItem(value: t, child: Text(s(t))),
                  ],
                  onChanged: busy ? null : (v) => setState(() => type = v!),
                ),
                const SizedBox(height: 18),
                if (widget.wallet == null) ...[
                  DropdownButtonFormField<String>(
                    key: const ValueKey('wallet-currency'),
                    initialValue: selectedCurrency,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: s('currency')),
                    items: [
                      for (final c in currencies.keys)
                        DropdownMenuItem(value: c, child: Text(c)),
                      DropdownMenuItem(
                        value: 'custom',
                        child: Text(s('custom')),
                      ),
                    ],
                    onChanged: busy
                        ? null
                        : (v) => setState(() => selectedCurrency = v!),
                  ),
                  if (selectedCurrency == 'custom') ...[
                    const SizedBox(height: 18),
                    WalletTextField(
                      key: const ValueKey('wallet-code'),
                      label: s('code'),
                      controller: code,
                      validator: (v) =>
                          RegExp(r'^[A-Za-z]{3}$').hasMatch(v?.trim() ?? '')
                          ? null
                          : s('codeInvalid'),
                    ),
                    const SizedBox(height: 18),
                    DropdownButtonFormField<int>(
                      key: const ValueKey('wallet-scale'),
                      initialValue: customScale,
                      decoration: InputDecoration(labelText: s('scale')),
                      items: [
                        for (var i = 0; i <= 6; i++)
                          DropdownMenuItem(value: i, child: Text('$i')),
                      ],
                      onChanged: busy
                          ? null
                          : (v) => setState(() => customScale = v!),
                    ),
                  ],
                  const SizedBox(height: 18),
                  WalletTextField(
                    key: const ValueKey('wallet-opening'),
                    label: s('opening'),
                    controller: opening,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    validator: (v) {
                      try {
                        Money.parse(v ?? '', currency);
                        return null;
                      } catch (_) {
                        return s('moneyInvalid');
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  Text(
                    s('openingHelp'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ] else ...[
                  Text(
                    '${s('currency')}: ${currency.code} · ${currency.scale} ${s('scale')}',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s('immutable'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  s('color'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in walletColors)
                      ChoiceChip(
                        key: ValueKey('wallet-color-$c'),
                        label: Text(s(c)),
                        avatar: CircleAvatar(
                          backgroundColor: walletColor(c),
                          radius: 8,
                        ),
                        selected: color == c,
                        onSelected: busy
                            ? null
                            : (_) => setState(() => color = c),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(s('icon'), style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final i in walletIcons)
                      ChoiceChip(
                        key: ValueKey('wallet-icon-$i'),
                        label: Text(s(i)),
                        avatar: Icon(walletIcon(i), size: 18),
                        selected: icon == i,
                        onSelected: busy
                            ? null
                            : (_) => setState(() => icon = i),
                      ),
                  ],
                ),
                if (error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    error!,
                    key: const ValueKey('wallet-error'),
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
            child: Text(s('cancel')),
          ),
          FilledButton(
            key: const ValueKey('wallet-save'),
            onPressed: busy ? null : save,
            child: Text(s(busy ? 'saving' : 'save')),
          ),
        ],
      ),
    );
  }
}
