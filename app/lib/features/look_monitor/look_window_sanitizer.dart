import 'look_activity_models.dart';

/// Sanitizes application window titles and permitted text records to prevent leakage
/// of credentials, passwords, OTPs, credit cards, URL query parameters, or personal tokens.
class LookWindowSanitizer {
  const LookWindowSanitizer({this.customExclusions = const []});

  final List<PrivacyExclusionRule> customExclusions;

  static final RegExp _urlRegex = RegExp(
    r'https?:\/\/[^\s]+',
    caseSensitive: false,
  );
  static final RegExp _emailRegex = RegExp(
    r'\b[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+\b',
    caseSensitive: false,
  );
  static final RegExp _creditCardRegex = RegExp(r'\b(?:\d[ -]*?){13,16}\b');
  static final RegExp _tokenRegex = RegExp(r'\b[A-Za-z0-9-_]{24,}\b');
  static final RegExp _authSecretRegex = RegExp(
    r'\b(?:cvv|cvc|exp|pin|otp|passcode|token|bearer|secret|password)\s*[:=]\s*\S+',
    caseSensitive: false,
  );

  /// Checks if an application or window title matches a privacy exclusion rule.
  bool isApplicationExcluded(String appName) {
    final clean = appName.toLowerCase().trim();
    for (final rule in customExclusions) {
      if (rule.isActive && clean.contains(rule.appName.toLowerCase().trim())) {
        return true;
      }
    }
    return false;
  }

  /// Checks if text content contains sensitive fields (passwords, OTPs, card numbers).
  bool containsSensitiveContent(String? text, {String? appName}) {
    if (text == null || text.trim().isEmpty) return false;
    final lowerApp = (appName ?? '').toLowerCase();
    // Calculator and mathematical utilities never contain masked financial secrets or OTPs
    if (lowerApp.contains('calculator') || lowerApp.contains('calc')) {
      return false;
    }
    if (_creditCardRegex.hasMatch(text)) return true;
    if (_authSecretRegex.hasMatch(text)) return true;
    return false;
  }

  /// Cleans the raw window title.
  String sanitize(String? rawTitle, {String? appName}) {
    if (rawTitle == null || rawTitle.trim().isEmpty) {
      return '';
    }

    if (appName != null && isApplicationExcluded(appName)) {
      return '[Excluded Application: $appName]';
    }

    var text = rawTitle.trim();

    // 1. Sanitize URLs to base domain/path only
    text = text.replaceAllMapped(_urlRegex, (match) {
      final urlStr = match.group(0);
      try {
        final uri = Uri.parse(urlStr!);
        return '${uri.scheme}://${uri.host}${uri.path}';
      } on Object catch (_) {
        return '[Web URL]';
      }
    });

    // 2. Redact Email addresses
    text = text.replaceAll(_emailRegex, '[Redacted Email]');

    // 3. Redact Credit cards and financial data
    text = text.replaceAll(_creditCardRegex, '[Redacted Card Number]');

    // 4. Redact Auth secrets, OTPs & tokens
    text = text.replaceAll(_authSecretRegex, '[Redacted Secret]');
    text = text.replaceAll(_tokenRegex, '[Redacted Token]');

    // 5. Truncate length
    if (text.length > 80) {
      text = '${text.substring(0, 77)}...';
    }

    return text;
  }

  /// Sanitizes permitted text entries before storage or transmission.
  String sanitizeTextRecord(String? text, {String? appName}) {
    if (text == null || text.trim().isEmpty) return '';
    if (appName != null && isApplicationExcluded(appName)) {
      return '[Excluded Content]';
    }
    if (containsSensitiveContent(text)) {
      return '[Redacted Sensitive Record]';
    }
    return sanitize(text, appName: appName);
  }
}
