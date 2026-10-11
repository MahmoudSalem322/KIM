import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/wallet.dart';
import '../domain/wallet_repository.dart';
import 'wallet_copy.dart';
import 'wallet_providers.dart';

class WalletDataView extends ConsumerWidget {
  const WalletDataView({super.key, required this.builder});
  final Widget Function(List<WalletSnapshot>) builder;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(walletsProvider)
      .when(
        data: builder,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Column(
          children: [
            Text(WalletCopy.of(context)('loadError')),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => ref.invalidate(walletsProvider),
              child: Text(WalletCopy.of(context)('retry')),
            ),
          ],
        ),
      );
}

class WalletActionButton extends ConsumerStatefulWidget {
  const WalletActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.requestKey,
    required this.action,
    this.enabled = true,
    this.confirmation,
  });
  final String label, requestKey;
  final IconData icon;
  final bool enabled;
  final String? confirmation;
  final Future<void> Function(WalletRepository, WalletOperation) action;
  @override
  ConsumerState<WalletActionButton> createState() => _WalletActionButtonState();
}

class _WalletActionButtonState extends ConsumerState<WalletActionButton> {
  bool busy = false;
  WalletOperation? operation;
  @override
  void didUpdateWidget(covariant WalletActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.requestKey != widget.requestKey) operation = null;
  }

  Future<void> run() async {
    if (busy) return;
    if (widget.confirmation != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(widget.label),
          content: Text(widget.confirmation!),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(WalletCopy.of(context)('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(widget.label),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    if (busy) return;
    setState(() => busy = true);
    operation ??= WalletOperation.generate();
    try {
      await widget.action(ref.read(walletRepositoryProvider), operation!);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(WalletCopy.of(context).error(error))),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: widget.enabled && !busy ? run : null,
    icon: busy
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(widget.icon, size: 19),
    label: Text(widget.label),
  );
}

class WalletTotals extends StatelessWidget {
  const WalletTotals({super.key, required this.wallets});
  final List<WalletSnapshot> wallets;
  @override
  Widget build(BuildContext context) {
    final s = WalletCopy.of(context);
    final grouped = <Object, List<WalletSnapshot>>{};
    for (final snapshot in wallets.where((w) => !w.wallet.archived)) {
      (grouped[snapshot.wallet.currency] ??= []).add(snapshot);
    }
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final group in grouped.values)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${group.first.wallet.currency.code} · ${group.first.wallet.currency.scale} ${s('scale')}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  group.any((w) => w.wallet.hidden)
                      ? s('privacyTotals')
                      : '${group.skip(1).fold(group.first.balance, (sum, w) => sum + w.balance).decimal} ${group.first.wallet.currency.code}',
                  textDirection: group.any((w) => w.wallet.hidden)
                      ? null
                      : TextDirection.ltr,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
