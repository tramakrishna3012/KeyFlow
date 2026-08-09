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
  const CloudApprovalRequiredException([
    this.message = 'Cloud translation requires per-use user approval.',
  ]);
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
  TranslationService({String? relayEndpoint, http.Client? httpClient})
    : _relayEndpoint = relayEndpoint ?? 'http://localhost:3000/translate',
      _client = httpClient ?? http.Client();

  final String _relayEndpoint;
  final http.Client _client;

  // On-device local dictionary pairs
  static const Map<String, Map<String, String>> _onDeviceDictionary = {
    'es': {
      'hello, how are you?': 'Hola, ¿cómo estás?',
      'good morning': 'Buenos días',
      'thank you': 'Gracias',
      'welcome to keyflow': 'Bienvenido a KeyFlow',
      'project roadmap': 'Hoja de ruta del proyecto',
    },
    'fr': {
      'hello, how are you?': 'Bonjour, comment allez-vous?',
      'good morning': 'Bonjour',
      'thank you': 'Merci',
      'welcome to keyflow': 'Bienvenue sur KeyFlow',
    },
    'de': {
      'hello, how are you?': 'Hallo, wie geht es Ihnen?',
      'good morning': 'Guten Morgen',
      'thank you': 'Danke',
    },
    'ja': {
      'hello, how are you?': 'こんにちは、お元気ですか？',
      'good morning': 'おはようございます',
      'thank you': 'ありがとうございます',
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

    // 1. Try On-Device Translation
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
      final response = await _client
          .post(
            Uri.parse(_relayEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'text': cleanText,
              'source_lang': sourceLang,
              'target_lang': targetLang,
              'mock': true,
            }),
          )
          .timeout(const Duration(seconds: 4));

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
        throw TranslationException(
          'Cloud relay returned status ${response.statusCode}',
        );
      }
    } catch (e) {
      if (e is CloudApprovalRequiredException) rethrow;
      debugPrint('Translation error: $e');
      throw const TranslationException(
        'Translation failed: Cloud relay service unreachable. Please check your internet connection.',
      );
    }
  }
}
