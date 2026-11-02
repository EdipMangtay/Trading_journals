import SwiftUI
import Charts

/// A descriptive view of the current filtered observations. Every plotted point
/// keeps its original values; missing axes are excluded rather than filled in.
struct TradeScatterChart: View {
    var trades: [TradeRecord]
    @Environment(JournalStore.self) private var store
    @State private var horizontal = HorizontalMeasure.process
    @State private var vertical = VerticalMeasure.r
    @State private var selectedID: UUID?

    private enum HorizontalMeasure: String, CaseIterable, Identifiable {
        case process = "Süreç puanı", risk = "Risk (%)", duration = "İşlem süresi"
        var id: String { rawValue }
        var axisTitle: String {
            switch self {
            case .process: return "SÜREÇ PUANI / 100"
            case .risk: return "KAYDEDİLEN RİSK (%)"
            case .duration: return "İŞLEM SÜRESİ (DAKİKA)"
            }
        }
        func value(_ trade: TradeRecord) -> Double? {
            switch self {
            case .process: return trade.scores.overall
            case .risk: return trade.riskPercent
            case .duration: return trade.duration.map { $0 / 60 }
            }
        }
    }
    private enum VerticalMeasure: String, CaseIterable, Identifiable {
        case r = "Sonuç (R)", pnl = "Net K/Z"
        var id: String { rawValue }
        func value(_ trade: TradeRecord) -> Double? { self == .r ? trade.rMultiple : trade.netPnL }
    }
    private struct Observation: Identifiable {
        let trade: TradeRecord
        let x: Double
        let y: Double
        var id: UUID { trade.id }
    }
    private var observations: [Observation] {
        trades.compactMap { trade in
            guard let x = horizontal.value(trade), let y = vertical.value(trade), x.isFinite, y.isFinite else { return nil }
            return Observation(trade: trade, x: x, y: y)
        }
    }
    private func processColor(_ trade: TradeRecord) -> Color { trade.compliant ? Palette.mint : Palette.amber }
    private func xFormatted(_ number: Double) -> String {
        switch horizontal {
        case .process: return Format.number(number, digits: 1) + " / 100"
        case .risk: return Format.percent(number)
        case .duration: return Format.number(number, digits: 1) + " dk"
        }
    }
    private func yFormatted(_ number: Double) -> String {
        vertical == .r ? Format.r(number) : Format.money(number, currency: store.preferences.currency)
    }
    private func compact(_ number: Double) -> String {
        number.formatted(.number.locale(L10n.locale).notation(.compactName).precision(.fractionLength(0...1)))
    }
    private func xDomain(_ data: [Observation]) -> ClosedRange<Double> {
        if horizontal == .process { return 0...100 }
        let high = data.map(\.x).max() ?? 0
        let upper = high * 1.12
        return 0...max(horizontal == .risk ? 1 : 5, upper.isFinite ? upper : Double.greatestFiniteMagnitude)
    }
    private func xTicks(_ data: [Observation]) -> [Double] {
        let upper = xDomain(data).upperBound
        return (0...4).map { Double($0) * (upper / 4) }
    }
    private func yDomain(_ data: [Observation]) -> ClosedRange<Double> {
        let values = data.map(\.y)
        let low = min(0, values.min() ?? 0), high = max(0, values.max() ?? 0)
        let span = high - low
        let padding = max(vertical == .r ? 0.35 : 1, (span.isFinite ? span : max(abs(low), abs(high))) * 0.15)
        let lower = low - padding, upper = high + padding
        return (lower.isFinite ? lower : -Double.greatestFiniteMagnitude)...(upper.isFinite ? upper : Double.greatestFiniteMagnitude)
    }
    private func mean(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let average = values.reduce(0) { $0 + $1 / Double(values.count) }
        return average.isFinite ? average : nil
    }

