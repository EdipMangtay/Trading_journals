import SwiftUI
import AppKit

enum Palette {
    static let canvas = adaptive(0x080C12, 0xF4F6F9)
    static let panel = adaptive(0x101722, 0xFFFFFF)
    static let raised = adaptive(0x192434, 0xEBF0F6)
    static let sidebar = adaptive(0x0C1119, 0xEEF2F7)
    static let field = adaptive(0x0B111A, 0xF6F8FB)
    static let line = adaptive(0x222E3E, 0xDCE3EC)
    static let primaryButtonInk = adaptive(0x062016, 0xFFFFFF)
    static let ink = adaptive(0xF1F5F8, 0x16202A)
    static let muted = adaptive(0x9AA6B6, 0x526173)
    static let mint = adaptive(0x5CE1B3, 0x087851)
    static let red = adaptive(0xF4767E, 0xBA3546)
    static let amber = adaptive(0xF0BC6B, 0x906018)
    static let blue = adaptive(0x7DA9F8, 0x315EAB)
    static let specular = adaptive(0xFFFFFF, 0xFFFFFF)
    static func adaptive(_ dark: UInt32, _ light: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, alpha: 1)
        })
    }
    static func outcome(_ number: Double) -> Color { number > 0 ? mint : number < 0 ? red : muted }
    static func classification(_ c: Classification) -> Color {
        switch c { case .invalidWinner, .invalidLoser: return amber; case .validWinner: return mint; case .validLoser: return blue; case .breakeven: return muted }
    }
}

enum EdgeHaptics {
    @MainActor static func tick() {
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }
    @MainActor static func selection() {
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }
}
enum Format {
    static func money(_ value: Double, currency: String = "USD") -> String { value.formatted(.currency(code: currency).locale(L10n.locale).precision(.fractionLength(2))) }
    static func number(_ value: Double, digits: Int = 2) -> String { value.formatted(.number.locale(L10n.locale).precision(.fractionLength(digits))) }
    static func r(_ value: Double?) -> String { value.map { ($0 > 0 ? "+" : "") + number($0) + "R" } ?? "—" }
    static func percent(_ value: Double) -> String { number(value, digits: 1) + "%" }
    static func factor(_ p: Performance) -> String { p.profitFactor.map { number($0) } ?? (p.grossProfit > 0 ? "∞" : "—") }
    static func date(_ date: Date, calendar: Calendar, time: Bool = false) -> String {
        var style = Date.FormatStyle(date: .abbreviated, time: time ? .shortened : .omitted)
        style.locale = L10n.locale
        style.timeZone = calendar.timeZone
        style.calendar = calendar
        return date.formatted(style)
    }
    static func month(_ date: Date, calendar: Calendar) -> String {
        var style = Date.FormatStyle().month(.wide).year()
        style.locale = L10n.locale
        style.timeZone = calendar.timeZone
        style.calendar = calendar
        return date.formatted(style)
    }
}
private struct EdgeAnimationsKey: EnvironmentKey {
    static let defaultValue = true
}
extension EnvironmentValues {
    var edgeAnimationsEnabled: Bool {
        get { self[EdgeAnimationsKey.self] }
        set { self[EdgeAnimationsKey.self] = newValue }
    }
}

/// Shared control typography and spacing remain native to the macOS window.
enum EdgeType {
    static let section = Font.system(size: 13, weight: .semibold)
    static let body = Font.system(size: 13)
    static let label = Font.system(size: 12, weight: .medium)
    static let caption = Font.system(size: 11)
    static let eyebrow = Font.system(size: 10, weight: .semibold)
}

