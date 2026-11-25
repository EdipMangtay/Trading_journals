import SwiftUI

enum JournalPage: String, CaseIterable, Identifiable {
    case accounts = "Hesaplar & Risk", research = "Araştırma Laboratuvarı", quant = "Senaryo Analizi", planning = "Günlük Plan", dataImport = "CSV Aktarım"
    case dashboard = "Dashboard", trades = "Trades", newTrade = "New Trade", calendar = "Calendar", analytics = "Analytics", setups = "Setup Analysis", playbook = "Playbook", mistakes = "Mistakes", screenshots = "Screenshots", statistics = "Statistics", review = "Review", settings = "Settings"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .accounts: return "building.columns"
        case .research: return "slider.horizontal.2.square"
        case .quant: return "chart.line.uptrend.xyaxis"
        case .planning: return "checklist"
        case .dataImport: return "square.and.arrow.down"
        case .dashboard: return "square.grid.2x2"
        case .trades: return "list.bullet.rectangle"
        case .newTrade: return "plus.app"
        case .calendar: return "calendar"
        case .analytics: return "chart.xyaxis.line"
        case .setups: return "square.stack.3d.up"
        case .playbook: return "book.closed"
        case .mistakes: return "exclamationmark.shield"
        case .screenshots: return "photo.on.rectangle"
        case .statistics: return "chart.bar.xaxis"
        case .review: return "checkmark.rectangle"
        case .settings: return "slider.horizontal.3"
        }
    }
}
struct EditorRoute: Identifiable { let id = UUID(); var record: TradeRecord? }
struct DetailRoute: Identifiable { var id: UUID }
enum RootSheet: Identifiable {
    case tradeEditor(EditorRoute)
    case tradeDetail(DetailRoute)
    case commandPalette
    case playbookEditor(PlaybookDraft)
    var id: String {
        switch self {
        case .tradeEditor(let r): return "editor-\(r.id.uuidString)"
        case .tradeDetail(let r): return "detail-\(r.id.uuidString)"
        case .commandPalette: return "palette"
        case .playbookEditor(let d): return "playbook-\(d.id.uuidString)"
        }
    }
}
struct RootView: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var startJournal: () -> Void
    var openDemo: () -> Void
    @SceneStorage("journal.navigation.page") private var selectedPage = JournalPage.dashboard.rawValue
    @AppStorage("journal.sidebar.collapsed") private var collapsed = false
    @State private var activeSheet: RootSheet?
    @State private var globalQuery = ""
    @FocusState private var searchFocused: Bool
    @Namespace private var sidebarNamespace
    var initialPage: JournalPage? = nil
    private var page: JournalPage {
        get { initialPage ?? (JournalPage(rawValue: selectedPage) ?? .dashboard) }
        nonmutating set { selectedPage = newValue.rawValue }
    }
    private var animation: Animation? { store.preferences.animations && !reduceMotion ? .spring(response: 0.28, dampingFraction: 0.86) : nil }
    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(Palette.line.opacity(0.8)).frame(width: 1)
            VStack(spacing: 0) {
                topbar
                if store.isDemo { demoBanner }
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background { TerminalBackdrop() }
        }.background(Palette.canvas).foregroundStyle(Palette.ink).tint(Palette.mint)
        .animation(animation, value: collapsed)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .tradeEditor(let route):
                TradeEditorView(record: route.record).environment(store)
            case .tradeDetail(let route):
                TradeDetailView(tradeID: route.id, edit: { record in
                    activeSheet = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        activeSheet = .tradeEditor(EditorRoute(record: record))
                    }
                }).environment(store)
            case .commandPalette:
                commandPalette
            case .playbookEditor(let draft):
                PlaybookEditor(initial: draft).environment(store)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newTrade)) { _ in if activeSheet == nil { activeSheet = .tradeEditor(EditorRoute()) } }
        .onReceive(NotificationCenter.default.publisher(for: .commandPalette)) { _ in if activeSheet == nil { showSearch() } }
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in if activeSheet == nil { page = .settings } }
        .alert(L10n.text("Journal error"), isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) { Button(L10n.text("OK")) { store.errorMessage = nil } } message: { Text(L10n.text(store.errorMessage ?? "")) }
        .environment(\.timeZone, TimeZone(identifier: store.preferences.timezone) ?? .current)
        .environment(\.edgeAnimationsEnabled, store.preferences.animations)
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [Palette.mint.opacity(0.24), .clear], center: .center, startRadius: 2, endRadius: 28))
                        .frame(width: 52, height: 52)
                    RoundedRectangle(cornerRadius: 12).fill(LinearGradient(colors: [Palette.mint.opacity(0.2), Palette.mint.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.mint.opacity(0.35), lineWidth: 1)
                    Image(systemName: "waveform.path").font(.system(size: 22, weight: .medium)).foregroundStyle(Palette.mint)
                }.frame(width: 39, height: 41)
                if !collapsed {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(verbatim: "LIQUIDITY").tracking(2).foregroundStyle(Palette.ink)
                        HStack(spacing: 6) {
                            Text(verbatim: "EDGE").tracking(4).foregroundStyle(Palette.mint)
                            Text(verbatim: "v6")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(Palette.mint)
                                .padding(.horizontal, 5).padding(.vertical, 1.5)
                                .background(Palette.mint.opacity(0.12), in: Capsule())
                                .overlay(Capsule().strokeBorder(Palette.mint.opacity(0.28), lineWidth: 0.8))
                        }
                    }.font(.system(size: 11, weight: .semibold, design: .monospaced))
                }
            }.padding(.horizontal, collapsed ? 17 : 22).padding(.top, 39).padding(.bottom, 27)
            ScrollView {
                VStack(alignment: .leading, spacing: 21) {
                    navigationGroup("GÜNLÜK", pages: [.dashboard, .trades, .calendar])
                    navigationGroup("PERFORMANS", pages: [.research, .accounts, .quant, .analytics, .setups, .statistics, .mistakes])
                    navigationGroup("GELİŞİM", pages: [.planning, .playbook, .screenshots, .review, .dataImport])
                }.padding(.horizontal, 12).padding(.bottom, 16)
            }.scrollIndicators(.hidden)
            VStack(alignment: .leading, spacing: 14) {
                Rectangle().fill(Palette.line.opacity(0.8)).frame(height: 1)
                navigationItem(.settings)
                if !collapsed {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 7) {
                            Image(systemName: store.isDemo ? "sparkles" : "internaldrive.fill").foregroundStyle(store.isDemo ? Palette.amber : Palette.mint)
                            Text(store.isDemo ? "Örnek çalışma alanı" : "Bu Mac’te saklanıyor").fontWeight(.medium)
                        }.font(.system(size: 11))
                        Text(store.isDemo ? "Örnek veriler kalıcı günlüğünüzü etkilemez." : "Verileriniz yerel olarak kaydedilir.").font(.system(size: 10)).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
                    }.padding(13).frame(maxWidth: .infinity, alignment: .leading).background(Palette.field.opacity(0.7), in: RoundedRectangle(cornerRadius: 11)).overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Palette.line.opacity(0.6)))
                }
                Button { collapsed.toggle() } label: {
                    HStack(spacing: 10) {
                        Image(systemName: collapsed ? "sidebar.left" : "sidebar.leading").frame(width: 20)
                        if !collapsed { Text("Kenar çubuğunu daralt").font(.system(size: 11)); Spacer() }
                    }.foregroundStyle(Palette.muted).frame(maxWidth: .infinity, minHeight: 28, alignment: .leading).padding(.horizontal, 12)
                }.buttonStyle(NavigationButtonStyle()).help(L10n.text("Toggle sidebar")).accessibilityLabel(L10n.text("Toggle sidebar"))
            }.padding(.horizontal, 12).padding(.bottom, 15)
        }.frame(width: collapsed ? 76 : 226).background(Palette.sidebar)
    }
    private func navigationGroup(_ title: String, pages: [JournalPage]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if !collapsed { Text(title).font(EdgeType.eyebrow).tracking(1.4).foregroundStyle(Palette.muted.opacity(0.85)).accessibilityAddTraits(.isHeader).padding(.horizontal, 12).padding(.bottom, 6) }
            ForEach(pages) { item in navigationItem(item) }
        }
    }
    private func navigationItem(_ item: JournalPage) -> some View {
        let isSelected = page == item
        return Button {
            if page != item {
                page = item
                if store.preferences.animations && !reduceMotion { EdgeHaptics.tick() }
            }
        } label: {
            HStack(spacing: 11) {
                Image(systemName: item.icon)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Palette.mint : Palette.muted)
                    .frame(width: 20)
                if !collapsed {
                    Text(L10n.text(item.rawValue))
                        .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? Palette.ink : Palette.muted)
                    Spacer(minLength: 0)
                    if item == .trades && !store.scopedTrades.isEmpty {
                        Text(store.scopedTrades.count.description)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(isSelected ? Palette.mint : Palette.muted)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(isSelected ? Palette.mint.opacity(0.16) : Palette.raised, in: RoundedRectangle(cornerRadius: 5))
                            .contentTransition(.numericText())
                    } else if item == .playbook && !store.setups.isEmpty {
                        Text(store.setups.count.description)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(isSelected ? Palette.mint : Palette.muted)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(isSelected ? Palette.mint.opacity(0.16) : Palette.raised, in: RoundedRectangle(cornerRadius: 5))
                            .contentTransition(.numericText())
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
            .padding(.horizontal, 12)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(LinearGradient(colors: [Palette.mint.opacity(0.14), Palette.mint.opacity(0.05)], startPoint: .leading, endPoint: .trailing))
                        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Palette.mint.opacity(0.24), lineWidth: 1))
                        .overlay(alignment: .leading) {
                            Capsule().fill(Palette.mint).frame(width: 3, height: 18).padding(.leading, 1)
                                .shadow(color: Palette.mint.opacity(0.6), radius: 4, x: 0, y: 0)
                        }
                        .matchedGeometryEffect(id: "sidebarActivePill", in: sidebarNamespace)
                }
            }
        }
        .buttonStyle(SidebarRowHoverStyle(selected: isSelected))
        .help(L10n.text(item.rawValue))
        .accessibilityLabel(L10n.text(item.rawValue))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
    private var topbar: some View {
        HStack(spacing: 13) {
            Image(systemName: page.icon).foregroundStyle(Palette.mint).font(.system(size: 14, weight: .semibold))
                .frame(width: 32, height: 32)
                .background(LinearGradient(colors: [Palette.mint.opacity(0.15), Palette.mint.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Palette.mint.opacity(0.24), lineWidth: 1))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("ÇALIŞMA ALANI").font(.system(size: 8, weight: .bold, design: .monospaced)).tracking(1.3).foregroundStyle(Palette.muted)
                Text(L10n.text(page.rawValue)).font(.system(size: 14, weight: .semibold)).accessibilityAddTraits(.isHeader)
            }
            Spacer(minLength: 8)
            if !store.scopedTrades.isEmpty {
                let net = store.scopedPerformance.netPnL
                let today = store.scopedTodayPnL
                let wr = store.scopedPerformance.winRate
                ViewThatFits(in: .horizontal) {
                    topbarTelemetryButton(net: net, today: abs(today) >= 0.01 ? today : nil, winRate: wr)
                    topbarTelemetryButton(net: net, today: abs(today) >= 0.01 ? today : nil, winRate: nil)
                    topbarTelemetryButton(net: net, today: nil, winRate: nil)
                    EmptyView()
                }
            }
            AccountPicker()
            Rectangle().fill(Palette.line.opacity(0.9)).frame(width: 1, height: 22).padding(.horizontal, 3)
            Button(action: showSearch) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                    Text(L10n.text("Search")).lineLimit(1)
                    Text("⌘K").font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.muted)
                        .padding(.horizontal, 5).padding(.vertical, 2).background(Palette.field, in: RoundedRectangle(cornerRadius: 4))
                }
                .fixedSize(horizontal: true, vertical: false)
            }.buttonStyle(EdgeButtonStyle(prominent: false)).fixedSize(horizontal: true, vertical: false).help(L10n.text("Search & Commands"))
            Button { activeSheet = .tradeEditor(EditorRoute()) } label: { Label(L10n.text("New trade"), systemImage: "plus").fixedSize(horizontal: true, vertical: false) }.buttonStyle(EdgeButtonStyle()).fixedSize(horizontal: true, vertical: false).help("Yeni işlem · ⌘N")
        }
        .padding(.horizontal, 28).frame(height: 68)
        .background(.ultraThinMaterial)
        .background(Palette.panel.opacity(0.58))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(LinearGradient(colors: [Palette.mint.opacity(0.18), Palette.line.opacity(0.75), Palette.line.opacity(0.5)], startPoint: .leading, endPoint: .trailing))
                .frame(height: 1)
        }
    }
    private func topbarTelemetryButton(net: Double, today: Double?, winRate: Double?) -> some View {
        Button { page = .accounts } label: {
            HStack(spacing: 7) {
                Circle().fill(Palette.outcome(net)).frame(width: 6, height: 6)
                    .shadow(color: Palette.outcome(net).opacity(0.55), radius: 3)
                Text("NET").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(Palette.muted)
                Text(verbatim: Format.money(net, currency: store.accountCurrency))
                    .font(.system(size: 11, weight: .bold, design: .rounded)).monospacedDigit()
                    .foregroundStyle(Palette.outcome(net))
                if let today {
                    Rectangle().fill(Palette.line).frame(width: 1, height: 12)
                    Text("BUGÜN").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(Palette.muted)
                    Text(verbatim: (today > 0 ? "+" : "") + Format.money(today, currency: store.accountCurrency))
                        .font(.system(size: 11, weight: .bold, design: .rounded)).monospacedDigit()
                        .foregroundStyle(Palette.outcome(today))
                }
                if let winRate {
                    Rectangle().fill(Palette.line).frame(width: 1, height: 12)
                    Text("WR").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(Palette.muted)
                    Text(verbatim: Format.percent(winRate))
                        .font(.system(size: 11, weight: .semibold, design: .rounded)).monospacedDigit()
                        .foregroundStyle(Palette.ink)
                }
            }
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 12).padding(.vertical, 6.5)
            .background(Palette.field.opacity(0.88), in: Capsule())
            .overlay(Capsule().strokeBorder(Palette.line.opacity(0.9), lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("Hesaplar ve Risk özetine git")
    }
    private var demoBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles").foregroundStyle(Palette.amber)
            Badge(text: "DEMO WORKSPACE", color: Palette.amber)
            Text(L10n.text("Explore 28 sample trades. Your real journal stays separate.")).font(.system(size: 11)).foregroundStyle(Palette.muted)
            Spacer(minLength: 8)
            Button(L10n.text("Start My Journal"), action: startJournal).buttonStyle(EdgeButtonStyle(prominent: false))
        }.padding(.horizontal, 28).padding(.vertical, 10).background(Palette.amber.opacity(0.045))
    }
    @ViewBuilder private var content: some View {
        switch page {
        case .accounts: AccountRiskView()
        case .research: ResearchLabView(openTrade: openTrade)
        case .quant: QuantView()
        case .planning: PlanningView()
        case .dataImport: CSVImportView()
        case .dashboard: DashboardView(openTrade: openTrade, newTrade: { activeSheet = .tradeEditor(EditorRoute()) }, openDemo: openDemo)
        case .trades, .newTrade: TradesView(initialQuery: globalQuery, openTrade: openTrade, newTrade: { activeSheet = .tradeEditor(EditorRoute()) })
        case .calendar: CalendarView(openTrade: openTrade)
        case .analytics: AnalyticsView(mode: .analytics, openPlaybook: openPlaybook)
        case .setups: AnalyticsView(mode: .setups, openPlaybook: openPlaybook)
        case .statistics: AnalyticsView(mode: .statistics, openPlaybook: openPlaybook)
        case .mistakes: MistakesView()
        case .playbook: PlaybookView(openPlaybook: openPlaybook)
        case .screenshots: ScreenshotLibraryView(openTrade: openTrade)
        case .review: ReviewsView()
        case .settings: SettingsView(openDemo: openDemo)
        }
    }
    private func openTrade(_ record: TradeRecord) { activeSheet = .tradeDetail(DetailRoute(id: record.id)) }
    private func openPlaybook(_ draft: PlaybookDraft) { activeSheet = .playbookEditor(draft) }
    private func showSearch() { globalQuery = ""; activeSheet = .commandPalette }
    private var matchingPages: [JournalPage] {
        JournalPage.allCases.filter { globalQuery.isEmpty || $0.rawValue.localizedCaseInsensitiveContains(globalQuery) || L10n.text($0.rawValue).localizedCaseInsensitiveContains(globalQuery) }
    }
    private var matchingTrades: [TradeRecord] {
        let prepared = TradeSearch.PreparedQuery(globalQuery)
        return store.scopedTrades.filter { prepared.matches($0) }
    }
    private func submitSearch() {
        if let item = matchingPages.first {
            activeSheet = nil
            if item == .newTrade { DispatchQueue.main.async { activeSheet = .tradeEditor(EditorRoute()) } }
            else { page = item }
        } else if let trade = matchingTrades.first {
            activeSheet = nil
            DispatchQueue.main.async { openTrade(trade) }
        }
    }
    private var commandPalette: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    Text("KOMUT MERKEZİ").font(EdgeType.eyebrow).tracking(1.4).foregroundStyle(Palette.muted)
                    Spacer()
                    Button { activeSheet = nil } label: { Text("esc").font(.system(size: 10, design: .monospaced)) }
                        .buttonStyle(EdgeButtonStyle(prominent: false, compact: true)).keyboardShortcut(.cancelAction).help(L10n.text("Close")).accessibilityLabel(L10n.text("Close"))
                }
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass").font(.system(size: 18, weight: .regular)).foregroundStyle(Palette.mint)
                    TextField(L10n.text("Search trades or jump to a page…"), text: $globalQuery).textFieldStyle(.plain).font(.system(size: 16)).focused($searchFocused).onSubmit(submitSearch)
                }.padding(14).background(Palette.field, in: RoundedRectangle(cornerRadius: 11))
                    .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(searchFocused ? Palette.mint.opacity(0.45) : Palette.line))
            }.padding(22)
            Rectangle().fill(Palette.line.opacity(0.7)).frame(height: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 5) {
                    if !matchingPages.isEmpty {
                        Text("SAYFALAR VE KOMUTLAR").font(EdgeType.eyebrow).tracking(1.3).foregroundStyle(Palette.muted).padding(.horizontal, 12).padding(.bottom, 8)
                        ForEach(matchingPages) { item in
                            Button {
                                activeSheet = nil
                                if item == .newTrade { DispatchQueue.main.async { activeSheet = .tradeEditor(EditorRoute()) } } else { page = item }
                            } label: {
                                HStack(spacing: 12) { Image(systemName: item.icon).frame(width: 19).foregroundStyle(Palette.mint); Text(L10n.text(item.rawValue)); Spacer(); Image(systemName: "return").font(.system(size: 10)).foregroundStyle(Palette.muted) }.font(.system(size: 13)).padding(12)
                            }.buttonStyle(NavigationButtonStyle())
                        }
                    }
                    if !matchingTrades.isEmpty {
                        Text(globalQuery.isEmpty ? "SON İŞLEMLER" : "EŞLEŞEN İŞLEMLER").font(EdgeType.eyebrow).tracking(1.3).foregroundStyle(Palette.muted).padding(.horizontal, 12).padding(.top, 15).padding(.bottom, 8)
                        ForEach(Array(matchingTrades.prefix(globalQuery.isEmpty ? 6 : 30))) { trade in
                            Button { activeSheet = nil; DispatchQueue.main.async { openTrade(trade) } } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: trade.direction == "Long" ? "arrow.up.right" : "arrow.down.right").foregroundStyle(trade.direction == "Long" ? Palette.mint : Palette.red).frame(width: 19)
                                    VStack(alignment: .leading, spacing: 4) { Text(verbatim: trade.instrument).fontWeight(.semibold); Text(trade.setupID == nil ? L10n.text(trade.setupName) : trade.setupName).font(.system(size: 10)).foregroundStyle(Palette.muted) }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 4) {
                                        HStack(spacing: 8) {
                                            Text(verbatim: Format.money(trade.netPnL, currency: store.currency(for: trade.id))).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(Palette.outcome(trade.netPnL))
                                            Text(Format.r(trade.rMultiple)).font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(Palette.outcome(trade.rMultiple ?? 0))
                                        }.monospacedDigit()
                                        Text(Format.date(trade.date, calendar: store.preferences.calendar)).font(.system(size: 10)).foregroundStyle(Palette.muted)
                                    }
                                }.font(.system(size: 13)).padding(12)
                            }.buttonStyle(NavigationButtonStyle())
                        }
                    }
                    if matchingPages.isEmpty && matchingTrades.isEmpty {
                        EmptyJournal(title: "Sonuç bulunamadı", subtitle: "Enstrüman, strateji, not veya sayfa adıyla tekrar arayın.")
                    }
                }.padding(16)
            }
            Rectangle().fill(Palette.line.opacity(0.7)).frame(height: 1)
            HStack {
                Text("↵ Aç    esc Kapat").font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.muted)
                Spacer()
                Button(L10n.text("Show all matching trades")) { page = .trades; activeSheet = nil }.buttonStyle(EdgeButtonStyle(prominent: false))
            }.padding(16).background(Palette.field.opacity(0.55))
        }.frame(width: 680, height: 580).background(Palette.panel).foregroundStyle(Palette.ink).onAppear { searchFocused = true }
    }
}
