import SwiftUI

struct CalendarView: View {
    @Environment(JournalStore.self) private var store
    var openTrade: (TradeRecord) -> Void
    @State private var month = Date()
    @State private var selectedDate: Date?
    @State private var showR = false
    var body: some View {
        let calendar = store.preferences.calendar
        let interval = calendar.dateInterval(of: .month, for: month)!
        let monthTrades = store.scopedTrades.filter { $0.date >= interval.start && $0.date < interval.end }
        let p = AnalyticsEngine.performance(monthTrades)
        let buckets = Dictionary(grouping: monthTrades) { calendar.startOfDay(for: $0.date) }
        let count = calendar.range(of: .day, in: .month, for: month)!.count
        let offset = (calendar.component(.weekday, from: interval.start) - calendar.firstWeekday + 7) % 7
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top, spacing: 24) {
                    PageHeader(eyebrow: "Session by session", title: "The rhythm of your trading.", subtitle: "Daily outcomes, with the process one click away.")
                    Spacer(minLength: 0)
                    Toggle(isOn: $showR) { Text(L10n.text("Show R")).font(.system(size: 12, weight: .medium)) }
                        .toggleStyle(.switch).fixedSize().padding(12)
                        .background(Palette.panel, in: RoundedRectangle(cornerRadius: 11))
                        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Palette.muted.opacity(0.12)))
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4), spacing: 14) {
                    MetricCard(title: "Monthly PnL", value: Format.money(p.netPnL, currency: store.accountCurrency), color: Palette.outcome(p.netPnL))
                    MetricCard(title: "Monthly R", value: p.rCount == 0 ? "—" : Format.r(p.totalR), color: Palette.outcome(p.totalR))
                    MetricCard(title: "Win rate", value: p.count == 0 ? "—" : Format.percent(p.winRate))
                    MetricCard(title: "Trades", value: p.count.description)
                }.edgeEntrance(delay: 0.03)
                Panel {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 11).fill(Palette.mint.opacity(0.09)).frame(width: 42, height: 42)
                            Image(systemName: "calendar").font(.system(size: 18, weight: .medium)).foregroundStyle(Palette.mint)
                        }.accessibilityHidden(true)
                        Text(Format.month(month, calendar: calendar)).font(.system(size: 22, weight: .semibold)).tracking(-0.5)
                        Spacer(minLength: 8)
                        Button(L10n.text("This month")) { month = Date(); selectedDate = calendar.startOfDay(for: Date()) }
                            .buttonStyle(EdgeButtonStyle(prominent: false, compact: true))
                        HStack(spacing: 6) {
                            Button { shift(-1) } label: { Image(systemName: "chevron.left").frame(width: 12, height: 16) }
                                .buttonStyle(EdgeButtonStyle(prominent: false, compact: true)).help("Önceki ay").accessibilityLabel("Önceki ay")
                            Button { shift(1) } label: { Image(systemName: "chevron.right").frame(width: 12, height: 16) }
                                .buttonStyle(EdgeButtonStyle(prominent: false, compact: true)).help("Sonraki ay").accessibilityLabel("Sonraki ay")
                        }
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                        ForEach(["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"], id: \.self) { weekday in
                            Text(L10n.text(weekday)).font(.system(size: 10, weight: .semibold)).tracking(0.7)
                                .foregroundStyle(Palette.muted).padding(.vertical, 8).frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 12)
                        }
                        ForEach(0..<(offset + count), id: \.self) { index in
                            if index < offset { Color.clear.frame(height: 108).accessibilityHidden(true) }
                            else {
                                let date = calendar.date(byAdding: .day, value: index - offset, to: interval.start)!
                                let dayTrades = buckets[date] ?? []
                                let stats = dayTrades.isEmpty ? Performance() : AnalyticsEngine.performance(dayTrades)
                                let number = showR ? stats.totalR : stats.netPnL
                                Button {
                                    selectedDate = date
                                    if store.preferences.animations { EdgeHaptics.tick() }
                                } label: {
                                    CalendarDayContent(day: index - offset + 1, today: calendar.isDateInToday(date), hasTrades: !dayTrades.isEmpty, count: stats.count, value: showR ? (stats.rCount == 0 ? "—" : Format.r(number)) : Format.money(number, currency: store.accountCurrency), color: Palette.outcome(number))
                                }
                                .buttonStyle(CalendarDayButtonStyle(selected: selectedDate == date, color: dayTrades.isEmpty ? Palette.muted : Palette.outcome(number), hasTrades: !dayTrades.isEmpty))
                                .accessibilityLabel("\(Format.date(date, calendar: calendar)), \(dayTrades.count) işlem, \(showR ? (stats.rCount == 0 ? "R kaydedilmedi" : Format.r(stats.totalR)) : Format.money(stats.netPnL, currency: store.accountCurrency))")
                                .accessibilityAddTraits(selectedDate == date ? .isSelected : [])
                            }
                        }
                    }
                    HStack(spacing: 18) {
                        Label("Kazanç", systemImage: "circle.fill").foregroundStyle(Palette.mint)
                        Label("Zarar", systemImage: "circle.fill").foregroundStyle(Palette.red)
                        Spacer(minLength: 8)
                        Label("Bugün", systemImage: "circle.inset.filled").foregroundStyle(Palette.muted)
                    }.font(.system(size: 10, weight: .medium)).padding(.top, 2)
                }
                if let selectedDate {
                    Panel(title: Format.date(selectedDate, calendar: calendar).uppercased()) {
                        let selected = buckets[calendar.startOfDay(for: selectedDate)] ?? []
                        if selected.isEmpty {
                            HStack(spacing: 13) {
                                Image(systemName: "calendar.badge.minus").font(.system(size: 22, weight: .light)).foregroundStyle(Palette.muted)
                                Text(L10n.text("No trades on this day.")).font(.system(size: 13)).foregroundStyle(Palette.muted)
                                Spacer()
                            }.padding(.vertical, 10)
                        } else { TradeRows(trades: selected, openTrade: openTrade) }
                    }
                } else {
                    HStack(spacing: 8) { Image(systemName: "cursorarrow.rays"); Text("Ayrıntıları görmek için bir gün seç.") }
                        .font(.system(size: 12)).foregroundStyle(Palette.muted).frame(maxWidth: .infinity).padding(.vertical, 10)
                }
            }.pagePadding()
        }
        .animation(store.preferences.animations ? .spring(response: 0.32, dampingFraction: 0.84) : nil, value: month)
        .animation(store.preferences.animations ? .spring(response: 0.28, dampingFraction: 0.84) : nil, value: selectedDate)
        .animation(store.preferences.animations ? .spring(response: 0.28, dampingFraction: 0.84) : nil, value: showR)
    }
    private func shift(_ value: Int) { month = store.preferences.calendar.date(byAdding: .month, value: value, to: month) ?? month; selectedDate = nil }
}

