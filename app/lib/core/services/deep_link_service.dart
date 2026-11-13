import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../data/auth_service.dart';
import '../router/app_router.dart';

/// Service responsible for receiving and processing custom URI deep links (`keyflow://pair`, `keyflow://open`).
class DeepLinkService {
  DeepLinkService({AuthService? authService})
    : _authService = authService ?? AuthService.instance;

  static final DeepLinkService instance = DeepLinkService();
  static const MethodChannel _channel = MethodChannel(
    'com.keyflow.app/deeplink',
  );

  final AuthService _authService;
  bool _initialized = false;

  /// Initializes deep link listening from the native Android channel.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // AppLinks emits the initial URL and subsequent URLs in the same stream.
      AppLinks().uriLinkStream.listen(
        (uri) => unawaited(handleLink(uri.toString())),
        onError: (Object _) => debugPrint('Could not read the incoming link.'),
      );
      return;
    }

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onDeepLink') {
        final link = call.arguments as String?;
        if (link != null && link.isNotEmpty) {
          await handleLink(link);
        }
      }
    });

    try {
      final initialLink = await _channel.invokeMethod<String>('getInitialLink');
      if (initialLink != null && initialLink.isNotEmpty) {
        await handleLink(initialLink);
      }
    } on PlatformException catch (e) {
      debugPrint(
        '[DeepLinkService] PlatformException getting initial link: $e',
      );
    } on Object catch (e) {
      debugPrint('[DeepLinkService] Error getting initial link: $e');
    }
  }

  /// Parses and routes incoming `keyflow://` URLs.
  Future<bool> handleLink(String linkStr) async {
    final uri = Uri.tryParse(linkStr.trim());
    if (uri == null || uri.scheme != 'keyflow') {
      return false;
    }

    debugPrint(
      '[DeepLinkService] Handling link: scheme=${uri.scheme}, host=${uri.host}, path=${uri.path}',
    );

    // 1. Mobile pairing handshake: keyflow://pair?token=<TOKEN>
    if (uri.host == 'pair' || uri.path.contains('pair')) {
      final token =
          uri.queryParameters['token'] ?? uri.queryParameters['pairing_token'];
      if (token != null && token.isNotEmpty) {
        appRouter.go(
          Uri(path: '/pair', queryParameters: {'token': token}).toString(),
        );
        return true;
      }
    }

    // 2. Open action: keyflow://open
    if (uri.host == 'open' || uri.path.contains('open')) {
      if (_authService.isAuthenticated) {
        appRouter.go('/home');
      } else {
        appRouter.go('/login');
      }
      return true;
    }

    return false;
  }
}
