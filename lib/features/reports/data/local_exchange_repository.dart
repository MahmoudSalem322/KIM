import 'dart:convert';

import 'package:sembast/sembast.dart';

import '../../../core/data/app_database.dart';
import '../../../core/domain/money.dart';
import '../../wallets/domain/wallet.dart';
import '../domain/exchange_book.dart';

final class LocalExchangeRepository {
  LocalExchangeRepository(this.db);
  final AppDatabase db;
  static final store = stringMapStoreFactory.store('report_exchange');
  ExchangeBook _decode(Map<String, Object?>? j) => j == null
      ? ExchangeBook(currency: Currency('ILS', 2), rates: [])
      : ExchangeBook(
          currency: Currency(j['currency'] as String, j['scale'] as int),
          revision: j['revision'] as int,
          rates: (j['rates'] as List)
              .map(
                (v) => ManualRate.fromJson(Map<String, Object?>.from(v as Map)),
              )
              .toList(),
        );
  Future<ExchangeBook> load() async =>
      _decode(await store.record('book').get(db.database));
  Stream<ExchangeBook> watch() => store
      .record('book')
      .onSnapshot(db.database)
      .map((row) => _decode(row?.value));
  Future<void> save(
    WalletOperation op,
    int expectedRevision,
    Currency currency,
    List<ManualRate> rates,
  ) async {
    final validated = ExchangeBook(currency: currency, rates: rates);
    final encodedRates = validated.rates.map((r) => r.toJson()).toList();
    final request = jsonEncode([
      'exchange-v1',
      expectedRevision,
      currency.code,
      currency.scale,
      encodedRates,
    ]);
    await db.applyOnce(op.id, request, (txn) async {
      final old = _decode(await store.record('book').get(txn));
      if (old.revision != expectedRevision) {
        throw const WalletFailure('conflict');
      }
      await store.record('book').put(txn, {
        'currency': currency.code,
        'scale': currency.scale,
        'revision': old.revision + 1,
        'rates': encodedRates,
      });
    });
  }
}
