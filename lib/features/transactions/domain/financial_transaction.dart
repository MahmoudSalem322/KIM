import '../../../core/domain/money.dart';
import '../../wallets/domain/wallet.dart';

enum TransactionKind { income, expense }

const incomeCategories = ['salary', 'freelance', 'gift', 'otherIncome'];
const expenseCategories = [
  'food',
  'transport',
  'housing',
  'bills',
  'health',
  'shopping',
  'otherExpense',
  'transferFee',
];
List<String> categoriesFor(TransactionKind kind) =>
    kind == TransactionKind.income ? incomeCategories : expenseCategories;

bool validTransactionDate(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
  final date = DateTime.tryParse(value);
  return date != null &&
      date.year >= 1900 &&
      date.year <= 2100 &&
      calendarDate(date) == value;
}

String calendarDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

final class TransactionDraft {
  const TransactionDraft({
    required this.walletId,
    required this.kind,
    required this.amount,
    required this.category,
    required this.date,
    this.notes = '',
  });
  final String walletId, category, date, notes;
  final TransactionKind kind;
  final Money amount;
  Money get effect => Money(
    kind == TransactionKind.income ? amount.minorUnits : -amount.minorUnits,
    amount.currency,
  );
  void validate() {
    if (walletId.isEmpty || amount.minorUnits <= BigInt.zero) {
      throw const WalletFailure('amount');
    }
    if (!categoriesFor(kind).contains(category) &&
        !RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(category)) {
      throw const WalletFailure('category');
    }
    if (!validTransactionDate(date)) throw const WalletFailure('date');
    if (notes.trim().length > 1000) throw const WalletFailure('notes');
  }

  Map<String, Object?> toJson() => {
    'walletId': walletId,
    'kind': kind.name,
    'amount': amount.toJson(),
    'category': category,
    'date': date,
    'notes': notes.trim(),
  };
  factory TransactionDraft.fromJson(Map<String, Object?> value) =>
      TransactionDraft(
        walletId: value['walletId'] as String,
        kind: TransactionKind.values.byName(value['kind'] as String),
        amount: Money.fromJson(
          Map<String, Object?>.from(value['amount'] as Map),
        ),
        category: value['category'] as String,
        date: value['date'] as String,
        notes: value['notes'] as String,
      );
}

final class FinancialTransaction {
  const FinancialTransaction({
    required this.id,
    required this.draft,
    required this.revision,
    required this.deleted,
    required this.createdAt,
    required this.updatedAt,
    this.linkedTransferId = '',
  });
  final String id;
  final String linkedTransferId;
  final TransactionDraft draft;
  final int revision;
  final bool deleted;
  final DateTime createdAt, updatedAt;
  String get walletId => draft.walletId;
  String get date => draft.date;
  factory FinancialTransaction.fromJson(String id, Map<String, Object?> value) {
    final draft = TransactionDraft.fromJson(value);
    draft.validate();
    return FinancialTransaction(
      id: id,
      draft: draft,
      revision: value['revision'] as int,
      deleted: value['deleted'] as bool,
      createdAt: DateTime.parse(value['createdAt'] as String),
      updatedAt: DateTime.parse(value['updatedAt'] as String),
      linkedTransferId: value['linkedTransferId'] as String? ?? '',
    );
  }
}

final class TransactionQuery {
  const TransactionQuery({
    this.search = '',
    this.kind,
    this.walletId,
    this.category,
    this.from,
    this.to,
    this.deleted = false,
  });
  final String search;
  final TransactionKind? kind;
  final String? walletId, category, from, to;
  final bool? deleted;
  bool matches(
    FinancialTransaction t, {
    String walletName = '',
    String categoryName = '',
  }) =>
      (deleted == null || t.deleted == deleted) &&
      (kind == null || t.draft.kind == kind) &&
      (walletId == null || t.walletId == walletId) &&
      (category == null || t.draft.category == category) &&
      (from == null || t.date.compareTo(from!) >= 0) &&
      (to == null || t.date.compareTo(to!) <= 0) &&
      '${t.draft.notes} $walletName $categoryName ${t.draft.category} ${t.id}'
          .toLowerCase()
          .contains(search.trim().toLowerCase());
}
