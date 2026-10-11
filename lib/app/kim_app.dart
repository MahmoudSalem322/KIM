import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/domain/app_settings.dart';
import '../features/settings/presentation/settings_controller.dart';
import '../shared/design_system/app_theme.dart';
import '../core/platform/document_language.dart';
import 'router.dart';

class KimApp extends ConsumerWidget {
  const KimApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider).settings;
    updateDocumentLanguage(settings.languageCode);
    return MaterialApp.router(
      title: 'Kim',
      debugShowCheckedModeBanner: false,
      locale: Locale(settings.languageCode),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: AppThemeData.build(Brightness.light, settings.languageCode),
      darkTheme: AppThemeData.build(Brightness.dark, settings.languageCode),
      themeMode: switch (settings.theme) {
        AppTheme.system => ThemeMode.system,
        AppTheme.light => ThemeMode.light,
        AppTheme.dark => ThemeMode.dark,
      },
      routerConfig: ref.watch(routerProvider),
    );
  }
}
