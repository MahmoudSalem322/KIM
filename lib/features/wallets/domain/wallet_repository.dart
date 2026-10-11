import '../../../core/domain/money.dart';
import 'wallet.dart';

abstract interface class WalletRepository {
  Future<List<WalletSnapshot>> load();
  Stream<List<WalletSnapshot>> watch();
  Future<String> create(
    WalletOperation operation,
    WalletDraft draft,
    Money opening,
  );
  Future<void> edit(
    WalletOperation operation,
    String id,
    int revision,
    WalletDraft draft,
  );
  Future<void> adjust(
    WalletOperation operation,
    String id,
    int revision,
    Money target,
    String reason,
  );
  Future<void> setArchived(
    WalletOperation operation,
    String id,
    int revision,
    bool archived,
  );
  Future<void> setHidden(
    WalletOperation operation,
    String id,
    int revision,
    bool hidden,
  );
  Future<void> reorder(
    WalletOperation operation,
    List<String> ids,
    Map<String, int> revisions,
  );
}
