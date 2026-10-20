import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:kim/core/data/app_database.dart';
import 'package:kim/core/domain/money.dart';
import 'package:kim/features/backup/data/backup_repository.dart';
import 'package:kim/features/backup/domain/backup_codec.dart';
import 'package:kim/features/security/data/security_repository.dart';
import 'package:kim/features/settings/data/local_settings_repository.dart';
import 'package:kim/features/settings/domain/app_settings.dart';
import 'package:kim/features/wallets/data/local_wallet_repository.dart';
import 'package:kim/features/wallets/domain/wallet.dart';
import 'package:kim/features/transactions/data/local_transaction_repository.dart';
import 'package:kim/features/transactions/domain/financial_transaction.dart';
import 'package:kim/features/transfers/data/local_transfer_repository.dart';
import 'package:kim/features/transfers/domain/wallet_transfer.dart';
import 'package:kim/features/transfers/domain/exchange_rate.dart';
import 'package:kim/features/budgets/data/local_budget_repository.dart';
import 'package:kim/features/budgets/domain/budget.dart';
import 'package:kim/features/savings/data/local_savings_repository.dart';
import 'package:kim/features/savings/domain/savings_goal.dart';
import 'package:kim/features/debts/data/local_debt_repository.dart';
import 'package:kim/features/debts/domain/debt.dart';
import 'package:kim/features/recurring/data/local_recurring_repository.dart';
import 'package:kim/features/recurring/domain/recurring_payment.dart';
import 'package:kim/features/reports/data/local_exchange_repository.dart';
import 'package:kim/features/reports/domain/exchange_book.dart';
import 'package:kim/features/notifications/data/local_notice_repository.dart';

