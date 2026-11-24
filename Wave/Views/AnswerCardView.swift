import SwiftUI

struct AnswerCardView: View {
    let text: String
    let onCopy: () -> Void
    let onClose: () -> Void

    @State private var didCopy = false

    private let cardWidth: CGFloat = 360
    private let textMaxHeight: CGFloat = 220
    // If text exceeds this many characters, use a scrolling view. Otherwise the card fits the text.
    private let scrollThreshold = 400

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if text.count > scrollThreshold {
                ScrollView(.vertical, showsIndicators: true) {
                    Text(text)
                        .font(WaveFont.body)
                        .foregroundStyle(WaveHUD.text)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.trailing, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: textMaxHeight)
            } else {
                Text(text)
                    .font(WaveFont.body)
                    .foregroundStyle(WaveHUD.text)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 6) {
                Button(action: {
                    onCopy()
                    withAnimation(.easeInOut(duration: 0.15)) { didCopy = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        withAnimation(.easeInOut(duration: 0.2)) { didCopy = false }
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                            .font(WaveFont.chartLabel)
                        Text(didCopy ? "Copied" : "Copy")
                            .font(WaveFont.sectionHeader)
                    }
                    .foregroundStyle(WaveHUD.text)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: WaveRadius.button)
                            .fill(WaveHUD.control)
                    )
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(WaveFont.chartLabel)
                        .foregroundStyle(WaveHUD.secondaryText)
                        .frame(width: 22, height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: WaveRadius.button)
                                .fill(WaveHUD.control)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(WaveSpacing.card)
        .frame(width: cardWidth)
        .background(
            RoundedRectangle(cornerRadius: WaveHUD.cardRadius)
                .fill(WaveHUD.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: WaveHUD.cardRadius)
                        .stroke(WaveHUD.stroke, lineWidth: 0.5)
                )
        )
    }
}
