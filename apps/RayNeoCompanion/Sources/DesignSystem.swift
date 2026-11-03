import SwiftUI
import UIKit

// MARK: - Palette
// Neutral system colours with a system-blue accent. Every colour adapts to light and dark
// appearance. Legacy names (`green`, `mint`, `ink`) are kept so call sites stay unchanged.
enum Palette {
    private static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }

    /// Grouped page background behind the glass layer.
    static let background = Color(.systemGroupedBackground)
    /// Primary text.
    static let ink = Color(.label)
    /// Secondary text.
    static let muted = Color(.secondaryLabel)
    /// Hairlines and quiet fills.
    static let line = Color(.separator)
    /// System blue accent (icons, tint, prominent controls).
    static let accent = Color(.systemBlue)
    /// Legacy name: now the accent colour.
    static let green = accent
    /// Accent for small text; darker in light mode so it keeps ≥4.5:1 contrast.
    static let accentText = dynamic(0x0051D5, 0x64B5FF)
    /// Light blue highlight used on dark surfaces and as a soft tint wash.
    static let mint = Color(red: 0.42, green: 0.72, blue: 1.0)
    /// Warning text.
    static let amber = dynamic(0x8A5A00, 0xFFD27A)
    /// Warning background.
    static let warningFill = dynamic(0xFFF3D6, 0x3B2F14)
    /// Opaque card colour (used where glass would sit on glass).
    static let card = Color(.secondarySystemGroupedBackground)
    /// Always-dark surface that carries white text in both appearances.
    static let inkFill = dynamic(0x1C1C1E, 0x2C2C2E)
    /// Graphite gradient for hero cards (white text on top).
    static let heroGradient = LinearGradient(
        colors: [dynamic(0x1C1C1E, 0x1C1C1E), dynamic(0x3A3A3C, 0x2C2C2E)],
        startPoint: .topLeading, endPoint: .bottomTrailing)
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

// MARK: - Liquid Glass
// iOS 26+: system Liquid Glass. Earlier systems: a regular material with a hairline,
// so nothing depends on the new API at runtime.
extension View {
    @ViewBuilder
    func liquidGlass<S: Shape>(in shape: S, tint: Color? = nil, interactive: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(GlassStyle.make(tint: tint, interactive: interactive), in: shape)
        } else {
            self.background(.regularMaterial, in: shape)
                .background(tint.map { AnyShapeStyle($0.opacity(0.18)) } ?? AnyShapeStyle(Color.clear), in: shape)
                .overlay(shape.stroke(Palette.line.opacity(0.6), lineWidth: 0.5))
        }
    }

    /// Secondary button: system glass button on iOS 26+, bordered button below.
    @ViewBuilder
    func secondaryGlassButton() -> some View {
        if #available(iOS 26.0, *) {
            self.buttonStyle(.glass).buttonBorderShape(.capsule)
        } else {
            self.buttonStyle(.bordered).buttonBorderShape(.capsule)
        }
    }

    /// Soft accent-tinted panel for informational notes (no glass-on-glass).
    func accentNote(cornerRadius: CGFloat = 16) -> some View {
        self.background(Palette.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    /// Groups nearby glass shapes so they blend and morph together on iOS 26.
    @ViewBuilder
    func glassGroup(spacing: CGFloat = 12) -> some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { self }
        } else {
            self
        }
    }
}

@available(iOS 26.0, *)
enum GlassStyle {
    static func make(tint: Color?, interactive: Bool) -> Glass {
        var glass = Glass.regular
        if let tint { glass = glass.tint(tint) }
        if interactive { glass = glass.interactive() }
        return glass
    }
}

/// Soft, mostly neutral backdrop so glass has something to refract.
struct GlassBackdrop: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let strength = scheme == .dark ? 1.0 : 0.75
            ZStack {
                Palette.background
                Circle().fill(Color(.systemBlue).opacity(0.16 * strength))
                    .frame(width: width * 0.95).blur(radius: 90)
                    .offset(x: -width * 0.35, y: -geometry.size.height * 0.32)
                Circle().fill(Color(.systemTeal).opacity(0.10 * strength))
                    .frame(width: width * 0.75).blur(radius: 90)
                    .offset(x: width * 0.45, y: geometry.size.height * 0.05)
                Circle().fill(Color(.systemIndigo).opacity(0.10 * strength))
                    .frame(width: width * 0.85).blur(radius: 100)
                    .offset(x: -width * 0.1, y: geometry.size.height * 0.42)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

// MARK: - Screen

struct Screen<Content: View>: View {
    @EnvironmentObject private var store: CompanionStore
    let title: String
    let eyebrow: String
    var headerIcon: String? = nil
    var headerAction: (() -> Void)? = nil
    @ScaledMetric private var titleSize = 32.0
    @ViewBuilder var content: () -> Content

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(title).font(.system(size: titleSize, weight: .bold)).foregroundStyle(Palette.ink)
                            Text(eyebrow).font(.system(size: 13)).foregroundStyle(Palette.muted)
                        }
                        Spacer()
                        if let headerIcon {
                            Button { headerAction?() } label: {
                                Image(systemName: headerIcon).font(.system(size: 19, weight: .medium)).foregroundStyle(Palette.ink)
                                    .frame(width: 44, height: 44)
                                    .liquidGlass(in: Circle(), interactive: true)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(headerIcon == "gearshape" ? "偏好设置" : "归档链路")
                        }
                    }
                    if store.demoMode {
                        Label("演示模式 · 示例数据，不连接眼镜", systemImage: "sparkles")
                            .font(.caption.weight(.medium)).foregroundStyle(Palette.amber)
                            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Palette.warningFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    content()
                }
                // NavigationStack can extend its scroll area beneath the root's custom tab inset.
                // Keep the last row reachable above the floating tab bar on iOS 16 and 26.
                .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 110)
            }
            .scrollContentBackground(.hidden)
            .background(GlassBackdrop())
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

