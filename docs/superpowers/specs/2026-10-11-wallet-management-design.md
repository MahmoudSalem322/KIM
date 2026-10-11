# Kim phase 2: wallet management design

User explicitly authorizes implementation of phase 2 only. Existing name Kim
is retained despite the historical project name MyWallet in the request.

Unlimited wallets, local/offline IndexedDB, Arabic/English, dark/light/system,
existing premium design system; no dependencies added. No generic income,
expenses or transfers. Existing settings and financial foundations stay intact.

Wallet metadata: UUID, trimmed non-empty name, palette color, icon key, type,
immutable Currency(code, explicit scale), created/updated UTC timestamp,
revision for optimistic concurrency, integer position, archived and hidden flags.
Supported common currencies plus custom uppercase three-letter code and explicit
0..6 decimal scale. Negative opening balances supported for liabilities.

Immutable ledger entries: operation UUID, wallet UUID, opening/adjustment kind,
exact delta as minor-unit string, previous/resulting balances, UTC timestamp,
non-empty adjustment reason, monotonically increasing wallet revision/sequence.
Creation always records an opening entry, even for zero. Balance is derived from
entries; metadata editing cannot replace it. Adjustment asks for the correct
current balance and reason, computes delta in one atomic transaction, refuses
no-op, stale revision, archived wallet, different-currency payloads. All writes
use applyOnce receipts with retained command IDs/timestamps and canonical payloads.
UI retries retain the exact command; changing inputs deliberately creates a new
command. Optimistic revisions prevent lost edits across tabs.

Archive is reversible. Archived wallets have read-only financial history and
cannot be edited or adjusted until restored. Restore appends to active order.
Reordering validates the complete active set atomically; no hardcoded wallet cap.
Hidden balances never appear in list/detail/history/aggregate semantics; hide
also suppresses dashboard amounts. Privacy is local presentation, not encryption.
No meaningless mixed-currency total. Wallet summaries group exact totals by
currency; totals withheld when a relevant wallet is hidden.

UI: responsive fintech wallet cards, create/edit form dialog, palette and icon
choices, type/currency/opening amount, wallet detail route /wallets/:id,
opening and adjustment timeline, balance adjustment dialog with preview/reason,
archive/restore confirmation, show/hide balance and move up/down controls,
active/archived tabs, loading/error/retry and honest empty states. Header shows
count and totals per currency only. Dashboard reflects real wallet count/data.

Schema 3 adds named wallets and wallet_entries stores, preserving preferences
and receipts. Migration from v2 yields empty stores without fake financial data.
Feature boundaries: wallets/domain entities + repository contract;
wallets/data local repository; presentation providers, pages, forms and cards.
Bootstrap injects repository. Stream snapshots read metadata and ledger in one
transaction and refresh on metadata revision changes.

Acceptance: analyze clean, all old/new tests green, release build and offline
browser creation/edit/reload/detail/adjustment/archive/reorder/hide tests pass.
Tests prove opening accuracy for huge/Arabic/negative/zero values, exact delta,
idempotency/conflicting IDs, rollback/stale edits, migration/persistence and
no overwrite of original entries. Read-only review before completion.

Builder rulings: totals key by Currency(code,scale); reorder validates every active expected revision; privacy toggles allowed on archived wallets; two-tab stale financial/order verification required.

