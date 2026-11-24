import SwiftUI

struct DashboardView: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.edgeAnimationsEnabled) private var animationsEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var openTrade: (TradeRecord) -> Void
    var newTrade: () -> Void
    var openDemo: (() -> Void)? = nil
    @State private var period = "ALL TIME"
    @State private var mode = CurveMode.dollars
    @State private var customize = false
    private var isAllTime: Bool { period == "ALL TIME" }
    private var data: [TradeRecord] {
        guard !isAllTime else { return store.scopedTrades }
        let c = store.preferences.calendar
        let component: Calendar.Component? = period == "TODAY" ? .day : period == "THIS WEEK" ? .weekOfYear : period == "THIS MONTH" ? .month : nil
        guard let component, let interval = c.dateInterval(of: component, for: Date()) else { return store.scopedTrades }
        return store.scopedTrades.filter { $0.date >= interval.start && $0.date < interval.end }
    }
    private func classificationCounts(for trades: [TradeRecord]) -> [Classification: Int] {
        if isAllTime { return store.scopedClassifications }
        var counts: [Classification: Int] = [:]
        for t in trades { counts[t.classification, default: 0] += 1 }
        return counts
    }
    var body: some View {
        let trades = data
        let p = isAllTime ? store.scopedPerformance : AnalyticsEngine.performance(trades)
        let curve = isAllTime ? store.scopedCurve : AnalyticsEngine.curve(trades)
        let counts = classificationCounts(for: trades)
        let shouldAnimate = animationsEnabled && !reduceMotion
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) {
                        headerTitle
                        Spacer(minLength: 12)
                        telemetryStrip(p)
                        Button { customize = true } label: { Label("Düzen", systemImage: "slider.horizontal.3") }.buttonStyle(EdgeButtonStyle(prominent: false))
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top) {
                            headerTitle
                            Spacer()
                            Button { customize = true } label: { Label("Düzen", systemImage: "slider.horizontal.3") }.buttonStyle(EdgeButtonStyle(prominent: false))
                        }
                        telemetryStrip(p)
                    }
                }
                HStack(spacing: 0) {
                    TerminalMetric(
                        title: "NET SONUÇ",
                        value: trades.isEmpty ? "—" : Format.money(p.netPnL, currency: store.accountCurrency),
                        color: Palette.outcome(p.netPnL),
                        subtitle: trades.isEmpty ? "" : "Beklenti " + Format.money(p.expectancy, currency: store.accountCurrency)
                    )
                    kpiDivider
                    TerminalMetric(
                        title: "ORTALAMA R",
                        value: Format.r(p.averageR),
                        color: Palette.mint,
                        subtitle: p.rCount == 0 ? "" : "Toplam " + Format.r(p.totalR)
                    )
                    kpiDivider
                    TerminalMetric(
                        title: "KAZANMA ORANI",
                        value: trades.isEmpty ? "—" : Format.percent(p.winRate),
                        subtitle: {
                            guard !trades.isEmpty else { return "" }
                            let be = max(0, p.count - p.wins - p.losses)
                            return be > 0 ? "\(p.wins)W · \(p.losses)L · \(be)BE" : "\(p.wins)W · \(p.losses)L"
                        }()
                    )
                    kpiDivider
                    TerminalMetric(
                        title: "KÂR FAKTÖRÜ",
                        value: trades.isEmpty ? "—" : Format.factor(p),
                        subtitle: p.payoffRatio.map { "Payoff " + Format.number($0) } ?? ""
                    )
                    kpiDivider
                    TerminalMetric(
                        title: "ÖRNEKLEM",
                        value: "n = \(p.count)",
                        subtitle: trades.isEmpty ? "" : "Uyum " + Format.percent(p.compliance)
                    )
                }
                .padding(.horizontal, 22).padding(.vertical, 18)
                .background(
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 15).fill(Palette.panel.opacity(0.75))
                        LinearGradient(colors: [Palette.outcome(p.netPnL).opacity(trades.isEmpty ? 0 : 0.045), .clear], startPoint: .leading, endPoint: .center)
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                    }
                )
                .overlay(RoundedRectangle(cornerRadius: 15).strokeBorder(Palette.line.opacity(0.85), lineWidth: 1))
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(LinearGradient(colors: [Palette.mint.opacity(0.32), Palette.specular.opacity(0.03)], startPoint: .leading, endPoint: .trailing))
                        .frame(height: 1)
                        .padding(.horizontal, 18)
                }
                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
                .edgeEntrance(delay: 0.03)
                ViewThatFits(in: .horizontal) {
                    HStack { periodPicker; Spacer(); unitPicker }
                    VStack(alignment: .leading) { periodPicker; unitPicker }
                }
                if trades.isEmpty {
                    VStack(alignment: .leading, spacing: 20) {
                        Image(systemName: "chart.xyaxis.line").font(.system(size: 45, weight: .ultraLight)).foregroundStyle(Palette.mint)
                        Text(store.scopedTrades.isEmpty ? "Bir sonraki kararın,\nbugünkü kaydınla başlar." : "Bu dönemde kayıt yok.").font(.system(size: 30, weight: .medium))
                        Text("İşlemlerini kaydet, kararlarını incele, gelişimini izle. Grafikler gerçek kayıtlarınla oluşur.").foregroundStyle(Palette.muted)
                        HStack {
                            Button("İşlem kaydet", action: newTrade).buttonStyle(EdgeButtonStyle())
                            if let openDemo { Button("Örnek günlüğü keşfet", action: openDemo).buttonStyle(EdgeButtonStyle(prominent: false)) }
                            if !store.scopedTrades.isEmpty { Button("Tüm zamanlar") { period = "ALL TIME" } }
                        }
                    }.padding(36).frame(maxWidth: .infinity, minHeight: 350, alignment: .leading).background(Palette.panel, in: RoundedRectangle(cornerRadius: 16))
                } else {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 24) {
                            flagship(p, curve: curve).frame(minWidth: 510)
                            processRail(p, counts: counts, total: trades.count).frame(width: 248)
                        }
                        VStack(spacing: 24) { flagship(p, curve: curve); processRail(p, counts: counts, total: trades.count) }
                    }.edgeEntrance(delay: 0.07)
                    ForEach(store.workspace.widgets.filter { !store.workspace.hiddenWidgets.contains($0) }, id: \.self) { widget in
                        switch widget {
                        case "Risk & R":
                            HStack(alignment: .top, spacing: 24) {
                                Panel(title: "R / RİSK BİRİMİ", subtitle: "\(p.rCount) kayıtlı R · \(Format.r(p.totalR)) toplam") {
                                    if p.rCount > 0 { EquityChart(points: curve, mode: .r, height: 205) }
                                    else { Text("R değeri kaydedilmemiş.").foregroundStyle(Palette.muted) }
                                }
                                Panel(title: "DRAWDOWN / ZİRVEDEN UZAKLIK", subtitle: "Maksimum \(Format.money(p.maxDrawdown, currency: store.accountCurrency))") {
                                    EquityChart(points: curve, mode: .drawdown, height: 205)
                                }
                            }
                        case "Rolling":
                            Panel(title: "HAREKETLİ KAZANMA ORANI", subtitle: "Son 20 işlem · İlk pencerelerde mevcut örneklem") { EquityChart(points: Array(curve.dropFirst()), mode: .rolling, height: 190) }
                        case "Timing":
                            Panel(title: "ZAMANLAMA / ORTALAMA R", subtitle: store.preferences.timezone) { PerformanceHeatmap(trades: trades, calendar: store.preferences.calendar) }
                        case "Recent":
                            Panel(title: "SON İŞLEMLER", subtitle: "Bir kayıt seçerek ayrıntıları incele") { TradeRows(trades: Array(trades.prefix(6)), openTrade: openTrade) }
                        case "Metrics":
                            DisclosureGroup("Tüm performans ölçümleri") { MetricsGrid(performance: p, currency: store.accountCurrency).padding(.top, 16) }.font(.system(size: 13, weight: .medium))
                        default: EmptyView()
                        }
                    }
                }
                Label(store.isDemo ? "İzole örnek çalışma alanı" : "Yerel günlük · Kaydedilen gözlemler", systemImage: "lock.shield").font(.caption).foregroundStyle(Palette.muted)
            }.pagePadding()
        }
        .animation(shouldAnimate ? .spring(response: 0.35, dampingFraction: 0.8) : nil, value: period)
        .animation(shouldAnimate ? .spring(response: 0.35, dampingFraction: 0.8) : nil, value: mode)
        .sheet(isPresented: $customize) { DashboardLayoutEditor().environment(store) }
    }
    private var headerTitle: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Capsule().fill(Palette.mint).frame(width: 14, height: 3)
                Text("PERFORMANCE / 01").font(EdgeType.eyebrow).tracking(2).foregroundStyle(Palette.mint)
            }
            Text("Performans masası").font(.system(size: 29, weight: .semibold)).tracking(-1)
            Text(store.selectedAccount.name + "  ·  " + store.accountCurrency).font(.caption).foregroundStyle(Palette.muted)
        }
    }
    private func telemetryStrip(_ p: Performance) -> some View {
        let balance = store.selectedAccount.startingBalance + store.scopedPerformance.netPnL
        let today = store.scopedTodayPnL
        return HStack(spacing: 8) {
            telemetryPill(label: "BAKİYE", value: Format.money(balance, currency: store.accountCurrency), color: Palette.ink, dot: Palette.mint)
            telemetryPill(label: "BUGÜN", value: (today > 0 ? "+" : "") + Format.money(today, currency: store.accountCurrency), color: Palette.outcome(today), dot: Palette.outcome(today))
            if p.currentWinStreak > 0 {
                telemetryPill(label: "SERİ", value: "\(p.currentWinStreak)W", color: Palette.mint, dot: Palette.mint)
            } else if p.currentLossStreak > 0 {
                telemetryPill(label: "SERİ", value: "\(p.currentLossStreak)L", color: Palette.red, dot: Palette.red)
            }
        }
    }
    private func telemetryPill(label: String, value: String, color: Color, dot: Color) -> some View {
        HStack(spacing: 8) {
            Circle().fill(dot).frame(width: 6, height: 6)
                .shadow(color: dot.opacity(0.45), radius: 3, x: 0, y: 0)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 8, weight: .semibold, design: .monospaced)).tracking(1).foregroundStyle(Palette.muted)
                Text(verbatim: value).font(.system(size: 12, weight: .semibold, design: .rounded)).monospacedDigit().foregroundStyle(color)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(Palette.panel.opacity(0.8), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.line.opacity(0.85), lineWidth: 1))
    }
    private var periodPicker: some View { SegmentedTabs(options: ["TODAY", "THIS WEEK", "THIS MONTH", "ALL TIME"], selection: $period, title: { $0 }) }
    private var unitPicker: some View { SegmentedTabs(options: [CurveMode.dollars, .r, .percent], selection: $mode, title: { $0 == .dollars ? store.accountCurrency : $0.rawValue }) }
    private func flagship(_ p: Performance, curve: [CurvePoint]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                HStack(spacing: 9) {
                    ZStack {
                        Circle().fill(Palette.mint.opacity(0.22)).frame(width: 14, height: 14)
                        Circle().fill(Palette.mint).frame(width: 6, height: 6)
                    }
                    Text("Sermaye gelişimi").font(.system(size: 18, weight: .semibold))
                }
                Spacer()
                HStack(spacing: 10) {
                    if p.maxDrawdown > 0 {
                        Text("MAX DD −\(Format.money(p.maxDrawdown, currency: store.accountCurrency))")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Palette.red.opacity(0.9))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Palette.red.opacity(0.08), in: Capsule())
                    }
                    Text("NET / \(L10n.text(period))")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced)).tracking(1.4)
                        .foregroundStyle(Palette.mint)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Palette.mint.opacity(0.1), in: Capsule())
                }
            }
            EquityChart(points: curve, mode: mode, accountSize: store.selectedAccount.startingBalance, height: 315)
            HStack {
                Label("Doğrusal · kayıt sırası korunur", systemImage: "waveform.path").foregroundStyle(Palette.muted)
                Spacer()
                Text("\(p.rCount) / \(p.count) R kaydı").font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.muted)
            }.font(.system(size: 10))
        }
        .padding(22)
        .background(Palette.panel, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Palette.line.opacity(0.85), lineWidth: 1))
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: 1)
                .fill(LinearGradient(colors: [Palette.mint.opacity(0.38), Palette.mint.opacity(0.02)], startPoint: .leading, endPoint: .trailing))
                .frame(height: 1.5)
                .padding(.horizontal, 18)
        }
        .shadow(color: Color.black.opacity(0.06), radius: 14, x: 0, y: 6)
    }
    private var kpiDivider: some View {
        Rectangle().fill(Palette.line.opacity(0.65)).frame(width: 1, height: 38).padding(.horizontal, 16)
    }
    private func processRail(_ p: Performance, counts: [Classification: Int], total: Int) -> some View {
        let ordered: [Classification] = [.validWinner, .validLoser, .invalidWinner, .invalidLoser, .breakeven]
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("SÜREÇ / DİSİPLİN").font(EdgeType.eyebrow).tracking(1.4).foregroundStyle(Palette.muted)
                Spacer()
                Badge(text: Format.percent(p.compliance), color: p.compliance >= 80 ? Palette.mint : Palette.amber)
            }
            HStack {
                Spacer()
                ExecutionScoreRing(score: p.executionScore, size: 122, lineWidth: 8.5)
                Spacer()
            }.padding(.vertical, 2)
            HStack {
                Text("Plana uyum").foregroundStyle(Palette.muted)
                Spacer()
                Text(Format.percent(p.compliance))
                    .fontWeight(.semibold).monospacedDigit()
                    .foregroundStyle(p.compliance >= 80 ? Palette.mint : Palette.amber)
            }.font(.caption)
            // Proportional stacked classification distribution bar
            if total > 0 {
                GeometryReader { geo in
                    let nonZero = ordered.filter { (counts[$0] ?? 0) > 0 }
                    let spacingTotal = CGFloat(max(0, nonZero.count - 1)) * 2
                    let avail = max(1, geo.size.width - spacingTotal)
                    HStack(spacing: 2) {
                        ForEach(nonZero, id: \.self) { type in
                            let share = CGFloat(counts[type] ?? 0) / CGFloat(total)
                            Capsule()
                                .fill(Palette.classification(type))
                                .frame(width: max(4, avail * share))
                        }
                    }
                }
                .frame(height: 6)
            }
            Rectangle().fill(Palette.line.opacity(0.7)).frame(height: 1)
            VStack(spacing: 8) {
                ForEach(ordered, id: \.self) { type in
                    let count = counts[type] ?? 0
                    let share = total > 0 ? Int(round(Double(count) / Double(total) * 100)) : 0
                    HStack(spacing: 8) {
                        Circle().fill(Palette.classification(type)).frame(width: 6, height: 6)
                        Text(L10n.text(type.rawValue)).font(.system(size: 10, weight: .medium)).foregroundStyle(Palette.ink.opacity(0.9))
                        Spacer()
                        if count > 0 {
                            Text("\(share)%").font(.system(size: 9, design: .monospaced)).foregroundStyle(Palette.muted.opacity(0.75))
                        }
                        Text(count.description).font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundStyle(count > 0 ? Palette.ink : Palette.muted.opacity(0.5)).frame(minWidth: 18, alignment: .trailing)
                    }
                }
            }
            Rectangle().fill(Palette.line.opacity(0.7)).frame(height: 1)
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("A+ kazanma oranı").font(.caption).foregroundStyle(Palette.muted)
                    Text(p.aPlusWinRate.map(Format.percent) ?? "—")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Palette.mint)
                }
                Spacer()
                if let rec = p.recoveryFactor {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("Recovery").font(.caption).foregroundStyle(Palette.muted)
                        Text(Format.number(rec))
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Palette.blue)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.panel, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Palette.line.opacity(0.85), lineWidth: 1))
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: 1)
                .fill(LinearGradient(colors: [Palette.specular.opacity(0.08), .clear], startPoint: .leading, endPoint: .trailing))
                .frame(height: 1)
                .padding(.horizontal, 16)
        }
        .shadow(color: Color.black.opacity(0.06), radius: 14, x: 0, y: 6)
    }
}
struct DashboardLayoutEditor: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack { Text("Çalışma alanını düzenle").font(.title2.weight(.semibold)); Spacer(); Button("Bitti") { dismiss() }.buttonStyle(EdgeButtonStyle(compact: true)).keyboardShortcut(.cancelAction) }
            Text("Ana grafik her zaman görünür. İkincil bölümler hesabınla birlikte yerel olarak saklanır.").font(.caption).foregroundStyle(Palette.muted)
            ForEach(Array(store.workspace.widgets.enumerated()), id: \.element) { index, widget in
                HStack {
                    Toggle(widget, isOn: Binding(get: { !store.workspace.hiddenWidgets.contains(widget) }, set: { visible in change { state in state.hiddenWidgets.removeAll { $0 == widget }; if !visible { state.hiddenWidgets.append(widget) } } }))
                    Spacer()
                    Button { change { $0.widgets.swapAt(index, index - 1) } } label: { Image(systemName: "arrow.up") }.buttonStyle(EdgeButtonStyle(prominent: false, compact: true)).disabled(index == 0).help("Yukarı taşı")
                    Button { change { $0.widgets.swapAt(index, index + 1) } } label: { Image(systemName: "arrow.down") }.buttonStyle(EdgeButtonStyle(prominent: false, compact: true)).disabled(index == store.workspace.widgets.count - 1).help("Aşağı taşı")
                }.padding(10).background(Palette.panel, in: RoundedRectangle(cornerRadius: 8))
            }
            Button("Varsayılan düzen") { change { $0.widgets = WorkspaceState().widgets; $0.hiddenWidgets = [] } }.buttonStyle(EdgeButtonStyle(prominent: false, compact: true))
        }.padding(28).frame(width: 520).background(Palette.canvas).foregroundStyle(Palette.ink).tint(Palette.mint)
    }
    private func change(_ body: (inout WorkspaceState) -> Void) { do { try store.updateWorkspace(body) } catch { store.report(error) } }
}
struct MetricsGrid: View {
    var performance: Performance
    var currency: String
    var body: some View {
        let p = performance
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
            MetricCard(title: "Profit factor", value: Format.factor(p))
            MetricCard(title: "Expectancy / trade", value: Format.money(p.expectancy, currency: currency))
            MetricCard(title: "Average winner", value: Format.money(p.averageWinner, currency: currency), color: Palette.outcome(p.averageWinner))
            MetricCard(title: "Average loser", value: Format.money(p.averageLoser, currency: currency), color: Palette.outcome(p.averageLoser))
            MetricCard(title: "Average R", value: Format.r(p.averageR))
            MetricCard(title: "Best trade", value: Format.money(p.bestTrade, currency: currency))
            MetricCard(title: "Worst trade", value: Format.money(p.worstTrade, currency: currency))
            MetricCard(title: "Max drawdown", value: Format.money(p.maxDrawdown, currency: currency))
            MetricCard(title: "Current win streak", value: p.currentWinStreak.description)
            MetricCard(title: "Current loss streak", value: p.currentLossStreak.description)
            MetricCard(title: "Rule compliance", value: Format.percent(p.compliance))
            MetricCard(title: "Total trades", value: p.count.description)
            MetricCard(title: "Loss rate", value: Format.percent(p.lossRate))
            MetricCard(title: "Recovery factor", value: p.recoveryFactor.map { Format.number($0) } ?? "—")
            MetricCard(title: "Realized payoff ratio", value: p.payoffRatio.map { Format.number($0) } ?? "—")
            MetricCard(title: "Average duration", value: p.averageDuration.map { Format.number($0 / 60, digits: 0) + " dk" } ?? "—")
        }
    }
}
