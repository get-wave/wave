import SwiftUI

// Wave design system. Every view composes UI from these tokens and components;
// a raw font size, padding, radius or colour in a view is a design-system bug.
// The rules behind them are documented in DESIGN.md.

extension Color {
    static let brand = Color(red: 0x7B / 255, green: 0x6E / 255, blue: 0xF6 / 255)
    static let waveSuccess = Color.green
    static let waveWarning = Color.orange
    static let waveDanger = Color.red
}

/// The floating pill and answer card always sit on a dark heads-up surface,
/// whatever the system appearance.
enum WaveHUD {
    static let background = CGColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 0.9)
    static let border = CGColor(red: 1, green: 1, blue: 1, alpha: 0.1)
    static let surface = Color(cgColor: background)
    static let stroke = Color(cgColor: border)
    static let text = Color.white.opacity(0.95)
    static let secondaryText = Color.white.opacity(0.7)
    static let control = Color.white.opacity(0.08)
    static let cardRadius: CGFloat = 14
    static let pillRadius: CGFloat = 6
}

enum WaveFont {
    static let pageTitle = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let sheetTitle = Font.system(size: 16, weight: .semibold)
    static let sectionHeader = Font.system(size: 11, weight: .medium)
    static let body = Font.system(size: 13)
    static let bodyEmphasis = Font.system(size: 13, weight: .medium)
    static let detail = Font.system(size: 12)
    static let caption = Font.system(size: 11)
    static let mono = Font.system(size: 12, design: .monospaced)
    static let button = Font.system(size: 12, weight: .medium, design: .rounded)
    static let micro = Font.system(size: 10)
    static let chartLabel = Font.system(size: 10, weight: .medium, design: .rounded)
    static let heatmapLabel = Font.system(size: 9, design: .monospaced)
    static let emptyStateIcon = Font.system(size: 24)
    static let dismissIcon = Font.system(size: 18)
    static let heroIcon = Font.system(size: 48)
}

enum WaveSpacing {
    static let page: CGFloat = 16
    static let section: CGFloat = 20
    static let item: CGFloat = 8
    static let sheet: CGFloat = 20
    static let card: CGFloat = 12
}

enum WaveSize {
    static let appIcon: CGFloat = 20
}

enum WaveRadius {
    static let card: CGFloat = 8
    static let button: CGFloat = 6
    static let primaryButton: CGFloat = 7
}

struct WaveSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: WaveSpacing.item) {
            Text(title)
                .font(WaveFont.sectionHeader)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            content
        }
    }
}

struct WaveButtonStyle: ButtonStyle {
    enum Kind { case standard, primary, subtle, icon, iconDestructive }
    let kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        WaveButtonBody(kind: kind, configuration: configuration)
    }
}

private struct WaveButtonBody: View {
    let kind: WaveButtonStyle.Kind
    let configuration: ButtonStyleConfiguration
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        styled
            .contentShape(Rectangle())
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
    }

    @ViewBuilder
    private var styled: some View {
        switch kind {
        case .standard:
            configuration.label
                .font(WaveFont.button)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: WaveRadius.button))
        case .primary:
            configuration.label
                .font(WaveFont.button)
                .foregroundStyle(Color.brand)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.brand.opacity(0.15), in: RoundedRectangle(cornerRadius: WaveRadius.primaryButton))
        case .subtle:
            configuration.label
                .font(WaveFont.button)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
        case .icon:
            configuration.label
                .font(WaveFont.detail)
                .foregroundStyle(.secondary)
        case .iconDestructive:
            configuration.label
                .font(WaveFont.detail)
                .foregroundStyle(Color.waveDanger.opacity(0.8))
        }
    }
}

extension ButtonStyle where Self == WaveButtonStyle {
    static var wave: WaveButtonStyle { WaveButtonStyle(kind: .standard) }
    static var wavePrimary: WaveButtonStyle { WaveButtonStyle(kind: .primary) }
    static var waveSubtle: WaveButtonStyle { WaveButtonStyle(kind: .subtle) }
    static var waveIcon: WaveButtonStyle { WaveButtonStyle(kind: .icon) }
    static var waveIconDestructive: WaveButtonStyle { WaveButtonStyle(kind: .iconDestructive) }
}

extension View {
    /// A row or card. Pass a tint for selected, warning or status cards.
    func waveCard(tint: Color? = nil) -> some View {
        padding(.horizontal, WaveSpacing.card)
            .padding(.vertical, 8)
            .waveSurface(tint: tint)
    }

    /// The card surface alone, for tiles and charts that set their own padding.
    func waveSurface(tint: Color? = nil) -> some View {
        background(
                tint.map { AnyShapeStyle($0.opacity(0.08)) } ?? AnyShapeStyle(.quaternary.opacity(0.5)),
                in: RoundedRectangle(cornerRadius: WaveRadius.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: WaveRadius.card)
                    .stroke(tint?.opacity(0.2) ?? .clear, lineWidth: 1)
            )
    }

    /// Background for multi-line inputs such as TextEditor.
    func waveField() -> some View {
        padding(8)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: WaveRadius.card))
    }
}
