# Kim phase 3: income and expenses

User authorizes implementation, preserving phase 1/2 and excluding transfers.
Flutter Web, offline IndexedDB/Sembast, Riverpod/GoRouter, Arabic/English and
shared themes/components remain. No dependencies or backend added.
Branch feature/income-expenses starts from main and includes wallet branch as
a dependency without merging main. Implementation proceeds inline.

Transaction metadata: UUID, income/expense, wallet ID, positive exact Money,
category key from fixed translated choices, calendar date YYYY-MM-DD,
notes <=1000, UTC created/updated timestamps, optimistic revision, deleted flag.
Categories are static choices, not dummy financial data: income salary/freelance/
gift/otherIncome; expense food/transport/housing/bills/health/shopping/otherExpense.
No category management this phase. Date permits historical entries (1900..2100).
Future dates allowed; entry affects current balance immediately, no scheduling.
All currencies use wallet's immutable currency and scale, no conversion.

Extend wallet ledger kinds with income, expense, reversal. Every mutation adds
immutable audit entries with transaction ID. Creation adds signed effect.
Editing reverses prior effect and appends replacement, even when only metadata
changes; deleting reverses once and tombstones transaction. No original entry
removed. Entries follow recording sequence, independent of business date;
backdated operations never rewrite subsequent settlements or opening balances.
Current balance = opening + settlements + net transaction effects.

Transactions repository atomically writes metadata, ledger, wallet revisions,
and operation receipt via applyOnce. UUID command retained across retries;
secondary reversal entry ID deterministically UUID-v5 from command UUID.
All command IDs created outside retry callbacks. Transaction revision AND
expected wallet revisions guard stale commands and archive races. Editing can
reassign to another active wallet (reverse old, apply new atomically); no transfer
feature. Wallet currency must match replacement amount; require explicit input
when wallet currency changes. Archived wallets are read-only including deletion;
restore first. Atomic rollback if any wallet/history invalid. Deleted rows remain
as evidence but hidden from normal list; optional cancelled status filter exposes
them read-only. Privacy masks transaction amounts for hidden wallets and clears
open editor amount on a live transition to hidden, fail closed on loading.

UI: quick add dialog with type, wallet, category, amount, calendar picker, notes;
busy/retry/error, stable operation fingerprint. Transactions list with search in
notes/category/wallet, type/wallet/category/date-range/status filters, clear filters,
newest business date first (stable tie by created/id). Edit and confirmed delete;
empty/no-result/loading/error states. Live wallets and transaction providers.
Dashboard recent actual operations replaces activity empty state, wallet details
label new ledger kinds accurately and link transaction history. No mixed totals.

Schema 4 adds transaction schema marker lazily; v3 wallets/history/settings/
receipts preserved. Tests: income/expense decimals/Arabic/huge amounts, replay,
conflicting IDs, edit amount/type/wallet/date, delete twice, old operations after
settlement, failed writes rollback, archive/stale races, reopen/migration,
search/filter, UI edit/delete/validation/privacy, Chrome reload/offline/two tabs.
Analyze, full tests, release build + offline cache + browser verification required.
Final report includes files, checks, limitations; push feature branch only.