private struct CalendarDayContent: View {
    let day: Int
    let today: Bool
    let hasTrades: Bool
    let count: Int
    let value: String
    let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text(verbatim: "\(day)").font(.system(size: 12, weight: today ? .bold : .medium)).monospacedDigit().foregroundStyle(today ? Palette.mint : Palette.muted)
                Spacer(minLength: 0)
                if today { Circle().fill(Palette.mint).frame(width: 5, height: 5) }
            }
            if hasTrades {
                VStack(alignment: .leading, spacing: 5) {
                    Text(verbatim: value).font(.system(size: 14, weight: .semibold, design: .rounded)).monospacedDigit().foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.65)
                    Text(L10n.text("\(count) trades")).font(.system(size: 10)).foregroundStyle(Palette.muted)
                }
            }
            Spacer(minLength: 0)
        }.padding(12).frame(height: 108).frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CalendarDayButtonStyle: ButtonStyle {
    let selected: Bool
    let color: Color
    let hasTrades: Bool
    func makeBody(configuration: Configuration) -> some View {
        DayButtonBody(configuration: configuration, selected: selected, color: color, hasTrades: hasTrades)
    }
    private struct DayButtonBody: View {
        let configuration: ButtonStyleConfiguration
        let selected: Bool
        let color: Color
        let hasTrades: Bool
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @Environment(\.edgeAnimationsEnabled) private var animationsEnabled
        @State private var hovered = false
        var body: some View {
            let shouldAnimate = animationsEnabled && !reduceMotion
            configuration.label
                .background(selected ? Palette.mint.opacity(0.11) : hovered ? Palette.raised.opacity(0.72) : hasTrades ? color.opacity(0.075) : Palette.raised.opacity(0.28), in: RoundedRectangle(cornerRadius: 11))
                .overlay(alignment: .top) {
                    if hasTrades {
                        Capsule().fill(color.opacity(selected || hovered ? 0.9 : 0.55)).frame(height: 2.5).padding(.horizontal, 14).padding(.top, 2)
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(selected ? Palette.mint.opacity(0.8) : hasTrades && hovered ? color.opacity(0.45) : Palette.muted.opacity(hovered ? 0.3 : 0.1), lineWidth: selected ? 1.5 : 1))
                .shadow(color: selected ? Palette.mint.opacity(0.14) : hovered ? .black.opacity(0.12) : .clear, radius: selected || hovered ? 8 : 0, x: 0, y: 3)
                .scaleEffect(configuration.isPressed ? 0.97 : (shouldAnimate && hovered ? 1.02 : 1.0))
                .contentShape(RoundedRectangle(cornerRadius: 11))
                .onHover { hovered = $0 }
                .animation(shouldAnimate ? .spring(response: 0.22, dampingFraction: 0.78) : nil, value: hovered)
                .animation(shouldAnimate ? .spring(response: 0.2, dampingFraction: 0.78) : nil, value: selected)
        }
    }
}
