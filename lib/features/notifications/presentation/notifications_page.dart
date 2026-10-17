import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/design_system/components.dart';
import '../../../shared/widgets/operation_action.dart';
import '../../wallets/domain/wallet.dart';
import '../../recurring/presentation/recurring_copy.dart';
import 'notification_providers.dart';
import '../domain/notice.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});
  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  bool unreadOnly = false, dismissed = false, busy = false;
  String? localMessage;
  @override
  Widget build(BuildContext context) {
    final s = RecurringCopy.of(context),
        theme = Theme.of(context),
        notices = ref.watch(noticesProvider),
        preferences = ref.watch(noticePreferencesProvider),
        adapter = ref.watch(reminderAdapterProvider);
    final loading = notices.isLoading || preferences.isLoading,
        error = notices.hasError || preferences.hasError;
    final prefs = loading || error ? null : preferences.requireValue;
    final List<Notice> list = loading || error
        ? <Notice>[]
        : notices.requireValue
              .where(
                (n) =>
                    prefs!.dismissed.contains(n.id) == dismissed &&
                    (!unreadOnly || !prefs.read.contains(n.id)),
              )
              .toList();
    return Column(
      key: const ValueKey('notifications-page'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s('notifications'), style: theme.textTheme.headlineLarge),
        const SizedBox(height: 8),
        Text(s('notificationsSub')),
        const SizedBox(height: 22),
        WalletCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s('localHint')),
              const SizedBox(height: 12),
              if (!adapter.supported)
                Text(s('unavailable'))
              else
                FilledButton.icon(
                  onPressed: busy || prefs == null
                      ? null
                      : () async {
                          setState(() {
                            busy = true;
                            localMessage = null;
                          });
                          try {
                            final enable = !prefs.enabled;
                            if (enable && !await adapter.requestPermission()) {
                              if (mounted) {
                                setState(
                                  () => localMessage = s('permissionDenied'),
                                );
                              }
                              return;
                            }
                            await ref
                                .read(noticeRepositoryProvider)
                                .setFlag(
                                  WalletOperation.generate(),
                                  'preferences',
                                  'enabled',
                                  enable,
                                );
                            if (!enable) await adapter.disable();
                          } catch (_) {
                            if (mounted) {
                              setState(() => localMessage = s('localFailure'));
                            }
                          } finally {
                            if (mounted) setState(() => busy = false);
                          }
                        },
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: Text(
                    s(prefs?.enabled == true ? 'disableLocal' : 'enableLocal'),
                  ),
                ),
              if (localMessage != null) Text(localMessage!),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            FilterChip(
              label: Text(s('unreadOnly')),
              selected: unreadOnly,
              onSelected: (v) => setState(() => unreadOnly = v),
            ),
            FilterChip(
              label: Text(s('showDismissed')),
              selected: dismissed,
              onSelected: (v) => setState(() => dismissed = v),
            ),
            TextButton(
              onPressed: () => context.go('/recurring'),
              child: Text(s('navigation')),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (loading)
          const Center(child: CircularProgressIndicator())
        else if (error)
          WalletCard(
            child: Column(
              children: [
                Text(s('error')),
                TextButton(
                  onPressed: () {
                    ref.invalidate(noticesProvider);
                    ref.invalidate(noticePreferencesProvider);
                  },
                  child: Text(s('retry')),
                ),
              ],
            ),
          )
        else if (list.isEmpty)
          WalletCard(
            child: SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 14),
                  Text(s('emptyNotices'), style: theme.textTheme.titleLarge),
                ],
              ),
            ),
          )
        else
          for (final n in list) ...[
            WalletCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s(n.kind.name),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(n.name, style: theme.textTheme.titleLarge),
                  Text(n.date, textDirection: TextDirection.ltr),
                  if (n.detail.isNotEmpty)
                    Text(
                      n.kind.name == 'blocked'
                          ? s('error-${n.detail}')
                          : s(n.detail),
                    ),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => context.go(n.route),
                        child: Text(s('open')),
                      ),
                      OperationAction(
                        key: ValueKey(
                          'read-${n.id}-${prefs!.read.contains(n.id)}',
                        ),
                        label: s(prefs.read.contains(n.id) ? 'unread' : 'read'),
                        cancelLabel: s('cancel'),
                        errorText: s.error,
                        run: (op) => ref
                            .read(noticeRepositoryProvider)
                            .setFlag(
                              op,
                              n.id,
                              'read',
                              !prefs.read.contains(n.id),
                            ),
                      ),
                      OperationAction(
                        key: ValueKey('dismiss-${n.id}-$dismissed'),
                        label: s(dismissed ? 'restore' : 'dismiss'),
                        cancelLabel: s('cancel'),
                        errorText: s.error,
                        run: (op) => ref
                            .read(noticeRepositoryProvider)
                            .setFlag(op, n.id, 'dismissed', !dismissed),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
      ],
    );
  }
}
