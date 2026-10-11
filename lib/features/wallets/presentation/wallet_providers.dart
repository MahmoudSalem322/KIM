import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/wallet.dart';
import '../domain/wallet_repository.dart';

final walletRepositoryProvider = Provider<WalletRepository>(
  (ref) => throw StateError('Wallet repository must be initialized'),
);
final walletsProvider = StreamProvider<List<WalletSnapshot>>(
  (ref) => ref.watch(walletRepositoryProvider).watch(),
);
