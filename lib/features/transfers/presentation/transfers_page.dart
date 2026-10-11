import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/design_system/components.dart';
import '../../wallets/presentation/wallet_widgets.dart';
import 'transfer_copy.dart';
import 'transfer_editor.dart';
import 'transfer_providers.dart';
import 'transfer_row.dart';

class TransfersPage extends ConsumerStatefulWidget {
  const TransfersPage({super.key});
  @override
  ConsumerState<TransfersPage> createState() => _TransfersPageState();
}

class _TransfersPageState extends ConsumerState<TransfersPage> {
  String search = '';
  bool showCancelled = true;
  @override
  Widget build(BuildContext context) {
    final s = TransferCopy.of(context), theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s('title'), style: theme.textTheme.headlineLarge),
        const SizedBox(height: 8),
        Text(s('subtitle')),
        const SizedBox(height: 24),
        WalletDataView(
          builder: (wallets) {
            final active = wallets.where((w) => !w.wallet.archived).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    WalletButton(
                      key: const ValueKey('transfer-add'),
                      label: s('add'),
                      icon: Icons.swap_horiz_rounded,
                      onPressed: active.length < 2
                          ? null
                          : () => showTransferEditor(context, wallets),
                    ),
                    WalletButton(
                      label: s('wallets'),
                      secondary: true,
                      onPressed: () => context.go('/wallets'),
                    ),
                  ],
                ),
                if (active.length < 2) ...[
                  const SizedBox(height: 12),
                  Text(s('needWallets')),
                ],
                const SizedBox(height: 24),
                WalletTextField(
                  key: const ValueKey('transfer-search'),
                  label: s('search'),
                  onChanged: (value) => setState(() => search = value),
                ),
                const SizedBox(height: 12),
                FilterChip(
                  label: Text(s('all')),
                  selected: showCancelled,
                  onSelected: (value) => setState(() => showCancelled = value),
                ),
                const SizedBox(height: 24),
                ref
                    .watch(transfersProvider)
                    .when(
                      skipLoadingOnRefresh: false,
                      skipLoadingOnReload: false,
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => WalletCard(
                        child: Column(
                          children: [
                            Text(s.error(e)),
                            TextButton(
                              onPressed: () =>
                                  ref.invalidate(transfersProvider),
                              child: Text(s('retry')),
                            ),
                          ],
                        ),
                      ),
                      data: (all) {
                        final rows = all.where((t) {
                          final names = wallets
                              .where(
                                (w) =>
                                    w.wallet.id == t.draft.sourceId ||
                                    w.wallet.id == t.draft.destinationId,
                              )
                              .map((w) => w.wallet.name)
                              .join(' ');
                          return (showCancelled || !t.cancelled) &&
                              '${t.id} ${t.draft.notes} $names'
                                  .toLowerCase()
                                  .contains(search.trim().toLowerCase());
                        }).toList();
                        if (rows.isEmpty) {
                          return WalletCard(
                            child: SizedBox(
                              width: double.infinity,
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.swap_horiz_rounded,
                                    size: 56,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    s(all.isEmpty ? 'empty' : 'noResults'),
                                    style: theme.textTheme.titleLarge,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    s('emptyBody'),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return Column(
                          children: [
                            for (final t in rows) ...[
                              TransferRow(
                                key: ValueKey('transfer-${t.id}'),
                                transfer: t,
                                wallets: wallets,
                              ),
                              const SizedBox(height: 16),
                            ],
                          ],
                        );
                      },
                    ),
              ],
            );
          },
        ),
      ],
    );
  }
}
