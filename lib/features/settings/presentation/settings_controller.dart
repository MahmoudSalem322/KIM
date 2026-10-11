import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/app_settings.dart';
import '../domain/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => throw StateError('Settings repository must be initialized'),
);
final initialSettingsProvider = Provider<AppSettings>(
  (ref) => const AppSettings(),
);
final settingsControllerProvider =
    NotifierProvider<SettingsController, SettingsState>(SettingsController.new);

final class SettingsState {
  const SettingsState(this.settings, {this.isSaving = false, this.error});
  final AppSettings settings;
  final bool isSaving;
  final Object? error;
}

final class SettingsController extends Notifier<SettingsState> {
  Future<void> _pending = Future.value();
  @override
  SettingsState build() => SettingsState(ref.read(initialSettingsProvider));

  Future<bool> setLanguage(String code) {
    if (!['ar', 'en'].contains(code)) {
      throw ArgumentError('Unsupported language');
    }
    return _save((current) => current.copyWith(languageCode: code));
  }

  Future<bool> setTheme(AppTheme theme) =>
      _save((current) => current.copyWith(theme: theme));

  Future<bool> _save(AppSettings Function(AppSettings) transform) {
    final job = _pending.then((_) async {
      if (!ref.mounted) return false;
      final committed = state.settings;
      state = SettingsState(committed, isSaving: true);
      try {
        final next = transform(committed);
        await ref.read(settingsRepositoryProvider).save(next);
        if (ref.mounted) state = SettingsState(next);
        return true;
      } catch (error) {
        if (ref.mounted) state = SettingsState(committed, error: error);
        return false;
      }
    });
    _pending = job.then((_) {});
    return job;
  }
}
