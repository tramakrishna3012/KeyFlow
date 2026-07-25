import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:keyflow_app/features/translate/translation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Translation Engine & Cloud Relay Tests (SRS FR-15..18)', () {
    test('On-device translation returns local result with "Translated on-device" badge', () async {
      final service = TranslationService();

      final res = await service.translate(
        text: 'Hello, how are you?',
        targetLang: 'es',
      );

      expect(res.translatedText, equals('Hola, ¿cómo estás?'));
      expect(res.isCloud, isFalse);
      expect(res.attributionBadge, equals('Translated on-device'));
    });

    test('Cloud fallback requires per-use user approval (TRD S-4)', () async {
      final service = TranslationService();

      expect(
        () => service.translate(
          text: 'Custom phrase requiring cloud fallback',
          targetLang: 'es',
          userApprovedCloud: false,
        ),
        throwsA(isA<CloudApprovalRequiredException>()),
      );
    });

    test('Approved cloud translation returns "Translated via cloud (user approved)" badge', () async {
      final mockHttpClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'translated_text': 'Hola, mundo',
            'source_lang': 'en',
            'target_lang': 'es',
            'provider': 'relay-cloud-mock',
          }),
          200,
          headers: {'Content-Type': 'application/json'},
        );
      });

      final service = TranslationService(
        relayEndpoint: 'http://localhost:3000/translate',
        httpClient: mockHttpClient,
      );

      final res = await service.translate(
        text: 'Hello world',
        targetLang: 'es',
        userApprovedCloud: true,
      );

      expect(res.translatedText, equals('Hola, mundo'));
      expect(res.isCloud, isTrue);
      expect(res.attributionBadge, equals('Translated via cloud (user approved)'));
    });

    test('Unreachable relay / offline network fails gracefully with clear error message', () async {
      final failingHttpClient = MockClient((request) async {
        throw Exception('Connection refused / SocketException');
      });

      final service = TranslationService(
        relayEndpoint: 'http://invalid-endpoint:3000/translate',
        httpClient: failingHttpClient,
      );

      expect(
        () => service.translate(
          text: 'Offline test phrase',
          targetLang: 'es',
          userApprovedCloud: true,
        ),
        throwsA(
          isA<TranslationException>().having(
            (e) => e.message,
            'message',
            contains('Cloud relay service unreachable'),
          ),
        ),
      );
    });
  });
}
