import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../data/history_repository.dart';
import '../../data/models/history_entry.dart';
import '../../data/sync_service.dart';
import '../look_monitor/look_window_sanitizer.dart';
import '../settings/models/installed_app_info.dart';
import 'session_aggregator.dart';

class CaptureService {
  CaptureService(
    this._repository, {
    this.typingDebounceMs = 1000,
    this.syncService,
    this.syncServiceGetter,
    LookWindowSanitizer? sanitizer,
    this.onEntryCaptured,
  }) : _sanitizer = sanitizer ?? const LookWindowSanitizer() {
    _methodChannel.setMethodCallHandler(_handleNativeMethodCall);
    _sessionAggregator = DartSessionAggregator(
      onSessionUpdate: _onSessionAggregatorUpdate,
      onSessionFinalize: _onSessionAggregatorUpdate,
      inactivityDebounceMs: typingDebounceMs,
    );
  }

  static const MethodChannel _methodChannel = MethodChannel('keyflow/capture');
  static const EventChannel _eventChannel = EventChannel(
    'keyflow/capture/stream',
  );

  final HistoryRepository _repository;

  /// How long typing must pause before a draft is saved to history.
  final int typingDebounceMs;
  final SyncService? syncService;
  final SyncService? Function()? syncServiceGetter;
  final LookWindowSanitizer _sanitizer;
  final void Function(HistoryEntry entry)? onEntryCaptured;
  late final DartSessionAggregator _sessionAggregator;
  StreamSubscription<dynamic>? _subscription;

  SyncService? get activeSyncService =>
      syncServiceGetter?.call() ?? syncService;

  bool _isCapturing = false;
  bool get isCapturing => _isCapturing;

  bool _isPaused = false;
  bool get isPaused => _isPaused;

  final Map<String, String> _lastSavedTextPerApp = {};
  final Map<String, int> _lastSavedTimePerApp = {};

  // Local copy of the exclusion list so events are filtered on the Dart side too
  // (covers events buffered on disk before an app was excluded, and platforms
  // whose native engine has not received the list yet).
  Set<String> _exactExclusions = {};
  List<String> _keywordExclusions = [];

  /// Returns true when [appIdentifier] matches the user's exclusion list.
  /// Entries containing a dot are matched exactly (package / bundle id / exe);
  /// entries without a dot (e.g. "bank") match as a substring.
  bool isAppExcluded(String appIdentifier) {
    final id = appIdentifier.trim().toLowerCase();
    if (id.isEmpty) return false;
    if (_exactExclusions.contains(id)) return true;
    for (final keyword in _keywordExclusions) {
      if (id.contains(keyword)) return true;
    }
    return false;
  }

  void _applyLocalExclusions(List<String> exclusions) {
    final exact = <String>{};
    final keywords = <String>[];
    for (final raw in exclusions) {
      final entry = raw.trim().toLowerCase();
      if (entry.isEmpty) continue;
      if (entry.contains('.')) {
        exact.add(entry);
      } else {
        keywords.add(entry);
      }
    }
    _exactExclusions = exact;
    _keywordExclusions = keywords;
  }

  Future<void> initialize() async {
    // Load & push exclusions BEFORE capture starts so no excluded keystroke slips through.
    try {
      final exclusions = await _repository.getExclusionList();
      await syncExclusionList(exclusions);
    } on Exception catch (e) {
      debugPrint('Sync exclusions error: $e');
    }
    await startCapture();
  }

  /// Saves any in-progress typing immediately (e.g. when the app goes to background).
  void flushPendingTyping() {
    _sessionAggregator.finalizeAll();
  }

  Future<void> _flushPendingNativeEvents() async {
    try {
      final pending = await _methodChannel.invokeMethod<List<dynamic>>(
        'getPendingEvents',
      );
      if (pending != null && pending.isNotEmpty) {
        debugPrint(
          '[CaptureService] Flushing ${pending.length} pending events from disk buffer',
        );
        for (final item in pending) {
          if (item is Map) {
            _onNativeEvent(item);
          }
        }
      }
    } on PlatformException catch (e) {
      debugPrint(
        'CaptureService _flushPendingNativeEvents error: ${e.message}',
      );
    }
  }

