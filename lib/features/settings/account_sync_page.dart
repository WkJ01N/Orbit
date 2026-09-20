import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/features/settings/avatar_crop_dialog.dart';
import 'package:orbit/models/account_sync.dart';
import 'package:orbit/models/auto_sync_settings.dart';
import 'package:orbit/providers/account_sync_providers.dart';
import 'package:orbit/services/account_sync_service.dart';

class AccountSyncPage extends ConsumerStatefulWidget {
  const AccountSyncPage({super.key});

  @override
  ConsumerState<AccountSyncPage> createState() => _AccountSyncPageState();
}

class _AccountSyncPageState extends ConsumerState<AccountSyncPage> {
  String? _refreshedUid;

  @override
  Widget build(BuildContext context) {
    final text = _SyncText.of(context);
    final state = ref.watch(accountSyncProvider);
    final account = state.value?.account;
    if (account == null) _refreshedUid = null;
    if (account != null && _refreshedUid != account.uid) {
      _refreshedUid = account.uid;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(ref.read(accountSyncProvider.notifier).refreshProfile());
        }
      });
    }
    return Scaffold(
      appBar: AppBar(title: Text(text.title)),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorView(
          message: _friendlyError(text, error),
          onRetry: () => ref.invalidate(accountSyncProvider),
        ),
        data: (status) => status.signedIn
            ? _SignedInBody(status: status)
            : _SignedOutBody(
                configured: ref.read(accountSyncProvider.notifier).configured,
              ),
      ),
    );
  }
}

class _SignedOutBody extends ConsumerWidget {
  const _SignedOutBody({required this.configured});

  final bool configured;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = _SyncText.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Icon(
          configured ? Icons.cloud_sync_outlined : Icons.cloud_off_outlined,
          size: 64,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 20),
        Text(
          configured ? text.optionalIntro : text.notAvailable,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Text(
          text.offlineWorks,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 32),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(
                  onPressed: configured
                      ? () => _showAuth(context, ref, register: false)
                      : null,
                  child: _buttonText(text.signIn),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: configured
                      ? () => _showAuth(context, ref, register: true)
                      : null,
                  child: _buttonText(text.register),
                ),
                TextButton(
                  onPressed: configured ? () => _showReset(context, ref) : null,
                  child: _buttonText(text.forgotPassword),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SignedInBody extends ConsumerWidget {
  const _SignedInBody({required this.status});

  final SyncStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = _SyncText.of(context);
    final syncing = status.phase == SyncPhase.syncing;
    return ListView(
      children: [
        ListTile(
          leading: _AccountAvatar(account: status.account!, radius: 24),
          title: Text(status.account!.username ?? status.account!.email),
          subtitle: Text(
            status.account!.username == null
                ? text.accountReady
                : status.account!.email,
          ),
          trailing: const Icon(Icons.edit_outlined),
          onTap: () async {
            await ref.read(accountSyncProvider.notifier).refreshProfile();
            if (!context.mounted) return;
            final account = ref.read(accountSyncProvider).value?.account;
            if (account != null) await _showProfileEditor(context, account);
          },
        ),
        const Divider(),
        ListTile(
          leading: syncing
              ? const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(_statusIcon(status.phase)),
          title: Text(_statusLabel(text, status)),
          subtitle: Text(
            status.lastSyncedAt == null
                ? text.neverSynced
                : text.lastSync(status.lastSyncedAt!),
          ),
          trailing: IconButton(
            tooltip: text.syncNow,
            onPressed: syncing
                ? null
                : () => ref.read(accountSyncProvider.notifier).syncNow(),
            icon: const Icon(Icons.refresh),
          ),
        ),
        if (status.pendingCount > 0)
          ListTile(
            leading: const Icon(Icons.upload_outlined),
            title: Text(text.pending(status.pendingCount)),
          ),
        if (status.conflictCount > 0)
          ListTile(
            leading: Icon(
              Icons.warning_amber_rounded,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(text.conflicts(status.conflictCount)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const SyncConflictsPage(),
              ),
            ),
          ),
        if (status.phase == SyncPhase.needsInitialMerge)
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: () => _resumeInitialMerge(context, ref),
              icon: const Icon(Icons.merge_outlined),
              label: Text(text.reviewMerge),
            ),
          ),
        const Divider(),
        const _AutoSyncSection(),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout),
          title: Text(text.signOut),
          subtitle: Text(text.signOutKeepsData),
          onTap: () => _confirmSignOut(context, ref),
        ),
        ListTile(
          leading: Icon(
            Icons.person_remove_outlined,
            color: Theme.of(context).colorScheme.error,
          ),
          title: Text(text.deleteAccount),
          subtitle: Text(text.deleteAccountHint),
          onTap: () => _confirmDeleteAccount(context, ref),
        ),
      ],
    );
  }
}

