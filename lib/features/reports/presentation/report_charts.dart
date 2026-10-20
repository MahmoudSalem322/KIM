import 'package:flutter/material.dart';

import '../../../core/domain/money.dart';
import '../../../shared/design_system/components.dart';
import '../../dashboard/domain/dashboard_summary.dart' show chartFraction;
import 'report_copy.dart';

typedef ReportChartPoint = ({String date, Money income, Money expense});
String reportAmount(Money m) => '${m.decimal} ${m.currency.code}';

class ReportTrend extends StatefulWidget {
  const ReportTrend({super.key, required this.points});
  final List<ReportChartPoint> points;
  @override
  State<ReportTrend> createState() => _ReportTrendState();
}

class _ReportTrendState extends State<ReportTrend> {
  int? selected;
  @override
  void didUpdateWidget(covariant ReportTrend oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points != widget.points) selected = null;
  }

  @override
  Widget build(BuildContext context) {
    final s = ReportCopy.of(context), points = widget.points;
    final max = points.fold(BigInt.zero, (v, p) {
      final a = p.income.minorUnits > p.expense.minorUnits
          ? p.income.minorUnits
          : p.expense.minorUnits;
      return a > v ? a : v;
    });
    final current = selected == null ? null : points[selected!];
    return WalletCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s('trend'), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(s('selectBar'), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          if (max == BigInt.zero)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Text(s('emptyChart')),
            )
          else
            SizedBox(
              height: 210,
              child: LayoutBuilder(
                builder: (context, bounds) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: bounds.maxWidth < points.length * 52
                        ? points.length * 52
                        : bounds.maxWidth,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < points.length; i++)
                          Expanded(
                            child: Tooltip(
                              message:
                                  '${points[i].date}\n${s('income')}: ${reportAmount(points[i].income)}\n${s('expense')}: ${reportAmount(points[i].expense)}',
                              child: InkWell(
                                key: ValueKey('report-bar-$i'),
                                onTap: () => setState(() => selected = i),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 4,
                                  ),
                                  color: selected == i
                                      ? Theme.of(context).colorScheme.primary
                                            .withValues(alpha: .08)
                                      : null,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Expanded(
                                              child: Container(
                                                height:
                                                    160 *
                                                    chartFraction(
                                                      points[i]
                                                          .income
                                                          .minorUnits,
                                                      max,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFF238875,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(5),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 3),
                                            Expanded(
                                              child: Container(
                                                height:
                                                    160 *
                                                    chartFraction(
                                                      points[i]
                                                          .expense
                                                          .minorUnits,
                                                      max,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFC86648,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(5),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        points[i].date.substring(5),
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              Text(
                s('income'),
                style: const TextStyle(color: Color(0xFF238875)),
              ),
              Text(
                s('expense'),
                style: const TextStyle(color: Color(0xFFC86648)),
              ),
            ],
          ),
          if (current != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                '${current.date} · ${s('income')}: ${reportAmount(current.income)} · ${s('expense')}: ${reportAmount(current.expense)}',
              ),
            ),
        ],
      ),
    );
  }
}

class ReportDistribution extends StatefulWidget {
  const ReportDistribution({
    super.key,
    required this.values,
    required this.label,
  });
  final Map<String, Money> values;
  final String Function(String) label;
  @override
  State<ReportDistribution> createState() => _ReportDistributionState();
}

class _ReportDistributionState extends State<ReportDistribution> {
  String? selected;
  @override
  Widget build(BuildContext context) {
    final s = ReportCopy.of(context),
        sum = widget.values.values.fold(
          BigInt.zero,
          (v, m) => v + m.minorUnits,
        );
    return WalletCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s('distribution'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          if (sum == BigInt.zero) Text(s('emptyChart')),
          for (final e in widget.values.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () =>
                    setState(() => selected = selected == e.key ? null : e.key),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(widget.label(e.key))),
                          Text(
                            reportAmount(e.value),
                            textDirection: TextDirection.ltr,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: chartFraction(e.value.minorUnits, sum),
                        minHeight: selected == e.key ? 12 : 7,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      if (selected == e.key)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '${((e.value.minorUnits * BigInt.from(10000)) ~/ sum).toString().padLeft(3, '0').replaceAllMapped(RegExp(r'(\d{2})$'), (m) => '.${m[1]}')}%',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
