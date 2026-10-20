import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_io.dart';
import 'package:kim/core/data/app_database.dart';
import 'package:kim/core/domain/money.dart';
import 'package:kim/core/domain/operation_id.dart';
import 'package:kim/features/backup/data/backup_repository.dart';
import 'package:kim/features/budgets/data/local_budget_repository.dart';
import 'package:kim/features/budgets/domain/budget.dart';
import 'package:kim/features/dashboard/domain/dashboard_summary.dart';
import 'package:kim/features/debts/data/local_debt_repository.dart';
import 'package:kim/features/debts/domain/debt.dart';
import 'package:kim/features/recurring/data/local_recurring_repository.dart';
import 'package:kim/features/recurring/domain/recurring_payment.dart';
import 'package:kim/features/reports/data/local_exchange_repository.dart';
import 'package:kim/features/reports/domain/exchange_book.dart';
import 'package:kim/features/reports/domain/financial_report.dart';
import 'package:kim/features/savings/data/local_savings_repository.dart';
import 'package:kim/features/savings/domain/savings_goal.dart';
import 'package:kim/features/transactions/data/local_transaction_repository.dart';
import 'package:kim/features/transactions/domain/financial_transaction.dart';
import 'package:kim/features/transfers/data/local_transfer_repository.dart';
import 'package:kim/features/transfers/domain/exchange_rate.dart';
import 'package:kim/features/transfers/domain/wallet_transfer.dart';
import 'package:kim/features/wallets/data/local_wallet_repository.dart';
import 'package:kim/features/wallets/domain/wallet.dart';