class _AutoSyncSection extends ConsumerWidget {
  const _AutoSyncSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = _SyncText.of(context);
    final settings = ref.watch(autoSyncSettingsProvider);
    return settings.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => ListTile(
        leading: const Icon(Icons.sync_problem_outlined),
        title: Text(text.autoSyncSettingsFailed),
        trailing: IconButton(
          tooltip: text.retry,
          onPressed: () => ref.invalidate(autoSyncSettingsProvider),
          icon: const Icon(Icons.refresh),
        ),
      ),
      data: (value) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              text.autoSync,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          SwitchListTile(
            title: Text(text.autoSync),
            subtitle: Text(text.autoSyncHint),
            value: value.enabled,
            onChanged: (enabled) =>
                _save(ref, value.copyWith(enabled: enabled)),
          ),
          SwitchListTile(
            title: Text(text.syncOnStartup),
            value: value.onStartup,
            onChanged: value.enabled
                ? (enabled) => _save(ref, value.copyWith(onStartup: enabled))
                : null,
          ),
          SwitchListTile(
            title: Text(text.syncOnResume),
            value: value.onAppResume,
            onChanged: value.enabled
                ? (enabled) => _save(ref, value.copyWith(onAppResume: enabled))
                : null,
          ),
          SwitchListTile(
            title: Text(text.syncOnLocalChange),
            value: value.onLocalChange,
            onChanged: value.enabled
                ? (enabled) =>
                      _save(ref, value.copyWith(onLocalChange: enabled))
                : null,
          ),
          SwitchListTile(
            title: Text(text.syncOnNetworkRestored),
            value: value.onNetworkRestored,
            onChanged: value.enabled
                ? (enabled) =>
                      _save(ref, value.copyWith(onNetworkRestored: enabled))
                : null,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: DropdownButtonFormField<SyncNetworkPolicy>(
              initialValue: value.networkPolicy,
              decoration: InputDecoration(labelText: text.syncNetwork),
              items: [
                DropdownMenuItem(
                  value: SyncNetworkPolicy.any,
                  child: Text(text.syncNetworkAny),
                ),
                DropdownMenuItem(
                  value: SyncNetworkPolicy.unmetered,
                  child: Text(text.syncNetworkUnmetered),
                ),
              ],
              onChanged: value.enabled
                  ? (policy) {
                      if (policy != null) {
                        _save(ref, value.copyWith(networkPolicy: policy));
                      }
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  void _save(WidgetRef ref, AutoSyncSettings value) {
    unawaited(ref.read(autoSyncSettingsProvider.notifier).save(value));
  }
}

class SyncConflictsPage extends ConsumerStatefulWidget {
  const SyncConflictsPage({super.key});

  @override
  ConsumerState<SyncConflictsPage> createState() => _SyncConflictsPageState();
}

class _SyncConflictsPageState extends ConsumerState<SyncConflictsPage> {
  late Future<List<SyncConflict>> _conflicts;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _conflicts = ref.read(accountSyncProvider.notifier).conflicts();
  }

  @override
  Widget build(BuildContext context) {
    final text = _SyncText.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(text.conflictTitle)),
      body: FutureBuilder<List<SyncConflict>>(
        future: _conflicts,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final conflicts = snapshot.data!;
          if (conflicts.isEmpty) {
            return Center(child: Text(text.noConflicts));
          }
          return ListView.builder(
            itemCount: conflicts.length,
            itemBuilder: (context, index) {
              final conflict = conflicts[index];
              return Card(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _entityTitle(conflict.local.entity),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(text.conflictHint),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: () => _resolve(conflict, true),
                            child: Text(text.useLocal),
                          ),
                          FilledButton(
                            onPressed: () => _resolve(conflict, false),
                            child: Text(text.useCloud),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _resolve(SyncConflict conflict, bool useLocal) async {
    await ref
        .read(accountSyncProvider.notifier)
        .resolveConflict(conflict, useLocal);
    if (!mounted) return;
    setState(_reload);
  }
}

class _AccountAvatar extends ConsumerStatefulWidget {
  const _AccountAvatar({required this.account, required this.radius});

  final SyncAccount account;
  final double radius;

  @override
  ConsumerState<_AccountAvatar> createState() => _AccountAvatarState();
}

class _AccountAvatarState extends ConsumerState<_AccountAvatar> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant _AccountAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.account.uid != widget.account.uid) _bytes = null;
    if (oldWidget.account.uid != widget.account.uid ||
        oldWidget.account.avatarFileId != widget.account.avatarFileId) {
      unawaited(_load());
    } else if (!identical(oldWidget.account, widget.account)) {
      // A profile refresh with the same remote id retries a previously failed
      // download without making stable avatars hit the network again.
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final account = widget.account;
    if (account.avatarFileId == null) {
      if (mounted) setState(() => _bytes = null);
      try {
        await ref.read(accountAvatarCacheProvider).clearUser(account.uid);
      } catch (_) {
        // A missing or unavailable cache must never break profile rendering.
      }
      return;
    }
    final bytes = await ref
        .read(accountAvatarCacheProvider)
        .load(
          uid: account.uid,
          fileId: account.avatarFileId,
          resolveUrl: ref.read(accountServiceProvider).avatarDownloadUrl,
        );
    if (!mounted ||
        account.uid != widget.account.uid ||
        account.avatarFileId != widget.account.avatarFileId) {
      return;
    }
    setState(() => _bytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final diameter = widget.radius * 2;
    final fallback = CircleAvatar(
      radius: widget.radius,
      child: const Icon(Icons.person_outline),
    );
    final bytes = _bytes;
    if (bytes == null) return fallback;
    return ClipOval(
      child: Image.memory(
        bytes,
        width: diameter,
        height: diameter,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

Future<void> _showProfileEditor(BuildContext context, SyncAccount account) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ProfileEditorDialog(account: account),
    );

class _ProfileEditorDialog extends ConsumerStatefulWidget {
  const _ProfileEditorDialog({required this.account});

  final SyncAccount account;

  @override
  ConsumerState<_ProfileEditorDialog> createState() =>
      _ProfileEditorDialogState();
}

class _ProfileEditorDialogState extends ConsumerState<_ProfileEditorDialog> {
  late final TextEditingController _username;
  Uint8List? _avatarBytes;
  String? _extension;
  String? _contentType;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _username = TextEditingController(text: widget.account.username ?? '');
  }

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes =
        file.bytes ??
        (file.path == null ? null : await File(file.path!).readAsBytes());
    if (!mounted || bytes == null) return;
    if (bytes.length > 2 * 1024 * 1024) {
      setState(() => _error = _SyncText.of(context).avatarTooLarge);
      return;
    }
    final extension = (file.extension ?? '').toLowerCase();
    final contentType = switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'jpg' || 'jpeg' => 'image/jpeg',
      _ => null,
    };
    if (contentType == null) {
      setState(() => _error = _SyncText.of(context).avatarTypeInvalid);
      return;
    }
    final cropped = await showAvatarCropDialog(context, bytes);
    if (!mounted || cropped == null) return;
    setState(() {
      _avatarBytes = cropped;
      _extension = 'png';
      _contentType = 'image/png';
      _error = null;
    });
  }

  Future<void> _save() async {
    final text = _SyncText.of(context);
    if (!isValidOrbitUsername(_username.text)) {
      setState(() => _error = text.invalidUsername);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final avatar = _avatarBytes == null
          ? null
          : AccountAvatarUpload(
              bytes: _avatarBytes!,
              extension: _extension!,
              contentType: _contentType!,
            );
      await ref
          .read(accountSyncProvider.notifier)
          .updateProfile(username: _username.text, avatar: avatar);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _friendlyError(text, error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = _SyncText.of(context);
    final preview = _avatarBytes == null
        ? _AccountAvatar(account: widget.account, radius: 42)
        : CircleAvatar(radius: 42, backgroundImage: MemoryImage(_avatarBytes!));
    return AlertDialog(
      title: Text(text.editProfile),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              preview,
              TextButton.icon(
                onPressed: _busy ? null : _pickAvatar,
                icon: const Icon(Icons.photo_camera_outlined),
                label: _buttonText(text.chooseAvatar),
              ),
              Text(
                text.avatarHint,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _username,
                enabled: !_busy,
                maxLength: 24,
                decoration: InputDecoration(
                  labelText: text.usernameOptional,
                  helperText: text.usernameHint,
                  helperMaxLines: 2,
                ),
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actionsOverflowButtonSpacing: 8,
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: _buttonText(text.cancel),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : _buttonText(text.save),
        ),
      ],
    );
  }
}

Future<void> _showAuth(
  BuildContext context,
  WidgetRef ref, {
  required bool register,
}) async {
  final text = _SyncText.of(context);
  final email = TextEditingController();
  final username = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  var obscure = true;
  var busy = false;
  String? error;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(register ? text.register : text.signIn),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: email,
                  enabled: !busy,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(labelText: text.email),
                ),
                if (register)
                  TextField(
                    controller: username,
                    enabled: !busy,
                    maxLength: 24,
                    decoration: InputDecoration(
                      labelText: text.usernameOptional,
                      helperText: text.usernameHint,
                      helperMaxLines: 2,
                    ),
                  ),
                TextField(
                  controller: password,
                  enabled: !busy,
                  obscureText: obscure,
                  maxLength: 20,
                  inputFormatters: [LengthLimitingTextInputFormatter(20)],
                  autofillHints: register
                      ? const [AutofillHints.newPassword]
                      : const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: text.password,
                    helperText: register ? text.passwordRule : null,
                    helperMaxLines: 2,
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => obscure = !obscure),
                      icon: Icon(
                        obscure ? Icons.visibility : Icons.visibility_off,
                      ),
                    ),
                  ),
                ),
                if (register)
                  TextField(
                    controller: confirm,
                    enabled: !busy,
                    obscureText: true,
                    maxLength: 20,
                    inputFormatters: [LengthLimitingTextInputFormatter(20)],
                    decoration: InputDecoration(
                      labelText: text.confirmPassword,
                    ),
                  ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(dialogContext),
            child: _buttonText(text.cancel),
          ),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    if (!email.text.contains('@') ||
                        !isValidOrbitPassword(password.text)) {
                      setState(() => error = text.invalidCredentials);
                      return;
                    }
                    if (register && !isValidOrbitUsername(username.text)) {
                      setState(() => error = text.invalidUsername);
                      return;
                    }
                    if (register && password.text != confirm.text) {
                      setState(() => error = text.passwordMismatch);
                      return;
                    }
                    setState(() {
                      busy = true;
                      error = null;
                    });
                    try {
                      InitialSyncPreview preview;
                      if (register) {
                        final challenge = await ref
                            .read(accountSyncProvider.notifier)
                            .signUp(
                              email.text,
                              password.text,
                              username: username.text,
                            );
                        if (!dialogContext.mounted) return;
                        var code = '';
                        if (challenge.requiresCode) {
                          final entered = await _askCode(
                            dialogContext,
                            challenge,
                          );
                          if (entered == null) {
                            setState(() => busy = false);
                            return;
                          }
                          code = entered;
                        }
                        preview = await ref
                            .read(accountSyncProvider.notifier)
                            .finishVerification(challenge, code);
                      } else {
                        preview = await ref
                            .read(accountSyncProvider.notifier)
                            .signIn(email.text, password.text);
                      }
                      if (!dialogContext.mounted) return;
                      Navigator.pop(dialogContext);
                      await _showMergePreview(context, ref, preview);
                    } catch (value) {
                      setState(() {
                        busy = false;
                        error = _friendlyError(text, value);
                      });
                    }
                  },
            child: _buttonText(register ? text.register : text.signIn),
          ),
        ],
      ),
    ),
  );
}

