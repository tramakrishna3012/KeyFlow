import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../data/history_repository.dart';
import '../../data/models/history_entry.dart';
import '../../data/sync_service.dart';

class CaptureService {
  CaptureService(this._repository, {this._syncService}) {
    _methodChannel.setMethodCallHandler(_handleNativeMethodCall);
  }

  static const MethodChannel _methodChannel = MethodChannel('keyflow/capture');
  static const EventChannel _eventChannel = EventChannel('keyflow/capture/stream');

  final HistoryRepository _repository;
  final SyncService? _syncService;
  StreamSubscription<dynamic>? _subscription;

  bool _isCapturing = false;
  bool get isCapturing => _isCapturing;

  bool _isPaused = false;
  bool get isPaused => _isPaused;

  final Map<String, String> _inputBuffers = {};

  Future<void> initialize() async {
    final exclusions = await _repository.getExclusionList();
    await syncExclusionList(exclusions);
    await startCapture();
  }

  Future<bool> startCapture() async {
    if (_isCapturing) return true;
    try {
      final result = await _methodChannel.invokeMethod('startCapture');
      _subscription = _eventChannel.receiveBroadcastStream().listen(
            _onNativeEvent,
            onError: (error) => debugPrint('CaptureService stream error: $error'),
          );
      _isCapturing = true;
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

  Future<bool> pauseCapture() async {
    try {
      final result = await _methodChannel.invokeMethod('pauseCapture');
      _isPaused = true;
      return result == true || true;
    } on PlatformException catch (e) {
      debugPrint('CaptureService pauseCapture error: ${e.message}');
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
      return false;
    }
  }

  Future<bool> isAccessibilityServiceEnabled() async {
    try {
      final bool enabled = await _methodChannel.invokeMethod('isAccessibilityServiceEnabled');
      return enabled;
    } on PlatformException catch (_) {
      return false;
    }
  }

  Future<void> openAccessibilitySettings() async {
    try {
      await _methodChannel.invokeMethod('openAccessibilitySettings');
    } on PlatformException catch (e) {
      debugPrint('CaptureService openAccessibilitySettings error: ${e.message}');
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
    _subscription?.cancel();
    _subscription = null;
  }

  void _onNativeEvent(dynamic event) {
    if (event is! Map) return;

    final appName = (event['appName'] as String?) ?? 'Unknown App';
    final windowTitle = (event['windowTitle'] as String?) ?? '';
    final text = (event['text'] as String?) ?? '';
    final timestamp = (event['timestamp'] as int?) ?? DateTime.now().millisecondsSinceEpoch;

    if (text.isNotEmpty) {
      _inputBuffers[appName] = text;
      _flushBufferForApp(appName, windowTitle, timestamp);
    }
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
        deviceId: 'mobile_native',
      );
      await _repository.addEntry(entry);
      unawaited(_syncService?.syncEntry(entry));
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

