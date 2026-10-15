import '../../../core/domain/money.dart';
import '../../wallets/domain/wallet.dart';
import 'savings_goal.dart';

abstract interface class SavingsRepository {
  Future<List<GoalSnapshot>> load();
  Stream<List<GoalSnapshot>> watch();
  Future<String> create(WalletOperation op, GoalDraft draft);
  Future<void> edit(
    WalletOperation op,
    String id,
    int revision,
    GoalDraft draft,
  );

  /// Sets this goal's earmarked amount in one wallet; zero releases it entirely.
  Future<void> allocate(
    WalletOperation op,
    String id,
    int revision,
    String walletId,
    int walletRevision,
    Money amount,
    String note,
  );
  Future<void> close(WalletOperation op, String id, int revision);
}
