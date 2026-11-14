import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/auth_service.dart';
import '../../data/models/history_entry.dart';
import '../../data/providers.dart';
import '../auth/auth_modal.dart';
import '../look_monitor/look_window_sanitizer.dart';
import 'history_providers.dart';

class SaveSnippetDialog extends ConsumerStatefulWidget {
  const SaveSnippetDialog({super.key});

  static Future<void> show(BuildContext context) async {
    final message = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const SaveSnippetDialog(),
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
  final _controller = TextEditingController();
  final _draftId = const Uuid().v4();
  HistoryEntry? _savedEntry;
  String? _syncOwnerId;
  bool _syncRequested = false;
  bool _requiresSignIn = false;
  bool _saving = false;
  String? _error;

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
          sourceApp: 'Manual entry',
          capturedAt: DateTime.now(),
        );
        await ref
            .read(historyNotifierProvider.notifier)
            .saveLocalSnippet(entry);
        _savedEntry = entry;
      }
      if (sync) {
        _syncRequested = true;
        await auth.publishManualSnippet(_savedEntry!, ownerId: _syncOwnerId);
      }
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
          const Text(
            'Type text to save. Leave out passwords, PINs, and payment details.',
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
        if (_savedEntry == null)
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
