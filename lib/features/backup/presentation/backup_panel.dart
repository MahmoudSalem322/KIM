import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../reports/export/export_download.dart';
import '../../security/presentation/security_copy.dart';
import '../../security/presentation/security_controller.dart';
import '../../wallets/domain/wallet.dart';
import '../../notifications/presentation/notification_providers.dart';
import '../../recurring/presentation/recurring_providers.dart';
import '../data/backup_repository.dart';
import '../domain/backup_codec.dart';

final backupRepositoryProvider = Provider<BackupRepository?>((ref) => null);

class BackupPanel extends ConsumerStatefulWidget {
  const BackupPanel({super.key, this.restoreOnly = false});
  final bool restoreOnly;
  @override
  ConsumerState<BackupPanel> createState() => _BackupPanelState();
}

class _BackupPanelState extends ConsumerState<BackupPanel> {
  final password = TextEditingController(),
      confirm = TextEditingController(),
      restorePassword = TextEditingController();
  bool encrypted = false, busy = false;
  String? message;
  @override
  void dispose() {
    password.dispose();
    confirm.dispose();
    restorePassword.dispose();
    super.dispose();
  }

  Future<bool> saveFile(Uint8List bytes, String filename) async {
    if (kIsWeb) {
      await ExportDownload.save(bytes, filename, 'application/octet-stream');
      return true;
    }
    final dialog = ref.read(externalFileDialogProvider.notifier);
    dialog.set(true);
    try {
      return await FilePicker.saveFile(
            fileName: filename,
            bytes: bytes,
            mimeType: 'application/octet-stream',
          ) !=
          null;
    } finally {
      dialog.set(false);
    }
  }

