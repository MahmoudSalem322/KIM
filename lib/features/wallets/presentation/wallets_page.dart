import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../transfers/presentation/transfer_copy.dart';

import '../../../shared/design_system/components.dart';
import '../domain/wallet.dart';
import 'wallet_card.dart';
import 'wallet_copy.dart';
import 'wallet_editor.dart';
import 'wallet_providers.dart';
import 'wallet_widgets.dart';

class WalletsPage extends ConsumerStatefulWidget {
  const WalletsPage({super.key});
  @override
  ConsumerState<WalletsPage> createState() => _WalletsPageState();
}

class _WalletsPageState extends ConsumerState<WalletsPage> {
  bool archived = false, moving = false;
  WalletOperation? moveOperation;
  String? moveFingerprint;
  Future<void> move(List<WalletSnapshot> active, int from, int to) async {
    if (moving) return;
    final ids = active.map((s) => s.wallet.id).toList();
    final id = ids.removeAt(from);
    ids.insert(to, id);
    final revisions = {for (final s in active) s.wallet.id: s.wallet.revision};
    final fingerprint = '$ids $revisions';
    if (moveFingerprint != fingerprint) {
      moveFingerprint = fingerprint;
      moveOperation = WalletOperation.generate();
    }
    setState(() => moving = true);
    try {
      await ref
          .read(walletRepositoryProvider)
          .reorder(moveOperation!, ids, revisions);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(WalletCopy.of(context).error(e))),
        );
      }
    } finally {
      if (mounted) setState(() => moving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = WalletCopy.of(context), theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s('title'), style: theme.textTheme.headlineLarge),
        const SizedBox(height: 8),
        Text(
          s('subtitle'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        WalletButton(
          key: const ValueKey('wallet-create'),
          label: s('create'),
          icon: Icons.add_rounded,
          onPressed: () => showWalletEditor(context),
        ),
        const SizedBox(height: 28),
        TextButton.icon(
          onPressed: () => context.go('/transfers'),
          icon: const Icon(Icons.swap_horiz_rounded),
          label: Text(TransferCopy.of(context)('navigation')),
        ),
        const SizedBox(height: 18),
        WalletDataView(
          builder: (all) {
            final active = all.where((s) => !s.wallet.archived).toList();
            final visible = all
                .where((s) => s.wallet.archived == archived)
                .toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (active.isNotEmpty) ...[
                  Text(
                    '${active.length} ${s('count')}',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  WalletTotals(wallets: active),
                  const SizedBox(height: 24),
                ],
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    OutlinedButton(
                      key: const ValueKey('wallet-active'),
                      onPressed: () => setState(() => archived = false),
                      child: Text('${s('active')} (${active.length})'),
                    ),
                    OutlinedButton(
                      key: const ValueKey('wallet-archived'),
                      onPressed: () => setState(() => archived = true),
                      child: Text(
                        '${s('archived')} (${all.length - active.length})',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (visible.isEmpty)
                  WalletCard(
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        children: [
                          Icon(
                            archived
                                ? Icons.inventory_2_outlined
                                : Icons.account_balance_wallet_outlined,
                            size: 56,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            s(archived ? 'emptyArchive' : 'empty'),
                            style: theme.textTheme.titleLarge,
                          ),
                          if (!archived) ...[
                            const SizedBox(height: 10),
                            Text(s('emptyBody'), textAlign: TextAlign.center),
                          ],
                        ],
                      ),
                    ),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 1000
                          ? 3
                          : constraints.maxWidth >= 640
                          ? 2
                          : 1;
                      final width =
                          (constraints.maxWidth - 20 * (columns - 1)) / columns;
                      return Wrap(
                        spacing: 20,
                        runSpacing: 20,
                        children: [
                          for (var i = 0; i < visible.length; i++)
                            SizedBox(
                              width: width,
                              child: FinancialWalletCard(
                                key: ValueKey('wallet-${visible[i].wallet.id}'),
                                snapshot: visible[i],
                                moveUp: !archived && i > 0 && !moving
                                    ? () => move(active, i, i - 1)
                                    : null,
                                moveDown:
                                    !archived &&
                                        i < visible.length - 1 &&
                                        !moving
                                    ? () => move(active, i, i + 1)
                                    : null,
                              ),
                            ),
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
