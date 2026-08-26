import Cocoa
import ApplicationServices

public struct MacOSCapturedEvent {
    public let text: String
    public let appName: String
    public let windowTitle: String
    public let timestampMs: UInt64
}

public class MacOSCaptureEngine {
    public static let shared = MacOSCaptureEngine()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isRunning = false
    private var isPaused = false

    private var exclusionList: [String] = []
    private var callback: ((MacOSCapturedEvent) -> Void)?

    private init() {}

    /// Checks and optionally prompts for macOS Accessibility Permission via System Settings.
    public func checkAccessibilityPermission(prompt: Bool = true) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    public func startCapture(callback: @escaping (MacOSCapturedEvent) -> Void) -> Bool {
        guard checkAccessibilityPermission(prompt: true) else {
            return false
        }

        self.callback = callback
        self.isRunning = true
        self.isPaused = false

        if eventTap == nil {
            let eventMask = (1 << CGEventType.keyDown.rawValue)
            let observer = Unmanaged.passUnretained(self).toOpaque()

            guard let tap = CGEvent.tapCreate(
                tap: .cghidEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: CGEventMask(eventMask),
                callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                    guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                    let engine = Unmanaged<MacOSCaptureEngine>.fromOpaque(refcon).takeUnretainedValue()
                    return engine.handleCGEvent(proxy: proxy, type: type, event: event)
                },
                userInfo: observer
            ) else {
                return false
            }

            self.eventTap = tap
            self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            if let source = runLoopSource {
                CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
                CGEvent.tapEnable(tap: tap, enable: true)
            }
        }

        return true
    }

    public func stopCapture() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            }
            eventTap = nil
            runLoopSource = nil
        }
        isRunning = false
        callback = nil
    }

    public func pauseCapture() {
        isPaused = true
    }

    public func resumeCapture() {
        isPaused = false
    }

    public var paused: Bool {
        return isPaused
    }

    public func setExclusionList(_ list: [String]) {
        self.exclusionList = list.map { $0.lowercased() }
    }

    private func handleCGEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard isRunning && !isPaused else {
            return Unmanaged.passUnretained(event)
        }

        let frontmostApp = NSWorkspace.shared.frontmostApplication
        let appName = frontmostApp?.localizedName ?? "Unknown"
        let bundleId = frontmostApp?.bundleIdentifier ?? ""

        // Native Exclusion List check before processing
        if isExcluded(appName: appName, bundleId: bundleId) {
            return Unmanaged.passUnretained(event)
        }

        var length = 0
        event.keyboardGetUnicodeString(maxStringLength: 0, actualStringLength: &length, unicodeString: nil)
        if length > 0 {
            var chars = [UniChar](repeating: 0, count: length)
            event.keyboardGetUnicodeString(maxStringLength: length, actualStringLength: &length, unicodeString: &chars)
            let capturedText = String(utf16CodeUnits: chars, count: length)

            if !capturedText.isEmpty, let cb = callback {
                let timestampMs = UInt64(Date().timeIntervalSince1970 * 1000)
                let capturedEvent = MacOSCapturedEvent(
                    text: capturedText,
                    appName: appName,
                    windowTitle: appName,
                    timestampMs: timestampMs
                )
                cb(capturedEvent)
            }
        }

        return Unmanaged.passUnretained(event)
    }

    private func isExcluded(appName: String, bundleId: String) -> Bool {
        if exclusionList.isEmpty { return false }
        let lowerAppName = appName.lowercased()
        let lowerBundleId = bundleId.lowercased()

        return exclusionList.contains { item in
            !item.isEmpty && (lowerAppName.contains(item) || lowerBundleId.contains(item))
        }
    }
}
