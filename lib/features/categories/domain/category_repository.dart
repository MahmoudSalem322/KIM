import '../../wallets/domain/wallet.dart';
import 'app_category.dart';

abstract interface class CategoryRepository {
  Future<List<AppCategory>> load();
  Stream<List<AppCategory>> watch();
  Future<String> create(WalletOperation op, CategoryDraft draft);
  Future<void> edit(
    WalletOperation op,
    String id,
    int revision,
    CategoryDraft draft,
  );
  Future<void> setArchived(
    WalletOperation op,
    String id,
    int revision,
    bool archived,
  );
  Future<void> delete(WalletOperation op, String id, int revision);
}
