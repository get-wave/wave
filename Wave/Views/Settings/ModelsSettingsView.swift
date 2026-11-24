import SwiftUI

struct ModelsSettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var showProviderPicker = false
    @State private var showLLMPicker = false
    @State private var isEditingKey = false

    var body: some View {
        @Bindable var state = appState

        VStack(alignment: .leading, spacing: WaveSpacing.section) {
                WaveSection("Active Models") {
                    modelRow(
                        icon: "waveform",
                        label: "Audio",
                        value: audioModelLabel,
                        action: { showProviderPicker = true }
                    )
                    modelRow(
                        icon: "brain",
                        label: "LLM",
                        value: aiModelLabel,
                        action: (appState.transcriptionProvider == .groq && !appState.groqAPIKey.isEmpty) ? { showLLMPicker = true } : nil
                    )
                }

                WaveSection("Groq") {
                    Toggle("Use Groq API", isOn: Binding(
                        get: { appState.transcriptionProvider == .groq },
                        set: { appState.transcriptionProvider = $0 ? .groq : .local }
                    ))
                    .font(WaveFont.body)

                    if appState.transcriptionProvider == .groq {
                        if !appState.groqAPIKey.isEmpty && !isEditingKey {
                            HStack(spacing: 6) {
                                Text(maskedAPIKey)
                                    .font(WaveFont.mono)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button("Edit") { isEditingKey = true }
                                    .buttonStyle(.wave)
                            }
                        } else {
                            HStack(spacing: 6) {
                                TextField("API Key (gsk_...)", text: Binding(
                                    get: { appState.groqAPIKey },
                                    set: { appState.groqAPIKey = $0 }
                                ))
                                .textFieldStyle(.roundedBorder)
                                .font(WaveFont.mono)
                                Button("Save") {
                                    Task {
                                        await appState.verifyAndFetchGroqModels()
                                        if appState.groqAPIStatus == .operational {
                                            isEditingKey = false
                                        }
                                    }
                                }
                                .buttonStyle(.wavePrimary)
                                .disabled(appState.groqAPIKey.isEmpty || appState.groqAPIStatus == .checking)
                            }
                        }

                        groqStatusView
                    }
                }

                WaveSection("LLM System Prompt") {
                    TextEditor(text: $state.llmSystemPrompt)
                        .font(WaveFont.detail)
                        .frame(minHeight: 80, maxHeight: 120)
                        .scrollContentBackground(.hidden)
                        .waveField()
                    Text("Instructions for the AI when using AI Mode shortcut.")
                        .font(WaveFont.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(WaveSpacing.page)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $showProviderPicker) {
            ProviderPickerView()
                .environment(appState)
                .frame(width: 420)
        }
        .sheet(isPresented: $showLLMPicker) {
            LLMPickerView()
                .environment(appState)
                .frame(width: 520)
        }
    }

    @ViewBuilder
    private var groqStatusView: some View {
        switch appState.groqAPIStatus {
        case .unknown:
            EmptyView()
        case .checking:
            HStack(spacing: 5) {
                ProgressView().scaleEffect(0.6).frame(width: 8, height: 8)
                Text("Verifying...")
                    .font(WaveFont.caption)
                    .foregroundStyle(.secondary)
            }
        case .operational:
            HStack(spacing: 5) {
                Circle().fill(Color.waveSuccess).frame(width: 6, height: 6)
                Text("Operational")
                    .font(WaveFont.caption)
                    .foregroundStyle(Color.waveSuccess)
            }
        case .error(let msg):
            HStack(spacing: 5) {
                Circle().fill(Color.waveDanger).frame(width: 6, height: 6)
                Text(msg)
                    .font(WaveFont.caption)
                    .foregroundStyle(Color.waveDanger)
            }
        }
    }

    private var maskedAPIKey: String {
        let key = appState.groqAPIKey
        guard key.count > 10 else { return key }
        let prefix = String(key.prefix(6))
        let suffix = String(key.suffix(4))
        return "\(prefix)...\(suffix)"
    }

    private var audioModelLabel: String {
        switch appState.transcriptionProvider {
        case .local:
            if let path = appState.modelManager.selectedModelPath {
                return "Local \u{00B7} \(URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent)"
            }
            return "No model selected"
        case .groq:
            return "Groq \u{00B7} \(appState.groqModel)"
        }
    }

    private var aiModelLabel: String {
        llmModels.first(where: { $0.id == appState.aiModel })?.name ?? appState.aiModel
    }


    @ViewBuilder
    private func modelRow(icon: String, label: String, value: String, action: (() -> Void)?) -> some View {
        HStack {
            Image(systemName: icon)
                .font(WaveFont.detail)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(label)
                .font(WaveFont.bodyEmphasis)
            Spacer()
            Text(value)
                .font(WaveFont.detail)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if let action {
                Button("Change\u{2026}") { action() }
                    .buttonStyle(.wave)
            }
        }
        .waveCard()
        .opacity(action == nil ? 0.5 : 1)
    }
}
