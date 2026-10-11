import '../../wallets/domain/wallet.dart';
import 'financial_transaction.dart';

abstract interface class TransactionRepository {
  Future<List<FinancialTransaction>> load();
  Stream<List<FinancialTransaction>> watch();
  Future<String> create(
    WalletOperation operation,
    TransactionDraft draft,
    Map<String, int> walletRevisions,
  );
  Future<void> edit(
    WalletOperation operation,
    String id,
    int revision,
    TransactionDraft draft,
    Map<String, int> walletRevisions,
  );
  Future<void> delete(
    WalletOperation operation,
    String id,
    int revision,
    Map<String, int> walletRevisions,
  );
}