struct EdgeButtonStyle: ButtonStyle {
    var prominent = true
    var compact = false
    func makeBody(configuration: Configuration) -> some View {
        EdgeButtonBody(configuration: configuration, prominent: prominent, compact: compact)
    }
    private struct EdgeButtonBody: View {
        let configuration: ButtonStyleConfiguration
        let prominent: Bool
        let compact: Bool
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.isFocused) private var isFocused
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @Environment(\.colorSchemeContrast) private var contrast
        @Environment(\.edgeAnimationsEnabled) private var animationsEnabled
        @State private var hovered = false
        private var accent: Color { configuration.role == .destructive ? Palette.red : Palette.mint }
        private var fill: Color {
            if !isEnabled { return Palette.raised.opacity(0.55) }
            if prominent { return accent.opacity(configuration.isPressed ? 0.78 : hovered ? 0.92 : 1) }
            return hovered ? Palette.raised : Palette.raised.opacity(0.58)
        }
        private var stroke: Color {
            if isFocused { return accent }
            if configuration.role == .destructive { return accent.opacity(hovered ? 0.45 : 0.2) }
            return prominent ? accent.opacity(0.6) : Palette.line.opacity(contrast == .increased ? 1 : hovered ? 1 : 0.75)
        }
        var body: some View {
            configuration.label
                .font(.system(size: compact ? 11 : 12, weight: .semibold))
                .padding(.horizontal, compact ? 10 : 15).padding(.vertical, compact ? 6 : 9)
                .frame(minHeight: compact ? 28 : 36)
                .foregroundStyle(!isEnabled ? Palette.muted.opacity(0.6) : prominent ? Palette.primaryButtonInk : configuration.role == .destructive ? Palette.red : Palette.ink)
                .background(fill, in: RoundedRectangle(cornerRadius: compact ? 7 : 9))
                .overlay(RoundedRectangle(cornerRadius: compact ? 7 : 9).strokeBorder(stroke, lineWidth: isFocused ? 2 : 1))
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: 1).fill(Color.white.opacity(prominent && isEnabled ? 0.22 : hovered ? 0.08 : 0.035)).frame(height: 1).padding(.horizontal, 9)
                }
                .shadow(color: prominent && isEnabled && hovered ? accent.opacity(0.28) : .clear, radius: 10, x: 0, y: 3)
                .scaleEffect(configuration.isPressed && isEnabled ? 0.97 : 1.0)
                .opacity(configuration.isPressed && !prominent ? 0.8 : 1)
                .contentShape(RoundedRectangle(cornerRadius: 9))
                .onHover { hovered = $0 }
                .animation(animationsEnabled && !reduceMotion ? .spring(response: 0.22, dampingFraction: 0.78) : nil, value: hovered)
                .animation(animationsEnabled && !reduceMotion ? .spring(response: 0.16, dampingFraction: 0.7) : nil, value: configuration.isPressed)
        }
    }
}

struct NavigationButtonStyle: ButtonStyle {
    var selected = false
    func makeBody(configuration: Configuration) -> some View {
        NavigationButtonBody(configuration: configuration, selected: selected)
    }
    private struct NavigationButtonBody: View {
        let configuration: ButtonStyleConfiguration
        let selected: Bool
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.isFocused) private var isFocused
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @Environment(\.edgeAnimationsEnabled) private var animationsEnabled
        @State private var hovered = false
        var body: some View {
            configuration.label
                .foregroundStyle(selected ? Palette.ink : Palette.muted)
                .background(selected ? Palette.mint.opacity(0.1) : hovered ? Palette.raised.opacity(0.65) : Color.clear, in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(isFocused ? Palette.mint : selected ? Palette.mint.opacity(0.17) : Color.clear, lineWidth: isFocused ? 2 : 1))
                .overlay(alignment: .leading) { if selected { Capsule().fill(Palette.mint).frame(width: 3, height: 16).padding(.leading, 1) } }
                .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
                .contentShape(RoundedRectangle(cornerRadius: 9))
                .onHover { hovered = $0 }
                .animation(animationsEnabled && !reduceMotion ? .easeOut(duration: 0.12) : nil, value: hovered)
        }
    }
}

/// Keeps native text editing, formatters, bindings and keyboard shortcuts intact.
struct EdgeTextFieldStyle: TextFieldStyle {
    var compact = false
    func _body(configuration: TextField<_Label>) -> some View {
        EdgeTextInput(compact: compact) { configuration.textFieldStyle(.plain) }
    }
    private struct EdgeTextInput<Content: View>: View {
        var compact: Bool
        @ViewBuilder var content: Content
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @Environment(\.edgeAnimationsEnabled) private var animationsEnabled
        @FocusState private var focused: Bool
        @State private var hovered = false
        var body: some View {
            content.font(.system(size: 12)).foregroundStyle(isEnabled ? Palette.ink : Palette.muted)
                .padding(.horizontal, compact ? 9 : 12).padding(.vertical, compact ? 7 : 10)
                .frame(minHeight: compact ? 30 : 37)
                .focused($focused)
                .background(Palette.field.opacity(isEnabled ? 1 : 0.5), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(focused ? Palette.mint.opacity(0.8) : hovered && isEnabled ? Palette.muted.opacity(0.35) : Palette.line, lineWidth: focused ? 1.5 : 1))
                .onHover { hovered = $0 }
                .animation(animationsEnabled && !reduceMotion ? .easeOut(duration: 0.12) : nil, value: focused)
        }
    }
}

