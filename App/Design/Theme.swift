import SwiftUI
import UIKit

/// Тёмная тема «Рациона»: тёплый почти чёрный фон, у каждого макронутриента свой цвет во всём приложении.
enum Theme {
    static let bg = Color(hex: 0x0B0B0A)
    static let surface = Color(hex: 0x151513)
    static let raised = Color(hex: 0x20201D)
    static let line = Color.white.opacity(0.08)
    static let line2 = Color.white.opacity(0.15)
    static let track = Color.white.opacity(0.07)
    static let text = Color(hex: 0xF6F2EA)
    static let muted = Color(hex: 0xA29E94)
    static let dim = Color(hex: 0x6E6B64)
    static let accent = Color(hex: 0xFF6A3D)
    static let accent2 = Color(hex: 0xFFA260)
    static let accentInk = Color(hex: 0x1C0B04)
    static let prot = Color(hex: 0x8FA9FF)
    static let fat = Color(hex: 0xF4CF55)
    static let carb = Color(hex: 0x56D8E2)
    static let ok = Color(hex: 0x7DDF9C)
    static let warn = Color(hex: 0xFFAB4F)

    static let accentGradient = LinearGradient(colors: [accent, accent2], startPoint: .topLeading, endPoint: .bottomTrailing)

    static func icon(_ p: Place) -> String {
        switch p {
        case .fridge: return "refrigerator"
        case .freezer: return "snowflake"
        case .cupboard: return "cabinet"
        case .table: return "table.furniture"
        case .other: return "ellipsis.circle"
        }
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

extension Font {
    /// Цифры и заголовки — скруглённый системный шрифт.
    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

private let ruLocale = Locale(identifier: "ru_RU")

/// «2 370», «88,5».
func fmt(_ x: Double, decimals: Int = 0) -> String {
    x.formatted(.number.precision(.fractionLength(decimals)).locale(ruLocale))
}

func fmtSmart(_ x: Double) -> String {
    x == x.rounded() ? fmt(x) : fmt(x, decimals: 1)
}

// MARK: - Фон

struct Backdrop: View {
    var body: some View {
        ZStack {
            Theme.bg
            RadialGradient(colors: [Theme.accent.opacity(0.22), .clear],
                           center: UnitPoint(x: 0.92, y: -0.06), startRadius: 0, endRadius: 400)
            RadialGradient(colors: [Theme.prot.opacity(0.10), .clear],
                           center: UnitPoint(x: 0, y: 0), startRadius: 0, endRadius: 340)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Карточка

struct Card<Content: View>: View {
    var padding: CGFloat = 18
    var radius: CGFloat = 26
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(LinearGradient(colors: [Color.white.opacity(0.04), .clear], startPoint: .top, endPoint: .center))
                    )
            )
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }
}

struct Eyebrow: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .semibold))
            .tracking(1.4)
            .foregroundStyle(Theme.muted)
    }
}

struct SectionHeader: View {
    let title: String
    var aside: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Eyebrow(title)
            Spacer(minLength: 8)
            if let aside {
                Text(aside).font(.system(size: 13)).foregroundStyle(Theme.dim).multilineTextAlignment(.trailing)
            }
        }
        .padding(.horizontal, 4)
    }
}

struct Dot: View {
    let color: Color
    var size: CGFloat = 8
    var body: some View {
        Circle().fill(color).frame(width: size, height: size).shadow(color: color.opacity(0.8), radius: 4)
    }
}

// MARK: - Кнопки

struct PrimaryButtonStyle: ButtonStyle {
    var height: CGFloat = 58
    func makeBody(configuration: Configuration) -> some View {
        PrimaryLabel(configuration: configuration, height: height)
    }
    private struct PrimaryLabel: View {
        let configuration: ButtonStyleConfiguration
        let height: CGFloat
        @Environment(\.isEnabled) private var isEnabled
        var body: some View {
            configuration.label
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.accentInk)
                .frame(maxWidth: .infinity, minHeight: height)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.accentGradient))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.28), lineWidth: 1).blendMode(.overlay))
                .shadow(color: Theme.accent.opacity(isEnabled ? 0.45 : 0), radius: 18, y: 10)
                .opacity(isEnabled ? 1 : 0.45)
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
        }
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    var height: CGFloat = 50
    func makeBody(configuration: Configuration) -> some View {
        SecondaryLabel(configuration: configuration, height: height)
    }
    private struct SecondaryLabel: View {
        let configuration: ButtonStyleConfiguration
        let height: CGFloat
        @Environment(\.isEnabled) private var isEnabled
        var body: some View {
            configuration.label
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.text)
                .frame(maxWidth: .infinity, minHeight: height)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.raised))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.line2, lineWidth: 1))
                .opacity(isEnabled ? 1 : 0.45)
                .scaleEffect(configuration.isPressed ? 0.98 : 1)
                .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
        }
    }
}

