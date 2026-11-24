import SwiftUI

struct TransformsView: View {
    @Environment(AppState.self) private var appState
    @State private var editingTransform: TransformProfile?
    @State private var isAddingTransform = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WaveSpacing.section) {
                Text("Select text in any app, then press a shortcut to rewrite it in place. Polish is always available; add up to 9 of your own.")
                    .font(WaveFont.detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                WaveSection("Your Transforms") {
                    ForEach(appState.transformManager.allTransforms) { transform in
                        transformRow(transform)
                    }

                    Button {
                        isAddingTransform = true
                    } label: {
                        Label("Add Transform", systemImage: "plus")
                    }
                    .buttonStyle(.wavePrimary)
                    .disabled(appState.transformManager.transforms.count >= TransformManager.maxTransformCount)
                }

                WaveSection("Automatic Polish") {
                    Toggle("Polish dictations before pasting", isOn: Binding(
                        get: { appState.autoPolishDictations },
                        set: { appState.autoPolishDictations = $0 }
                    ))
                    .font(WaveFont.body)
                    .disabled(!appState.isLLMReady)

                    Text(appState.isLLMReady
                         ? "Uses \(appState.llmProvider.displayName) after transcription. If polishing fails, the original transcription is pasted."
                         : "Requires an AI provider, set up in Models. If polishing fails, the original transcription is pasted.")
                        .font(WaveFont.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(WaveSpacing.page)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .sheet(item: $editingTransform) { transform in
            TransformEditorView(transform: transform) { updated in
                appState.transformManager.update(updated)
                appState.setupHotkey()
            }
            .environment(appState)
            .frame(width: 420)
        }
        .sheet(isPresented: $isAddingTransform) {
            TransformEditorView(transform: nil) { name, prompt, keyCode, modifiers in
                appState.transformManager.add(name: name, prompt: prompt, keyCode: keyCode, modifiers: modifiers)
                appState.setupHotkey()
            }
            .environment(appState)
            .frame(width: 420)
        }
    }

    @ViewBuilder
    private func transformRow(_ transform: TransformProfile) -> some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(transform.name)
                    .font(WaveFont.bodyEmphasis)
                Text(transform.keyCode == 0 ? "Unassigned" : KeyCodeMapping.displayString(
                    keyCode: transform.keyCode,
                    modifiers: CGEventFlags(rawValue: transform.modifiers)
                ))
                .font(WaveFont.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { transform.isEnabled },
                set: { enabled in
                    var updated = transform
                    updated.isEnabled = enabled
                    appState.transformManager.update(updated)
                    appState.setupHotkey()
                }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)

            Button("Edit") {
                editingTransform = transform
            }
            .buttonStyle(.wave)

            if !transform.isBuiltIn {
                Button {
                    appState.transformManager.remove(transform)
                    appState.setupHotkey()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.waveIconDestructive)
            }
        }
        .waveCard()
        .opacity(transform.isEnabled ? 1 : 0.55)
    }
}

private struct TransformEditorView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let transform: TransformProfile?
    let onUpdate: ((TransformProfile) -> Void)?
    let onAdd: ((String, String, UInt16, UInt64) -> Void)?

    @State private var name: String
    @State private var prompt: String
    @State private var keyCode: UInt16
    @State private var modifiers: UInt64
    @State private var validationMessage: String?

    init(transform: TransformProfile?, onUpdate: @escaping (TransformProfile) -> Void) {
        self.transform = transform
        self.onUpdate = onUpdate
        self.onAdd = nil
        _name = State(initialValue: transform?.name ?? "")
        _prompt = State(initialValue: transform?.prompt ?? "")
        _keyCode = State(initialValue: transform?.keyCode ?? 0)
        _modifiers = State(initialValue: transform?.modifiers ?? 0)
    }

    init(transform: TransformProfile?, onAdd: @escaping (String, String, UInt16, UInt64) -> Void) {
        self.transform = transform
        self.onUpdate = nil
        self.onAdd = onAdd
        _name = State(initialValue: "")
        _prompt = State(initialValue: "")
        _keyCode = State(initialValue: 0)
        _modifiers = State(initialValue: 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: WaveSpacing.section) {
            Text(transform == nil ? "New Transform" : "Edit Transform")
                .font(WaveFont.sheetTitle)

            WaveSection("Name") {
                TextField("Make More Formal", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .font(WaveFont.body)
            }

            WaveSection("Instruction") {
                TextEditor(text: $prompt)
                    .font(WaveFont.mono)
                    .frame(height: 110)
                    .scrollContentBackground(.hidden)
                    .waveField()
                Text("Be specific about the task, output format, and constraints. Keep one transformation per shortcut. Return only the result.")
                    .font(WaveFont.caption)
                    .foregroundStyle(.secondary)
            }

            WaveSection("Shortcut") {
                ShortcutRecorderView(
                    keyCode: $keyCode,
                    modifiers: $modifiers,
                    onRecordingChanged: { isRecording in
                        if isRecording {
                            appState.stopTransformHotkeys()
                        } else {
                            appState.setupHotkey()
                        }
                    }
                )
            }

            if let validationMessage {
                Text(validationMessage)
                    .font(WaveFont.caption)
                    .foregroundStyle(Color.waveDanger)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.waveSubtle)
                Button(transform == nil ? "Add" : "Save") {
                    save()
                }
                .buttonStyle(.wavePrimary)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                          || prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                          || keyCode == 0)
            }
        }
        .padding(WaveSpacing.sheet)
    }

    private func save() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty, !cleanPrompt.isEmpty, keyCode != 0 else { return }
        guard appState.isTransformShortcutAvailable(keyCode: keyCode, modifiers: modifiers, excluding: transform?.id) else {
            validationMessage = "That shortcut is already used by another Wave action."
            return
        }

        if let transform {
            var updated = transform
            updated.name = cleanName
            updated.prompt = cleanPrompt
            updated.keyCode = keyCode
            updated.modifiers = modifiers
            onUpdate?(updated)
        } else {
            onAdd?(cleanName, cleanPrompt, keyCode, modifiers)
        }
        dismiss()
    }
}