private struct EdgeEditorSurface: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled
    @FocusState private var focused: Bool
    func body(content: Content) -> some View {
        content.scrollContentBackground(.hidden).font(EdgeType.body)
            .padding(10).focused($focused)
            .background(Palette.field.opacity(isEnabled ? 1 : 0.5), in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(focused ? Palette.mint.opacity(0.8) : Palette.line, lineWidth: focused ? 1.5 : 1))
    }
}

private struct EdgeSegmentStyle: ButtonStyle {
    let selected: Bool
    func makeBody(configuration: Configuration) -> some View {
        SegmentBody(configuration: configuration, selected: selected)
    }
    private struct SegmentBody: View {
        let configuration: ButtonStyleConfiguration
        let selected: Bool
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.isFocused) private var isFocused
        @State private var hovered = false
        var body: some View {
            configuration.label
                .foregroundStyle(selected ? Palette.ink : Palette.muted)
                .background(selected ? Palette.raised : hovered ? Palette.raised.opacity(0.4) : .clear, in: RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(isFocused ? Palette.mint : selected ? Palette.line : .clear, lineWidth: isFocused ? 2 : 1))
                .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
                .contentShape(RoundedRectangle(cornerRadius: 7)).onHover { hovered = $0 }
        }
    }
}
struct SegmentedTabs<Value: Hashable>: View {
    let options: [Value]
    @Binding var selection: Value
    var title: (Value) -> String
    @Namespace private var tabNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 3) {
            ForEach(options, id: \.self) { value in
                let isSelected = selection == value
                Button {
                    selection = value
                } label: {
                    Text(L10n.text(title(value)))
                        .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? Palette.ink : Palette.muted)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 29)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(Palette.raised)
                                    .matchedGeometryEffect(id: "tabHighlight", in: tabNamespace)
                                    .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Palette.line, lineWidth: 1))
                                    .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 1)
                            }
                        }
                }
                .buttonStyle(.plain)
                .contentShape(RoundedRectangle(cornerRadius: 7))
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .padding(4)
        .background(Palette.field, in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Palette.line.opacity(0.85)))
        .animation(!reduceMotion ? .spring(response: 0.28, dampingFraction: 0.76) : nil, value: selection)
    }
}
struct Panel<Content: View>: View {
    var title: String? = nil
    var subtitle: String? = nil
    @ViewBuilder var content: Content
    @Environment(\.colorSchemeContrast) private var contrast
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let title {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 16) {
                        panelTitle(title)
                        Spacer(minLength: 8)
                        if let subtitle { panelSubtitle(subtitle).multilineTextAlignment(.trailing) }
                    }
                    VStack(alignment: .leading, spacing: 7) {
                        panelTitle(title)
                        if let subtitle { panelSubtitle(subtitle) }
                    }
                }.padding(.bottom, 14)
                    .overlay(alignment: .bottom) { Rectangle().fill(Palette.line.opacity(0.6)).frame(height: 1) }
            }
            content
        }.padding(22).frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.panel, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Palette.line.opacity(contrast == .increased ? 1 : 0.85), lineWidth: 1))
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(LinearGradient(colors: [Palette.specular.opacity(0.085), Palette.specular.opacity(0.01)], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 1)
                    .padding(.horizontal, 18)
            }
            .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 6)
    }
    private func panelTitle(_ title: String) -> some View {
        Text(L10n.text(title)).font(EdgeType.section).tracking(0.1).fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
    }
    private func panelSubtitle(_ subtitle: String) -> some View {
        Text(L10n.text(subtitle)).font(EdgeType.caption).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
    }
}
struct Badge: View {
    var text: String
    var color: Color = Palette.muted
    var body: some View {
        Text(L10n.text(text)).font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 9).padding(.vertical, 5).foregroundStyle(color)
            .background(color.opacity(0.1), in: Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.12)))
            .lineLimit(2).fixedSize(horizontal: false, vertical: true)
    }
}
struct MetricCard: View {
    var title: String, value: String, footnote: String = ""
    var color: Color = Palette.ink
    @State private var hovering = false
    @Environment(\.edgeAnimationsEnabled) private var animationsEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .title) private var valueSize = 28
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 8) {
                Text(L10n.text(title)).font(EdgeType.label).foregroundStyle(Palette.muted).lineLimit(2)
                Spacer(minLength: 0)
                Image(systemName: symbol).font(.system(size: 12, weight: .medium)).foregroundStyle(color.opacity(0.8)).frame(width: 25, height: 25).background(color.opacity(0.065), in: RoundedRectangle(cornerRadius: 7)).accessibilityHidden(true)
            }
            Text(verbatim: value).font(.system(size: valueSize, weight: .semibold, design: .rounded))
                .tracking(-0.8).monospacedDigit().foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.65)
                .contentTransition(animationsEnabled && !reduceMotion ? .numericText() : .identity)
            if !footnote.isEmpty { Text(L10n.text(footnote)).font(EdgeType.caption).foregroundStyle(Palette.muted).lineLimit(2).frame(height: 30, alignment: .top) }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(19)
            .background(
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 14).fill(hovering ? Palette.raised.opacity(0.72) : Palette.panel)
                    if hovering {
                        RadialGradient(colors: [color.opacity(0.11), .clear], center: .topTrailing, startRadius: 2, endRadius: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            )
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(hovering ? color.opacity(0.32) : Palette.line.opacity(0.85)))
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(LinearGradient(colors: [hovering ? color.opacity(0.35) : Palette.specular.opacity(0.07), .clear], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 1)
                    .padding(.horizontal, 14)
            }
            .shadow(color: .black.opacity(hovering ? 0.14 : 0.04), radius: hovering ? 14 : 6, x: 0, y: hovering ? 6 : 2)
            .offset(y: animationsEnabled && !reduceMotion && hovering ? -1.5 : 0)
            .onHover { hovering = $0 }
            .animation(animationsEnabled && !reduceMotion ? .spring(response: 0.24, dampingFraction: 0.78) : nil, value: hovering)
            .accessibilityElement(children: .combine)
    }
    private var symbol: String {
        let key = title.lowercased()
        if key.contains("win") { return "arrow.up.right" }
        if key.contains("loss") || key.contains("drawdown") || key.contains("loser") { return "arrow.down.right" }
        if key.contains("compliance") || key.contains("process") { return "checkmark.shield" }
        if key.contains("pnl") || key.contains("winner") || key.contains("trade") { return "chart.line.uptrend.xyaxis" }
        if key.contains("duration") { return "clock" }
        if key.contains("rate") || key.contains("factor") || key.contains("ratio") { return "percent" }
        return "chart.bar.xaxis"
    }
}
struct PageHeader: View {
    var eyebrow: String, title: String, subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) { Capsule().fill(Palette.mint).frame(width: 15, height: 3); Text(L10n.text(eyebrow.uppercased())).font(.system(size: 10, weight: .semibold)).tracking(1.8).foregroundStyle(Palette.muted) }
            Text(L10n.text(title)).font(.system(size: 30, weight: .semibold)).tracking(-1).fixedSize(horizontal: false, vertical: true)
            Text(L10n.text(subtitle)).font(EdgeType.body).foregroundStyle(Palette.muted).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
        }
    }
}
struct EmptyJournal: View {
    var title = "Your edge starts with one trade."
    var subtitle = "Log the setup, record the process, and let your own data tell the story."
    var actionTitle = "New trade"
    var action: (() -> Void)? = nil
    var body: some View {
        VStack(spacing: 17) {
            ZStack {
                RoundedRectangle(cornerRadius: 20).fill(Palette.mint.opacity(0.07)).frame(width: 84, height: 84)
                RoundedRectangle(cornerRadius: 20).strokeBorder(Palette.mint.opacity(0.15)).frame(width: 84, height: 84)
                Image(systemName: "chart.xyaxis.line").font(.system(size: 32, weight: .light)).foregroundStyle(Palette.mint)
            }
            Text(L10n.text(title)).font(.system(size: 22, weight: .semibold)).tracking(-0.5)
            Text(L10n.text(subtitle)).font(.system(size: 12)).foregroundStyle(Palette.muted).multilineTextAlignment(.center).frame(maxWidth: 440)
            if let action { Button(action: action) { Label(L10n.text(actionTitle), systemImage: "plus") }.buttonStyle(EdgeButtonStyle()).padding(.top, 5) }
        }.padding(.horizontal, 32).padding(.vertical, 48).frame(maxWidth: .infinity)
    }
}
struct ChipSelection: View {
    let options: [String]
    @Binding var selection: [String]
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), alignment: .leading)], alignment: .leading, spacing: 8) {
            ForEach(Array(Set(options)).sorted(), id: \.self) { option in
                Button {
                    if selection.contains(option) { selection.removeAll { $0 == option } }
                    else { selection.append(option) }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: selection.contains(option) ? "checkmark.circle.fill" : "circle").foregroundStyle(selection.contains(option) ? Palette.mint : Palette.muted.opacity(0.65))
                        Text(L10n.text(option)).font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }.padding(.horizontal, 10).padding(.vertical, 9).frame(minHeight: 35)
                }.buttonStyle(EdgeSegmentStyle(selected: selection.contains(option)))
                    .accessibilityLabel(L10n.text(option))
                    .accessibilityValue(selection.contains(option) ? "Seçili" : "Seçili değil")
                    .accessibilityAddTraits(selection.contains(option) ? [.isSelected] : [])
            }
        }
    }
}
struct ScoreSlider: View {
    var title: String
    @Binding var value: Double
    var lower = 0.0
    var body: some View {
        HStack(spacing: 14) {
            Text(L10n.text(title)).font(EdgeType.label).frame(width: 145, alignment: .leading)
            Slider(value: $value, in: lower...10, step: 1).tint(Palette.mint)
                .accessibilityLabel(L10n.text(title)).accessibilityValue("\(Int(value)) / 10")
            Text(Int(value).description).font(.system(size: 12, weight: .semibold, design: .monospaced)).monospacedDigit()
                .frame(width: 31, height: 28).background(Palette.field, in: RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Palette.line.opacity(0.7)))
                .accessibilityHidden(true)
        }
    }
}
struct SidebarRowHoverStyle: ButtonStyle {
    var selected = false
    func makeBody(configuration: Configuration) -> some View {
        BodyView(configuration: configuration, selected: selected)
    }
    private struct BodyView: View {
        let configuration: ButtonStyleConfiguration
        let selected: Bool
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @Environment(\.edgeAnimationsEnabled) private var animationsEnabled
        @State private var hovered = false
        var body: some View {
            configuration.label
                .background(!selected && hovered ? Palette.raised.opacity(0.6) : .clear, in: RoundedRectangle(cornerRadius: 9))
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .contentShape(RoundedRectangle(cornerRadius: 9))
                .onHover { hovered = $0 }
                .animation(animationsEnabled && !reduceMotion ? .easeOut(duration: 0.12) : nil, value: hovered)
                .animation(animationsEnabled && !reduceMotion ? .spring(response: 0.16, dampingFraction: 0.72) : nil, value: configuration.isPressed)
        }
    }
}

