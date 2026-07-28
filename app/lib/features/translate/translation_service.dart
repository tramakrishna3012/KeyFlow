import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Result of a translation request containing translated text and attribution status.
class TranslationResult {
  const TranslationResult({
    required this.translatedText,
    required this.sourceLang,
    required this.targetLang,
    required this.isCloud,
    required this.attributionBadge,
  });

  final String translatedText;
  final String sourceLang;
  final String targetLang;
  final bool isCloud;
  final String attributionBadge;
}

/// Exception thrown when cloud fallback requires per-use user approval (TRD S-4).
class CloudApprovalRequiredException implements Exception {
  const CloudApprovalRequiredException([this.message = 'Cloud translation requires per-use user approval.']);
  final String message;
  @override
  String toString() => message;
}

/// Exception thrown when translation fails due to network or service unreachable.
class TranslationException implements Exception {
  const TranslationException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// On-Device & Cloud Relay Translation Service for KeyFlow (Architecture §5, SRS FR-15..18).
class TranslationService {
  TranslationService({
    String? relayEndpoint,
    http.Client? httpClient,
  })  : _relayEndpoint = relayEndpoint ??
            (kIsWeb || defaultTargetPlatform != TargetPlatform.android
                ? 'http://localhost:3000/translate'
                : 'http://10.0.2.2:3000/translate'),
        _client = httpClient ?? http.Client();

  final String _relayEndpoint;
  final http.Client _client;

  // On-device local dictionary pairs for instant offline translation
  static const Map<String, Map<String, String>> _onDeviceDictionary = {
    'es': {
      'hello': 'Hola',
      'hi': 'Hola',
      'hello, how are you?': 'Hola, ¿cómo estás?',
      'how are you?': '¿Cómo estás?',
      'good morning': 'Buenos días',
      'good night': 'Buenas noches',
      'thank you': 'Gracias',
      'thanks': 'Gracias',
      'yes': 'Sí',
      'no': 'No',
      'please': 'Por favor',
      'goodbye': 'Adiós',
      'bye': 'Adiós',
      'welcome to keyflow': 'Bienvenido a KeyFlow',
      'welcome': 'Bienvenido',
      'project roadmap': 'Hoja de ruta del proyecto',
    },
    'fr': {
      'hello': 'Bonjour',
      'hi': 'Salut',
      'hello, how are you?': 'Bonjour, comment allez-vous?',
      'how are you?': 'Comment allez-vous?',
      'good morning': 'Bonjour',
      'good night': 'Bonne nuit',
      'thank you': 'Merci',
      'thanks': 'Merci',
      'yes': 'Oui',
      'no': 'Non',
      'please': 'S\'il vous plaît',
      'goodbye': 'Au revoir',
      'welcome to keyflow': 'Bienvenue sur KeyFlow',
      'welcome': 'Bienvenue',
    },
    'de': {
      'hello': 'Hallo',
      'hi': 'Hallo',
      'hello, how are you?': 'Hallo, wie geht es Ihnen?',
      'how are you?': 'Wie geht es Ihnen?',
      'good morning': 'Guten Morgen',
      'good night': 'Gute Nacht',
      'thank you': 'Danke',
      'thanks': 'Danke',
      'yes': 'Ja',
      'no': 'Nein',
      'please': 'Bitte',
      'goodbye': 'Auf Wiedersehen',
    },
    'ja': {
      'hello': 'こんにちは',
      'hi': 'やあ',
      'hello, how are you?': 'こんにちは、お元気ですか？',
      'how are you?': 'お元気ですか？',
      'good morning': 'おはようございます',
      'thank you': 'ありがとうございます',
      'thanks': 'ありがとう',
      'yes': 'はい',
      'no': 'いいえ',
      'goodbye': 'さようなら',
    },
    'zh': {
      'hello': '你好',
      'hi': '嗨',
      'hello, how are you?': '你好，你好吗？',
      'thank you': '谢谢',
      'yes': '是',
      'no': '不',
    },
    'ar': {
      'hello': 'مرحبا',
      'thank you': 'شكرا',
      'yes': 'نعم',
      'no': 'لا',
    },
    'pt': {
      'hello': 'Olá',
      'thank you': 'Obrigado',
      'yes': 'Sim',
      'no': 'Não',
    },
    'ko': {
      'hello': '안녕하세요',
      'thank you': '감사합니다',
      'yes': '네',
      'no': '아니요',
    },
  };

  /// Check if the target language is supported on-device.
  bool isOnDeviceSupported(String targetLang) {
    final lang = targetLang.toLowerCase();
    return _onDeviceDictionary.containsKey(lang);
  }

  /// Translates [text] to [targetLang].
  ///
  /// Enforces explicit per-use consent ([userApprovedCloud] = true) before contacting the cloud relay.
  Future<TranslationResult> translate({
    required String text,
    required String targetLang,
    String sourceLang = 'en',
    bool userApprovedCloud = false,
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) {
      return TranslationResult(
        translatedText: '',
        sourceLang: sourceLang,
        targetLang: targetLang,
        isCloud: false,
        attributionBadge: 'Translated on-device',
      );
    }

    final targetClean = targetLang.toLowerCase();

    // 1. Try On-Device Dictionary Match
    if (isOnDeviceSupported(targetClean)) {
      final dict = _onDeviceDictionary[targetClean];
      final localMatch = dict?[cleanText.toLowerCase()];
      if (localMatch != null) {
        return TranslationResult(
          translatedText: localMatch,
          sourceLang: sourceLang,
          targetLang: targetLang,
          isCloud: false,
          attributionBadge: 'Translated on-device',
        );
      }
    }

    // 2. Cloud Fallback Path — Enforce per-use approval check
    if (!userApprovedCloud) {
      throw const CloudApprovalRequiredException(
        'Cloud fallback requested. This text snippet will be sent to the KeyFlow Translation Relay.',
      );
    }

    // 3. Perform Cloud Relay POST Request
    try {
      final response = await _client.post(
        Uri.parse(_relayEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': cleanText,
          'source_lang': sourceLang,
          'target_lang': targetLang,
          'mock': true,
        }),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        final translated = body['translated_text'] as String? ?? cleanText;

        return TranslationResult(
          translatedText: translated,
          sourceLang: sourceLang,
          targetLang: targetLang,
          isCloud: true,
          attributionBadge: 'Translated via cloud (user approved)',
        );
      } else {
        throw TranslationException('Cloud relay returned status ${response.statusCode}');
      }
    } catch (e) {
      if (e is CloudApprovalRequiredException || e is TranslationException) rethrow;
      debugPrint('Translation error: $e');
      throw const TranslationException(
        'Translation failed: Cloud relay service unreachable. Please check your internet connection.',
      );
    }
  }
}
