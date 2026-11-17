import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "com.keyflow.app/shared-snippets",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      do {
        switch call.method {
        case "next":
          guard let snippet = try SharedSnippetStore().next() else {
            result(nil)
            return
          }
          result([
            "id": snippet.id.uuidString.lowercased(),
            "text": snippet.text,
            "capturedAt": ISO8601DateFormatter().string(from: snippet.capturedAt)
          ])
        case "remove":
          guard let rawID = call.arguments as? String, let id = UUID(uuidString: rawID) else {
            result(FlutterError(code: "invalid-id", message: nil, details: nil))
            return
          }
          try SharedSnippetStore().remove(id)
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      } catch {
        result(FlutterError(code: "shared-snippet-unavailable", message: nil, details: nil))
      }
    }
  }
}
