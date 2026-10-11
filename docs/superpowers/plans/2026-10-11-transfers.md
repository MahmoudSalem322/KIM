# Wallet Transfers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: use executing-plans for inline implementation, then requesting-code-review for a fresh whole-branch review.

**Goal:** Durable exact transfers between Kim wallets, without double-counting principal.
**Architecture:** Feature-first transfer domain/data/presentation; existing atomic database and wallet ledger; linked readonly fee expenses.
**Tech Stack:** Existing Flutter, Riverpod, GoRouter, Sembast Web, UUID, BigInt; no new packages.
**Spec:** docs/superpowers/specs/2026-10-11-transfers-design.md

## Global constraints
One approved phase; offline Flutter Web; Arabic/English/themes; exact amounts;
immutable audit history; optimistic revisions; atomic idempotent persistence.

## Review focus
- Two tabs editing either side must reject stale commands.
- Fee expenses must remain readonly outside the owning transfer.
- Hidden or refreshing wallets must not leak old editor values.
- Same code with differing minor-unit precision must convert at rate 1.
- Net edit debits, including swapped wallets, must validate final balances.

### Task 1: exact domain and atomic persistence
Files: lib/features/transfers/domain/{exchange_rate,wallet_transfer,transfer_repository}.dart;
data/local_transfer_repository.dart; wallet.dart ledger links/kinds;
app_database.dart migration 5; financial_transaction.dart optional fee ownership;
local_transaction_repository.dart reject linked edits; test/transfers/transfer_repository_test.dart.
Interfaces: TransferRepository.load/watch/create(op,draft,revisions)/edit(op,id,revision,draft,revisions)/cancel(op,id,revision,revisions).
- [ ] Write failing exact quote and real repository tests; run targeted tests (RED).
- [ ] Implement rational half-up conversion and transactional linked ledger/fees.
- [ ] Run targeted tests (GREEN), including post-first-leg rollback and reopen.
- [ ] Commit domain/data and tests.

### Task 2: bilingual transfer UI and integration
Files: presentation/transfer_{copy,providers,editor,row}.dart; transfers_page.dart;
bootstrap.dart/router.dart; wallets_page.dart/wallet_detail_page.dart;
transaction_copy.dart/transaction_row.dart; test/transfers/transfer_ui_test.dart.
- [ ] Write/run failing create/edit/cancel UI, fee readonly and privacy tests.
- [ ] Implement responsive history/editor, route and wallet entry points.
- [ ] Run UI and all Flutter tests/analyze; commit interface and integration.

### Task 3: release, review and real-browser verification
Files: tool/transfer_browser_smoke.cjs/package.json; docs/phase-4-report.md/results/screenshots; README.md/AGENTS.md/git-workflow.md.
- [ ] Fresh code review; resolve material issues with regression tests.
- [ ] Build local-resource web release and generate offline cache.
- [ ] Real Chrome create/FX/fee/edit/cancel/reload/offline/mobile and older suites.
- [ ] Record evidence, commit and push feature/wallet-transfers; do not merge main.
