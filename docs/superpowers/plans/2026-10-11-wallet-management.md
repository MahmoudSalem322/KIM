# Wallet Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Fully implement phase 2 wallets while preserving phase 1.
**Architecture:** Immutable exact ledger, atomic repository commands, Riverpod streams and GoRouter detail pages. Existing local web database and design tokens.
**Tech Stack:** Flutter 3.47.2, Dart 3.13.2, Riverpod, GoRouter, Sembast Web, UUID.
**Spec:** ../specs/2026-10-11-wallet-management-design.md

## Global Constraints
Phase 2 only; Kim name; no backend/login; offline local; Arabic/English RTL/LTR;
light/dark/system; BigInt money and string persistence; no new dependencies.

## Review Focus
- Replayed submits and different payloads sharing an ID must never duplicate money.
- Stale multi-tab adjustments must fail instead of replacing a newer balance.
- Negative/zero/huge openings and custom precision must survive serialization.
- Archive/reorder races and failed writes must preserve complete prior state.
- Hidden balances must not leak through detail history/dashboard or semantics.

### Task 1: Exact wallet domain and durable ledger
Files: lib/features/wallets/domain/{wallet.dart,wallet_repository.dart},
lib/features/wallets/data/local_wallet_repository.dart, core/data/app_database.dart,
test/wallets/wallet_repository_test.dart.
Interfaces: WalletDraft, WalletSnapshot, WalletEntry, WalletOperation;
WalletRepository.watch(), load(), create(id, draft, opening, at), edit(id,...),
adjust(id, walletId, revision, target, reason, at), archive/hidden, reorder.
- [ ] Write tests for real repository: create/opening, metadata edits, adjustment,
      replay/conflict, stale writes, archived rejection, reorder, hide and reopen.
- [ ] Run flutter test test/wallets: missing implementation must fail.
- [ ] Implement immutable entities, canonical receipts and atomic stores/schema 3.
- [ ] Run tests; add schema v2 preservation and rollback/conflict edge coverage.
- [ ] Commit domain/repository and meaningful financial tests.

### Task 2: Wallet UI and app integration
Files: wallets/presentation/{wallet_providers,wallets_page,wallet_detail_page,
wallet_editor,wallet_adjustment,wallet_card,wallet_copy}.dart; bootstrap/router/
shell/dashboard; test/wallets/wallet_ui_test.dart and existing app tests.
Interfaces: injected WalletRepository; StreamProvider<List<WalletSnapshot>>;
forms retain operation IDs for write retries, state/error/retry/localization.
- [ ] Write UI tests for creation, detail/edit, adjustment and hidden text.
- [ ] Run to confirm missing UI behavior, then implement responsive components.
- [ ] Route /wallets/:id, archived/active lists, reorder, archive/restore and hide.
- [ ] Reflect real wallets on dashboard, preserving other future empty pages.
- [ ] Run widgets in Arabic/dark/mobile; commit presentation integration.

### Task 3: Release/offline verification and report
Files: tool/wallet_browser_smoke.cjs, docs/phase-2-report.md, README.md.
- [ ] Build real browser smoke assertions for creation/edit/reload, ledger accuracy,
      settlement reason/history, privacy, order and archived persistence offline.
- [ ] Run flutter analyze, flutter test, release web build and regenerate cache.
- [ ] Run Chrome test, inspect screenshots and fix observed issues.
- [ ] Request independent whole-feature review and resolve actual findings.
- [ ] Commit report/results and push feature/wallet-management; no phase 3,
      no merge to main without a new merge request.
