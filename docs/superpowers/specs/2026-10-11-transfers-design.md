# Kim phase 4: wallet transfers

Authorized by the user's phase-4 implementation request. Preserve phase 1–3;
no advanced currency management, live rates, backend, login or phase 5.

Transfers own a UUID, two distinct active wallets, positive principal, source-
currency nonnegative fee, manual decimal rate, notes and immutable timestamps.
One source unit equals rate destination units. Rates accept Arabic digits and
at most 12 fractional digits; use BigInt rational arithmetic, destination-scale
half-up rounding, rejecting a zero received result. Identical currency codes
require rate 1, even when their configured scales differ.

Creation, replacement and cancellation commit all linked ledger entries,
wallet revisions, transfer metadata, fee expense and receipt in one existing
Sembast transaction. Never generate IDs or perform side effects inside retriable
callbacks. A stable command UUID prevents double saves; mismatched reuse fails.
All affected wallets require current revisions and cannot be archived.

Principal entries use transferOut/transferIn/transferReversal and a transferId;
they never become income or expense. A nonzero fee is a genuine expense with
category transferFee and immutable linkedTransferId; ordinary transaction editing
and deletion reject it. Transfer changes reverse previous fee effects and replace
them atomically. Fee IDs derive deterministically from the transfer UUID.

Editing retains reversals and applies replacements, including reassignment of
either wallet. Validate final aggregate debits against available balances; an
atomic edit may temporarily reverse an old credit before its replacement.
Cancellation reverses principal and fees, retaining a cancelled audit record.
If destination funds were spent, cancellation fails without any partial write.
Existing negative wallets may receive funds; any net debit must end nonnegative.
Load and mutation validate transfer metadata against linked ledger totals and
saved FX quote, rejecting corrupted records rather than changing balances.

Add a responsive transfer history/editor, accessible through wallets and a
GoRouter /transfers route; preserve the existing six-item mobile navigation.
Reuse design-system components, Arabic RTL/English and themes. Show direction,
amount, received amount, fees, rate, notes, status and traceable transfer ID.
An explicit swap action supports both directions with exactly two wallets and
clears currency-specific values/FX when the source currency changes.
Use bundled Material arrow icons and an ASCII slash in currency-pair input
labels: the text arrow glyph triggers an engine Symbols-font CDN fallback.
Hide monetary values for hidden wallets; fail closed during wallet refresh and
clear exposed editor values when either wallet becomes hidden. Busy forms lock
all actions and keep command IDs across same-payload retries.

Schema 5 introduces only the transfer marker and backward-compatible optional
links. Preserve old settings, wallets, transactions and receipts.

Verify exact FX, create/edit/cancel/reopen, duplicates, stale/archived wallets,
insufficient funds, rollback after a first leg write, ledger tampering and fee
classification. Run all Flutter tests/analyze, offline release and real Chrome
IndexedDB reload/offline/mobile validation plus previous browser regressions.
