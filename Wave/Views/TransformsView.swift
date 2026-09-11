import SwiftUI

struct TransformsView: View {
    @Environment(AppState.self) private var appState
    @State private var editingTransform: TransformProfile?
    @State private var isAddingTransform = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            section("Transforms") {
                Text("Select text in any app, then use a shortcut to rewrite it in place. Polish is the base action; you can configure up to 9 shortcut slots.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                ForEach(appState.transformManager.allTransforms) { transform in
                    transformRow(transform)
                }

                Button {
                    isAddingTransform = true
                } label: {
                    Label("Add Transform", systemImage: "plus")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
                .buttonStyle(.plain)
                .foregroundStyle(appState.transformManager.transforms.count < TransformManager.maxTransformCount ? Color.brand : .secondary)
                .disabled(appState.transformManager.transforms.count >= TransformManager.maxTransformCount)
            }

            section("Automatic Polish") {
                Toggle("Polish dictations before pasting", isOn: Binding(
                    get: { appState.autoPolishDictations },
                    set: { appState.autoPolishDictations = $0 }
                ))
                .font(.system(size: 13))
                .disabled(appState.groqAPIKey.isEmpty)

                Text(appState.groqAPIKey.isEmpty
                     ? "Requires a Groq API key. If polishing fails, the original transcription is pasted."
                     : "Uses Groq after transcription. If polishing fails, the original transcription is pasted.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(transform.name)
                    .font(.system(size: 12, weight: .medium))
                Text(transform.keyCode == 0 ? "Unassigned" : KeyCodeMapping.displayString(
                    keyCode: transform.keyCode,
                    modifiers: CGEventFlags(rawValue: transform.modifiers)
                ))
                .font(.system(size: 10, design: .rounded))
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

            Button("Edit") {
                editingTransform = transform
            }
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            .buttonStyle(.plain)

            if !transform.isBuiltIn {
                Button {
                    appState.transformManager.remove(transform)
                    appState.setupHotkey()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
        .opacity(transform.isEnabled ? 1 : 0.55)
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            content()
        }
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
        VStack(alignment: .leading, spacing: 16) {
            Text(transform == nil ? "New Transform" : "Edit Transform")
                .font(.system(size: 16, weight: .semibold))

            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 6) {
                Text("Instruction")
                    .font(.system(size: 12, weight: .medium))
                TextEditor(text: $prompt)
                    .font(.system(size: 12))
                    .frame(height: 110)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                Text("Be specific about the task, output format, and constraints. Keep one transformation per shortcut. Return only the result.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Shortcut")
                    .font(.system(size: 12, weight: .medium))
                Spacer()
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
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                Button(transform == nil ? "Add" : "Save") {
                    save()
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.brand.opacity(0.15), in: RoundedRectangle(cornerRadius: 7))
                .foregroundStyle(Color.brand)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                          || prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                          || keyCode == 0)
            }
        }
        .padding(20)
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
