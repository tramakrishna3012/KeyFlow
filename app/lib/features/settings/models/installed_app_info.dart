import 'dart:typed_data';

class InstalledAppInfo {

  InstalledAppInfo({
    required this.appName,
    required this.packageName,
    this.appIcon,
    this.isSystemApp = false,
    this.isBankingApp = false,
  });

  factory InstalledAppInfo.fromMap(Map<dynamic, dynamic> map) => InstalledAppInfo(
      appName: (map['appName'] as String?) ?? 'Unknown App',
      packageName: (map['packageName'] as String?) ?? '',
      appIcon: map['appIcon'] as Uint8List?,
      isSystemApp: (map['isSystemApp'] as bool?) ?? false,
      isBankingApp: (map['isBankingApp'] as bool?) ?? false,
    );
  final String appName;
  final String packageName;
  final Uint8List? appIcon;
  final bool isSystemApp;
  final bool isBankingApp;
}
