import SwiftUI
import Charts

struct QuantView: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.edgeAnimationsEnabled) private var animationsEnabled

    @State private var runs: Double = 500
    @State private var horizon: Double = 100
    @State private var shuffle = false
    @State private var rollingWindow: Double = 20
    @State private var simulationSeed: UInt64 = 42
    @State private var cachedSimulation: WorkstationAnalytics.Simulation?
    @State private var isSimulating = false
    @State private var hoveredStep: Int?

    private var animate: Bool { store.preferences.animations && animationsEnabled && !reduceMotion }

    private var trades: [TradeRecord] {
        store.scopedTrades
    }

    private var simulationKey: String {
        "\(store.revision)-\(store.selectedAccount.id)-\(Int(runs))-\(Int(horizon))-\(shuffle)-\(simulationSeed)"
    }

    private var activeSimulation: WorkstationAnalytics.Simulation? {
        if let cachedSimulation { return cachedSimulation }
        // Immediate deterministic fallback for first frame / offscreen preview capture
        return WorkstationAnalytics.simulate(trades, runs: Int(runs), horizon: Int(horizon), shuffle: shuffle, seed: simulationSeed)
    }

    private var underwaterInfo: WorkstationAnalytics.Underwater {
        WorkstationAnalytics.underwater(trades)
    }

    private var rollingPoints: [WorkstationAnalytics.RollingPoint] {
        WorkstationAnalytics.rolling(trades, window: Int(rollingWindow))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerView

                if trades.count < 3 {
                    EmptyJournal(
                        title: "Yetersiz Veri",
                        subtitle: "Senaryo ve Monte Carlo simülasyonları için en az 3 tamamlanmış işlem kaydı gereklidir."
                    )
                } else {
                    keyRiskMetricsRibbon.edgeEntrance(delay: 0.02)
                    monteCarloSection.edgeEntrance(delay: 0.06)
                    drawdownDurationSection.edgeEntrance(delay: 0.1)
                    rollingExpectancySection.edgeEntrance(delay: 0.14)
                    riskConcentrationSection.edgeEntrance(delay: 0.18)
                    methodologyDisclaimer
                }
            }
            .pagePadding()
        }
        .task(id: simulationKey) {
            let snapshot = trades
            let r = Int(runs), h = Int(horizon), sh = shuffle, seed = simulationSeed
            guard snapshot.count >= 3 else { cachedSimulation = nil; return }
            isSimulating = true
            let result = await Task.detached(priority: .userInitiated) {
                WorkstationAnalytics.simulate(snapshot, runs: r, horizon: h, shuffle: sh, seed: seed)
            }.value
            if !Task.isCancelled {
                cachedSimulation = result
                isSimulating = false
            }
        }
    }

    // MARK: - Header
    private var headerView: some View {
        PageHeader(
            eyebrow: "QUANT / SCENARIO LAB",
            title: "Kantitatif Performans & Monte Carlo",
            subtitle: "Geçmiş sonuçları yeniden örnekleyerek sıra bağımlılığını ve olası sermaye yollarını test edin."
        )
    }

    // MARK: - Key Risk Metrics Ribbon
    private var keyRiskMetricsRibbon: some View {
        let p = AnalyticsEngine.performance(trades)
        return HStack(spacing: 20) {
            TerminalMetric(
                title: "EN UZUN TOPARLANMA",
                value: underwaterInfo.longestRecoveredSeconds != nil ? "\(Int(underwaterInfo.longestRecoveredSeconds! / 86400)) gün" : "—"
            )
            TerminalMetric(
                title: "MEVCUT SU ALTI DURUMU",
                value: underwaterInfo.ongoing ? "Devam ediyor (\(Int(underwaterInfo.longestSeconds / 86400))g)" : "Zirvede",
                color: underwaterInfo.ongoing ? Palette.amber : Palette.mint
            )
            TerminalMetric(
                title: "EN UZUN KAYIP SERİSİ",
                value: "\(p.longestLossStreak) işlem",
                color: p.longestLossStreak >= 4 ? Palette.red : Palette.ink
            )
            TerminalMetric(
                title: "R DEĞİŞKENLİK / STABİLİTE",
                value: Format.number(calculateRStability(trades), digits: 2)
            )
            TerminalMetric(
                title: "TOPARLANMA FAKTÖRÜ",
                value: p.recoveryFactor.map { Format.number($0) } ?? "—"
            )
        }
        .padding(20)
        .background(Palette.panel, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Monte Carlo Section
    private var monteCarloSection: some View {
        Panel(
            title: "MONTE CARLO YENİDEN ÖRNEKLEME",
            subtitle: "\(Int(runs)) simülasyon · \(Int(horizon)) işlem ufku · \(shuffle ? "Rastgele sıra (Shuffle)" : "Yerine koyarak örnekleme (Bootstrap)")"
        ) {
            VStack(alignment: .leading, spacing: 20) {
                // Controls
                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Simülasyon Sayısı: \(Int(runs))").font(.caption).foregroundStyle(Palette.muted)
                        Slider(value: $runs, in: 100...1500, step: 100)
                            .frame(width: 180)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("İşlem Ufku: \(Int(horizon))").font(.caption).foregroundStyle(Palette.muted)
                        Slider(value: $horizon, in: 20...300, step: 10)
                            .frame(width: 180)
                    }

                    Toggle("Sıra Değiştirme (Shuffle)", isOn: $shuffle)
                        .toggleStyle(.switch)
                        .font(.caption)

                    Spacer()

                    if isSimulating {
                        ProgressView().controlSize(.small)
                    }

                    Button {
                        simulationSeed = UInt64.random(in: 1...1000000)
                        if animate { EdgeHaptics.selection() }
                    } label: {
                        Label("Yeniden Simüle Et", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(EdgeButtonStyle(prominent: false, compact: true))
                }
                .padding(14)
                .background(Palette.field.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))

                if let sim = activeSimulation {
                    let hoveredPoint = hoveredStep.flatMap { step in sim.band.first { $0.id == step } }
                    // Monte Carlo Band Chart
                    Chart {
                        ForEach(sim.band) { pt in
                            AreaMark(
                                x: .value("Adım", pt.id),
                                yStart: .value("5th", pt.low),
                                yEnd: .value("95th", pt.high)
                            )
                            .foregroundStyle(LinearGradient(colors: [Palette.mint.opacity(0.20), Palette.blue.opacity(0.08), Palette.red.opacity(0.08)], startPoint: .top, endPoint: .bottom))

                            LineMark(
                                x: .value("Adım", pt.id),
                                y: .value("Medyan", pt.median),
                                series: .value("Seri", "Medyan Halo")
                            )
                            .foregroundStyle(Palette.mint.opacity(0.24))
                            .lineStyle(StrokeStyle(lineWidth: 6.5, lineCap: .round, lineJoin: .round))

                            LineMark(
                                x: .value("Adım", pt.id),
                                y: .value("Medyan", pt.median),
                                series: .value("Seri", "Medyan")
                            )
                            .foregroundStyle(Palette.mint)
                            .lineStyle(StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))

                            LineMark(
                                x: .value("Adım", pt.id),
                                y: .value("95. Yüzdelik", pt.high),
                                series: .value("Seri", "95th")
                            )
                            .foregroundStyle(Palette.mint.opacity(0.65))
                            .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [4, 4]))

                            LineMark(
                                x: .value("Adım", pt.id),
                                y: .value("5. Yüzdelik", pt.low),
                                series: .value("Seri", "5th")
                            )
                            .foregroundStyle(Palette.red.opacity(0.65))
                            .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
                        }

                        RuleMark(y: .value("Sıfır", 0))
                            .foregroundStyle(Palette.muted.opacity(0.4))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))

                        if let pt = hoveredPoint {
                            RuleMark(x: .value("Seçili Adım", pt.id))
                                .foregroundStyle(Palette.mint.opacity(0.45))
                                .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                            PointMark(x: .value("Adım", pt.id), y: .value("Medyan", pt.median))
                                .foregroundStyle(Palette.mint)
                                .symbolSize(64)
                                .annotation(position: .top, spacing: 10, overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("İşlem +\(pt.id)").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(Palette.muted)
                                        HStack(spacing: 8) {
                                            Text("95%: \(Format.money(pt.high, currency: store.accountCurrency))").foregroundStyle(Palette.mint)
                                            Text("Med: \(Format.money(pt.median, currency: store.accountCurrency))").foregroundStyle(Palette.ink).fontWeight(.semibold)
                                            Text("5%: \(Format.money(pt.low, currency: store.accountCurrency))").foregroundStyle(Palette.red)
                                        }.font(.system(size: 10, design: .monospaced))
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                                    .background(Palette.canvas.opacity(0.86), in: RoundedRectangle(cornerRadius: 8))
                                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Palette.mint.opacity(0.4)))
                                    .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 4)
                                }
                        }
                    }
                    .chartOverlay { proxy in
                        GeometryReader { geo in
                            Color.clear.contentShape(Rectangle()).onContinuousHover { phase in
                                switch phase {
                                case .active(let loc):
                                    guard let plotFrame = proxy.plotFrame else { return }
                                    let frame = geo[plotFrame]
                                    guard frame.contains(loc) else { if hoveredStep != nil { hoveredStep = nil }; return }
                                    if let xVal = proxy.value(atX: loc.x - frame.minX, as: Double.self) {
                                        let clamped = max(0, min(sim.horizon, Int(xVal.rounded())))
                                        if clamped != hoveredStep {
                                            hoveredStep = clamped
                                            if animate { EdgeHaptics.tick() }
                                        }
                                    }
                                case .ended:
                                    if hoveredStep != nil { hoveredStep = nil }
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 4])).foregroundStyle(Palette.line)
                            AxisValueLabel {
                                if let d = value.as(Double.self) {
                                    Text(Format.money(d, currency: store.accountCurrency))
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundStyle(Palette.muted)
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks { value in
                            AxisGridLine().foregroundStyle(Palette.line)
                            AxisValueLabel {
                                if let i = value.as(Int.self) {
                                    Text("+\(i)")
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundStyle(Palette.muted)
                                }
                            }
                        }
                    }
                    .frame(height: 295)
                    .animation(animate ? .spring(response: 0.35, dampingFraction: 0.82) : nil, value: simulationSeed)
                    .animation(animate ? .spring(response: 0.22, dampingFraction: 0.85) : nil, value: hoveredStep)

                    // Simulation Stats Ribbon
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("MEDYAN SONUÇ").font(.caption).foregroundStyle(Palette.muted)
                            Text(Format.money(sim.band.last?.median ?? 0, currency: store.accountCurrency))
                                .font(.title3.weight(.bold))
                                .foregroundStyle(Palette.outcome(sim.band.last?.median ?? 0))
                        }
                        Divider().frame(height: 36)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("5. YÜZDELİK (KÖTÜ SENARYO)").font(.caption).foregroundStyle(Palette.muted)
                            Text(Format.money(sim.band.last?.low ?? 0, currency: store.accountCurrency))
                                .font(.title3.weight(.bold))
                                .foregroundStyle(Palette.outcome(sim.band.last?.low ?? 0))
                        }
                        Divider().frame(height: 36)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("95. YÜZDELİK (İYİ SENARYO)").font(.caption).foregroundStyle(Palette.muted)
                            Text(Format.money(sim.band.last?.high ?? 0, currency: store.accountCurrency))
                                .font(.title3.weight(.bold))
                                .foregroundStyle(Palette.mint)
                        }
                        Divider().frame(height: 36)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("ZARARLA BİTME OLASILIĞI").font(.caption).foregroundStyle(Palette.muted)
                            Text(Format.percent(sim.lossFraction * 100))
                                .font(.title3.weight(.bold))
                                .foregroundStyle(sim.lossFraction > 0.3 ? Palette.red : Palette.ink)
                        }
                        Divider().frame(height: 36)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("MEDYAN MAKS. DRAWDOWN").font(.caption).foregroundStyle(Palette.muted)
                            let medianDD = WorkstationAnalytics.percentile(sim.drawdowns, 0.5)
                            Text(Format.money(medianDD, currency: store.accountCurrency))
                                .font(.title3.weight(.bold))
                                .foregroundStyle(Palette.red)
                        }
                    }
                    .padding(14)
                    .background(Palette.field.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    // MARK: - Drawdown Duration Section
    private var drawdownDurationSection: some View {
        Panel(title: "SU ALTI (DRAWDOWN) ANALİZİ", subtitle: "Zirveden düşüş ve toparlanma süreleri") {
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Toparlanma Dinamikleri").font(.headline)
                    Text("Piyasa stratejisinin psikolojik zorluğu sadece drawdown yüzdesiyle değil, su altında geçirilen süre ile ölçülür.")
                        .font(.caption).foregroundStyle(Palette.muted)

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("En Uzun Toparlanma:")
                                .font(.caption).foregroundStyle(Palette.muted)
                            Text(underwaterInfo.longestRecoveredSeconds.map { "\(Int($0 / 86400)) gün (\(Int($0 / 3600)) saat)" } ?? "Henüz toparlanma gerçekleşmedi")
                                .font(.subheadline.weight(.semibold))
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(Palette.field.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Mevcut Durum:")
                                .font(.caption).foregroundStyle(Palette.muted)
                            Text(underwaterInfo.ongoing ? "Su altında (\(Int(underwaterInfo.longestSeconds / 86400)) gündür yeni zirve yok)" : "Tarihi zirvede")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(underwaterInfo.ongoing ? Palette.amber : Palette.mint)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(Palette.field.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                }
                .frame(maxWidth: 360)

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Drawdown Derinlik Eğrisi").font(.caption).foregroundStyle(Palette.muted)
                    EquityChart(points: AnalyticsEngine.curve(trades), mode: .drawdown, height: 200)
                }
            }
        }
    }

    // MARK: - Rolling Expectancy Section
    private var rollingExpectancySection: some View {
        Panel(
            title: "HAREKETLİ BEKLENTİ & DİSİPLİN (ROLLING WINDOW)",
            subtitle: "Son \(Int(rollingWindow)) işlem penceresinde beklenti (Expectancy) ve kural uyumu trendi"
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Pencere Genişliği: \(Int(rollingWindow)) İşlem").font(.caption).foregroundStyle(Palette.muted)
                    Slider(value: $rollingWindow, in: 5...50, step: 5).frame(width: 200)
                    Spacer()
                }

                if rollingPoints.isEmpty {
                    Text("Yeterli işlem yok.").foregroundStyle(Palette.muted)
                } else {
                    Chart {
                        ForEach(rollingPoints) { pt in
                            LineMark(
                                x: .value("Tarih", pt.date),
                                y: .value("Beklenti", pt.expectancy)
                            )
                            .foregroundStyle(Palette.mint)
                            .lineStyle(StrokeStyle(lineWidth: 2))

                            RuleMark(y: .value("Sıfır", 0))
                                .foregroundStyle(Palette.line)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 4])).foregroundStyle(Palette.line)
                            AxisValueLabel {
                                if let d = value.as(Double.self) {
                                    Text(Format.money(d, currency: store.accountCurrency))
                                        .font(.system(size: 9, design: .monospaced))
                                }
                            }
                        }
                    }
                    .frame(height: 200)
                }
            }
        }
    }

    // MARK: - Risk Concentration Section
    private var riskConcentrationSection: some View {
        Panel(title: "RİSK VE KÂR KONSANTRASYONU", subtitle: "Performans az sayıda büyük işleme mi bağlı?") {
            let winners = trades.filter { $0.netPnL > 0 }.map(\.netPnL).sorted(by: >)
            let totalProfit = winners.reduce(0, +)
            let top1Share = totalProfit > 0 && !winners.isEmpty ? (winners[0] / totalProfit) * 100 : 0
            let top3Share = totalProfit > 0 ? (winners.prefix(3).reduce(0, +) / totalProfit) * 100 : 0

            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("En İyi 1 İşlemin Kârdaki Payı").font(.caption).foregroundStyle(Palette.muted)
                    Text(Format.percent(top1Share)).font(.title2.weight(.bold))
                    Text(top1Share > 40 ? "Uyarı: Toplam kârın büyük kısmı tek bir işleme dayanıyor." : "Kâr dağılımı dengeli.")
                        .font(.caption2).foregroundStyle(top1Share > 40 ? Palette.amber : Palette.muted)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.field.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 6) {
                    Text("En İyi 3 İşlemin Kârdaki Payı").font(.caption).foregroundStyle(Palette.muted)
                    Text(Format.percent(top3Share)).font(.title2.weight(.bold))
                    Text(top3Share > 70 ? "Yüksek kâr yoğunlaşması riski." : "İşlemler arasında homojen dağılım.")
                        .font(.caption2).foregroundStyle(top3Share > 70 ? Palette.amber : Palette.muted)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.field.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: - Helper
    private func calculateRStability(_ trades: [TradeRecord]) -> Double {
        let rs = trades.compactMap(\.rMultiple)
        guard rs.count >= 2 else { return 0 }
        let mean = rs.reduce(0, +) / Double(rs.count)
        let variance = rs.map { pow($0 - mean, 2) }.reduce(0, +) / Double(rs.count - 1)
        return sqrt(variance)
    }

    // MARK: - Disclaimer
    private var methodologyDisclaimer: some View {
        Text("Deterministik Kantitatif Analiz Notu: Monte Carlo yeniden örneklemesi, kaydedilmiş işlemlerin sıra duyarlılığını ve olası varyans aralıklarını simüle eder. Gelecekteki piyasa rejimlerini, kayma (slippage) veya likidite şoklarını öngöremez. Hiçbir simülasyon kârlılık taahhüdü değildir.")
            .font(.caption)
            .foregroundStyle(Palette.muted)
    }
}
