import '../../../core/domain/money.dart';
import '../../wallets/domain/wallet.dart';
import 'exchange_rate.dart';

final class TransferDraft {
  const TransferDraft({
    required this.sourceId,
    required this.destinationId,
    required this.amount,
    required this.fee,
    required this.rate,
    this.notes = '',
  });
  final String sourceId, destinationId, notes;
  final Money amount, fee;
  final ExchangeRate rate;
  void validate() {
    if (sourceId.isEmpty ||
        destinationId.isEmpty ||
        sourceId == destinationId) {
      throw const WalletFailure('wallets');
    }
    if (amount.minorUnits <= BigInt.zero || fee.minorUnits < BigInt.zero) {
      throw const WalletFailure('amount');
    }
    if (amount.currency != fee.currency) throw const WalletFailure('currency');
    if (notes.trim().length > 1000) throw const WalletFailure('notes');
  }

  Money quote(Currency destination) {
    validate();
    if (amount.currency.code == destination.code && rate.decimal != '1') {
      throw const WalletFailure('rate');
    }
    final result = rate.convert(amount, destination);
    if (result.minorUnits <= BigInt.zero) throw const WalletFailure('rounding');
    return result;
  }

  Map<String, Object?> toJson() => {
    'sourceId': sourceId,
    'destinationId': destinationId,
    'amount': amount.toJson(),
    'fee': fee.toJson(),
    'rate': rate.decimal,
    'notes': notes.trim(),
  };
  factory TransferDraft.fromJson(Map<String, Object?> json) => TransferDraft(
    sourceId: json['sourceId'] as String,
    destinationId: json['destinationId'] as String,
    amount: Money.fromJson(Map<String, Object?>.from(json['amount'] as Map)),
    fee: Money.fromJson(Map<String, Object?>.from(json['fee'] as Map)),
    rate: ExchangeRate.parse(json['rate'] as String),
    notes: json['notes'] as String,
  );
}

final class WalletTransfer {
  const WalletTransfer({
    required this.id,
    required this.draft,
    required this.received,
    required this.revision,
    required this.cancelled,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id;
  final TransferDraft draft;
  final Money received;
  final int revision;
  final bool cancelled;
  final DateTime createdAt, updatedAt;
  factory WalletTransfer.fromJson(String id, Map<String, Object?> json) {
    final draft = TransferDraft.fromJson(json);
    final received = Money.fromJson(
      Map<String, Object?>.from(json['received'] as Map),
    );
    if (json['rounding'] != 'halfUp' ||
        draft.quote(received.currency) != received) {
      throw const WalletFailure('integrity');
    }
    return WalletTransfer(
      id: id,
      draft: draft,
      received: received,
      revision: json['revision'] as int,
      cancelled: json['cancelled'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
