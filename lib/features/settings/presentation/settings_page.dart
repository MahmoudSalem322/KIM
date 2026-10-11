import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../shared/design_system/components.dart';
import '../domain/app_settings.dart';
import 'settings_controller.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    return Column(
      key: const ValueKey('settings-page'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s('settings'), style: theme.textTheme.headlineLarge),
        const SizedBox(height: 8),
        Text(
          s('settingsSub'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 28),
        _SettingsCard(
          title: s('appearance'),
          subtitle: s('appearanceSub'),
          icon: Icons.palette_outlined,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final mode in AppTheme.values)
                _Option(
                  key: ValueKey('theme-${mode.name}'),
                  label: s(mode.name),
                  icon: switch (mode) {
                    AppTheme.system => Icons.brightness_auto_outlined,
                    AppTheme.light => Icons.light_mode_outlined,
                    AppTheme.dark => Icons.dark_mode_outlined,
                  },
                  selected: state.settings.theme == mode,
                  onTap: state.isSaving
                      ? null
                      : () => controller.setTheme(mode),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _SettingsCard(
          title: s('language'),
          subtitle: s('languageSub'),
          icon: Icons.language_rounded,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _Option(
                key: const ValueKey('language-ar'),
                label: 'العربية',
                selected: state.settings.languageCode == 'ar',
                onTap: state.isSaving
                    ? null
                    : () => controller.setLanguage('ar'),
              ),
              _Option(
                key: const ValueKey('language-en'),
                label: 'English',
                selected: state.settings.languageCode == 'en',
                onTap: state.isSaving
                    ? null
                    : () => controller.setLanguage('en'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _SettingsCard(
          title: s('storage'),
          subtitle: s('storageBody'),
          icon: Icons.shield_outlined,
          child: WalletButton(
            secondary: true,
            label: s('learnMore'),
            icon: Icons.info_outline_rounded,
            onPressed: () => showWalletInfo(
              context,
              title: s('storage'),
              body: s('storageDetails'),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Icon(
              state.error != null
                  ? Icons.error_outline
                  : state.isSaving
                  ? Icons.sync
                  : Icons.check_circle_outline,
              size: 17,
              color: state.error != null
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                s(
                  state.error != null
                      ? 'saveError'
                      : state.isSaving
                      ? 'saving'
                      : 'saved',
                ),
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  @override
  Widget build(BuildContext context) => WalletCard(
    child: SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    ),
  );
}

class _Option extends StatelessWidget {
  const _Option({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return MergeSemantics(
      child: Semantics(
        selected: selected,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: selected
                ? colors.primary
                : colors.onSurfaceVariant,
            backgroundColor: selected
                ? colors.primary.withValues(alpha: .07)
                : null,
            side: BorderSide(
              color: selected ? colors.primary : colors.outlineVariant,
              width: selected ? 1.5 : 1,
            ),
          ),
          onPressed: onTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 19),
                const SizedBox(width: 10),
              ],
              Text(label),
              if (selected) ...[
                const SizedBox(width: 14),
                const Icon(Icons.check_rounded, size: 18),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
