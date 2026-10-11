import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_io.dart';
import 'package:kim/core/data/app_database.dart';
import 'package:kim/core/domain/money.dart';
import 'package:kim/features/wallets/domain/wallet.dart';
import 'package:kim/features/wallets/data/local_wallet_repository.dart';

void main() {
  late Directory dir;
  late AppDatabase db;
  late LocalWalletRepository repo;
  final ils = Currency('ILS', 2);
  WalletDraft draft({String name = 'Everyday', Currency? currency}) =>
      WalletDraft(
        name: name,
        color: 'emerald',
        icon: 'wallet',
        type: 'cash',
        currency: currency ?? ils,
      );
  WalletOperation op() => WalletOperation.generate();
  Future<WalletSnapshot> create(String amount, {WalletDraft? data}) async {
    final d = data ?? draft();
    final id = await repo.create(op(), d, Money.parse(amount, d.currency));
    return (await repo.load()).firstWhere((s) => s.wallet.id == id);
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('kim_wallets_');
    db = await AppDatabase.open(databaseFactoryIo, '${dir.path}/kim.db');
    repo = LocalWalletRepository(db);
  });
  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  test(
    'creation records exact huge opening once and survives database reopen',
    () async {
      final command = op();
      final opening = Money.parse('900719925474099312345.17', ils);
      final id = await repo.create(command, draft(), opening);
      await Future.wait(
        List.generate(4, (_) => repo.create(command, draft(), opening)),
      );
      var s = (await repo.load()).single;
      expect(s.wallet.id, id);
      expect(s.balance, opening);
      expect(s.entries.length, 1);
      expect(s.entries.single.kind, WalletEntryKind.opening);
      expect(s.entries.single.before.minorUnits, BigInt.zero);
      expect(s.entries.single.after, opening);
      expect(s.entries.single.operationId, command.id.value);
      await db.close();
      db = await AppDatabase.open(databaseFactoryIo, '${dir.path}/kim.db');
      repo = LocalWalletRepository(db);
      s = (await repo.load()).single;
      expect(s.balance, opening);
      expect(s.entries.single.at, command.at);
    },
  );
  test(
    'zero negative Arabic and custom precision openings remain exact',
    () async {
      expect((await create('0')).entries.length, 1);
      expect((await create('-١٢٫٣٤')).balance.decimal, '-12.34');
      final s = await create(
        '0.123456',
        data: draft(currency: Currency('ABC', 6)),
      );
      expect(s.balance.decimal, '0.123456');
    },
  );
  test('metadata edits cannot change currency or opening ledger', () async {
    var s = await create('10.25');
    final entry = s.entries.single;
    await repo.edit(
      op(),
      s.wallet.id,
      s.wallet.revision,
      draft(name: ' Renamed '),
    );
    s = (await repo.load()).single;
    expect(s.wallet.name, 'Renamed');
    expect(s.balance.decimal, '10.25');
    expect(s.entries.single.operationId, entry.operationId);
    await expectLater(
      repo.edit(
        op(),
        s.wallet.id,
        s.wallet.revision,
        draft(currency: Currency('USD', 2)),
      ),
      throwsA(isA<WalletFailure>()),
    );
    expect((await repo.load()).single.wallet.currency, ils);
  });
  test(
    'documented settlement appends exact delta with before and after values',
    () async {
      var s = await create('10.10');
      final command = op();
      final target = Money.parse('11.25', ils);
      await repo.adjust(
        command,
        s.wallet.id,
        s.wallet.revision,
        target,
        'Counted cash',
      );
      await repo.adjust(
        command,
        s.wallet.id,
        s.wallet.revision,
        target,
        'Counted cash',
      );
      s = (await repo.load()).single;
      expect(s.balance, target);
      expect(s.entries.length, 2);
      expect(s.entries.first.delta.decimal, '10.10');
      final e = s.entries.last;
      expect(e.kind, WalletEntryKind.adjustment);
      expect(e.delta.decimal, '1.15');
      expect(e.before.decimal, '10.10');
      expect(e.after, target);
      expect(e.reason, 'Counted cash');
      expect(e.at, command.at);
      expect(e.operationId, command.id.value);
      await expectLater(
        repo.adjust(
          command,
          s.wallet.id,
          s.wallet.revision,
          Money.parse('20', ils),
          'different',
        ),
        throwsStateError,
      );
      expect((await repo.load()).single.balance, target);
    },
  );
  test('invalid settlement rejects no-op blank reason and mismatched currency atomically', () async {
    final s = await create('10');
    for (final args in [
      (Money.parse('10', ils), 'no change'),
      (Money.parse('20', ils), '   '),
      (Money.parse('20', Currency('USD', 2)), 'different currency'),
    ]) {
      await expectLater(
        repo.adjust(op(), s.wallet.id, s.wallet.revision, args.$1, args.$2),
        throwsA(isA<WalletFailure>()),
      );
    }
    final unchanged = (await repo.load()).single;
    expect(unchanged.wallet.revision, s.wallet.revision);
    expect(unchanged.entries.length, 1);
  });
  test(
    'concurrent stale settlements only commit one and failed command may retry',
    () async {
      final s = await create('10');
      final a = op();
      final b = op();
      final outcomes = await Future.wait(
        [a, b].map((command) async {
          try {
            await repo.adjust(
              command,
              s.wallet.id,
              s.wallet.revision,
              Money.parse('12', ils),
              'Count',
            );
            return true;
          } on WalletFailure {
            return false;
          }
        }),
      );
      expect(outcomes.where((v) => v).length, 1);
      var current = (await repo.load()).single;
      expect(current.entries.length, 2);
      final failed = outcomes.first ? b : a;
      await repo.adjust(
        failed,
        s.wallet.id,
        current.wallet.revision,
        Money.parse('13', ils),
        'Retry corrected revision',
      );
      current = (await repo.load()).single;
      expect(current.balance.decimal, '13.00');
      expect(current.entries.length, 3);
    },
  );
  test('archive is reversible and blocks edits and settlements while keeping history', () async {
    var s = await create('-25');
    await repo.setArchived(op(), s.wallet.id, s.wallet.revision, true);
    s = (await repo.load()).single;
    expect(s.wallet.archived, true);
    await expectLater(
      repo.adjust(
        op(),
        s.wallet.id,
        s.wallet.revision,
        Money.parse('0', ils),
        'reset',
      ),
      throwsA(isA<WalletFailure>()),
    );
    await expectLater(
      repo.edit(op(), s.wallet.id, s.wallet.revision, draft(name: 'lost')),
      throwsA(isA<WalletFailure>()),
    );
    await repo.setArchived(op(), s.wallet.id, s.wallet.revision, false);
    s = (await repo.load()).single;
    expect(s.wallet.archived, false);
    expect(s.balance.decimal, '-25.00');
    expect(s.entries.length, 1);
  });
  test('hide and complete reorder persist and invalid order cannot partially apply', () async {
    final a = await create('1', data: draft(name: 'A'));
    final b = await create('2', data: draft(name: 'B'));
    await repo.setHidden(op(), a.wallet.id, a.wallet.revision, true);
    final revisions = {
      for (final s in await repo.load()) s.wallet.id: s.wallet.revision,
    };
    await repo.reorder(op(), [b.wallet.id, a.wallet.id], revisions);
    var list = await repo.load();
    expect(list.map((s) => s.wallet.name), ['B', 'A']);
    expect(list.last.wallet.hidden, true);
    await expectLater(
      repo.reorder(op(), [b.wallet.id], revisions),
      throwsA(isA<WalletFailure>()),
    );
    await expectLater(
      repo.reorder(op(), [b.wallet.id, b.wallet.id], revisions),
      throwsA(isA<WalletFailure>()),
    );
    await expectLater(
      repo.reorder(op(), [a.wallet.id, b.wallet.id], revisions),
      throwsA(isA<WalletFailure>()),
    );
    list = await repo.load();
    expect(list.map((s) => s.wallet.name), ['B', 'A']);
    await db.close();
    db = await AppDatabase.open(databaseFactoryIo, '${dir.path}/kim.db');
    list = await LocalWalletRepository(db).load();
    expect(list.last.wallet.hidden, true);
    expect(list.first.wallet.name, 'B');
  });
  test(
    'migration from phase 1 preserves settings and operation receipts',
    () async {
      final legacyPath = '${dir.path}/legacy.db';
      final old = await databaseFactoryIo.openDatabase(legacyPath, version: 2);
      await AppDatabase.settings.record('preferences').put(old, {
        'languageCode': 'en',
        'theme': 'dark',
      });
      await stringMapStoreFactory
          .store('operation_receipts')
          .record('legacy')
          .put(old, {'request': 'keep'});
      await old.close();
      final migrated = await AppDatabase.open(databaseFactoryIo, legacyPath);
      expect(migrated.database.version, 3);
      expect(await LocalWalletRepository(migrated).load(), isEmpty);
      expect(
        (await AppDatabase.settings
            .record('preferences')
            .get(migrated.database))?['theme'],
        'dark',
      );
      expect(
        (await stringMapStoreFactory
            .store('operation_receipts')
            .record('legacy')
            .get(migrated.database))?['request'],
        'keep',
      );
      await migrated.close();
    },
  );
  test(
    'invalid metadata cannot create money and wallet count has no fixed cap',
    () async {
      await expectLater(
        repo.create(op(), draft(name: '  '), Money.parse('1', ils)),
        throwsA(isA<WalletFailure>()),
      );
      expect(await repo.load(), isEmpty);
      for (var i = 0; i < 32; i++) {
        await repo.create(
          op(),
          draft(name: 'Wallet $i'),
          Money.parse('0', ils),
        );
      }
      expect((await repo.load()).length, 32);
    },
  );
}
