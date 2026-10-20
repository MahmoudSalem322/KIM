import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/budget.dart';
import '../domain/budget_repository.dart';

final budgetRepositoryProvider = Provider<BudgetRepository>(
  (ref) => throw StateError('Budget repository not initialized'),
);
final budgetsProvider = StreamProvider<List<Budget>>(
  (ref) => ref.watch(budgetRepositoryProvider).watch(),
);
