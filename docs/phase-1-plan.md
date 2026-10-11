# Kim foundation implementation plan

Execution: native, in this chat, as explicitly requested by the user.
Goal: complete phase 1 only. Spec: phase-1-design.md.
Stack: Flutter 3.47.2 / Dart 3.13.2, Riverpod, GoRouter, Sembast Web, UUID.

## Global constraints
Offline, no backend/login, Arabic/English, dark/light, exact financial amounts,
permanent storage, no financial feature implementations in phase 1.

## Review focus
Huge amounts on JS; duplicate/concurrent operation keys; migration failure;
rapid settings changes and failed writes; RTL layouts at narrow widths.

## Tasks
- [x] Scaffold web project and resolve compatible packages, bundle fonts.
- [x] Test then implement core/domain/money.dart and operation_id.dart.
      Verify strict precision, currency matching, huge string round trips.
- [x] Test then implement core/data/app_database.dart: versioned migrations,
      settings store and atomic operation receipts; preserve legacy preferences,
      reject newer schemas, rollback failures and conflicting retry payloads.
- [x] Test then implement settings domain/repository/controller; serialized
      save operations, persisted state and visible error handling.
- [x] Test then implement localized app shell, routes and empty feature pages.
      Add shared theme, button, card, field, dialog and navigation components.
- [x] Build web with bundled renderer; generate offline cache and test browser
      reload, navigation, theme/language persistence and offline return.
- [x] Run flutter analyze, full tests and web build. Document files, results
      and platform/storage limits. Stop before phase 2.
