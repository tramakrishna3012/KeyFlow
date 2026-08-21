import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../theme/app_colors.dart';

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

/// Checks if any permissions were denied and shows a non-blocking graceful
/// degradation notice informing the user of degraded features without halting the app.
void handlePermissionDegradation(
  BuildContext context,
  Map<Permission, PermissionStatus> statuses,
) {
  final denied = <String>[];
  if (statuses[Permission.notification]?.isDenied == true ||
      statuses[Permission.notification]?.isPermanentlyDenied == true) {
    denied.add('Notifications (sync alerts)');
  }
  if (statuses[Permission.camera]?.isDenied == true ||
      statuses[Permission.camera]?.isPermanentlyDenied == true) {
    denied.add('Camera (OCR scanning)');
  }
  if (statuses[Permission.storage]?.isDenied == true ||
      statuses[Permission.storage]?.isPermanentlyDenied == true) {
    denied.add('Storage (export/backup)');
  }

  if (denied.isNotEmpty && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.elevatedSurface,
        content: Text(
          'Operating in graceful mode: ${denied.join(", ")} disabled.',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        action: const SnackBarAction(
          label: 'Settings',
          textColor: AppColors.primary,
          onPressed: openAppSettings,
        ),
      ),
    );
  }
}

