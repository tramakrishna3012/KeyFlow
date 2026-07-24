/// A single captured text entry in the typing history.
///
/// Schema matches Architecture §3:
/// `history_entries(id, text, source_app, captured_at, language,
///  was_translated, device_id)`
class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.text,
    required this.sourceApp,
    required this.capturedAt,
    this.language,
    this.wasTranslated = false,
    this.deviceId,
    this.category,
    this.useCount = 0,
  });

  /// Unique identifier for this entry.
  final String id;

  /// The captured text content.
  final String text;

  /// Identifier of the source application (e.g., package name, window title).
  final String sourceApp;

  /// When this text was captured.
  final DateTime capturedAt;

  /// Detected or tagged language code (e.g., 'en', 'es').
  final String? language;

  /// Whether this entry was the result of a translation.
  final bool wasTranslated;

  /// Device identifier (for multi-device awareness, even without sync).
  final String? deviceId;

  /// User-assigned or auto-detected category tag.
  final String? category;

  /// How many times this snippet has been reused.
  final int useCount;

  /// Creates a copy with overridden fields.
  HistoryEntry copyWith({
    String? id,
    String? text,
    String? sourceApp,
    DateTime? capturedAt,
    String? language,
    bool? wasTranslated,
    String? deviceId,
    String? category,
    int? useCount,
  }) =>
      HistoryEntry(
        id: id ?? this.id,
        text: text ?? this.text,
        sourceApp: sourceApp ?? this.sourceApp,
        capturedAt: capturedAt ?? this.capturedAt,
        language: language ?? this.language,
        wasTranslated: wasTranslated ?? this.wasTranslated,
        deviceId: deviceId ?? this.deviceId,
        category: category ?? this.category,
        useCount: useCount ?? this.useCount,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HistoryEntry &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'HistoryEntry(id: $id, text: "${text.length > 30 ? '${text.substring(0, 30)}...' : text}")';
}