void main() {
  late AppDatabase db;
  late BackupRepository repo;
  late LocalWalletRepository wallets;
  late String wid;
  final ils = Currency('ILS', 2), usd = Currency('USD', 2);
  Future<Map<String, int>> revisions() async => {
    for (final w in await wallets.load()) w.wallet.id: w.wallet.revision,
  };
  Future<void> seed() async {
    wid = await wallets.create(
      WalletOperation.generate(),
      WalletDraft(
        name: 'محفظة',
        color: 'blue',
        icon: 'cash',
        type: 'cash',
        currency: ils,
      ),
      Money.parse('1000', ils),
    );
    final dollars = await wallets.create(
      WalletOperation.generate(),
      WalletDraft(
        name: 'USD',
        color: 'blue',
        icon: 'bank',
        type: 'bank',
        currency: usd,
      ),
      Money.parse('500', usd),
    );
    await LocalTransactionRepository(db).create(
      WalletOperation.generate(),
      TransactionDraft(
        walletId: wid,
        kind: TransactionKind.income,
        amount: Money.parse('100', ils),
        category: 'salary',
        date: '2026-10-20',
      ),
      await revisions(),
    );
    await LocalTransferRepository(db).create(
      WalletOperation.generate(),
      TransferDraft(
        sourceId: dollars,
        destinationId: wid,
        amount: Money.parse('10', usd),
        fee: Money.parse('1', usd),
        rate: ExchangeRate.parse('3.75'),
      ),
      await revisions(),
    );
    await LocalBudgetRepository(db).create(
      WalletOperation.generate(),
      BudgetDraft(
        name: 'Monthly',
        limit: Money.parse('200', ils),
        cycle: BudgetCycle.monthly,
        startsOn: '2026-10-01',
        category: 'bills',
      ),
    );
    final savings = LocalSavingsRepository(db),
        goal = await savings.create(
          WalletOperation.generate(),
          GoalDraft(
            name: 'رحلة',
            target: Money.parse('500', ils),
            dueOn: '2027-01-01',
            color: 'blue',
            icon: 'travel',
          ),
        );
    await savings.allocate(
      WalletOperation.generate(),
      goal,
      0,
      wid,
      (await revisions())[wid]!,
      Money.parse('100', ils),
      'تخصيص',
    );
    final debts = LocalDebtRepository(db),
        debt = await debts.create(
          WalletOperation.generate(),
          DebtDraft(
            direction: DebtDirection.borrowed,
            person: 'صديق',
            principal: Money.parse('50', ils),
            dueOn: '2027-01-01',
          ),
        );
    await debts.record(
      WalletOperation.generate(),
      debt,
      0,
      DebtCashDraft(
        kind: DebtEventKind.principal,
        walletId: wid,
        amount: Money.parse('50', ils),
        date: '2026-10-20',
      ),
      await revisions(),
    );
    final plans = LocalRecurringRepository(db),
        plan = await plans.create(
          WalletOperation.generate(),
          RecurringDraft(
            name: 'Internet',
            amount: Money.parse('20', ils),
            walletId: wid,
            cycle: RecurringCycle.monthly,
            nextDate: '2026-10-01',
            category: 'bills',
          ),
        );
    await plans.payNext(
      WalletOperation.generate(),
      plan,
      0,
      DateTime(2026, 10, 20),
    );
    await LocalSettingsRepository(db).save(
      const AppSettings(
        languageCode: 'en',
        theme: AppTheme.dark,
        hideBalances: true,
      ),
    );
    await LocalExchangeRepository(db).save(WalletOperation.generate(), 0, usd, [
      ManualRate(
        from: usd,
        to: ils,
        decimal: '3.75',
        source: 'Manual',
        asOf: '2026-10-20',
        updatedAt: DateTime.utc(2026, 10, 20),
      ),
    ]);
    await LocalNoticeRepository(db)
        .setFlag(WalletOperation.generate(), 'test', 'read', true);
  }

  setUp(() async {
    db = await AppDatabase.open(newDatabaseFactoryMemory(), 'backup');
    repo = BackupRepository(db);
    wallets = LocalWalletRepository(db);
  });
  tearDown(() async => db.close());
  Future<Map<String, Object?>> payload() async => Map<String, Object?>.from(
    jsonDecode(
      jsonEncode({
        'createdAt': '2026-10-20T00:00:00Z',
        'database': await repo.snapshot(),
      }),
    ) as Map,
  );
  test('all financial stores round trip exact relationships and settings; recovery and receipt are atomic', () async {
    await seed();
    await SecurityRepository(db).setPin('654321');
    final original = canonicalBackup(await repo.snapshot()),
        bytes = await repo.create();
    final checked = await repo.inspect(bytes);
    expect(checked.records, greaterThan(30));
    await LocalSettingsRepository(db)
        .save(const AppSettings(languageCode: 'ar'));
    final before = canonicalBackup(await repo.snapshot());
    final preview = await repo.preview(checked);
    await repo.restore(preview, 'restore-1');
    expect(canonicalBackup(await repo.snapshot()), original);
    await repo.restore(preview, 'restore-1');
    expect(canonicalBackup(await repo.snapshot()), original);
    expect(await SecurityRepository(db).verify('654321'), true);
    final recovery = await repo.previous();
    expect(recovery, isNotNull);
    await repo.restore(await repo.preview(recovery!), 'restore-2');
    expect(canonicalBackup(await repo.snapshot()), before);
    final plan = (await LocalRecurringRepository(db).load()).single;
    expect(plan.draft.nextDate, '2026-11-01');
    expect(
      (await LocalSavingsRepository(db).load()).single.allocated.decimal,
      '100.00',
    );
  });
  test('encrypted backup authenticates password, ciphertext and randomizes salt/nonce', () async {
    await seed();
    final a = await repo.create(password: 'correct password'),
        b = await repo.create(password: 'correct password');
    expect(a, isNot(equals(b)));
    expect(utf8.decode(a), isNot(contains('محفظة')));
    expect(
      (await repo.inspect(a, password: 'correct password')).records,
      greaterThan(30),
    );
    await expectLater(
      repo.inspect(a, password: 'wrong password'),
      throwsA(anything),
    );
    final e = jsonDecode(utf8.decode(a)) as Map;
    final cipher = e['ciphertext'] as String;
    e['ciphertext'] =
        '${cipher.startsWith('A') ? 'B' : 'A'}${cipher.substring(1)}';
    await expectLater(
      repo.inspect(
        Uint8List.fromList(utf8.encode(jsonEncode(e))),
        password: 'correct password',
      ),
      throwsA(anything),
    );
    e['iterations'] = 999999999;
    await expectLater(
      repo.inspect(
        Uint8List.fromList(utf8.encode(jsonEncode(e))),
        password: 'correct password',
      ),
      throwsA(anything),
    );
  });
  test('invalid JSON, checksum, envelope and future data versions never mutate live data', () async {
    await seed();
    final original = canonicalBackup(await repo.snapshot());
    await expectLater(
      repo.inspect(Uint8List.fromList(utf8.encode('{broken'))),
      throwsA(anything),
    );
    final e = jsonDecode(utf8.decode(await repo.create())) as Map;
    e['content'] = '{}';
    await expectLater(
      repo.inspect(Uint8List.fromList(utf8.encode(jsonEncode(e)))),
      throwsA(anything),
    );
    e['format'] = 2;
    await expectLater(
      repo.inspect(Uint8List.fromList(utf8.encode(jsonEncode(e)))),
      throwsA(anything),
    );
    final p = await payload();
    (p['database'] as Map)['version'] = 99;
    await expectLater(repo.validate(p), throwsA(anything));
    expect(canonicalBackup(await repo.snapshot()), original);
  });
  test('orphan relationships and altered ledger are rejected even with a valid checksum', () async {
    await seed();
    final p = await payload(), raw = p['database'] as Map;
    final stores = raw['stores'] as List;
    final ws = stores.singleWhere((s) => s['name'] == 'wallets') as Map;
    (ws['keys'] as List).removeAt(0);
    (ws['values'] as List).removeAt(0);
    await expectLater(
      repo.inspect(await BackupCodec.encode(p)),
      throwsA(anything),
    );
    final q = await payload();
    final entry =
        ((q['database'] as Map)['stores'] as List).singleWhere(
              (s) => s['name'] == 'wallet_entries',
            )['values'][0]
            as Map;
    (entry['after'] as Map)['minorUnits'] = '999';
    await expectLater(repo.validate(q), throwsA(anything));
  });
  test(
    'duplicate IDs/stores and unknown stores reject the entire file',
    () async {
      await seed();
      final p = await payload();
      final stores = (p['database'] as Map)['stores'] as List;
      stores.add(stores.first);
      await expectLater(repo.validate(p), throwsA(anything));
      final q = await payload();
      ((q['database'] as Map)['stores'] as List).add({
        'name': 'unknown',
        'keys': ['a'],
        'values': [{}],
      });
      await expectLater(repo.validate(q), throwsA(anything));
    },
  );
  test('schema 8, 9 and 10 snapshots migrate before replacement and preserve original amounts', () async {
    await seed();
    for (final version in [8, 9, 10]) {
      final p = await payload();
      (p['database'] as Map)['version'] = version;
      final stores = (p['database'] as Map)['stores'] as List;
      stores.removeWhere(
        (s) =>
            s['name'] == 'security' ||
            version < 10 && s['name'] == 'report_exchange' ||
            version < 9 &&
                [
                  'recurring_payments',
                  'recurring_occurrences',
                ].contains(s['name']),
      );
      final preferences =
          stores.singleWhere((s) => s['name'] == 'settings') as Map;
      final keyIndex = (preferences['keys'] as List).indexOf('preferences');
      (preferences['values'][keyIndex] as Map).remove('hideBalances');
      final checked = await repo.validate(p);
      expect(checked.sourceVersion, version);
      await repo.restore(await repo.preview(checked), 'legacy-$version');
      expect(
        (await LocalTransactionRepository(
          db,
        ).load()).any((t) => t.draft.amount.decimal == '100.00'),
        true,
      );
    }
  });
  test('write after review prevents restore; interrupted restore rolls back all stores and recovery', () async {
    await seed();
    final backup = await repo.inspect(await repo.create()),
        preview = await repo.preview(backup);
    await LocalSettingsRepository(db)
        .save(const AppSettings(languageCode: 'ar'));
    await expectLater(repo.restore(preview, 'stale'), throwsStateError);
    final current = canonicalBackup(await repo.snapshot());
    await expectLater(
      repo.restore(
        await repo.preview(backup),
        'interrupt',
        beforeCommit: (txn) async {
          throw StateError('power loss');
        },
      ),
      throwsStateError,
    );
    expect(canonicalBackup(await repo.snapshot()), current);
    expect(await repo.previous(), null);
    await repo.restore(await repo.preview(backup), 'interrupt');
    expect(await repo.previous(), isNotNull);
  });
  test('backup includes records hidden globally without mutating individual privacy', () async {
    await seed();
    final checked = await repo.inspect(await repo.create());
    expect(checked.records, greaterThan(30));
    expect((await wallets.load()).every((w) => !w.wallet.hidden), true);
    expect((await LocalSettingsRepository(db).load()).hideBalances, true);
  });
}
