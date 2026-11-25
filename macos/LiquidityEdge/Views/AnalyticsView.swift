import SwiftUI
import Charts
import AppKit

enum AnalyticsMode { case analytics, setups, statistics }
struct AnalyticsView: View {
    @Environment(JournalStore.self) private var store
    var mode: AnalyticsMode
    var openPlaybook: ((PlaybookDraft) -> Void)? = nil
    @State private var filter = TradeFilter()
    @State private var dimension = AnalysisDimension.setup
    @State private var metric = GroupMetric.averageR
    @State private var curveMode = CurveMode.r
    @State private var fallbackPlaybook: PlaybookDraft?
    @State private var exportedPDFURL: URL?
    var body: some View {
        let unfiltered = filter.isEmpty
        let data = unfiltered ? store.scopedTrades : filter.apply(store.scopedTrades, calendar: store.preferences.calendar)
        let p = unfiltered ? store.scopedPerformance : AnalyticsEngine.performance(data)
        let groups = AnalyticsEngine.groups(data, by: dimension, calendar: store.preferences.calendar)
        let curve = unfiltered ? store.scopedCurve : AnalyticsEngine.curve(data)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top, spacing: 20) {
                    PageHeader(eyebrow: "Research desk", title: mode == .setups ? "Find the combinations that matter." : mode == .statistics ? "Your performance, precisely." : "Evidence over intuition.", subtitle: "Measure confirmations against your own execution history.")
                    Spacer(minLength: 8)
                    HStack(spacing: 10) {
                        Button {
                            if let url = Self.performExportPDF(mode: mode, filter: filter, trades: data, in: store) {
                                exportedPDFURL = url
                            }
                        } label: { Label("PDF Raporu", systemImage: "doc.richtext") }
                            .buttonStyle(EdgeButtonStyle(prominent: false))
                            .disabled(data.isEmpty)
                            .help("Filtrelenen verilerle kurumsal PDF performans karnesi dışa aktar")
                        if mode == .setups {
                            Button {
                                let draft = PlaybookDraft()
                                if let openPlaybook { openPlaybook(draft) } else { fallbackPlaybook = draft }
                            } label: { Label(L10n.text("New setup"), systemImage: "plus") }
                                .buttonStyle(EdgeButtonStyle())
                        }
                    }
                }
                if let url = exportedPDFURL {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.mint)
                        Text("Kurumsal PDF raporu kaydedildi: \(url.lastPathComponent)")
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.ink)
                        Spacer()
                        Button { NSWorkspace.shared.open(url) } label: { Label("PDF’i Aç", systemImage: "doc.viewfinder") }
                            .buttonStyle(EdgeButtonStyle(prominent: false, compact: true))
                        Button { NSWorkspace.shared.activateFileViewerSelecting([url]) } label: { Label("Finder", systemImage: "folder") }
                            .buttonStyle(EdgeButtonStyle(prominent: false, compact: true))
                        Button { exportedPDFURL = nil } label: { Image(systemName: "xmark").font(.caption) }
                            .buttonStyle(.plain).foregroundStyle(Palette.muted)
                    }
                    .padding(14)
                    .background(Palette.mint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.mint.opacity(0.28), lineWidth: 0.9))
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
                        let comps = unfiltered ? store.scopedComparisons : AnalyticsEngine.comparisons(data)
                        Text(L10n.text("CONFIRMATION CONTRIBUTION")).font(.system(size: 11, weight: .bold, design: .monospaced)).tracking(1.5).foregroundStyle(Palette.mint)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 310), spacing: 16)], spacing: 16) {
                            ForEach(comps) { comparison in
                                let deltaR: Double? = {
                                    guard let l = comparison.left.performance.averageR, let r = comparison.right.performance.averageR else { return nil }
                                    return l - r
                                }()
                                Panel(title: comparison.title.uppercased(), subtitle: deltaR.map { "Δ " + Format.r($0) }, accent: deltaR.map { Palette.outcome($0) }) {
                                    comparisonRow(comparison.left)
                                    Divider()
                                    comparisonRow(comparison.right)
                                    Text(L10n.text("Descriptive comparison; cohorts can differ in setup and execution.")).font(.system(size: 10)).foregroundStyle(Palette.muted)
                                }
                            }
                        }
                        edgeMatrix(unfiltered ? store.scopedEdgeMatrix : AnalyticsEngine.edgeMatrix(data))
                    }
                    compliance(unfiltered ? store.scopedMonthlyProcess : AnalyticsEngine.monthlyProcess(data, calendar: store.preferences.calendar))
                    Panel(title: "SESSION PERFORMANCE") { GroupMetricsTable(groups: unfiltered ? store.scopedSessionGroups : AnalyticsEngine.groups(data, by: .session, calendar: store.preferences.calendar), currency: store.accountCurrency) }
                    Panel(title: "ENTRY TIME HEATMAP") { PerformanceHeatmap(trades: data, calendar: store.preferences.calendar, precomputedBuckets: unfiltered ? store.scopedHeatmapBuckets : nil) }
                    Panel(title: "METRIC DEFINITIONS") {
                        Text(L10n.text("All PnL metrics use gross PnL minus fees. Win/loss rates include breakeven trades in the denominator. Expectancy is net PnL ÷ trades; expectancy in R and average R both equal total recorded R ÷ trades with R. Average winning R uses winners only. Profit factor is gross net winners ÷ absolute net losers; ∞ means wins with no losses, and — means undefined. Drawdown starts from zero cumulative PnL. Percentage equity uses the configured starting account size, without deposits or withdrawals. Streaks reset on breakeven. Session labels are recorded manually; time buckets use the configured trading time zone. Multi-label groups can overlap.")).font(.caption).foregroundStyle(Palette.muted).textSelection(.enabled)
                    }
                }
            }.pagePadding()
        }
        .sheet(item: $fallbackPlaybook) { draft in PlaybookEditor(initial: draft).environment(store) }
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
    private func edgeMatrix(_ edges: [EdgeCombination]) -> some View {
        Panel(title: "EDGE MATRIX", subtitle: "CONFIRMED MODEL COMBINATIONS", accent: Palette.mint) {
            if edges.isEmpty { Text(L10n.text("Record valid model confirmations to reveal combinations.")).foregroundStyle(Palette.muted) }
            ForEach(edges) { edge in
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(edge.name).font(.system(size: 13, weight: .semibold))
                        Badge(text: edge.sampleLabel, color: edge.performance.count < 30 ? Palette.amber : Palette.mint)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        HStack(spacing: 10) {
                            Text(Format.percent(edge.performance.winRate) + " WR")
                                .foregroundStyle(Palette.ink)
                            Text(Format.r(edge.performance.averageR))
                                .fontWeight(.bold)
                                .foregroundStyle(Palette.outcome(edge.performance.averageR ?? 0))
                        }
                        Text(L10n.text("Avg winning R \(Format.r(edge.performance.averageWinningR)) · n = \(edge.performance.count)")).foregroundStyle(Palette.muted)
                    }.font(.caption.monospaced())
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Palette.field.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.line.opacity(0.6), lineWidth: 0.8))
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
    private func compliance(_ months: [MonthlyProcess]) -> some View {
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

    @MainActor @discardableResult
    static func performExportPDF(
        mode: AnalyticsMode,
        filter: TradeFilter,
        trades: [TradeRecord],
        in store: JournalStore
    ) -> URL? {
        let cal = store.preferences.calendar
        let ordered = AnalyticsEngine.ordered(trades)
        let title: String
        let prefix: String
        switch mode {
        case .setups:
            title = "Strateji & Kurulum Analiz Raporu"
            prefix = "LiquidityEdge-Kurulumlar"
        case .statistics:
            title = "İstatistiksel Performans Raporu"
            prefix = "LiquidityEdge-Istatistikler"
        case .analytics:
            title = "Analitik Performans Karnesi"
            prefix = "LiquidityEdge-Analiz"
        }

        let periodLabel: String
        if let from = filter.from, let to = filter.to {
            periodLabel = "\(Format.date(from, calendar: cal)) – \(Format.date(to, calendar: cal))"
        } else if let first = ordered.first?.date, let last = ordered.last?.date {
            periodLabel = "\(Format.date(first, calendar: cal)) – \(Format.date(last, calendar: cal)) (\(ordered.count) işlem)"
        } else {
            periodLabel = "Tüm İşlemler"
        }

        let request = PDFReportService.ReportRequest(
            title: title,
            subtitle: filter.isEmpty ? "Hesap Geneli Kurumsal Analiz" : "Filtrelenmiş Analiz Görünümü",
            periodLabel: periodLabel,
            accountName: store.selectedAccount.name,
            currency: store.accountCurrency,
            startingBalance: store.selectedAccount.startingBalance,
            trades: ordered,
            allAccountTrades: store.scopedTrades,
            calendar: cal,
            reviewNotes: nil
        )
        let fileName = PDFReportService.sanitizedFileName(prefix: prefix, period: filter.isEmpty ? "Genel" : "Filtreli")
        switch PDFReportService.exportWithSavePanel(request: request, suggestedFileName: fileName) {
        case .success(let url):
            return url
        case .failure(let error):
            store.report(error)
            return nil
        case nil:
            return nil
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
        let mistakes = store.scopedMistakes
        let ruleBreakTrades = store.scopedTrades.filter { !$0.compliant }
        let breakPerf = AnalyticsEngine.performance(ruleBreakTrades)
        ScrollView { LazyVStack(alignment: .leading, spacing: 24) {
            PageHeader(eyebrow: "Process audit", title: "The cost of breaking your rules.", subtitle: "Profitable mistakes are still mistakes. Learn from the process.")
            if !mistakes.isEmpty {
                GlassRibbon(accent: Palette.amber) {
                    HStack(spacing: 0) {
                        TerminalMetric(title: "KURAL İHLALLİ İŞLEM", value: "\(ruleBreakTrades.count)", color: Palette.amber, subtitle: "Toplam \(store.scopedTrades.count) işlem içinde")
                        Rectangle().fill(Palette.line.opacity(0.7)).frame(width: 1, height: 40).padding(.horizontal, 16)
                        TerminalMetric(title: "İHLAL NET SONUÇ", value: Format.money(breakPerf.netPnL, currency: store.accountCurrency), color: Palette.outcome(breakPerf.netPnL), subtitle: "Toplam R " + Format.r(breakPerf.totalR))
                        Rectangle().fill(Palette.line.opacity(0.7)).frame(width: 1, height: 40).padding(.horizontal, 16)
                        TerminalMetric(title: "EN SIK HATA", value: mistakes.first?.name ?? "—", color: Palette.ink, subtitle: mistakes.first.map { "\($0.performance.count) kez tekrarlandı" } ?? "")
                    }
                }
            }
            if mistakes.isEmpty { EmptyJournal(title: "No rule violations recorded.", subtitle: "Honest process reviews are the foundation of a useful journal.") }
            ForEach(mistakes) { mistake in
                Panel(accent: Palette.amber) {
                    HStack(alignment: .center, spacing: 20) {
                        Image(systemName: "exclamationmark.shield").font(.system(size: 22, weight: .light)).foregroundStyle(Palette.amber)
                            .frame(width: 48, height: 48)
                            .background(Palette.amber.opacity(0.09), in: RoundedRectangle(cornerRadius: 13))
                            .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(Palette.amber.opacity(0.24), lineWidth: 1))
                        VStack(alignment: .leading, spacing: 8) {
                            Text(verbatim: mistake.name).font(.system(size: 16, weight: .bold)).tracking(-0.3).fixedSize(horizontal: false, vertical: true)
                            Text(L10n.text("\(mistake.performance.count) trades · \(Format.percent(mistake.performance.winRate)) win rate")).foregroundStyle(Palette.muted).font(.system(size: 11))
                        }
                        Spacer(minLength: 12)
                        VStack(alignment: .trailing, spacing: 6) { Text("TOPLAM R").font(.system(size: 9, weight: .semibold, design: .monospaced)).foregroundStyle(Palette.muted); Text(Format.r(mistake.performance.totalR)).font(.system(size: 23, weight: .bold, design: .rounded)).foregroundStyle(Palette.amber).monospacedDigit() }
                        VStack(alignment: .trailing, spacing: 6) { Text(L10n.text("NET PNL")).font(.system(size: 9, weight: .semibold, design: .monospaced)).foregroundStyle(Palette.muted); Text(Format.money(mistake.performance.netPnL, currency: store.accountCurrency)).font(.system(size: 20, weight: .semibold, design: .rounded)).foregroundStyle(Palette.outcome(mistake.performance.netPnL)).monospacedDigit() }
                    }
                    if mistake.performance.netPnL > 0 { Label(L10n.text("Positive outcome, poor process"), systemImage: "exclamationmark.triangle").foregroundStyle(Palette.amber).font(.caption) }
                }
            }
            if !mistakes.isEmpty { Text(L10n.text("A trade can break multiple rules; counts and PnL overlap between mistakes.")).font(.caption).foregroundStyle(Palette.muted) }
        }.pagePadding() }
    }
}
