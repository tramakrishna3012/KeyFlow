import 'package:flutter_test/flutter_test.dart';
import 'package:keyflow_app/features/look_monitor/look_activity_models.dart';
import 'package:keyflow_app/features/look_monitor/look_monitor_service.dart';
import 'package:keyflow_app/features/look_monitor/look_window_sanitizer.dart';

void main() {
  group('Look System: Window Title Sanitization (Privacy Guarantees)', () {
    const sanitizer = LookWindowSanitizer();

    test('Sanitizes URLs by stripping query parameters and sensitive tokens', () {
      const raw = 'Google Chrome — https://internal.company.com/project?auth_token=super_secret_token_12345678901234567890';
      final sanitized = sanitizer.sanitize(raw);
      expect(sanitized.contains('auth_token'), isFalse);
      expect(sanitized.contains('super_secret'), isFalse);
      expect(sanitized.contains('https://internal.company.com/project'), isTrue);
    });

    test('Redacts email addresses from window titles', () {
      const raw = 'Slack — Direct Message with sarah.connor@cyberdyne.corp';
      final sanitized = sanitizer.sanitize(raw);
      expect(sanitized.contains('sarah.connor@cyberdyne.corp'), isFalse);
      expect(sanitized, contains('[Redacted Email]'));
    });

    test('Redacts API keys and secret hash strings (>24 chars)', () {
      const raw = 'VS Code — API_KEY_mock_token_1234567890abcdef1234567890';
      final sanitized = sanitizer.sanitize(raw);
      expect(sanitized.contains('mock_token_1234567890abcdef1234567890'), isFalse);
      expect(sanitized, contains('[Redacted Token]'));
    });
  });

  group('Look System: Monitor Service & Consent Lifecycle', () {
    late LookMonitorService service;

    setUp(() {
      service = LookMonitorService();
    });

    tearDown(() {
      service.dispose();
    });

    test('Starts in active state with granted consent', () {
      service.startMonitoring();
      expect(service.status, equals(LookMonitoringStatus.active));
      expect(service.consentState, equals(LookConsentState.granted));
    });

    test('Pause and resume toggle monitoring state transparently', () {
      service.startMonitoring();
      expect(service.status, equals(LookMonitoringStatus.active));

      service.pauseMonitoring();
      expect(service.status, equals(LookMonitoringStatus.paused));

      service.resumeMonitoring();
      expect(service.status, equals(LookMonitoringStatus.active));
    });

    test('Revoking consent halts monitoring immediately', () {
      service.startMonitoring();
      expect(service.status, equals(LookMonitoringStatus.active));

      service.setConsent(LookConsentState.revoked);
      expect(service.status, equals(LookMonitoringStatus.stopped));
      expect(service.consentState, equals(LookConsentState.revoked));

      // Attempting to start without consent fails
      service.startMonitoring();
      expect(service.status, equals(LookMonitoringStatus.stopped));
    });

    test('Updates foreground activity and categorizes appropriately', () {
      service
        ..startMonitoring()
        ..updateForegroundWindow(
          appName: 'Visual Studio Code',
          rawTitle: 'main.dart — KeyFlow project',
        );

      expect(service.currentApp, equals('Visual Studio Code'));
      expect(service.currentWindowTitle, contains('main.dart'));
      expect(service.isCurrentlyIdle, isFalse);

      // Transition to idle Slack
      service.updateForegroundWindow(
        appName: 'Slack',
        rawTitle: 'Chat in #general',
        isIdle: true,
        idleSeconds: 300,
      );

      expect(service.currentApp, equals('Slack'));
      expect(service.isCurrentlyIdle, isTrue);
      expect(service.activityLogs, isNotEmpty);
      expect(service.activityLogs.first.appName, equals('Visual Studio Code'));
      expect(service.activityLogs.first.appCategory, equals('Development'));
    });

    test('Rolling intervals occur when window title changes within same application', () {
      service
        ..startMonitoring()
        ..updateForegroundWindow(
          appName: 'Google Chrome',
          rawTitle: 'Tab 1 — Documentation',
        );

      final initialLogsCount = service.activityLogs.length;

      // Switch tab within same browser
      service.updateForegroundWindow(
        appName: 'Google Chrome',
        rawTitle: 'Tab 2 — GitHub Pull Request',
      );

      expect(service.activityLogs.length, equals(initialLogsCount + 1));
      expect(service.activityLogs.first.appName, equals('Google Chrome'));
      expect(service.activityLogs.first.windowTitle, equals('Tab 1 — Documentation'));
      expect(service.currentWindowTitle, equals('Tab 2 — GitHub Pull Request'));
    });
  });

  group('Look System: Model Resilience & Hardening', () {
    test('LookActivityLog.fromJson gracefully handles missing or invalid timestamps without throwing', () {
      final invalidJson = <String, dynamic>{
        'id': 'test-123',
        'appName': 'TestApp',
        'startedAt': null,
        'endedAt': 'invalid-date-format',
      };

      final log = LookActivityLog.fromJson(invalidJson);
      expect(log.id, equals('test-123'));
      expect(log.appName, equals('TestApp'));
      expect(log.startedAt, isA<DateTime>());
      expect(log.endedAt, isA<DateTime>());
    });
  });
}
