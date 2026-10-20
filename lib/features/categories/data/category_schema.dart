import 'package:sembast/sembast.dart';

import '../domain/app_category.dart';

final categoryStore = stringMapStoreFactory.store('categories');
Future<void> seedCategories(DatabaseClient client) async {
  for (final category in defaultCategories()) {
    if (!await categoryStore.record(category.id).exists(client)) {
      await categoryStore.record(category.id).put(client, category.toJson());
    }
  }
}
