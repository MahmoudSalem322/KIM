import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/l10n/app_strings.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/categories/presentation/categories_page.dart';
import '../features/wallets/presentation/wallets_page.dart';
import '../features/wallets/presentation/wallet_detail_page.dart';
import '../features/transactions/presentation/transactions_page.dart';
import '../features/budgets/presentation/budgets_page.dart';
import '../features/savings/presentation/savings_page.dart';
import '../features/recurring/presentation/recurring_page.dart';
import '../features/notifications/presentation/notifications_page.dart';
import '../features/debts/presentation/debts_page.dart';
import '../features/reports/presentation/reports_page.dart';
import '../features/reports/presentation/currency_management_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../shared/design_system/components.dart';
import '../shared/widgets/page_viewport.dart';
import 'shell.dart';
import '../features/transfers/presentation/transfers_page.dart';

final launchLocationProvider = Provider<String?>((ref) => null);
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: ref.watch(launchLocationProvider),
    overridePlatformDefaultLocation: ref.watch(launchLocationProvider) != null,
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const PageViewport(child: DashboardPage()),
          ),
          GoRoute(
            path: '/wallets',
            builder: (_, _) => const PageViewport(child: WalletsPage()),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) => PageViewport(
                  child: WalletDetailPage(id: state.pathParameters['id']!),
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/transactions',
            builder: (_, _) => const PageViewport(child: TransactionsPage()),
          ),
          GoRoute(
            path: '/categories',
            builder: (_, _) => const PageViewport(child: CategoriesPage()),
          ),
          GoRoute(
            path: '/transfers',
            builder: (_, _) => const PageViewport(child: TransfersPage()),
          ),
          GoRoute(
            path: '/budgets',
            builder: (_, _) => const PageViewport(child: BudgetsPage()),
          ),
          GoRoute(
            path: '/goals',
            builder: (_, _) => const PageViewport(child: SavingsPage()),
          ),
          GoRoute(
            path: '/recurring',
            builder: (_, _) => const PageViewport(child: RecurringPage()),
          ),
          GoRoute(
            path: '/notifications',
            builder: (_, _) => const PageViewport(child: NotificationsPage()),
          ),
          GoRoute(
            path: '/debts',
            builder: (_, _) => const PageViewport(child: DebtsPage()),
          ),
          GoRoute(
            path: '/reports',
            builder: (_, _) => const PageViewport(child: ReportsPage()),
          ),
          GoRoute(
            path: '/currencies',
            builder: (_, _) =>
                const PageViewport(child: CurrencyManagementPage()),
          ),
          GoRoute(
            path: '/settings',
            builder: (_, _) => const PageViewport(child: SettingsPage()),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => AppShell(
      location: state.uri.path,
      child: PageViewport(
        child: WalletCard(
          child: Column(
            children: [
              const Icon(Icons.explore_off_rounded, size: 64),
              const SizedBox(height: 24),
              Text(AppStrings.of(context)('notFound')),
              const SizedBox(height: 24),
              WalletButton(
                label: AppStrings.of(context)('goHome'),
                onPressed: () => context.go('/'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  ref.onDispose(router.dispose);
  return router;
});
