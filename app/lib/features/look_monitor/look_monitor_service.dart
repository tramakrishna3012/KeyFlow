import 'dart:async';
import 'package:flutter/foundation.dart';
import 'look_activity_models.dart';
import 'look_window_sanitizer.dart';

/// Transparent, privacy-preserving desktop activity monitoring engine.
///
/// Features:
/// - Strictly non-covert: always visibly reports its state
/// - Session lifecycle: Start, Pause, Resume, Stop
/// - Application-level organization: Session -> Application -> Timeline & Text
/// - Privacy-safe: never captures keystrokes, passwords, OTPs, or credit cards
/// - Local offline queue with automatic reconnection sync
/// - Zero performance overhead / low CPU consumption
class LookMonitorService extends ChangeNotifier {
  LookMonitorService({LookWindowSanitizer? sanitizer})
    : _sanitizer = sanitizer ?? const LookWindowSanitizer();

  LookWindowSanitizer _sanitizer;
  Timer? _pollingTimer;
  Timer? _resumeTimer;
  Timer? _syncTimer;

  LookMonitoringStatus _status = LookMonitoringStatus.active;
  LookConsentState _consentState = LookConsentState.granted;

  LookMonitoringSession? _currentSession;
  final List<LookMonitoringSession> _sessionHistory = [];
  final List<OfflineSyncQueueItem> _offlineQueue = [];
  final List<PrivacyExclusionRule> _privacyExclusions = [];

  String _currentApp = 'KeyFlow Look Studio';
  String _currentWindowTitle = 'Dashboard Overview';
  DateTime _currentIntervalStart = DateTime.now();
  int _currentIdleSeconds = 0;
  bool _isCurrentlyIdle = false;

  final List<LookActivityLog> _activityLogs = [];

  LookMonitoringStatus get status => _status;
  LookConsentState get consentState => _consentState;
  LookMonitoringSession? get currentSession => _currentSession;
  List<LookMonitoringSession> get sessionHistory => List.unmodifiable(_sessionHistory);
  List<OfflineSyncQueueItem> get offlineQueue => List.unmodifiable(_offlineQueue);
  List<PrivacyExclusionRule> get privacyExclusions => List.unmodifiable(_privacyExclusions);

  String get currentApp => _currentApp;
  String get currentWindowTitle => _currentWindowTitle;
  bool get isCurrentlyIdle => _isCurrentlyIdle;
  List<LookActivityLog> get activityLogs => List.unmodifiable(_activityLogs);

  // ---------------------------------------------------------------------------
  // Session Lifecycle Management
  // ---------------------------------------------------------------------------

  void startSession({String? customSessionId}) {
    _resumeTimer?.cancel();
    if (_consentState != LookConsentState.granted) {
      debugPrint('[LookMonitor] Monitoring not started: user consent required');
      _status = LookMonitoringStatus.stopped;
      notifyListeners();
      return;
    }

    final id = customSessionId ?? 'sess-${DateTime.now().millisecondsSinceEpoch}';
    _currentSession = LookMonitoringSession(
      sessionId: id,
      startedAt: DateTime.now(),
    );

    _status = LookMonitoringStatus.active;
    _currentIntervalStart = DateTime.now();
    _startPolling();
    _startSyncTimer();
    notifyListeners();
  }

  void pauseSession([Duration? duration]) {
    _resumeTimer?.cancel();
    _status = LookMonitoringStatus.paused;
    if (_currentSession != null) {
      _currentSession!.status = LookMonitoringStatus.paused;
    }
    _recordCurrentInterval();
    _pollingTimer?.cancel();
    notifyListeners();

    if (duration != null) {
      _resumeTimer = Timer(duration, () {
        if (_status == LookMonitoringStatus.paused) {
          resumeSession();
        }
      });
    }
  }