struct ExecutionScoreRing: View {
    var score: Double
    var size: CGFloat = 128
    var lineWidth: CGFloat = 9
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.edgeAnimationsEnabled) private var animationsEnabled
    @State private var animatedProgress: Double = 1.0

    private var clamped: Double { min(1, max(0, score / 100)) }
    private var ringColor: Color { score >= 75 ? Palette.mint : score >= 50 ? Palette.blue : Palette.amber }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Palette.raised.opacity(0.85), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        colors: [ringColor.opacity(0.55), ringColor, Palette.mint],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: ringColor.opacity(0.32), radius: 6, x: 0, y: 0)
            VStack(spacing: 2) {
                Text(Format.number(score, digits: 0))
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
                    .contentTransition(animationsEnabled && !reduceMotion ? .numericText() : .identity)
                Text("/ 100")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Palette.muted)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            if animationsEnabled && !reduceMotion {
                animatedProgress = 0
                withAnimation(.spring(response: 0.75, dampingFraction: 0.82)) {
                    animatedProgress = clamped
                }
            } else {
                animatedProgress = clamped
            }
        }
        .onChange(of: score) { _, _ in
            if animationsEnabled && !reduceMotion {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    animatedProgress = clamped
                }
            } else {
                animatedProgress = clamped
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Süreç puanı \(Format.number(score, digits: 0)) / 100")
    }
}

private struct EdgeEntranceModifier: ViewModifier {
    let delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.edgeAnimationsEnabled) private var animationsEnabled
    @State private var shown = false

    func body(content: Content) -> some View {
        let shouldAnimate = animationsEnabled && !reduceMotion
        content
            .opacity(shouldAnimate ? (shown ? 1 : 0) : 1)
            .offset(y: shouldAnimate ? (shown ? 0 : 8) : 0)
            .onAppear {
                guard shouldAnimate, !shown else { return }
                withAnimation(.spring(response: 0.42, dampingFraction: 0.84).delay(delay)) {
                    shown = true
                }
            }
    }
}

extension View {
    func edgeEditorSurface() -> some View { modifier(EdgeEditorSurface()) }
    func edgeEntrance(delay: Double = 0) -> some View { modifier(EdgeEntranceModifier(delay: delay)) }
    func pagePadding() -> some View { self.padding(28).frame(maxWidth: 1600).frame(maxWidth: .infinity, alignment: .topLeading) }
}
