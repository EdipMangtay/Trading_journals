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
        let dayStats: [Date: Performance] = buckets.mapValues { AnalyticsEngine.performance($0) }
        let count = calendar.range(of: .day, in: .month, for: month)!.count
        let offset = (calendar.component(.weekday, from: interval.start) - calendar.firstWeekday + 7) % 7
        let totalRows = Int(ceil(Double(offset + count) / 7.0))
        let maxAbsDayValue: Double = max(1.0, dayStats.values.map { abs(showR ? $0.totalR : $0.netPnL) }.max() ?? 1.0)
        let greenDays = dayStats.values.filter { (showR ? $0.totalR : $0.netPnL) > 0.005 }.count
        let activeDays = dayStats.count
        let bestDayVal = dayStats.values.map { showR ? $0.totalR : $0.netPnL }.max()
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top, spacing: 24) {
                    PageHeader(eyebrow: "Session by session", title: "The rhythm of your trading.", subtitle: "Günlük sonuçlar, haftalık toplamlar ve tek tıkla süreç ayrıntıları.")
                    Spacer(minLength: 0)
                    Toggle(isOn: $showR) { Text(L10n.text("Show R")).font(.system(size: 12, weight: .semibold)) }
                        .toggleStyle(.switch).fixedSize().padding(.horizontal, 14).padding(.vertical, 10)
                        .background(Palette.panelGradient, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.line.opacity(0.85)))
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4), spacing: 14) {
                    MetricCard(
                        title: "Monthly PnL",
                        value: Format.money(p.netPnL, currency: store.accountCurrency),
                        footnote: bestDayVal.map { "En iyi gün " + (showR ? Format.r($0) : Format.money($0, currency: store.accountCurrency)) } ?? "",
                        color: Palette.outcome(p.netPnL)
                    )
                    MetricCard(
                        title: "Monthly R",
                        value: p.rCount == 0 ? "—" : Format.r(p.totalR),
                        footnote: p.averageR.map { "Ort. " + Format.r($0) + " / işlem" } ?? "",
                        color: Palette.outcome(p.totalR)
                    )
                    MetricCard(
                        title: "Win rate",
                        value: p.count == 0 ? "—" : Format.percent(p.winRate),
                        footnote: activeDays > 0 ? "\(greenDays) / \(activeDays) yeşil gün" : ""
                    )
                    MetricCard(
                        title: "Trades",
                        value: p.count.description,
                        footnote: activeDays > 0 ? "\(activeDays) aktif işlem günü" : ""
                    )
                }.edgeEntrance(delay: 0.03)
                Panel {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 11).fill(Palette.mint.opacity(0.11)).frame(width: 42, height: 42)
                            RoundedRectangle(cornerRadius: 11).strokeBorder(Palette.mint.opacity(0.24), lineWidth: 1).frame(width: 42, height: 42)
                            Image(systemName: "calendar").font(.system(size: 18, weight: .medium)).foregroundStyle(Palette.mint)
                        }.accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Format.month(month, calendar: calendar)).font(.system(size: 22, weight: .bold)).tracking(-0.5)
                            Text("\(activeDays) işlem günü · \(p.count) kayıt").font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.muted)
                        }
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
                    let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7) + [GridItem(.fixed(112), spacing: 10)]
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"], id: \.self) { weekday in
                            Text(L10n.text(weekday)).font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(0.8)
                                .foregroundStyle(Palette.muted).padding(.vertical, 8).frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 10)
                        }
                        Text("HAFTA").font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(0.9)
                            .foregroundStyle(Palette.mint).padding(.vertical, 8).frame(maxWidth: .infinity, alignment: .trailing).padding(.trailing, 10)

                        ForEach(0..<totalRows, id: \.self) { row in
                            ForEach(0..<7, id: \.self) { col in
                                let cellIndex = row * 7 + col
                                if cellIndex < offset || cellIndex >= offset + count {
                                    RoundedRectangle(cornerRadius: 11)
                                        .fill(Palette.canvas.opacity(0.22))
                                        .frame(height: 106)
                                        .accessibilityHidden(true)
                                } else {
                                    let dayNum = cellIndex - offset + 1
                                    let date = calendar.date(byAdding: .day, value: dayNum - 1, to: interval.start)!
                                    let stats = dayStats[date] ?? Performance()
                                    let hasTrades = stats.count > 0
                                    let number = showR ? stats.totalR : stats.netPnL
                                    let intensity = hasTrades ? min(1.0, abs(number) / maxAbsDayValue) : 0
                                    Button {
                                        selectedDate = date
                                        if store.preferences.animations { EdgeHaptics.tick() }
                                    } label: {
                                        CalendarDayContent(
                                            day: dayNum,
                                            today: calendar.isDateInToday(date),
                                            hasTrades: hasTrades,
                                            count: stats.count,
                                            value: showR ? (stats.rCount == 0 ? "—" : Format.r(number)) : Format.money(number, currency: store.accountCurrency),
                                            color: Palette.outcome(number)
                                        )
                                    }
                                    .buttonStyle(CalendarDayButtonStyle(selected: selectedDate == date, color: hasTrades ? Palette.outcome(number) : Palette.muted, hasTrades: hasTrades, intensity: intensity))
                                    .accessibilityLabel("\(Format.date(date, calendar: calendar)), \(stats.count) işlem, \(showR ? (stats.rCount == 0 ? "R kaydedilmedi" : Format.r(stats.totalR)) : Format.money(stats.netPnL, currency: store.accountCurrency))")
                                    .accessibilityAddTraits(selectedDate == date ? .isSelected : [])
                                }
                            }
                            weekSummaryCell(row: row, offset: offset, count: count, start: interval.start, calendar: calendar, dayStats: dayStats)
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

    private func weekSummaryCell(row: Int, offset: Int, count: Int, start: Date, calendar: Calendar, dayStats: [Date: Performance]) -> some View {
        var weekPnL = 0.0
        var weekR = 0.0
        var weekRCount = 0
        var weekTrades = 0
        for col in 0..<7 {
            let idx = row * 7 + col
            guard idx >= offset && idx < offset + count else { continue }
            if let d = calendar.date(byAdding: .day, value: idx - offset, to: start),
               let s = dayStats[d] {
                weekPnL += s.netPnL
                weekR += s.totalR
                weekRCount += s.rCount
                weekTrades += s.count
            }
        }
        let value = showR ? weekR : weekPnL
        let color = weekTrades > 0 ? Palette.outcome(value) : Palette.muted
        return VStack(alignment: .trailing, spacing: 6) {
            Text("H\(row + 1)")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(Palette.muted)
            Spacer(minLength: 0)
            if weekTrades > 0 {
                Text(verbatim: showR ? (weekRCount == 0 ? "—" : Format.r(weekR)) : Format.money(weekPnL, currency: store.accountCurrency))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                Text("\(weekTrades) işlem")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Palette.muted)
            } else {
                Text("—")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Palette.muted.opacity(0.45))
            }
            Spacer(minLength: 0)
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .frame(height: 106)
        .background(weekTrades > 0 ? color.opacity(0.08) : Palette.field.opacity(0.45), in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(weekTrades > 0 ? color.opacity(0.26) : Palette.line.opacity(0.55), lineWidth: 1))
    }
}