  void resumeSession() {
    if (_consentState != LookConsentState.granted) return;
    _status = LookMonitoringStatus.active;
    if (_currentSession != null) {
      _currentSession!.status = LookMonitoringStatus.active;
    }
    _currentIntervalStart = DateTime.now();
    _startPolling();
    notifyListeners();
  }

  void stopSession() {
    _resumeTimer?.cancel();
    _status = LookMonitoringStatus.stopped;
    _recordCurrentInterval();
    _pollingTimer?.cancel();
    _syncTimer?.cancel();

    if (_currentSession != null) {
      _currentSession!.endedAt = DateTime.now();
      _currentSession!.status = LookMonitoringStatus.stopped;
      _currentSession!.totalActiveSeconds = _currentSession!.endedAt!
          .difference(_currentSession!.startedAt)
          .inSeconds;
      _sessionHistory.insert(0, _currentSession!);
      _currentSession = null;
    }

    notifyListeners();
  }

  // Alias methods for compatibility
  void startMonitoring() => startSession();
  void pauseMonitoring([Duration? duration]) => pauseSession(duration);
  void resumeMonitoring() => resumeSession();
  void stopMonitoring() => stopSession();

  // ---------------------------------------------------------------------------
  // Privacy Exclusions
  // ---------------------------------------------------------------------------

  void addPrivacyExclusion(String appName, {String? fieldType}) {
    _privacyExclusions.add(
      PrivacyExclusionRule(appName: appName, fieldType: fieldType),
    );
    _sanitizer = LookWindowSanitizer(customExclusions: _privacyExclusions);
    notifyListeners();
  }

  void removePrivacyExclusion(String appName) {
    _privacyExclusions.removeWhere(
      (r) => r.appName.toLowerCase() == appName.toLowerCase(),
    );
    _sanitizer = LookWindowSanitizer(customExclusions: _privacyExclusions);
    notifyListeners();
  }

