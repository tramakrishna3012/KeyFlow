import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../data/history_repository.dart';
import '../../data/models/history_entry.dart';
import '../../data/sync_service.dart';
import '../look_monitor/look_window_sanitizer.dart';
import '../settings/models/installed_app_info.dart';

class CaptureService {
  CaptureService(
    this._repository, {
    SyncService? syncService,
    SyncService? Function()? syncServiceGetter,
    LookWindowSanitizer? sanitizer,
    this.onEntryCaptured,
  }) : _syncService = syncService,
       _syncServiceGetter = syncServiceGetter,
       _sanitizer = sanitizer ?? const LookWindowSanitizer() {
    _methodChannel.setMethodCallHandler(_handleNativeMethodCall);
  }

  static const MethodChannel _methodChannel = MethodChannel('keyflow/capture');
  static const EventChannel _eventChannel = EventChannel(
    'keyflow/capture/stream',
  );

  final HistoryRepository _repository;
  final SyncService? _syncService;
  final SyncService? Function()? _syncServiceGetter;
  final LookWindowSanitizer _sanitizer;
  final void Function(HistoryEntry entry)? onEntryCaptured;
  StreamSubscription<dynamic>? _subscription;

  SyncService? get activeSyncService => _syncServiceGetter?.call() ?? _syncService;


  bool _isCapturing = false;
  bool get isCapturing => _isCapturing;

  bool _isPaused = false;
  bool get isPaused => _isPaused;

  final Map<String, String> _inputBuffers = {};
  final Map<String, Timer> _debounceTimers = {};
  final Map<String, String> _lastSavedTextPerApp = {};
  final Map<String, int> _lastSavedTimePerApp = {};

  Future<void> initialize() async {
    await startCapture();
    await _flushPendingNativeEvents();
    try {
      final exclusions = await _repository.getExclusionList();
      await syncExclusionList(exclusions);
    } on Exception catch (e) {
      debugPrint('Sync exclusions error: $e');
    }
  }

  Future<void> _flushPendingNativeEvents() async {
    try {
      final pending = await _methodChannel.invokeMethod<List<dynamic>>('getPendingEvents');
      if (pending != null && pending.isNotEmpty) {
        debugPrint('[CaptureService] Flushing ${pending.length} pending events from disk buffer');
        for (final item in pending) {
          if (item is Map) {
            _onNativeEvent(item);
          }
        }
      }
    } on PlatformException catch (e) {
      debugPrint('CaptureService _flushPendingNativeEvents error: ${e.message}');
    }
  }

  Future<bool> isBatteryOptimizationIgnored() async {
    try {
      final ignored = await _methodChannel.invokeMethod<bool>('isBatteryOptimizationIgnored');
      return ignored ?? true;
    } on PlatformException catch (_) {
      return true;
    }
  }

  Future<void> requestIgnoreBatteryOptimizations() async {
    try {
      await _methodChannel.invokeMethod('requestIgnoreBatteryOptimizations');
    } on PlatformException catch (e) {
      debugPrint('CaptureService requestIgnoreBatteryOptimizations error: ${e.message}');
    }
  }

  Future<bool> startCapture() async {
    if (_isCapturing) {
      await _flushPendingNativeEvents();
      return true;
    }
    try {
      final result = await _methodChannel.invokeMethod('startCapture');
      _subscription = _eventChannel.receiveBroadcastStream().listen(
        _onNativeEvent,
        onError: (error) => debugPrint('CaptureService stream error: $error'),
      );
      _isCapturing = true;
      await _flushPendingNativeEvents();
      return result == true || true;
    } on PlatformException catch (e) {
      debugPrint('CaptureService startCapture error: ${e.message}');
      return false;
    }
  }


  Future<bool> stopCapture() async {
    if (!_isCapturing) return true;
    try {
      for (final timer in _debounceTimers.values) {
        timer.cancel();
      }
      _debounceTimers.clear();
      final result = await _methodChannel.invokeMethod('stopCapture');
      await _subscription?.cancel();
      _subscription = null;
      _isCapturing = false;
      return result == true || true;
    } on PlatformException catch (e) {
      debugPrint('CaptureService stopCapture error: ${e.message}');
      return false;
    }
  }

  Future<bool> isCapturePaused() async {
    try {
      final paused = await _methodChannel.invokeMethod<bool>('isCapturePaused');
      if (paused != null) {
        _isPaused = paused;
      }
      return _isPaused;
    } on PlatformException catch (_) {
      return _isPaused;
    }
  }

  Future<bool> pauseCapture() async {
    try {
      final result = await _methodChannel.invokeMethod('pauseCapture');
      _isPaused = true;
      return result == true || true;
    } on PlatformException catch (e) {
      debugPrint('CaptureService pauseCapture error: ${e.message}');
      _isPaused = true;
      return false;
    }
  }

  Future<bool> resumeCapture() async {
    try {
      final result = await _methodChannel.invokeMethod('resumeCapture');
      _isPaused = false;
      return result == true || true;
    } on PlatformException catch (e) {
      debugPrint('CaptureService resumeCapture error: ${e.message}');
      _isPaused = false;
      return false;
    }
  }

  Future<bool> isAccessibilityServiceEnabled() async {
    try {
      final bool enabled = await _methodChannel.invokeMethod(
        'isAccessibilityServiceEnabled',
      );
      return enabled;
    } on PlatformException catch (_) {
      return false;
    }
  }

  Future<void> openAccessibilitySettings() async {
    try {
      await _methodChannel.invokeMethod('openAccessibilitySettings');
    } on PlatformException catch (e) {
      debugPrint(
        'CaptureService openAccessibilitySettings error: ${e.message}',
      );
    }
  }

