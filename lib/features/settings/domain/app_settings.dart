enum AppTheme { system, light, dark }

final class AppSettings {
  const AppSettings({this.languageCode = 'ar', this.theme = AppTheme.system});
  final String languageCode;
  final AppTheme theme;
  AppSettings copyWith({String? languageCode, AppTheme? theme}) => AppSettings(
    languageCode: languageCode ?? this.languageCode,
    theme: theme ?? this.theme,
  );
  Map<String, Object?> toJson() => {
    'languageCode': languageCode,
    'theme': theme.name,
  };
  factory AppSettings.fromJson(Map<String, Object?>? json) => AppSettings(
    languageCode: json?['languageCode'] == 'en' ? 'en' : 'ar',
    theme: AppTheme.values.firstWhere(
      (value) => value.name == json?['theme'],
      orElse: () => AppTheme.system,
    ),
  );
}
