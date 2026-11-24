import SwiftUI

struct ModelsSettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var showProviderPicker = false
    @State private var showLLMPicker = false
    @State private var editingProvider: AIProvider?
    @State private var draftKey = ""
    @State private var draftBaseURL = ""

    var body: some View {
        VStack(alignment: .leading, spacing: WaveSpacing.section) {
            WaveSection("Active Models") {
                modelRow(
                    icon: "waveform",
                    label: "Speech",
                    value: speechModelLabel,
                    action: { showProviderPicker = true }
                )
                modelRow(
                    icon: "brain",
                    label: "AI",
                    value: aiModelLabel,
                    action: { showLLMPicker = true }
                )
            }

            WaveSection("Connections") {
                ForEach(appState.providersInUse) { provider in
                    if editingProvider == provider {
                        connectionEditor(provider)
                    } else {
                        connectionRow(provider)
                    }
                }
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

    // MARK: - Connections

    @ViewBuilder
    private func connectionRow(_ provider: AIProvider) -> some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(provider.displayName)
                        .font(WaveFont.bodyEmphasis)
                    statusBadge(provider)
                }
                Text(connectionDetail(provider))
                    .font(WaveFont.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if provider.runsOnThisMac {
                Button("Check") { Task { await appState.verifyProvider(provider) } }
                    .buttonStyle(.wave)
            } else {
                Button(appState.hasCredentials(provider) ? "Edit" : "Set Up") { startEditing(provider) }
                    .buttonStyle(appState.hasCredentials(provider) ? .wave : .wavePrimary)
            }
        }
        .waveCard()
    }

    @ViewBuilder
    private func connectionEditor(_ provider: AIProvider) -> some View {
        VStack(alignment: .leading, spacing: WaveSpacing.item) {
            Text(provider.displayName)
                .font(WaveFont.bodyEmphasis)
            if provider == .custom {
                TextField("Base URL (https://host/v1)", text: $draftBaseURL)
                    .textFieldStyle(.roundedBorder)
                    .font(WaveFont.mono)
            }
            if provider.acceptsAPIKey {
                SecureField(provider.keyPlaceholder, text: $draftKey)
                    .textFieldStyle(.roundedBorder)
                    .font(WaveFont.mono)
            }
            HStack(spacing: 6) {
                Spacer()
                Button("Cancel") { editingProvider = nil }
                    .buttonStyle(.waveSubtle)
                Button("Save") { save(provider) }
                    .buttonStyle(.wavePrimary)
                    .disabled(provider.requiresAPIKey && draftKey.trimmingCharacters(in: .whitespaces).isEmpty
                              || provider == .custom && draftBaseURL.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .waveCard()
    }

    @ViewBuilder
    private func statusBadge(_ provider: AIProvider) -> some View {
        switch appState.providerStatus[provider] {
        case .checking:
            ProgressView().controlSize(.mini)
        case .operational:
            Circle().fill(Color.waveSuccess).frame(width: 6, height: 6)
        case .error:
            Circle().fill(Color.waveDanger).frame(width: 6, height: 6)
        case .unknown, nil:
            EmptyView()
        }
    }

    private func connectionDetail(_ provider: AIProvider) -> String {
        if case .error(let message) = appState.providerStatus[provider] { return message }
        let use = [
            appState.transcriptionProvider.cloudProvider == provider ? "Speech" : nil,
            appState.llmProvider == provider ? "AI" : nil,
        ].compactMap { $0 }.joined(separator: " and ")
        if provider.runsOnThisMac { return "\(use) · on this Mac · no key needed" }
        if !appState.hasCredentials(provider) { return "\(use) · not set up" }
        let key = appState.apiKey(for: provider)
        guard !key.isEmpty else { return "\(use) · \(appState.baseURL(for: provider))" }
        return "\(use) · \(key.count > 10 ? "\(key.prefix(6))…\(key.suffix(4))" : "key set")"
    }

    private func startEditing(_ provider: AIProvider) {
        draftKey = appState.apiKey(for: provider)
        draftBaseURL = appState.customBaseURL
        editingProvider = provider
    }

    private func save(_ provider: AIProvider) {
        appState.apiKeys[provider] = draftKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if provider == .custom { appState.customBaseURL = draftBaseURL.trimmingCharacters(in: .whitespacesAndNewlines) }
        editingProvider = nil
        Task { await appState.verifyProvider(provider) }
    }

    // MARK: - Active models

    private var speechModelLabel: String {
        if let cloud = appState.transcriptionProvider.cloudProvider {
            return "\(cloud.displayName) \u{00B7} \(appState.cloudTranscriptionModel)"
        }
        if let path = appState.modelManager.selectedModelPath {
            return "Local \u{00B7} \(URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent)"
        }
        return "No model selected"
    }

    private var aiModelLabel: String {
        let model = llmModels.first(where: { $0.id == appState.aiModel })?.name ?? appState.aiModel
        return "\(appState.llmProvider.displayName) \u{00B7} \(model.isEmpty ? "choose a model" : model)"
    }

    @ViewBuilder
    private func modelRow(icon: String, label: String, value: String, action: @escaping () -> Void) -> some View {
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
                .truncationMode(.middle)
            Button("Change\u{2026}") { action() }
                .buttonStyle(.wave)
        }
        .waveCard()
    }
}
