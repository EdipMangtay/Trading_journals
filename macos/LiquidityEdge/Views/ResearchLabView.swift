import SwiftUI
import Charts

struct ResearchLabView: View {
    @Environment(JournalStore.self) private var store
    var openTrade: (TradeRecord) -> Void

    @State private var filter = TradeFilter()
    @State private var presetName = ""
    @State private var presetError: String?
    @State private var showSavePreset = false
    @State private var selectedTab = "Matrix"
    @State private var selectedCohortTrades: [TradeRecord] = []
    @State private var selectedCohortTitle = ""
    @State private var coachQuestion = ""
    @State private var coachHistory: [EdgeMLEngine.AICoachResponse] = []

    init(openTrade: @escaping (TradeRecord) -> Void, initialTab: String = "Matrix") {
        self.openTrade = openTrade
        _selectedTab = State(initialValue: initialTab)
    }

    private var trades: [TradeRecord] {
        filter.isEmpty ? store.scopedTrades : filter.apply(store.scopedTrades, calendar: store.preferences.calendar)
    }

    private var performance: Performance {
        filter.isEmpty ? store.scopedPerformance : AnalyticsEngine.performance(trades)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                headerView
                presetBar
                FilterBar(allTrades: store.scopedTrades, calendar: store.preferences.calendar, filter: $filter)

                if trades.isEmpty {
                    EmptyJournal(title: "Filtreye uyan işlem bulunamadı", subtitle: "Filtre kriterlerini genişleterek veya farklı bir hesap seçerek araştırmaya devam edin.")
                } else {
                    summaryRibbon
                    sampleCautionBanner

                    SegmentedTabs(
                        options: ["Matrix", "ML Keşif", "Setup × Session", "Confirmations", "Risk & Process", "Day & Time", "Related Trades"],
                        selection: $selectedTab,
                        title: { $0 }
                    )

                    switch selectedTab {
                    case "Matrix":
                        matrixSection
                    case "ML Keşif":
                        mlDiscoverySection
                    case "Setup × Session":
                        setupSessionSection
                    case "Confirmations":
                        confirmationCombinationsSection
                    case "Risk & Process":
                        riskAndProcessSection
                    case "Day & Time":
                        dayAndTimeSection
                    case "Related Trades":
                        relatedTradesSection
                    default:
                        EmptyView()
                    }

                    methodologyDisclaimer
                }
            }
            .pagePadding()
        }
        .sheet(isPresented: $showSavePreset) {
            savePresetSheet
        }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack(alignment: .top) {
            PageHeader(
                eyebrow: "STRATEGY LAB / 02",
                title: "Strateji Araştırma Laboratuvarı",
                subtitle: "Kayıtlı modelleri, oturumları ve teyit kombinasyonlarını çok boyutlu analiz edin."
            )
            Spacer()
            Button {
                showSavePreset = true
            } label: {
                Label("Filtreyi Kaydet", systemImage: "bookmark")
            }
            .buttonStyle(EdgeButtonStyle(prominent: false))
        }
    }

    // MARK: - Presets
    private var presetBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "slider.horizontal.2.square")
                .foregroundStyle(Palette.mint)
                .font(.system(size: 13))
            Text("Kayıtlı Filtreler:")
                .font(.caption)
                .foregroundStyle(Palette.muted)

            if store.workspace.presets.isEmpty {
                Text("Henüz kaydedilmiş filtre yok")
                    .font(.caption)
                    .foregroundStyle(Palette.muted.opacity(0.7))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(store.workspace.presets) { preset in
                            HStack(spacing: 6) {
                                Button {
                                    filter = preset.filter
                                } label: {
                                    Text(preset.name)
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(Palette.mint)
                                        .padding(.vertical, 3)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                Button {
                                    deletePreset(preset)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Palette.muted)
                                        .frame(width: 22, height: 22)
                                        .contentShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .help("Kayıtlı filtreyi sil")
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Palette.panel, in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Palette.line))
                        }
                    }
                }
            }
            Spacer()
            if !filter.isEmpty {
                Button("Filtreyi Temizle") {
                    filter = TradeFilter()
                }
                .buttonStyle(EdgeButtonStyle(prominent: false, compact: true))
            }
        }
        .padding(12)
        .background(Palette.panel.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Summary Ribbon
    private var summaryRibbon: some View {
        GlassRibbon(accent: Palette.outcome(performance.netPnL)) {
            HStack(spacing: 0) {
                TerminalMetric(title: "FİLTRELENEN İŞLEM", value: "n = \(performance.count)")
                labDivider
                TerminalMetric(title: "KAZANMA ORANI", value: Format.percent(performance.winRate))
                labDivider
                TerminalMetric(title: "ORTALAMA R", value: Format.r(performance.averageR), color: Palette.outcome(performance.averageR ?? 0))
                labDivider
                TerminalMetric(title: "KÂR FAKTÖRÜ", value: Format.factor(performance), color: (performance.profitFactor ?? 0) >= 2.0 ? Palette.mint : Palette.ink)
                labDivider
                TerminalMetric(title: "BEKLENTİ", value: Format.money(performance.expectancy, currency: store.accountCurrency), color: Palette.outcome(performance.expectancy))
                labDivider
                TerminalMetric(title: "PLANA UYUM", value: Format.percent(performance.compliance), color: performance.compliance >= 80 ? Palette.mint : Palette.amber)
            }
        }
    }

    private var labDivider: some View {
        Rectangle().fill(Palette.line.opacity(0.7)).frame(width: 1, height: 38).padding(.horizontal, 14)
    }

    // MARK: - Caution Banner
    @ViewBuilder
    private var sampleCautionBanner: some View {
        if performance.count < 30 {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(Palette.amber)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Düşük Örneklem Uyarısı (n = \(performance.count))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.amber)
                    Text("30'dan az işlem içeren örneklemler istatistiksel genelleme yapmak için yetersizdir. Gözlemlenen sonuçlar şans veya piyasa rejiminden kaynaklanabilir.")
                        .font(.caption)
                        .foregroundStyle(Palette.muted)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.amber.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.amber.opacity(0.2)))
        }
    }

    // MARK: - Tab: ML Keşif (Ultra On-Device ML + Walk-Forward AUC + CUSUM Regime + AI Filter Sim + Coach)
    private var mlDiscoverySection: some View {
        let ml = filter.isEmpty ? store.scopedMLInsights : EdgeMLEngine.analyze(trades, calendar: store.preferences.calendar)
        let tiltColor: Color = ml.tilt.level == .elevated ? Palette.red : ml.tilt.level == .caution ? Palette.amber : Palette.mint
        let regimeColor: Color = ml.regime.state == .regimeDrift ? Palette.red : ml.regime.state == .coldVariance ? Palette.amber : ml.regime.state == .hotEdge ? Palette.mint : Palette.blue
        let displayedResponses: [EdgeMLEngine.AICoachResponse] = coachHistory.isEmpty ? [
            EdgeMLEngine.askCoach(
                question: EdgeMLEngine.suggestedCoachQuestions[0],
                trades: trades,
                setups: store.setups,
                account: store.selectedAccount,
                risk: store.scopedRisk,
                calendar: store.preferences.calendar
            )
        ] : coachHistory
        return VStack(alignment: .leading, spacing: 20) {
            // 1. Flagship Model Validation (Walk-Forward ROC-AUC) & Active Regime Ribbon
            GlassRibbon(accent: regimeColor) {
                HStack(spacing: 0) {
                    TerminalMetric(
                        title: "WALK-FORWARD ROC-AUC",
                        value: ml.validation.isReady ? String(format: "%.2f", ml.validation.rocAUC) : "—",
                        color: ml.validation.rocAUC >= 0.65 ? Palette.mint : Palette.blue,
                        subtitle: ml.validation.isReady ? "\(ml.validation.qualityLabel) (n=\(ml.validation.evaluatedCount))" : "En az 8 işlem gerekir"
                    )
                    labDivider
                    TerminalMetric(
                        title: "AI EDGE AYRIŞTIRMA (WR LIFT)",
                        value: ml.validation.isReady ? String(format: "%+.0f puan", ml.validation.winRateLiftPoints) : "—",
                        color: ml.validation.winRateLiftPoints >= 0 ? Palette.mint : Palette.amber,
                        subtitle: ml.validation.isReady ? "≥60: %\(Int(ml.validation.highEdgeWinRate)) WR · <48: %\(Int(ml.validation.lowEdgeWinRate)) WR" : "Yüksek vs Düşük Edge farkı"
                    )
                    labDivider
                    TerminalMetric(
                        title: "AKTİF REJİM (CUSUM/EWMA)",
                        value: ml.regime.state.rawValue,
                        color: regimeColor,
                        subtitle: "Risk Çarpanı \(String(format: "%.2fx", ml.regime.riskMultiplier)) · EWMA \(Format.r(ml.regime.ewmaR))"
                    )
                    labDivider
                    TerminalMetric(
                        title: "AI FİLTRE SERMAYE KAZANCI",
                        value: Format.money(ml.filterSimulation.savedCapital, currency: store.accountCurrency),
                        color: Palette.outcome(ml.filterSimulation.savedCapital),
                        subtitle: "\(ml.filterSimulation.skippedTrades) zayıf/kuralsız işlem elenirse"
                    )
                }
            }

            // 2. Counterfactual AI Filter Simulator (Actual vs. AI-Filtered Equity)
            Panel(title: "AI FİLTRE KARŞI-OLGUSAL SİMÜLATÖRÜ", subtitle: "AI Edge < 42, kural ihlali veya <15 dk intikam işlemleri elenseydi sonuç nasıl olurdu?", accent: Palette.mint) {
                let fs = ml.filterSimulation
                VStack(alignment: .leading, spacing: 12) {
                    Text(fs.summary)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Palette.ink)
                    HStack(spacing: 14) {
                        aiSimCompareBox(
                            title: "GERÇEK PERFORMANS (n=\(fs.totalTrades))",
                            netPnL: Format.money(fs.actualNetPnL, currency: store.accountCurrency),
                            winRate: Format.percent(fs.actualWinRate),
                            avgR: Format.r(fs.actualAvgR),
                            maxDD: Format.money(fs.actualMaxDrawdown, currency: store.accountCurrency),
                            accent: Palette.muted
                        )
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Palette.mint)
                        aiSimCompareBox(
                            title: "AI FİLTRELİ PERFORMANS (n=\(fs.keptTrades))",
                            netPnL: Format.money(fs.filteredNetPnL, currency: store.accountCurrency),
                            winRate: Format.percent(fs.filteredWinRate),
                            avgR: Format.r(fs.filteredAvgR),
                            maxDD: Format.money(fs.filteredMaxDrawdown, currency: store.accountCurrency),
                            accent: Palette.mint
                        )
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "waveform.path.ecg").foregroundStyle(regimeColor)
                        Text("Rejim Yorumu: \(ml.regime.summary) → \(ml.regime.advice)")
                            .font(.system(size: 11)).foregroundStyle(Palette.muted)
                    }
                }
            }

            // 3. Multi-Turn Entity-Aware AI Trading Coach
            Panel(title: "AI TRADING KOÇU — GÜNLÜĞÜNE SOR", subtitle: "Varlık-farkındalıklı (Parite, Strateji, Seans, QT/SSMT, AUC, Filtre, Kelly) doğal dil analizi", accent: Palette.mint) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles").foregroundStyle(Palette.mint)
                        TextField("Sorunu yaz (örn: NQ performansım nasıl? AI filtresi kullansaydım ne olurdu? Modelin AUC'si ne?)...", text: $coachQuestion)
                            .textFieldStyle(EdgeTextFieldStyle())
                            .onSubmit { runAICoach(coachQuestion) }
                        Button {
                            runAICoach(coachQuestion.isEmpty ? EdgeMLEngine.suggestedCoachQuestions[0] : coachQuestion)
                        } label: {
                            Label("AI Koça Sor", systemImage: "paperplane.fill")
                        }
                        .buttonStyle(EdgeButtonStyle(compact: true))
                        if !coachHistory.isEmpty {
                            Button("Temizle") { coachHistory.removeAll() }
                                .buttonStyle(EdgeButtonStyle(prominent: false, compact: true))
                        }
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(EdgeMLEngine.suggestedCoachQuestions, id: \.self) { q in
                                Button {
                                    coachQuestion = q
                                    runAICoach(q)
                                } label: {
                                    Text(q)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Palette.ink.opacity(0.9))
                                        .padding(.horizontal, 11).padding(.vertical, 6)
                                        .background(Palette.field, in: Capsule())
                                        .overlay(Capsule().strokeBorder(Palette.mint.opacity(0.28), lineWidth: 0.9))
                                        .contentShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    ForEach(displayedResponses.reversed()) { activeResponse in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    if !activeResponse.question.isEmpty {
                                        Text("SORU: \(activeResponse.question)")
                                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(Palette.muted)
                                    }
                                    Label(activeResponse.headline, systemImage: "brain.head.profile")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(Palette.mint)
                                }
                                Spacer()
                                ForEach(activeResponse.metrics) { m in
                                    HStack(spacing: 4) {
                                        Text(m.label + ":").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(Palette.muted)
                                        Text(m.value).font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(Palette.ink)
                                    }
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(Palette.raised, in: Capsule())
                                }
                            }
                            Text(activeResponse.answer)
                                .font(.system(size: 12))
                                .foregroundStyle(Palette.ink.opacity(0.92))
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                            if !activeResponse.actionItems.isEmpty {
                                Divider()
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("AKSİYON ADIMLARI").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(Palette.blue)
                                    ForEach(activeResponse.actionItems, id: \.self) { act in
                                        HStack(alignment: .top, spacing: 6) {
                                            Image(systemName: "arrow.right.circle.fill").font(.system(size: 11)).foregroundStyle(Palette.blue).padding(.top, 1)
                                            Text(act).font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.ink)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(14)
                        .background(Palette.field.opacity(0.65), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.mint.opacity(0.25), lineWidth: 1))
                    }
                }
            }

            HStack(alignment: .top, spacing: 20) {
                Panel(title: "ALTIN KURULUMLAR (OTOMATİK EDGE)", subtitle: "Empirical Bayes sıralı · ⚡ \(Format.number(ml.computeMs, digits: 1)) ms", accent: Palette.mint) {
                    if ml.goldenSetups.isEmpty {
                        Text("En az 4 işlemle istatistiksel olarak öne çıkan kombinasyonlar otomatik keşfedilir.").font(.caption).foregroundStyle(Palette.muted)
                    } else {
                        ForEach(ml.goldenSetups) { pat in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(pat.title).font(.system(size: 13, weight: .semibold))
                                    Text("\(pat.subtitle) · n = \(pat.sampleCount) · WR \(Format.percent(pat.winRate))")
                                        .font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.muted)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 3) {
                                    Text(Format.r(pat.averageR)).font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundStyle(Palette.mint)
                                    Text(Format.money(pat.netPnL, currency: store.accountCurrency)).font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.muted)
                                }
                            }
                            .padding(12)
                            .background(Palette.mint.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.mint.opacity(0.22), lineWidth: 1))
                        }
                    }
                }

                Panel(title: "PARA SIZINTILARI (ML LEAK DETECTOR)", subtitle: "Kârlılığı aşağı çeken kalıplar", accent: Palette.amber) {
                    if ml.moneyLeaks.isEmpty {
                        Text("Belirgin negatif sızıntı kalıbı tespit edilmedi.").font(.caption).foregroundStyle(Palette.muted)
                    } else {
                        ForEach(ml.moneyLeaks) { pat in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(pat.title).font(.system(size: 13, weight: .semibold))
                                    Text("\(pat.subtitle) · n = \(pat.sampleCount) · WR \(Format.percent(pat.winRate))")
                                        .font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.muted)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 3) {
                                    Text(Format.money(pat.netPnL, currency: store.accountCurrency)).font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundStyle(Palette.outcome(pat.netPnL))
                                    Text(Format.r(pat.averageR)).font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.amber)
                                }
                            }
                            .padding(12)
                            .background(Palette.amber.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.amber.opacity(0.22), lineWidth: 1))
                        }
                    }
                }
            }

            Panel(title: "DAVRANIŞ & TİLT ANOMALİ DEDEKTÖRÜ", subtitle: "Skor: \(ml.tilt.score)/100 · \(ml.tilt.level.rawValue)", accent: tiltColor) {
                if ml.tilt.signals.isEmpty {
                    Label("Kontrollü süreç: ardışık zarar sonrası intikam işlemi, risk artışı veya ani disiplin düşüşü yok.", systemImage: "checkmark.shield.fill")
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.mint)
                } else {
                    ForEach(ml.tilt.signals) { sig in
                        let c: Color = sig.severity >= 3 ? Palette.red : sig.severity == 2 ? Palette.amber : Palette.blue
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: sig.severity >= 3 ? "flame.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(c).padding(.top, 2)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(sig.title).font(.system(size: 12, weight: .semibold)).foregroundStyle(c)
                                Text(sig.detail).font(.system(size: 11)).foregroundStyle(Palette.muted)
                            }
                            Spacer()
                        }
                        .padding(11)
                        .background(c.opacity(0.07), in: RoundedRectangle(cornerRadius: 9))
                        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(c.opacity(0.24), lineWidth: 0.9))
                    }
                }
            }

            Panel(title: "NOTLARDAN NLP KELİME MADENCİLİĞİ (APPLE NATURALLANGUAGE)", subtitle: "İşlem tezi ve ders notlarındaki yüksek etkili düşünce kalıpları", accent: Palette.blue) {
                if ml.positiveKeywords.isEmpty && ml.negativeKeywords.isEmpty {
                    Text("Not ve tez alanlarını doldurdukça kazançlı ve zararlı işlemlerle ilişkili anahtar kelimeler burada otomatik çıkarılır.")
                        .font(.caption).foregroundStyle(Palette.muted)
                } else {
                    HStack(alignment: .top, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("POZİTİF ETKİLİ KAVRAMLAR").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(Palette.mint)
                            ForEach(ml.positiveKeywords) { kw in
                                HStack {
                                    Text("“\(kw.keyword)”").font(.system(size: 12, weight: .semibold))
                                    Spacer()
                                    Text("n=\(kw.count) · WR \(Format.percent(kw.winRate))").font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.muted)
                                    Text(Format.r(kw.averageR)).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(Palette.mint)
                                }
                                .padding(9).background(Palette.mint.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("NEGATİF ETKİLİ KAVRAMLAR").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(Palette.red)
                            ForEach(ml.negativeKeywords) { kw in
                                HStack {
                                    Text("“\(kw.keyword)”").font(.system(size: 12, weight: .semibold))
                                    Spacer()
                                    Text("n=\(kw.count) · WR \(Format.percent(kw.winRate))").font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.muted)
                                    Text(Format.r(kw.averageR)).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(Palette.red)
                                }
                                .padding(9).background(Palette.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    // MARK: - Tab: Matrix
    private var matrixSection: some View {
        let edges = filter.isEmpty ? store.scopedEdgeMatrix : AnalyticsEngine.edgeMatrix(trades)
        let comps = filter.isEmpty ? store.scopedComparisons : AnalyticsEngine.comparisons(trades)
        return VStack(alignment: .leading, spacing: 20) {
            Panel(title: "STRATEJİ VE MODEL AVANTAJI", subtitle: "Doğrulanmış model teyitleri ve gözlemlenen sonuçlar", accent: Palette.mint) {
                if edges.isEmpty {
                    Text("Filtrelenen verilerde model teyidi kaydedilmiş işlem bulunamadı.")
                        .foregroundStyle(Palette.muted)
                } else {
                    ForEach(edges) { edge in
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(edge.name).font(.system(size: 13, weight: .semibold))
                                Badge(text: edge.sampleLabel, color: edge.performance.count < 30 ? Palette.amber : Palette.mint)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text("\(Format.percent(edge.performance.winRate)) WR").foregroundStyle(Palette.ink)
                                    Text(Format.r(edge.performance.averageR))
                                        .fontWeight(.bold)
                                        .foregroundStyle(Palette.outcome(edge.performance.averageR ?? 0))
                                }
                                .font(.system(size: 12, design: .monospaced))
                                Text("Ort. Kazanç: \(Format.r(edge.performance.averageWinningR)) · n = \(edge.performance.count)")
                                    .font(.caption)
                                    .foregroundStyle(Palette.muted)
                            }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .background(Palette.field.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.line.opacity(0.65), lineWidth: 0.8))
                    }
                }
            }

            Panel(title: "TEYİT KARŞILAŞTIRMALARI (A/B KOHORT)", accent: Palette.blue) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 16)], spacing: 16) {
                    ForEach(comps) { comp in
                        let deltaR: Double? = {
                            guard let l = comp.left.performance.averageR, let r = comp.right.performance.averageR else { return nil }
                            return l - r
                        }()
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(comp.title.uppercased()).font(.caption.weight(.bold)).foregroundStyle(Palette.mint)
                                Spacer()
                                if let deltaR {
                                    Text("Δ " + Format.r(deltaR))
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundStyle(Palette.outcome(deltaR))
                                        .padding(.horizontal, 7).padding(.vertical, 2.5)
                                        .background(Palette.outcome(deltaR).opacity(0.11), in: Capsule())
                                }
                            }
                            cohortRow(comp.left)
                            Divider()
                            cohortRow(comp.right)
                        }
                        .padding(14)
                        .background(Palette.field.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.line.opacity(0.75), lineWidth: 1))
                    }
                }
            }
        }
    }

    private func cohortRow(_ group: MetricGroup) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(group.name).font(.system(size: 12, weight: .medium))
                Text("n = \(group.performance.count) · WR: \(Format.percent(group.performance.winRate))")
                    .font(.caption)
                    .foregroundStyle(Palette.muted)
            }
            Spacer()
            Text(Format.r(group.performance.averageR))
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.outcome(group.performance.averageR ?? 0))
        }
    }

    // MARK: - Tab: Setup × Session
    private var setupSessionSection: some View {
        let sessions = Array(Set(trades.map(\.session))).sorted()
        let setups = Array(Set(trades.map(\.setupName))).sorted()
        let instruments = Array(Set(trades.map(\.instrument))).sorted()
        let bySetupSession = Dictionary(grouping: trades) { "\($0.setupName)\u{1F}\($0.session)" }
        let bySetupInstrument = Dictionary(grouping: trades) { "\($0.setupName)\u{1F}\($0.instrument)" }
        return VStack(alignment: .leading, spacing: 20) {
            Panel(title: "SETUP × OTURUM DAĞILIMI", subtitle: "Hangi kurulum hangi seansta en yüksek beklentiyi üretti?") {
                ScrollView(.horizontal) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("SETUP / SESSION").font(.caption.weight(.bold)).frame(width: 160, alignment: .leading)
                            ForEach(sessions, id: \.self) { s in
                                Text(s.uppercased()).font(.caption.weight(.bold)).frame(width: 120, alignment: .trailing)
                            }
                        }
                        .padding(.vertical, 8)
                        Divider()

                        ForEach(setups, id: \.self) { setup in
                            HStack {
                                Text(setup).font(.system(size: 12, weight: .medium)).frame(width: 160, alignment: .leading)
                                ForEach(sessions, id: \.self) { session in
                                    let cellTrades = bySetupSession["\(setup)\u{1F}\(session)"] ?? []
                                    VStack(alignment: .trailing, spacing: 2) {
                                        if cellTrades.isEmpty {
                                            Text("—").foregroundStyle(Palette.muted)
                                        } else {
                                            let cellPerf = AnalyticsEngine.performance(cellTrades)
                                            Button {
                                                selectedCohortTrades = cellTrades
                                                selectedCohortTitle = "\(setup) · \(session)"
                                                selectedTab = "Related Trades"
                                            } label: {
                                                VStack(alignment: .trailing) {
                                                    Text(Format.r(cellPerf.averageR))
                                                        .font(.system(size: 11, weight: .semibold))
                                                        .foregroundStyle(Palette.outcome(cellPerf.averageR ?? 0))
                                                    Text("n=\(cellTrades.count) (\(Format.percent(cellPerf.winRate)))")
                                                        .font(.system(size: 9))
                                                        .foregroundStyle(Palette.muted)
                                                }
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .frame(width: 120, alignment: .trailing)
                                }
                            }
                            .padding(.vertical, 6)
                            Divider()
                        }
                    }
                }
            }

            Panel(title: "SETUP × ENSTRÜMAN DAĞILIMI", subtitle: "Kurulumların enstrümanlara göre performansı") {
                ScrollView(.horizontal) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("SETUP / ENSTRÜMAN").font(.caption.weight(.bold)).frame(width: 160, alignment: .leading)
                            ForEach(instruments, id: \.self) { inst in
                                Text(inst).font(.caption.weight(.bold)).frame(width: 120, alignment: .trailing)
                            }
                        }
                        .padding(.vertical, 8)
                        Divider()

                        ForEach(setups, id: \.self) { setup in
                            HStack {
                                Text(setup).font(.system(size: 12, weight: .medium)).frame(width: 160, alignment: .leading)
                                ForEach(instruments, id: \.self) { inst in
                                    let cellTrades = bySetupInstrument["\(setup)\u{1F}\(inst)"] ?? []
                                    VStack(alignment: .trailing, spacing: 2) {
                                        if cellTrades.isEmpty {
                                            Text("—").foregroundStyle(Palette.muted)
                                        } else {
                                            let cellPerf = AnalyticsEngine.performance(cellTrades)
                                            Button {
                                                selectedCohortTrades = cellTrades
                                                selectedCohortTitle = "\(setup) · \(inst)"
                                                selectedTab = "Related Trades"
                                            } label: {
                                                VStack(alignment: .trailing) {
                                                    Text(Format.r(cellPerf.averageR))
                                                        .font(.system(size: 11, weight: .semibold))
                                                        .foregroundStyle(Palette.outcome(cellPerf.averageR ?? 0))
                                                    Text("n=\(cellTrades.count) (\(Format.percent(cellPerf.winRate)))")
                                                        .font(.system(size: 9))
                                                        .foregroundStyle(Palette.muted)
                                                }
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .frame(width: 120, alignment: .trailing)
                                }
                            }
                            .padding(.vertical, 6)
                            Divider()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Tab: Confirmations
    private var confirmationCombinationsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Panel(title: "TEYİT SAYISI VE ETKİSİ", subtitle: "Kayıtlı teyit sayısı arttıkça başarı oranı ve R beklentisi nasıl değişiyor?") {
                let groupedByCount = Dictionary(grouping: trades, by: { $0.confirmations.count })
                let sortedKeys = groupedByCount.keys.sorted()

                HStack(spacing: 16) {
                    ForEach(sortedKeys, id: \.self) { count in
                        let group = groupedByCount[count] ?? []
                        let perf = AnalyticsEngine.performance(group)
                        VStack(spacing: 8) {
                            Text("\(count) Teyit").font(.caption.weight(.bold)).foregroundStyle(Palette.muted)
                            Text(Format.r(perf.averageR)).font(.title2.weight(.bold)).foregroundStyle(Palette.outcome(perf.averageR ?? 0))
                            Text("WR: \(Format.percent(perf.winRate))").font(.caption)
                            Text("n = \(perf.count)").font(.caption2).foregroundStyle(Palette.muted)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(Palette.field.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.line))
                    }
                }
            }

            Panel(title: "BİREYSEL TEYİT PERFORMANSLARI", subtitle: "Her bir teyidin yer aldığı işlemlerin toplu metriği") {
                let allConfirmations = Array(Set(trades.flatMap(\.confirmations))).sorted()
                ForEach(allConfirmations, id: \.self) { conf in
                    let confTrades = trades.filter { $0.confirmations.contains(conf) }
                    let perf = AnalyticsEngine.performance(confTrades)
                    HStack {
                        Badge(text: conf, color: Palette.mint)
                        Spacer()
                        Text("n = \(perf.count)").font(.caption).foregroundStyle(Palette.muted).frame(width: 80, alignment: .trailing)
                        Text(Format.percent(perf.winRate)).font(.caption).frame(width: 80, alignment: .trailing)
                        Text(Format.r(perf.averageR)).font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.outcome(perf.averageR ?? 0)).frame(width: 90, alignment: .trailing)
                        Text(Format.money(perf.netPnL, currency: store.accountCurrency)).font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.outcome(perf.netPnL)).frame(width: 120, alignment: .trailing)
                    }
                    .padding(.vertical, 6)
                    Divider()
                }
            }
        }
    }

    // MARK: - Tab: Risk & Process
    private var riskAndProcessSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 20) {
                Panel(title: "PLANA UYUMUN ETKİSİ", subtitle: "Disiplinli işlemler ile kural ihlali içerenlerin karşılaştırması") {
                    let compliantTrades = trades.filter(\.compliant)
                    let nonCompliantTrades = trades.filter { !$0.compliant }
                    let compPerf = AnalyticsEngine.performance(compliantTrades)
                    let nonCompPerf = AnalyticsEngine.performance(nonCompliantTrades)

                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Label("Plana Tam Uyum", systemImage: "checkmark.shield").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.mint)
                                Text("n = \(compPerf.count) (\(Format.percent(Double(compPerf.count) / Double(max(1, trades.count)) * 100)))").font(.caption).foregroundStyle(Palette.muted)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(Format.r(compPerf.averageR)).font(.title3.weight(.bold)).foregroundStyle(Palette.outcome(compPerf.averageR ?? 0))
                                Text("WR: \(Format.percent(compPerf.winRate)) · Net: \(Format.money(compPerf.netPnL, currency: store.accountCurrency))").font(.caption).foregroundStyle(Palette.muted)
                            }
                        }
                        .padding(14)
                        .background(Palette.mint.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))

                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Label("Kural İhlali / Disiplinsiz", systemImage: "exclamationmark.shield").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.red)
                                Text("n = \(nonCompPerf.count) (\(Format.percent(Double(nonCompPerf.count) / Double(max(1, trades.count)) * 100)))").font(.caption).foregroundStyle(Palette.muted)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(Format.r(nonCompPerf.averageR)).font(.title3.weight(.bold)).foregroundStyle(Palette.outcome(nonCompPerf.averageR ?? 0))
                                Text("WR: \(Format.percent(nonCompPerf.winRate)) · Net: \(Format.money(nonCompPerf.netPnL, currency: store.accountCurrency))").font(.caption).foregroundStyle(Palette.muted)
                            }
                        }
                        .padding(14)
                        .background(Palette.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                    }
                }

                Panel(title: "NOT GRUPLARI (A+ / A / B / C / F)", subtitle: "İşlem notuna göre R beklentisi") {
                    let grades = ["A+", "A", "B", "C", "D", "F"]
                    ForEach(grades, id: \.self) { g in
                        let gradeTrades = trades.filter { $0.grade == g }
                        let perf = AnalyticsEngine.performance(gradeTrades)
                        HStack {
                            Badge(text: g, color: g == "A+" || g == "A" ? Palette.mint : g == "B" ? Palette.blue : Palette.amber)
                            Text("n = \(perf.count)").font(.caption).foregroundStyle(Palette.muted).frame(width: 70, alignment: .trailing)
                            Spacer()
                            Text(Format.percent(perf.winRate)).font(.caption).frame(width: 80, alignment: .trailing)
                            Text(Format.r(perf.averageR)).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.outcome(perf.averageR ?? 0)).frame(width: 80, alignment: .trailing)
                        }
                        .padding(.vertical, 4)
                        Divider()
                    }
                }
            }
        }
    }

    // MARK: - Tab: Day & Time
    private var dayAndTimeSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Panel(title: "GÜNLERE GÖRE PERFORMANS (HAFTANIN GÜNLERİ)", subtitle: store.preferences.timezone) {
                let cal = store.preferences.calendar
                let weekdays = ["Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma"]
                let grouped = Dictionary(grouping: trades) { t -> Int in
                    let weekday = cal.component(.weekday, from: t.date)
                    return (weekday + 5) % 7 // Pazartesi=0, Salı=1, ...
                }

                HStack(spacing: 12) {
                    ForEach(0..<5, id: \.self) { idx in
                        let dayTrades = grouped[idx] ?? []
                        let perf = AnalyticsEngine.performance(dayTrades)
                        VStack(spacing: 8) {
                            Text(weekdays[idx]).font(.caption.weight(.bold)).foregroundStyle(Palette.muted)
                            Text(Format.r(perf.averageR)).font(.title3.weight(.bold)).foregroundStyle(Palette.outcome(perf.averageR ?? 0))
                            Text(Format.percent(perf.winRate)).font(.caption)
                            Text("n = \(perf.count)").font(.caption2).foregroundStyle(Palette.muted)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .background(Palette.field.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.line))
                    }
                }
            }

            Panel(title: "ZAMANLAMA VE SEANS ISI HARİTASI", subtitle: "Giriş saati ve oturum yoğunluğu") {
                PerformanceHeatmap(trades: trades, calendar: store.preferences.calendar, precomputedBuckets: filter.isEmpty ? store.scopedHeatmapBuckets : nil)
            }
        }
    }

    // MARK: - Tab: Related Trades Drill-Down
    private var relatedTradesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(selectedCohortTitle.isEmpty ? "Filtrelenen Tüm İşlemler" : "Kohort: \(selectedCohortTitle)")
                    .font(.title3.weight(.semibold))
                Spacer()
                if !selectedCohortTrades.isEmpty {
                    Button("Tüm Filtrelenenleri Göster") {
                        selectedCohortTrades = []
                        selectedCohortTitle = ""
                    }
                    .font(.caption)
                    .foregroundStyle(Palette.mint)
                    .buttonStyle(.plain)
                }
            }

            let displayList = selectedCohortTrades.isEmpty ? trades : selectedCohortTrades
            TradeRows(trades: displayList, openTrade: openTrade)
        }
    }

    // MARK: - Save Preset Sheet
    private var savePresetSheet: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Araştırma Filtresini Kaydet").font(.title2.weight(.bold))
                Spacer()
                Button("İptal") { presetError = nil; showSavePreset = false }
                    .buttonStyle(EdgeButtonStyle(prominent: false, compact: true))
                    .keyboardShortcut(.cancelAction)
            }
            Text("Geçerli arama terimi, tarih aralığı ve boyut filtreleri bir ön ayar olarak saklanır.").font(.caption).foregroundStyle(Palette.muted)

            TextField("Filtre Adı (örn: London CRT + SSMT)", text: $presetName)
                .textFieldStyle(EdgeTextFieldStyle())
                .onSubmit { savePreset() }

            if let presetError {
                Text(presetError).font(.caption).foregroundStyle(Palette.amber)
            }

            HStack {
                Spacer()
                Button("Kaydet") { savePreset() }
                    .buttonStyle(EdgeButtonStyle(compact: true))
                    .disabled(presetName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 440)
        .background(Palette.canvas)
        .foregroundStyle(Palette.ink)
        .tint(Palette.mint)
    }

    private func savePreset() {
        let clean = presetName.trimmingCharacters(in: .whitespaces)
        guard !clean.isEmpty else { return }
        let preset = ResearchPreset(name: clean, filter: filter)
        do {
            try store.updateWorkspace { $0.presets.append(preset) }
            presetName = ""
            presetError = nil
            showSavePreset = false
        } catch {
            presetError = error.localizedDescription
        }
    }

    private func deletePreset(_ preset: ResearchPreset) {
        do {
            try store.updateWorkspace { ws in
                ws.presets.removeAll { $0.id == preset.id }
            }
        } catch {
            store.report(error)
        }
    }

    private func aiSimCompareBox(title: String, netPnL: String, winRate: String, avgR: String, maxDD: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(accent)
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("NET P&L").font(.system(size: 8, design: .monospaced)).foregroundStyle(Palette.muted)
                    Text(netPnL).font(.system(size: 13, weight: .bold, design: .monospaced))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("WIN RATE").font(.system(size: 8, design: .monospaced)).foregroundStyle(Palette.muted)
                    Text(winRate).font(.system(size: 13, weight: .bold, design: .monospaced))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("ORT. R").font(.system(size: 8, design: .monospaced)).foregroundStyle(Palette.muted)
                    Text(avgR).font(.system(size: 13, weight: .bold, design: .monospaced))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("MAX DD").font(.system(size: 8, design: .monospaced)).foregroundStyle(Palette.muted)
                    Text(maxDD).font(.system(size: 13, weight: .bold, design: .monospaced))
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(accent.opacity(0.22), lineWidth: 0.9))
    }

    private func runAICoach(_ q: String) {
        let trimmed = q.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let reply = EdgeMLEngine.askCoach(
            question: trimmed,
            trades: trades,
            setups: store.setups,
            account: store.selectedAccount,
            risk: store.scopedRisk,
            calendar: store.preferences.calendar
        )
        coachHistory.append(reply)
        if coachHistory.count > 6 {
            coachHistory.removeFirst()
        }
        coachQuestion = ""
    }

    // MARK: - Disclaimer
    private var methodologyDisclaimer: some View {
        Text("Yöntem: Korelasyon nedensellik oluşturmaz. Geçmiş işlemlerin istatistiksel kohort incelemesidir. Örneklem sayısı 30'dan küçük olan gruplar için genelleme yapılmamalıdır. Döviz kurları farklı hesaplar arasında toplanmaz.")
            .font(.caption)
            .foregroundStyle(Palette.muted)
            .padding(.top, 10)
    }
}

