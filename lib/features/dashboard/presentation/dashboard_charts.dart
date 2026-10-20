import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/money.dart';
import '../../../shared/design_system/components.dart';
import '../../categories/presentation/category_providers.dart';
import '../../categories/presentation/category_widgets.dart';
import '../../wallets/presentation/wallet_copy.dart' show walletColor;
import '../domain/dashboard_summary.dart';
import 'dashboard_copy.dart';

const dashboardIncomeColor = Color(0xFF238875);
const dashboardExpenseColor = Color(0xFFC86648);
const _palette = [
  Color(0xFF238875),
  Color(0xFF658DD1),
  Color(0xFF9D7BCC),
  Color(0xFFD99A35),
  Color(0xFFCC6C83),
  Color(0xFF488DAB),
  Color(0xFF87825C),
  Color(0xFF777E91),
];
String dashboardAmount(Money value) =>
    '${value.decimal} ${value.currency.code}';

class DashboardCharts extends StatelessWidget {
  const DashboardCharts({super.key, required this.summary});
  final DashboardSummary summary;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final children = [
        FlowChart(summary: summary),
        SpendingChart(summary: summary),
      ];
      if (bounds.maxWidth < 850) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [children[0], const SizedBox(height: 20), children[1]],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: children[0]),
          const SizedBox(width: 20),
          Expanded(flex: 2, child: children[1]),
        ],
      );
    },
  );
}

class FlowChart extends StatefulWidget {
  const FlowChart({super.key, required this.summary});
  final DashboardSummary summary;
  @override
  State<FlowChart> createState() => _FlowChartState();
}

