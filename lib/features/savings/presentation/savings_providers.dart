import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/savings_goal.dart';
import '../domain/savings_repository.dart';

final savingsRepositoryProvider = Provider<SavingsRepository>(
  (ref) => throw StateError('Savings repository not initialized'),
);
final savingsGoalsProvider = StreamProvider<List<GoalSnapshot>>(
  (ref) => ref.watch(savingsRepositoryProvider).watch(),
);
