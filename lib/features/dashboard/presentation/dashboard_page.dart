import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../shared/design_system/components.dart';
import 'dashboard_wallet_overview.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s('welcome'), style: theme.textTheme.headlineLarge),
        const SizedBox(height: 8),
        Text(
          s('welcomeSub'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 28),
        LayoutBuilder(
          builder: (context, constraints) {
            final hero = Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF183B43), Color(0xFF0C252D)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome_outlined,
                        size: 18,
                        color: Color(0xFF9AEACD),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          s('tagline'),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: const Color(0xFF9AEACD),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    s('heroTitle'),
                    style: theme.textTheme.headlineLarge?.copyWith(
                      color: Colors.white,
                      fontSize: 36,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    s('heroBody'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFFCFDFDF),
                    ),
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFA3E9CB),
                      foregroundColor: const Color(0xFF123B34),
                    ),
                    onPressed: () => context.go('/wallets'),
                    icon: const Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 18,
                    ),
                    label: Text(s('explore')),
                  ),
                ],
              ),
            );
            const wallet = DashboardWalletOverview();
            if (constraints.maxWidth < 720) {
              return Column(
                children: [hero, const SizedBox(height: 20), wallet],
              );
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 3, child: hero),
                  const SizedBox(width: 24),
                  Expanded(flex: 2, child: wallet),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 28),
        WalletCard(
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s('activity'), style: theme.textTheme.titleLarge),
                const SizedBox(height: 28),
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 36,
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: .6,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        s('noActivity'),
                        style: theme.textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        s('noActivitySub'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(s('essentials'), style: theme.textTheme.titleMedium),
        const SizedBox(height: 16),
        Wrap(
          spacing: 24,
          runSpacing: 16,
          children: [
            _Principle(
              icon: Icons.shield_outlined,
              title: s('private'),
              body: s('deviceSub'),
            ),
            _Principle(
              icon: Icons.calculate_outlined,
              title: s('precision'),
              body: s('precisionSub'),
            ),
          ],
        ),
      ],
    );
  }
}

class _Principle extends StatelessWidget {
  const _Principle({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 420),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                body,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
