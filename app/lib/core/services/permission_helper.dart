import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Requests camera, storage, and notification permissions at app startup.
///
/// Only executes on Android and iOS — desktop platforms do not use the
/// [permission_handler] runtime permission flow.
///
/// Returns a map of each requested [Permission] to its resulting
/// [PermissionStatus] so callers can react (e.g. show rationale dialogs).
Future<Map<Permission, PermissionStatus>> requestStartupPermissions() async {
  // permission_handler targets mobile only; skip on desktop / web.
  if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
    return {};
  }

  final statuses = await [
    Permission.camera,
    Permission.storage,
    Permission.notification,
  ].request();

  return statuses;
}
