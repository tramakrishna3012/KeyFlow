import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';

/// Information model representing the auto-update check result.
class UpdateInfo {
  const UpdateInfo({
    required this.hasUpdate,
    required this.latestVersion,
    required this.currentVersion,
    required this.downloadUrl,
    required this.releaseNotes,
  });

  final bool hasUpdate;
  final String latestVersion;
  final String currentVersion;
  final String downloadUrl;
  final String releaseNotes;
}

/// Service that checks the Express backend & GitHub Releases API for updates,
/// downloads APK files to internal storage, and triggers the Android system package installer.
class AutoUpdateService {
  AutoUpdateService({
    String? apiBase,
    http.Client? client,
  })  : _apiBase = apiBase ?? 'https://keyflow-dnsd.onrender.com/api/v1',
        _client = client ?? http.Client();

  final String _apiBase;
  final http.Client _client;
  static const MethodChannel _platformChannel = MethodChannel('keyflow/capture');

  static const String _repoOwner = 'tramakrishna3012';
  static const String _repoName = 'KeyFlow';

  /// Checks the KeyFlow Express backend (with GitHub fallback) for a newer version.
  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // 1. Try KeyFlow Express backend version endpoint
      try {
        final url = Uri.parse('$_apiBase/app/version');
        final response = await _client.get(url).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = jsonDecode(response.body);
          final latestVersion = (data['latestVersion'] ?? '').toString().replaceAll('v', '').trim();
          final downloadUrl = (data['downloadUrl'] ?? '').toString();
          final releaseNotes = (data['releaseNotes'] ?? 'Bug fixes and performance improvements.').toString();

          final hasUpdate = _isVersionNewer(latestVersion, currentVersion);

          return UpdateInfo(
            hasUpdate: hasUpdate,
            latestVersion: latestVersion,
            currentVersion: currentVersion,
            downloadUrl: downloadUrl,
            releaseNotes: releaseNotes,
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
        final body = data['body']?.toString() ?? 'Bug fixes and performance improvements.';
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

        final hasUpdate = _isVersionNewer(latestVersion, currentVersion);

        return UpdateInfo(
          hasUpdate: hasUpdate,
          latestVersion: latestVersion,
          currentVersion: currentVersion,
          downloadUrl: downloadUrl,
          releaseNotes: body,
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
            content: Text(
              'KeyFlow is up to date (v${update.currentVersion}).',
            ),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.system_update_alt_rounded, color: AppColors.primary),
              const SizedBox(width: 10),
              Text(
                'Update Available (v${update.latestVersion})',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current version: v${update.currentVersion}',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
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
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    progress > 0
                        ? 'Downloading: ${(progress * 100).toInt()}%'
                        : 'Preparing download...',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ),
              ],
            ],
          ),
          actions: isDownloading
              ? []
              : [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
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
                            content: Text('Could not complete in-app install. Opening download link.'),
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

  bool _isVersionNewer(String remote, String local) {
    try {
      final remoteParts = remote
          .split('+')[0]
          .split('.')
          .map(int.parse)
          .toList();
      final localParts = local.split('+')[0].split('.').map(int.parse).toList();

      for (var i = 0; i < remoteParts.length && i < localParts.length; i++) {
        if (remoteParts[i] > localParts[i]) return true;
        if (remoteParts[i] < localParts[i]) return false;
      }
      return remoteParts.length > localParts.length;
    } on Object catch (_) {
      return remote != local;
    }
  }
}
