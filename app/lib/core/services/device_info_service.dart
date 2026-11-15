import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Reads the real device model and OS version from the platform, so every
/// place that reports "which device" a snippet came from (the web dashboard,
/// the Manage Sessions screen) shows the device that actually captured it
/// instead of a hardcoded placeholder string.
///
/// Each value is fetched once and cached for the lifetime of the app — the
/// physical device and its OS version never change mid-session, and this
/// avoids repeated platform-channel round-trips.
class DeviceInfoService {
  DeviceInfoService({DeviceInfoPlugin? plugin})
    : _plugin = plugin ?? DeviceInfoPlugin();

  final DeviceInfoPlugin _plugin;

  String? _cachedDeviceName;
  String? _cachedOsInfo;

  /// The real device model, e.g. "Pixel 8" or "iPhone 16 Pro".
  ///
  /// Falls back to a generic, honest label (never a fabricated model name)
  /// if the platform channel is unavailable — e.g. in a test environment
  /// with no device_info_plus mock set up, or on an unsupported platform.
  Future<String> getDeviceName() async {
    final cached = _cachedDeviceName;
    if (cached != null) return cached;
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final info = await _plugin.iosInfo;
        final name = info.modelName.trim();
        return _cachedDeviceName = name.isNotEmpty ? name : 'iPhone';
      }
      final info = await _plugin.androidInfo;
      final name = info.model.trim();
      return _cachedDeviceName = name.isNotEmpty ? name : 'Android device';
    } on Object catch (e) {
      debugPrint('DeviceInfoService getDeviceName error: $e');
      return defaultTargetPlatform == TargetPlatform.iOS
          ? 'iPhone'
          : 'Android device';
    }
  }

  /// The real OS name and version, e.g. "Android 15" or "iOS 18.1".
  Future<String> getOsInfo() async {
    final cached = _cachedOsInfo;
    if (cached != null) return cached;
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final info = await _plugin.iosInfo;
        final version = info.systemVersion.trim();
        return _cachedOsInfo = version.isEmpty
            ? info.systemName
            : '${info.systemName} $version';
      }
      final info = await _plugin.androidInfo;
      final release = info.version.release.trim();
      return _cachedOsInfo = release.isEmpty ? 'Android' : 'Android $release';
    } on Object catch (e) {
      debugPrint('DeviceInfoService getOsInfo error: $e');
      return defaultTargetPlatform == TargetPlatform.iOS ? 'iOS' : 'Android';
    }
  }
}

/// Shared instance used across the app so the platform channel is only hit
/// once overall, not once per service that needs device info.
final sharedDeviceInfoService = DeviceInfoService();
