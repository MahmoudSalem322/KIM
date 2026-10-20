import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/wallet.dart';
import '../domain/wallet_repository.dart';
import '../../settings/presentation/settings_controller.dart';

final walletRepositoryProvider = Provider<WalletRepository>(
  (ref) => throw StateError('Wallet repository must be initialized'),
);
final walletsProvider = StreamProvider<List<WalletSnapshot>>((ref) {
  final hidden = ref.watch(settingsControllerProvider).settings.hideBalances;
  return ref
      .watch(walletRepositoryProvider)
      .watch()
      .map(
        (rows) => !hidden
            ? rows
            : [
                for (final row in rows)
                  WalletSnapshot(
                    Wallet(
                      id: row.wallet.id,
                      name: row.wallet.name,
                      color: row.wallet.color,
                      icon: row.wallet.icon,
                      type: row.wallet.type,
                      currency: row.wallet.currency,
                      createdAt: row.wallet.createdAt,
                      updatedAt: row.wallet.updatedAt,
                      revision: row.wallet.revision,
                      position: row.wallet.position,
                      archived: row.wallet.archived,
                      hidden: true,
                    ),
                    row.entries,
                  ),
              ],
      );
});
