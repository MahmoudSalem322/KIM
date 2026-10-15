import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/debt.dart';
import '../domain/debt_repository.dart';

final debtRepositoryProvider = Provider<DebtRepository>(
  (ref) => throw StateError('Debt repository not initialized'),
);
final debtsProvider = StreamProvider<List<DebtSnapshot>>(
  (ref) => ref.watch(debtRepositoryProvider).watch(),
);
