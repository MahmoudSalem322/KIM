import 'package:flutter/material.dart';

import '../../../shared/widgets/empty_feature_page.dart';

class WalletsPage extends StatelessWidget {
  const WalletsPage({super.key});
  @override
  Widget build(BuildContext context) => const EmptyFeaturePage(
    feature: 'wallets',
    icon: Icons.account_balance_wallet_outlined,
  );
}
