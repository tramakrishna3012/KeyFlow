import 'package:flutter_test/flutter_test.dart';
import 'package:keyflow_app/features/look_monitor/look_activity_models.dart';
import 'package:keyflow_app/features/look_monitor/look_monitor_service.dart';
import 'package:keyflow_app/features/look_monitor/look_window_sanitizer.dart';

void main() {
  group('Look System Desktop Application Tests', () {
    late LookMonitorService service;
    late LookWindowSanitizer sanitizer;

    setUp(() {
      sanitizer = const LookWindowSanitizer(
        customExclusions: [
          PrivacyExclusionRule(appName: '1Password'),
          PrivacyExclusionRule(appName: 'Bitwarden'),
        ],
      );
      service = LookMonitorService(sanitizer: sanitizer);
    });

    test('1. Session Lifecycle: Start -> Pause -> Resume -> Stop', () {
      service.startSession(customSessionId: 'sess-test-101');
      expect(service.status, equals(LookMonitoringStatus.active));
      expect(service.currentSession, isNotNull);
      expect(service.currentSession!.sessionId, equals('sess-test-101'));

      service.pauseSession();
      expect(service.status, equals(LookMonitoringStatus.paused));
      expect(service.currentSession!.status, equals(LookMonitoringStatus.paused));

      service.resumeSession();
      expect(service.status, equals(LookMonitoringStatus.active));
      expect(service.currentSession!.status, equals(LookMonitoringStatus.active));

      service.stopSession();
      expect(service.status, equals(LookMonitoringStatus.stopped));
      expect(service.currentSession, isNull);
      expect(service.sessionHistory.length, equals(1));
      expect(service.sessionHistory.first.sessionId, equals('sess-test-101'));
    });

    test('2. Application-Level Organization (Session -> App -> Timeline & Text)', () {
      service
        ..startSession(customSessionId: 'sess-hierarchical-002')
        ..updateForegroundWindow(
          appName: 'Google Chrome',
          rawTitle: 'KeyFlow Pull Request #14',
          textContent: 'Reviewing session hierarchy and offline sync.',
        )
        ..updateForegroundWindow(
          appName: 'Visual Studio Code',
          rawTitle: 'look_monitor_service.dart',
          textContent: 'Writing unit tests for desktop client.',
        );

      final session = service.currentSession!;
      expect(session.applications.length, equals(2));

      final chromeApp = session.applications.firstWhere((a) => a.appName == 'Google Chrome');
      expect(chromeApp.category, equals('Browsing'));
      expect(chromeApp.activityTimeline.isNotEmpty, isTrue);
      expect(chromeApp.textRecords.isNotEmpty, isTrue);
      expect(chromeApp.textRecords.first.content, contains('Reviewing session hierarchy'));

      final vscodeApp = session.applications.firstWhere((a) => a.appName == 'Visual Studio Code');
      expect(vscodeApp.category, equals('Development'));
    });

    test('3. Privacy Sanitizer: Redacts passwords, credit cards, OTPs, and tokens', () {
      const rawWithSensitive = 'Login with secret: 4111-2222-3333-4444 and otp=892314 for user john.doe@keyflow.io';
      final sanitized = sanitizer.sanitizeTextRecord(rawWithSensitive);

      expect(sanitized, isNot(contains('4111-2222-3333-4444')));
      expect(sanitized, isNot(contains('john.doe@keyflow.io')));
      expect(sanitized, contains('[Redacted Sensitive Record]'));
    });

    test('4. Privacy Exclusions: Completely blocks configured applications', () {
      expect(sanitizer.isApplicationExcluded('1Password'), isTrue);
      expect(sanitizer.isApplicationExcluded('Bitwarden Vault'), isTrue);
      expect(sanitizer.isApplicationExcluded('Google Chrome'), isFalse);

      service
        ..startSession()
        ..updateForegroundWindow(
          appName: '1Password',
          rawTitle: 'Master Password Vault',
          textContent: 'Master password string',
        );

      final session = service.currentSession!;
      expect(session.applications.any((a) => a.appName == '1Password'), isFalse);
    });

    test('5. Offline Sync Queue Enqueues & Flushes on Reconnection', () async {
      service
        ..startSession()
        ..updateForegroundWindow(
          appName: 'Slack',
          rawTitle: '#general channel',
          textContent: 'Team sync meeting notes',
        );

      expect(service.offlineQueue.isNotEmpty, isTrue);
      expect(service.offlineQueue.first.appName, equals('Slack'));

      final flushed = await service.flushOfflineQueue();
      expect(flushed, greaterThan(0));
      expect(service.offlineQueue.isEmpty, isTrue);
    });
  });
}
