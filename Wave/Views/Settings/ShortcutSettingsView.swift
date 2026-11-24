import SwiftUI

struct ShortcutSettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        VStack(alignment: .leading, spacing: WaveSpacing.section) {
                WaveSection("Mode") {
                    Picker("", selection: $state.dictationMode) {
                        ForEach(DictationMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .onChange(of: appState.dictationMode) { appState.setupHotkey() }

                    Text(appState.dictationMode == .toggle
                         ? "Press the dictation shortcut once to start, again to stop."
                         : "Hold the dictation shortcut to record, release to transcribe.")
                        .font(WaveFont.detail)
                        .foregroundStyle(.secondary)
                }

                WaveSection("Actions") {
                    shortcutRow("Dictation", keyCode: $state.hotkeyKeyCode, modifiers: $state.hotkeyModifiers) { isRecording in
                        if isRecording { appState.hotkeyService.stop() } else { appState.hotkeyService.start() }
                    } onChange: { appState.setupHotkey() }

                    shortcutRow("AI Mode", keyCode: $state.aiModeKeyCode, modifiers: $state.aiModeModifiers) { isRecording in
                        if isRecording { appState.aiHotkeyService.stop() } else { appState.aiHotkeyService.start() }
                    } onChange: { appState.setupHotkey() }

                    shortcutRow("Dismiss", keyCode: $state.cancelHotkeyKeyCode, modifiers: $state.cancelHotkeyModifiers) { isRecording in
                        if isRecording { appState.cancelHotkeyService.stop() } else { appState.cancelHotkeyService.start() }
                    } onChange: { appState.setupHotkey() }

                    shortcutRow("Paste Last", keyCode: $state.pasteLastHotkeyKeyCode, modifiers: $state.pasteLastHotkeyModifiers) { isRecording in
                        if isRecording { appState.pasteLastHotkeyService.stop() } else { appState.pasteLastHotkeyService.start() }
                    } onChange: { appState.setupHotkey() }
                }
            }
            .padding(WaveSpacing.page)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func shortcutRow(
        _ label: String,
        keyCode: Binding<UInt16>,
        modifiers: Binding<UInt64>,
        onRecordingChanged: @escaping (Bool) -> Void,
        onChange: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(WaveFont.body)
                .frame(width: 72, alignment: .leading)
            ShortcutRecorderView(
                keyCode: keyCode,
                modifiers: modifiers,
                onRecordingChanged: onRecordingChanged
            )
            .onChange(of: keyCode.wrappedValue) { onChange() }
            .onChange(of: modifiers.wrappedValue) { onChange() }
            Spacer()
        }
    }

}
