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
    @State private var selectedPointID: Int?
    @State private var revealProgress: CGFloat = 1.0
    @Environment(JournalStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.edgeAnimationsEnabled) private var animationsEnabled

    private var animate: Bool { store.preferences.animations && animationsEnabled && !reduceMotion }

    private var color: Color {
        switch mode {
        case .drawdown: return Palette.red
        case .rolling: return Palette.blue
        default: return Palette.outcome(points.last.map(value) ?? 0)
        }
    }

    private var plottedPoints: [CurvePoint] {
        // Fast path: AnalyticsEngine.curve() already outputs points sorted ascending by date & id
        var alreadyOrdered = true
        for i in 0..<points.count {
            if !value(points[i]).isFinite { alreadyOrdered = false; break }
            if i > 0 {
                let prev = points[i - 1], curr = points[i]
                if prev.date > curr.date || (prev.date == curr.date && prev.id > curr.id) {
                    alreadyOrdered = false; break
                }
            }
        }
        if alreadyOrdered { return points }
        return points.filter { value($0).isFinite }.sorted { $0.date == $1.date ? $0.id < $1.id : $0.date < $1.date }
    }

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
        case .dollars, .drawdown: return Format.money(number, currency: store.accountCurrency)
        case .r: return Format.r(number)
        case .percent, .rolling: return Format.percent(number)
        }
    }

    private func formattedDelta(_ delta: Double) -> String {
        let sign = delta > 0 ? "+" : ""
        switch mode {
        case .dollars, .drawdown: return sign + Format.money(delta, currency: store.accountCurrency)
        case .r: return Format.r(delta)
        case .percent, .rolling: return sign + Format.percent(delta)
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
        var low = 0.0, high = 0.0
        for p in data {
            let v = value(p)
            if v < low { low = v }
            if v > high { high = v }
        }
        let minimumPadding: Double = mode == .r || mode == .percent ? 0.5 : 1
        let padding = max(minimumPadding, (high - low) * 0.14)
        return (low - padding)...(mode == .drawdown ? padding * 0.2 : high + padding)
    }

    private func nearest(to date: Date, in data: [CurvePoint]) -> CurvePoint? {
        guard !data.isEmpty else { return nil }
        // Binary search on ascending dates for O(log N) hover snapping
        var low = 0, high = data.count - 1
        while low < high {
            let mid = (low + high) / 2
            if data[mid].date < date { low = mid + 1 } else { high = mid }
        }
        var best = data[low]
        var bestDist = abs(best.date.timeIntervalSince(date))
        if low > 0 {
            let prev = data[low - 1]
            let d = abs(prev.date.timeIntervalSince(date))
            if d < bestDist { best = prev; bestDist = d }
        }
        if low + 1 < data.count {
            let next = data[low + 1]
            let d = abs(next.date.timeIntervalSince(date))
            if d < bestDist || (d == bestDist && next.id > best.id) { best = next }
        }
        return best
    }

    var body: some View {
        let data = plottedPoints
        let selectedIndex = selectedPointID.flatMap { id in data.firstIndex { $0.id == id } }
        let selected = selectedIndex.map { data[$0] }
        let previousValue: Double? = selectedIndex.flatMap { $0 > 0 ? value(data[$0 - 1]) : nil }
        let focus = selected ?? data.last

        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                    .shadow(color: color.opacity(0.6), radius: 3)
                Text(selected == nil ? "Son değer" : "Seçilen işlem #\(selected?.id ?? 0)")
                    .foregroundStyle(Palette.muted)
                if let focus {
                    Text(formatted(value(focus)))
                        .fontWeight(.semibold)
                        .foregroundStyle(color)
                        .monospacedDigit()
                        .contentTransition(animate ? .numericText() : .identity)
                    if let prev = previousValue {
                        let delta = value(focus) - prev
                        Text("(\(formattedDelta(delta)))")
                            .font(.system(size: height < 200 ? 9 : 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(Palette.outcome(delta))
                    }
                    Spacer(minLength: 8)
                    Text(Format.date(focus.date, calendar: store.preferences.calendar, time: true))
                        .foregroundStyle(Palette.muted)
                }
            }
            .font(.system(size: height < 200 ? 10 : 11))
            .lineLimit(1)
            .minimumScaleFactor(0.8)

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
                                    .init(color: color.opacity(0.28), location: 0),
                                    .init(color: color.opacity(0.10), location: 0.48),
                                    .init(color: color.opacity(0.002), location: 1)
                                ],
                                startPoint: mode == .drawdown ? .bottom : .top,
                                endPoint: mode == .drawdown ? .top : .bottom
                            ))
                            .interpolationMethod(.linear)

                        LineMark(x: .value("Tarih", point.date), y: .value("Performans", value(point)), series: .value("Katman", "Halo"))
                            .foregroundStyle(color.opacity(0.22))
                            .lineStyle(StrokeStyle(lineWidth: height < 200 ? 6.0 : 8.0, lineCap: .round, lineJoin: .round))
                            .interpolationMethod(.linear)

                        LineMark(x: .value("Tarih", point.date), y: .value("Performans", value(point)), series: .value("Katman", "Core"))
                            .foregroundStyle(LinearGradient(colors: [color.opacity(0.82), color], startPoint: .leading, endPoint: .trailing))
                            .lineStyle(StrokeStyle(lineWidth: height < 200 ? 2.1 : 2.6, lineCap: .round, lineJoin: .round))
                            .interpolationMethod(.linear)
                    }

                    RuleMark(y: .value("Başlangıç", 0))
                        .foregroundStyle(Palette.muted.opacity(0.32))
                        .lineStyle(StrokeStyle(lineWidth: 0.9, dash: [4, 5]))

                    if mode != .drawdown && mode != .rolling,
                       let peakVal = data.map(value).max(),
                       peakVal > 0.01 {
                        RuleMark(y: .value("Zirve", peakVal))
                            .foregroundStyle(color.opacity(0.24))
                            .lineStyle(StrokeStyle(lineWidth: 0.75, dash: [2, 5]))
                    }

                    if let focus {
                        if selected != nil {
                            RuleMark(x: .value("Seçilen tarih", focus.date))
                                .foregroundStyle(LinearGradient(colors: [color.opacity(0.08), color.opacity(0.5), color.opacity(0.08)], startPoint: .top, endPoint: .bottom))
                                .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                            RuleMark(y: .value("Seçilen değer", value(focus)))
                                .foregroundStyle(color.opacity(0.22))
                                .lineStyle(StrokeStyle(lineWidth: 0.8, dash: [2, 4]))
                        }

                        if selected != nil {
                            PointMark(x: .value("Tarih", focus.date), y: .value("Performans", value(focus)))
                                .foregroundStyle(color.opacity(0.18)).symbolSize(380)
                            PointMark(x: .value("Tarih", focus.date), y: .value("Performans", value(focus)))
                                .foregroundStyle(color.opacity(0.45)).symbolSize(130)
                        } else {
                            PointMark(x: .value("Tarih", focus.date), y: .value("Performans", value(focus)))
                                .foregroundStyle(color.opacity(0.14))
                                .symbolSize(280)
                            PointMark(x: .value("Tarih", focus.date), y: .value("Performans", value(focus)))
                                .foregroundStyle(color.opacity(0.32))
                                .symbolSize(110)
                        }

                        PointMark(x: .value("Tarih", focus.date), y: .value("Performans", value(focus)))
                            .foregroundStyle(color)
                            .symbolSize(selected == nil ? 40 : 68)
                            .annotation(
                                position: .top,
                                spacing: 12,
                                overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))
                            ) {
                                if selected != nil {
                                    hudTooltip(focus: focus, previousValue: previousValue)
                                }
                            }
                            .annotation(position: .overlay) {
                                Circle().fill(Color.white).frame(width: 3.5, height: 3.5)
                            }
                    }
                }
                .chartXScale(domain: dateDomain(data))
                .chartYScale(domain: valueDomain(data))
                .chartPlotStyle { plot in
                    plot
                        .background(LinearGradient(colors: [Palette.canvas.opacity(0.22), Palette.canvas.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                        .mask(alignment: .leading) {
                            GeometryReader { geo in
                                Rectangle().frame(width: max(1, geo.size.width * revealProgress))
                            }
                        }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: height < 200 ? 3 : 5)) { axis in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.55)).foregroundStyle(Palette.muted.opacity(0.1))
                        AxisValueLabel {
                            if let number = axis.as(Double.self) {
                                Text(axisValue(number))
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(Palette.muted.opacity(0.85))
                                    .padding(.leading, 8)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: height < 200 ? 3 : 5)) { axis in
                        AxisTick(length: 4).foregroundStyle(Palette.muted.opacity(0.18))
                        AxisValueLabel {
                            if let date = axis.as(Date.self) {
                                Text(axisDate(date, data: data))
                                    .font(.system(size: 10))
                                    .foregroundStyle(Palette.muted.opacity(0.85))
                                    .padding(.top, 6)
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
                                guard frame.contains(location) else {
                                    if selectedPointID != nil { selectedPointID = nil }
                                    return
                                }
                                if let hoveredDate = proxy.value(atX: location.x - frame.minX, as: Date.self),
                                   let snapped = nearest(to: hoveredDate, in: data),
                                   snapped.id != selectedPointID {
                                    selectedPointID = snapped.id
                                    if animate { EdgeHaptics.tick() }
                                }
                            case .ended:
                                if selectedPointID != nil { selectedPointID = nil }
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
        .background(presentation == .dashboard ? Palette.canvas.opacity(0.32) : .clear, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(presentation == .dashboard ? Palette.muted.opacity(0.08) : .clear))
        .animation(animate ? .spring(response: 0.36, dampingFraction: 0.82) : nil, value: mode)
        .animation(animate ? .spring(response: 0.22, dampingFraction: 0.86) : nil, value: selectedPointID)
        .onAppear {
            if animate {
                revealProgress = 0.02
                withAnimation(.easeOut(duration: 0.62)) { revealProgress = 1.0 }
            } else {
                revealProgress = 1.0
            }
        }
        .onChange(of: points.count) { _, _ in
            selectedPointID = nil
            if animate {
                revealProgress = 0.05
                withAnimation(.easeOut(duration: 0.48)) { revealProgress = 1.0 }
            }
        }
    }

    private func hudTooltip(focus: CurvePoint, previousValue: Double?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 5, height: 5)
                Text(formatted(value(focus)))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)
                if let prev = previousValue {
                    let delta = value(focus) - prev
                    Text(formattedDelta(delta))
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Palette.outcome(delta))
                        .padding(.horizontal, 5).padding(.vertical, 1.5)
                        .background(Palette.outcome(delta).opacity(0.14), in: Capsule())
                }
            }
            HStack(spacing: 8) {
                Text(Format.date(focus.date, calendar: store.preferences.calendar, time: true))
                    .font(.system(size: 9))
                    .foregroundStyle(Palette.muted)
                if mode != .r && focus.r.isFinite {
                    Text(Format.r(focus.r))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(Palette.ink.opacity(0.85))
                }
                if focus.drawdown < -0.005 {
                    Text("DD \(Format.money(focus.drawdown, currency: store.accountCurrency))")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Palette.red)
                }
            }
        }
        .padding(.horizontal, 11).padding(.vertical, 7)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 9))
        .background(Palette.canvas.opacity(0.86), in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(color.opacity(0.45), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 5)
        .transition(.scale(scale: 0.92).combined(with: .opacity))
    }
}

