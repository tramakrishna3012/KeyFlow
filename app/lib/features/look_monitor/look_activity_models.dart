enum LookMonitoringStatus {
  active,
  paused,
  stopped,
}

enum LookConsentState {
  granted,
  revoked,
  pending,
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

  factory LookActivityLog.fromJson(Map<String, dynamic> json) => LookActivityLog(
    id: json['id'] as String? ?? '',
    appName: json['appName'] as String? ?? 'Unknown',
    appCategory: json['appCategory'] as String? ?? 'General',
    windowTitle: json['windowTitle'] as String? ?? '',
    durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
    idleSeconds: (json['idleSeconds'] as num?)?.toInt() ?? 0,
    isIdle: json['isIdle'] as bool? ?? false,
    startedAt: DateTime.tryParse(json['startedAt']?.toString() ?? '') ?? DateTime.now(),
    endedAt: DateTime.tryParse(json['endedAt']?.toString() ?? '') ?? DateTime.now(),
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
