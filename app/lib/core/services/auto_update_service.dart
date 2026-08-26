import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';

/// Storage key for persisting the user-dismissed update version.
const String kDismissedUpdateVersionKey = 'dismissed_update_version';

/// Information model representing the auto-update check result.
class UpdateInfo {
  const UpdateInfo({
    required this.hasUpdate,
    required this.latestVersion,
    required this.currentVersion,
    required this.downloadUrl,
    required this.releaseNotes,
    this.isDismissed = false,
  });

  final bool hasUpdate;
  final String latestVersion;
  final String currentVersion;
  final String downloadUrl;
  final String releaseNotes;
  final bool isDismissed;
}

/// Service that checks the Express backend & GitHub Releases API for updates,
/// downloads APK files to internal storage, and triggers the Android system package installer.
class AutoUpdateService {
  AutoUpdateService({
    String? apiBase,
    http.Client? client,
    FlutterSecureStorage? storage,
  }) : _apiBase = apiBase ?? 'https://keyflow-dnsd.onrender.com/api/v1',
       _client = client ?? http.Client(),
       _storage =
           storage ??
           const FlutterSecureStorage(
             aOptions: AndroidOptions(encryptedSharedPreferences: true),
             iOptions: IOSOptions(
               accessibility: KeychainAccessibility.first_unlock,
             ),
           );

  final String _apiBase;
  final http.Client _client;
  final FlutterSecureStorage _storage;

  static const MethodChannel _platformChannel = MethodChannel(
    'keyflow/capture',
  );

  static const String _repoOwner = 'tramakrishna3012';
  static const String _repoName = 'KeyFlow';

  /// Process-level flag ensuring the automatic update prompt is only triggered once per process run.
  static bool hasCheckedThisProcess = false;

  /// In-memory cache of dismissed version for the current active session.
  static String? _dismissedVersionThisSession;

  /// Persists a version dismissal so it won't pop up again on subsequent launches.
  Future<void> dismissUpdate(String version) async {
    _dismissedVersionThisSession = version;
    try {
      await _storage.write(key: kDismissedUpdateVersionKey, value: version);
    } on Object catch (e) {
      debugPrint('AutoUpdateService: Failed to persist update dismissal: $e');
    }
  }

  /// Checks if a version has been dismissed by the user either in-memory or in persistent storage.
  Future<bool> isUpdateDismissed(String version) async {
    if (_dismissedVersionThisSession == version) return true;
    try {
      final saved = await _storage.read(key: kDismissedUpdateVersionKey);
      return saved == version;
    } on Object catch (_) {
      return false;
    }
  }

  /// Checks the KeyFlow Express backend (with GitHub fallback) for a newer version.
  Future<UpdateInfo?> checkForUpdate({bool isManualCheck = false}) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuild = packageInfo.buildNumber;
      final fullLocalVersion = currentBuild.isNotEmpty
          ? '$currentVersion+$currentBuild'
          : currentVersion;

