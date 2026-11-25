import SwiftUI
import UniformTypeIdentifiers

struct ProviderPickerView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var state = appState

        VStack(alignment: .leading, spacing: WaveSpacing.section) {
            HStack {
                Text("Speech Model")
                    .font(WaveFont.sheetTitle)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(WaveFont.dismissIcon)
                }
                .buttonStyle(.waveIcon)
            }

            Picker("", selection: Binding(
                get: { appState.transcriptionProvider.isOnDevice ? .local : appState.transcriptionProvider },
                set: { choice in
                    guard !(choice == .local && appState.transcriptionProvider.isOnDevice) else { return }
                    appState.transcriptionProvider = choice
                }
            )) {
                Text("On this Mac").tag(TranscriptionProvider.local)
                Text("Groq").tag(TranscriptionProvider.groq)
                Text("OpenAI").tag(TranscriptionProvider.openai)
                Text("Custom").tag(TranscriptionProvider.custom)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if let cloud = appState.transcriptionProvider.cloudProvider {
                cloudContent(cloud)
            } else {
                localContent
            }
        }
        .padding(WaveSpacing.sheet)
    }

    // MARK: - Local

    @ViewBuilder
    private var localContent: some View {
        WaveSection("Parakeet \u{00B7} fastest") {
            ForEach(ParakeetModel.allCases) { model in
                parakeetRow(model)
            }
        }

        WaveSection("Whisper \u{00B7} 99 languages") {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(WhisperModel.available) { model in
                        modelRow(model)
                    }
                }
            }
            .frame(maxHeight: 200)
        }

        HStack {
            Text("Or locate a model file:")
                .font(WaveFont.body)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Choose File...") {
                let panel = NSOpenPanel()
                panel.allowedContentTypes = [.init(filenameExtension: "bin")!]
                panel.canChooseDirectories = false
                panel.allowsMultipleSelection = false
                if panel.runModal() == .OK, let url = panel.url {
                    appState.modelManager.selectModelAtPath(url.path)
                    useWhisper()
                }
            }
            .buttonStyle(.wave)
        }
    }

    // MARK: - Cloud

    @ViewBuilder
    private func cloudContent(_ provider: AIProvider) -> some View {
        @Bindable var state = appState

        WaveSection("Model") {
            if provider == .custom {
                TextField("Model name", text: $state.cloudTranscriptionModel)
                    .textFieldStyle(.roundedBorder)
                    .font(WaveFont.mono)
            } else {
                Picker("", selection: $state.cloudTranscriptionModel) {
                    ForEach(provider.transcriptionModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
                .font(WaveFont.body)
            }

            Text(appState.hasCredentials(provider)
                 ? "Audio is sent to \(provider.displayName) for transcription."
                 : "Set up \(provider.displayName) under Models \u{2192} Connections to use it.")
                .font(WaveFont.caption)
                .foregroundStyle(appState.hasCredentials(provider) ? .secondary : Color.waveWarning)
        }
    }

    private func useWhisper() {
        if appState.transcriptionProvider == .local {
            Task { await appState.loadSelectedModel() }
        } else {
            appState.transcriptionProvider = .local
        }
    }

    // MARK: - Parakeet row

    @ViewBuilder
    private func parakeetRow(_ model: ParakeetModel) -> some View {
        let isCurrent = appState.transcriptionProvider == .parakeet && appState.parakeetModel == model
        let isDownloaded = appState.parakeetService.isDownloaded(model)

        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.name)
                    .font(WaveFont.bodyEmphasis)
                Text(model.detail)
                    .font(WaveFont.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isCurrent, let progress = appState.parakeetDownloadProgress {
                HStack(spacing: 8) {
                    ProgressView(value: progress)
                        .frame(width: 60)
                    Text("\(Int(progress * 100))%")
                        .font(WaveFont.caption.monospacedDigit())
                }
            } else if isCurrent && !appState.isParakeetLoaded {
                ProgressView().controlSize(.small)
            } else if isCurrent {
                HStack(spacing: 8) {
                    Label("Active", systemImage: "checkmark.circle.fill")
                        .font(WaveFont.detail)
                        .foregroundStyle(Color.waveSuccess)
                    Button(action: { appState.deleteParakeet(model) }) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.waveIconDestructive)
                }
            } else {
                HStack(spacing: 6) {
                    Button(isDownloaded ? "Use" : "Download") { appState.selectParakeet(model) }
                        .buttonStyle(.wave)
                        .disabled(!isDownloaded && appState.offlineMode)
                        .help(!isDownloaded && appState.offlineMode ? "Turn off offline mode to download" : "")
                    if isDownloaded {
                        Button(action: { appState.deleteParakeet(model) }) {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.waveIconDestructive)
                    }
                }
            }
        }
        .waveCard(tint: isCurrent ? .brand : nil)
    }

    // MARK: - Local model row

    @ViewBuilder
    private func modelRow(_ model: WhisperModel) -> some View {
        let isDownloaded = appState.modelManager.isDownloaded(model)
        let isSelected = appState.transcriptionProvider == .local
            && appState.modelManager.selectedModelPath == appState.modelManager.fileURL(for: model).path
        let isDownloading = appState.modelManager.downloadingModelId == model.id.uuidString

        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(model.name)
                        .font(WaveFont.bodyEmphasis)
                    Text(model.size)
                        .font(WaveFont.caption)
                        .foregroundStyle(.secondary)
                }
                Text(model.type)
                    .font(WaveFont.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isSelected {
                HStack(spacing: 8) {
                    Label("Active", systemImage: "checkmark.circle.fill")
                        .font(WaveFont.detail)
                        .foregroundStyle(Color.waveSuccess)
                    Button(action: {
                        appState.modelManager.deleteModel(model)
                        appState.transcriptionService.unloadModel()
                        appState.isModelLoaded = false
                    }) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.waveIconDestructive)
                }
            } else if isDownloaded {
                HStack(spacing: 6) {
                    Button("Use") {
                        appState.modelManager.selectModel(model)
                        useWhisper()
                    }
                    .buttonStyle(.wave)
                    Button(action: { appState.modelManager.deleteModel(model) }) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.waveIconDestructive)
                }
            } else if isDownloading {
                let progress = appState.modelManager.downloadProgress[model.id.uuidString] ?? 0
                HStack(spacing: 8) {
                    ProgressView(value: progress)
                        .frame(width: 60)
                    Text("\(Int(progress * 100))%")
                        .font(WaveFont.caption.monospacedDigit())
                    Button(action: { appState.modelManager.cancelDownload() }) {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.waveIcon)
                }
            } else {
                Button("Download") {
                    appState.downloadWhisperModel(model)
                }
                .buttonStyle(.wave)
                .disabled(appState.offlineMode)
                .help(appState.offlineMode ? "Turn off offline mode to download" : "")
            }
        }
        .waveCard()
    }
}