Future<String?> _askCode(
  BuildContext context,
  VerificationChallenge challenge,
) => showDialog<String>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _VerificationCodeDialog(challenge: challenge),
);

class _VerificationCodeDialog extends StatefulWidget {
  const _VerificationCodeDialog({required this.challenge});

  final VerificationChallenge challenge;

  @override
  State<_VerificationCodeDialog> createState() =>
      _VerificationCodeDialogState();
}

class _VerificationCodeDialogState extends State<_VerificationCodeDialog> {
  final _controller = TextEditingController();
  Timer? _timer;
  int _seconds = 60;
  bool _resending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_refresh);
    _startCooldown();
  }

  void _refresh() => setState(() {});

  void _startCooldown() {
    _timer?.cancel();
    setStateIfMounted(() => _seconds = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_seconds <= 1) {
        timer.cancel();
        setState(() => _seconds = 0);
      } else {
        setState(() => _seconds--);
      }
    });
  }

  void setStateIfMounted(VoidCallback update) {
    if (mounted) setState(update);
  }

  Future<void> _resend() async {
    if (_seconds > 0 || _resending) return;
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      await widget.challenge.resend();
      if (mounted) _startCooldown();
    } catch (error) {
      if (mounted) {
        setState(() => _error = _friendlyError(_SyncText.of(context), error));
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _SyncText.of(context);
    return AlertDialog(
      title: Text(text.verificationCode),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(8),
            ],
            decoration: InputDecoration(hintText: text.codeHint),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: _seconds == 0 && !_resending ? _resend : null,
              child: _buttonText(
                _resending
                    ? text.sendingCode
                    : _seconds > 0
                    ? text.resendIn(_seconds)
                    : text.resendCode,
              ),
            ),
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
      actionsOverflowButtonSpacing: 8,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: _buttonText(text.cancel),
        ),
        FilledButton(
          onPressed: _controller.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, _controller.text.trim()),
          child: _buttonText(text.confirm),
        ),
      ],
    );
  }
}

