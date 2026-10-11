# Kim — phase 1

User-authorized scope: create a Flutter Web foundation only. No wallet CRUD,
transactions, budget calculations, backend, authentication, or sample balances.

## Architecture
Feature-first: app composition and routing; shared core for money, operation
identifiers, database and localization; shared design system; features with
presentation/domain/data boundaries where behavior exists. Settings are the
first complete vertical slice. Other features expose honest empty pages only.

Riverpod supplies dependencies and settings state; GoRouter supplies URL routes.
Sembast Web persists locally in IndexedDB with cross-tab transaction support.
Database schema versions and migrations are transactional. No storage failure
may silently fall back to memory. Money uses BigInt minor units, explicit ISO
currency and scale, strict decimal parsing and string serialization. Operations
use UUID v4 and an atomic idempotency receipt helper for future financial writes.

## Design decisions (implementation choices)
Arabic default, English switch, RTL/LTR through Flutter localization. System,
light and dark themes. Navy/emerald palette, restrained rounded cards, bundled
Arabic/Latin typography, accessible controls. Responsive sidebar above 900px;
compact navigation below. Dashboard, wallets, transactions, budgets, reports,
settings. No pretend action buttons for unfinished functions.

## Offline
No runtime backend, CDN fonts or external requests. Bundle web renderer resources
and a service worker that caches the release build for offline revisits. First
visit requires a local server or internet; offline revisits require HTTPS or
localhost. Browser-origin storage remains subject to browser deletion/quotas.

## Acceptance
Analyze clean, all tests pass, release web builds, browser navigation works in
both languages/themes, settings survive reload, assets load offline after cache
installation. Migration tests preserve old settings; operation receipts reject
conflicting retries and roll back failed writes. Mobile widths show no overflow.
