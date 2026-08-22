enum LookMonitoringStatus { active, paused, stopped, completed }

enum LookConsentState { granted, revoked, pending }

class MonitoredActivityEvent {
  const MonitoredActivityEvent({
    required this.id,
    required this.eventType,
    required this.startedAt,
    required this.endedAt,
    required this.durationSeconds,
    required this.isIdle,
    required this.windowTitle,
  });

  factory MonitoredActivityEvent.fromJson(Map<String, dynamic> json) =>
      MonitoredActivityEvent(
        id: json['id'] as String? ?? '',
        eventType: json['eventType'] as String? ?? 'active',
        startedAt:
            DateTime.tryParse(json['startedAt']?.toString() ?? '') ??
            DateTime.now(),
        endedAt:
            DateTime.tryParse(json['endedAt']?.toString() ?? '') ??
            DateTime.now(),
        durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
        isIdle: json['isIdle'] as bool? ?? false,
        windowTitle: json['windowTitle'] as String? ?? '',
      );

  final String id;
  final String eventType;
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationSeconds;
  final bool isIdle;
  final String windowTitle;

  Map<String, dynamic> toJson() => {
    'id': id,
    'eventType': eventType,
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt.toIso8601String(),
    'durationSeconds': durationSeconds,
    'isIdle': isIdle,
    'windowTitle': windowTitle,
  };
}

class PermittedTextRecord {
  const PermittedTextRecord({
    required this.id,
    required this.capturedAt,
    required this.content,
    required this.sanitizedPreview,
    this.isExcluded = false,
  });

  factory PermittedTextRecord.fromJson(Map<String, dynamic> json) =>
      PermittedTextRecord(
        id: json['id'] as String? ?? '',
        capturedAt:
            DateTime.tryParse(json['capturedAt']?.toString() ?? '') ??
            DateTime.now(),
        content: json['content'] as String? ?? '',
        sanitizedPreview: json['sanitizedPreview'] as String? ?? '',
        isExcluded: json['isExcluded'] as bool? ?? false,
      );

  final String id;
  final DateTime capturedAt;
  final String content;
  final String sanitizedPreview;
  final bool isExcluded;

  Map<String, dynamic> toJson() => {
    'id': id,
    'capturedAt': capturedAt.toIso8601String(),
    'content': content,
    'sanitizedPreview': sanitizedPreview,
    'isExcluded': isExcluded,
  };
}

class MonitoredApplication {
  MonitoredApplication({
    required this.appName,
    required this.category,
    this.totalDurationSeconds = 0,
    List<MonitoredActivityEvent>? activityTimeline,
    List<PermittedTextRecord>? textRecords,
  }) : activityTimeline = activityTimeline ?? [],
       textRecords = textRecords ?? [];

  final String appName;
  final String category;
  int totalDurationSeconds;
  final List<MonitoredActivityEvent> activityTimeline;
  final List<PermittedTextRecord> textRecords;

  Map<String, dynamic> toJson() => {
    'appName': appName,
    'category': category,
    'totalDurationSeconds': totalDurationSeconds,
    'activityTimeline': activityTimeline.map((e) => e.toJson()).toList(),
    'textRecords': textRecords.map((e) => e.toJson()).toList(),
  };
}

class LookMonitoringSession {
  LookMonitoringSession({
    required this.sessionId,
    required this.startedAt,
    this.endedAt,
    this.status = LookMonitoringStatus.active,
    this.totalActiveSeconds = 0,
    this.totalIdleSeconds = 0,
    List<MonitoredApplication>? applications,
  }) : applications = applications ?? [];

  final String sessionId;
  final DateTime startedAt;
  DateTime? endedAt;
  LookMonitoringStatus status;
  int totalActiveSeconds;
  int totalIdleSeconds;
  final List<MonitoredApplication> applications;

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt?.toIso8601String(),
    'status': status.name,
    'totalActiveSeconds': totalActiveSeconds,
    'totalIdleSeconds': totalIdleSeconds,
    'applications': applications.map((a) => a.toJson()).toList(),
  };
}

class PrivacyExclusionRule {
  const PrivacyExclusionRule({
    required this.appName,
    this.fieldType,
    this.isActive = true,
  });

  final String appName;
  final String? fieldType;
  final bool isActive;
}

class OfflineSyncQueueItem {
  const OfflineSyncQueueItem({
    required this.id,
    required this.sessionId,
    required this.appName,
    required this.windowTitle,
    this.textRecord,
    required this.durationSeconds,
    required this.timestamp,
  });

  final String id;
  final String sessionId;
  final String appName;
  final String windowTitle;
  final String? textRecord;
  final int durationSeconds;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
    'id': id,
    'sessionId': sessionId,
    'appName': appName,
    'windowTitle': windowTitle,
    'textRecord': textRecord,
    'durationSeconds': durationSeconds,
    'startedAt': timestamp.toIso8601String(),
    'endedAt': timestamp.add(Duration(seconds: durationSeconds)).toIso8601String(),
  };
}

class LookActivityLog {
  const LookActivityLog({
    required this.id,
    required this.appName,
    required this.appCategory,
    required this.windowTitle,
    required this.durationSeconds,
    required this.idleSeconds,
    required this.isIdle,
    required this.startedAt,
    required this.endedAt,
  });

  factory LookActivityLog.fromJson(Map<String, dynamic> json) =>
      LookActivityLog(
        id: json['id'] as String? ?? '',
        appName: json['appName'] as String? ?? 'Unknown',
        appCategory: json['appCategory'] as String? ?? 'General',
        windowTitle: json['windowTitle'] as String? ?? '',
        durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
        idleSeconds: (json['idleSeconds'] as num?)?.toInt() ?? 0,
        isIdle: json['isIdle'] as bool? ?? false,
        startedAt:
            DateTime.tryParse(json['startedAt']?.toString() ?? '') ??
            DateTime.now(),
        endedAt:
            DateTime.tryParse(json['endedAt']?.toString() ?? '') ??
            DateTime.now(),
      );

  final String id;
  final String appName;
  final String appCategory;
  final String windowTitle;
  final int durationSeconds;
  final int idleSeconds;
  final bool isIdle;
  final DateTime startedAt;
  final DateTime endedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'appName': appName,
    'appCategory': appCategory,
    'windowTitle': windowTitle,
    'durationSeconds': durationSeconds,
    'idleSeconds': idleSeconds,
    'isIdle': isIdle,
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt.toIso8601String(),
  };
}

class LookDailySummary {
  const LookDailySummary({
    required this.totalDurationSeconds,
    required this.totalActiveSeconds,
    required this.totalIdleSeconds,
    required this.productivityScore,
    required this.topApps,
    required this.categories,
  });

  final int totalDurationSeconds;
  final int totalActiveSeconds;
  final int totalIdleSeconds;
  final int productivityScore;
  final List<Map<String, dynamic>> topApps;
  final List<Map<String, dynamic>> categories;
}
