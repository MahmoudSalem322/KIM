import 'package:flutter/material.dart';

import '../../../shared/widgets/empty_feature_page.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const EmptyFeaturePage(feature: 'reports', icon: Icons.bar_chart_rounded);
}