      // 1. Try KeyFlow Express backend version endpoint
      try {
        final url = Uri.parse('$_apiBase/app/version');
        final response = await _client
            .get(url)
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = jsonDecode(response.body);
          final latestVersion = (data['latestVersion'] ?? '')
              .toString()
              .replaceAll('v', '')
              .trim();
          final versionCode = data['versionCode'];
          final fullRemoteVersion = versionCode != null
              ? '$latestVersion+$versionCode'
              : latestVersion;

          final downloadUrl = (data['downloadUrl'] ?? '').toString();
          final releaseNotes =
              (data['releaseNotes'] ??
                      'Bug fixes and performance improvements.')
                  .toString();

          final isNewer = isVersionNewer(fullRemoteVersion, fullLocalVersion);
          final isDismissed = await isUpdateDismissed(latestVersion);
          final hasUpdate = isNewer && (isManualCheck || !isDismissed);

          return UpdateInfo(
            hasUpdate: hasUpdate,
            latestVersion: latestVersion,
            currentVersion: currentVersion,
            downloadUrl: downloadUrl,
            releaseNotes: releaseNotes,
            isDismissed: isDismissed,
          );
        }
      } on Object catch (e) {
        debugPrint('Backend version check skipped/error: $e');
      }

      // 2. Fallback to GitHub Releases API
      final ghUrl = Uri.parse(
        'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest',
      );

      final ghResponse = await _client
          .get(ghUrl, headers: {'Accept': 'application/vnd.github.v3+json'})
          .timeout(const Duration(seconds: 4));

      if (ghResponse.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(ghResponse.body);
        final tagName = data['tag_name']?.toString() ?? '';
        final body =
            data['body']?.toString() ??
            'Bug fixes and performance improvements.';
        final latestVersion = tagName.replaceAll('v', '').trim();

        var downloadUrl =
            'https://github.com/$_repoOwner/$_repoName/releases/latest/download/app-arm64-v8a-release.apk';
        final assets = data['assets'] as List<dynamic>?;
        if (assets != null && assets.isNotEmpty) {
          final apkAsset = assets.firstWhere(
            (a) => a['name'].toString().endsWith('.apk'),
            orElse: () => assets.first,
          );
          if (apkAsset != null && apkAsset['browser_download_url'] != null) {
            downloadUrl = apkAsset['browser_download_url'].toString();
          }
        }

        final isNewer = isVersionNewer(latestVersion, fullLocalVersion);
        final isDismissed = await isUpdateDismissed(latestVersion);
        final hasUpdate = isNewer && (isManualCheck || !isDismissed);

        return UpdateInfo(
          hasUpdate: hasUpdate,
          latestVersion: latestVersion,
          currentVersion: currentVersion,
          downloadUrl: downloadUrl,
          releaseNotes: body,
          isDismissed: isDismissed,
        );
      }
    } on Object catch (e) {
      debugPrint('AutoUpdateService check failed: $e');
    }
    return null;
  }

  /// Downloads the release APK into app internal cache and launches the system installer via FileProvider.
  Future<bool> downloadAndInstallApk(
    String downloadUrl, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      if (!Platform.isAndroid) {
        return launchDownloadUrl(downloadUrl);
      }

      final uri = Uri.parse(downloadUrl);
      final request = http.Request('GET', uri);
      final response = await _client.send(request);

      if (response.statusCode != 200) {
        debugPrint('Download failed with status: ${response.statusCode}');
        return launchDownloadUrl(downloadUrl);
      }

      final tempDir = await getTemporaryDirectory();
      final apkFile = File('${tempDir.path}/keyflow_update.apk');
      if (apkFile.existsSync()) {
        apkFile.deleteSync();
      }

      final totalBytes = response.contentLength ?? 0;
      var receivedBytes = 0;
      final sink = apkFile.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0 && onProgress != null) {
          onProgress(receivedBytes / totalBytes);
        }
      }
      await sink.close();

      // Trigger native package installer via FileProvider
      final bool result = await _platformChannel.invokeMethod('installApk', {
        'filePath': apkFile.path,
      });

      return result;
    } on Object catch (e) {
      debugPrint('downloadAndInstallApk error: $e');
      return launchDownloadUrl(downloadUrl);
    }
  }

  /// Launch the direct download URL in external browser.
  Future<bool> launchDownloadUrl(String urlStr) async {
    final uri = Uri.parse(urlStr);
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// Shows an in-app update prompt dialog.
  Future<void> showUpdatePrompt(
    BuildContext context,
    UpdateInfo update, {
    bool isManualCheck = false,
  }) async {
    if (!update.hasUpdate) {
      if (isManualCheck && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('KeyFlow is up to date (v${update.currentVersion}).'),
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;

    var progress = 0.0;
    var isDownloading = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.system_update_alt_rounded,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              Text(
                'Update Available (v${update.latestVersion})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current version: v${update.currentVersion}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Release Notes:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Container(
                constraints: const BoxConstraints(maxHeight: 120),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.elevatedSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    update.releaseNotes,
                    style: const TextStyle(fontSize: 12, height: 1.4),
                  ),
                ),
              ),
              if (isDownloading) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: progress > 0 ? progress : null,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    progress > 0
                        ? 'Downloading: ${(progress * 100).toInt()}%'
                        : 'Preparing download...',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: isDownloading
              ? []
              : [
                  TextButton(
                    onPressed: () async {
                      await dismissUpdate(update.latestVersion);
                      if (dialogCtx.mounted) {
                        Navigator.of(dialogCtx).pop();
                      }
                    },
                    child: const Text('Later'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      setDialogState(() {
                        isDownloading = true;
                      });

                      final success = await downloadAndInstallApk(
                        update.downloadUrl,
                        onProgress: (p) {
                          setDialogState(() {
                            progress = p;
                          });
                        },
                      );

                      if (dialogCtx.mounted) {
                        Navigator.of(dialogCtx).pop();
                      }

                      if (!success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Could not complete in-app install. Opening download link.',
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text('Download & Install'),
                  ),
                ],
        ),
      ),
    );
  }

  /// Robust semantic version comparison.
  /// Returns `true` if [remote] is strictly newer than [local].
  ///
  /// Correctly compares numeric SemVer segments:
  /// - `1.10.0` is newer than `1.2.0` (numeric comparison, not string comparison)
  /// - `1.0.0` vs `1.0` (pads missing components with 0)
  /// - `1.0.0+7` vs `1.0.0+6` (compares build numbers if semantic versions match)
  /// - Returns `false` on identical versions or parsing errors (no false positives).
  static bool isVersionNewer(String remote, String local) {
    try {
      final cleanRemote = remote.trim().replaceFirst(RegExp('^[vV]'), '');
      final cleanLocal = local.trim().replaceFirst(RegExp('^[vV]'), '');

      if (cleanRemote.isEmpty || cleanLocal.isEmpty) return false;

      // Extract core version without build or pre-release tags
      final remoteCore = cleanRemote.split('+')[0].split('-')[0].trim();
      final localCore = cleanLocal.split('+')[0].split('-')[0].trim();

      final remoteParts = remoteCore
          .split('.')
          .map((s) => int.tryParse(s.trim()) ?? 0)
          .toList();
      final localParts = localCore
          .split('.')
          .map((s) => int.tryParse(s.trim()) ?? 0)
          .toList();

      // Pad to at least 3 parts (major, minor, patch)
      while (remoteParts.length < 3) {
        remoteParts.add(0);
      }
      while (localParts.length < 3) {
        localParts.add(0);
      }

      final maxLen = remoteParts.length > localParts.length
          ? remoteParts.length
          : localParts.length;

      for (var i = 0; i < maxLen; i++) {
        final r = i < remoteParts.length ? remoteParts[i] : 0;
        final l = i < localParts.length ? localParts[i] : 0;
        if (r > l) return true;
        if (r < l) return false;
      }

      // If core versions match, check build metadata if present (e.g. 1.0.0+7 vs 1.0.0+6)
      final remoteBuild = _extractBuildNumber(cleanRemote);
      final localBuild = _extractBuildNumber(cleanLocal);
      if (remoteBuild != null && localBuild != null) {
        return remoteBuild > localBuild;
      }

      return false;
    } on Object catch (_) {
      return false;
    }
  }

  static int? _extractBuildNumber(String versionStr) {
    if (versionStr.contains('+')) {
      final parts = versionStr.split('+');
      if (parts.length > 1) {
        return int.tryParse(parts[1].trim());
      }
    }
    return null;
  }
}
