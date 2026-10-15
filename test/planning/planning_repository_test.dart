import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_io.dart';
import 'package:uuid/uuid.dart';
import 'package:kim/core/data/app_database.dart';
import 'package:kim/core/domain/money.dart';
import 'package:kim/features/categories/data/local_category_repository.dart';
import 'package:kim/features/categories/domain/app_category.dart';
import 'package:kim/features/budgets/data/local_budget_repository.dart';
import 'package:kim/features/budgets/domain/budget.dart';
import 'package:kim/features/transactions/data/local_transaction_repository.dart';
import 'package:kim/features/transactions/domain/financial_transaction.dart';
import 'package:kim/features/transfers/data/local_transfer_repository.dart';
import 'package:kim/features/transfers/domain/wallet_transfer.dart';
import 'package:kim/features/transfers/domain/exchange_rate.dart';
import 'package:kim/features/wallets/data/local_wallet_repository.dart';
import 'package:kim/features/wallets/domain/wallet.dart';

void main() {
  final ils = Currency('ILS', 2), usd = Currency('USD', 2);
  late Directory dir;
  late AppDatabase db;
  late LocalCategoryRepository categories;
  late LocalBudgetRepository budgets;
  late LocalWalletRepository wallets;
  late LocalTransactionRepository transactions;
  Future<void> open() async {
    db = await AppDatabase.open(databaseFactoryIo, '${dir.path}/data.db');
    categories = LocalCategoryRepository(db);
    budgets = LocalBudgetRepository(db);
    wallets = LocalWalletRepository(db);
    transactions = LocalTransactionRepository(db);
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('kim-planning-');
    await open();
  });
  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });
  CategoryDraft category({
    String name = 'Coffee',
    TransactionKind kind = TransactionKind.expense,
  }) => CategoryDraft(name: name, kind: kind, color: 'purple', icon: 'coffee');
  Future<String> wallet({Currency? currency}) => wallets.create(
    WalletOperation.generate(),
    WalletDraft(
      name: 'Cash',
      color: 'emerald',
      icon: 'wallet',
      type: 'cash',
      currency: currency ?? ils,
    ),
    Money.parse('1000000000000000000000', currency ?? ils),
  );
  Future<Map<String, int>> revisions() async => {
    for (final w in await wallets.load()) w.wallet.id: w.wallet.revision,
  };
  Future<String> expense(
    String id,
    String amount, {
    String category = 'food',
    String date = '2026-10-15',
    Currency? currency,
    TransactionKind kind = TransactionKind.expense,
  }) async => transactions.create(
    WalletOperation.generate(),
    TransactionDraft(
      walletId: id,
      kind: kind,
      amount: Money.parse(amount, currency ?? ils),
      category: category,
      date: date,
    ),
    await revisions(),
  );
  BudgetDraft draft({
    String category = '',
    Currency? currency,
    String amount = '100',
    BudgetCycle cycle = BudgetCycle.monthly,
    String starts = '2026-01-01',
    List<int> thresholds = const [50, 80, 100],
  }) => BudgetDraft(
    name: 'Plan',
    limit: Money.parse(amount, currency ?? ils),
    cycle: cycle,
    startsOn: starts,
    category: category,
    thresholds: thresholds,
  );
  Future<BudgetUsage> usage(String id, {DateTime? date}) async => BudgetUsage(
    (await budgets.load()).singleWhere((b) => b.id == id),
    date ?? DateTime(2026, 10, 15),
    await transactions.load(),
    await wallets.load(),
  );
  final failure = isA<WalletFailure>();

  test(
    'seeded categories and exact custom metadata survive restart and replay',
    () async {
      expect((await categories.load()).length, defaultCategories().length);
      final op = WalletOperation.generate(), d = category();
      final id = await categories.create(op, d);
      await categories.create(op, d);
      await db.close();
      await open();
      final c = (await categories.load()).singleWhere((c) => c.id == id);
      expect(c.draft.name, 'Coffee');
      expect(c.draft.icon, 'coffee');
      expect(c.draft.color, 'purple');
      expect((await categories.load()).length, defaultCategories().length + 1);
      await expectLater(
        categories.create(op, category(name: 'Other')),
        throwsStateError,
      );
    },
  );
  test('category names are unique per kind and concurrent requests cannot duplicate', () async {
    await categories.create(WalletOperation.generate(), category());
    await expectLater(
      categories.create(WalletOperation.generate(), category(name: ' coffee ')),
      throwsA(failure),
    );
    final incomeId = await categories.create(
      WalletOperation.generate(),
      category(kind: TransactionKind.income),
    );
    final w = await wallet();
    await expense(w, '10', category: incomeId, kind: TransactionKind.income);
    expect(
      (await transactions.load()).single.draft.kind,
      TransactionKind.income,
    );
    await expectLater(
      budgets.create(WalletOperation.generate(), draft(category: incomeId)),
      throwsA(failure),
    );
    final op = WalletOperation.generate();
    await Future.wait([
      categories.create(op, category(name: 'Travel')),
      categories.create(op, category(name: 'Travel')),
    ]);
    expect(
      (await categories.load()).where((c) => c.draft.name == 'Travel').length,
      1,
    );
  });
  test('unknown, wrong-kind and archived assignments reject without financial effects', () async {
    final w = await wallet(),
        id = await categories.create(WalletOperation.generate(), category());
    final opening = (await wallets.load()).single.balance;
    await expectLater(
      expense(w, '1', category: const Uuid().v4()),
      throwsA(failure),
    );
    await expectLater(
      expense(w, '1', category: id, kind: TransactionKind.income),
      throwsA(failure),
    );
    await categories.setArchived(WalletOperation.generate(), id, 0, true);
    await expectLater(expense(w, '1', category: id), throwsA(failure));
    expect((await wallets.load()).single.balance, opening);
    expect(await transactions.load(), isEmpty);
  });
  test('rename and archive preserve old records; retaining archived category allows corrections', () async {
    final w = await wallet(),
        id = await categories.create(WalletOperation.generate(), category());
    final tx = await expense(w, '25', category: id);
    await categories.edit(
      WalletOperation.generate(),
      id,
      0,
      category(name: 'Cafe'),
    );
    await categories.setArchived(WalletOperation.generate(), id, 1, true);
    final current = (await transactions.load()).single;
    await transactions.edit(
      WalletOperation.generate(),
      tx,
      current.revision,
      TransactionDraft(
        walletId: w,
        kind: TransactionKind.expense,
        amount: Money.parse('20', ils),
        category: id,
        date: current.date,
      ),
      await revisions(),
    );
    expect((await transactions.load()).single.draft.amount.decimal, '20.00');
    await expectLater(
      categories.delete(WalletOperation.generate(), id, 2),
      throwsA(failure),
    );
    await transactions.delete(
      WalletOperation.generate(),
      tx,
      1,
      await revisions(),
    );
    await expectLater(
      categories.delete(WalletOperation.generate(), id, 2),
      throwsA(failure),
    );
    await expectLater(
      categories.edit(WalletOperation.generate(), id, 0, category()),
      throwsA(failure),
    );
  });
  test(
    'unused custom category deletes; budget references and built-ins stay safe',
    () async {
      var id = await categories.create(WalletOperation.generate(), category());
      await categories.delete(WalletOperation.generate(), id, 0);
      expect((await categories.load()).any((c) => c.id == id), false);
      id = await categories.create(WalletOperation.generate(), category());
      await budgets.create(WalletOperation.generate(), draft(category: id));
      await expectLater(
        categories.delete(WalletOperation.generate(), id, 0),
        throwsA(failure),
      );
      await expectLater(
        categories.delete(WalletOperation.generate(), 'food', 0),
        throwsA(failure),
      );
      await expectLater(
        categories.setArchived(
          WalletOperation.generate(),
          'transferFee',
          0,
          true,
        ),
        throwsA(failure),
      );
    },
  );
  test(
    'budget data, selected thresholds and idempotency persist exactly',
    () async {
      final op = WalletOperation.generate(),
          d = draft(
            amount: '900719925474099312345.67',
            thresholds: [100, 50, 50],
          );
      final id = await budgets.create(op, d);
      await budgets.create(op, d);
      await db.close();
      await open();
      final b = (await budgets.load()).single;
      expect(b.id, id);
      expect(b.draft.limit.decimal, '900719925474099312345.67');
      expect(b.draft.thresholds, [50, 100]);
      await expectLater(
        budgets.create(op, draft(amount: '5')),
        throwsStateError,
      );
    },
  );
  test('monthly boundaries and deleted income other currency and precision never inflate spending', () async {
    final w = await wallet(),
        foreign = await wallet(currency: usd),
        precise = await wallet(currency: Currency('ILS', 3));
    final id = await budgets.create(WalletOperation.generate(), draft());
    await expense(w, '10', date: '2026-09-30');
    await expense(w, '20', date: '2026-10-01');
    await expense(w, '30', date: '2026-10-31');
    await expense(w, '40', date: '2026-11-01');
    await expense(w, '99', kind: TransactionKind.income, category: 'salary');
    await expense(foreign, '99', currency: usd);
    await expense(precise, '99.001', currency: Currency('ILS', 3));
    final deleted = await expense(w, '99');
    await transactions.delete(
      WalletOperation.generate(),
      deleted,
      0,
      await revisions(),
    );
    final u = await usage(id);
    expect(u.spent.decimal, '50.00');
    expect(u.remaining.decimal, '50.00');
    expect(u.percentage, '50.0%');
    expect(u.crossed, 50);
  });
  test('general and category budgets remain independent and duplicate IDs count once', () async {
    final w = await wallet(),
        c = await categories.create(WalletOperation.generate(), category());
    final a = await budgets.create(WalletOperation.generate(), draft()),
        b = await budgets.create(
          WalletOperation.generate(),
          draft(category: c),
        );
    await expense(w, '10', category: c);
    await expense(w, '20', category: 'food');
    expect((await usage(a)).spent.decimal, '30.00');
    expect((await usage(b)).spent.decimal, '10.00');
    final records = await transactions.load();
    final dedup = BudgetUsage(
      (await budgets.load()).singleWhere((v) => v.id == a),
      DateTime(2026, 10, 15),
      [...records, ...records],
      await wallets.load(),
    );
    expect(dedup.spent.decimal, '30.00');
  });
  test('editing old amount date category and deleting recalculates history and alerts', () async {
    final w = await wallet(),
        c = await categories.create(WalletOperation.generate(), category());
    final id = await budgets.create(
      WalletOperation.generate(),
      draft(category: c),
    );
    final tx = await expense(w, '80', category: c);
    expect((await usage(id)).crossed, 80);
    await transactions.edit(
      WalletOperation.generate(),
      tx,
      0,
      TransactionDraft(
        walletId: w,
        kind: TransactionKind.expense,
        amount: Money.parse('25', ils),
        category: c,
        date: '2026-09-30',
      ),
      await revisions(),
    );
    expect((await usage(id)).spent.decimal, '0.00');
    expect((await usage(id)).crossed, isNull);
    expect(
      (await usage(id, date: DateTime(2026, 9, 30))).spent.decimal,
      '25.00',
    );
    await transactions.edit(
      WalletOperation.generate(),
      tx,
      1,
      TransactionDraft(
        walletId: w,
        kind: TransactionKind.expense,
        amount: Money.parse('100', ils),
        category: c,
        date: '2026-10-15',
      ),
      await revisions(),
    );
    expect((await usage(id)).crossed, 100);
    await transactions.edit(
      WalletOperation.generate(),
      tx,
      2,
      TransactionDraft(
        walletId: w,
        kind: TransactionKind.expense,
        amount: Money.parse('100', ils),
        category: 'food',
        date: '2026-10-15',
      ),
      await revisions(),
    );
    expect((await usage(id)).spent.decimal, '0.00');
    expect((await usage(id)).crossed, isNull);
    await transactions.delete(
      WalletOperation.generate(),
      tx,
      3,
      await revisions(),
    );
    expect((await usage(id)).spent.decimal, '0.00');
    expect((await usage(id)).crossed, isNull);
  });
  test('thresholds use exact comparisons, overspending stays negative and progress is bounded', () async {
    final w = await wallet(),
        id = await budgets.create(WalletOperation.generate(), draft());
    await expense(w, '49.99');
    expect((await usage(id)).crossed, isNull);
    await expense(w, '0.01');
    expect((await usage(id)).crossed, 50);
    await expense(w, '29.99');
    expect((await usage(id)).crossed, 50);
    await expense(w, '0.01');
    expect((await usage(id)).crossed, 80);
    await expense(w, '20.01');
    final u = await usage(id);
    expect(u.crossed, 100);
    expect(u.remaining.decimal, '-0.01');
    expect(u.progress, 1);
    expect(u.percentage, '100.0%');
  });
  test('FX transfers contribute only source fees, editing and cancelling reverse their budget effects', () async {
    final w = await wallet(),
        v = await wallet(currency: usd),
        id = await budgets.create(WalletOperation.generate(), draft());
    final repo = LocalTransferRepository(db), op = WalletOperation.generate();
    final transfer = await repo.create(
      WalletOperation(op.id, DateTime(2026, 10, 15)),
      TransferDraft(
        sourceId: w,
        destinationId: v,
        amount: Money.parse('500', ils),
        fee: Money.parse('2', ils),
        rate: ExchangeRate.parse('0.5'),
      ),
      await revisions(),
    );
    expect((await usage(id)).spent.decimal, '2.00');
    await repo.cancel(
      WalletOperation.generate(),
      transfer,
      0,
      await revisions(),
    );
    expect((await usage(id)).spent.decimal, '0.00');
  });
  test('weekly calendar is Monday-Sunday across year boundary, leap month and not-yet-started', () async {
    expect(
      BudgetPeriod.containing(BudgetCycle.weekly, DateTime(2026, 1, 1)).from,
      '2025-12-29',
    );
    expect(
      BudgetPeriod.containing(BudgetCycle.weekly, DateTime(2026, 1, 1)).to,
      '2026-01-04',
    );
    expect(
      BudgetPeriod.containing(BudgetCycle.monthly, DateTime(2024, 2, 29)).to,
      '2024-02-29',
    );
    final w = await wallet(),
        id = await budgets.create(
          WalletOperation.generate(),
          draft(cycle: BudgetCycle.weekly, starts: '2026-10-12'),
        );
    await expense(w, '40', date: '2026-10-11');
    await expense(w, '20', date: '2026-10-12');
    await expense(w, '30', date: '2026-10-18');
    await expense(w, '90', date: '2026-10-19');
    expect((await usage(id)).spent.decimal, '50.00');
    expect((await usage(id, date: DateTime(2026, 10, 11))).started, false);
  });
  test('archive does not erase history, hidden balances conceal usage, disabled thresholds stay quiet', () async {
    final w = await wallet(),
        id = await budgets.create(
          WalletOperation.generate(),
          draft(thresholds: []),
        );
    await expense(w, '100');
    var meta = (await wallets.load()).single.wallet;
    await wallets.setHidden(WalletOperation.generate(), w, meta.revision, true);
    meta = (await wallets.load()).single.wallet;
    await wallets.setArchived(
      WalletOperation.generate(),
      w,
      meta.revision,
      true,
    );
    final u = await usage(id);
    expect(u.spent.decimal, '100.00');
    expect(u.concealed, true);
    expect(u.crossed, isNull);
  });
  test('overlapping identical scopes reject; revision conflicts and deletion do not touch ledger', () async {
    final w = await wallet(),
        id = await budgets.create(WalletOperation.generate(), draft());
    await expense(w, '25');
    final balance = (await wallets.load()).single.balance;
    await expectLater(
      budgets.create(WalletOperation.generate(), draft(starts: '2026-02-01')),
      throwsA(failure),
    );
    await budgets.edit(WalletOperation.generate(), id, 0, draft(amount: '200'));
    await expectLater(
      budgets.edit(WalletOperation.generate(), id, 0, draft()),
      throwsA(failure),
    );
    await budgets.setArchived(WalletOperation.generate(), id, 1, true);
    await budgets.create(WalletOperation.generate(), draft());
    await expectLater(
      budgets.setArchived(WalletOperation.generate(), id, 2, false),
      throwsA(failure),
    );
    await budgets.delete(WalletOperation.generate(), id, 2);
    expect((await wallets.load()).single.balance, balance);
    expect((await transactions.load()).length, 1);
  });
  test('migration from schema five preserves exact ledger, receipts and preferences and seeds once', () async {
    final w = await wallet();
    await expense(w, '0.01');
    final legacy = await databaseFactoryIo.openDatabase(
      '${dir.path}/legacy.db',
      version: 5,
    );
    for (final name in [
      'wallets',
      'wallet_entries',
      'transactions',
      'operation_receipts',
      'settings',
    ]) {
      final store = stringMapStoreFactory.store(name);
      for (final row in await store.find(db.database)) {
        await store.record(row.key).put(legacy, row.value);
      }
    }
    await legacy.close();
    var migrated = await AppDatabase.open(
      databaseFactoryIo,
      '${dir.path}/legacy.db',
    );
    expect(migrated.database.version, AppDatabase.schemaVersion);
    expect(
      (await LocalTransactionRepository(
        migrated,
      ).load()).single.draft.amount.decimal,
      '0.01',
    );
    expect(
      (await LocalWalletRepository(migrated).load()).single.balance.decimal,
      '999999999999999999999.99',
    );
    expect(
      (await LocalCategoryRepository(migrated).load()).length,
      defaultCategories().length,
    );
    await migrated.close();
    migrated = await AppDatabase.open(
      databaseFactoryIo,
      '${dir.path}/legacy.db',
    );
    expect(
      (await LocalCategoryRepository(migrated).load()).length,
      defaultCategories().length,
    );
    await migrated.close();
  });
}
