import SwiftUI
import Charts

enum CurveMode: String, CaseIterable {
    case dollars = "$", r = "R", percent = "%", drawdown = "Drawdown", rolling = "Rolling WR"
}

enum ChartPresentation { case standard, dashboard }

struct EquityChart: View {
    var points: [CurvePoint]
    var mode: CurveMode = .dollars
    var accountSize: Double = 50000
    var height: CGFloat = 260
    var presentation: ChartPresentation = .standard
    @State private var selectedDate: Date?
    @Environment(JournalStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var color: Color {
        switch mode {
        case .drawdown: return Palette.red
        case .rolling: return Palette.blue
        default: return Palette.outcome(points.last.map(value) ?? 0)
        }
    }
    private var plottedPoints: [CurvePoint] { points.filter { value($0).isFinite }.sorted { $0.date == $1.date ? $0.id < $1.id : $0.date < $1.date } }
    private func value(_ point: CurvePoint) -> Double {
        switch mode {
        case .dollars: return point.equity
        case .r: return point.r
        case .percent: return accountSize > 0 ? point.equity / accountSize * 100 : 0
        case .drawdown: return point.drawdown
        case .rolling: return point.rollingWinRate
        }
    }
    private func formatted(_ number: Double) -> String {
        switch mode {
        case .dollars, .drawdown: return Format.money(number, currency: store.preferences.currency)
        case .r: return Format.r(number)
        case .percent, .rolling: return Format.percent(number)
        }
    }
    private func axisValue(_ number: Double) -> String {
        let numberText = number.formatted(.number.locale(L10n.locale).notation(.compactName).precision(.fractionLength(0...1)))
        switch mode {
        case .r: return numberText + "R"
        case .percent, .rolling: return numberText + "%"
        case .dollars, .drawdown: return numberText
        }
    }
    private func axisDate(_ date: Date, data: [CurvePoint]) -> String {
        let span = data.last?.date.timeIntervalSince(data.first?.date ?? date) ?? 0
        var style = span < 86400 ? Date.FormatStyle().hour().minute() : Date.FormatStyle().day().month(.abbreviated)
        if span > 120 * 86400 { style = Date.FormatStyle().month(.abbreviated).year(.twoDigits) }
        style.locale = L10n.locale
        style.calendar = store.preferences.calendar
        style.timeZone = store.preferences.calendar.timeZone
        return date.formatted(style)
    }
    private func dateDomain(_ data: [CurvePoint]) -> ClosedRange<Date> {
        let first = data.first?.date ?? Date(), last = data.last?.date ?? Date()
        let span = last.timeIntervalSince(first)
        let padding = max(60, span * 0.025)
        return first.addingTimeInterval(-padding)...last.addingTimeInterval(padding)
    }
    private func valueDomain(_ data: [CurvePoint]) -> ClosedRange<Double> {
        if mode == .rolling { return 0...100 }
        let values = data.map(value), low = min(0, values.min() ?? 0), high = max(0, values.max() ?? 0)
        let minimumPadding: Double = mode == .r || mode == .percent ? 0.5 : 1
        let padding = max(minimumPadding, (high - low) * 0.12)
        return (low - padding)...(mode == .drawdown ? padding * 0.2 : high + padding)
    }
    private func nearest(_ date: Date, in data: [CurvePoint]) -> CurvePoint? {
        data.min {
            let left = abs($0.date.timeIntervalSince(date)), right = abs($1.date.timeIntervalSince(date))
            return left == right ? $0.id > $1.id : left < right
        }
    }

    var body: some View {
        let data = plottedPoints
        let selected = selectedDate.flatMap { nearest($0, in: data) }
        let focus = selected ?? data.last
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(selected == nil ? "Son değer" : "Seçilen nokta").foregroundStyle(Palette.muted)
                if let focus {
                    Text(formatted(value(focus))).fontWeight(.semibold).foregroundStyle(color).monospacedDigit()
                    Spacer(minLength: 8)
                    Text(Format.date(focus.date, calendar: store.preferences.calendar, time: true)).foregroundStyle(Palette.muted)
                }
            }.font(.system(size: height < 200 ? 10 : 11)).lineLimit(1).minimumScaleFactor(0.8)
            if data.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "chart.xyaxis.line").font(.system(size: 26, weight: .light)).foregroundStyle(Palette.muted.opacity(0.7))
                    Text("Grafik için henüz veri yok").font(.caption).foregroundStyle(Palette.muted)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Chart {
                    ForEach(data) { point in
                        AreaMark(x: .value("Tarih", point.date), y: .value("Performans", value(point)))
                            .foregroundStyle(LinearGradient(
                                stops: [
                                    .init(color: color.opacity(0.26), location: 0),
                                    .init(color: color.opacity(0.09), location: 0.5),
                                    .init(color: color.opacity(0.002), location: 1)
                                ],
                                startPoint: mode == .drawdown ? .bottom : .top,
                                endPoint: mode == .drawdown ? .top : .bottom
                            ))
                            .interpolationMethod(.linear)

                        // Subtle glowing backdrop stroke
                        LineMark(x: .value("Tarih", point.date), y: .value("Performans", value(point)))
                            .foregroundStyle(color.opacity(0.24))
                            .lineStyle(StrokeStyle(lineWidth: height < 200 ? 5.5 : 7.0, lineCap: .round, lineJoin: .round))
                            .interpolationMethod(.linear)

                        // Crisp core stroke
                        LineMark(x: .value("Tarih", point.date), y: .value("Performans", value(point)))
                            .foregroundStyle(LinearGradient(colors: [color, color.opacity(0.85)], startPoint: .leading, endPoint: .trailing))
                            .lineStyle(StrokeStyle(lineWidth: height < 200 ? 2.1 : 2.6, lineCap: .round, lineJoin: .round))
                            .interpolationMethod(.linear)
                    }
                    RuleMark(y: .value("Başlangıç", 0)).foregroundStyle(Palette.muted.opacity(0.3)).lineStyle(StrokeStyle(lineWidth: 0.8, dash: [4, 5]))
                    if let focus {
                        if selected != nil {
                            RuleMark(x: .value("Seçilen tarih", focus.date))
                                .foregroundStyle(color.opacity(0.4))
                                .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                            RuleMark(y: .value("Seçilen değer", value(focus)))
                                .foregroundStyle(color.opacity(0.2))
                                .lineStyle(StrokeStyle(lineWidth: 0.8, dash: [2, 4]))
                        }
                        // Concentric interactive pulse
                        if selected != nil {
                            PointMark(x: .value("Tarih", focus.date), y: .value("Performans", value(focus)))
                                .foregroundStyle(color.opacity(0.18)).symbolSize(360)
                            PointMark(x: .value("Tarih", focus.date), y: .value("Performans", value(focus)))
                                .foregroundStyle(color.opacity(0.42)).symbolSize(120)
                        } else {
                            PointMark(x: .value("Tarih", focus.date), y: .value("Performans", value(focus)))
                                .foregroundStyle(color.opacity(0.15)).symbolSize(180)
                        }
                        PointMark(x: .value("Tarih", focus.date), y: .value("Performans", value(focus)))
                            .foregroundStyle(color).symbolSize(selected == nil ? 36 : 64)
                            .annotation(position: .top, spacing: 10) {
                                if selected != nil {
                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(spacing: 6) {
                                            Circle().fill(color).frame(width: 5, height: 5)
                                            Text(formatted(value(focus)))
                                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                                .foregroundStyle(color)
                                            if mode != .r && focus.r.isFinite {
                                                Text(Format.r(focus.r))
                                                    .font(.system(size: 10, design: .monospaced))
                                                    .foregroundStyle(Palette.muted)
                                            }
                                        }
                                        HStack(spacing: 6) {
                                            Text(Format.date(focus.date, calendar: store.preferences.calendar, time: true))
                                                .font(.system(size: 9))
                                                .foregroundStyle(Palette.muted)
                                            if focus.drawdown > 0 {
                                                Text("DD: \(Format.money(focus.drawdown, currency: store.preferences.currency))")
                                                    .font(.system(size: 9, design: .monospaced))
                                                    .foregroundStyle(Palette.red)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                                    .background(Palette.canvas.opacity(0.85), in: RoundedRectangle(cornerRadius: 8))
                                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(color.opacity(0.4), lineWidth: 1))
                                    .shadow(color: Color.black.opacity(0.35), radius: 8, x: 0, y: 4)
                                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                                }
                            }
                            .annotation(position: .overlay) { Circle().fill(Color.white).frame(width: 3.5, height: 3.5) }
                    }
                }
                .chartXScale(domain: dateDomain(data))
                .chartYScale(domain: valueDomain(data))
                .chartXSelection(value: $selectedDate)
                .chartPlotStyle { plot in
                    plot.background(LinearGradient(colors: [Palette.canvas.opacity(0.16), Palette.canvas.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                }
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: height < 200 ? 3 : 5)) { axis in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.6)).foregroundStyle(Palette.muted.opacity(0.1))
                        AxisValueLabel { if let number = axis.as(Double.self) { Text(axisValue(number)).font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.muted.opacity(0.85)).padding(.leading, 8) } }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: height < 200 ? 3 : 5)) { axis in
                        AxisTick(length: 4).foregroundStyle(Palette.muted.opacity(0.18))
                        AxisValueLabel {
                            if let date = axis.as(Date.self) {
                                Text(axisDate(date, data: data)).font(.system(size: 10)).foregroundStyle(Palette.muted.opacity(0.85)).padding(.top, 6)
                            }
                        }
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Color.clear.contentShape(Rectangle()).onContinuousHover { phase in
                            switch phase {
                            case .active(let location):
                                guard let plotFrame = proxy.plotFrame else { return }
                                let frame = geometry[plotFrame]
                                guard frame.contains(location) else { selectedDate = nil; return }
                                selectedDate = proxy.value(atX: location.x - frame.minX, as: Date.self)
                            case .ended: selectedDate = nil
                            }
                        }
                    }
                }
                .padding(.top, 3)
                .accessibilityLabel(L10n.text("\(mode.rawValue) performance curve, \(max(0, points.count - (points.first?.id == 0 ? 1 : 0))) trades"))
                .accessibilityValue(focus.map { formatted(value($0)) } ?? "")
            }
        }
        .padding(presentation == .dashboard ? 14 : 4)
        .frame(height: height)
        .background(presentation == .dashboard ? Palette.canvas.opacity(0.27) : .clear, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(presentation == .dashboard ? Palette.muted.opacity(0.06) : .clear))
        .animation(store.preferences.animations && !reduceMotion ? .easeInOut(duration: 0.22) : nil, value: mode)
        .onChange(of: points.count) { _, _ in selectedDate = nil }
    }
}

