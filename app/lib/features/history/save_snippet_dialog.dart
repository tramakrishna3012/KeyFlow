import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/auth_service.dart';
import '../../data/models/history_entry.dart';
import '../../data/providers.dart';
import '../auth/auth_modal.dart';
import '../look_monitor/look_window_sanitizer.dart';
import 'history_providers.dart';
import 'shared_snippets.dart';

class SaveSnippetDialog extends ConsumerStatefulWidget {
  const SaveSnippetDialog({super.key, this.sharedSnippet});

  final HistoryEntry? sharedSnippet;

  static Future<void> show(
    BuildContext context, {
    HistoryEntry? sharedSnippet,
  }) async {
    final message = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => SaveSnippetDialog(sharedSnippet: sharedSnippet),
    );
    if (message != null && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  ConsumerState<SaveSnippetDialog> createState() => _SaveSnippetDialogState();
}

class _SaveSnippetDialogState extends ConsumerState<SaveSnippetDialog> {
  late final _controller = TextEditingController(
    text: widget.sharedSnippet?.text,
  );
  late final _draftId = widget.sharedSnippet?.id ?? const Uuid().v4();
  HistoryEntry? _savedEntry;
  String? _syncOwnerId;
  bool _syncRequested = false;
  bool _requiresSignIn = false;
  bool _synced = false;
  bool _saving = false;
  String? _error;

  Future<void> _finishImport() async {
    final shared = widget.sharedSnippet;
    if (shared != null) await SharedSnippets.remove(shared.id);
  }

  Future<void> _discardImport() async {
    setState(() => _saving = true);
    try {
      await _finishImport();
      if (mounted) Navigator.of(context).pop('Shared text discarded');
    } on PlatformException {
      if (mounted) setState(() => _error = 'Could not discard. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save({required bool sync}) async {
    if (_saving) return;
    final text = _controller.text;
    if (text.trim().isEmpty) {
      setState(() => _error = 'Enter or paste text to save.');
      return;
    }
    if (const LookWindowSanitizer().containsSensitiveContent(text)) {
      setState(
        () => _error = 'Remove credentials or payment details before saving.',
      );
      return;
    }

    final auth = ref.read(authServiceProvider);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (sync) {
        _syncOwnerId ??= auth.currentUser?.id;
        if (_requiresSignIn ||
            !auth.isAuthenticated ||
            auth.currentUser == null) {
          final signedIn = await AuthModal.show(context);
          if (!mounted) return;
          if (signedIn != true) {
            setState(
              () => _error = 'Sign in to sync or choose Save for a local copy.',
            );
            return;
          }
          _requiresSignIn = false;
          _syncOwnerId ??= auth.currentUser?.id;
        }
        if (!auth.isAuthenticated ||
            _syncOwnerId == null ||
            auth.currentUser?.id != _syncOwnerId) {
          setState(() => _error = 'Sign in to the intended account to sync.');
          return;
        }
      }

      if (_savedEntry == null) {
        final entry = HistoryEntry(
          id: _draftId,
          text: text,
          sourceApp: widget.sharedSnippet?.sourceApp ?? 'Manual entry',
          capturedAt: widget.sharedSnippet?.capturedAt ?? DateTime.now(),
        );
        await ref
            .read(historyNotifierProvider.notifier)
            .saveLocalSnippet(entry);
        _savedEntry = entry;
      }
      if (sync && !_synced) {
        _syncRequested = true;
        await auth.publishManualSnippet(_savedEntry!, ownerId: _syncOwnerId);
        _synced = true;
      }
      await _finishImport();
      if (mounted) {
        Navigator.of(
          context,
        ).pop(sync ? 'Saved and synced to your dashboard' : 'Snippet saved');
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _requiresSignIn =
              error is SnippetSyncException && error.requiresSignIn;
          final syncMessage = error is SnippetSyncException
              ? error.message
              : 'Sync failed. Tap Retry Sync to try again.';
          _error = _savedEntry == null
              ? 'Could not save your snippet. Please try again.'
              : (!_syncRequested || _synced)
              ? 'Saved on this device. Could not clear the shared item. Try again.'
              : 'Saved on this device. $syncMessage';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      scrollable: true,
      title: const Text('Save Snippet'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.sharedSnippet == null
                ? 'Type text to save. Leave out passwords, PINs, and payment details.'
                : 'Review the shared text. Leave out passwords, PINs, and payment details.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            readOnly: _saving || _savedEntry != null,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.multiline,
            minLines: 3,
            maxLines: 6,
            decoration: InputDecoration(
              labelText: 'Snippet',
              errorText: _error,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(_savedEntry == null ? 'Cancel' : 'Done'),
        ),
        if (widget.sharedSnippet != null && _savedEntry == null)
          TextButton(
            onPressed: _saving ? null : _discardImport,
            child: const Text('Discard'),
          ),
        if (_savedEntry == null ||
            (widget.sharedSnippet != null && !_syncRequested))
          OutlinedButton(
            onPressed: _saving ? null : () => _save(sync: false),
            child: const Text('Save'),
          ),
        FilledButton(
          onPressed: _saving ? null : () => _save(sync: true),
          child: Text(_syncRequested ? 'Retry Sync' : 'Save & Sync'),
        ),
      ],
    ),
  );
}
