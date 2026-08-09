class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.text,
    required this.sourceApp,
    required this.capturedAt,
    this.language = 'en',
    this.wasTranslated = false,
    this.deviceId,
    this.category,
    this.useCount = 0,
  });

  factory HistoryEntry.fromMap(Map<String, dynamic> map) => HistoryEntry(
        id: map['id'] as String,
        text: map['text'] as String,
        sourceApp: map['source_app'] as String,
        capturedAt: DateTime.fromMillisecondsSinceEpoch(map['captured_at'] as int),
        language: (map['language'] as String?) ?? 'en',
        wasTranslated: (map['was_translated'] as int?) == 1,
        deviceId: map['device_id'] as String?,
        category: map['category'] as String?,
        useCount: (map['use_count'] as int?) ?? 0,
      );

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry.fromMap(json);

  Map<String, dynamic> toJson() => toMap();


  final String id;
  final String text;
  final String sourceApp;
  final DateTime capturedAt;
  final String language;
  final bool wasTranslated;
  final String? deviceId;
  final String? category;
  final int useCount;

  Map<String, dynamic> toMap() => {
      'id': id,
      'text': text,
      'source_app': sourceApp,
      'captured_at': capturedAt.millisecondsSinceEpoch,
      'language': language,
      'was_translated': wasTranslated ? 1 : 0,
      'device_id': deviceId,
      'category': category,
      'use_count': useCount,
    };

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
  }) => HistoryEntry(
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
}
