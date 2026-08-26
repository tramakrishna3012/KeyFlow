import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keyflow_app/core/services/auto_update_service.dart';

void main() {
  group('AutoUpdateService Semantic Version Comparison (SemVer)', () {
    test('Correctly compares numeric minor versions (1.10.0 is newer than 1.2.0)', () {
      expect(AutoUpdateService.isVersionNewer('1.10.0', '1.2.0'), isTrue);
      expect(AutoUpdateService.isVersionNewer('1.2.0', '1.10.0'), isFalse);
    });

    test('Correctly compares major versions (1.0.0 is newer than 0.1.5)', () {
      expect(AutoUpdateService.isVersionNewer('1.0.0', '0.1.5'), isTrue);
      expect(AutoUpdateService.isVersionNewer('0.1.5', '1.0.0'), isFalse);
    });

    test('Identifies identical versions as not newer', () {
      expect(AutoUpdateService.isVersionNewer('1.0.0', '1.0.0'), isFalse);
      expect(AutoUpdateService.isVersionNewer('v1.0.0', '1.0.0'), isFalse);
      expect(AutoUpdateService.isVersionNewer('1.0.0', 'v1.0.0'), isFalse);
    });

    test('Handles missing minor/patch segments by zero padding', () {
      expect(AutoUpdateService.isVersionNewer('1.0', '1.0.0'), isFalse);
      expect(AutoUpdateService.isVersionNewer('1.0.0', '1.0'), isFalse);
      expect(AutoUpdateService.isVersionNewer('1.0.1', '1.0'), isTrue);
      expect(AutoUpdateService.isVersionNewer('1.1', '1.0.5'), isTrue);
    });

    test('Correctly compares build metadata when SemVer is identical', () {
      expect(AutoUpdateService.isVersionNewer('1.0.0+7', '1.0.0+6'), isTrue);
      expect(AutoUpdateService.isVersionNewer('1.0.0+6', '1.0.0+6'), isFalse);
      expect(AutoUpdateService.isVersionNewer('1.0.0+5', '1.0.0+6'), isFalse);
    });

    test('Handles pre-release tags cleanly', () {
      expect(AutoUpdateService.isVersionNewer('1.0.1-beta.1', '1.0.0'), isTrue);
      expect(AutoUpdateService.isVersionNewer('1.0.0-beta.1', '1.0.0'), isFalse);
    });

    test('Handles malformed or empty strings safely without throwing or false positives', () {
      expect(AutoUpdateService.isVersionNewer('', '1.0.0'), isFalse);
      expect(AutoUpdateService.isVersionNewer('1.0.0', ''), isFalse);
      expect(AutoUpdateService.isVersionNewer('invalid_version', '1.0.0'), isFalse);
    });
  });

  group('AutoUpdateService Dismissal Persistence', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('Dismissing a version persists and suppresses automatic prompt for that version', () async {
      const storage = FlutterSecureStorage();
      final service = AutoUpdateService(storage: storage);

      expect(await service.isUpdateDismissed('1.0.0'), isFalse);

      await service.dismissUpdate('1.0.0');

      expect(await service.isUpdateDismissed('1.0.0'), isTrue);
      // Genuinely newer version should not be suppressed
      expect(await service.isUpdateDismissed('1.0.1'), isFalse);
    });
  });
}
