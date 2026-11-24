import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WaveSpacing.section) {
                WaveSection("Wave") {
                    Text("Wave is a macOS app that turns your voice into text, anywhere you type. Press a shortcut, speak, and your words appear at the cursor — no setup, no interruptions.")
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
                    HStack {
                        Text("Feedback")
                            .font(WaveFont.detail)
                        Spacer()
                        Link("@monawwarx", destination: URL(string: "https://x.com/monawwarx")!)
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