    var body: some View {
        let data = observations
        let selected = data.first { $0.id == selectedID }
        let averageX = mean(data.map(\.x))
        let averageY = mean(data.map(\.y))
        let correlation = AnalyticsEngine.correlation(data.map { ($0.x, $0.y) }).flatMap { $0.isFinite ? $0 : nil }
        Panel(title: horizontal == .process ? "Süreç × sonuç" : horizontal == .risk ? "Risk × sonuç" : "Süre × sonuç", subtitle: "Dağılım analizi · Her nokta bir işlem") {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 18) { horizontalPicker; Spacer(minLength: 12); verticalPicker }
                VStack(alignment: .leading, spacing: 12) { horizontalPicker; verticalPicker }
            }
            inspector(selected)
            if data.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.dots.scatter").font(.system(size: 30, weight: .light)).foregroundStyle(Palette.blue)
                    Text("Bu iki ölçüm için kayıt bulunamadı.").font(.system(size: 13, weight: .medium))
                    Text("Sonuç R için bir R değeri; risk için risk yüzdesi; süre için giriş ve çıkış zamanı gerekir.")
                        .font(.caption).foregroundStyle(Palette.muted).multilineTextAlignment(.center).frame(maxWidth: 440)
                }.frame(maxWidth: .infinity).frame(height: 270)
            } else {
                plot(data, selected: selected, averageX: averageX)
                HStack(spacing: 8) {
                    legendItem("Plana uygun", symbol: "circle.fill", color: Palette.mint)
                    legendItem("Kural ihlali", symbol: "diamond.fill", color: Palette.amber)
                    HStack(spacing: 5) { Capsule().fill(Palette.blue.opacity(0.6)).frame(width: 14, height: 1); Text("Yatay eksen ortalaması").foregroundStyle(Palette.muted) }
                    Spacer(minLength: 8)
                    HStack(spacing: 5) { Capsule().fill(Palette.muted.opacity(0.6)).frame(width: 14, height: 1); Text("0 = başa baş") }.foregroundStyle(Palette.muted)
                }.font(.system(size: 10))
                summary(data: data, averageX: averageX, averageY: averageY, correlation: correlation)
            }
            VStack(alignment: .leading, spacing: 5) {
                if data.count < trades.count {
                    Text("\(trades.count - data.count) işlem, seçili eksenlerde eksik veri olduğu için gösterilmiyor.")
                        .foregroundStyle(Palette.amber)
                }
                Text("Yalnızca yukarıdaki filtrelere uyan kayıtlar kullanılır. İlişki, neden-sonuç veya gelecekteki performans anlamına gelmez.")
                    .foregroundStyle(Palette.muted)
            }.font(.system(size: 10)).fixedSize(horizontal: false, vertical: true)
        }
        .onChange(of: horizontal) { _, _ in selectedID = nil }
        .onChange(of: vertical) { _, _ in selectedID = nil }
        .onChange(of: trades) { _, _ in selectedID = nil }
    }

    private var horizontalPicker: some View {
        Picker("Yatay eksen", selection: $horizontal) {
            ForEach(HorizontalMeasure.allCases) { Text($0.rawValue).tag($0) }
        }.pickerStyle(.menu).buttonStyle(.borderless).padding(.horizontal, 12).frame(width: 280, height: 36).background(Palette.canvas.opacity(0.45), in: RoundedRectangle(cornerRadius: 9)).overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Palette.muted.opacity(0.12)))
    }
    private var verticalPicker: some View {
        SegmentedTabs(options: VerticalMeasure.allCases, selection: $vertical, title: { $0.rawValue })
            .accessibilityLabel("Dağılım grafiği dikey ekseni")
    }
    private func legendItem(_ title: String, symbol: String, color: Color) -> some View {
        HStack(spacing: 5) { Image(systemName: symbol).font(.system(size: 7)).foregroundStyle(color); Text(title).foregroundStyle(Palette.muted) }
            .padding(.trailing, 10)
    }
    private func inspector(_ point: Observation?) -> some View {
        HStack(spacing: 12) {
            if let point {
                Image(systemName: point.trade.compliant ? "checkmark.shield" : "exclamationmark.shield").foregroundStyle(processColor(point.trade))
                VStack(alignment: .leading, spacing: 4) {
                    Text(point.trade.instrument + " · " + L10n.text(point.trade.direction)).font(.system(size: 12, weight: .semibold))
                    Text(Format.date(point.trade.date, calendar: store.preferences.calendar, time: true)).font(.system(size: 10)).foregroundStyle(Palette.muted)
                }
                Spacer(minLength: 6)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(yFormatted(point.y)).font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(Palette.outcome(point.y)).monospacedDigit()
                    Text(horizontal.rawValue + " · " + xFormatted(point.x)).font(.system(size: 10)).foregroundStyle(Palette.muted)
                }
            } else {
                Image(systemName: "cursorarrow.rays").foregroundStyle(Palette.blue)
                VStack(alignment: .leading, spacing: 4) {
                    Text("İşlemlerin dağılımını keşfet").font(.system(size: 12, weight: .medium))
                    Text("Bir noktanın üzerine gel veya tıkla; tarih, enstrüman ve sonuç burada görünür.")
                        .font(.system(size: 10)).foregroundStyle(Palette.muted)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(height: 38).padding(.horizontal, 14).padding(.vertical, 10)
        .background(Palette.raised.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }
    private func summary(data: [Observation], averageX: Double?, averageY: Double?, correlation: Double?) -> some View {
        HStack(alignment: .top, spacing: 18) {
            summaryValue("GÖSTERİLEN", value: "\(data.count) / \(trades.count)", detail: "işlem", color: Palette.ink)
            Spacer(minLength: 0)
            summaryValue("ORT. SONUÇ", value: averageY.map(yFormatted) ?? "—", detail: averageX.map { "Ort. " + horizontal.rawValue.lowercased() + ": " + xFormatted($0) } ?? "", color: averageY.map(Palette.outcome) ?? Palette.muted)
            Spacer(minLength: 0)
            summaryValue("PEARSON r", value: correlation.map { ($0 > 0 ? "+" : "") + Format.number($0) } ?? "—", detail: correlation == nil ? "En az 3 gözlem ve değişkenlik gerekir" : "Seçili iki ölçüm arasındaki ilişki", color: Palette.blue)
        }
        .padding(.top, 14)
        .overlay(alignment: .top) { Rectangle().fill(Palette.muted.opacity(0.12)).frame(height: 1) }
    }
    private func summaryValue(_ title: String, value: String, detail: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 9, weight: .medium)).tracking(0.8).foregroundStyle(Palette.muted)
            Text(value).font(.system(size: 19, weight: .semibold, design: .rounded)).monospacedDigit().foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.7)
            Text(detail).font(.system(size: 9)).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func plot(_ data: [Observation], selected: Observation?, averageX: Double?) -> some View {
        Chart {
            RuleMark(y: .value("Başa baş", 0)).foregroundStyle(Palette.muted.opacity(0.45)).lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            if let averageX {
                RuleMark(x: .value("Yatay eksen ortalaması", averageX)).foregroundStyle(Palette.blue.opacity(0.3)).lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 5]))
            }
            ForEach(data) { point in
                PointMark(x: .value(horizontal.rawValue, point.x), y: .value(vertical.rawValue, point.y))
                    .symbol(point.trade.compliant ? .circle : .diamond)
                    .symbolSize(selectedID == point.id ? 90 : 55)
                    .foregroundStyle(processColor(point.trade).opacity(selectedID == nil || selectedID == point.id ? 0.85 : 0.32))
                    .accessibilityLabel("\(point.trade.instrument), \(Format.date(point.trade.date, calendar: store.preferences.calendar)), \(point.trade.compliant ? "plana uygun" : "kural ihlali")")
                    .accessibilityValue("\(horizontal.rawValue): \(xFormatted(point.x)), \(vertical.rawValue): \(yFormatted(point.y))")
            }
            if let selected {
                RuleMark(x: .value("Seçilen X", selected.x))
                    .foregroundStyle(processColor(selected.trade).opacity(0.25))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                RuleMark(y: .value("Seçilen Y", selected.y))
                    .foregroundStyle(processColor(selected.trade).opacity(0.25))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))

                // Glowing concentric halos
                PointMark(x: .value(horizontal.rawValue, selected.x), y: .value(vertical.rawValue, selected.y))
                    .symbolSize(320).foregroundStyle(processColor(selected.trade).opacity(0.16))
                PointMark(x: .value(horizontal.rawValue, selected.x), y: .value(vertical.rawValue, selected.y))
                    .symbolSize(130).foregroundStyle(processColor(selected.trade).opacity(0.35))
                PointMark(x: .value(horizontal.rawValue, selected.x), y: .value(vertical.rawValue, selected.y))
                    .symbol(selected.trade.compliant ? .circle : .diamond).symbolSize(72)
                    .foregroundStyle(processColor(selected.trade))
                    .annotation(position: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 5) {
                                Text(selected.trade.instrument + " " + selected.trade.direction)
                                    .font(.system(size: 11, weight: .bold))
                                Badge(text: selected.trade.grade, color: processColor(selected.trade))
                            }
                            HStack(spacing: 6) {
                                Text(yFormatted(selected.y))
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(Palette.outcome(selected.y))
                                Text("· " + selected.trade.setupName)
                                    .font(.system(size: 9))
                                    .foregroundStyle(Palette.muted)
                            }
                        }
                        .padding(.horizontal, 9).padding(.vertical, 5)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                        .background(Palette.canvas.opacity(0.85), in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(processColor(selected.trade).opacity(0.4), lineWidth: 1))
                        .shadow(color: Color.black.opacity(0.35), radius: 6, x: 0, y: 3)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                    }
                    .annotation(position: .overlay) {
                        Circle().fill(Color.white).frame(width: 3.5, height: 3.5)
                    }
            }
        }
        .chartXScale(domain: xDomain(data), range: .plotDimension(padding: 14))
        .chartYScale(domain: yDomain(data), range: .plotDimension(padding: 10))
        .chartXAxis {
            AxisMarks(values: xTicks(data)) { axis in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Palette.muted.opacity(0.1))
                AxisTick().foregroundStyle(Palette.muted.opacity(0.25))
                AxisValueLabel { if let number = axis.as(Double.self) { Text(compact(number)).font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.muted) } }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { axis in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 4])).foregroundStyle(Palette.muted.opacity(0.15))
                AxisValueLabel { if let number = axis.as(Double.self) { Text(compact(number) + (vertical == .r ? "R" : "")).font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.muted) } }
            }
        }
        .chartXAxisLabel(horizontal.axisTitle, position: .bottom, alignment: .center, spacing: 10)
        .chartYAxisLabel(vertical == .r ? "KAYDEDİLEN R" : "NET K/Z · \(store.preferences.currency)", position: .leading, alignment: .center, spacing: 8)
        .chartPlotStyle { plot in plot.background(Palette.canvas.opacity(0.32)).overlay(Rectangle().strokeBorder(Palette.muted.opacity(0.08))) }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Color.clear.contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location): select(at: location, proxy: proxy, geometry: geometry, data: data)
                        case .ended: selectedID = nil
                        }
                    }
                    .gesture(SpatialTapGesture().onEnded { event in select(at: event.location, proxy: proxy, geometry: geometry, data: data) })
            }
        }
        .font(.system(size: 9, weight: .medium)).foregroundStyle(Palette.muted)
        .frame(height: 310)
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: selectedID)
        .accessibilityLabel("\(horizontal.rawValue) ve \(vertical.rawValue) dağılım grafiği, \(data.count) işlem")
    }
    private func select(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy, data: [Observation]) {
        guard let plotFrame = proxy.plotFrame else { selectedID = nil; return }
        let frame = geometry[plotFrame]
        guard frame.contains(location) else { selectedID = nil; return }
        let local = CGPoint(x: location.x - frame.minX, y: location.y - frame.minY)
        var nearest: (id: UUID, distance: CGFloat)?
        for point in data {
            guard let x = proxy.position(forX: point.x), let y = proxy.position(forY: point.y) else { continue }
            let distance = hypot(local.x - x, local.y - y)
            if distance <= 24 && (nearest == nil || distance < nearest!.distance) { nearest = (point.id, distance) }
        }
        selectedID = nearest?.id
    }
}
