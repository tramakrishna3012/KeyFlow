import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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

/// Service that checks GitHub Releases API for automated app updates (free deployment hosting).
class AutoUpdateService {
  AutoUpdateService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _repoOwner = 'tramakrishna3012';
  static const String _repoName = 'KeyFlow';

  /// Checks GitHub Releases API for a newer version of KeyFlow.
  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final url = Uri.parse(
        'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest',
      );

      final response = await _client
          .get(url, headers: {'Accept': 'application/vnd.github.v3+json'})
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final tagName = data['tag_name']?.toString() ?? '';
        final body =
            data['body']?.toString() ??
            'Bug fixes and performance improvements.';

        // Clean version strings for comparison
        final latestVersion = tagName.replaceAll('v', '').trim();

        // Direct APK download URL from GitHub Release assets
        var downloadUrl =
            'https://github.com/$_repoOwner/$_repoName/releases/latest/download/KeyFlow.apk';
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

  /// Launch the direct download URL in the browser / system handler.
  Future<bool> launchDownloadUrl(String urlStr) async {
    final uri = Uri.parse(urlStr);
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
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
