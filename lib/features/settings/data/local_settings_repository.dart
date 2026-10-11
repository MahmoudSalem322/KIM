import 'package:sembast/sembast.dart';

import '../../../core/data/app_database.dart';
import '../domain/app_settings.dart';
import '../domain/settings_repository.dart';

final class LocalSettingsRepository implements SettingsRepository {
  const LocalSettingsRepository(this.db);
  final AppDatabase db;
  @override
  Future<AppSettings> load() async => AppSettings.fromJson(
    await AppDatabase.settings.record('preferences').get(db.database),
  );
  @override
  Future<void> save(AppSettings settings) async {
    if (!['ar', 'en'].contains(settings.languageCode)) {
      throw ArgumentError('Unsupported language');
    }
    await AppDatabase.settings
        .record('preferences')
        .put(db.database, settings.toJson());
  }
}
