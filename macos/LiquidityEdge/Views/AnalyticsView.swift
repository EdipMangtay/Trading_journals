import SwiftUI
import Charts

enum AnalyticsMode { case analytics, setups, statistics }
struct AnalyticsView: View {
    @Environment(JournalStore.self) private var store
    var mode: AnalyticsMode
    @State private var filter = TradeFilter()
    @State private var dimension = AnalysisDimension.setup
    @State private var metric = GroupMetric.averageR
    @State private var curveMode = CurveMode.r
    @State private var newSetupDraft: PlaybookDraft?
    var body: some View {
        let unfiltered = filter.isEmpty
        let data = unfiltered ? store.scopedTrades : filter.apply(store.scopedTrades, calendar: store.preferences.calendar)
        let p = unfiltered ? store.scopedPerformance : AnalyticsEngine.performance(data)
        let groups = AnalyticsEngine.groups(data, by: dimension, calendar: store.preferences.calendar)
        let curve = unfiltered ? store.scopedCurve : AnalyticsEngine.curve(data)
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top, spacing: 20) {
                    PageHeader(eyebrow: "Research desk", title: mode == .setups ? "Find the combinations that matter." : mode == .statistics ? "Your performance, precisely." : "Evidence over intuition.", subtitle: "Measure confirmations against your own execution history.")
                    if mode == .setups {
                        Spacer(minLength: 8)
                        Button { newSetupDraft = PlaybookDraft() } label: { Label(L10n.text("New setup"), systemImage: "plus") }
                            .buttonStyle(EdgeButtonStyle()).fixedSize()
                    }
                }
                FilterBar(allTrades: store.scopedTrades, calendar: store.preferences.calendar, filter: $filter)
                if data.isEmpty { EmptyJournal(title: "No observations yet.", subtitle: "Add trades or adjust filters to begin your analysis.") }
                else {
                    if mode == .statistics { MetricsGrid(performance: p, currency: store.accountCurrency) }
                    if mode != .statistics {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4), spacing: 14) {
                            MetricCard(title: "Sample", value: "n = \(p.count)", footnote: "Filtreye uyan işlem sayısı")
                            MetricCard(title: "Win rate", value: Format.percent(p.winRate), footnote: "\(p.wins) kazançlı · \(p.losses) zararlı işlem")
                            MetricCard(title: "Expectancy", value: Format.r(p.averageR), footnote: "R kaydedilen işlemlerin ortalaması", color: Palette.outcome(p.averageR ?? 0))
                            MetricCard(title: "Compliance", value: Format.percent(p.compliance), footnote: "İşlem planına tam uyum")
                        }.edgeEntrance(delay: 0.03)
                    }
                    if p.count < 30 {
                        Label("Bu görünüm \(p.count) işleme dayanıyor. Daha fazla kayıt, karşılaştırmaları güçlendirir.", systemImage: "info.circle")
                            .font(.caption).foregroundStyle(Palette.amber).padding(14).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Palette.amber.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                    }
                    Panel(title: "Performans eğrisi", subtitle: "Filtrelenen işlemler · Masraflar sonrası") {
                        ViewThatFits(in: .horizontal) {
                            HStack { Text("Zaman içinde gelişim").font(.caption).foregroundStyle(Palette.muted); Spacer(); curveTabs }
                            curveTabs
                        }
                        EquityChart(points: curveMode == .rolling ? Array(curve.dropFirst()) : curve, mode: curveMode, accountSize: store.selectedAccount.startingBalance, height: 260)
                    }.edgeEntrance(delay: 0.06)
                    TradeScatterChart(trades: data)
                    Panel(title: "PERFORMANCE BREAKDOWN", subtitle: "Gruplar ve ölçülebilir sonuçlar") {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 20) { dimensionPicker; Spacer(); metricPicker }
                            VStack(alignment: .leading, spacing: 12) { dimensionPicker; metricPicker }
                        }
                        GroupBarChart(groups: groups, metric: metric)
                        GroupMetricsTable(groups: groups, currency: store.accountCurrency)
                    }
                    if mode != .statistics {
                        Text(L10n.text("CONFIRMATION CONTRIBUTION")).font(.system(size: 11, weight: .semibold, design: .monospaced)).tracking(1.5)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 310), spacing: 16)], spacing: 16) {
                            ForEach(AnalyticsEngine.comparisons(data)) { comparison in
                                Panel(title: comparison.title.uppercased()) {
                                    comparisonRow(comparison.left)
                                    Divider()
                                    comparisonRow(comparison.right)
                                    Text(L10n.text("Descriptive comparison; cohorts can differ in setup and execution.")).font(.system(size: 10)).foregroundStyle(Palette.muted)
                                }
                            }
                        }
                        edgeMatrix(data)
                    }
                    compliance(data)
                    Panel(title: "SESSION PERFORMANCE") { GroupMetricsTable(groups: AnalyticsEngine.groups(data, by: .session, calendar: store.preferences.calendar), currency: store.accountCurrency) }
                    Panel(title: "ENTRY TIME HEATMAP") { PerformanceHeatmap(trades: data, calendar: store.preferences.calendar) }
                    Panel(title: "METRIC DEFINITIONS") {
                        Text(L10n.text("All PnL metrics use gross PnL minus fees. Win/loss rates include breakeven trades in the denominator. Expectancy is net PnL ÷ trades; expectancy in R and average R both equal total recorded R ÷ trades with R. Average winning R uses winners only. Profit factor is gross net winners ÷ absolute net losers; ∞ means wins with no losses, and — means undefined. Drawdown starts from zero cumulative PnL. Percentage equity uses the configured starting account size, without deposits or withdrawals. Streaks reset on breakeven. Session labels are recorded manually; time buckets use the configured trading time zone. Multi-label groups can overlap.")).font(.caption).foregroundStyle(Palette.muted).textSelection(.enabled)
                    }
                }
            }.pagePadding()
        }
        .sheet(item: $newSetupDraft) { draft in PlaybookEditor(initial: draft).environment(store) }
    }
    private var curveTabs: some View {
        SegmentedTabs(options: CurveMode.allCases, selection: $curveMode, title: { $0.rawValue })
            .accessibilityLabel("Performans grafiği ölçümü")
    }
    private var dimensionPicker: some View {
        Picker(L10n.text("Group by"), selection: $dimension) {
            ForEach(AnalysisDimension.allCases) { Text(L10n.text($0.rawValue)).tag($0) }
        }.pickerStyle(.menu).labelsHidden().buttonStyle(.borderless).padding(.horizontal, 12).frame(width: 270, height: 36).background(Palette.canvas.opacity(0.45), in: RoundedRectangle(cornerRadius: 9)).overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Palette.muted.opacity(0.12)))
    }
    private var metricPicker: some View {
        Picker(L10n.text("Metric"), selection: $metric) {
            ForEach(GroupMetric.allCases, id: \.self) { Text(L10n.text($0.rawValue)).tag($0) }
        }.pickerStyle(.menu).labelsHidden().buttonStyle(.borderless).padding(.horizontal, 12).frame(width: 270, height: 36).background(Palette.canvas.opacity(0.45), in: RoundedRectangle(cornerRadius: 9)).overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Palette.muted.opacity(0.12)))
    }
    private func comparisonRow(_ group: MetricGroup) -> some View {
        HStack { VStack(alignment: .leading, spacing: 6) { Text(group.name).font(.system(size: 12, weight: .medium)); Text(L10n.text("n = \(group.performance.count) · \(Format.percent(group.performance.winRate)) WR")).font(.caption).foregroundStyle(Palette.muted) }; Spacer(); Text(Format.r(group.performance.averageR)).font(.system(size: 20, weight: .medium, design: .rounded)).foregroundStyle(Palette.outcome(group.performance.averageR ?? 0)) }
    }
    private func edgeMatrix(_ data: [TradeRecord]) -> some View {
        Panel(title: "EDGE MATRIX", subtitle: "CONFIRMED MODEL COMBINATIONS") {
            let edges = AnalyticsEngine.edgeMatrix(data)
            if edges.isEmpty { Text(L10n.text("Record valid model confirmations to reveal combinations.")).foregroundStyle(Palette.muted) }
            ForEach(edges) { edge in
                HStack { VStack(alignment: .leading, spacing: 6) { Text(edge.name).font(.system(size: 13, weight: .medium)); Badge(text: edge.sampleLabel, color: edge.performance.count < 30 ? Palette.amber : Palette.mint) }; Spacer(); VStack(alignment: .trailing, spacing: 6) { Text(L10n.text("\(Format.percent(edge.performance.winRate)) WR · \(Format.r(edge.performance.averageR)) expectancy")); Text(L10n.text("Avg winning R \(Format.r(edge.performance.averageWinningR)) · n = \(edge.performance.count)")).foregroundStyle(Palette.muted) }.font(.caption.monospaced()) }.padding(.vertical, 7)
            }
            Text(L10n.text("Combinations include trades with additional confirmations. “Only” excludes the other four tracked models. n < 30: low sample; 30+: reasonable sample; 50+: more evidence. Sample count alone does not establish statistical confidence or a durable edge.")).font(.caption).foregroundStyle(Palette.muted)
        }
    }
    private func monthAxisDates(_ months: [MonthlyProcess]) -> [Date] {
        let step = max(1, Int(ceil(Double(months.count) / 6)))
        return months.enumerated().compactMap { index, month in index.isMultiple(of: step) || index == months.count - 1 ? month.date : nil }
    }
    private func monthAxisLabel(_ date: Date) -> String {
        var style = Date.FormatStyle().month(.abbreviated).year(.twoDigits)
        style.locale = L10n.locale
        style.calendar = store.preferences.calendar
        style.timeZone = store.preferences.calendar.timeZone
        return date.formatted(style)
    }
    private func compliance(_ data: [TradeRecord]) -> some View {
        let months = AnalyticsEngine.monthlyProcess(data, calendar: store.preferences.calendar)
        let correlation = AnalyticsEngine.correlation(months.compactMap { m in m.performance.averageR.map { (m.performance.compliance, $0) } })
        return Panel(title: "DISCIPLINE OVER TIME", subtitle: "MONTHLY RULE COMPLIANCE") {
            Chart(months) { month in
                LineMark(x: .value("Ay", month.date), y: .value("Plana uyum", month.performance.compliance))
                    .foregroundStyle(Palette.mint).lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)).interpolationMethod(.linear)
                PointMark(x: .value("Ay", month.date), y: .value("Plana uyum", month.performance.compliance))
                    .foregroundStyle(Palette.mint).symbolSize(45)
                    .accessibilityLabel(Format.month(month.date, calendar: store.preferences.calendar))
                    .accessibilityValue("\(Format.percent(month.performance.compliance)), \(month.performance.count) işlem")
            }
            .chartYScale(domain: 0...100, range: .plotDimension(padding: 9))
            .chartXScale(domain: (months.first?.date ?? Date()).addingTimeInterval(-14 * 86400)...(months.last?.date ?? Date()).addingTimeInterval(14 * 86400))
            .chartYAxis {
                AxisMarks(position: .trailing, values: [0, 25, 50, 75, 100]) { axis in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 4])).foregroundStyle(Palette.muted.opacity(0.16))
                    AxisValueLabel { if let number = axis.as(Double.self) { Text(Format.percent(number)).font(.system(size: 9, design: .monospaced)).foregroundStyle(Palette.muted) } }
                }
            }
            .chartXAxis {
                AxisMarks(values: monthAxisDates(months)) { axis in
                    AxisValueLabel { if let date = axis.as(Date.self) { Text(monthAxisLabel(date)).font(.system(size: 10)).foregroundStyle(Palette.muted) } }
                }
            }
            .chartPlotStyle { plot in plot.background(Palette.canvas.opacity(0.25)) }
            .frame(height: 200)
            .accessibilityLabel("Aylık işlem planına uyum grafiği")
            ForEach(months) { month in HStack { Text(Format.month(month.date, calendar: store.preferences.calendar)); Spacer(); Text(Format.percent(month.performance.compliance)); Text(Format.r(month.performance.averageR)).frame(width: 90, alignment: .trailing) }.font(.caption) }
            Text(L10n.text(correlation.map { "Monthly compliance ↔ expectancy Pearson r = \(Format.number($0)). Association is not causation; \(months.count) monthly observations." } ?? "Correlation needs at least three months with recorded R and variation in both metrics.")).font(.caption).foregroundStyle(Palette.muted)
        }
    }
}
struct GroupMetricsTable: View {
    var groups: [MetricGroup]
    var currency: String
    private let widths: [CGFloat] = [190, 44, 80, 90, 120, 120, 60]
    var body: some View {
        ScrollView(.horizontal) {
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    ForEach(Array(["COHORT", "N", "WR", "AVG R", "NET PNL", "EXPECTANCY", "PF"].enumerated()), id: \.offset) { index, label in
                        Text(L10n.text(label)).font(.system(size: 9, weight: .medium, design: .monospaced)).foregroundStyle(Palette.muted)
                            .frame(width: widths[index], alignment: index == 0 ? .leading : .trailing)
                    }
                }.padding(.horizontal, 12).padding(.vertical, 12).background(Palette.raised.opacity(0.7))
                ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                    let performance = group.performance
                    HStack(spacing: 14) {
                        Text(group.name).fontWeight(.medium).frame(width: widths[0], alignment: .leading).lineLimit(2)
                        Text(performance.count.description).foregroundStyle(Palette.muted).frame(width: widths[1], alignment: .trailing)
                        Text(Format.percent(performance.winRate)).frame(width: widths[2], alignment: .trailing)
                        Text(Format.r(performance.averageR)).foregroundStyle(Palette.outcome(performance.averageR ?? 0)).frame(width: widths[3], alignment: .trailing)
                        Text(Format.money(performance.netPnL, currency: currency)).foregroundStyle(Palette.outcome(performance.netPnL)).frame(width: widths[4], alignment: .trailing)
                        Text(Format.money(performance.expectancy, currency: currency)).frame(width: widths[5], alignment: .trailing)
                        Text(Format.factor(performance)).frame(width: widths[6], alignment: .trailing)
                    }
                    .font(.system(size: 11)).monospacedDigit().textSelection(.enabled)
                    .padding(.horizontal, 12).padding(.vertical, 13)
                    .background(index.isMultiple(of: 2) ? Palette.raised.opacity(0.18) : Color.clear)
                    if index < groups.count - 1 { Rectangle().fill(Palette.muted.opacity(0.08)).frame(height: 1) }
                }
            }.clipShape(RoundedRectangle(cornerRadius: 9)).overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Palette.muted.opacity(0.1)))
                .padding(.bottom, 5)
        }
        .accessibilityLabel("Performans grupları tablosu")
    }
}
struct MistakesView: View {
    @Environment(JournalStore.self) private var store
    var body: some View {
        let mistakes = AnalyticsEngine.mistakes(store.scopedTrades)
        ScrollView { VStack(alignment: .leading, spacing: 24) {
            PageHeader(eyebrow: "Process audit", title: "The cost of breaking your rules.", subtitle: "Profitable mistakes are still mistakes. Learn from the process.")
            if mistakes.isEmpty { EmptyJournal(title: "No rule violations recorded.", subtitle: "Honest process reviews are the foundation of a useful journal.") }
            ForEach(mistakes) { mistake in
                Panel {
                    HStack(alignment: .center, spacing: 20) {
                        Image(systemName: "exclamationmark.shield").font(.system(size: 22, weight: .light)).foregroundStyle(Palette.amber)
                            .frame(width: 48, height: 48).background(Palette.amber.opacity(0.07), in: RoundedRectangle(cornerRadius: 13))
                        VStack(alignment: .leading, spacing: 9) {
                            Text(verbatim: mistake.name).font(.system(size: 16, weight: .semibold)).tracking(-0.3).fixedSize(horizontal: false, vertical: true)
                            Text(L10n.text("\(mistake.performance.count) trades · \(Format.percent(mistake.performance.winRate)) win rate")).foregroundStyle(Palette.muted).font(.system(size: 11))
                        }
                        Spacer(minLength: 12)
                        VStack(alignment: .trailing, spacing: 6) { Text("TOPLAM R").font(.system(size: 9, weight: .medium)).foregroundStyle(Palette.muted); Text(Format.r(mistake.performance.totalR)).font(.system(size: 23, weight: .semibold, design: .rounded)).foregroundStyle(Palette.amber).monospacedDigit() }
                        VStack(alignment: .trailing, spacing: 6) { Text(L10n.text("NET PNL")).font(.system(size: 9, weight: .medium)).foregroundStyle(Palette.muted); Text(Format.money(mistake.performance.netPnL, currency: store.accountCurrency)).font(.system(size: 20, weight: .medium, design: .rounded)).foregroundStyle(Palette.muted).monospacedDigit() }
                    }
                    if mistake.performance.netPnL > 0 { Label(L10n.text("Positive outcome, poor process"), systemImage: "exclamationmark.triangle").foregroundStyle(Palette.amber).font(.caption) }
                }
            }
            if !mistakes.isEmpty { Text(L10n.text("A trade can break multiple rules; counts and PnL overlap between mistakes.")).font(.caption).foregroundStyle(Palette.muted) }
        }.pagePadding() }
    }
}