  Future<void> download() async {
    final s = SecurityCopy.of(context),
        repo = ref.read(backupRepositoryProvider);
    if (repo == null) return;
    if (encrypted &&
        (password.text.length < 10 ||
            password.text.length > 4096 ||
            password.text != confirm.text)) {
      setState(() => message = s('passwordError'));
      return;
    }
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final bytes = await repo.create(
        password: encrypted ? password.text : null,
      );
      if (!mounted) return;
      final saved = await saveFile(
        bytes,
        'Kim-backup-${DateTime.now().millisecondsSinceEpoch}.kim',
      );
      if (!saved) return;
      if (mounted) {
        password.clear();
        confirm.clear();
        setState(() => message = s('success'));
      }
    } catch (_) {
      if (mounted) setState(() => message = s('error'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> inspect({bool recovery = false}) async {
    final repo = ref.read(backupRepositoryProvider),
        s = SecurityCopy.of(context);
    if (repo == null) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      ValidatedBackup? checked;
      if (recovery) {
        checked = await repo.previous();
      } else {
        final dialog = ref.read(externalFileDialogProvider.notifier);
        dialog.set(true);
        final PlatformFile? file;
        try {
          file = await FilePicker.pickFile(type: FileType.any);
        } finally {
          dialog.set(false);
        }
        if (file == null || !mounted) return;
        final builder = BytesBuilder(copy: false);
        await for (final chunk in file.readAsByteStream()) {
          if (builder.length + chunk.length > BackupCodec.maxFileBytes) {
            throw const FormatException('File too large');
          }
          builder.add(chunk);
        }
        final data = builder.takeBytes();
        if (!mounted) return;
        checked = await repo.inspect(
          data,
          password: restorePassword.text.isEmpty ? null : restorePassword.text,
        );
        if (!mounted) return;
        restorePassword.clear();
      }
      if (checked == null || !mounted) {
        if (mounted) setState(() => message = s('failed'));
        return;
      }
      final preview = await repo.preview(checked);
      if (!mounted) return;
      var accepted = false, saveCurrent = !widget.restoreOnly;
      final approved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, update) => AlertDialog(
            title: Text(s('preview')),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${s('created')}: ${checked!.createdAt.toLocal().toIso8601String()}',
                    ),
                    Text(
                      '${s('schema')}: ${checked.sourceVersion} · ${checked.records} ${s('records')}',
                    ),
                    const SizedBox(height: 16),
                    Text(s('restoreWarning')),
                    if (checked.hasPin)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(s('restoredPin')),
                      ),
                    const SizedBox(height: 12),
                    if (!widget.restoreOnly)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(s('saveCurrent')),
                        value: saveCurrent,
                        onChanged: (v) => update(() => saveCurrent = v ?? true),
                      ),
                    CheckboxListTile(
                      key: const ValueKey('restore-confirm-check'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(s('confirmRestore')),
                      value: accepted,
                      onChanged: (v) => update(() => accepted = v ?? false),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(s('cancel')),
              ),
              FilledButton(
                key: const ValueKey('restore-confirm'),
                onPressed: accepted ? () => Navigator.pop(ctx, true) : null,
                child: Text(s('restore')),
              ),
            ],
          ),
        ),
      );
      if (approved != true || !mounted) return;
      final operation = WalletOperation.generate();
      ref.read(restoreCommittedProvider.notifier).set(false);
      ref.read(workspaceMaintenanceProvider.notifier).set(true);
      try {
        // Finish a batch already in flight before replacing its data. Any writes
        // it made invalidate the reviewed snapshot and require a fresh review.
        if (ref.exists(processingProvider) &&
            ref.read(processingProvider).isLoading) {
          try {
            await ref.read(processingProvider.future);
          } catch (_) {
            /* Validation below still compares the full workspace. */
          }
          if (!mounted) return;
        }
        if (saveCurrent) {
          final current = await repo.create();
          if (!await saveFile(
            current,
            'Kim-before-restore-${operation.at.millisecondsSinceEpoch}.kim',
          )) {
            return;
          }
        }
        // Disable old device alarms before replacing notification metadata.
        if (ref.exists(reminderAdapterProvider)) {
          await ref.read(reminderAdapterProvider).disable();
        }
        await repo.restore(preview, operation.id.value);
        if (!mounted) return;
        ref.read(restoreCommittedProvider.notifier).set(true);
        await ref.read(reloadWorkspaceProvider)();
        if (mounted) setState(() => message = s('restored'));
      } finally {
        if (mounted && !ref.read(restoreCommittedProvider)) {
          ref.read(workspaceMaintenanceProvider.notifier).set(false);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => message = s(
            ref.read(restoreCommittedProvider) ? 'restoredReload' : 'failed',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = SecurityCopy.of(context),
        available = ref.watch(backupRepositoryProvider) != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.restoreOnly) Text(s('backupBody')),
        const SizedBox(height: 16),
        if (!widget.restoreOnly) ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s('encrypted')),
            value: encrypted,
            onChanged: busy ? null : (v) => setState(() => encrypted = v),
          ),
          if (encrypted) ...[
            Semantics(
              container: true,
              child: TextField(
                key: const ValueKey('backup-password'),
                controller: password,
                obscureText: true,
                enabled: !busy,
                decoration: InputDecoration(labelText: s('password')),
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              container: true,
              child: TextField(
                key: const ValueKey('backup-password-confirm'),
                controller: confirm,
                obscureText: true,
                enabled: !busy,
                decoration: InputDecoration(labelText: s('confirmPassword')),
              ),
            ),
            const SizedBox(height: 16),
          ],
          FilledButton.icon(
            key: const ValueKey('backup-download'),
            onPressed: busy || !available ? null : download,
            icon: const Icon(Icons.download_outlined),
            label: Text(s('create')),
          ),
          const SizedBox(height: 16),
          Text(s('plain')),
          const Divider(height: 32),
        ],
        Semantics(
          container: true,
          child: TextField(
            key: const ValueKey('restore-password'),
            controller: restorePassword,
            obscureText: true,
            enabled: !busy,
            decoration: InputDecoration(labelText: s('passwordRestore')),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('backup-inspect'),
              onPressed: busy || !available ? null : inspect,
              icon: const Icon(Icons.upload_file_outlined),
              label: Text(s('inspect')),
            ),
            if (!widget.restoreOnly)
              TextButton(
                onPressed: busy || !available
                    ? null
                    : () => inspect(recovery: true),
                child: Text(s('recovery')),
              ),
          ],
        ),
        if (!widget.restoreOnly)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              s('recoveryHint'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (busy)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(s('busy'))),
              ],
            ),
          ),
        if (message != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(message!, key: const ValueKey('backup-message')),
          ),
      ],
    );
  }
}