  Future<bool> canDrawOverlays() async {
    try {
      final allowed = await _methodChannel.invokeMethod<bool>(
        'canDrawOverlays',
      );
      return allowed ?? false;
    } on PlatformException catch (e) {
      debugPrint('CaptureService canDrawOverlays error: ${e.message}');
      return false;
    }
  }

  Future<void> requestOverlayPermission() async {
    try {
      await _methodChannel.invokeMethod('requestOverlayPermission');
    } on PlatformException catch (e) {
      debugPrint('CaptureService requestOverlayPermission error: ${e.message}');
    }
  }

  Future<bool> showOverlayBubble() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'showOverlayBubble',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('CaptureService showOverlayBubble error: ${e.message}');
      return false;
    }
  }

  Future<bool> hideOverlayBubble() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'hideOverlayBubble',
      );
      return result ?? true;
    } on PlatformException catch (e) {
      debugPrint('CaptureService hideOverlayBubble error: ${e.message}');
      return false;
    }
  }

  Future<bool> isOverlayShowing() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'isOverlayShowing',
      );
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  Future<List<InstalledAppInfo>> getInstalledApps({
    bool includeSystem = false,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod<List<dynamic>>(
        'getInstalledApps',
        {'includeSystem': includeSystem},
      );
      if (result == null) return [];
      return result
          .map(
            (item) => InstalledAppInfo.fromMap(item as Map<dynamic, dynamic>),
          )
          .toList();
    } on PlatformException catch (e) {
      debugPrint('CaptureService getInstalledApps error: ${e.message}');
      return [];
    }
  }

  Future<void> setExclusionList(List<String> exclusions) async {
    try {
      await _methodChannel.invokeMethod('setExclusionList', exclusions);
    } on PlatformException catch (e) {
      debugPrint('CaptureService setExclusionList error: ${e.message}');
    }
  }

  Future<void> syncExclusionList(List<String> exclusions) async {
    await setExclusionList(exclusions);
  }

  Future<bool> setAutostart(bool enabled) async {
    try {
      final result = await _methodChannel.invokeMethod('setAutostart', enabled);
      return result ?? true;
    } on PlatformException catch (e) {
      debugPrint('CaptureService setAutostart error: ${e.message}');
      return false;
    }
  }

  Future<bool> isAutostartEnabled() async {
    try {
      final enabled = await _methodChannel.invokeMethod('isAutostartEnabled');
      return enabled ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  void dispose() {
    stopCapture();
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    _debounceTimers.clear();
    _subscription?.cancel();
    _subscription = null;
  }

  void _onNativeEvent(dynamic event) {
    debugPrint('[CaptureService] _onNativeEvent: $event');
    if (event is! Map) return;

    final appName = (event['appName'] as String?) ?? 'Unknown App';
    final windowTitle = (event['windowTitle'] as String?) ?? '';
    final text = (event['text'] as String?) ?? '';
    final timestamp =
        (event['timestamp'] as int?) ?? DateTime.now().millisecondsSinceEpoch;

    if (text.trim().isEmpty) return;

    // Buffer incoming text for this application
    _inputBuffers[appName] = text;

    // Debounce timer: wait 800ms for user typing burst before writing to database
    _debounceTimers[appName]?.cancel();
    _debounceTimers[appName] = Timer(const Duration(milliseconds: 800), () {
      _flushBufferForApp(appName, windowTitle, timestamp);
    });
  }

  Future<void> _flushBufferForApp(
    String appName,
    String windowTitle,
    int timestamp,
  ) async {
    _debounceTimers[appName]?.cancel();
    _debounceTimers.remove(appName);

    final rawText = _inputBuffers[appName]?.trim();
    _inputBuffers.remove(appName);

    if (rawText != null && rawText.isNotEmpty) {
      final sanitizedText = _sanitizer.sanitizeTextRecord(
        rawText,
        appName: appName,
      );

      // Do not store excluded or redacted sensitive records (passwords, OTPs, cards)
      if (sanitizedText.isEmpty ||
          sanitizedText == '[Excluded Content]' ||
          sanitizedText == '[Redacted Sensitive Record]') {
        return;
      }

      // Deduplication check: Do not save if identical text was saved for this app in last 10s
      final now = DateTime.now().millisecondsSinceEpoch;
      final lastSaved = _lastSavedTextPerApp[appName];
      final lastSavedTime = _lastSavedTimePerApp[appName] ?? 0;
      if (lastSaved == sanitizedText && (now - lastSavedTime) < 10000) {
        debugPrint(
          '[CaptureService] Skipping duplicate entry for $appName: $sanitizedText',
        );
        return;
      }

      _lastSavedTextPerApp[appName] = sanitizedText;
      _lastSavedTimePerApp[appName] = now;

      final entry = HistoryEntry(
        id: '${timestamp}_${appName.hashCode}',
        text: sanitizedText,
        sourceApp: appName,
        capturedAt: DateTime.fromMillisecondsSinceEpoch(timestamp),
        deviceId: 'mobile_native',
      );
      await _repository.addEntry(entry);
      onEntryCaptured?.call(entry);
      debugPrint('[CaptureService] Entry ${entry.id} added locally, triggering cloud sync (activeSyncService != null: ${activeSyncService != null})');
      unawaited(activeSyncService?.syncEntry(entry));
    }
  }



  Future<dynamic> _handleNativeMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onTextCaptured':
        _onNativeEvent(call.arguments);
        return true;
      default:
        throw MissingPluginException();
    }
  }
}
