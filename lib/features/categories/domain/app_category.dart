import '../../transactions/domain/financial_transaction.dart';
import '../../wallets/domain/wallet.dart';

const categoryIcons = [
  'category',
  'food',
  'transport',
  'home',
  'health',
  'shopping',
  'salary',
  'gift',
  'work',
  'bill',
  'education',
  'travel',
  'coffee',
  'pet',
  'transfer',
];

final class CategoryDraft {
  const CategoryDraft({
    required this.name,
    required this.kind,
    required this.color,
    required this.icon,
  });
  final String name, color, icon;
  final TransactionKind kind;
  void validate({bool builtin = false}) {
    if ((!builtin && name.trim().isEmpty) ||
        name.trim().length > 80 ||
        !walletColors.contains(color) ||
        !categoryIcons.contains(icon)) {
      throw const WalletFailure('invalidCategory');
    }
  }

  Map<String, Object?> toJson() => {
    'name': name.trim(),
    'kind': kind.name,
    'color': color,
    'icon': icon,
  };
}

final class AppCategory {
  const AppCategory({
    required this.id,
    required this.draft,
    required this.revision,
    required this.archived,
    required this.builtin,
  });
  final String id;
  final CategoryDraft draft;
  final int revision;
  final bool archived, builtin;
  Map<String, Object?> toJson() => {
    ...draft.toJson(),
    'revision': revision,
    'archived': archived,
    'builtin': builtin,
  };
  factory AppCategory.fromJson(String id, Map<String, Object?> value) {
    final category = AppCategory(
      id: id,
      draft: CategoryDraft(
        name: value['name'] as String,
        kind: TransactionKind.values.byName(value['kind'] as String),
        color: value['color'] as String,
        icon: value['icon'] as String,
      ),
      revision: value['revision'] as int,
      archived: value['archived'] as bool,
      builtin: value['builtin'] as bool,
    );
    category.draft.validate(builtin: category.builtin);
    return category;
  }
}

List<AppCategory> defaultCategories() => [
  for (final kind in TransactionKind.values)
    for (final id in categoriesFor(kind))
      AppCategory(
        id: id,
        draft: CategoryDraft(
          name: '',
          kind: kind,
          color: switch (id) {
            'food' => 'emerald',
            'housing' => 'navy',
            'bills' || 'transferFee' => 'amber',
            'health' => 'rose',
            'shopping' => 'purple',
            _ => kind == TransactionKind.income ? 'emerald' : 'blue',
          },
          icon: switch (id) {
            'food' => 'food',
            'transport' => 'transport',
            'housing' => 'home',
            'bills' => 'bill',
            'health' => 'health',
            'shopping' => 'shopping',
            'salary' => 'salary',
            'freelance' => 'work',
            'gift' => 'gift',
            'transferFee' => 'transfer',
            _ => 'category',
          },
        ),
        revision: 0,
        archived: false,
        builtin: true,
      ),
];
