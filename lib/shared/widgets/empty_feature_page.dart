import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../design_system/components.dart';

class EmptyFeaturePage extends StatelessWidget {
  const EmptyFeaturePage({
    super.key,
    required this.feature,
    required this.icon,
  });
  final String feature;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s(feature), style: theme.textTheme.headlineLarge),
        const SizedBox(height: 28),
        WalletCard(
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 64),
              child: Column(
                children: [
                  Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: Icon(
                      icon,
                      size: 48,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    s('${feature}Title'),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Text(
                      s('${feature}Body'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  StatusPill(
                    label: s('foundation'),
                    icon: Icons.layers_outlined,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
