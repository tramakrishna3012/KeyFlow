import 'dart:async';
import 'package:uuid/uuid.dart';

class DraftSnapshot {
  const DraftSnapshot({
    required this.timestamp,
    required this.text,
    required this.charCount,
  });

  factory DraftSnapshot.fromJson(Map<String, dynamic> json) => DraftSnapshot(
        timestamp: json['timestamp'] as String? ?? '',
        text: json['text'] as String? ?? '',
        charCount: json['charCount'] as int? ?? 0,
      );

  final String timestamp;
  final String text;
  final int charCount;

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp,
        'text': text,
        'charCount': charCount,
      };
}

class AggregatedTypingSession {
  AggregatedTypingSession({
    required this.id,
    this.userId,
    required this.deviceName,
    required this.appName,
    this.windowTitle,
    required this.content,
    required this.characterCount,
    required this.wordCount,
    required this.startedAt,
    required this.updatedAt,
    this.isFavorite = false,
    List<DraftSnapshot>? draftHistory,
    this.isFinalized = false,
  }) : draftHistory = draftHistory ?? [];

  final String id;
  final String? userId;
  final String deviceName;
  final String appName;
  final String? windowTitle;
  String content;
  int characterCount;
  int wordCount;
  final String startedAt;
  String updatedAt;
  bool isFavorite;
  final List<DraftSnapshot> draftHistory;
  bool isFinalized;

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'deviceName': deviceName,
        'appName': appName,
        'windowTitle': windowTitle,
        'content': content,
        'characterCount': characterCount,
        'wordCount': wordCount,
        'startedAt': startedAt,
        'updatedAt': updatedAt,
        'isFavorite': isFavorite,
        'draftHistory': draftHistory.map((s) => s.toJson()).toList(),
        'isFinalized': isFinalized,
      };
}

class DartSessionAggregator {
  DartSessionAggregator({
    this.inactivityDebounceMs = 2500,
    this.sessionTimeoutMs = 60000,
    List<String>? blacklistedApps,
    this.onSessionUpdate,
    this.onSessionFinalize,
  }) : blacklistedApps = (blacklistedApps ?? [])
            .map((e) => e.toLowerCase())
            .toSet();

  final int inactivityDebounceMs;
  final int sessionTimeoutMs;
  final Set<String> blacklistedApps;
  final void Function(AggregatedTypingSession session)? onSessionUpdate;
  final void Function(AggregatedTypingSession session)? onSessionFinalize;

  static const _uuid = Uuid();
  final Map<String, AggregatedTypingSession> _activeSessions = {};
  final Map<String, Timer> _debounceTimers = {};
  final Map<String, Timer> _expiryTimers = {};
  final Map<String, int> _lastActivityTimes = {};

  static int calculateWordCount(String text) {
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
  }

  String _getSessionKey(String appName, String windowTitle, String deviceName) =>
      '${appName.trim().toLowerCase()}::${windowTitle.trim().toLowerCase()}::${deviceName.trim().toLowerCase()}';

  bool isPrivacySensitive(String appName, String windowTitle, bool isPasswordField) {
    if (isPasswordField) return true;
    if (blacklistedApps.contains(appName.toLowerCase())) return true;

    final lowerApp = appName.toLowerCase();
    if (lowerApp.contains('calc') || lowerApp.contains('calculator')) {
      return false;
    }

    final sensitivePatterns = [
      RegExp('password', caseSensitive: false),
      RegExp('authenticator', caseSensitive: false),
      RegExp('banking', caseSensitive: false),
      RegExp('card details', caseSensitive: false),
      RegExp('cvv', caseSensitive: false),
    ];

    for (final pattern in sensitivePatterns) {
      if (pattern.hasMatch(windowTitle)) {
        return true;
      }
    }
    return false;
  }

  AggregatedTypingSession? handleTypingInput({
    required String appName,
    String windowTitle = '',
    String deviceName = 'Android',
    required String text,
    bool isReplacement = false,
    bool isPasswordField = false,
    String? userId,
  }) {
    if (isPrivacySensitive(appName, windowTitle, isPasswordField)) {
      return null;
    }

    if (text.isEmpty && !isReplacement) return null;

    final sessionKey = _getSessionKey(appName, windowTitle, deviceName);
    final now = DateTime.now().millisecondsSinceEpoch;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    var session = _activeSessions[sessionKey];
    final lastActivity = _lastActivityTimes[sessionKey] ?? 0;

    // 60s termination boundary
    if (session != null && now - lastActivity > sessionTimeoutMs) {
      finalizeSession(sessionKey);
      session = null;
    }

    if (session == null) {
      session = AggregatedTypingSession(
        id: _uuid.v4(),
        userId: userId,
        deviceName: deviceName,
        appName: appName,
        windowTitle: windowTitle,
        content: text,
        characterCount: text.length,
        wordCount: calculateWordCount(text),
        startedAt: nowIso,
        updatedAt: nowIso,
        draftHistory: [
          DraftSnapshot(timestamp: nowIso, text: text, charCount: text.length)
        ],
      );
      _activeSessions[sessionKey] = session;
    } else {
      session
        ..content = text
        ..characterCount = session.content.length
        ..wordCount = calculateWordCount(session.content)
        ..updatedAt = nowIso;

      if (session.draftHistory.isEmpty ||
          (session.content.length - session.draftHistory.last.charCount).abs() >= 5) {
        session.draftHistory.add(
          DraftSnapshot(timestamp: nowIso, text: session.content, charCount: session.content.length),
        );
        if (session.draftHistory.length > 100) {
          session.draftHistory.removeAt(0);
        }
      }
    }

    _lastActivityTimes[sessionKey] = now;

    // Reset expiry timer
    _expiryTimers[sessionKey]?.cancel();
    _expiryTimers[sessionKey] = Timer(Duration(milliseconds: sessionTimeoutMs), () {
      finalizeSession(sessionKey);
    });

    // Reset 2.5s debounce timer
    _debounceTimers[sessionKey]?.cancel();
    _debounceTimers[sessionKey] = Timer(Duration(milliseconds: inactivityDebounceMs), () {
      _dispatchDebouncedUpdate(sessionKey);
    });

    return session;
  }

  void _dispatchDebouncedUpdate(String sessionKey) {
    final session = _activeSessions[sessionKey];
    if (session == null) return;
    onSessionUpdate?.call(session);
  }

  AggregatedTypingSession? finalizeSession(String sessionKey) {
    final session = _activeSessions[sessionKey];
    if (session == null) return null;

    _debounceTimers[sessionKey]?.cancel();
    _debounceTimers.remove(sessionKey);
    _expiryTimers[sessionKey]?.cancel();
    _expiryTimers.remove(sessionKey);

    session
      ..isFinalized = true
      ..updatedAt = DateTime.now().toUtc().toIso8601String();

    onSessionFinalize?.call(session);

    _activeSessions.remove(sessionKey);
    _lastActivityTimes.remove(sessionKey);
    return session;
  }

  List<AggregatedTypingSession> finalizeAll() {
    final list = <AggregatedTypingSession>[];
    final keys = _activeSessions.keys.toList();
    for (final key in keys) {
      final sess = finalizeSession(key);
      if (sess != null) list.add(sess);
    }
    return list;
  }

  void dispose() {
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    for (final timer in _expiryTimers.values) {
      timer.cancel();
    }
    _expiryTimers.clear();
    _activeSessions.clear();
    _lastActivityTimes.clear();
  }
}
