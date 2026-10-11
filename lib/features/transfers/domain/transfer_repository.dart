import '../../wallets/domain/wallet.dart';
import 'wallet_transfer.dart';

abstract interface class TransferRepository {
  Future<List<WalletTransfer>> load();
  Stream<List<WalletTransfer>> watch();
  Future<String> create(
    WalletOperation op,
    TransferDraft draft,
    Map<String, int> revisions,
  );
  Future<void> edit(
    WalletOperation op,
    String id,
    int revision,
    TransferDraft draft,
    Map<String, int> revisions,
  );
  Future<void> cancel(
    WalletOperation op,
    String id,
    int revision,
    Map<String, int> revisions,
  );
}
