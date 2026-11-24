import SwiftUI

struct DictionaryEditorView: View {
    @Environment(AppState.self) private var appState
    @State private var newTerm = ""

    var body: some View {
        @Bindable var state = appState

        VStack(alignment: .leading, spacing: 0) {
            if state.customVocabulary.isEmpty {
                Text("No terms yet. Add technical names,\nlibrary names, or jargon below.")
                    .foregroundStyle(.secondary)
                    .font(WaveFont.body)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(state.customVocabulary, id: \.self) { term in
                            HStack {
                                Text(term)
                                    .font(WaveFont.body)
                                Spacer()
                                Button {
                                    state.customVocabulary.removeAll { $0 == term }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                }
                                .buttonStyle(.waveIcon)
                            }
                            .waveCard()
                        }
                    }
                    .padding(WaveSpacing.page)
                }
            }

            HStack {
                TextField("Add term\u{2026}", text: $newTerm)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addTerm(to: &state.customVocabulary) }
                Button("Add") { addTerm(to: &state.customVocabulary) }
                    .buttonStyle(.wave)
                    .disabled(newTerm.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(maxHeight: .infinity)
    }

    private func addTerm(to list: inout [String]) {
        let term = newTerm.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty, !list.contains(term) else { return }
        list.append(term)
        newTerm = ""
    }
}
