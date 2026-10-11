import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/design_system/components.dart';
import '../../wallets/presentation/wallet_widgets.dart';
import '../../wallets/presentation/wallet_copy.dart';

class DashboardWalletOverview extends StatelessWidget {
  const DashboardWalletOverview({super.key});
  @override
  Widget build(BuildContext context) => WalletDataView(
    builder: (all) {
      final active = all.where((s) => !s.wallet.archived).toList();
      final s = WalletCopy.of(context);
      return WalletCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 44,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text(
              active.isEmpty ? s('empty') : '${active.length} ${s('count')}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (active.isEmpty)
              Text(s('emptyBody'))
            else
              WalletTotals(wallets: active),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => context.go('/wallets'),
              child: Text(s('back')),
            ),
          ],
        ),
      );
    },
  );
}
