enum AppTheme { system, light, dark }

final class AppSettings {
  const AppSettings({
    this.languageCode = 'ar',
    this.theme = AppTheme.system,
    this.hideBalances = false,
  });
  final String languageCode;
  final AppTheme theme;
  final bool hideBalances;
  AppSettings copyWith({
    String? languageCode,
    AppTheme? theme,
    bool? hideBalances,
  }) => AppSettings(
    languageCode: languageCode ?? this.languageCode,
    theme: theme ?? this.theme,
    hideBalances: hideBalances ?? this.hideBalances,
  );
  Map<String, Object?> toJson() => {
    'languageCode': languageCode,
    'theme': theme.name,
    'hideBalances': hideBalances,
  };
  factory AppSettings.fromJson(Map<String, Object?>? json) => AppSettings(
    languageCode: json?['languageCode'] == 'en' ? 'en' : 'ar',
    hideBalances: json?['hideBalances'] == true,
    theme: AppTheme.values.firstWhere(
      (value) => value.name == json?['theme'],
      orElse: () => AppTheme.system,
    ),
  );
}
