import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/financial_transaction.dart';
import '../domain/transaction_repository.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>(
  (ref) => throw StateError('Transaction repository not initialized'),
);
final transactionsProvider = StreamProvider<List<FinancialTransaction>>(
  (ref) => ref.watch(transactionRepositoryProvider).watch(),
);