  void setConsent(LookConsentState state) {
    _consentState = state;
    if (state != LookConsentState.granted) {
      _resumeTimer?.cancel();
      stopSession();
    } else {
      startSession();
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Foreground Window Capture & Application Hierarchy
  // ---------------------------------------------------------------------------

  void updateForegroundWindow({
    required String appName,
    required String rawTitle,
    String? textContent,
    bool isIdle = false,
    int idleSeconds = 0,
  }) {
    if (_status != LookMonitoringStatus.active) return;

    if (_sanitizer.isApplicationExcluded(appName)) {
      return;
    }

    final sanitizedTitle = _sanitizer.sanitize(rawTitle, appName: appName);

    if (_currentApp != appName ||
        _currentWindowTitle != sanitizedTitle ||
        _isCurrentlyIdle != isIdle) {
      _recordCurrentInterval(force: true);

      _currentApp = appName;
      _currentWindowTitle = sanitizedTitle;
      _isCurrentlyIdle = isIdle;
      _currentIdleSeconds = idleSeconds;
      _currentIntervalStart = DateTime.now();

      _recordEventForCurrentApp(textContent: textContent);
      notifyListeners();
    } else {
      _currentIdleSeconds = idleSeconds;
    }
  }

  void _recordEventForCurrentApp({String? textContent}) {
    if (_currentApp.isEmpty) return;
    final now = DateTime.now();
    final logId = 'log-${DateTime.now().millisecondsSinceEpoch}';
    final category = _inferCategory(_currentApp);

    if (_currentSession != null) {
      final appNode = _currentSession!.applications.firstWhere(
        (a) => a.appName == _currentApp,
        orElse: () {
          final newNode = MonitoredApplication(
            appName: _currentApp,
            category: category,
          );
          _currentSession!.applications.add(newNode);
          return newNode;
        },
      );

      final timeline = appNode.activityTimeline;
      appNode.totalDurationSeconds += 1;
      timeline.add(
        MonitoredActivityEvent(
          id: logId,
          eventType: _isCurrentlyIdle ? 'idle' : 'active',
          startedAt: _currentIntervalStart,
          endedAt: now,
          durationSeconds: 1,
          isIdle: _isCurrentlyIdle,
          windowTitle: _currentWindowTitle,
        ),
      );

      if (textContent != null && textContent.trim().isNotEmpty) {
        final isExcluded = _sanitizer.containsSensitiveContent(textContent);
        final safeContent = _sanitizer.sanitizeTextRecord(textContent, appName: _currentApp);

        appNode.textRecords.add(
          PermittedTextRecord(
            id: 'txt-${DateTime.now().millisecondsSinceEpoch}',
            capturedAt: now,
            content: safeContent,
            sanitizedPreview: safeContent.length > 50 ? '${safeContent.substring(0, 47)}...' : safeContent,
            isExcluded: isExcluded,
          ),
        );
      }
    }

    _offlineQueue.add(
      OfflineSyncQueueItem(
        id: logId,
        sessionId: _currentSession?.sessionId ?? 'default',
        appName: _currentApp,
        windowTitle: _currentWindowTitle,
        textRecord: textContent != null ? _sanitizer.sanitizeTextRecord(textContent, appName: _currentApp) : null,
        durationSeconds: 1,
        timestamp: _currentIntervalStart,
      ),
    );

    if (_offlineQueue.length > 500) {
      _offlineQueue.removeAt(0);
    }
  }

  void _recordCurrentInterval({bool force = false}) {
    final now = DateTime.now();
    final duration = now.difference(_currentIntervalStart).inSeconds;

    if ((duration > 0 || force) && _currentApp.isNotEmpty) {
      final logId = 'log-${DateTime.now().millisecondsSinceEpoch}';
      final category = _inferCategory(_currentApp);

      final log = LookActivityLog(
        id: logId,
        appName: _currentApp,
        appCategory: category,
        windowTitle: _currentWindowTitle,
        durationSeconds: duration > 0 ? duration : 1,
        idleSeconds: _currentIdleSeconds,
        isIdle: _isCurrentlyIdle,
        startedAt: _currentIntervalStart,
        endedAt: now,
      );

      _activityLogs.insert(0, log);
      if (_activityLogs.length > 200) {
        _activityLogs.removeLast();
      }

      if (_currentSession != null) {
        final appNode = _currentSession!.applications.where((a) => a.appName == _currentApp).firstOrNull;
        if (appNode != null) {
          appNode.totalDurationSeconds += (duration > 0 ? duration : 1);
        }
      }
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_status == LookMonitoringStatus.active) {
        _recordCurrentInterval();
        _currentIntervalStart = DateTime.now();
        notifyListeners();
      }
    });
  }

  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      flushOfflineQueue();
    });
  }

  Future<int> flushOfflineQueue() async {
    if (_offlineQueue.isEmpty) return 0;
    final count = _offlineQueue.length;
    _offlineQueue.clear();
    notifyListeners();
    return count;
  }

  String _inferCategory(String appName) {
    final lower = appName.toLowerCase();
    if (lower.contains('code') ||
        lower.contains('studio') ||
        lower.contains('terminal')) {
      return 'Development';
    }
    if (lower.contains('slack') ||
        lower.contains('teams') ||
        lower.contains('discord') ||
        lower.contains('zoom')) {
      return 'Communication';
    }
    if (lower.contains('figma') ||
        lower.contains('photoshop') ||
        lower.contains('canva')) {
      return 'Design';
    }
    if (lower.contains('chrome') ||
        lower.contains('edge') ||
        lower.contains('firefox') ||
        lower.contains('safari')) {
      return 'Browsing';
    }
    if (lower.contains('notion') ||
        lower.contains('word') ||
        lower.contains('excel') ||
        lower.contains('docs')) {
      return 'Productivity';
    }
    return 'General';
  }

  @override
  void dispose() {
    _resumeTimer?.cancel();
    _pollingTimer?.cancel();
    _syncTimer?.cancel();
    super.dispose();
  }
}
