import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/design_system/components.dart';
import '../../../shared/widgets/operation_action.dart';
import '../../transactions/domain/financial_transaction.dart';
import '../../wallets/domain/wallet.dart';
import '../../wallets/presentation/wallet_copy.dart';
import '../domain/app_category.dart';
import 'category_providers.dart';
import 'category_widgets.dart';
import 'planning_copy.dart';

class CategoriesPage extends ConsumerStatefulWidget {
  const CategoriesPage({super.key});
  @override
  ConsumerState<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends ConsumerState<CategoriesPage> {
  TransactionKind kind = TransactionKind.expense;
  bool archived = false;
  @override
  Widget build(BuildContext context) {
    final s = PlanningCopy.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s('categories'), style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 8),
        Text(s('categoriesSub')),
        const SizedBox(height: 24),
        FilledButton.icon(
          key: const ValueKey('category-add'),
          onPressed: () => showCategoryEditor(context, kind: kind),
          icon: const Icon(Icons.add),
          label: Text(s('addCategory')),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<TransactionKind>(
              segments: [
                for (final k in TransactionKind.values)
                  ButtonSegment(value: k, label: Text(s(k.name))),
              ],
              selected: {kind},
              onSelectionChanged: (v) => setState(() => kind = v.single),
            ),
            FilterChip(
              label: Text(s('showArchived')),
              selected: archived,
              onSelected: (v) => setState(() => archived = v),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(s('historyNote'), style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 20),
        ref
            .watch(categoriesProvider)
            .when(
              skipLoadingOnRefresh: false,
              skipLoadingOnReload: false,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Column(
                children: [
                  Text(s.error(e)),
                  TextButton(
                    onPressed: () => ref.invalidate(categoriesProvider),
                    child: Text(s('retry')),
                  ),
                ],
              ),
              data: (all) => Column(
                children: [
                  for (final c in all.where(
                    (c) => c.draft.kind == kind && c.archived == archived,
                  )) ...[
                    WalletCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: walletColor(c.draft.color)
                                    .withValues(alpha: .12),
                                child: Icon(
                                  categoryIcon(c.draft.icon),
                                  color: walletColor(c.draft.color),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      categoryLabel(context, ref, c.id),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    Text(s(c.builtin ? 'builtin' : 'custom')),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 10,
                            runSpacing: 4,
                            children: [
                              TextButton(
                                onPressed: () =>
                                    showCategoryEditor(context, category: c),
                                child: Text(s('edit')),
                              ),
                              if (c.id != 'transferFee')
                                OperationAction(
                                  key: ValueKey(
                                    'category-archive-${c.id}-${c.revision}',
                                  ),
                                  label: s(c.archived ? 'restore' : 'archive'),
                                  errorText: s.error,
                                  cancelLabel: s('cancel'),
                                  run: (op) => ref
                                      .read(categoryRepositoryProvider)
                                      .setArchived(
                                        op,
                                        c.id,
                                        c.revision,
                                        !c.archived,
                                      ),
                                ),
                              if (!c.builtin)
                                OperationAction(
                                  key: ValueKey(
                                    'category-delete-${c.id}-${c.revision}',
                                  ),
                                  label: s('delete'),
                                  confirm: s('deleteConfirm'),
                                  errorText: s.error,
                                  cancelLabel: s('cancel'),
                                  run: (op) => ref
                                      .read(categoryRepositoryProvider)
                                      .delete(op, c.id, c.revision),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
      ],
    );
  }
}

Future<void> showCategoryEditor(
  BuildContext context, {
  AppCategory? category,
  TransactionKind kind = TransactionKind.expense,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _CategoryEditor(category: category, kind: kind),
);

class _CategoryEditor extends ConsumerStatefulWidget {
  const _CategoryEditor({this.category, required this.kind});
  final AppCategory? category;
  final TransactionKind kind;
  @override
  ConsumerState<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends ConsumerState<_CategoryEditor> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(
    text: widget.category?.draft.name ?? '',
  );
  late String color = widget.category?.draft.color ?? 'emerald',
      icon = widget.category?.draft.icon ?? 'category';
  late TransactionKind kind = widget.category?.draft.kind ?? widget.kind;
  bool busy = false;
  String? error, fingerprint;
  WalletOperation? op;
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = PlanningCopy.of(context), w = WalletCopy.of(context);
    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        title: Text(
          s(widget.category == null ? 'addCategory' : 'editCategory'),
        ),
        scrollable: true,
        content: SizedBox(
          width: 460,
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WalletTextField(
                  key: const ValueKey('category-name'),
                  label: s('name'),
                  controller: name,
                  enabled: !busy,
                  validator: (v) =>
                      ((v?.trim().isEmpty ?? true) &&
                              widget.category?.builtin != true) ||
                          (v?.trim().length ?? 0) > 80
                      ? s('invalidCategory')
                      : null,
                ),
                const SizedBox(height: 18),
                SegmentedButton<TransactionKind>(
                  segments: [
                    for (final k in TransactionKind.values)
                      ButtonSegment(value: k, label: Text(s(k.name))),
                  ],
                  selected: {kind},
                  onSelectionChanged: busy || widget.category != null
                      ? null
                      : (v) => setState(() => kind = v.single),
                ),
                const SizedBox(height: 18),
                Text(s('color')),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in walletColors)
                      ChoiceChip(
                        label: Text(w(c)),
                        avatar: Icon(
                          Icons.circle,
                          color: walletColor(c),
                          size: 16,
                        ),
                        selected: color == c,
                        onSelected: busy
                            ? null
                            : (_) => setState(() => color = c),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(s('icon')),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final i in categoryIcons)
                      IconButton.filledTonal(
                        isSelected: icon == i,
                        tooltip: s('icon-$i'),
                        onPressed: busy ? null : () => setState(() => icon = i),
                        icon: Icon(categoryIcon(i)),
                      ),
                  ],
                ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            child: Text(s('cancel')),
          ),
          FilledButton(
            key: const ValueKey('category-save'),
            onPressed: busy
                ? null
                : () async {
                    if (!form.currentState!.validate()) return;
                    final draft = CategoryDraft(
                      name: name.text,
                      kind: kind,
                      color: color,
                      icon: icon,
                    );
                    final next = jsonEncode(draft.toJson());
                    if (next != fingerprint) {
                      fingerprint = next;
                      op = WalletOperation.generate();
                    }
                    setState(() {
                      busy = true;
                      error = null;
                    });
                    try {
                      final repo = ref.read(categoryRepositoryProvider),
                          c = widget.category;
                      if (c == null) {
                        await repo.create(op!, draft);
                      } else {
                        await repo.edit(op!, c.id, c.revision, draft);
                      }
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (mounted) setState(() => error = s.error(e));
                    } finally {
                      if (mounted) setState(() => busy = false);
                    }
                  },
            child: Text(s('save')),
          ),
        ],
      ),
    );
  }
}
