import SwiftUI
import Combine

struct GeneralSettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var micGranted = PermissionService.isMicrophoneAuthorized()
    @State private var accessibilityGranted = PermissionService.isAccessibilityGranted()

    var body: some View {
        @Bindable var state = appState

        VStack(alignment: .leading, spacing: WaveSpacing.section) {
                // Transcription
                WaveSection("Transcription") {
                    Toggle("Include punctuation", isOn: $state.includePunctuation)
                        .font(WaveFont.body)
                    Toggle("Mute system audio while dictating", isOn: $state.muteSystemAudio)
                        .font(WaveFont.body)
                    Toggle("Hide pill when idle", isOn: $state.hideIdlePill)
                        .font(WaveFont.body)
                    Toggle("Show in Dock", isOn: $state.showInDock)
                        .font(WaveFont.body)
                    Picker("Language", selection: $state.transcriptionLanguage) {
                        ForEach(Self.languages, id: \.code) { lang in
                            Text(lang.label).tag(lang.code)
                        }
                    }
                    .font(WaveFont.body)
                }

                // Microphone
                WaveSection("Microphone") {
                    Picker("Input", selection: Binding(
                        get: { appState.selectedMicUID },
                        set: { appState.selectedMicUID = $0 }
                    )) {
                        Text("System Default").tag("")
                        ForEach(appState.microphoneManager.devices) { device in
                            Text(device.name).tag(device.uid)
                        }
                    }
                    .labelsHidden()
                    .onAppear { appState.microphoneManager.refresh() }
                }

                WaveSection("Privacy") {
                    Toggle("Offline mode", isOn: $state.offlineMode)
                        .font(WaveFont.body)
                    Text("Wave makes no network requests except checking for updates. Speech must run on this Mac; AI features work with Ollama or LM Studio.")
                        .font(WaveFont.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(appState.offlineModeImpacts, id: \.self) { impact in
                        Label(impact, systemImage: "exclamationmark.triangle.fill")
                            .font(WaveFont.caption)
                            .foregroundStyle(Color.waveWarning)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                // Permissions
                if !micGranted || !accessibilityGranted {
                    WaveSection("Permissions") {
                        if !micGranted {
                            permissionRow(
                                icon: "mic.fill",
                                label: "Microphone",
                                detail: "Required to record speech",
                                action: {
                                    Task { await PermissionService.requestMicrophoneAccess() }
                                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
                                }
                            )
                        }
                        if !accessibilityGranted {
                            permissionRow(
                                icon: "hand.raised.fill",
                                label: "Accessibility",
                                detail: "Required for global shortcut",
                                action: {
                                    PermissionService.requestAccessibility()
                                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                                }
                            )
                        }
                    }
                }
            }
            .padding(WaveSpacing.page)
        .onReceive(Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()) { _ in
            micGranted = PermissionService.isMicrophoneAuthorized()
            accessibilityGranted = PermissionService.isAccessibilityGranted()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Language list

    static let languages: [(code: String, label: String)] = [
        ("auto", "Auto Detect"),
        ("en", "English"),
        ("es", "Spanish"),
        ("fr", "French"),
        ("de", "German"),
        ("it", "Italian"),
        ("pt", "Portuguese"),
        ("nl", "Dutch"),
        ("pl", "Polish"),
        ("ru", "Russian"),
        ("ja", "Japanese"),
        ("zh", "Chinese"),
        ("ko", "Korean"),
        ("ar", "Arabic"),
        ("hi", "Hindi"),
        ("tr", "Turkish"),
        ("sv", "Swedish"),
        ("da", "Danish"),
        ("fi", "Finnish"),
        ("no", "Norwegian"),
    ]


    @ViewBuilder
    private func permissionRow(icon: String, label: String, detail: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(Color.waveWarning)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(WaveFont.bodyEmphasis)
                Text(detail)
                    .font(WaveFont.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Allow") { action() }
                .buttonStyle(.wave)
        }
        .waveCard(tint: .waveWarning)
    }
}
