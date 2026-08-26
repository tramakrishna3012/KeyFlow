import Cocoa
import FlutterMacOS

public class KeyflowMacOSCapturePlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?

    private let statusItem = MacOSStatusItem()

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "keyflow/capture", binaryMessenger: registrar.messenger)
        let eventChannel = FlutterEventChannel(name: "keyflow/capture/stream", binaryMessenger: registrar.messenger)

        let instance = KeyflowMacOSCapturePlugin()
        instance.methodChannel = channel
        instance.eventChannel = eventChannel

        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(instance)

        instance.setupMenu()
    }

    private func setupMenu() {
        statusItem.setupStatusItem { [weak self] command in
            self?.handleMenuCommand(command)
        }
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "checkAccessibilityPermission":
            let prompt = (call.arguments as? Bool) ?? true
            let isGranted = MacOSCaptureEngine.shared.checkAccessibilityPermission(prompt: prompt)
            result(isGranted)

        case "startCapture":
            let ok = MacOSCaptureEngine.shared.startCapture { [weak self] event in
                self?.sendCapturedEvent(event)
            }
            statusItem.updateStatus(isPaused: false)
            result(ok)

        case "stopCapture":
            MacOSCaptureEngine.shared.stopCapture()
            statusItem.updateStatus(isPaused: true)
            result(true)

        case "pauseCapture":
            MacOSCaptureEngine.shared.pauseCapture()
            statusItem.updateStatus(isPaused: true)
            result(true)

        case "resumeCapture":
            MacOSCaptureEngine.shared.resumeCapture()
            statusItem.updateStatus(isPaused: false)
            result(true)

        case "setExclusionList":
            if let list = call.arguments as? [String] {
                MacOSCaptureEngine.shared.setExclusionList(list)
            }
            result(true)

        case "setAutostart":
            result(true)

        case "isAutostartEnabled":
            result(false)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func sendCapturedEvent(_ event: MacOSCapturedEvent) {
        let data: [String: Any] = [
            "text": event.text,
            "app_name": event.appName,
            "window_title": event.windowTitle,
            "timestamp": event.timestampMs
        ]
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(data)
        }
    }

    private func handleMenuCommand(_ command: MacOSMenuCommand) {
        switch command {
        case .pause1Hour, .pauseUntilReenabled:
            MacOSCaptureEngine.shared.pauseCapture()
            statusItem.updateStatus(isPaused: true)
            methodChannel?.invokeMethod("onPauseChanged", arguments: true)

        case .resume:
            MacOSCaptureEngine.shared.resumeCapture()
            statusItem.updateStatus(isPaused: false)
            methodChannel?.invokeMethod("onPauseChanged", arguments: false)

        case .openHistory:
            NSApp.activate(ignoringOtherApps: true)
            methodChannel?.invokeMethod("onNavigate", arguments: "history")

        case .openSettings:
            NSApp.activate(ignoringOtherApps: true)
            methodChannel?.invokeMethod("onNavigate", arguments: "settings")

        case .quit:
            NSApplication.shared.terminate(nil)
        }
    }

    // MARK: - FlutterStreamHandler
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}