enum GroupMetric: String, CaseIterable {
    case averageR = "Average R", winRate = "Win rate", pnl = "Net PnL", expectancy = "Expectancy", profitFactor = "Profit factor"
}

struct GroupBarChart: View {
    var groups: [MetricGroup]
    var metric: GroupMetric
    @Environment(JournalStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.edgeAnimationsEnabled) private var animationsEnabled
    @State private var hoveredGroupName: String? = nil

    private var animate: Bool { store.preferences.animations && animationsEnabled && !reduceMotion }

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
        case .pnl: return Format.money(performance.netPnL, currency: store.accountCurrency)
        case .expectancy: return Format.money(performance.expectancy, currency: store.accountCurrency)
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
                            let isFocused = hoveredGroupName == group.name
                            let dimmed = hoveredGroupName != nil && !isFocused
                            BarMark(x: .value(L10n.text(metric.rawValue), number), y: .value("Grup", group.name), height: .fixed(isFocused ? 18 : 15))
                                .foregroundStyle(LinearGradient(
                                    colors: [
                                        Palette.outcome(number).opacity(isFocused ? 1.0 : dimmed ? 0.38 : 0.94),
                                        Palette.outcome(number).opacity(isFocused ? 0.72 : dimmed ? 0.2 : 0.52)
                                    ],
                                    startPoint: .trailing,
                                    endPoint: .leading
                                ))
                                .cornerRadius(5)
                                .annotation(position: number < 0 ? .leading : .trailing, spacing: 9, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                                    Text(formatted(group.performance))
                                        .font(.system(size: isFocused ? 11 : 10, weight: isFocused ? .bold : .medium, design: .monospaced))
                                        .foregroundStyle(isFocused ? Palette.outcome(number) : Palette.ink)
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
                                    Text(L10n.text(name))
                                        .font(.system(size: 11, weight: hoveredGroupName == name ? .semibold : .medium))
                                        .foregroundStyle(hoveredGroupName == name ? Palette.mint : Palette.ink)
                                        .lineLimit(2)
                                    if let group = plotted.first(where: { $0.name == name }) {
                                        Text("n = \(group.performance.count)").font(.system(size: 9, design: .monospaced)).foregroundStyle(Palette.muted)
                                    }
                                }.frame(maxWidth: 170, alignment: .trailing).padding(.trailing, 8)
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
                                guard frame.contains(location) else {
                                    if hoveredGroupName != nil { hoveredGroupName = nil }
                                    return
                                }
                                let hit = proxy.value(atY: location.y - frame.minY, as: String.self)
                                if hit != hoveredGroupName {
                                    hoveredGroupName = hit
                                    if hit != nil && animate { EdgeHaptics.tick() }
                                }
                            case .ended:
                                if hoveredGroupName != nil { hoveredGroupName = nil }
                            }
                        }
                    }
                }
                .chartXAxisLabel(L10n.text(metric.rawValue) + ((metric == .pnl || metric == .expectancy) ? " · " + store.accountCurrency : ""), position: .bottom, alignment: .trailing, spacing: 10)
                .frame(height: max(180, CGFloat(plotted.count) * 50 + 42))
                .padding(.trailing, 10)
                .animation(animate ? .spring(response: 0.28, dampingFraction: 0.82) : nil, value: hoveredGroupName)
                .animation(animate ? .spring(response: 0.38, dampingFraction: 0.82) : nil, value: metric)
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
    var precomputedBuckets: [Int: Performance]? = nil
    @Environment(JournalStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.edgeAnimationsEnabled) private var animationsEnabled
    @State private var hoveredCellKey: Int? = nil
    @State private var localBuckets: [Int: Performance] = [:]
    @State private var localSignature = ""
    private let cellWidth: CGFloat = 48

    private var animate: Bool { store.preferences.animations && animationsEnabled && !reduceMotion }

    private var inputSignature: String {
        "\(trades.count)-\(trades.first?.id.uuidString ?? "")-\(trades.last?.id.uuidString ?? "")-\(calendar.timeZone.identifier)"
    }

    private var resolvedBuckets: [Int: Performance] {
        if let precomputedBuckets { return precomputedBuckets }
        if localSignature == inputSignature { return localBuckets }
        return AnalyticsEngine.heatmapBuckets(trades, calendar: calendar)
    }
    private func slots(_ values: [Int: Performance]) -> ClosedRange<Int> {
        let recorded = values.keys.map { $0 % 100 }
        guard let first = recorded.min(), let last = recorded.max() else { return 18...33 }
        return max(0, first - 1)...min(47, max(first + 7, last + 1))
    }
    private func time(_ slot: Int) -> String { String(format: "%02d:%02d", slot / 2, slot % 2 * 30) }

    var body: some View {
        let values = resolvedBuckets, range = slots(values)
        let weekdays = (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }
        VStack(alignment: .leading, spacing: 16) {
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
                                    let key = day * 100 + slot
                                    let performance = values[key]
                                    let dayName = L10n.text(calendar.weekdaySymbols[day - 1])
                                    let timeLabel = time(slot)
                                    HeatmapCell(
                                        performance: performance,
                                        isHovered: hoveredCellKey == key,
                                        cellWidth: cellWidth,
                                        dayName: dayName,
                                        timeLabel: timeLabel,
                                        onHover: { h in
                                            let next = h ? key : (hoveredCellKey == key ? nil : hoveredCellKey)
                                            if next != hoveredCellKey {
                                                hoveredCellKey = next
                                                if h && performance != nil && animate { EdgeHaptics.tick() }
                                            }
                                        }
                                    )
                                }
                            }
                        }
                    }.padding(.bottom, 8)
                }
            }

            if let key = hoveredCellKey, let perf = values[key] {
                let dayIndex = key / 100
                let slotIndex = key % 100
                HStack(spacing: 14) {
                    Circle().fill(Palette.outcome(perf.averageR ?? perf.netPnL)).frame(width: 6, height: 6)
                    Text("\(L10n.text(calendar.weekdaySymbols[max(0, min(6, dayIndex - 1))])) · \(time(slotIndex))")
                        .font(.system(size: 11, weight: .semibold))
                    Spacer()
                    Text("n = \(perf.count)").font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.muted)
                    Text("WR \(Format.percent(perf.winRate))").font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.ink)
                    Text(Format.r(perf.averageR)).font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(Palette.outcome(perf.averageR ?? 0))
                    Text(Format.money(perf.netPnL, currency: store.accountCurrency)).font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(Palette.outcome(perf.netPnL))
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Palette.field.opacity(0.85), in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Palette.mint.opacity(0.25)))
                .transition(.opacity.combined(with: .move(edge: .bottom)))
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
        .animation(animate ? .spring(response: 0.24, dampingFraction: 0.82) : nil, value: hoveredCellKey)
        .onAppear {
            if precomputedBuckets == nil {
                localBuckets = AnalyticsEngine.heatmapBuckets(trades, calendar: calendar)
                localSignature = inputSignature
            }
        }
        .onChange(of: inputSignature) { _, nextSig in
            if precomputedBuckets == nil {
                localBuckets = AnalyticsEngine.heatmapBuckets(trades, calendar: calendar)
                localSignature = nextSig
            }
        }
    }
}

