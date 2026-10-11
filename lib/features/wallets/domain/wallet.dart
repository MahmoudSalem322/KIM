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

enum WalletEntryKind { opening, adjustment }

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
  });
  final String operationId, walletId, reason;
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
      );
}

final class WalletSnapshot {
  WalletSnapshot(this.wallet, Iterable<WalletEntry> entries)
    : entries = List.unmodifiable(entries);
  final Wallet wallet;
  final List<WalletEntry> entries;
  Money get balance => entries.fold(
    Money(BigInt.zero, wallet.currency),
    (total, e) => total + e.delta,
  );
}
