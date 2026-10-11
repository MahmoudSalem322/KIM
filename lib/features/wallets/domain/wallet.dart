import '../../../core/domain/money.dart';
import '../../../core/domain/operation_id.dart';

const walletColors = ['emerald', 'navy', 'blue', 'purple', 'amber', 'rose'];
const walletIcons = ['wallet', 'bank', 'cash', 'card', 'savings', 'digital'];
const walletTypes = ['cash', 'bank', 'credit', 'savings', 'digital', 'other'];

final class WalletFailure implements Exception {
  const WalletFailure(this.code);
  final String code;
  @override
  String toString() => 'WalletFailure($code)';
}

final class WalletOperation {
  WalletOperation(this.id, DateTime at) : at = at.toUtc();
  factory WalletOperation.generate() =>
      WalletOperation(OperationId.generate(), DateTime.now());
  final OperationId id;
  final DateTime at;
}

final class WalletDraft {
  const WalletDraft({
    required this.name,
    required this.color,
    required this.icon,
    required this.type,
    required this.currency,
  });
  final String name, color, icon, type;
  final Currency currency;
  void validate() {
    if (name.trim().isEmpty ||
        name.trim().length > 80 ||
        !walletColors.contains(color) ||
        !walletIcons.contains(icon) ||
        !walletTypes.contains(type)) {
      throw const WalletFailure('invalid');
    }
  }

  Map<String, Object?> toJson() => {
    'name': name.trim(),
    'color': color,
    'icon': icon,
    'type': type,
    'currency': currency.code,
    'scale': currency.scale,
  };
}

final class Wallet {
  Wallet({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
    required this.type,
    required this.currency,
    required this.createdAt,
    required this.updatedAt,
    required this.revision,
    required this.position,
    required this.archived,
    required this.hidden,
  });
  final String id, name, color, icon, type;
  final Currency currency;
  final DateTime createdAt, updatedAt;
  final int revision, position;
  final bool archived, hidden;
  factory Wallet.fromJson(String id, Map<String, Object?> value) => Wallet(
    id: id,
    name: value['name'] as String,
    color: value['color'] as String,
    icon: value['icon'] as String,
    type: value['type'] as String,
    currency: Currency(value['currency'] as String, value['scale'] as int),
    createdAt: DateTime.parse(value['createdAt'] as String),
    updatedAt: DateTime.parse(value['updatedAt'] as String),
    revision: value['revision'] as int,
    position: value['position'] as int,
    archived: value['archived'] as bool,
    hidden: value['hidden'] as bool,
  );
  WalletDraft get draft => WalletDraft(
    name: name,
    color: color,
    icon: icon,
    type: type,
    currency: currency,
  );
}

enum WalletEntryKind {
  opening,
  adjustment,
  income,
  expense,
  reversal,
  transferOut,
  transferIn,
  transferReversal,
}

final class WalletEntry {
  const WalletEntry({
    required this.operationId,
    required this.walletId,
    required this.kind,
    required this.delta,
    required this.before,
    required this.after,
    required this.at,
    required this.reason,
    required this.sequence,
    this.transactionId = '',
    this.transferId = '',
  });
  final String operationId, walletId, reason;
  final String transactionId;
  final String transferId;
  final WalletEntryKind kind;
  final Money delta, before, after;
  final DateTime at;
  final int sequence;
  Map<String, Object?> toJson() => {
    'walletId': walletId,
    'kind': kind.name,
    'delta': delta.toJson(),
    'before': before.toJson(),
    'after': after.toJson(),
    'at': at.toIso8601String(),
    'reason': reason,
    'sequence': sequence,
    if (transactionId.isNotEmpty) 'transactionId': transactionId,
    if (transferId.isNotEmpty) 'transferId': transferId,
  };
  factory WalletEntry.fromJson(String id, Map<String, Object?> value) =>
      WalletEntry(
        operationId: id,
        walletId: value['walletId'] as String,
        kind: WalletEntryKind.values.byName(value['kind'] as String),
        delta: Money.fromJson(Map<String, Object?>.from(value['delta'] as Map)),
        before: Money.fromJson(
          Map<String, Object?>.from(value['before'] as Map),
        ),
        after: Money.fromJson(Map<String, Object?>.from(value['after'] as Map)),
        at: DateTime.parse(value['at'] as String),
        reason: value['reason'] as String,
        sequence: value['sequence'] as int,
        transactionId: value['transactionId'] as String? ?? '',
        transferId: value['transferId'] as String? ?? '',
      );
}

final class WalletSnapshot {
  WalletSnapshot(this.wallet, Iterable<WalletEntry> entries)
    : entries = List.unmodifiable(entries) {
    if (this.entries.isEmpty ||
        this.entries.first.kind != WalletEntryKind.opening ||
        this.entries.first.sequence != 0 ||
        this.entries.first.at != wallet.createdAt) {
      throw const WalletFailure('integrity');
    }
    var total = Money(BigInt.zero, wallet.currency);
    var previousSequence = -1;
    for (final entry in this.entries) {
      if (entry.walletId != wallet.id ||
          entry.sequence <= previousSequence ||
          entry.sequence > wallet.revision ||
          entry.delta.currency != wallet.currency ||
          entry.before.currency != wallet.currency ||
          entry.after.currency != wallet.currency ||
          (previousSequence >= 0 && entry.kind == WalletEntryKind.opening) ||
          (entry.kind == WalletEntryKind.income &&
              entry.delta.minorUnits <= BigInt.zero) ||
          (entry.kind == WalletEntryKind.expense &&
              entry.delta.minorUnits >= BigInt.zero) ||
          ((entry.kind == WalletEntryKind.income ||
                  entry.kind == WalletEntryKind.expense ||
                  entry.kind == WalletEntryKind.reversal) &&
              (entry.transactionId.isEmpty ||
                  entry.delta.minorUnits == BigInt.zero)) ||
          (entry.kind == WalletEntryKind.adjustment &&
              entry.reason.trim().isEmpty) ||
          (entry.kind == WalletEntryKind.transferOut &&
              entry.delta.minorUnits >= BigInt.zero) ||
          (entry.kind == WalletEntryKind.transferIn &&
              entry.delta.minorUnits <= BigInt.zero) ||
          ((entry.kind == WalletEntryKind.transferOut ||
                  entry.kind == WalletEntryKind.transferIn ||
                  entry.kind == WalletEntryKind.transferReversal) &&
              (entry.transferId.isEmpty ||
                  entry.transactionId.isNotEmpty ||
                  entry.delta.minorUnits == BigInt.zero)) ||
          entry.before != total ||
          entry.after != total + entry.delta) {
        throw const WalletFailure('integrity');
      }
      total = entry.after;
      previousSequence = entry.sequence;
    }
    _balance = total;
  }
  final Wallet wallet;
  final List<WalletEntry> entries;
  late final Money _balance;
  Money get balance => _balance;
}