enum GroupMetric: String, CaseIterable {
    case averageR = "Average R", winRate = "Win rate", pnl = "Net PnL", expectancy = "Expectancy", profitFactor = "Profit factor"
}

struct GroupBarChart: View {
    var groups: [MetricGroup]
    var metric: GroupMetric
    @Environment(JournalStore.self) private var store
    @State private var hoveredGroupName: String? = nil

    private func value(_ performance: Performance) -> Double? {
        switch metric {
        case .averageR: return performance.averageR
        case .winRate: return performance.winRate
        case .pnl: return performance.netPnL
        case .expectancy: return performance.expectancy
        case .profitFactor: return performance.profitFactor
        }
    }
    private func formatted(_ performance: Performance) -> String {
        switch metric {
        case .averageR: return Format.r(performance.averageR)
        case .winRate: return Format.percent(performance.winRate)
        case .pnl: return Format.money(performance.netPnL, currency: store.preferences.currency)
        case .expectancy: return Format.money(performance.expectancy, currency: store.preferences.currency)
        case .profitFactor: return Format.factor(performance)
        }
    }
    private func domain(_ data: [MetricGroup]) -> ClosedRange<Double> {
        if metric == .winRate { return 0...100 }
        let values = data.compactMap { value($0.performance) }
        let low = min(0, values.min() ?? 0), high = max(0, values.max() ?? 0)
        let padding = max(0.25, (high - low) * 0.28)
        return (low < 0 ? low - padding : 0)...max(padding, high + padding)
    }

