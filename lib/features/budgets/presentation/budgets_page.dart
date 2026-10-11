import 'package:flutter/material.dart';

import '../../../shared/widgets/empty_feature_page.dart';

class BudgetsPage extends StatelessWidget {
  const BudgetsPage({super.key});
  @override
  Widget build(BuildContext context) => const EmptyFeaturePage(
    feature: 'budgets',
    icon: Icons.donut_large_rounded,
  );
}
