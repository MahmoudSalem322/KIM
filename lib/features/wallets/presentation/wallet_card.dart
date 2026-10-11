import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../domain/wallet.dart';
import 'wallet_copy.dart';
import 'wallet_widgets.dart';

class FinancialWalletCard extends StatelessWidget {
  const FinancialWalletCard({
    super.key,
    required this.snapshot,
    this.moveUp,
    this.moveDown,
    this.orderKey = '',
  });
  final WalletSnapshot snapshot;
  final Future<void> Function()? moveUp, moveDown;
  final String orderKey;
  @override
  Widget build(BuildContext context) {
    final w = snapshot.wallet, s = WalletCopy.of(context);
    final color = walletColor(w.color);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, Color.lerp(color, Colors.black, .35)!],
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => context.go('/wallets/${w.id}'),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(walletIcon(w.icon), color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        w.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(color: Colors.white),
                      ),
                    ),
                    if (w.archived)
                      const Icon(
                        Icons.inventory_2_outlined,
                        color: Colors.white70,
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  s('balance'),
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      w.hidden
                          ? '••••••'
                          : '${snapshot.balance.decimal} ${w.currency.code}',
                      textDirection: TextDirection.ltr,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${s(w.type)} · ${w.currency.code}',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 20),
                TextButton.icon(
                  onPressed: () => context.go('/wallets/${w.id}'),
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  icon: const Icon(Icons.arrow_outward_rounded, size: 18),
                  label: Text(s('details')),
                ),
                const SizedBox(height: 10),
                Theme(
                  data: Theme.of(context).copyWith(
                    outlinedButtonTheme: OutlinedButtonThemeData(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        disabledForegroundColor: Colors.white38,
                        side: const BorderSide(color: Colors.white38),
                      ),
                    ),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      WalletActionButton(
                        key: ValueKey('hide-${w.id}'),
                        label: s(w.hidden ? 'show' : 'hide'),
                        icon: w.hidden
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        requestKey: 'hide-${w.id}-${w.revision}-${w.hidden}',
                        action: (repo, op) =>
                            repo.setHidden(op, w.id, w.revision, !w.hidden),
                      ),
                      if (!w.archived) ...[
                        IconButton(
                          key: ValueKey('up-${w.id}'),
                          tooltip: s('moveUp'),
                          color: Colors.white,
                          disabledColor: Colors.white38,
                          onPressed: moveUp,
                          icon: const Icon(Icons.arrow_upward_rounded),
                        ),
                        IconButton(
                          key: ValueKey('down-${w.id}'),
                          tooltip: s('moveDown'),
                          color: Colors.white,
                          disabledColor: Colors.white38,
                          onPressed: moveDown,
                          icon: const Icon(Icons.arrow_downward_rounded),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
