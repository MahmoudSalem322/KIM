import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kim/features/settings/domain/app_settings.dart';
import 'package:kim/features/settings/domain/settings_repository.dart';
import 'package:kim/features/settings/presentation/settings_controller.dart';
import 'package:kim/core/data/app_database.dart';
import 'package:kim/features/settings/data/local_settings_repository.dart';
import 'package:sembast/sembast_memory.dart';

class FailingRepository implements SettingsRepository {
  @override
  Future<AppSettings> load() async => const AppSettings();
  @override
  Future<void> save(AppSettings settings) async =>
      throw StateError('disk full');
}

void main() {
  test('rapid settings changes preserve both language and theme', () async {
    final db = await AppDatabase.open(newDatabaseFactoryMemory(), 'rapid.db');
    final repository = LocalSettingsRepository(db);
    final container = ProviderContainer(
      overrides: [settingsRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    final controller = container.read(settingsControllerProvider.notifier);
    await Future.wait([
      controller.setLanguage('en'),
      controller.setTheme(AppTheme.dark),
      controller.setLanguage('ar'),
    ]);
    final state = container.read(settingsControllerProvider);
    final stored = await repository.load();
    expect(state.settings.languageCode, 'ar');
    expect(state.settings.theme, AppTheme.dark);
    expect(stored.languageCode, 'ar');
    expect(stored.theme, AppTheme.dark);
  });
  test(
    'failed persistence keeps committed settings and exposes error',
    () async {
      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(FailingRepository()),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(settingsControllerProvider.notifier);
      expect(await controller.setLanguage('en'), isFalse);
      final state = container.read(settingsControllerProvider);
      expect(state.settings.languageCode, 'ar');
      expect(state.error, isNotNull);
      expect(state.isSaving, isFalse);
    },
  );
}
