import SwiftUI

struct LLMModel: Identifiable {
    let id: String
    let name: String
    let inputPer1M: String
    let outputPer1M: String
    let context: String
}

// Hardcoded pricing for known models
let llmModels: [LLMModel] = [
    LLMModel(id: "openai/gpt-oss-20b",                            name: "GPT OSS 20B",             inputPer1M: "$0.075", outputPer1M: "$0.30",  context: "131k"),
    LLMModel(id: "openai/gpt-oss-120b",                           name: "GPT OSS 120B",            inputPer1M: "$0.15",  outputPer1M: "$0.60",  context: "131k"),
    LLMModel(id: "meta-llama/llama-4-scout-17b-16e-instruct",     name: "Llama 4 Scout (17B)",     inputPer1M: "$0.11",  outputPer1M: "$0.34",  context: "131k"),
    LLMModel(id: "meta-llama/llama-4-maverick-17b-128e-instruct", name: "Llama 4 Maverick (17B)",  inputPer1M: "$0.20",  outputPer1M: "$0.60",  context: "131k"),
    LLMModel(id: "llama-3.3-70b-versatile",                       name: "Llama 3.3 70B Versatile", inputPer1M: "$0.59",  outputPer1M: "$0.79",  context: "128k"),
    LLMModel(id: "llama-3.1-8b-instant",                          name: "Llama 3.1 8B Instant",    inputPer1M: "$0.05",  outputPer1M: "$0.08",  context: "128k"),
    LLMModel(id: "qwen/qwen3-32b",                                name: "Qwen 3 32B",              inputPer1M: "$0.29",  outputPer1M: "$0.59",  context: "131k"),
    LLMModel(id: "gemma-7b-it",                                   name: "Gemma 7B IT",             inputPer1M: "$0.05",  outputPer1M: "$0.08",  context: "8k"),
    LLMModel(id: "moonshotai/kimi-k2-instruct",                   name: "Kimi K2 Instruct",        inputPer1M: "$1.00",  outputPer1M: "$3.00",  context: "262k"),
]

private let pricingLookup: [String: LLMModel] = Dictionary(uniqueKeysWithValues: llmModels.map { ($0.id, $0) })

struct LLMPickerView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    private var showsPricing: Bool { appState.llmProvider == .groq }

    /// Fetched models with Groq pricing where known; Groq falls back to the built-in list.
    private var displayModels: [LLMModel] {
        let fetched = appState.fetchedModels
        if fetched.isEmpty { return showsPricing ? llmModels : [] }
        return fetched.map { id in
            if showsPricing, let known = pricingLookup[id] { return known }
            return LLMModel(id: id, name: id, inputPer1M: "\u{2014}", outputPer1M: "\u{2014}", context: "\u{2014}")
        }
    }

    var body: some View {
        @Bindable var state = appState

        VStack(alignment: .leading, spacing: WaveSpacing.section) {
            HStack {
                Text("AI Model")
                    .font(WaveFont.sheetTitle)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(WaveFont.dismissIcon)
                }
                .buttonStyle(.waveIcon)
            }

            WaveSection("Provider") {
                HStack(spacing: 6) {
                    Picker("", selection: $state.llmProvider) {
                        ForEach(AIProvider.allCases) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 160)
                    Button("Refresh") { Task { await appState.verifyProvider(appState.llmProvider) } }
                        .buttonStyle(.wave)
                        .disabled(!appState.hasCredentials(appState.llmProvider))
                    Spacer()
                }
                Text(providerHint)
                    .font(WaveFont.caption)
                    .foregroundStyle(appState.hasCredentials(appState.llmProvider) ? .secondary : Color.waveWarning)
            }

            WaveSection("Model") {
                TextField("Model name", text: $state.aiModel)
                    .textFieldStyle(.roundedBorder)
                    .font(WaveFont.mono)

                if !displayModels.isEmpty {
                    if showsPricing {
                        HStack(spacing: 0) {
                            Text("Model")
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("Input/1M")
                                .frame(width: 70, alignment: .trailing)
                            Text("Output/1M")
                                .frame(width: 75, alignment: .trailing)
                            Text("Context")
                                .frame(width: 60, alignment: .trailing)
                            Spacer().frame(width: 60)
                        }
                        .font(WaveFont.sectionHeader)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, WaveSpacing.card)
                    }

                    ScrollView {
                        VStack(spacing: 6) {
                            ForEach(displayModels) { model in
                                modelRow(model)
                            }
                        }
                    }
                    .frame(maxHeight: 180)
                }
            }

            WaveSection("AI Mode Prompt") {
                TextEditor(text: $state.llmSystemPrompt)
                    .font(WaveFont.detail)
                    .frame(height: 64)
                    .scrollContentBackground(.hidden)
                    .waveField()
            }
        }
        .padding(WaveSpacing.sheet)
    }

    private var providerHint: String {
        let provider = appState.llmProvider
        if !appState.hasCredentials(provider) {
            return "Set up \(provider.displayName) under Models \u{2192} Connections to use it."
        }
        if provider.runsOnThisMac {
            return "Runs on this Mac. Start \(provider.displayName) and load a model, then press Refresh."
        }
        return "Text you send to AI Mode and transforms goes to \(provider.displayName)."
    }

    @ViewBuilder
    private func modelRow(_ model: LLMModel) -> some View {
        let isSelected = appState.aiModel == model.id

        HStack(spacing: 0) {
            Text(model.name)
                .font(isSelected ? WaveFont.bodyEmphasis : WaveFont.body)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
            if showsPricing {
                Text(model.inputPer1M)
                    .font(WaveFont.detail.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 70, alignment: .trailing)
                Text(model.outputPer1M)
                    .font(WaveFont.detail.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 75, alignment: .trailing)
                Text(model.context)
                    .font(WaveFont.detail)
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .trailing)
            }
            HStack {
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(WaveFont.body)
                        .foregroundStyle(Color.waveSuccess)
                } else {
                    Button("Use") {
                        appState.aiModel = model.id
                    }
                    .buttonStyle(.wave)
                }
            }
            .frame(width: 60)
        }
        .waveCard(tint: isSelected ? .brand : nil)
    }
}
