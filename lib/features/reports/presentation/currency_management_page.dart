import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/money.dart';
import '../../../shared/design_system/components.dart';
import '../../wallets/domain/wallet.dart';
import '../../wallets/presentation/wallet_providers.dart';
import '../domain/exchange_book.dart';
import 'currency_copy.dart';
import 'currency_providers.dart';

class CurrencyManagementPage extends ConsumerStatefulWidget {
  const CurrencyManagementPage({super.key});
  @override
  ConsumerState<CurrencyManagementPage> createState() =>
      _CurrencyManagementPageState();
}

class _CurrencyManagementPageState
    extends ConsumerState<CurrencyManagementPage> {
  bool busy = false;
  String? error;
  Future<void> save(
    ExchangeBook book,
    Currency currency,
    List<ManualRate> rates,
  ) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref
          .read(exchangeRepositoryProvider)
          .save(WalletOperation.generate(), book.revision, currency, rates);
    } catch (_) {
      if (mounted) setState(() => error = CurrencyCopy.of(context)('error'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = CurrencyCopy.of(context),
        state = ref.watch(exchangeBookProvider),
        wallets = ref.watch(walletsProvider);
    if (state.isLoading || wallets.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.hasError || wallets.hasError) return Text(s('loadingError'));
    final book = state.requireValue;
    final currencies =
        <Currency>{
          Currency('ILS', 2),
          Currency('USD', 2),
          Currency('EUR', 2),
          Currency('GBP', 2),
          Currency('JOD', 3),
          Currency('KWD', 3),
          Currency('SAR', 2),
          Currency('AED', 2),
          Currency('JPY', 0),
          book.currency,
          for (final wallet in wallets.requireValue) wallet.wallet.currency,
          for (final rate in book.rates) ...[rate.from, rate.to],
        }.toList()..sort(
          (a, b) => '${a.code}${a.scale}'.compareTo('${b.code}${b.scale}'),
        );
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey('currencies-page'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s('title'), style: theme.textTheme.headlineLarge),
        const SizedBox(height: 8),
        Text(s('description')),
        const SizedBox(height: 24),
        WalletCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<Currency>(
                key: ValueKey(
                  'display-currency-${book.currency.code}-${book.currency.scale}',
                ),
                initialValue: book.currency,
                decoration: InputDecoration(labelText: s('primary')),
                isExpanded: true,
                items: [
                  for (final c in currencies)
                    DropdownMenuItem(
                      value: c,
                      child: Text('${c.code} · ${c.scale}'),
                    ),
                ],
                onChanged: busy
                    ? null
                    : (c) {
                        if (c != null && c != book.currency) {
                          save(book, c, book.rates);
                        }
                      },
              ),
              const SizedBox(height: 16),
              Text(s('policy'), style: theme.textTheme.bodySmall),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(s('rates'), style: theme.textTheme.titleLarge),
            WalletButton(
              label: s('add'),
              icon: Icons.add,
              onPressed: busy
                  ? null
                  : () => showDialog<void>(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) =>
                          _RateEditor(book: book, currencies: currencies),
                    ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (book.rates.isEmpty)
          WalletCard(
            child: Column(
              children: [
                Icon(
                  Icons.currency_exchange,
                  size: 42,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(s('empty')),
              ],
            ),
          ),
        for (final rate in book.rates)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: WalletCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      '1 ${rate.from.code} = ${rate.decimal} ${rate.to.code}',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('${s('source')}: ${rate.source}'),
                  Text('${s('date')}: ${rate.asOf}'),
                  Text(
                    '${s('updated')}: ${rate.updatedAt.toLocal().toIso8601String().substring(0, 16).replaceFirst('T', ' ')}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.edit_outlined),
                        label: Text(s('edit')),
                        onPressed: busy
                            ? null
                            : () => showDialog<void>(
                                context: context,
                                barrierDismissible: false,
                                builder: (_) => _RateEditor(
                                  book: book,
                                  currencies: currencies,
                                  rate: rate,
                                ),
                              ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.delete_outline),
                        label: Text(s('delete')),
                        onPressed: busy
                            ? null
                            : () async {
                                final yes = await showDialog<bool>(
                                  context: context,
                                  builder: (c) => AlertDialog(
                                    title: Text(s('deleteTitle')),
                                    content: Text(s('deleteBody')),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(c, false),
                                        child: Text(s('cancel')),
                                      ),
                                      FilledButton(
                                        onPressed: () => Navigator.pop(c, true),
                                        child: Text(s('delete')),
                                      ),
                                    ],
                                  ),
                                );
                                if (yes == true && mounted) {
                                  await save(book, book.currency, [
                                    for (final r in book.rates)
                                      if (r != rate) r,
                                  ]);
                                }
                              },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _RateEditor extends ConsumerStatefulWidget {
  const _RateEditor({required this.book, required this.currencies, this.rate});
  final ExchangeBook book;
  final List<Currency> currencies;
  final ManualRate? rate;
  @override
  ConsumerState<_RateEditor> createState() => _RateEditorState();
}

class _RateEditorState extends ConsumerState<_RateEditor> {
  late Currency from =
          widget.rate?.from ??
          widget.currencies.firstWhere(
            (c) => c.code == 'USD',
            orElse: () => widget.currencies.first,
          ),
      to = widget.rate?.to ?? widget.book.currency;
  late final decimal = TextEditingController(text: widget.rate?.decimal ?? ''),
      source = TextEditingController(text: widget.rate?.source ?? ''),
      date = TextEditingController(
        text:
            widget.rate?.asOf ??
            DateTime.now().toIso8601String().substring(0, 10),
      );
  bool busy = false;
  String? error, fingerprint;
  WalletOperation? operation;
  @override
  void dispose() {
    decimal.dispose();
    source.dispose();
    date.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final s = CurrencyCopy.of(context);
    ManualRate rate;
    try {
      rate = ManualRate(
        from: from,
        to: to,
        decimal: decimal.text.trim(),
        source: source.text.trim(),
        asOf: date.text.trim(),
        updatedAt: DateTime.now(),
      );
    } catch (_) {
      setState(() => error = s('invalid'));
      return;
    }
    final key =
        '${from.code}:${from.scale}|${to.code}:${to.scale}|${decimal.text}|${source.text}|${date.text}';
    if (key != fingerprint) {
      fingerprint = key;
      operation = WalletOperation.generate();
    }
    // Keep the same timestamp and operation payload on retry.
    rate = ManualRate(
      from: from,
      to: to,
      decimal: rate.decimal,
      source: rate.source,
      asOf: rate.asOf,
      updatedAt: operation!.at,
    );
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final rates = [
        for (final r in widget.book.rates)
          if (r != widget.rate &&
              !((r.from == from && r.to == to) ||
                  (r.from == to && r.to == from)))
            r,
        rate,
      ];
      await ref
          .read(exchangeRepositoryProvider)
          .save(operation!, widget.book.revision, widget.book.currency, rates);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => error = s('error'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = CurrencyCopy.of(context);
    return AlertDialog(
      title: Text(s(widget.rate == null ? 'add' : 'edit')),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final isFrom in [true, false])
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: DropdownButtonFormField<Currency>(
                    initialValue: isFrom ? from : to,
                    decoration: InputDecoration(
                      labelText: s(isFrom ? 'from' : 'to'),
                    ),
                    isExpanded: true,
                    items: [
                      for (final c in widget.currencies)
                        DropdownMenuItem(
                          value: c,
                          child: Text('${c.code} · ${c.scale}'),
                        ),
                    ],
                    onChanged: busy
                        ? null
                        : (c) {
                            if (c != null) {
                              setState(() {
                                if (isFrom) {
                                  from = c;
                                } else {
                                  to = c;
                                }
                              });
                            }
                          },
                  ),
                ),
              WalletTextField(
                label: s('rate'),
                controller: decimal,
                enabled: !busy,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 16),
              WalletTextField(
                label: s('source'),
                controller: source,
                enabled: !busy,
              ),
              const SizedBox(height: 16),
              WalletTextField(
                label: s('date'),
                controller: date,
                enabled: !busy,
              ),
              const SizedBox(height: 16),
              Text(
                s('description'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
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
        FilledButton(onPressed: busy ? null : submit, child: Text(s('save'))),
      ],
    );
  }
}
