import SwiftUI
import Charts

struct ResearchLabView: View {
    @Environment(JournalStore.self) private var store
    var openTrade: (TradeRecord) -> Void

    @State private var filter = TradeFilter()
    @State private var presetName = ""
    @State private var showSavePreset = false
    @State private var selectedTab = "Matrix"
    @State private var selectedCohortTrades: [TradeRecord] = []
    @State private var selectedCohortTitle = ""

    private var trades: [TradeRecord] {
        filter.apply(store.scopedTrades, calendar: store.preferences.calendar)
    }

    private var performance: Performance {
        AnalyticsEngine.performance(trades)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerView
                presetBar
                FilterBar(allTrades: store.scopedTrades, calendar: store.preferences.calendar, filter: $filter)

                if trades.isEmpty {
                    EmptyJournal(title: "Filtreye uyan işlem bulunamadı", subtitle: "Filtre kriterlerini genişleterek veya farklı bir hesap seçerek araştırmaya devam edin.")
                } else {
                    summaryRibbon
                    sampleCautionBanner

                    SegmentedTabs(
                        options: ["Matrix", "Setup × Session", "Confirmations", "Risk & Process", "Day & Time", "Related Trades"],
                        selection: $selectedTab,
                        title: { $0 }
                    )

                    switch selectedTab {
                    case "Matrix":
                        matrixSection
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
                                Button(preset.name) {
                                    filter = preset.filter
                                }
                                .buttonStyle(.plain)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Palette.mint)

                                Button {
                                    deletePreset(preset)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Palette.muted)
                                }
                                .buttonStyle(.plain)
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
            if !filter.query.isEmpty || filter.from != nil || filter.to != nil || !filter.facets.isEmpty {
                Button("Filtreyi Temizle") {
                    filter = TradeFilter()
                }
                .font(.caption)
                .foregroundStyle(Palette.amber)
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Palette.panel.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Summary Ribbon
    private var summaryRibbon: some View {
        HStack(spacing: 20) {
            TerminalMetric(title: "FİLTRELENEN İŞLEM", value: "n = \(performance.count)")
            TerminalMetric(title: "KAZANMA ORANI", value: Format.percent(performance.winRate))
            TerminalMetric(title: "ORTALAMA R", value: Format.r(performance.averageR), color: Palette.outcome(performance.averageR ?? 0))
            TerminalMetric(title: "KÂR FAKTÖRÜ", value: Format.factor(performance))
            TerminalMetric(title: "BEKLENTİ", value: Format.money(performance.expectancy, currency: store.accountCurrency))
            TerminalMetric(title: "PLANA UYUM", value: Format.percent(performance.compliance), color: performance.compliance >= 80 ? Palette.mint : Palette.amber)
        }
        .padding(20)
        .background(Palette.panel, in: RoundedRectangle(cornerRadius: 14))
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

    // MARK: - Tab: Matrix
    private var matrixSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Panel(title: "STRATEJİ VE MODEL AVANTAJI", subtitle: "Doğrulanmış model teyitleri ve gözlemlenen sonuçlar") {
                let edges = AnalyticsEngine.edgeMatrix(trades)
                if edges.isEmpty {
                    Text("Filtrelenen verilerde model teyidi kaydedilmiş işlem bulunamadı.")
                        .foregroundStyle(Palette.muted)
                } else {
                    ForEach(edges) { edge in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(edge.name).font(.system(size: 13, weight: .medium))
                                Badge(text: edge.sampleLabel, color: edge.performance.count < 30 ? Palette.amber : Palette.mint)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("\(Format.percent(edge.performance.winRate)) WR · \(Format.r(edge.performance.averageR))")
                                    .font(.system(size: 12, design: .monospaced))
                                Text("Ort. Kazanç: \(Format.r(edge.performance.averageWinningR)) · n = \(edge.performance.count)")
                                    .font(.caption)
                                    .foregroundStyle(Palette.muted)
                            }
                        }
                        .padding(.vertical, 8)
                        Divider()
                    }
                }
            }

            Panel(title: "TEYİT KARŞILAŞTIRMALARI (A/B KOHORT)") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 16)], spacing: 16) {
                    ForEach(AnalyticsEngine.comparisons(trades)) { comp in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(comp.title.uppercased()).font(.caption.weight(.bold)).foregroundStyle(Palette.mint)
                            cohortRow(comp.left)
                            Divider()
                            cohortRow(comp.right)
                        }
                        .padding(14)
                        .background(Palette.field.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
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
        VStack(alignment: .leading, spacing: 20) {
            Panel(title: "SETUP × OTURUM DAĞILIMI", subtitle: "Hangi kurulum hangi seansta en yüksek beklentiyi üretti?") {
                let sessions = Array(Set(trades.map(\.session))).sorted()
                let setups = Array(Set(trades.map(\.setupName))).sorted()

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
                                    let cellTrades = trades.filter { $0.setupName == setup && $0.session == session }
                                    let cellPerf = AnalyticsEngine.performance(cellTrades)
                                    VStack(alignment: .trailing, spacing: 2) {
                                        if cellTrades.isEmpty {
                                            Text("—").foregroundStyle(Palette.muted)
                                        } else {
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
                let instruments = Array(Set(trades.map(\.instrument))).sorted()
                let setups = Array(Set(trades.map(\.setupName))).sorted()

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
                                    let cellTrades = trades.filter { $0.setupName == setup && $0.instrument == inst }
                                    let cellPerf = AnalyticsEngine.performance(cellTrades)
                                    VStack(alignment: .trailing, spacing: 2) {
                                        if cellTrades.isEmpty {
                                            Text("—").foregroundStyle(Palette.muted)
                                        } else {
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
                PerformanceHeatmap(trades: trades, calendar: store.preferences.calendar)
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
                Button("İptal") { showSavePreset = false }.keyboardShortcut(.cancelAction)
            }
            Text("Geçerli arama terimi, tarih aralığı ve boyut filtreleri bir ön ayar olarak saklanır.").font(.caption).foregroundStyle(Palette.muted)

            TextField("Filtre Adı (örn: London CRT + SSMT)", text: $presetName)
                .textFieldStyle(EdgeTextFieldStyle())

            HStack {
                Spacer()
                Button("Kaydet") {
                    let clean = presetName.trimmingCharacters(in: .whitespaces)
                    guard !clean.isEmpty else { return }
                    let preset = ResearchPreset(name: clean, filter: filter)
                    do {
                        try store.updateWorkspace { $0.presets.append(preset) }
                        presetName = ""
                        showSavePreset = false
                    } catch {
                        store.report(error)
                    }
                }
                .buttonStyle(EdgeButtonStyle())
                .disabled(presetName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 440)
        .background(Palette.canvas)
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

    // MARK: - Disclaimer
    private var methodologyDisclaimer: some View {
        Text("Yöntem: Korelasyon nedensellik oluşturmaz. Geçmiş işlemlerin istatistiksel kohort incelemesidir. Örneklem sayısı 30'dan küçük olan gruplar için genelleme yapılmamalıdır. Döviz kurları farklı hesaplar arasında toplanmaz.")
            .font(.caption)
            .foregroundStyle(Palette.muted)
            .padding(.top, 10)
    }
}

