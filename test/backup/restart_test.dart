import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_io.dart';
import 'package:kim/core/data/app_database.dart';
import 'package:kim/core/domain/money.dart';
import 'package:kim/features/backup/data/backup_repository.dart';
import 'package:kim/features/wallets/data/local_wallet_repository.dart';
import 'package:kim/features/wallets/domain/wallet.dart';

void main() {
  test('committed restore, safety copy and stable request survive real database reopening', () async {
    final directory = await Directory.systemTemp.createTemp('kim-restore-');
    final path = '${directory.path}/workspace.db';
    var db = await AppDatabase.open(databaseFactoryIo, path);
    try {
      final currency = Currency('ILS', 2),
          draft = WalletDraft(
            name: 'Exact',
            color: 'blue',
            icon: 'cash',
            type: 'cash',
            currency: currency,
          );
      await LocalWalletRepository(db).create(
        WalletOperation.generate(),
        draft,
        Money.parse('9007199254740993.25', currency),
      );
      var repo = BackupRepository(db);
      final original = await repo.inspect(await repo.create());
      await LocalWalletRepository(db).create(
        WalletOperation.generate(),
        WalletDraft(
          name: 'Later',
          color: 'blue',
          icon: 'cash',
          type: 'cash',
          currency: currency,
        ),
        Money.parse('10', currency),
      );
      final preview = await repo.preview(original);
      await repo.restore(preview, 'stable-restore');
      await db.close();
      db = await AppDatabase.open(databaseFactoryIo, path);
      repo = BackupRepository(db);
      expect(
        (await LocalWalletRepository(db).load()).single.balance.decimal,
        '9007199254740993.25',
      );
      await repo.restore(preview, 'stable-restore');
      final recovery = await repo.previous();
      expect(recovery, isNotNull);
      final other = await repo.preview(recovery!);
      await expectLater(
        repo.restore(other, 'stable-restore'),
        throwsStateError,
      );
      await repo.restore(other, 'restore-recovery');
      expect((await LocalWalletRepository(db).load()).length, 2);
      await repo.restore(preview, 'stable-restore');
      expect((await LocalWalletRepository(db).load()).length, 2);
    } finally {
      await db.close();
      await directory.delete(recursive: true);
    }
  });
}
