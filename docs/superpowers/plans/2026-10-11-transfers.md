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
- [x] Write failing exact quote and real repository tests; run targeted tests (RED).
- [x] Implement rational half-up conversion and transactional linked ledger/fees.
- [x] Run targeted tests (GREEN), including post-first-leg rollback and reopen.
- [x] Commit domain/data and tests.

### Task 2: bilingual transfer UI and integration
Files: presentation/transfer_{copy,providers,editor,row}.dart; transfers_page.dart;
bootstrap.dart/router.dart; wallets_page.dart/wallet_detail_page.dart;
transaction_copy.dart/transaction_row.dart; test/transfers/transfer_ui_test.dart.
- [x] Write/run failing create/edit/cancel UI, fee readonly and privacy tests.
- [x] Implement responsive history/editor, route and wallet entry points.
- [x] Run UI and all Flutter tests/analyze; commit interface and integration.

### Task 3: release, review and real-browser verification
Files: tool/transfer_browser_smoke.cjs/package.json; docs/phase-4-report.md/results/screenshots; README.md/AGENTS.md/git-workflow.md.
- [x] Fresh code review; resolve material issues with regression tests.
- [x] Build local-resource web release and generate offline cache.
- [x] Real Chrome create/FX/fee/edit/cancel/reload/offline/mobile and older suites.
- [x] Record evidence, commit and push feature/wallet-transfers; do not merge main.

## Execution evidence

Builder check found no important gaps. Repository tests were first run with the
missing transfer API (RED), then all 16 real database/domain cases passed.
UI tests first failed for the missing transfer screen; all six now pass.
Fresh review caught the two-wallet direction limitation: the swap regression
failed without the action, then passed with a real reverse transfer.
Chrome exposed an external Symbols-font fallback from a text arrow; replaced
it with bundled icons and validated zero external requests. Localized date and
quote layout were reviewed visually for RTL.
Final analyze has no issues; the complete suite has 73 passing tests.
Release/cache build succeeds with 42 local files; 13 transfer browser cases and
36 prior-feature browser cases pass. Evidence and scope in phase-4-report.md.
Feature implementation/UI/tests were committed together to keep the exhaustive
ledger-kind switch and route integration buildable; focused follow-up commits
cover offline typography and RTL formatting. Only feature/wallet-transfers is
pushed; no main merge and no phase 5.
