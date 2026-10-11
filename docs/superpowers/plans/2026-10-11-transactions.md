# Income and expenses implementation plan

> REQUIRED SUB-SKILL: executing-plans; implement inline, review whole branch once.

**Goal:** Durable income/expense creation, editing, cancellation and searchable history.
**Architecture:** Transaction metadata with immutable wallet ledger compensations,
atomic receipts and revision guards; providers supply real snapshots.
**Tech Stack:** Existing Flutter, Riverpod, GoRouter, Sembast Web, UUID, BigInt.
**Spec:** ../specs/2026-10-11-transactions-design.md

## Global constraints
Phase 3 only, no transfers, no backend/new dependencies, Kim name, bilingual and
offline; no double money. Preserve phase 2 opening/settlement history.

## Review focus
Backdating after settlement does not overwrite it; moving an edited operation
between wallets rolls back entirely on failure; stale delete cannot reverse twice;
different currency requires explicit replacement amount; hidden balances do not
leak through list or open editor.

### Task 1: Exact domain and atomic transactions
Files: transactions/domain/{financial_transaction,transaction_repository}.dart,
transactions/data/local_transaction_repository.dart, wallet.dart and database.
Interfaces: TransactionDraft, FinancialTransaction, TransactionQuery;
create(op,draft,revisions), edit(op,id,revision,draft,revisions),
delete(op,id,revision,revisions), load/watch; existing WalletOperation reused.
- [x] Add real-file repository tests with literal expected balances and RED run.
- [x] Implement categories/calendar validation, query, immutable ledger kinds.
- [x] Implement create/edit/delete atomically and schema 4 migration preservation.
- [x] Run repository/full tests; commit scoped domain/data feature.

### Task 2: Presentation and integration
Files: transactions/presentation providers/copy/editor/page/row, bootstrap,
wallet detail, dashboard; tests for real create/edit/cancel/filter flows.
- [x] Write widget failures; implement bilingual responsive editor and history.
- [x] Add search/type/wallet/category/date/status filters and confirmation.
- [x] Reflect ledger/recent transactions and privacy; run full tests; commit.

### Task 3: Web and review
Files: tool/transaction_browser_smoke.cjs, docs/phase-3-report.md, README.
- [x] Verify analyze/tests/release build/offline cache and real Chrome flows.
- [x] Review branch independently; reproduce and fix substantial findings.
- [x] Inspect screenshots, record results, commit and push feature/income-expenses.

## Execution ledger
Ruling: Include verified phase 2 dependency in the feature branch while main stays
unchanged — transactions need wallets — integration remains for user's merge request.
Ruling: Cancellation uses retained metadata plus immutable reversal, not physical
erasure — balances and traceability — storage grows with audit history.

Task 1: complete — 451f432 — repository RED (missing feature) to GREEN; financial literals and real reopen/migration verified.
Task 2: complete — 2cb9bb2 — widget RED (missing provider) to GREEN; full suite 50/50 and clean analyze.
Final review: one P2 privacy-on-refresh defect; no deferred minors.
Final: fixed privacy while refreshing — refreshing visible wallet data conceals and clears editor until new snapshot — RED (7.25 retained) to GREEN, full suite 51/51; b25836c.
Final verification: analyze clean; release build +42 cached resources; transactions Chrome 11/11, no runtime errors or external requests.
Final regression: wallets Chrome 15/15; foundation Chrome 10/10 including 7 JavaScript money/ID assertions.