class _FlowChartState extends State<FlowChart> {
  int? selected;
  @override
  void didUpdateWidget(covariant FlowChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.summary != widget.summary) selected = null;
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.summary, s = DashboardCopy.of(context);
    final maxValue = d.buckets.fold(BigInt.zero, (v, b) {
      final candidate = b.income.minorUnits > b.expense.minorUnits
          ? b.income.minorUnits
          : b.expense.minorUnits;
      return candidate > v ? candidate : v;
    });
    final bucket = selected == null ? null : d.buckets[selected!];
    return WalletCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s('trend'), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _Legend(s('income'), dashboardIncomeColor),
              _Legend(s('expense'), dashboardExpenseColor),
            ],
          ),
          const SizedBox(height: 18),
          if (maxValue == BigInt.zero)
            ChartEmpty(
              icon: Icons.bar_chart_rounded,
              title: s('noActivity'),
              body: s('noActivityBody'),
            )
          else ...[
            Text(s('chartHint'), style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: LayoutBuilder(
                builder: (context, bounds) {
                  final width = math.max(
                    bounds.maxWidth,
                    d.buckets.length * 66.0,
                  );
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: width,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < d.buckets.length; i++)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                child: Builder(
                                  builder: (context) {
                                    final b = d.buckets[i];
                                    final label =
                                        '${b.from} – ${b.to}\n${s('income')}: ${dashboardAmount(b.income)}\n${s('expense')}: ${dashboardAmount(b.expense)}';
                                    return Tooltip(
                                      message: label,
                                      child: Semantics(
                                        label: label,
                                        button: true,
                                        child: InkWell(
                                          key: ValueKey('flow-bucket-$i'),
                                          onTap: () =>
                                              setState(() => selected = i),
                                          onHover: (hover) {
                                            if (hover) {
                                              setState(() => selected = i);
                                            }
                                          },
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: selected == i
                                                  ? Theme.of(context)
                                                        .colorScheme
                                                        .primary
                                                        .withValues(alpha: .08)
                                                  : null,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            padding: const EdgeInsets.all(6),
                                            child: Column(
                                              children: [
                                                Expanded(
                                                  child: Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.end,
                                                    children: [
                                                      for (final item in [
                                                        (
                                                          b.income,
                                                          dashboardIncomeColor,
                                                        ),
                                                        (
                                                          b.expense,
                                                          dashboardExpenseColor,
                                                        ),
                                                      ])
                                                        Expanded(
                                                          child: Padding(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal: 2,
                                                                ),
                                                            child: Align(
                                                              alignment: Alignment
                                                                  .bottomCenter,
                                                              child: FractionallySizedBox(
                                                                heightFactor:
                                                                    chartFraction(
                                                                      item
                                                                          .$1
                                                                          .minorUnits,
                                                                      maxValue,
                                                                    ),
                                                                widthFactor: 1,
                                                                child: DecoratedBox(
                                                                  decoration: BoxDecoration(
                                                                    color:
                                                                        item.$2,
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          5,
                                                                        ),
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(height: 10),
                                                Text(
                                                  b.from.substring(5),
                                                  textDirection:
                                                      TextDirection.ltr,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .labelSmall,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Text(
              bucket == null
                  ? '${d.period.from} — ${d.period.to}'
                  : '${bucket.from} — ${bucket.to}',
              textDirection: TextDirection.ltr,
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 20,
              runSpacing: 8,
              children: [
                Text(
                  '${s('income')}: ${dashboardAmount(bucket?.income ?? d.income)}',
                ),
                Text(
                  '${s('expense')}: ${dashboardAmount(bucket?.expense ?? d.expense)}',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class SpendingChart extends ConsumerStatefulWidget {
  const SpendingChart({super.key, required this.summary});
  final DashboardSummary summary;
  @override
  ConsumerState<SpendingChart> createState() => _SpendingChartState();
}

class _SpendingChartState extends ConsumerState<SpendingChart> {
  String? selected;
  @override
  void didUpdateWidget(covariant SpendingChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.summary != widget.summary) selected = null;
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.summary,
        s = DashboardCopy.of(context),
        allCategories = ref.watch(categoriesProvider).value ?? [];
    final entries = d.categories.entries.toList();
    String categoryTitle(String id) => categoryLabel(context, ref, id);
    final colors = [
      for (var i = 0; i < entries.length; i++)
        allCategories.any((c) => c.id == entries[i].key)
            ? walletColor(
                allCategories
                    .firstWhere((c) => c.id == entries[i].key)
                    .draft
                    .color,
              )
            : _palette[i % _palette.length],
    ];
    final chosen = selected == null ? null : d.categories[selected];
    return WalletCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s('distribution'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          if (entries.isEmpty)
            ChartEmpty(
              icon: Icons.donut_large_rounded,
              title: s('noSpend'),
              body: s('noSpendBody'),
            )
          else ...[
            Center(
              child: SizedBox(
                width: 210,
                height: 210,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ExcludeSemantics(
                      child: CustomPaint(
                        size: const Size(210, 210),
                        painter: _RingPainter(
                          colors: colors,
                          fractions: entries
                              .map(
                                (e) => chartFraction(
                                  e.value.minorUnits,
                                  d.expense.minorUnits,
                                ),
                              )
                              .toList(),
                          selected: entries.indexWhere(
                            (e) => e.key == selected,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(35),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            selected == null
                                ? s('expense')
                                : categoryTitle(selected!),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            dashboardAmount(chosen ?? d.expense),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            for (var i = 0; i < entries.length; i++)
              Builder(
                builder: (context) {
                  final e = entries[i];
                  final percent =
                      ((e.value.minorUnits * BigInt.from(1000)) ~/
                              d.expense.minorUnits)
                          .toInt();
                  final share = '${percent ~/ 10}.${percent % 10}%';
                  final label =
                      '${categoryTitle(e.key)}: ${dashboardAmount(e.value)} · $share ${s('share')}';
                  return Tooltip(
                    message: label,
                    child: ListTile(
                      key: ValueKey('spend-${e.key}'),
                      contentPadding: EdgeInsets.zero,
                      selected: selected == e.key,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      leading: Icon(Icons.circle, size: 12, color: colors[i]),
                      title: Text(categoryTitle(e.key)),
                      subtitle: Text(dashboardAmount(e.value)),
                      trailing: Text(share),
                      onTap: () => setState(
                        () => selected = selected == e.key ? null : e.key,
                      ),
                    ),
                  );
                },
              ),
          ],
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.fractions,
    required this.selected,
    required this.colors,
  });
  final List<Color> colors;
  final List<double> fractions;
  final int selected;
  @override
  void paint(Canvas canvas, Size size) {
    var angle = -math.pi / 2;
    final rect = (Offset.zero & size).deflate(15);
    for (var i = 0; i < fractions.length; i++) {
      final sweep = fractions[i] * math.pi * 2;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected == i ? 24 : 18
        ..color = colors[i].withValues(
          alpha: selected < 0 || selected == i ? 1 : .3,
        );
      canvas.drawArc(rect, angle, sweep, false, paint);
      angle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) => true;
}

class _Legend extends StatelessWidget {
  const _Legend(this.label, this.color);
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.circle, size: 10, color: color),
      const SizedBox(width: 7),
      Text(label),
    ],
  );
}

class ChartEmpty extends StatelessWidget {
  const ChartEmpty({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title, body;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Center(
      child: Column(
        children: [
          Icon(icon, size: 42, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}
