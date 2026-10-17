import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/data/app_database.dart';
import '../features/recurring/data/local_recurring_repository.dart';
import '../features/recurring/presentation/recurring_providers.dart';
import '../features/notifications/data/local_notice_repository.dart';
import '../features/notifications/presentation/notification_providers.dart';
import '../features/notifications/presentation/recurring_runtime.dart';
import '../features/debts/data/local_debt_repository.dart';
import '../features/debts/presentation/debt_providers.dart';
import '../features/savings/data/local_savings_repository.dart';
import '../features/savings/presentation/savings_providers.dart';
import '../core/data/open_database.dart';
import '../core/l10n/app_strings.dart';
import '../features/categories/data/local_category_repository.dart';
import '../features/categories/presentation/category_providers.dart';
import '../features/budgets/data/local_budget_repository.dart';
import '../features/budgets/presentation/budget_providers.dart';
import '../features/settings/data/local_settings_repository.dart';
import '../features/settings/domain/app_settings.dart';
import '../features/settings/presentation/settings_controller.dart';
import '../features/wallets/data/local_wallet_repository.dart';
import '../features/wallets/presentation/wallet_providers.dart';
import '../features/transactions/data/local_transaction_repository.dart';
import '../features/transactions/presentation/transaction_providers.dart';
import '../shared/design_system/app_theme.dart';
import '../shared/design_system/components.dart';
import 'kim_app.dart';
import '../features/transfers/data/local_transfer_repository.dart';
import '../features/transfers/presentation/transfer_providers.dart';

typedef BootstrapData = ({
  AppDatabase db,
  LocalSettingsRepository repository,
  AppSettings settings,
});

Future<BootstrapData> initializeWorkspace() async {
  final db = await openAppDatabase();
  try {
    final repository = LocalSettingsRepository(db);
    final settings = await repository.load();
    return (db: db, repository: repository, settings: settings);
  } catch (_) {
    await db.close();
    rethrow;
  }
}

class WorkspaceBootstrap extends StatefulWidget {
  const WorkspaceBootstrap({super.key});
  @override
  State<WorkspaceBootstrap> createState() => _WorkspaceBootstrapState();
}

class _WorkspaceBootstrapState extends State<WorkspaceBootstrap> {
  late Future<BootstrapData> _initialization = _initialize();
  AppDatabase? _db;
  Future<BootstrapData> _initialize() async {
    final result = await initializeWorkspace();
    if (!mounted) {
      await result.db.close();
    } else {
      _db = result.db;
    }
    return result;
  }

  @override
  void dispose() {
    _db?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<BootstrapData>(
    future: _initialization,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        final result = snapshot.requireData;
        return ProviderScope(
          overrides: [
            recurringRepositoryProvider.overrideWithValue(
              LocalRecurringRepository(result.db),
            ),
            noticeRepositoryProvider.overrideWithValue(
              LocalNoticeRepository(result.db),
            ),
            debtRepositoryProvider.overrideWithValue(
              LocalDebtRepository(result.db),
            ),
            savingsRepositoryProvider.overrideWithValue(
              LocalSavingsRepository(result.db),
            ),
            categoryRepositoryProvider.overrideWithValue(
              LocalCategoryRepository(result.db),
            ),
            budgetRepositoryProvider.overrideWithValue(
              LocalBudgetRepository(result.db),
            ),
            settingsRepositoryProvider.overrideWithValue(result.repository),
            initialSettingsProvider.overrideWithValue(result.settings),
            walletRepositoryProvider.overrideWithValue(
              LocalWalletRepository(result.db),
            ),
            transactionRepositoryProvider.overrideWithValue(
              LocalTransactionRepository(result.db),
            ),
            transferRepositoryProvider.overrideWithValue(
              LocalTransferRepository(result.db),
            ),
          ],
          child: const RecurringRuntime(child: KimApp()),
        );
      }
      return _StartupView(
        child: Scaffold(
          body: Center(
            child: snapshot.hasError
                ? Builder(
                    builder: (context) {
                      final s = AppStrings.of(context);
                      return ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 540),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: WalletCard(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.storage_rounded, size: 48),
                                const SizedBox(height: 24),
                                Text(
                                  s('startupError'),
                                  style: Theme.of(context).textTheme.titleLarge,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  s('startupBody'),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                WalletButton(
                                  label: s('retry'),
                                  onPressed: () => setState(() {
                                    _initialization = _initialize();
                                  }),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  )
                : const CircularProgressIndicator(),
          ),
        ),
      );
    },
  );
}

// Startup must not create a Navigator: it would consume the browser's initial
// route before the database is ready and GoRouter can restore the requested page.
class _StartupView extends StatelessWidget {
  const _StartupView({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => MediaQuery.fromView(
    view: View.of(context),
    child: Localizations(
      locale: const Locale('ar'),
      delegates: GlobalMaterialLocalizations.delegates,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Theme(
          data: AppThemeData.build(Brightness.light, 'ar'),
          child: child,
        ),
      ),
    ),
  );
}
