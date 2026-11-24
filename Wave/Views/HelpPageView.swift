import SwiftUI

struct HelpPageView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WaveSpacing.section) {
                WaveSection("Keyboard Shortcut") {
                    helpRow("Current shortcut", value: appState.shortcutDisplayString)
                    helpRow("Push to Talk", value: "Hold shortcut to record, release to transcribe")
                    helpRow("Toggle", value: "Press to start, press again to stop")
                }

                WaveSection("How it works") {
                    Text("Wave records your voice when you press the shortcut key and transcribes it into text. The transcription is inserted at your cursor position.")
                        .font(WaveFont.detail)
                        .foregroundStyle(.secondary)
                }

                WaveSection("About") {
                    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                        helpRow("Version", value: version)
                    }
                    HStack {
                        Text("Source")
                            .font(WaveFont.detail)
                        Spacer()
                        Link("GitHub", destination: URL(string: "https://github.com/get-wave/wave")!)
                            .font(WaveFont.detail)
                    }
                    HStack {
                        Text("Community")
                            .font(WaveFont.detail)
                        Spacer()
                        Link("Discord", destination: URL(string: "https://discord.com/invite/3kUSy2d")!)
                            .font(WaveFont.detail)
                    }
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