    private func axisText(_ number: Double) -> String {
        let compact = number.formatted(.number.locale(L10n.locale).notation(.compactName).precision(.fractionLength(0...1)))
        switch metric {
        case .averageR: return compact + "R"
        case .winRate: return compact + "%"
        case .pnl, .expectancy: return compact
        case .profitFactor: return compact + "×"
        }
    }
    var body: some View {
        let plotted = groups.filter { value($0.performance)?.isFinite == true }
        let missing = groups.filter { value($0.performance) == nil }
        VStack(alignment: .leading, spacing: 14) {
            if !plotted.isEmpty {
                Chart {
                    RuleMark(x: .value("Sıfır", 0)).foregroundStyle(Palette.muted.opacity(0.35))
                    ForEach(plotted) { group in
                        if let number = value(group.performance) {
                            BarMark(x: .value(L10n.text(metric.rawValue), number), y: .value("Grup", group.name), height: .fixed(15))
                                .foregroundStyle(LinearGradient(colors: [Palette.outcome(number).opacity(0.95), Palette.outcome(number).opacity(0.55)], startPoint: .trailing, endPoint: .leading))
                                .cornerRadius(4)
                                .annotation(position: number < 0 ? .leading : .trailing, spacing: 9, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                                    Text(formatted(group.performance)).font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(Palette.ink)
                                }
                                .accessibilityLabel(L10n.text(group.name))
                                .accessibilityValue("\(formatted(group.performance)), \(group.performance.count) işlem")
                        }
                    }
                }
                .chartXScale(domain: domain(plotted))
                .chartYScale(domain: plotted.map(\.name))
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { axis in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 4])).foregroundStyle(Palette.muted.opacity(0.16))
                        AxisValueLabel { if let number = axis.as(Double.self) { Text(axisText(number)).font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.muted) } }
                    }
                }
                .chartYAxis {
                    AxisMarks(preset: .aligned, position: .leading) { axis in
                        AxisValueLabel {
                            if let name = axis.as(String.self) {
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(L10n.text(name)).font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.ink).lineLimit(2)
                                    if let group = plotted.first(where: { $0.name == name }) { Text("n = \(group.performance.count)").font(.system(size: 9, design: .monospaced)).foregroundStyle(Palette.muted) }
                                }.frame(maxWidth: 170, alignment: .trailing).padding(.trailing, 8)
                            }
                        }
                    }
                }
                .chartXAxisLabel(L10n.text(metric.rawValue) + ((metric == .pnl || metric == .expectancy) ? " · " + store.preferences.currency : ""), position: .bottom, alignment: .trailing, spacing: 10)
                .frame(height: max(180, CGFloat(plotted.count) * 50 + 42))
                .padding(.trailing, 10)
            }
            if !missing.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle").foregroundStyle(Palette.muted)
                    Text(missing.map { "\(L10n.text($0.name)): \(formatted($0.performance))" }.joined(separator: "  ·  "))
                        .foregroundStyle(Palette.muted).textSelection(.enabled)
                }.font(.caption)
                if metric == .profitFactor {
                    Text("∞: Kaybeden işlem yok. —: Oran hesaplanamıyor.").font(.caption).foregroundStyle(Palette.muted)
                } else if metric == .averageR {
                    Text("Bu gruplarda ortalama R için kayıt bulunmuyor.").font(.caption).foregroundStyle(Palette.muted)
                }
            }
        }
    }
}

