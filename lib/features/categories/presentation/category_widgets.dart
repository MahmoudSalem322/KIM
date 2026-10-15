import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../transactions/presentation/transaction_copy.dart';
import '../domain/app_category.dart';
import 'category_providers.dart';

String categoryLabel(BuildContext context, WidgetRef ref, String id) {
  final item = ref
      .watch(categoriesProvider)
      .value
      ?.where((c) => c.id == id)
      .firstOrNull;
  if (item != null && item.draft.name.isNotEmpty) return item.draft.name;
  if (defaultCategories().any((c) => c.id == id)) {
    return TransactionCopy.of(context)(id);
  }
  return Localizations.localeOf(context).languageCode == 'ar'
      ? 'التصنيف غير متاح'
      : 'Category unavailable';
}

IconData categoryIcon(String icon) => switch (icon) {
  'food' => Icons.restaurant_outlined,
  'transport' => Icons.directions_bus_outlined,
  'home' => Icons.home_outlined,
  'health' => Icons.favorite_border,
  'shopping' => Icons.shopping_bag_outlined,
  'salary' => Icons.payments_outlined,
  'gift' => Icons.card_giftcard,
  'work' => Icons.work_outline,
  'bill' => Icons.receipt_long_outlined,
  'education' => Icons.school_outlined,
  'travel' => Icons.flight_outlined,
  'coffee' => Icons.coffee_outlined,
  'pet' => Icons.pets_outlined,
  'transfer' => Icons.swap_horiz_rounded,
  _ => Icons.category_outlined,
};
