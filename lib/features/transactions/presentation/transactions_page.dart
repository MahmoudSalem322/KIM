import 'package:flutter/material.dart';

import '../../../shared/widgets/empty_feature_page.dart';

class TransactionsPage extends StatelessWidget {
  const TransactionsPage({super.key});
  @override
  Widget build(BuildContext context) => const EmptyFeaturePage(
    feature: 'transactions',
    icon: Icons.swap_horiz_rounded,
  );
}
