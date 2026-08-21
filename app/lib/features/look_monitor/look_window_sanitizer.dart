/// Sanitizes application window titles to prevent leakage of credentials,
/// email addresses, URL query parameters, or personal tokens.
class LookWindowSanitizer {
  const LookWindowSanitizer();

  static final RegExp _urlRegex = RegExp(r'https?:\/\/[^\s]+', caseSensitive: false);
  static final RegExp _emailRegex = RegExp(r'[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+', caseSensitive: false);
  static final RegExp _tokenRegex = RegExp(r'\b[A-Za-z0-9-_]{24,}\b');

  /// Cleans the raw window title.
  String sanitize(String? rawTitle) {
    if (rawTitle == null || rawTitle.trim().isEmpty) {
      return '';
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

    // 3. Redact long token-like strings
    text = text.replaceAll(_tokenRegex, '[Redacted Token]');

    // 4. Truncate length
    if (text.length > 80) {
      text = '${text.substring(0, 77)}...';
    }

    return text;
  }
}