Future<void> _showMergePreview(
  BuildContext context,
  WidgetRef ref,
  InitialSyncPreview preview,
) async {
  final text = _SyncText.of(context);
  final choices = <String, bool>{};
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final complete = preview.conflicts.every(
          (conflict) => choices.containsKey(conflict.id),
        );
        return AlertDialog(
          title: Text(text.mergeTitle),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    text.mergeCounts(
                      preview.localOnly.length,
                      preview.remoteOnly.length,
                      preview.identical.length,
                      preview.conflicts.length,
                    ),
                  ),
                  for (final conflict in preview.conflicts) ...[
                    const Divider(),
                    Text(_entityTitle(conflict.local.entity)),
                    RadioGroup<bool>(
                      groupValue: choices[conflict.id],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => choices[conflict.id] = value);
                        }
                      },
                      child: Column(
                        children: [
                          RadioListTile<bool>(
                            value: true,
                            title: Text(text.useLocal),
                          ),
                          RadioListTile<bool>(
                            value: false,
                            title: Text(text.useCloud),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: _buttonText(text.cancel),
            ),
            FilledButton(
              onPressed: complete ? () => Navigator.pop(context, true) : null,
              child: _buttonText(text.startSync),
            ),
          ],
        );
      },
    ),
  );
  if (confirmed == true) {
    await ref
        .read(accountSyncProvider.notifier)
        .confirmInitialMerge(preview, choices);
  }
}

