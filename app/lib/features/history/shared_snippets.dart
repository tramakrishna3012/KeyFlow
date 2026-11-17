import 'package:flutter/services.dart';

import '../../data/models/history_entry.dart';

class SharedSnippets {
  static const _channel = MethodChannel('com.keyflow.app/shared-snippets');

  static Future<HistoryEntry?> next() async {
    final data = await _channel.invokeMapMethod<String, String>('next');
    if (data == null) return null;
    return HistoryEntry(
      id: data['id']!,
      text: data['text']!,
      sourceApp: 'Shared text',
      capturedAt: DateTime.parse(data['capturedAt']!),
    );
  }

  static Future<void> remove(String id) => _channel.invokeMethod('remove', id);
}
