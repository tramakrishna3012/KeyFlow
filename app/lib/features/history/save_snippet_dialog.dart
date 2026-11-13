import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/history_entry.dart';
import '../look_monitor/look_window_sanitizer.dart';
import 'history_providers.dart';

class SaveSnippetDialog extends ConsumerStatefulWidget {
  const SaveSnippetDialog({super.key});

  static Future<void> show(BuildContext context) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const SaveSnippetDialog(),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Snippet saved')));
    }
  }

  @override
  ConsumerState<SaveSnippetDialog> createState() => _SaveSnippetDialogState();
}

class _SaveSnippetDialogState extends ConsumerState<SaveSnippetDialog> {
  final _controller = TextEditingController();
  final _id = const Uuid().v4();
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
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

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(historyNotifierProvider.notifier)
          .saveLocalSnippet(
            HistoryEntry(
              id: _id,
              text: text,
              sourceApp: 'Manual entry',
              capturedAt: DateTime.now(),
            ),
          );
      if (mounted) Navigator.of(context).pop(true);
    } on Object {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save your snippet. Please try again.';
        });
      }
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
            'Type or paste text to save on this device. Leave out passwords, PINs, and payment details.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            readOnly: _saving,
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
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ],
    ),
  );
}