Future<void> _resumeInitialMerge(BuildContext context, WidgetRef ref) async {
  try {
    final preview = await ref
        .read(accountSyncProvider.notifier)
        .previewInitialMerge();
    if (context.mounted) await _showMergePreview(context, ref, preview);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(_SyncText.of(context), error))),
      );
    }
  }
}

Future<void> _showReset(BuildContext context, WidgetRef ref) async {
  final text = _SyncText.of(context);
  final email = TextEditingController();
  final submitted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text(text.forgotPassword),
      content: TextField(
        controller: email,
        keyboardType: TextInputType.emailAddress,
        decoration: InputDecoration(labelText: text.email),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: _buttonText(text.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: _buttonText(text.sendCode),
        ),
      ],
    ),
  );
  if (submitted != true || !context.mounted) return;
  try {
    final challenge = await ref
        .read(accountSyncProvider.notifier)
        .beginPasswordReset(email.text);
    if (!context.mounted) return;
    final values = await _askResetValues(context, challenge);
    if (values == null) return;
    await challenge.complete(values.$1, values.$2);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(text.passwordResetDone)));
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(text, error))));
    }
  }
}

Future<(String, String)?> _askResetValues(
  BuildContext context,
  PasswordResetChallenge challenge,
) => showDialog<(String, String)>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _PasswordResetDialog(challenge: challenge),
);

class _PasswordResetDialog extends StatefulWidget {
  const _PasswordResetDialog({required this.challenge});

  final PasswordResetChallenge challenge;

  @override
  State<_PasswordResetDialog> createState() => _PasswordResetDialogState();
}

class _PasswordResetDialogState extends State<_PasswordResetDialog> {
  final _code = TextEditingController();
  final _password = TextEditingController();
  Timer? _timer;
  int _seconds = 60;
  bool _resending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _code.addListener(_refresh);
    _password.addListener(_refresh);
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  void _refresh() => setState(() {});

  void _tick(Timer timer) {
    if (!mounted) return;
    if (_seconds <= 1) {
      timer.cancel();
      setState(() => _seconds = 0);
    } else {
      setState(() => _seconds--);
    }
  }