struct Chip: View {
    let title: String
    var icon: String? = nil
    let on: Bool
    var strikeWhenOff = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon).font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(on ? Theme.accent : Theme.muted)
                }
                Text(title).strikethrough(strikeWhenOff && !on, color: Theme.dim)
            }
            .font(.system(size: 14, weight: .medium))
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .foregroundStyle(on ? Theme.text : Theme.muted)
            .background(Capsule().fill(on ? (strikeWhenOff ? Color.white.opacity(0.06) : Theme.accent.opacity(0.16)) : Color.white.opacity(0.03)))
            .overlay(Capsule().stroke(on && !strikeWhenOff ? Theme.accent.opacity(0.55) : Theme.line2, lineWidth: 1))
            .opacity(strikeWhenOff && !on ? 0.45 : 1)
        }
        .buttonStyle(.plain)
    }
}

struct Segmented<T: Hashable>: View {
    let items: [(T, String)]
    @Binding var selection: T

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items.indices, id: \.self) { i in
                let value = items[i].0
                let on = selection == value
                Button {
                    withAnimation(.snappy(duration: 0.25)) { selection = value }
                } label: {
                    Text(items[i].1)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .foregroundStyle(on ? Theme.text : Theme.muted)
                        .background {
                            if on {
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(Theme.raised)
                                    .shadow(color: .black.opacity(0.55), radius: 6, y: 3)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Color.black.opacity(0.35)))
        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }
}

/// Строки чипов с переносом.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, widest: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > 0 && x + sz.width > maxW {
                y += rowH + spacing
                x = 0
                rowH = 0
            }
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: min(widest, maxW), height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > bounds.minX && x + sz.width > bounds.maxX {
                y += rowH + spacing
                x = bounds.minX
                rowH = 0
            }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sz))
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
    }
}

// MARK: - Кольца

/// Кольцо из долей (Б/Ж/У) с зазорами и прорисовкой при появлении.
struct SplitRing: View {
    let fractions: [Double]
    let colors: [Color]
    var lineWidth: CGFloat = 16
    var gap: Double = 0.04
    @State private var shown = false

    var body: some View {
        ZStack {
            Circle().stroke(Theme.track, lineWidth: lineWidth)
            ForEach(fractions.indices, id: \.self) { i in
                let start = fractions.prefix(i).reduce(0, +)
                let end = start + fractions[i]
                let a = start + gap / 2
                let b = max(a, end - gap / 2)
                Circle()
                    .trim(from: CGFloat(a), to: CGFloat(shown ? b : a))
                    .stroke(colors[i % colors.count], style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: colors[i % colors.count].opacity(0.35), radius: 8)
            }
        }
        .padding(lineWidth / 2)
        .animation(.snappy(duration: 0.5), value: fractions)
        .onAppear { withAnimation(.easeOut(duration: 0.9)) { shown = true } }
    }
}

/// Прогресс к цели: одна дуга, больше 100% — полный круг.
struct ProgressRing: View {
    let fraction: Double
    let color: Color
    var lineWidth: CGFloat = 7
    @State private var shown = false

    var body: some View {
        ZStack {
            Circle().stroke(Theme.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(shown ? min(max(fraction, 0), 1) : 0))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.4), radius: 5)
        }
        .padding(lineWidth / 2)
        .onAppear { withAnimation(.easeOut(duration: 0.8)) { shown = true } }
    }
}

/// Полоска долей Б/Ж/У по калориям.
struct MacroBar: View {
    let macros: Macros
    var body: some View {
        let kp = macros.p * 4, kf = macros.f * 9, kc = macros.c * 4
        let total = max(kp + kf + kc, 1)
        GeometryReader { g in
            HStack(spacing: 2) {
                Capsule().fill(Theme.prot).frame(width: max(0, g.size.width * kp / total - 2))
                Capsule().fill(Theme.fat).frame(width: max(0, g.size.width * kf / total - 2))
                Capsule().fill(Theme.carb)
            }
        }
        .frame(height: 5)
    }
}

// MARK: - Шапка экрана

struct AppHeader: View {
    var body: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: 0x2A2A26), Color(hex: 0x141412)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(Theme.line2, lineWidth: 1))
                    .shadow(color: Theme.accent.opacity(0.45), radius: 10, y: 6)
                SplitRing(fractions: [0.32, 0.26, 0.42], colors: [Theme.prot, Theme.fat, Theme.carb], lineWidth: 3.4, gap: 0.09)
                    .frame(width: 24, height: 24)
            }
            .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 1) {
                Text("Рацион").font(.rounded(17, .heavy))
                Text("из холодильника").font(.system(size: 13)).foregroundStyle(Theme.muted)
            }
            Spacer()
            Text(Date.now.formatted(.dateTime.weekday(.abbreviated).day().month(.wide).locale(Locale(identifier: "ru_RU"))))
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
        }
        .padding(.top, 6)
    }
}

struct ScreenTitle: View {
    let step: String
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(step)
            Text(title).font(.rounded(30, .heavy)).tracking(-0.5)
            Text(subtitle).font(.system(size: 15)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct Badge: View {
    let text: String
    var good = false
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 8)
            .frame(height: 20)
            .foregroundStyle(good ? Theme.ok : Theme.muted)
            .background(Capsule().fill(good ? Theme.ok.opacity(0.13) : Color.white.opacity(0.06)))
    }
}
