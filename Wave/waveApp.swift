import SwiftUI

@main
struct WaveApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = AppState()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        Window("Wave", id: "main") {
            HomeView()
                .environment(appState)
        }
        .defaultSize(width: 520, height: 440)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .textFormatting) {}
            CommandGroup(replacing: .toolbar) {}
            CommandGroup(replacing: .windowSize) {}
            CommandGroup(replacing: .windowArrangement) {}
            CommandGroup(replacing: .help) {}
        }

        MenuBarExtra {
            switch appState.status {
            case .idle:
                if appState.isReady {
                    Label("Ready", systemImage: "checkmark.circle")
                } else {
                    Label("Not configured", systemImage: "exclamationmark.triangle")
                }
            case .recording:
                Label("Recording...", systemImage: "mic.fill")
            case .transcribing:
                Label("Transcribing...", systemImage: "brain")
            case .transforming:
                Label("Transforming...", systemImage: "wand.and.stars")
            case .error(let msg):
                Label(msg, systemImage: "exclamationmark.triangle")
            }

            Divider()

            Menu("Recent Transcriptions") {
                if appState.historyManager.records.isEmpty {
                    Text("No transcriptions yet")
                } else {
                    ForEach(appState.historyManager.records.prefix(7)) { record in
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(record.text, forType: .string)
                        } label: {
                            Text(record.text.count > 40 ? String(record.text.prefix(40)) + "…" : record.text)
                        }
                    }
                    Divider()
                    Button("Clear History...") {
                        let alert = NSAlert()
                        alert.messageText = "Clear transcription history?"
                        alert.informativeText = "This cannot be undone."
                        alert.alertStyle = .warning
                        alert.addButton(withTitle: "Clear")
                        alert.addButton(withTitle: "Cancel")
                        if alert.runModal() == .alertFirstButtonReturn {
                            appState.historyManager.clearAll()
                        }
                    }
                }
            }

            Divider()

            Button("Check for Updates...") {
                UpdaterService.shared.checkForUpdates()
            }
            .disabled(!UpdaterService.shared.isAvailable)

            Divider()

            Button("Settings...") {
                appState.pendingNavSelection = .general
                openMainWindow()
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button("Quit Wave") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        } label: {
            Image("MenuBarIcon")
                .renderingMode(.template)
        }
    }

    /// Reliably shows the main window from MenuBarExtra.
    /// Works around SwiftUI `Window` scene + `openWindow(id:)` re-open bugs
    /// by finding and re-showing an existing window via AppKit first,
    /// falling back to `openWindow` only for the very first launch.
    private func openMainWindow() {
        // Find an existing window for the main scene (may be hidden/closed)
        let existing = NSApp.windows.first { window in
            // SwiftUI-created window titles match the Scene title; also check identifier
            window.title == "Wave" || window.identifier?.rawValue.contains("main") == true
        }

        NSApp.setActivationPolicy(.regular)

        if let window = existing {
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: "main")
        }

        NSApp.activate(ignoringOtherApps: true)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        enforceSingleInstance()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        Task { @MainActor in
            UpdaterService.shared.start()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // SwiftUI CommandGroup replacements leave empty menu headers on newer macOS.
        // Remove them directly via AppKit every time the app activates.
        guard let mainMenu = NSApp.mainMenu else { return }
        let remove = ["Format", "View", "File", "Window", "Help"]
        for title in remove {
            if let item = mainMenu.items.first(where: { $0.title == title }) {
                mainMenu.removeItem(item)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func enforceSingleInstance() {
        #if DEBUG
        return
        #endif

        guard let bundleID = Bundle.main.bundleIdentifier,
              !bundleID.hasSuffix(".debug") else { return }

        let currentPID = ProcessInfo.processInfo.processIdentifier
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != currentPID }
        guard let existing = others.first else { return }

        DispatchQueue.main.async {
            existing.activate(options: [.activateAllWindows])
            exit(0)
        }
    }
}