private struct CalendarDayContent: View {
    let day: Int
    let today: Bool
    let hasTrades: Bool
    let count: Int
    let value: String
    let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(verbatim: "\(day)").font(.system(size: 12, weight: today ? .bold : .semibold)).monospacedDigit().foregroundStyle(today ? Palette.mint : Palette.muted)
                Spacer(minLength: 0)
                if today {
                    Circle().fill(Palette.mint).frame(width: 6, height: 6)
                        .shadow(color: Palette.mint.opacity(0.7), radius: 3)
                }
            }
            if hasTrades {
                VStack(alignment: .leading, spacing: 5) {
                    Text(verbatim: value).font(.system(size: 14, weight: .bold, design: .rounded)).monospacedDigit().foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.62)
                    Text(L10n.text("\(count) trades"))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(Palette.muted)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Palette.canvas.opacity(0.45), in: Capsule())
                }
            }
            Spacer(minLength: 0)
        }.padding(11).frame(height: 106).frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CalendarDayButtonStyle: ButtonStyle {
    let selected: Bool
    let color: Color
    let hasTrades: Bool
    let intensity: Double
    func makeBody(configuration: Configuration) -> some View {
        DayButtonBody(configuration: configuration, selected: selected, color: color, hasTrades: hasTrades, intensity: intensity)
    }
    private struct DayButtonBody: View {
        let configuration: ButtonStyleConfiguration
        let selected: Bool
        let color: Color
        let hasTrades: Bool
        let intensity: Double
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @Environment(\.edgeAnimationsEnabled) private var animationsEnabled
        @State private var hovered = false
        var body: some View {
            let shouldAnimate = animationsEnabled && !reduceMotion
            let baseFillOpacity = 0.065 + intensity * 0.16
            configuration.label
                .background(selected ? Palette.mint.opacity(0.14) : hovered ? Palette.raised.opacity(0.8) : hasTrades ? color.opacity(baseFillOpacity) : Palette.raised.opacity(0.24), in: RoundedRectangle(cornerRadius: 11))
                .overlay(alignment: .top) {
                    if hasTrades {
                        Capsule().fill(color.opacity(selected || hovered ? 0.95 : 0.45 + intensity * 0.45)).frame(height: 2.5).padding(.horizontal, 12).padding(.top, 2)
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(selected ? Palette.mint.opacity(0.85) : hasTrades && hovered ? color.opacity(0.55) : hasTrades ? color.opacity(0.18 + intensity * 0.22) : Palette.line.opacity(hovered ? 0.7 : 0.35), lineWidth: selected ? 1.5 : 1))
                .shadow(color: selected ? Palette.mint.opacity(0.18) : hovered ? .black.opacity(0.16) : .clear, radius: selected || hovered ? 9 : 0, x: 0, y: 3)
                .scaleEffect(configuration.isPressed ? 0.97 : (shouldAnimate && hovered ? 1.025 : 1.0))
                .contentShape(RoundedRectangle(cornerRadius: 11))
                .onHover { hovered = $0 }
                .animation(shouldAnimate ? .spring(response: 0.2, dampingFraction: 0.78) : nil, value: hovered)
                .animation(shouldAnimate ? .spring(response: 0.18, dampingFraction: 0.78) : nil, value: selected)
        }
    }
}