  void _restartCooldown() {
    _timer?.cancel();
    setState(() => _seconds = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      await widget.challenge.resend();
      if (mounted) _restartCooldown();
    } catch (error) {
      if (mounted) {
        setState(() => _error = _friendlyError(_SyncText.of(context), error));
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code
      ..removeListener(_refresh)
      ..dispose();
    _password
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _SyncText.of(context);
    final valid =
        _code.text.trim().isNotEmpty && isValidOrbitPassword(_password.text);
    return AlertDialog(
      title: Text(text.resetPassword),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(8),
              ],
              decoration: InputDecoration(labelText: text.verificationCode),
            ),
            TextField(
              controller: _password,
              obscureText: true,
              maxLength: 20,
              inputFormatters: [LengthLimitingTextInputFormatter(20)],
              decoration: InputDecoration(
                labelText: text.newPassword,
                helperText: text.passwordRule,
                helperMaxLines: 2,
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: _seconds == 0 && !_resending ? _resend : null,
                child: _buttonText(
                  _resending
                      ? text.sendingCode
                      : _seconds > 0
                      ? text.resendIn(_seconds)
                      : text.resendCode,
                ),
              ),
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actionsOverflowButtonSpacing: 8,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: _buttonText(text.cancel),
        ),
        FilledButton(
          onPressed: valid
              ? () =>
                    Navigator.pop(context, (_code.text.trim(), _password.text))
              : null,
          child: _buttonText(text.confirm),
        ),
      ],
    );
  }
}

Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
  final text = _SyncText.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text(text.signOut),
      content: Text(text.signOutKeepsData),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: _buttonText(text.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: _buttonText(text.signOut),
        ),
      ],
    ),
  );
  if (confirmed == true) await ref.read(accountSyncProvider.notifier).signOut();
}

Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
  final text = _SyncText.of(context);
  final password = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text(text.deleteAccount),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text.deleteAccountConfirm),
          TextField(
            controller: password,
            obscureText: true,
            decoration: InputDecoration(labelText: text.password),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: _buttonText(text.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: _buttonText(text.deleteAccount),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    await ref.read(accountSyncProvider.notifier).deleteAccount(password.text);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(text, error))));
    }
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onRetry,
            child: Text(_SyncText.of(context).retry),
          ),
        ],
      ),
    ),
  );
}

IconData _statusIcon(SyncPhase phase) => switch (phase) {
  SyncPhase.error || SyncPhase.offline => Icons.cloud_off_outlined,
  SyncPhase.needsInitialMerge => Icons.merge_outlined,
  _ => Icons.cloud_done_outlined,
};

String _statusLabel(_SyncText text, SyncStatus status) =>
    switch (status.phase) {
      SyncPhase.syncing => text.syncing,
      SyncPhase.error => text.syncFailed,
      SyncPhase.offline => text.waitingNetwork,
      SyncPhase.needsInitialMerge => text.waitingMerge,
      _ => text.synced,
    };

String _entityTitle(SyncEntity entity) =>
    entity.payload['courseName'] as String? ??
    entity.payload['name'] as String? ??
    entity.id;

String _friendlyError(_SyncText text, Object error) {
  final value = '$error';
  if (value.contains('cloud_not_configured')) return text.notAvailable;
  if (value.contains('invalid_password_format')) return text.passwordRule;
  if (value.contains('invalid_username')) return text.invalidUsername;
  if (value.contains('avatar_too_large')) return text.avatarTooLarge;
  if (value.contains('avatar_type_invalid')) return text.avatarTypeInvalid;
  if (value.contains('avatar_upload_failed')) return text.avatarUploadFailed;
  if (value.contains('invalid_credentials') || value.contains('password')) {
    return text.authFailed;
  }
  if (value.contains('network') ||
      value.contains('unreachable') ||
      value.contains('SocketException')) {
    return text.networkFailed;
  }
  return '${text.operationFailed}: $value';
}

Widget _buttonText(String value) =>
    Text(value, maxLines: 2, softWrap: true, textAlign: TextAlign.center);

class _SyncText {
  const _SyncText(this.zh, this.hant);

  final bool zh;
  final bool hant;

  factory _SyncText.of(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final zh = locale.languageCode == 'zh';
    final script = locale.scriptCode?.toLowerCase();
    return _SyncText(zh, script == 'hant' || locale.countryCode == 'TW');
  }

