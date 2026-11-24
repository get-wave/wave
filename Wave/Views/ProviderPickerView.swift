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

            Picker("", selection: $state.transcriptionProvider) {
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
        ScrollView {
            VStack(spacing: 8) {
                ForEach(WhisperModel.available) { model in
                    modelRow(model)
                }
            }
        }
        .frame(maxHeight: 260)

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
                    Task { await appState.loadSelectedModel() }
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

    // MARK: - Local model row

    @ViewBuilder
    private func modelRow(_ model: WhisperModel) -> some View {
        let isDownloaded = appState.modelManager.isDownloaded(model)
        let isSelected = appState.modelManager.selectedModelPath == appState.modelManager.fileURL(for: model).path
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
                        Task { await appState.loadSelectedModel() }
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
                    appState.modelManager.download(model)
                }
                .buttonStyle(.wave)
            }
        }
        .waveCard()
    }
}