  Future<bool> isBatteryOptimizationIgnored() async {
    try {
      final ignored = await _methodChannel.invokeMethod<bool>(
        'isBatteryOptimizationIgnored',
      );
      return ignored ?? true;
    } on PlatformException catch (_) {
      return true;
    }
  }

  Future<void> requestIgnoreBatteryOptimizations() async {
    try {
      await _methodChannel.invokeMethod('requestIgnoreBatteryOptimizations');
    } on PlatformException catch (e) {
      debugPrint(
        'CaptureService requestIgnoreBatteryOptimizations error: ${e.message}',
      );
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
    } on Object catch (_) {
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
    _applyLocalExclusions(exclusions);
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
    _sessionAggregator
      ..finalizeAll()
      ..dispose();
    _subscription?.cancel();
    _subscription = null;
  }

  void _onNativeEvent(dynamic event) {
    if (event is! Map) return;

    final appName = (event['appName'] as String?) ?? 'Unknown App';
    final windowTitle = (event['windowTitle'] as String?) ?? '';
    final text = (event['text'] as String?) ?? '';
    final timestamp =
        (event['timestamp'] as int?) ?? DateTime.now().millisecondsSinceEpoch;
    final isCopied = (event['isCopied'] as bool?) ?? (appName == 'Clipboard');
    final isPasswordField = (event['isPasswordField'] as bool?) ?? false;

    if (text.trim().isEmpty) return;

    // Drop anything coming from an excluded application.
    if (isAppExcluded(appName)) return;

    // For clipboard copied events, save immediately
    if (isCopied) {
      _saveDirectEntry(appName, text.trim(), timestamp);
      return;
    }

    // Pass to DartSessionAggregator with debouncing & 60s termination timeout
    _sessionAggregator.handleTypingInput(
      appName: appName,
      windowTitle: windowTitle,
      deviceName: 'Motorola Edge 40',
      text: text,
      isPasswordField: isPasswordField,
    );
  }

  Future<void> _onSessionAggregatorUpdate(
    AggregatedTypingSession session,
  ) async {
    // App may have been excluded while this session was still pending.
    if (isAppExcluded(session.appName)) return;

    final sanitizedText = _sanitizer.sanitizeTextRecord(
      session.content,
      appName: session.appName,
    );

    if (sanitizedText.isEmpty ||
        sanitizedText == '[Excluded Content]' ||
        sanitizedText == '[Redacted Sensitive Record]') {
      return;
    }

    final entry = HistoryEntry(
      id: session.id,
      text: sanitizedText,
      sourceApp: session.appName,
      capturedAt: DateTime.tryParse(session.updatedAt) ?? DateTime.now(),
      deviceId: session.deviceName,
    );

    await _repository.addEntry(entry);
    onEntryCaptured?.call(entry);
    debugPrint(
      '[CaptureService] Session ${session.id} updated (${session.characterCount} chars), triggering debounced cloud sync',
    );
    unawaited(activeSyncService?.syncEntry(entry));
  }

  Future<void> _saveDirectEntry(
    String appName,
    String rawText,
    int timestamp,
  ) async {
    final sanitizedText = _sanitizer.sanitizeTextRecord(
      rawText,
      appName: appName,
    );

    if (sanitizedText.isEmpty ||
        sanitizedText == '[Excluded Content]' ||
        sanitizedText == '[Redacted Sensitive Record]') {
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final lastSaved = _lastSavedTextPerApp[appName];
    final lastSavedTime = _lastSavedTimePerApp[appName] ?? 0;
    if (lastSaved == sanitizedText && (now - lastSavedTime) < 5000) {
      return;
    }

    _lastSavedTextPerApp[appName] = sanitizedText;
    _lastSavedTimePerApp[appName] = now;

    final entry = HistoryEntry(
      id: '${timestamp}_${appName.hashCode}',
      text: sanitizedText,
      sourceApp: appName,
      capturedAt: DateTime.fromMillisecondsSinceEpoch(timestamp),
      deviceId: 'Motorola Edge 40',
    );
    await _repository.addEntry(entry);
    onEntryCaptured?.call(entry);
    debugPrint(
      '[CaptureService] Copied entry ${entry.id} added locally, triggering cloud sync',
    );
    unawaited(activeSyncService?.syncEntry(entry));
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
