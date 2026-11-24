import SwiftUI

struct HowToUseView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WaveSpacing.section) {
                WaveSection("Dictation") {
                    helpRow("Shortcut", value: appState.shortcutDisplayString)
                    helpRow("Push to Talk", value: "Hold shortcut to record, release to transcribe")
                    helpRow("Toggle", value: "Press to start, press again to stop")
                }

                WaveSection("AI Mode") {
                    helpRow("Shortcut", value: appState.aiShortcutDisplayString)
                    helpRow("How it works", value: "Transcribes your voice then sends it to the AI model for a direct answer")
                }

                WaveSection("How it works") {
                    Text("Wave records your voice when you press the shortcut key and transcribes it into text. The transcription is inserted at your cursor position.")
                        .font(WaveFont.detail)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(WaveSpacing.page)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }


    private func helpRow(_ label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(WaveFont.detail)
            Spacer()
            Text(value)
                .font(WaveFont.detail)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}
