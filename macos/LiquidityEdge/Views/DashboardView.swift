import SwiftUI

struct DashboardView: View {
    @Environment(JournalStore.self) private var store
    var openTrade: (TradeRecord) -> Void
    var newTrade: () -> Void
    var openDemo: (() -> Void)? = nil
    @State private var period = "ALL TIME"
    @State private var mode = CurveMode.dollars
    @State private var customize = false
    private var data: [TradeRecord] {
        let c = store.preferences.calendar
        let component: Calendar.Component? = period == "TODAY" ? .day : period == "THIS WEEK" ? .weekOfYear : period == "THIS MONTH" ? .month : nil
        guard let component, let interval = c.dateInterval(of: component, for: Date()) else { return store.scopedTrades }
        return store.scopedTrades.filter { $0.date >= interval.start && $0.date < interval.end }
    }
    var body: some View {
        let p = AnalyticsEngine.performance(data), curve = AnalyticsEngine.curve(data)
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PERFORMANCE / 01").font(EdgeType.eyebrow).tracking(2).foregroundStyle(Palette.mint)
                        Text("Performans masası").font(.system(size: 29, weight: .semibold)).tracking(-1)
                        Text(store.selectedAccount.name + "  ·  " + store.accountCurrency).font(.caption).foregroundStyle(Palette.muted)
                    }
                    Spacer()
                    Button { customize = true } label: { Label("Düzen", systemImage: "slider.horizontal.3") }.buttonStyle(EdgeButtonStyle(prominent: false))
                }
                HStack(spacing: 20) {
                    TerminalMetric(title: "NET SONUÇ", value: data.isEmpty ? "—" : Format.money(p.netPnL, currency: store.accountCurrency), color: Palette.outcome(p.netPnL))
                    TerminalMetric(title: "ORTALAMA R", value: Format.r(p.averageR), color: Palette.mint)
                    TerminalMetric(title: "KAZANMA ORANI", value: data.isEmpty ? "—" : Format.percent(p.winRate))
                    TerminalMetric(title: "KÂR FAKTÖRÜ", value: data.isEmpty ? "—" : Format.factor(p))
                    TerminalMetric(title: "ÖRNEKLEM", value: "n = \(p.count)")
                }.padding(.vertical, 20)
                    .overlay(alignment: .top) { Rectangle().fill(Palette.line).frame(height: 1) }
                    .overlay(alignment: .bottom) { Rectangle().fill(Palette.line).frame(height: 1) }
                ViewThatFits(in: .horizontal) {
                    HStack { periodPicker; Spacer(); unitPicker }
                    VStack(alignment: .leading) { periodPicker; unitPicker }
                }
                if data.isEmpty {
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
                            processRail(p).frame(width: 220)
                        }
                        VStack(spacing: 24) { flagship(p, curve: curve); processRail(p) }
                    }
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
                            Panel(title: "ZAMANLAMA / ORTALAMA R", subtitle: store.preferences.timezone) { PerformanceHeatmap(trades: data, calendar: store.preferences.calendar) }
                        case "Recent":
                            Panel(title: "SON İŞLEMLER", subtitle: "Bir kayıt seçerek ayrıntıları incele") { TradeRows(trades: Array(data.prefix(6)), openTrade: openTrade) }
                        case "Metrics":
                            DisclosureGroup("Tüm performans ölçümleri") { MetricsGrid(performance: p, currency: store.accountCurrency).padding(.top, 16) }.font(.system(size: 13, weight: .medium))
                        default: EmptyView()
                        }
                    }
                }
                Label(store.isDemo ? "İzole örnek çalışma alanı" : "Yerel günlük · Kaydedilen gözlemler", systemImage: "lock.shield").font(.caption).foregroundStyle(Palette.muted)
            }.pagePadding()
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: period)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: mode)
        .sheet(isPresented: $customize) { DashboardLayoutEditor().environment(store) }
    }
    private var periodPicker: some View { SegmentedTabs(options: ["TODAY", "THIS WEEK", "THIS MONTH", "ALL TIME"], selection: $period, title: { $0 }) }
    private var unitPicker: some View { SegmentedTabs(options: [CurveMode.dollars, .r, .percent], selection: $mode, title: { $0 == .dollars ? store.accountCurrency : $0.rawValue }) }
    private func flagship(_ p: Performance, curve: [CurvePoint]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 8) {
                    Circle().fill(Palette.mint).frame(width: 7, height: 7)
                    Text("Sermaye gelişimi").font(.system(size: 18, weight: .semibold))
                }
                Spacer()
                Text("NET / \(L10n.text(period))").font(.system(size: 9, weight: .semibold, design: .monospaced)).tracking(1.4).foregroundStyle(Palette.mint)
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
                .fill(LinearGradient(colors: [Palette.mint.opacity(0.35), Palette.mint.opacity(0.02)], startPoint: .leading, endPoint: .trailing))
                .frame(height: 1.5)
                .padding(.horizontal, 18)
        }
        .shadow(color: Color.black.opacity(0.06), radius: 14, x: 0, y: 6)
    }
    private func processRail(_ p: Performance) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("SÜREÇ / DİSİPLİN").font(EdgeType.eyebrow).tracking(1.2).foregroundStyle(Palette.muted)
            HStack(alignment: .firstTextBaseline) {
                Text(Format.number(p.executionScore, digits: 0)).font(.system(size: 48, weight: .light, design: .rounded)).monospacedDigit()
                Text("/ 100").font(.caption).foregroundStyle(Palette.muted)
            }
            ProgressView(value: p.executionScore, total: 100).tint(Palette.mint)
            HStack { Text("Plana uyum"); Spacer(); Text(Format.percent(p.compliance)).foregroundStyle(p.compliance >= 80 ? Palette.mint : Palette.amber) }.font(.caption)
            Divider()
            ForEach([Classification.validWinner, .validLoser, .invalidWinner, .invalidLoser, .breakeven], id: \.self) { type in
                HStack {
                    Circle().fill(Palette.classification(type)).frame(width: 5, height: 5)
                    Text(L10n.text(type.rawValue)).font(.system(size: 10))
                    Spacer()
                    Text(data.filter { $0.classification == type }.count.description).font(.system(size: 12, design: .monospaced))
                }
            }
            Divider()
            Text("A+ kazanma oranı").font(.caption).foregroundStyle(Palette.muted)
            Text(p.aPlusWinRate.map(Format.percent) ?? "—").font(.title2).monospacedDigit()
        }.padding(.vertical, 12).frame(maxWidth: .infinity, alignment: .leading)
    }
}
struct DashboardLayoutEditor: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack { Text("Çalışma alanını düzenle").font(.title2); Spacer(); Button("Bitti") { dismiss() }.keyboardShortcut(.cancelAction) }
            Text("Ana grafik her zaman görünür. İkincil bölümler hesabınla birlikte yerel olarak saklanır.").font(.caption).foregroundStyle(Palette.muted)
            ForEach(Array(store.workspace.widgets.enumerated()), id: \.element) { index, widget in
                HStack {
                    Toggle(widget, isOn: Binding(get: { !store.workspace.hiddenWidgets.contains(widget) }, set: { visible in change { state in state.hiddenWidgets.removeAll { $0 == widget }; if !visible { state.hiddenWidgets.append(widget) } } }))
                    Spacer()
                    Button { change { $0.widgets.swapAt(index, index - 1) } } label: { Image(systemName: "arrow.up") }.disabled(index == 0).help("Yukarı taşı")
                    Button { change { $0.widgets.swapAt(index, index + 1) } } label: { Image(systemName: "arrow.down") }.disabled(index == store.workspace.widgets.count - 1).help("Aşağı taşı")
                }.padding(10).background(Palette.panel, in: RoundedRectangle(cornerRadius: 8))
            }
            Button("Varsayılan düzen") { change { $0.widgets = WorkspaceState().widgets; $0.hiddenWidgets = [] } }
        }.padding(28).frame(width: 520).background(Palette.canvas)
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
