import Cocoa

public enum MacOSMenuCommand {
    case pause1Hour
    case pauseUntilReenabled
    case resume
    case openHistory
    case openSettings
    case quit
}

public class MacOSStatusItem: NSObject {
    private var statusItem: NSStatusItem?
    private var callback: ((MacOSMenuCommand) -> Void)?
    private var isPaused = false

    public func setupStatusItem(callback: @escaping (MacOSMenuCommand) -> Void) {
        self.callback = callback
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.title = "⚡ KeyFlow"
            button.toolTip = "KeyFlow - Active"
        }

        rebuildMenu()
    }

    public func updateStatus(isPaused: Bool) {
        self.isPaused = isPaused
        if let button = statusItem?.button {
            button.title = isPaused ? "⚡ KeyFlow (Paused)" : "⚡ KeyFlow"
            button.toolTip = isPaused ? "KeyFlow - Paused" : "KeyFlow - Active"
        }
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        if isPaused {
            let resumeItem = NSMenuItem(title: "Resume Capture", action: #selector(onResume), keyEquivalent: "")
            resumeItem.target = self
            menu.addItem(resumeItem)
        } else {
            let pause1hr = NSMenuItem(title: "Pause (1 hour)", action: #selector(onPause1Hr), keyEquivalent: "")
            pause1hr.target = self
            menu.addItem(pause1hr)

            let pauseUntil = NSMenuItem(title: "Pause (until re-enabled)", action: #selector(onPauseUntil), keyEquivalent: "")
            pauseUntil.target = self
            menu.addItem(pauseUntil)
        }

        menu.addItem(NSMenuItem.separator())

        let historyItem = NSMenuItem(title: "Open History", action: #selector(onOpenHistory), keyEquivalent: "h")
        historyItem.target = self
        menu.addItem(historyItem)

        let settingsItem = NSMenuItem(title: "Settings", action: #selector(onOpenSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit KeyFlow", action: #selector(onQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    @objc private func onPause1Hr() { callback?(.pause1Hour) }
    @objc private func onPauseUntil() { callback?(.pauseUntilReenabled) }
    @objc private func onResume() { callback?(.resume) }
    @objc private func onOpenHistory() { callback?(.openHistory) }
    @objc private func onOpenSettings() { callback?(.openSettings) }
    @objc private func onQuit() { callback?(.quit) }
}
