import 'package:sembast/sembast.dart';

import '../domain/money.dart';
import '../../features/wallets/domain/wallet.dart';

final savingsGoalsStore = stringMapStoreFactory.store('savings_goals');
final savingsEventsStore = stringMapStoreFactory.store('savings_events');

/// Reservations are claims on existing funds, never financial ledger entries.
/// All callers use the same database transaction as the financial mutation.
Future<Money> reservedInWallet(
  DatabaseClient txn,
  String id,
  Currency currency,
) async {
  var total = Money(BigInt.zero, currency);
  for (final row in await savingsEventsStore.find(
    txn,
    finder: Finder(filter: Filter.equals('walletId', id)),
  )) {
    final delta = Money.fromJson(
      Map<String, Object?>.from(row.value['delta'] as Map),
    );
    if (delta.currency != currency) throw const WalletFailure('integrity');
    total = total + delta;
  }
  if (total.minorUnits.isNegative) throw const WalletFailure('integrity');
  return total;
}

Future<WalletSnapshot> savingsWallet(DatabaseClient txn, String id) async {
  final value = await stringMapStoreFactory
      .store('wallets')
      .record(id)
      .get(txn);
  if (value == null) throw const WalletFailure('notFound');
  final wallet = Wallet.fromJson(id, value);
  final rows = await stringMapStoreFactory
      .store('wallet_entries')
      .find(txn, finder: Finder(filter: Filter.equals('walletId', id)));
  final entries = rows.map((r) => WalletEntry.fromJson(r.key, r.value)).toList()
    ..sort((a, b) => a.sequence.compareTo(b.sequence));
  return WalletSnapshot(wallet, entries);
}

/// Check final net balances, after every leg of an edit/reversal. This allows
/// valid replacements even when an intermediate reversal dips below a reserve.
Future<void> protectSavings(DatabaseClient txn, Iterable<String> ids) async {
  for (final id in ids.toSet()) {
    final snapshot = await savingsWallet(txn, id);
    final reserved = await reservedInWallet(txn, id, snapshot.wallet.currency);
    if (reserved.minorUnits > BigInt.zero &&
        (snapshot.wallet.archived ||
            snapshot.balance.minorUnits < reserved.minorUnits)) {
      throw const WalletFailure('reserved');
    }
  }
}
