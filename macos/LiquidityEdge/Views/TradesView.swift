import SwiftUI

struct TradeRows: View {
    @Environment(JournalStore.self) private var store
    var trades: [TradeRecord]
    var openTrade: (TradeRecord) -> Void
    var body: some View {
        LazyVStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(L10n.text("INSTRUMENT / SETUP")); Spacer()
                Text(L10n.text("PROCESS")).frame(width: 150)
                Text(L10n.text("NET PNL")).frame(width: 110, alignment: .trailing)
                Text(L10n.text("R")).frame(width: 70, alignment: .trailing)
                Color.clear.frame(width: 10, height: 1)
            }.font(.system(size: 9, weight: .semibold)).tracking(0.8).foregroundStyle(Palette.muted).padding(.horizontal, 12).padding(.bottom, 14)
            ForEach(Array(trades.enumerated()), id: \.element.id) { index, trade in
                Button { openTrade(trade) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: trade.direction == "Long" ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 14, weight: .medium)).foregroundStyle(Palette.blue)
                            .frame(width: 36, height: 38).background(Palette.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 7) {
                            HStack(spacing: 8) {
                                Text(verbatim: trade.instrument).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                                Text(L10n.text(trade.direction.uppercased())).font(.system(size: 9, weight: .medium)).foregroundStyle(Palette.muted)
                                Spacer(minLength: 4)
                                Text(Format.date(trade.date, calendar: store.preferences.calendar)).font(.system(size: 10)).foregroundStyle(Palette.muted).lineLimit(1)
                            }
                            Text((trade.setupID == nil ? L10n.text(trade.setupName) : trade.setupName) + " · " + L10n.text(trade.session))
                                .font(.system(size: 11)).foregroundStyle(Palette.muted).lineLimit(1).help(trade.setupName + " · " + L10n.text(trade.session))
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        Badge(text: trade.classification.rawValue, color: Palette.classification(trade.classification)).frame(width: 150)
                        Text(Format.money(trade.netPnL, currency: store.currency(for: trade.id))).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(Palette.outcome(trade.netPnL)).frame(width: 110, alignment: .trailing).lineLimit(1).minimumScaleFactor(0.75)
                        Text(Format.r(trade.rMultiple)).font(.system(size: 12, weight: .medium, design: .monospaced)).foregroundStyle(Palette.outcome(trade.rMultiple ?? 0)).frame(width: 70, alignment: .trailing).lineLimit(1).minimumScaleFactor(0.75)
                        Image(systemName: "chevron.right").font(.system(size: 9, weight: .medium)).foregroundStyle(Palette.muted.opacity(0.5)).frame(width: 10)
                    }.monospacedDigit().padding(.vertical, 13).contentShape(Rectangle())
                }.buttonStyle(TradeRowButtonStyle()).accessibilityHint("İşlem ayrıntılarını aç").help("İşlemi incele")
                if index < trades.count - 1 { Rectangle().fill(Palette.muted.opacity(0.075)).frame(height: 1).padding(.leading, 60) }
            }
        }
    }
}
struct FilterBar: View {
    var allTrades: [TradeRecord]
    var calendar: Calendar
    @Binding var filter: TradeFilter
    @State private var advanced = false
    @State private var dateEnabled = false
    @FocusState private var searching: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").font(.system(size: 14)).foregroundStyle(searching ? Palette.mint : Palette.muted)
                    TextField(L10n.text("Search instrument, model, emotion, notes…"), text: $filter.query).textFieldStyle(.plain).font(.system(size: 13)).focused($searching)
                }.padding(.horizontal, 13).frame(minHeight: 40).background(Palette.canvas.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(searching ? Palette.mint.opacity(0.5) : Palette.muted.opacity(0.1)))
                Button { advanced.toggle() } label: {
                    Label("Filtreler" + (activeFilterCount > 0 ? " · \(activeFilterCount)" : ""), systemImage: "line.3.horizontal.decrease").foregroundStyle(advanced || activeFilterCount > 0 ? Palette.mint : Palette.ink)
                }.buttonStyle(EdgeButtonStyle(prominent: false, compact: true)).help("Gelişmiş filtreleri göster")
                Button { filter = TradeFilter(); dateEnabled = false } label: { Label(L10n.text("Reset"), systemImage: "arrow.counterclockwise") }.buttonStyle(EdgeButtonStyle(prominent: false, compact: true))
            }
            if advanced {
                Rectangle().fill(Palette.muted.opacity(0.1)).frame(height: 1)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: 3), alignment: .leading, spacing: 14) {
                    ForEach(AnalysisDimension.allCases) { dimension in
                        VStack(alignment: .leading, spacing: 7) {
                            Text(L10n.text(dimension.rawValue)).font(.system(size: 10, weight: .medium)).foregroundStyle(Palette.muted)
                            Picker(L10n.text(dimension.rawValue), selection: Binding(get: { filter.facets[dimension] ?? "" }, set: { filter.facets[dimension] = $0 })) {
                                Text(L10n.text("All")).tag("")
                                ForEach(Array(Set(allTrades.flatMap { dimension.keys($0, calendar: calendar) })).sorted(), id: \.self) { Text(L10n.text($0)).tag($0) }
                            }.pickerStyle(.menu).labelsHidden().buttonStyle(.borderless).font(.system(size: 12)).padding(.horizontal, 10).frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                                .background(Palette.canvas.opacity(0.45), in: RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Palette.muted.opacity(0.1)))
                        }
                    }
                }
                HStack(spacing: 16) {
                    Toggle(L10n.text("Date range"), isOn: $dateEnabled).toggleStyle(.switch).font(.system(size: 12))
                        .onChange(of: dateEnabled) { _, enabled in filter.from = enabled ? calendar.date(byAdding: .month, value: -1, to: Date()) : nil; filter.to = enabled ? Date() : nil }
                    if dateEnabled {
                        DatePicker(L10n.text("From"), selection: Binding(get: { filter.from ?? Date() }, set: { filter.from = $0 }), displayedComponents: .date)
                        DatePicker(L10n.text("Through"), selection: Binding(get: { filter.to ?? Date() }, set: { filter.to = $0 }), displayedComponents: .date)
                    }
                    Spacer(minLength: 0)
                }.padding(12).background(Palette.canvas.opacity(0.3), in: RoundedRectangle(cornerRadius: 9))
            }
        }.padding(16).background(Palette.panel, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Palette.muted.opacity(0.11)))
        .animation(.spring(response: 0.3, dampingFraction: 0.84), value: advanced)
        .onAppear { dateEnabled = filter.from != nil || filter.to != nil }
        .onChange(of: filter.from) { _, _ in dateEnabled = filter.from != nil || filter.to != nil }
        .onChange(of: filter.to) { _, _ in dateEnabled = filter.from != nil || filter.to != nil }
    }
    private var activeFilterCount: Int { filter.facets.values.filter { !$0.isEmpty }.count + ((filter.from != nil || filter.to != nil) ? 1 : 0) }
}
struct TradesView: View {
    @Environment(JournalStore.self) private var store
    var initialQuery: String
    var openTrade: (TradeRecord) -> Void
    var newTrade: () -> Void
    @State private var filter = TradeFilter()
    @State private var sort = "Newest"
    @State private var outcome = "Tümü"
    private var visible: [TradeRecord] {
        let matches = filter.apply(store.scopedTrades, calendar: store.preferences.calendar).filter { trade in
            switch outcome {
            case "Kazanç": return trade.netPnL >= 0.005
            case "Zarar": return trade.netPnL <= -0.005
            case "Kurallı": return trade.compliant
            default: return true
            }
        }
        return matches.sorted { a, b in
            switch sort {
            case "Oldest": return a.date == b.date ? a.id.uuidString < b.id.uuidString : a.date < b.date
            case "Best R": return a.rMultiple == b.rMultiple ? a.date > b.date : (a.rMultiple ?? -.infinity) > (b.rMultiple ?? -.infinity)
            case "Best PnL": return a.netPnL == b.netPnL ? a.date > b.date : a.netPnL > b.netPnL
            default: return a.date == b.date ? a.id.uuidString < b.id.uuidString : a.date > b.date
            }
        }
    }
    var body: some View {
        let sorted = visible
        let performance = AnalyticsEngine.performance(sorted)
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top, spacing: 20) {
                    PageHeader(eyebrow: "Execution log", title: "Every trade tells a story.", subtitle: "\(sorted.count) trades · Search, inspect and refine your process.")
                    Spacer(minLength: 8)
                    Button(action: newTrade) { Label(L10n.text("New trade"), systemImage: "plus") }.buttonStyle(EdgeButtonStyle()).controlSize(.large)
                }
                FilterBar(allTrades: store.scopedTrades, calendar: store.preferences.calendar, filter: $filter)
                HStack {
                    SegmentedTabs(options: ["Tümü", "Kazanç", "Zarar", "Kurallı"], selection: $outcome, title: { $0 })
                    Spacer(minLength: 12)
                    Picker(L10n.text("Sort"), selection: $sort) { ForEach(["Newest", "Oldest", "Best R", "Best PnL"], id: \.self) { Text(L10n.text($0)).tag($0) } }.frame(width: 190)
                }
                if sorted.isEmpty {
                    EmptyJournal(title: store.scopedTrades.isEmpty ? "Your journal is ready." : "No matching trades.", subtitle: store.scopedTrades.isEmpty ? "Start with a quick entry. Add context when you review." : "Change your search or reset the filters.", actionTitle: store.scopedTrades.isEmpty ? "New trade" : "Reset", action: {
                        if store.scopedTrades.isEmpty { newTrade() } else { filter = TradeFilter(); outcome = "Tümü" }
                    })
                } else {
                    HStack(spacing: 20) {
                        Label("\(sorted.count) işlem", systemImage: "list.bullet.rectangle").foregroundStyle(Palette.muted)
                        Spacer()
                        Text("Net \(Format.money(performance.netPnL, currency: store.accountCurrency))").foregroundStyle(Palette.outcome(performance.netPnL))
                        Text("\(Format.percent(performance.winRate)) başarı").foregroundStyle(Palette.muted)
                    }.font(.system(size: 12, weight: .medium)).monospacedDigit()
                    Panel { TradeRows(trades: sorted, openTrade: openTrade) }
                    Label("Kayıtlar bu Mac’te saklanır. Ayrıntılar için bir işleme tıkla.", systemImage: "internaldrive").font(.caption).foregroundStyle(Palette.muted)
                }
            }.pagePadding()
        }.onAppear { filter.query = initialQuery }.onChange(of: initialQuery) { _, value in filter.query = value }
    }
}

private struct TradeRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { RowBody(configuration: configuration) }
    private struct RowBody: View {
        let configuration: Configuration
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @Environment(\.edgeAnimationsEnabled) private var animationsEnabled
        @State private var hovering = false
        var body: some View {
            configuration.label
                .padding(.horizontal, 12)
                .background(Palette.raised.opacity(configuration.isPressed ? 0.95 : hovering ? 0.62 : 0), in: RoundedRectangle(cornerRadius: 10))
                .overlay(alignment: .leading) {
                    if hovering {
                        Capsule().fill(Palette.mint).frame(width: 2.5, height: 22).padding(.leading, 2)
                            .transition(.opacity.combined(with: .scale(scale: 0.6)))
                    }
                }
                .scaleEffect(configuration.isPressed ? 0.992 : 1.0)
                .contentShape(Rectangle())
                .onHover { hovering = $0 }
                .animation(animationsEnabled && !reduceMotion ? .spring(response: 0.22, dampingFraction: 0.8) : nil, value: hovering)
                .animation(animationsEnabled && !reduceMotion ? .spring(response: 0.16, dampingFraction: 0.72) : nil, value: configuration.isPressed)
        }
    }
}
