import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/app_category.dart';
import '../domain/category_repository.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => throw StateError('Category repository not initialized'),
);
final categoriesProvider = StreamProvider<List<AppCategory>>(
  (ref) => ref.watch(categoryRepositoryProvider).watch(),
);