  String pick(String en, String hans, String traditional) =>
      zh ? (hant ? traditional : hans) : en;
  String get title => pick('Account & sync', '账号与同步', '帳號與同步');
  String get optionalIntro => pick(
    'Sign in to sync schedules across your devices.',
    '登录后可在不同设备间同步课表。',
    '登入後可在不同裝置間同步課表。',
  );
  String get notAvailable => pick(
    'Cloud sync is not available in this build yet.',
    '此版本暂未开放云同步。',
    '此版本暫未開放雲端同步。',
  );
  String get offlineWorks => pick(
    'Orbit remains fully usable offline without an account.',
    '不登录也可继续离线使用 Orbit 的全部课表和提醒功能。',
    '不登入也可繼續離線使用 Orbit 的全部課表和提醒功能。',
  );
  String get signIn => pick('Sign in', '登录', '登入');
  String get register => pick('Create account', '注册账号', '註冊帳號');
  String get forgotPassword => pick('Forgot password', '忘记密码', '忘記密碼');
  String get email => pick('Email', '邮箱', '電子郵件');
  String get password => pick('Password', '密码', '密碼');
  String get newPassword => pick('New password', '新密码', '新密碼');
  String get confirmPassword => pick('Confirm password', '确认密码', '確認密碼');
  String get usernameOptional =>
      pick('Display name (optional)', '用户名（可选）', '使用者名稱（選填）');
  String get usernameHint => pick(
    '1–24 characters; you can change it later.',
    '1–24 个字符，可稍后修改。',
    '1–24 個字元，可稍後修改。',
  );
  String get invalidUsername => pick(
    'Display name must be 1–24 characters.',
    '用户名必须为 1–24 个字符。',
    '使用者名稱必須為 1–24 個字元。',
  );
  String get passwordRule => pick(
    '8–20 characters with at least one letter and one number.',
    '密码须为 8–20 位，且必须包含字母和数字。',
    '密碼須為 8–20 位，且必須包含字母和數字。',
  );
  String get invalidCredentials => pick(
    'Enter a valid email and an 8–20 character password containing letters and numbers.',
    '请输入有效邮箱；密码须为 8–20 位并包含字母和数字。',
    '請輸入有效電子郵件；密碼須為 8–20 位並包含字母和數字。',
  );
  String get passwordMismatch =>
      pick('Passwords do not match.', '两次密码不一致。', '兩次密碼不一致。');
  String get verificationCode => pick('Verification code', '邮箱验证码', '電子郵件驗證碼');
  String get codeHint =>
      pick('Enter the code sent to your email', '输入邮箱中收到的验证码', '輸入電子郵件中收到的驗證碼');
  String get sendingCode => pick('Sending…', '正在发送…', '正在傳送…');
  String resendIn(int seconds) =>
      pick('Resend in ${seconds}s', '$seconds 秒后可重新发送', '$seconds 秒後可重新傳送');
  String get resendCode => pick('Resend code', '重新发送验证码', '重新傳送驗證碼');
  String get confirm => pick('Confirm', '确认', '確認');
  String get cancel => pick('Cancel', '取消', '取消');
  String get retry => pick('Retry', '重试', '重試');
  String get accountReady =>
      pick('Schedule sync enabled', '课表同步已启用', '課表同步已啟用');
  String get editProfile => pick('Edit profile', '编辑个人资料', '編輯個人資料');
  String get chooseAvatar => pick('Choose avatar', '选择头像', '選擇頭像');
  String get avatarHint => pick(
    'JPG, PNG or WebP, up to 2 MB.',
    '支持 JPG、PNG 或 WebP，最大 2 MB。',
    '支援 JPG、PNG 或 WebP，最大 2 MB。',
  );
  String get avatarTooLarge => pick(
    'The image must be no larger than 2 MB.',
    '头像不能超过 2 MB。',
    '頭像不能超過 2 MB。',
  );
  String get avatarTypeInvalid => pick(
    'Choose a JPG, PNG or WebP image.',
    '请选择 JPG、PNG 或 WebP 图片。',
    '請選擇 JPG、PNG 或 WebP 圖片。',
  );
  String get avatarUploadFailed =>
      pick('Avatar upload failed. Try again.', '头像上传失败，请重试。', '頭像上傳失敗，請重試。');
  String get save => pick('Save', '保存', '儲存');
  String get syncNow => pick('Sync now', '立即同步', '立即同步');
  String get autoSync => pick('Automatic sync', '自动同步', '自動同步');
  String get autoSyncHint => pick(
    'Sync when selected events occur. Manual sync remains available.',
    '在所选事件发生时同步，仍可随时手动同步。',
    '在所選事件發生時同步，仍可隨時手動同步。',
  );
  String get syncOnStartup =>
      pick('When Orbit starts', 'Orbit 启动时', 'Orbit 啟動時');
  String get syncOnResume => pick(
    'When Orbit returns to the foreground',
    'Orbit 回到前台时',
    'Orbit 回到前景時',
  );
  String get syncOnLocalChange =>
      pick('After local schedule changes', '本机课表变更后', '本機課表變更後');
  String get syncOnNetworkRestored =>
      pick('When an allowed network returns', '允许的网络恢复时', '允許的網路恢復時');
  String get syncNetwork => pick('Network', '网络条件', '網路條件');
  String get syncNetworkAny => pick('Any network', '任意网络', '任意網路');
  String get syncNetworkUnmetered =>
      pick('Wi-Fi or Ethernet only', '仅 Wi-Fi 或有线网络', '僅 Wi-Fi 或有線網路');
  String get autoSyncSettingsFailed => pick(
    'Could not load automatic sync settings.',
    '无法加载自动同步设置。',
    '無法載入自動同步設定。',
  );
  String get syncing => pick('Syncing…', '正在同步…', '正在同步…');
  String get synced => pick('Up to date', '已是最新', '已是最新');
  String get syncFailed => pick('Sync failed', '同步失败', '同步失敗');
  String get waitingNetwork =>
      pick('Waiting for network', '等待网络后重试', '等待網路後重試');
  String get waitingMerge =>
      pick('Initial merge required', '需要确认首次合并', '需要確認首次合併');
  String get neverSynced => pick('Not synced yet', '尚未完成同步', '尚未完成同步');
  String lastSync(DateTime value) =>
      pick('Last sync: $value', '上次同步：$value', '上次同步：$value');
  String pending(int count) => pick(
    '$count changes waiting to upload',
    '$count 项修改等待上传',
    '$count 項修改等待上傳',
  );
  String conflicts(int count) => pick(
    '$count conflicts need attention',
    '$count 项冲突需要处理',
    '$count 項衝突需要處理',
  );
  String get conflictTitle => pick('Sync conflicts', '同步冲突', '同步衝突');
  String get noConflicts =>
      pick('No unresolved conflicts', '没有未解决的冲突', '沒有未解決的衝突');
  String get conflictHint => pick(
    'This item changed on two devices. Choose the version to keep.',
    '此内容在两台设备上都被修改，请选择保留的版本。',
    '此內容在兩台裝置上都被修改，請選擇保留的版本。',
  );
  String get useLocal => pick('Use this device', '使用本机版本', '使用本機版本');
  String get useCloud => pick('Use cloud version', '使用云端版本', '使用雲端版本');
  String get reviewMerge => pick('Review initial merge', '查看首次合并', '查看首次合併');
  String get mergeTitle => pick('Review schedule merge', '确认课表合并', '確認課表合併');
  String mergeCounts(int local, int cloud, int same, int conflicts) => pick(
    '$local local only, $cloud cloud only, $same identical, $conflicts conflicts.',
    '本机独有 $local 项，云端独有 $cloud 项，相同 $same 项，冲突 $conflicts 项。',
    '本機獨有 $local 項，雲端獨有 $cloud 項，相同 $same 項，衝突 $conflicts 項。',
  );
  String get startSync => pick('Confirm and sync', '确认并同步', '確認並同步');
  String get signOut => pick('Sign out', '退出账号', '登出帳號');
  String get signOutKeepsData => pick(
    'Schedules and reminders stay on this device; cloud sync stops.',
    '本机课表和提醒会保留，云同步将停止。',
    '本機課表和提醒會保留，雲端同步將停止。',
  );
  String get deleteAccount => pick('Delete account', '注销账号', '刪除帳號');
  String get deleteAccountHint => pick(
    'Permanently removes cloud data; local schedules are kept.',
    '永久删除云端数据，本机课表默认保留。',
    '永久刪除雲端資料，本機課表預設保留。',
  );
  String get deleteAccountConfirm => pick(
    'Enter your password to permanently delete the account and all cloud schedule data.',
    '输入密码以永久注销账号并删除全部云端课表数据。',
    '輸入密碼以永久刪除帳號及全部雲端課表資料。',
  );
  String get sendCode => pick('Send code', '发送验证码', '傳送驗證碼');
  String get resetPassword => pick('Reset password', '重置密码', '重設密碼');
  String get passwordResetDone => pick(
    'Password reset. You can now sign in.',
    '密码已重置，现在可以登录。',
    '密碼已重設，現在可以登入。',
  );
  String get authFailed => pick(
    'Authentication failed. Check your email, password or code.',
    '验证失败，请检查邮箱、密码或验证码。',
    '驗證失敗，請檢查電子郵件、密碼或驗證碼。',
  );
  String get networkFailed => pick(
    'Network unavailable. Try again later.',
    '网络不可用，请稍后重试。',
    '網路無法使用，請稍後重試。',
  );
  String get operationFailed => pick('Operation failed', '操作失败', '操作失敗');
}