struct PerformanceHeatmap: View {
    var trades: [TradeRecord]
    var calendar: Calendar
    @State private var hoveredCellKey: Int? = nil
    private let cellWidth: CGFloat = 48
    private var buckets: [Int: Performance] {
        let grouped = Dictionary(grouping: trades) { trade in
            calendar.component(.weekday, from: trade.date) * 100 + calendar.component(.hour, from: trade.date) * 2 + (calendar.component(.minute, from: trade.date) >= 30 ? 1 : 0)
        }
        return grouped.mapValues { AnalyticsEngine.performance($0) }
    }
    private func slots(_ values: [Int: Performance]) -> ClosedRange<Int> {
        let recorded = values.keys.map { $0 % 100 }
        guard let first = recorded.min(), let last = recorded.max() else { return 18...33 }
        return max(0, first - 1)...min(47, max(first + 7, last + 1))
    }
    private func time(_ slot: Int) -> String { String(format: "%02d:%02d", slot / 2, slot % 2 * 30) }

    var body: some View {
        let values = buckets, range = slots(values)
        let weekdays = (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("GÜN").font(.system(size: 9, weight: .semibold)).tracking(1).foregroundStyle(Palette.muted).frame(height: 22)
                    ForEach(weekdays, id: \.self) { day in
                        Text(L10n.text(calendar.shortWeekdaySymbols[day - 1])).font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.muted).frame(height: 46)
                    }
                }.frame(width: 38, alignment: .leading)
                ScrollView(.horizontal) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            ForEach(range, id: \.self) { slot in Text(time(slot)).frame(width: cellWidth) }
                        }.font(.system(size: 9, design: .monospaced)).foregroundStyle(Palette.muted.opacity(0.8)).frame(height: 22)
                        ForEach(weekdays, id: \.self) { day in
                            HStack(spacing: 6) {
                                ForEach(range, id: \.self) { slot in
                                    let performance = values[day * 100 + slot]
                                    let averageR = performance?.averageR
                                    VStack(spacing: 4) {
                                        Text(averageR.map { Format.number($0, digits: 1) } ?? (performance == nil ? "·" : "—"))
                                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        if let performance { Text("n=\(performance.count)").font(.system(size: 8)).opacity(0.7) }
                                    }
                                    .foregroundStyle(averageR.map(Palette.outcome) ?? Palette.muted.opacity(performance == nil ? 0.25 : 0.8))
                                    .frame(width: cellWidth, height: 46)
                                    .background(averageR.map { Palette.outcome($0).opacity(min(0.3, 0.08 + abs($0) * 0.07)) } ?? Palette.canvas.opacity(0.33), in: RoundedRectangle(cornerRadius: 8))
                                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(hoveredCellKey == (day * 100 + slot) ? Palette.mint : (averageR.map { Palette.outcome($0).opacity(0.18) } ?? Palette.muted.opacity(0.055)), lineWidth: hoveredCellKey == (day * 100 + slot) ? 1.5 : 1))
                                    .scaleEffect(hoveredCellKey == (day * 100 + slot) ? 1.08 : 1.0)
                                    .zIndex(hoveredCellKey == (day * 100 + slot) ? 10 : 1)
                                    .onHover { h in hoveredCellKey = h ? (day * 100 + slot) : nil }
                                    .animation(.spring(response: 0.2, dampingFraction: 0.72), value: hoveredCellKey)
                                    .help("\(L10n.text(calendar.weekdaySymbols[day - 1])) · \(time(slot)) · n = \(performance?.count ?? 0) · \(Format.r(averageR))")
                                    .accessibilityElement(children: .ignore)
                                    .accessibilityLabel("\(L10n.text(calendar.weekdaySymbols[day - 1])), \(time(slot)), \(performance?.count ?? 0) işlem, \(Format.r(averageR))")
                                }
                            }
                        }
                    }.padding(.bottom, 8)
                }
            }
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Yarım saatlik giriş aralıkları · \(calendar.timeZone.identifier)")
                    Text("Hücreler ortalama R’yi gösterir · n = işlem sayısı").foregroundStyle(Palette.muted.opacity(0.7))
                }
                Spacer(minLength: 8)
                HStack(spacing: 6) {
                    Text("Negatif")
                    ForEach(0..<7) { index in
                        RoundedRectangle(cornerRadius: 2).fill(index < 3 ? Palette.red.opacity(0.65 - Double(index) * 0.18) : index == 3 ? Palette.raised : Palette.mint.opacity(0.2 + Double(index - 4) * 0.22)).frame(width: 12, height: 8)
                    }
                    Text("Pozitif")
                }
            }.font(.system(size: 9)).foregroundStyle(Palette.muted)
        }
    }
}
