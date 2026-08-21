import 'dart:async';
import 'package:flutter/foundation.dart';
import 'look_activity_models.dart';
import 'look_window_sanitizer.dart';

/// Transparent, privacy-preserving activity monitoring engine.
///
/// Features:
/// - Strictly non-covert: always reports its state
/// - Privacy-safe: never captures keystrokes, passwords, clipboard, or contents
/// - Zero performance overhead
class LookMonitorService extends ChangeNotifier {
  LookMonitorService({LookWindowSanitizer? sanitizer})
    : _sanitizer = sanitizer ?? const LookWindowSanitizer();

  final LookWindowSanitizer _sanitizer;
  Timer? _pollingTimer;
  Timer? _resumeTimer;

  LookMonitoringStatus _status = LookMonitoringStatus.active;
  LookConsentState _consentState = LookConsentState.granted;

  String _currentApp = 'KeyFlow Look Studio';
  String _currentWindowTitle = 'Dashboard Overview';
  DateTime _currentIntervalStart = DateTime.now();
  int _currentIdleSeconds = 0;
  bool _isCurrentlyIdle = false;

  final List<LookActivityLog> _activityLogs = [];

  LookMonitoringStatus get status => _status;
  LookConsentState get consentState => _consentState;
  String get currentApp => _currentApp;
  String get currentWindowTitle => _currentWindowTitle;
  bool get isCurrentlyIdle => _isCurrentlyIdle;
  List<LookActivityLog> get activityLogs => List.unmodifiable(_activityLogs);

  void startMonitoring() {
    _resumeTimer?.cancel();
    if (_consentState != LookConsentState.granted) {
      debugPrint('[LookMonitor] Monitoring not started: user consent required');
      _status = LookMonitoringStatus.stopped;
      notifyListeners();
      return;
    }

    _status = LookMonitoringStatus.active;
    _currentIntervalStart = DateTime.now();
    _startPolling();
    notifyListeners();
  }

  void pauseMonitoring([Duration? duration]) {
    _resumeTimer?.cancel();
    _status = LookMonitoringStatus.paused;
    _recordCurrentInterval();
    _pollingTimer?.cancel();
    notifyListeners();

    if (duration != null) {
      _resumeTimer = Timer(duration, () {
        if (_status == LookMonitoringStatus.paused) {
          startMonitoring();
        }
      });
    }
  }

  void resumeMonitoring() {
    startMonitoring();
  }

  void stopMonitoring() {
    _resumeTimer?.cancel();
    _status = LookMonitoringStatus.stopped;
    _recordCurrentInterval();
    _pollingTimer?.cancel();
    notifyListeners();
  }

  void setConsent(LookConsentState state) {
    _consentState = state;
    if (state != LookConsentState.granted) {
      _resumeTimer?.cancel();
      stopMonitoring();
    } else {
      startMonitoring();
    }
    notifyListeners();
  }

  /// Simulates / updates foreground window activity from native OS layer
  void updateForegroundWindow({
    required String appName,
    required String rawTitle,
    bool isIdle = false,
    int idleSeconds = 0,
  }) {
    if (_status != LookMonitoringStatus.active) return;

    final sanitizedTitle = _sanitizer.sanitize(rawTitle);

    if (_currentApp != appName ||
        _currentWindowTitle != sanitizedTitle ||
        _isCurrentlyIdle != isIdle) {
      _recordCurrentInterval(force: true);
      _currentApp = appName;
      _currentWindowTitle = sanitizedTitle;
      _isCurrentlyIdle = isIdle;
      _currentIdleSeconds = idleSeconds;
      _currentIntervalStart = DateTime.now();
      notifyListeners();
    } else {
      _currentIdleSeconds = idleSeconds;
    }
  }

  void _recordCurrentInterval({bool force = false}) {
    final now = DateTime.now();
    final duration = now.difference(_currentIntervalStart).inSeconds;

    if ((duration > 0 || force) && _currentApp.isNotEmpty) {
      final log = LookActivityLog(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        appName: _currentApp,
        appCategory: _inferCategory(_currentApp),
        windowTitle: _currentWindowTitle,
        durationSeconds: duration > 0 ? duration : 1,
        idleSeconds: _currentIdleSeconds,
        isIdle: _isCurrentlyIdle,
        startedAt: _currentIntervalStart,
        endedAt: now,
      );

      _activityLogs.insert(0, log);
      // Keep in-memory buffer to 200 items
      if (_activityLogs.length > 200) {
        _activityLogs.removeLast();
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
    super.dispose();
  }
}
