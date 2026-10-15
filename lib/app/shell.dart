import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/l10n/app_strings.dart';
import '../features/savings/presentation/savings_copy.dart';
import '../shared/design_system/components.dart';
import 'destinations.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final colors = Theme.of(context).colorScheme;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final selected = destinations.indexWhere(
      (d) =>
          d.path == location ||
          (location == '/categories' && d.path == '/transactions') ||
          (location == '/goals' && d.path == '/budgets') ||
          (location == '/transfers' && d.path == '/wallets') ||
          (d.path != '/' && location.startsWith('${d.path}/')),
    );
    final active = selected < 0 ? 0 : selected;
    return Scaffold(
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: active,
              labelBehavior:
                  NavigationDestinationLabelBehavior.onlyShowSelected,
              onDestinationSelected: (index) =>
                  context.go(destinations[index].path),
              destinations: [
                for (final d in destinations)
                  NavigationDestination(
                    key: ValueKey('nav-${d.key}'),
                    icon: Icon(d.icon),
                    label: s(d.key),
                  ),
              ],
            ),
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (wide)
              Container(
                width: 246,
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: BorderDirectional(
                    end: BorderSide(
                      color: colors.outlineVariant.withValues(alpha: .4),
                    ),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 30, 20, 24),
                child: _ScrollableSidebar(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _Brand(),
                      const SizedBox(height: 40),
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: 14,
                          bottom: 14,
                        ),
                        child: Text(
                          s('workspace'),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: colors.onSurfaceVariant,
                                letterSpacing: 1.4,
                              ),
                        ),
                      ),
                      for (var i = 0; i < destinations.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Material(
                            color: Colors.transparent,
                            child: ListTile(
                              key: ValueKey('nav-${destinations[i].key}'),
                              selected: i == selected,
                              selectedColor: colors.primary,
                              selectedTileColor: colors.primary.withValues(
                                alpha: .09,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              leading: Icon(destinations[i].icon, size: 22),
                              title: Text(
                                s(destinations[i].key),
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              onTap: () => context.go(destinations[i].path),
                            ),
                          ),
                        ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: .05),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.shield_outlined, color: colors.primary),
                            const SizedBox(height: 12),
                            Text(
                              s('private'),
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              s('deviceSub'),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    height: 1.7,
                                    color: colors.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        s('version'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: wide ? 32 : 20,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: colors.outlineVariant.withValues(alpha: .35),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        if (wide) ...[
                          Icon(
                            location == '/goals'
                                ? Icons.savings_outlined
                                : destinations[active].icon,
                            size: 20,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            location == '/goals'
                                ? SavingsCopy.of(context)('navigation')
                                : s(destinations[active].key),
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ] else
                          const SizedBox(
                            width: 210,
                            child: _Brand(compact: true),
                          ),
                        const Spacer(),
                        if (wide)
                          StatusPill(
                            label: s('local'),
                            icon: Icons.storage_rounded,
                          ),
                        if (!wide)
                          Tooltip(
                            message: s('local'),
                            child: Icon(
                              Icons.shield_outlined,
                              color: colors.primary,
                              size: 22,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Contain the nested Navigator's blocking route semantics so
                  // shell navigation remains available to assistive technology.
                  Expanded(
                    child: Semantics(
                      container: true,
                      explicitChildNodes: true,
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: compact ? 32 : 42,
          height: compact ? 32 : 42,
          decoration: BoxDecoration(
            color: colors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.account_balance_wallet_rounded,
            color: colors.onPrimary,
            size: compact ? 18 : 23,
          ),
        ),
        const SizedBox(width: 12),
        const Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Kim',
              textDirection: TextDirection.ltr,
              style: TextStyle(
                fontFamily: 'NotoSans',
                fontWeight: FontWeight.w800,
                fontSize: 22,
                letterSpacing: -.8,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScrollableSidebar extends StatelessWidget {
  const _ScrollableSidebar({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: IntrinsicHeight(child: child),
      ),
    ),
  );
}
