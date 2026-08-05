import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../data/history_repository.dart';
import '../../data/models/history_entry.dart';
import '../../data/sync_service.dart';

/// Service interfacing Flutter with the native Windows WH_KEYBOARD_LL capture engine.
class CaptureService {

  CaptureService(this._repository, {SyncService? syncService})
      : _syncService = syncService {
    _methodChannel.setMethodCallHandler(_handleNativeMethodCall);
  }
  static const MethodChannel _methodChannel = MethodChannel('keyflow/capture');
  static const EventChannel _eventChannel = EventChannel('keyflow/capture/stream');

  final HistoryRepository _repository;
  final SyncService? _syncService;
  StreamSubscription<dynamic>? _subscription;

  bool _isCapturing = false;
  bool _isPaused = false;

  final Map<String, String> _inputBuffers = {};
  Timer? _flushTimer;

  void Function(String route)? onNavigate;

  bool get isCapturing => _isCapturing;
  bool get isPaused => _isPaused;

  /// Initialize capture service, sync exclusion list, and start listening to stream.
  Future<void> initialize() async {
    try {
      // Fetch exclusion list from DB repository and sync to native layer
      final exclusions = await _repository.getExclusionList();
      await syncExclusionList(exclusions);

      // Listen to native capture stream
      _subscription = _eventChannel.receiveBroadcastStream().listen(
        _onNativeCaptureEvent,
        onError: (error) {
          debugPrint('CaptureService stream error: $error');
        },
      );

      // Start capture on native side
      await startCapture();
    } on Object catch (e) {
      debugPrint('Error initializing CaptureService: $e');
    }
  }

  Future<bool> startCapture() async {
    try {
      final success = await _methodChannel.invokeMethod('startCapture') ?? false;
      _isCapturing = success;
      _isPaused = false;
      return success;
    } on PlatformException catch (e) {
      debugPrint('Failed to start capture: ${e.message}');
      return false;
    }
  }

  Future<bool> stopCapture() async {
    try {
      final success = await _methodChannel.invokeMethod('stopCapture') ?? false;
      _isCapturing = !success;
      await _flushAllBuffers();
      return success;
    } on PlatformException catch (e) {
      debugPrint('Failed to stop capture: ${e.message}');
      return false;
    }
  }

  Future<bool> pauseCapture() async {
    try {
      final success = await _methodChannel.invokeMethod('pauseCapture') ?? false;
      _isPaused = success;
      return success;
    } on PlatformException catch (e) {
      debugPrint('Failed to pause capture: ${e.message}');
      return false;
    }
  }

  Future<bool> resumeCapture() async {
    try {
      final success = await _methodChannel.invokeMethod('resumeCapture') ?? false;
      _isPaused = !success;
      return success;
    } on PlatformException catch (e) {
      debugPrint('Failed to resume capture: ${e.message}');
      return false;
    }
  }

  Future<void> syncExclusionList(List<String> excludedApps) async {
    try {
      await _methodChannel.invokeMethod('setExclusionList', excludedApps);
    } on PlatformException catch (e) {
      debugPrint('Failed to sync exclusion list: ${e.message}');
    }
  }

  Future<bool> setAutostart(bool enable) async {
    try {
      final success = await _methodChannel.invokeMethod('setAutostart', enable) ?? false;
      return success;
    } on PlatformException catch (e) {
      debugPrint('Failed to set autostart: ${e.message}');
      return false;
    }
  }

  Future<bool> isAutostartEnabled() async {
    try {
      final result = await _methodChannel.invokeMethod('isAutostartEnabled') ?? false;
      return result;
    } on PlatformException catch (e) {
      debugPrint('Failed to query autostart status: ${e.message}');
      return false;
    }
  }

  /// Checks if the Android Accessibility Service is enabled in system settings.
  Future<bool> isAccessibilityServiceEnabled() async {
    try {
      final result = await _methodChannel.invokeMethod('isAccessibilityServiceEnabled') ?? false;
      return result;
    } on PlatformException catch (e) {
      debugPrint('Failed to query accessibility service status: ${e.message}');
      return false;
    }
  }

  /// Opens the native system Accessibility Settings page so the user can enable KeyFlow.
  Future<void> openAccessibilitySettings() async {
    try {
      await _methodChannel.invokeMethod('openAccessibilitySettings');
    } on PlatformException catch (e) {
      debugPrint('Failed to open accessibility settings: ${e.message}');
    }
  }

  void _onNativeCaptureEvent(dynamic rawEvent) {
    if (rawEvent is! Map) return;

    final data = rawEvent;
    final text = data['text']?.toString() ?? '';
    final appName = data['app_name']?.toString() ?? 'Unknown';
    final windowTitle = data['window_title']?.toString() ?? '';
    final timestamp = (data['timestamp'] as int?) ?? DateTime.now().millisecondsSinceEpoch;

    if (text.isEmpty) return;

    // Buffer keystrokes per app until Enter/Tab or timeout occurs
    _inputBuffers[appName] = (_inputBuffers[appName] ?? '') + text;

    if (text == '\n' || text == '\t' || (_inputBuffers[appName]?.length ?? 0) >= 120) {
      _flushBufferForApp(appName, windowTitle, timestamp);
    } else {
      _scheduleBufferFlush(appName, windowTitle, timestamp);
    }
  }

  void _scheduleBufferFlush(String appName, String windowTitle, int timestamp) {
    _flushTimer?.cancel();
    _flushTimer = Timer(const Duration(seconds: 2), () {
      _flushBufferForApp(appName, windowTitle, timestamp);
    });
  }

  Future<void> _flushBufferForApp(String appName, String windowTitle, int timestamp) async {
    final textToSave = _inputBuffers[appName]?.trim();
    _inputBuffers.remove(appName);

    if (textToSave != null && textToSave.isNotEmpty) {
      final entry = HistoryEntry(
        id: '${timestamp}_${appName.hashCode}',
        text: textToSave,
        sourceApp: appName,
        capturedAt: DateTime.fromMillisecondsSinceEpoch(timestamp),
        language: 'en',
        wasTranslated: false,
        deviceId: 'windows_native',
      );
      await _repository.addEntry(entry);

      // Fire-and-forget cloud sync — failures are queued for retry
      // inside SyncService and never block local capture.
      unawaited(_syncService?.syncEntry(entry));
    }
  }

  Future<void> _flushAllBuffers() async {
    final keys = List<String>.from(_inputBuffers.keys);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    for (final appName in keys) {
      await _flushBufferForApp(appName, '', nowMs);
    }
  }

  Future<dynamic> _handleNativeMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onPauseChanged':
        _isPaused = (call.arguments as bool?) ?? false;
        break;
      case 'onNavigate':
        final route = call.arguments?.toString();
        if (route != null && onNavigate != null) {
          onNavigate!(route);
        }
        break;
    }
  }

  void dispose() {
    _subscription?.cancel();
    _flushTimer?.cancel();
  }
}