/// One complete financial cycle on a real on-disk database, reopened between
/// stages like a browser reload. Every balance is recomputed independently
/// from the effective records and compared with the append-only ledger.
void main() {
  final ils = Currency('ILS', 2), usd = Currency('USD', 2);
  Money m(String v, [Currency? c]) => Money.parse(v, c ?? ils);
  WalletOperation at(int day, [int hour = 12]) =>
      WalletOperation(OperationId.generate(), DateTime(2026, 10, day, hour));

  late Directory directory;
  late String path;
  late AppDatabase db;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('kim-lifecycle-');
    path = '${directory.path}${Platform.pathSeparator}workspace.db';
    db = await AppDatabase.open(databaseFactoryIo, path);
  });
  tearDown(() async {
    await db.close();
    await directory.delete(recursive: true);
  });

  Future<void> reload() async {
    await db.close();
    db = await AppDatabase.open(databaseFactoryIo, path);
  }

  LocalWalletRepository wallets() => LocalWalletRepository(db);
  Future<Map<String, int>> revisions() async => {
    for (final w in await wallets().load()) w.wallet.id: w.wallet.revision,
  };
  Future<Map<String, String>> balances() async => {
    for (final w in await wallets().load()) w.wallet.name: w.balance.decimal,
  };

  /// Opening + adjustments + effective income/expense + live transfers + live
  /// debt cash events must equal the ledger balance for every wallet.
  Future<void> expectLedgerMatchesRecords() async {
    final snapshots = await wallets().load();
    final expected = <String, BigInt>{};
    for (final s in snapshots) {
      expected[s.wallet.id] = s.entries
          .where(
            (e) =>
                e.kind == WalletEntryKind.opening ||
                e.kind == WalletEntryKind.adjustment,
          )
          .fold(BigInt.zero, (v, e) => v + e.delta.minorUnits);
    }
    for (final t in await LocalTransactionRepository(db).load()) {
      if (t.deleted) continue;
      expected[t.walletId] = expected[t.walletId]! + t.draft.effect.minorUnits;
    }
    for (final t in await LocalTransferRepository(db).load()) {
      if (t.cancelled) continue;
      expected[t.draft.sourceId] =
          expected[t.draft.sourceId]! - t.draft.amount.minorUnits;
      expected[t.draft.destinationId] =
          expected[t.draft.destinationId]! + t.received.minorUnits;
    }
    for (final d in await LocalDebtRepository(db).load()) {
      for (final e in d.events.where((e) => !e.cancelled)) {
        expected[e.draft.walletId] =
            expected[e.draft.walletId]! +
            e.draft.effect(d.debt.draft.direction).minorUnits;
      }
    }
    for (final s in snapshots) {
      expect(
        s.balance.minorUnits,
        expected[s.wallet.id],
        reason: 'ledger and records disagree for ${s.wallet.name}',
      );
    }
  }

  test('complete cycle stays exact across edits, deletions, reloads, backup and restore', () async {
    // 1. Wallets with exact opening balances.
    final cash = await wallets().create(
      at(1, 8),
      WalletDraft(
        name: 'Cash',
        color: 'emerald',
        icon: 'cash',
        type: 'cash',
        currency: ils,
      ),
      m('1000.00'),
    );
    final bank = await wallets().create(
      at(1, 8),
      WalletDraft(
        name: 'Bank',
        color: 'navy',
        icon: 'bank',
        type: 'bank',
        currency: usd,
      ),
      m('2000.00', usd),
    );
    final vault = await wallets().create(
      at(1, 8),
      WalletDraft(
        name: 'Vault',
        color: 'purple',
        icon: 'savings',
        type: 'savings',
        currency: ils,
      ),
      m('0'),
    );

    // 2. Income and expenses, then an edit and a deletion.
    final tx = LocalTransactionRepository(db);
    await tx.create(
      at(1),
      TransactionDraft(
        walletId: cash,
        kind: TransactionKind.income,
        amount: m('5000.00'),
        category: 'salary',
        date: '2026-10-01',
      ),
      await revisions(),
    );
    final food = await tx.create(
      at(2),
      TransactionDraft(
        walletId: cash,
        kind: TransactionKind.expense,
        amount: m('120.50'),
        category: 'food',
        date: '2026-10-02',
        notes: 'سوق',
      ),
      await revisions(),
    );
    final bills = await tx.create(
      at(3),
      TransactionDraft(
        walletId: cash,
        kind: TransactionKind.expense,
        amount: m('300'),
        category: 'bills',
        date: '2026-10-03',
      ),
      await revisions(),
    );
    expect((await balances())['Cash'], '5579.50');
    await reload();
    final foodRow = (await LocalTransactionRepository(
      db,
    ).load()).singleWhere((t) => t.id == food);
    await LocalTransactionRepository(db).edit(
      at(4),
      food,
      foodRow.revision,
      TransactionDraft(
        walletId: cash,
        kind: TransactionKind.expense,
        amount: m('150.25'),
        category: 'food',
        date: '2026-10-02',
        notes: 'سوق',
      ),
      await revisions(),
    );
    final billsRow = (await LocalTransactionRepository(
      db,
    ).load()).singleWhere((t) => t.id == bills);
    await LocalTransactionRepository(db)
        .delete(at(4), bills, billsRow.revision, await revisions());
    expect((await balances())['Cash'], '5849.75');
    await expectLedgerMatchesRecords();

    // 3. Cross-currency transfer with fee, and a same-currency transfer that is
    // edited and then cancelled; cancellation fully restores both wallets.
    final transfers = LocalTransferRepository(db);
    await transfers.create(
      at(5),
      TransferDraft(
        sourceId: bank,
        destinationId: cash,
        amount: m('100', usd),
        fee: m('2', usd),
        rate: ExchangeRate.parse('3.7'),
      ),
      await revisions(),
    );
    final move = await transfers.create(
      at(6),
      TransferDraft(
        sourceId: cash,
        destinationId: vault,
        amount: m('900'),
        fee: m('0'),
        rate: ExchangeRate.parse('1'),
      ),
      await revisions(),
    );
    var moveRow = (await transfers.load()).singleWhere((t) => t.id == move);
    await transfers.edit(
      at(6, 13),
      move,
      moveRow.revision,
      TransferDraft(
        sourceId: cash,
        destinationId: vault,
        amount: m('1000'),
        fee: m('0'),
        rate: ExchangeRate.parse('1'),
      ),
      await revisions(),
    );
    expect(await balances(), {
      'Cash': '5219.75',
      'Bank': '1898.00',
      'Vault': '1000.00',
    });
    final spare = await transfers.create(
      at(6, 14),
      TransferDraft(
        sourceId: cash,
        destinationId: vault,
        amount: m('10.01'),
        fee: m('0'),
        rate: ExchangeRate.parse('1'),
      ),
      await revisions(),
    );
    moveRow = (await transfers.load()).singleWhere((t) => t.id == spare);
    await transfers.cancel(
      at(6, 15),
      spare,
      moveRow.revision,
      await revisions(),
    );
    expect((await balances())['Cash'], '5219.75');
    await reload();
    await expectLedgerMatchesRecords();

    // 4. Budget usage follows edits and threshold crossings.
    final budgets = LocalBudgetRepository(db);
    await budgets.create(
      at(7),
      BudgetDraft(
        name: 'Food',
        limit: m('500'),
        cycle: BudgetCycle.monthly,
        startsOn: '2026-10-01',
        category: 'food',
      ),
    );
    Future<BudgetUsage> currentUsage() async => BudgetUsage(
      (await LocalBudgetRepository(db).load()).single,
      DateTime(2026, 10, 15),
      await LocalTransactionRepository(db).load(),
      await wallets().load(),
    );
    var budget = await currentUsage();
    expect(budget.spent.decimal, '150.25');
    expect(budget.remaining.decimal, '349.75');
    expect(budget.percentage, '30.0%');
    expect(budget.crossed, isNull);
    await LocalTransactionRepository(db).create(
      at(8),
      TransactionDraft(
        walletId: cash,
        kind: TransactionKind.expense,
        amount: m('260'),
        category: 'food',
        date: '2026-10-08',
      ),
      await revisions(),
    );
    budget = await currentUsage();
    expect(budget.spent.decimal, '410.25');
    expect(budget.percentage, '82.0%');
    expect(budget.crossed, 80);

    // 5. Savings reservation protects earmarked money from overspending.
    final savings = LocalSavingsRepository(db);
    final goal = await savings.create(
      at(9),
      GoalDraft(
        name: 'Trip',
        target: m('3000'),
        dueOn: '2027-06-01',
        color: 'blue',
        icon: 'travel',
      ),
    );
    await savings.allocate(
      at(9, 13),
      goal,
      0,
      vault,
      (await revisions())[vault]!,
      m('800'),
      'first',
    );
    await expectLater(
      LocalTransactionRepository(db).create(
        at(10),
        TransactionDraft(
          walletId: vault,
          kind: TransactionKind.expense,
          amount: m('300'),
          category: 'shopping',
          date: '2026-10-10',
        ),
        await revisions(),
      ),
      throwsA(isA<WalletFailure>().having((e) => e.code, 'code', 'reserved')),
    );
    await LocalTransactionRepository(db).create(
      at(10),
      TransactionDraft(
        walletId: vault,
        kind: TransactionKind.expense,
        amount: m('150'),
        category: 'shopping',
        date: '2026-10-10',
      ),
      await revisions(),
    );
    final goalSnapshot = (await savings.load()).single;
    expect(goalSnapshot.allocated.decimal, '800.00');
    expect(goalSnapshot.remaining.decimal, '2200.00');
    expect((await balances())['Vault'], '850.00');

    // 6. Debt: principal received, payment recorded, edited, then cancelled.
    final debts = LocalDebtRepository(db);
    final debt = await debts.create(
      at(11),
      DebtDraft(
        direction: DebtDirection.borrowed,
        person: 'صديق',
        principal: m('1000'),
        dueOn: '2026-12-31',
      ),
    );
    Future<DebtSnapshot> debtRow() async => (await LocalDebtRepository(
      db,
    ).load()).singleWhere((d) => d.debt.id == debt);
    await debts.record(
      at(11, 13),
      debt,
      (await debtRow()).debt.revision,
      DebtCashDraft(
        kind: DebtEventKind.principal,
        walletId: cash,
        amount: m('1000'),
        date: '2026-10-11',
      ),
      await revisions(),
    );
    final payment = await debts.record(
      at(12),
      debt,
      (await debtRow()).debt.revision,
      DebtCashDraft(
        kind: DebtEventKind.payment,
        walletId: cash,
        amount: m('400'),
        date: '2026-10-12',
      ),
      await revisions(),
    );
    expect((await debtRow()).remaining.decimal, '600.00');
    expect((await balances())['Cash'], '5559.75');
    var event = (await debtRow()).events.singleWhere((e) => e.id == payment);
    await debts.editCash(
      at(12, 13),
      payment,
      event.revision,
      (await debtRow()).debt.revision,
      DebtCashDraft(
        kind: DebtEventKind.payment,
        walletId: cash,
        amount: m('250'),
        date: '2026-10-12',
      ),
      await revisions(),
    );
    expect((await debtRow()).remaining.decimal, '750.00');
    await reload();
    event = (await debtRow()).events.singleWhere((e) => e.id == payment);
    await LocalDebtRepository(db).cancelCash(
      at(12, 14),
      payment,
      event.revision,
      (await debtRow()).debt.revision,
      await revisions(),
    );
    expect((await debtRow()).remaining.decimal, '1000.00');
    expect((await debtRow()).status(DateTime(2026, 10, 20)), DebtStatus.active);
    expect((await balances())['Cash'], '5959.75');
    await expectLedgerMatchesRecords();

    // 7. Automatic subscription processes once, even when processing repeats.
    final plans = LocalRecurringRepository(db);
    await plans.create(
      at(13),
      RecurringDraft(
        name: 'Internet',
        amount: m('99.99'),
        walletId: cash,
        cycle: RecurringCycle.monthly,
        nextDate: '2026-10-05',
        category: 'bills',
        automatic: true,
      ),
    );
    final first = await plans.processDue(DateTime(2026, 10, 20));
    expect(first.recorded, 1);
    await reload();
    final again = await LocalRecurringRepository(db)
        .processDue(DateTime(2026, 10, 20));
    expect(again.recorded, 0);
    expect(
      (await LocalRecurringRepository(db).load()).single.draft.nextDate,
      '2026-11-05',
    );
    expect(await balances(), {
      'Cash': '5859.76',
      'Bank': '1898.00',
      'Vault': '850.00',
    });
    await expectLedgerMatchesRecords();

    // 8. Reports and dashboard agree on exact totals with a documented rate.
    await LocalExchangeRepository(db).save(at(14), 0, ils, [
      ManualRate(
        from: usd,
        to: ils,
        decimal: '3.7',
        source: 'Bank quote',
        asOf: '2026-10-14',
        updatedAt: DateTime.utc(2026, 10, 14),
      ),
    ]);
    final book = await LocalExchangeRepository(db).load();
    final report = ReportResult.calculate(
      filter: ReportFilter(from: '2026-10-01', to: '2026-10-31'),
      book: book,
      wallets: await wallets().load(),
      transactions: await LocalTransactionRepository(db).load(),
      transfers: await LocalTransferRepository(db).load(),
      debts: await LocalDebtRepository(db).load(),
    );
    // Food 150.25 + 260 + shopping 150 + internet 99.99 + 2 USD fee (7.40 ILS).
    expect(report.income.decimal, '5000.00');
    expect(report.expense.decimal, '667.64');
    expect(report.operatingNet.decimal, '4332.36');
    expect(report.debtNet.decimal, '1000.00');
    expect(report.complete, true);
    expect(report.categories['food']!.decimal, '410.25');
    final dashboard = DashboardSummary(
      wallets: await wallets().load(),
      transactions: await LocalTransactionRepository(db).load(),
      currency: ils,
      period: DashboardPeriod(DateTime(2026, 10, 1), DateTime(2026, 10, 31)),
      exchangeBook: book,
    );
    expect(dashboard.income.decimal, report.income.decimal);
    expect(dashboard.expense.decimal, report.expense.decimal);
    // 5859.76 + 850 + 1898 USD × 3.7 = 7022.60.
    expect(dashboard.balance.decimal, '13732.36');
    expect(dashboard.excludedCurrencies, isEmpty);

    // 9. Backup, diverge, restore: the workspace returns byte-for-byte and the
    // ledger is still consistent after a reload.
    final backup = BackupRepository(db);
    final reference = canonicalBackup(await backup.snapshot());
    final checked = await backup.inspect(
      await backup.create(password: 'lifecycle password'),
      password: 'lifecycle password',
    );
    await LocalTransactionRepository(db).create(
      at(15),
      TransactionDraft(
        walletId: cash,
        kind: TransactionKind.expense,
        amount: m('59.76'),
        category: 'food',
        date: '2026-10-15',
      ),
      await revisions(),
    );
    expect((await balances())['Cash'], '5800.00');
    await backup.restore(await backup.preview(checked), 'lifecycle-restore');
    await reload();
    expect(canonicalBackup(await BackupRepository(db).snapshot()), reference);
    expect(await balances(), {
      'Cash': '5859.76',
      'Bank': '1898.00',
      'Vault': '850.00',
    });
    expect(
      (await LocalSavingsRepository(db).load()).single.allocated.decimal,
      '800.00',
    );
    expect((await debtRow()).remaining.decimal, '1000.00');
    await expectLedgerMatchesRecords();

    // Recovery copy brings back the diverged workspace, still consistent.
    final recovery = await BackupRepository(db).previous();
    await BackupRepository(
      db,
    ).restore(await BackupRepository(db).preview(recovery!), 'lifecycle-back');
    await reload();
    expect((await balances())['Cash'], '5800.00');
    await expectLedgerMatchesRecords();
    // The processed subscription is not re-recorded after restore + reload.
    expect(
      (await LocalRecurringRepository(db).processDue(DateTime(2026, 10, 20)))
          .recorded,
      0,
    );
  });
}
