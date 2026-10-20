import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/design_system/components.dart';
import '../../wallets/domain/wallet.dart';
import '../../wallets/presentation/wallet_card.dart';
import 'dashboard_copy.dart';

class DashboardWalletOverview extends StatelessWidget {
  const DashboardWalletOverview({super.key, required this.wallets});
  final List<WalletSnapshot> wallets;
  @override
  Widget build(BuildContext context) {
    final s = DashboardCopy.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '${s('wallets')} · ${wallets.length} ${s('active')}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            TextButton(
              onPressed: () => context.go('/wallets'),
              child: Text(s('manage')),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (wallets.isEmpty)
          WalletCard(child: Text(s('noWallets')))
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < wallets.length; i++) ...[
                  if (i > 0) const SizedBox(width: 16),
                  SizedBox(
                    width: 285,
                    child: FinancialWalletCard(
                      snapshot: wallets[i],
                      showOrdering: false,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
