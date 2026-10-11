import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/transfer_repository.dart';
import '../domain/wallet_transfer.dart';

final transferRepositoryProvider = Provider<TransferRepository>(
  (ref) => throw StateError('Transfer repository must be injected'),
);
final transfersProvider = StreamProvider<List<WalletTransfer>>(
  (ref) => ref.watch(transferRepositoryProvider).watch(),
);