// MARK: - Building blocks

struct Card<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 16, content: content)
            .padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .liquidGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct SectionLabel: View {
    let title: String
    var trailing: String = ""
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.system(size: 20, weight: .bold)).foregroundStyle(Palette.ink)
            Spacer()
            Text(trailing).font(.caption).foregroundStyle(Palette.muted)
        }
        .padding(.top, 6)
    }
}

struct Badge: View {
    let text: String
    var active = false
    var body: some View {
        Text(text).font(.system(size: 11, weight: .semibold))
            .foregroundStyle(active ? Palette.accentText : Palette.muted)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(active ? AnyShapeStyle(Palette.accent.opacity(0.14)) : AnyShapeStyle(Color(.tertiarySystemFill)), in: Capsule())
    }
}

struct PrimaryButton: View {
    let title: String
    var icon = "arrow.right"
    var enabled = true
    let action: () -> Void
    var body: some View {
        if #available(iOS 26.0, *) {
            Button(action: action) { label.padding(.vertical, 6) }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.roundedRectangle(radius: 18))
                .controlSize(.large)
                .tint(Palette.accent)
                .disabled(!enabled)
        } else {
            Button(action: action) {
                label.padding(16).foregroundStyle(enabled ? .white : Palette.muted)
                    .background(enabled ? AnyShapeStyle(Palette.accent) : AnyShapeStyle(Color(.tertiarySystemFill)),
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }.disabled(!enabled)
        }
    }

    private var label: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
            Text(title).font(.system(size: 16, weight: .semibold))
        }
        .frame(maxWidth: .infinity)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var status: String = "待接入"
    var active = false
    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.accent.opacity(0.12)).frame(width: 42, height: 42)
                .overlay(Image(systemName: icon).font(.system(size: 18, weight: .medium)).foregroundStyle(Palette.accent))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.ink)
                Text(subtitle).font(.system(size: 12)).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            Badge(text: status, active: active)
        }.padding(.vertical, 2).contentShape(Rectangle())
    }
}

struct EmptyState: View {
    let icon: String
    let title: String
    let detail: String
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 28, weight: .regular)).foregroundStyle(Palette.accent)
                .frame(width: 72, height: 72).background(Palette.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            Text(title).font(.system(size: 20, weight: .semibold)).foregroundStyle(Palette.ink)
            Text(detail).font(.system(size: 14)).foregroundStyle(Palette.muted).multilineTextAlignment(.center).lineSpacing(5)
        }.frame(maxWidth: .infinity).padding(.vertical, 24)
    }
}

struct GlassesIllustration: View {
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let lens = width * 0.37
            ZStack {
                Ellipse().fill(Palette.mint.opacity(0.10)).frame(width: width * 0.9, height: 85).blur(radius: 14).offset(y: 25)
                Path { path in
                    path.move(to: CGPoint(x: 12, y: 67)); path.addLine(to: CGPoint(x: 3, y: 19)); path.addQuadCurve(to: CGPoint(x: 37, y: 9), control: CGPoint(x: 11, y: 0))
                    path.move(to: CGPoint(x: width - 12, y: 67)); path.addLine(to: CGPoint(x: width - 3, y: 19)); path.addQuadCurve(to: CGPoint(x: width - 37, y: 9), control: CGPoint(x: width - 11, y: 0))
                }.stroke(Color.white.opacity(0.35), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                HStack(spacing: 23) {
                    ForEach(0..<2) { _ in
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(LinearGradient(colors: [Palette.mint.opacity(0.28), Palette.mint.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: lens, height: 70)
                            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(LinearGradient(colors: [.white.opacity(0.95), Palette.mint.opacity(0.7)], startPoint: .top, endPoint: .bottom), lineWidth: 4))
                            .overlay(alignment: .topLeading) {
                                Capsule().fill(.white.opacity(0.6)).frame(width: 28, height: 3).rotationEffect(.degrees(-30)).offset(x: 15, y: 19)
                            }
                    }
                }.offset(y: 11)
                Path { path in
                    path.move(to: CGPoint(x: width / 2 - 12, y: 52)); path.addQuadCurve(to: CGPoint(x: width / 2 + 12, y: 52), control: CGPoint(x: width / 2, y: 39))
                }.stroke(Color.white.opacity(0.85), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            }.frame(width: width, height: geometry.size.height)
        }.frame(height: 130).accessibilityHidden(true)
    }
}
