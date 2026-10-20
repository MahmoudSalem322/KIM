import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/money.dart';
import '../../../shared/design_system/components.dart';
import '../../categories/presentation/category_providers.dart';
import '../../categories/presentation/category_widgets.dart';
import '../../dashboard/domain/dashboard_summary.dart';
import '../../debts/presentation/debt_providers.dart';
import '../../transactions/presentation/transaction_providers.dart';
import '../../transfers/presentation/transfer_providers.dart';
import '../../wallets/domain/wallet.dart';
import '../../wallets/presentation/wallet_providers.dart';
import '../domain/exchange_book.dart';
import '../domain/financial_report.dart';
import '../export/export_download.dart';
import '../export/report_exporter.dart';
import 'currency_providers.dart';
import 'report_charts.dart';
import 'report_copy.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});
  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  String preset = 'month';
  DashboardPeriod? custom;
  String? walletId, category;
  bool exporting = false;
  @override
  Widget build(BuildContext context) {
    final s = ReportCopy.of(context),
        wallets = ref.watch(walletsProvider),
        tx = ref.watch(transactionsProvider),
        transfers = ref.watch(transfersProvider),
        debts = ref.watch(debtsProvider),
        exchange = ref.watch(exchangeBookProvider),
        categories = ref.watch(categoriesProvider);
    final states = <AsyncValue<dynamic>>[
      wallets,
      tx,
      transfers,
      debts,
      exchange,
      categories,
    ];
    if (states.any((v) => v.isLoading)) {
      return const Center(child: CircularProgressIndicator());
    }
    if (states.any((v) => v.hasError)) {
      return WalletCard(
        child: Column(
          children: [
            Text(s('error')),
            TextButton(
              onPressed: () {
                ref.invalidate(walletsProvider);
                ref.invalidate(transactionsProvider);
                ref.invalidate(transfersProvider);
                ref.invalidate(debtsProvider);
                ref.invalidate(exchangeBookProvider);
                ref.invalidate(categoriesProvider);
              },
              child: Text(s('retry')),
            ),
          ],
        ),
      );
    }
    final list = wallets.requireValue;
    final period = preset == 'custom' && custom != null
        ? custom!
        : DashboardPeriod.preset(preset, DateTime.now());
    final selectedWallet = list.any((w) => w.wallet.id == walletId)
        ? walletId
        : null;
    final selectedCategory =
        categories.requireValue.any((c) => c.id == category) ? category : null;
    final filter = ReportFilter(
      from: period.from,
      to: period.to,
      walletId: selectedWallet,
      category: selectedCategory,
    );
    final data = ReportResult.calculate(
      filter: filter,
      book: exchange.requireValue,
      wallets: list,
      transactions: tx.requireValue,
      transfers: transfers.requireValue,
      debts: debts.requireValue,
    );
    final theme = Theme.of(context);
    String label(String id) => categoryLabel(context, ref, id);
    return Column(
      key: const ValueKey('reports-page'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s('title'), style: theme.textTheme.headlineLarge),
        const SizedBox(height: 8),
        Text(s('subtitle'), style: theme.textTheme.bodyMedium),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: () => context.go('/currencies'),
              icon: const Icon(Icons.currency_exchange),
              label: Text(s('currencies')),
            ),
            for (final format in ['CSV', 'Excel', 'PDF'])
              OutlinedButton.icon(
                key: ValueKey('export-${format.toLowerCase()}'),
                onPressed: exporting || data.concealed
                    ? null
                    : () => export(format, data, list, exchange.requireValue),
                icon: const Icon(Icons.file_download_outlined),
                label: Text('${s('export')} $format'),
              ),
          ],
        ),
        if (exporting)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(s('exporting')),
          ),
        const SizedBox(height: 20),
        WalletCard(
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  key: ValueKey('report-period-$preset'),
                  isExpanded: true,
                  initialValue: preset,
                  decoration: InputDecoration(labelText: s('period')),
                  items: [
                    for (final p in [
                      'month',
                      'week',
                      'lastMonth',
                      'year',
                      'custom',
                    ])
                      DropdownMenuItem(value: p, child: Text(s(p))),
                  ],
                  onChanged: (v) async {
                    if (v == null) return;
                    if (v == 'custom') {
                      final range = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(1900),
                        lastDate: DateTime(2100, 12, 31),
                        initialDateRange: DateTimeRange(
                          start: period.start,
                          end: period.end,
                        ),
                      );
                      if (range == null || !mounted) return;
                      setState(() {
                        custom = DashboardPeriod(range.start, range.end);
                        preset = v;
                      });
                    } else {
                      setState(() => preset = v);
                    }
                  },
                ),
              ),
              SizedBox(
                width: 230,
                child: DropdownButtonFormField<String>(
                  key: ValueKey('report-wallet-${selectedWallet ?? 'all'}'),
                  initialValue: selectedWallet ?? '',
                  isExpanded: true,
                  decoration: InputDecoration(labelText: s('wallet')),
                  items: [
                    DropdownMenuItem(value: '', child: Text(s('allWallets'))),
                    for (final w in list)
                      DropdownMenuItem(
                        value: w.wallet.id,
                        child: Text(
                          w.wallet.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) =>
                      setState(() => walletId = v == '' ? null : v),
                ),
              ),
              SizedBox(
                width: 230,
                child: DropdownButtonFormField<String>(
                  key: ValueKey('report-category-${selectedCategory ?? 'all'}'),
                  initialValue: selectedCategory ?? '',
                  isExpanded: true,
                  decoration: InputDecoration(labelText: s('category')),
                  items: [
                    DropdownMenuItem(
                      value: '',
                      child: Text(s('allCategories')),
                    ),
                    for (final c in categories.requireValue)
                      DropdownMenuItem(
                        value: c.id,
                        child: Text(
                          label(c.id),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) =>
                      setState(() => category = v == '' ? null : v),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${filter.from} / ${filter.to} · ${data.currency.code}',
          textDirection: TextDirection.ltr,
        ),
        const SizedBox(height: 20),
        if (data.concealed)
          WalletCard(child: Text(s('hidden')))
        else ...[
          if (!data.complete)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: WalletCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${s('incomplete')} ${data.missingCurrencies.map((c) => '${c.code}/${c.scale}').join(', ')}',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          LayoutBuilder(
            builder: (context, b) => Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final metric in <({String key, Money now, Money before})>[
                  (
                    key: 'income',
                    now: data.income,
                    before: data.previous.income,
                  ),
                  (
                    key: 'expense',
                    now: data.expense,
                    before: data.previous.expense,
                  ),
                  (
                    key: 'operating',
                    now: data.operatingNet,
                    before: data.previous.operatingNet,
                  ),
                  (
                    key: 'cash',
                    now: data.cashFlow,
                    before: data.previous.cashFlow,
                  ),
                ])
                  SizedBox(
                    width: b.maxWidth >= 1100
                        ? (b.maxWidth - 48) / 4
                        : b.maxWidth >= 600
                        ? (b.maxWidth - 16) / 2
                        : b.maxWidth,
                    child: _ReportMetric(
                      label: s(metric.key),
                      value: metric.now,
                      previous: metric.before,
                      partial: !data.complete,
                      hero: metric.key == 'cash',
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          WalletCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${s('previous')}: ${filter.previous.from} / ${filter.previous.to}',
                ),
                const SizedBox(height: 8),
                Text(s('previousNote')),
                const Divider(height: 28),
                Wrap(
                  spacing: 28,
                  runSpacing: 12,
                  children: [
                    Text('${s('debt')}: ${reportAmount(data.debtNet)}'),
                    Text('${s('transfer')}: ${reportAmount(data.transferNet)}'),
                    Text(
                      '${s('valuationDifference')}: ${reportAmount(data.totals.transferValuationDifference)}',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(s('policy')),
                const SizedBox(height: 8),
                Text(s('transferDate')),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (data.rows.isEmpty)
            WalletCard(
              child: Column(
                children: [
                  const Icon(Icons.insights_rounded, size: 48),
                  const SizedBox(height: 16),
                  Text(s('empty'), style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(s('emptyBody')),
                ],
              ),
            ),
          if (data.rows.isNotEmpty) ...[
            ReportTrend(
              points: [
                for (final b in data.buckets)
                  (date: b.from, income: b.income, expense: b.expense),
              ],
            ),
            const SizedBox(height: 20),
            ReportDistribution(values: data.categories, label: label),
            const SizedBox(height: 20),
            WalletCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${s('details')} · ${data.rows.length} ${s('rows')}',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: [
                        for (final h in [
                          'date',
                          'type',
                          'wallet',
                          'category',
                          'original',
                          'converted',
                          'rate',
                        ])
                          DataColumn(label: Text(s(h))),
                      ],
                      rows: [
                        for (final r in data.rows.take(100))
                          DataRow(
                            cells: [
                              DataCell(Text(r.date)),
                              DataCell(Text(kindLabel(s, r.kind))),
                              DataCell(Text(walletName(list, r.walletId))),
                              DataCell(
                                Text(
                                  r.category.isEmpty ? '—' : label(r.category),
                                ),
                              ),
                              DataCell(
                                Text(
                                  reportAmount(r.original),
                                  textDirection: TextDirection.ltr,
                                ),
                              ),
                              DataCell(
                                Text(
                                  r.converted == null
                                      ? s('unavailable')
                                      : reportAmount(r.converted!),
                                  textDirection: TextDirection.ltr,
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 230,
                                  child: Text(rateText(s, r.conversion)),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  if (data.rows.length > 100) Text(s('more')),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          WalletCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s('ratePolicy')),
                const SizedBox(height: 12),
                for (final rate in data.book.rates)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${rate.from.code}/${rate.from.scale} / ${rate.to.code}/${rate.to.scale} · ${rate.decimal} · ${rate.source} · ${rate.asOf}',
                      textDirection: TextDirection.ltr,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> export(
    String format,
    ReportResult snapshot,
    List<WalletSnapshot> wallets,
    ExchangeBook book,
  ) async {
    final s = ReportCopy.of(context);
    setState(() => exporting = true);
    try {
      final data = ReportExportData(
        title: s('title'),
        subtitle: '${snapshot.filter.from} / ${snapshot.filter.to}',
        generatedAt: DateTime.now(),
        currency: book.currency.code,
        arabic: s.ar,
        summary: {
          for (final e in {
            'income': snapshot.income,
            'expense': snapshot.expense,
            'operating': snapshot.operatingNet,
            'debt': snapshot.debtNet,
            'transfer': snapshot.transferNet,
            'valuationDifference': snapshot.totals.transferValuationDifference,
            'cash': snapshot.cashFlow,
          }.entries)
            s(e.key): reportAmount(e.value),
          s(
            'previous',
          ): '${snapshot.filter.previous.from} / ${snapshot.filter.previous.to}',
          '${s('previous')} · ${s('income')}': reportAmount(
            snapshot.previous.income,
          ),
          '${s('previous')} · ${s('expense')}': reportAmount(
            snapshot.previous.expense,
          ),
          '${s('previous')} · ${s('cash')}': reportAmount(
            snapshot.previous.cashFlow,
          ),
        },
        notes: [
          s('policy'),
          s('transferDate'),
          s('ratePolicy'),
          '${s('wallet')}: ${snapshot.filter.walletId == null ? s('allWallets') : walletName(wallets, snapshot.filter.walletId!)}',
          '${s('category')}: ${snapshot.filter.category == null ? s('allCategories') : categoryLabel(context, ref, snapshot.filter.category!)}',
          if (!snapshot.complete)
            '${s('incomplete')} ${snapshot.missingCurrencies.map((c) => '${c.code}/${c.scale}').join(', ')}',
          for (final r in book.rates)
            '${r.from.code}/${r.from.scale} / ${r.to.code}/${r.to.scale} = ${r.decimal}; ${r.source}; ${r.asOf}; ${r.updatedAt.toIso8601String()}',
        ],
        headers: [
          s('date'),
          s('type'),
          s('wallet'),
          s('category'),
          s('original'),
          s('converted'),
          s('rate'),
          s.ar ? 'الملاحظات' : 'Notes',
        ],
        rows: [
          for (final r in snapshot.rows)
            [
              r.date,
              kindLabel(s, r.kind),
              walletName(wallets, r.walletId),
              r.category.isEmpty
                  ? '—'
                  : categoryLabel(context, ref, r.category),
              reportAmount(r.original),
              r.converted == null
                  ? s('unavailable')
                  : reportAmount(r.converted!),
              rateText(s, r.conversion),
              r.notes,
            ],
        ],
      );
      final Uint8List bytes = switch (format) {
        'CSV' => ReportExporter.csv(data),
        'Excel' => ReportExporter.xlsx(data),
        _ => await ReportExporter.pdf(data),
      };
      if (!mounted) return;
      final current = ref.read(walletsProvider);
      if (current.isLoading ||
          current.hasError ||
          snapshot.concealedBy(current.requireValue)) {
        throw StateError('Privacy changed');
      }
      final ext = format == 'Excel' ? 'xlsx' : format.toLowerCase();
      final saved = await ExportDownload.save(
        bytes,
        'Kim-report-${snapshot.filter.from}-${snapshot.filter.to}.$ext',
        switch (ext) {
          'csv' => 'text/csv;charset=utf-8',
          'xlsx' =>
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          _ => 'application/pdf',
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${s('exported')}: $saved')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(s('exportError'))));
      }
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }
}

String walletName(List<WalletSnapshot> wallets, String id) =>
    wallets.where((w) => w.wallet.id == id).firstOrNull?.wallet.name ?? id;
String kindLabel(ReportCopy s, ReportRowKind k) => switch (k) {
  ReportRowKind.income => s('income'),
  ReportRowKind.expense => s('expense'),
  ReportRowKind.debtIn => s.ar ? 'قبض دين' : 'Debt receipt',
  ReportRowKind.debtOut => s.ar ? 'دفع دين' : 'Debt payment',
  ReportRowKind.transferIn => s.ar ? 'تحويل وارد' : 'Transfer in',
  ReportRowKind.transferOut => s.ar ? 'تحويل صادر' : 'Transfer out',
};
String rateText(ReportCopy s, ConvertedMoney? c) {
  if (c == null) return s('unavailable');
  final r = c.rate;
  if (r == null) return s('same');
  return '${c.inverse ? '1 / ' : ''}${r.decimal} (${r.from.code} / ${r.to.code}) · ${r.source} · ${r.asOf}';
}

class _ReportMetric extends StatelessWidget {
  const _ReportMetric({
    required this.label,
    required this.value,
    required this.previous,
    required this.partial,
    required this.hero,
  });
  final String label;
  final Money value, previous;
  final bool partial, hero;
  @override
  Widget build(BuildContext context) {
    final s = ReportCopy.of(context), t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: hero ? const Color(0xFF183B43) : t.colorScheme.surface,
        border: Border.all(
          color: t.colorScheme.outlineVariant.withValues(alpha: .4),
        ),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: hero ? Colors.white : null),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                alignment: AlignmentDirectional.centerStart,
                fit: BoxFit.scaleDown,
                child: Text(
                  '${reportAmount(value)}${partial ? ' *' : ''}',
                  textDirection: TextDirection.ltr,
                  style: t.textTheme.headlineSmall?.copyWith(
                    color: hero ? Colors.white : null,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('${s('previous')}: ${reportAmount(previous)}'),
            const SizedBox(height: 6),
            Text(
              '${s('change')}: ${reportAmount(value - previous)}${partial ? ' · ${s('partial')}' : ''}',
            ),
          ],
        ),
      ),
    );
  }
}
