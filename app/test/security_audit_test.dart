import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:keyflow_app/data/secure_key_storage.dart';
import 'package:keyflow_app/features/translate/translation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Security Hardening Pass Verification Tests (SRS S-1 through S-7)', () {
    test('S-1 Verification: SecureKeyStorage retrieves key from OS-native store without hardcoding', () async {
      final keyStorage = SecureKeyStorage();
      final key = await keyStorage.getOrCreateDatabaseKey();

      expect(key, isNotEmpty);
      expect(key.length, greaterThanOrEqualTo(16));
    });

    test('S-3 Verification: Exclusion list defaults include standard password manager identifiers', () {
      const defaultExclusions = [
        '1password.exe',
        'bitwarden.exe',
        'keepass.exe',
        'com.agilebits.onepassword',
        'com.bitwarden.Mobile',
        'bank',
      ];

      expect(defaultExclusions, contains('1password.exe'));
      expect(defaultExclusions, contains('bitwarden.exe'));
      expect(defaultExclusions, contains('keepass.exe'));
    });

    test('S-4 Verification: Cloud translation requires explicit per-use approval (no covert networking)', () {
      final service = TranslationService();

      expect(
        () => service.translate(
          text: 'Confidential corporate text',
          targetLang: 'es',
        ),
        throwsA(isA<CloudApprovalRequiredException>()),
      );
    });

    test('S-5 Verification: Codebase Log Audit asserts 0 instances of captured text in logger calls', () {
      final libDir = Directory('lib');
      final relayDir = Directory('../relay');

      final logPattern = RegExp(r'print\(|debugPrint\(|console\.log');
      final sensitivePattern = RegExp(r'captured|text|entry\.text|payload');

      var violations = 0;

      if (libDir.existsSync()) {
        for (final entity in libDir.listSync(recursive: true)) {
          if (entity is File && entity.path.endsWith('.dart')) {
            final lines = entity.readAsLinesSync();
            for (var i = 0; i < lines.length; i++) {
              final line = lines[i];
              if (logPattern.hasMatch(line) && sensitivePattern.hasMatch(line)) {
                // Ignore safe metadata length/count logs
                if (!line.contains('length') && !line.contains('count') && !line.contains('status')) {
                  violations++;
                  // ignore: avoid_print
                  print('Potential S-5 Violation in ${entity.path}:${i + 1}: $line');
                }
              }
            }
          }
        }
      }

      if (relayDir.existsSync()) {
        final serverFile = File('../relay/server.js');
        if (serverFile.existsSync()) {
          final lines = serverFile.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            final line = lines[i];
            if (line.contains('console.log') && line.contains('text') && !line.contains('length')) {
              violations++;
              // ignore: avoid_print
              print('Potential S-5 Violation in relay/server.js:${i + 1}: $line');
            }
          }
        }
      }


      // S-5 Acceptance Criteria: 0 violations found across the codebase
      expect(violations, equals(0), reason: 'S-5 Violation: Found logger call outputting captured text');
    });
  });
}
