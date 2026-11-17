import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keyflow_app/core/services/device_info_service.dart';

/// Builds a [DeviceInfoPlugin] pre-seeded with mock device data via the
/// package's own `setMockInitialValues` test helpers, so these tests prove
/// [DeviceInfoService] reports the real (mocked) device info instead of a
/// hardcoded literal — with no platform channel involved.
DeviceInfoPlugin _pluginWithAndroid({
  required String model,
  required String release,
}) => DeviceInfoPlugin.setMockInitialValues(
  androidDeviceInfo: AndroidDeviceInfo.setMockInitialValues(
    version: AndroidBuildVersion.setMockInitialValues(
      codename: 'REL',
      incremental: '1',
      previewSdkInt: 0,
      release: release,
      sdkInt: 34,
    ),
    board: 'board',
    bootloader: 'bootloader',
    brand: 'brand',
    device: 'device',
    display: 'display',
    fingerprint: 'fingerprint',
    hardware: 'hardware',
    host: 'host',
    id: 'id',
    manufacturer: 'manufacturer',
    model: model,
    product: 'product',
    name: 'name',
    supported32BitAbis: const [],
    supported64BitAbis: const [],
    supportedAbis: const [],
    tags: 'tags',
    type: 'type',
    isPhysicalDevice: true,
    freeDiskSize: 0,
    totalDiskSize: 0,
    systemFeatures: const [],
    isLowRamDevice: false,
    physicalRamSize: 0,
    availableRamSize: 0,
  ),
);

DeviceInfoPlugin _pluginWithIos({
  required String modelName,
  required String systemVersion,
}) => DeviceInfoPlugin.setMockInitialValues(
  iosDeviceInfo: IosDeviceInfo.setMockInitialValues(
    name: 'name',
    systemName: 'iOS',
    systemVersion: systemVersion,
    model: 'model',
    modelName: modelName,
    localizedModel: 'localizedModel',
    freeDiskSize: 0,
    totalDiskSize: 0,
    isPhysicalDevice: true,
    isiOSAppOnMac: false,
    isiOSAppOnVision: false,
    physicalRamSize: 0,
    availableRamSize: 0,
    utsname: IosUtsname.setMockInitialValues(
      sysname: 'sysname',
      nodename: 'nodename',
      release: 'release',
      version: 'version',
      machine: 'machine',
    ),
  ),
);

void main() {
  group('DeviceInfoService', () {
    final originalPlatform = debugDefaultTargetPlatformOverride;

    tearDown(() {
      debugDefaultTargetPlatformOverride = originalPlatform;
    });

    test('reads the real Android model and OS version instead of a hardcoded '
        'device name', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final service = DeviceInfoService(
        plugin: _pluginWithAndroid(model: 'Pixel 9', release: '16'),
      );

      expect(await service.getDeviceName(), 'Pixel 9');
      expect(await service.getOsInfo(), 'Android 16');
    });

    test('reads the real iPhone model name and OS version instead of a '
        'hardcoded device name', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final service = DeviceInfoService(
        plugin: _pluginWithIos(
          modelName: 'iPhone 16 Pro',
          systemVersion: '18.1',
        ),
      );

      expect(await service.getDeviceName(), 'iPhone 16 Pro');
      expect(await service.getOsInfo(), 'iOS 18.1');
    });

    test(
      'caches the resolved values instead of re-reading the platform channel',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        final service = DeviceInfoService(
          plugin: _pluginWithAndroid(model: 'Pixel 9', release: '16'),
        );

        final first = await service.getDeviceName();
        final second = await service.getDeviceName();

        expect(first, same(second));
      },
    );

    test('falls back to a generic, honest label (never a fabricated model '
        'name) when the real device model string is empty', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final service = DeviceInfoService(
        plugin: _pluginWithAndroid(model: '', release: ''),
      );

      expect(await service.getDeviceName(), 'Android device');
      expect(await service.getOsInfo(), 'Android');
    });
  });
}