private struct HeatmapCell: View {
    let performance: Performance?
    let isHovered: Bool
    let cellWidth: CGFloat
    let dayName: String
    let timeLabel: String
    let onHover: (Bool) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.edgeAnimationsEnabled) private var animationsEnabled

    private var averageR: Double? { performance?.averageR }

    private var cellText: String {
        averageR.map { Format.number($0, digits: 1) } ?? (performance == nil ? "·" : "—")
    }

    private var cellColor: Color {
        averageR.map(Palette.outcome) ?? Palette.muted.opacity(performance == nil ? 0.25 : 0.8)
    }

    private var cellBackground: Color {
        averageR.map { Palette.outcome($0).opacity(min(0.35, 0.09 + abs($0) * 0.08)) } ?? Palette.canvas.opacity(0.33)
    }

    private var cellBorder: Color {
        isHovered ? Palette.mint : (averageR.map { Palette.outcome($0).opacity(0.22) } ?? Palette.muted.opacity(0.055))
    }

    var body: some View {
        let shouldAnimate = animationsEnabled && !reduceMotion
        VStack(spacing: 4) {
            Text(cellText)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
            if let performance {
                Text("n=\(performance.count)").font(.system(size: 8)).opacity(0.75)
            }
        }
        .foregroundStyle(cellColor)
        .frame(width: cellWidth, height: 46)
        .background(cellBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(cellBorder, lineWidth: isHovered ? 1.5 : 1))
        .shadow(color: isHovered ? Palette.mint.opacity(0.22) : .clear, radius: 6, x: 0, y: 2)
        .scaleEffect(shouldAnimate && isHovered ? 1.09 : 1.0)
        .zIndex(isHovered ? 10 : 1)
        .onHover(perform: onHover)
        .animation(shouldAnimate ? .spring(response: 0.2, dampingFraction: 0.72) : nil, value: isHovered)
        .help("\(dayName) · \(timeLabel) · n = \(performance?.count ?? 0) · \(Format.r(averageR))")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(dayName), \(timeLabel), \(performance?.count ?? 0) işlem, \(Format.r(averageR))")
    }
}
