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
          SizedBox(
            height: 360,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: wallets.length,
              separatorBuilder: (_, _) => const SizedBox(width: 16),
              itemBuilder: (_, i) => SizedBox(
                width: 285,
                child: FinancialWalletCard(
                  snapshot: wallets[i],
                  showOrdering: false,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
