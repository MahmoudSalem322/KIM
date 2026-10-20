import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local_exchange_repository.dart';
import '../domain/exchange_book.dart';

final exchangeRepositoryProvider = Provider<LocalExchangeRepository>(
  (ref) => throw StateError('Exchange repository not initialized'),
);
final exchangeBookProvider = StreamProvider<ExchangeBook>(
  (ref) => ref.watch(exchangeRepositoryProvider).watch(),
);
