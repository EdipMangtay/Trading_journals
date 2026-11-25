import SwiftUI
import AppKit

/// Native AppKit macOS Menu Bar controller using NSStatusBar + NSPopover.
/// Immune to SwiftUI MenuBarExtraHost infinite layout loops on macOS 15–27, starts in < 1 ms,
/// uses ~0% background CPU (tears down hosting view on popover close), and respects Settings toggles live.
@MainActor final class MenuBarController: NSObject, NSPopoverDelegate {
    static let enabledKey = "journal.menubar.enabled"
    static let compactKey = "journal.menubar.compact"

    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var refreshTimer: Timer?
    private var defaultsObserver: NSObjectProtocol?

    private var storeProvider: (@MainActor () -> JournalStore?)?
    private var openMainWindowAction: (@MainActor () -> Void)?
    private var openNewTradeAction: (@MainActor () -> Void)?
    private var openDailyPlanAction: (@MainActor () -> Void)?
    private var openCommandPaletteAction: (@MainActor () -> Void)?

    private var lastTitle: String?
    private var lastSymbolName: String?

    var isEnabled: Bool {
        if UserDefaults.standard.object(forKey: Self.enabledKey) == nil { return true }
        return UserDefaults.standard.bool(forKey: Self.enabledKey)
    }

    var isCompact: Bool {
        UserDefaults.standard.bool(forKey: Self.compactKey)
    }

    override init() {
        super.init()
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
    }

    func attach(
        storeProvider: @escaping @MainActor () -> JournalStore?,
        openMainWindow: @escaping @MainActor () -> Void,
        openNewTrade: @escaping @MainActor () -> Void,
        openDailyPlan: @escaping @MainActor () -> Void,
        openCommandPalette: @escaping @MainActor () -> Void
    ) {
        self.storeProvider = storeProvider
        self.openMainWindowAction = openMainWindow
        self.openNewTradeAction = openNewTrade
        self.openDailyPlanAction = openDailyPlan
        self.openCommandPaletteAction = openCommandPalette

        if defaultsObserver == nil {
            defaultsObserver = NotificationCenter.default.addObserver(
                forName: UserDefaults.didChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.syncVisibilityAndStatus()
                }
            }
        }
        syncVisibilityAndStatus()
    }

    func syncVisibilityAndStatus() {
        if isEnabled {
            ensureStatusItemInstalled()
            updateStatusButton(at: Date())
            startTimerIfNeeded()
        } else {
            tearDownStatusItem()
        }
    }

    func formattedStatus(at date: Date = Date()) -> (title: String, symbolName: String) {
        guard let store = storeProvider?() else {
            return ("Liquidity Edge", "waveform.path.ecg")
        }
        let clock = KillzoneClockEngine.snapshot(at: date, preferences: store.preferences)
        let regime = store.scopedMLInsights.regime
        let title = clock.menuBarLabel(
            riskMultiplier: regime.riskMultiplier,
            regimeState: regime.state,
            compact: isCompact
        )
        let symbol: String
        if clock.isWeekendClosed {
            symbol = "moon.stars"
        } else {
            switch regime.state {
            case .regimeDrift: symbol = "exclamationmark.triangle"
            case .hotEdge: symbol = clock.isInKillzone ? "bolt.circle.fill" : "waveform.path.ecg"
            case .coldVariance: symbol = "shield.lefthalf.filled"
            case .stable: symbol = clock.isInKillzone ? "waveform.path.ecg" : "clock"
            }
        }
        return (title, symbol)
    }

    private func ensureStatusItemInstalled() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.imagePosition = .imageLeading
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "LIQUIDITY EDGE — Canlı Killzone & AI Rejim Asistanı"
        }
        statusItem = item
        lastTitle = nil
        lastSymbolName = nil
    }

    func tearDownStatusItem() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        if popover.isShown { popover.performClose(nil) }
        popover.contentViewController = nil
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
        lastTitle = nil
        lastSymbolName = nil
    }

    func detach() {
        tearDownStatusItem()
        if let observer = defaultsObserver {
            NotificationCenter.default.removeObserver(observer)
            defaultsObserver = nil
        }
    }

    private func startTimerIfNeeded() {
        guard refreshTimer == nil else { return }
        let timer = Timer(timeInterval: 15.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateStatusButton(at: Date())
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    func updateStatusButton(at date: Date = Date()) {
        guard let button = statusItem?.button else { return }
        let status = formattedStatus(at: date)
        if status.symbolName != lastSymbolName {
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
            let image = NSImage(systemSymbolName: status.symbolName, accessibilityDescription: "Liquidity Edge")?.withSymbolConfiguration(config)
            image?.isTemplate = true
            button.image = image
            lastSymbolName = status.symbolName
        }
        if status.title != lastTitle {
            let font = NSFont.monospacedDigitSystemFont(ofSize: 11.5, weight: .medium)
            button.attributedTitle = NSAttributedString(
                string: " " + status.title,
                attributes: [.font: font]
            )
            lastTitle = status.title
        }
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(sender)
            return
        }
        updateStatusButton(at: Date())
        let rootView: AnyView
        if let store = storeProvider?() {
            let theme = store.preferences.theme
            let scheme: ColorScheme? = theme == "System" ? nil : (theme == "Light" ? .light : .dark)
            rootView = AnyView(
                MenuBarAssistantView(
                    openMainWindow: { [weak self] in
                        self?.popover.performClose(nil)
                        self?.openMainWindowAction?()
                    },
                    openNewTrade: { [weak self] in
                        self?.popover.performClose(nil)
                        self?.openNewTradeAction?()
                    },
                    openDailyPlan: { [weak self] in
                        self?.popover.performClose(nil)
                        self?.openDailyPlanAction?()
                    },
                    openCommandPalette: { [weak self] in
                        self?.popover.performClose(nil)
                        self?.openCommandPaletteAction?()
                    }
                )
                .environment(store)
                .environment(\.locale, L10n.locale)
                .preferredColorScheme(scheme)
            )
        } else {
            rootView = AnyView(
                VStack(spacing: 10) {
                    Text("LIQUIDITY EDGE").font(.headline)
                    Button("Uygulamayı Aç") { [weak self] in
                        self?.popover.performClose(nil)
                        self?.openMainWindowAction?()
                    }
                    .buttonStyle(EdgeButtonStyle(compact: true))
                }
                .padding(16)
                .frame(width: 240)
            )
        }

        let host = NSHostingController(rootView: rootView)
        popover.contentViewController = host
        let fitting = host.sizeThatFits(in: CGSize(width: 392, height: 680))
        popover.contentSize = NSSize(width: 392, height: max(540, min(640, fitting.height)))
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    func popoverDidClose(_ notification: Notification) {
        // Release the hosting controller when closed so 1s TimelineView stops ticking (0% idle CPU)
        popover.contentViewController = nil
        updateStatusButton(at: Date())
    }
}

/// Compact live status label preview component (used in tests and compact embeds).
struct MenuBarStatusLabel: View {
    @Environment(JournalStore.self) private var store
    @AppStorage("journal.menubar.compact") private var compactLabel = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 15.0)) { context in
            let clock = KillzoneClockEngine.snapshot(at: context.date, preferences: store.preferences)
            let regime = store.scopedMLInsights.regime
            let labelText = clock.menuBarLabel(
                riskMultiplier: regime.riskMultiplier,
                regimeState: regime.state,
                compact: compactLabel
            )
            HStack(spacing: 5) {
                Image(systemName: iconName(clock: clock, regime: regime.state))
                    .symbolRenderingMode(.hierarchical)
                Text(labelText)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
            }
        }
    }

    private func iconName(clock: KillzoneClockEngine.ClockSnapshot, regime: EdgeMLEngine.RegimeState) -> String {
        if clock.isWeekendClosed { return "moon.stars" }
        switch regime {
        case .regimeDrift: return "exclamationmark.triangle"
        case .hotEdge: return clock.isInKillzone ? "bolt.circle.fill" : "waveform.path.ecg"
        case .coldVariance: return "shield.lefthalf.filled"
        case .stable: return clock.isInKillzone ? "waveform.path.ecg" : "clock"
        }
    }
}

/// Interactive macOS Menu Bar popover assistant showing:
/// 1. Live Killzone countdown & Quarterly Theory (Q1–Q4 Daily / 90m Micro / 22.5m Sub) phase tracker
/// 2. Real-time On-Device AI Regime (CUSUM), Risk Multiplier (1.10x / 1.00x / 0.75x / 0.50x), AUC & Tilt status
/// 3. Inline Quick Seans/Disiplin Note input that appends directly to today's DailyPlan on disk
/// 4. Instant actions: New Trade, Daily Plan, AI Coach (⌘K), Open Main Window
struct MenuBarAssistantView: View {
    @Environment(JournalStore.self) private var store
    @AppStorage("journal.menubar.compact") private var compactLabel = false

    var openMainWindow: () -> Void
    var openNewTrade: () -> Void
    var openDailyPlan: () -> Void
    var openCommandPalette: () -> Void

    @State private var quickNote = ""
    @State private var noteConfirmation: String?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let clock = KillzoneClockEngine.snapshot(at: context.date, preferences: store.preferences)
            let ml = store.scopedMLInsights
            let regime = ml.regime
            let tilt = ml.tilt
            let todayBrief = EdgeMLEngine.generateDailyPlanBriefing(
                for: context.date,
                account: store.selectedAccount,
                trades: store.scopedTrades,
                setups: store.setups,
                risk: store.scopedRisk,
                calendar: store.preferences.calendar
            )

            VStack(alignment: .leading, spacing: 12) {
                headerStrip(clock: clock)
                killzoneAndQuarterlyCard(clock: clock)
                aiRegimeAndDailyCard(regime: regime, tilt: tilt, validation: ml.validation, brief: todayBrief)
                quickNoteCard(clock: clock)
                quickActionsFooter
            }
            .padding(14)
            .frame(width: 392)
            .background(Palette.canvas)
            .foregroundStyle(Palette.ink)
            .tint(Palette.mint)
        }
    }

    // MARK: - Section 1: Header

    private func headerStrip(clock: KillzoneClockEngine.ClockSnapshot) -> some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Palette.mint.opacity(0.14))
                    .frame(width: 30, height: 30)
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Palette.mint.opacity(0.32), lineWidth: 0.9))
                Image(systemName: "waveform.path")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.mint)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("LIQUIDITY EDGE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1.4)
                    Badge(text: store.selectedAccount.name, color: Palette.blue)
                }
                Text("\(clock.tradingTimeFormatted) \(clock.timezoneAbbreviation)  ·  \(clock.nyTimeFormatted)")
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(Palette.muted)
            }

            Spacer(minLength: 4)

            Button {
                compactLabel.toggle()
            } label: {
                Image(systemName: compactLabel ? "text.badge.plus" : "text.badge.minus")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.muted)
                    .frame(width: 26, height: 26)
                    .background(Palette.panel, in: RoundedRectangle(cornerRadius: 7))
                    .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Palette.line.opacity(0.8), lineWidth: 0.8))
            }
            .buttonStyle(.plain)
            .help(compactLabel ? "Üst çubukta tam Killzone etiketi göster" : "Üst çubuğu sadeleştir")
        }
    }

    // MARK: - Section 2: Live Killzone & Quarterly Theory (Q1–Q4)

    private func killzoneAndQuarterlyCard(clock: KillzoneClockEngine.ClockSnapshot) -> some View {
        let activeColor: Color = clock.isWeekendClosed ? Palette.muted : (clock.isInKillzone ? Palette.mint : Palette.blue)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(activeColor)
                        .frame(width: 7, height: 7)
                        .shadow(color: activeColor.opacity(0.65), radius: 3)
                    Text(clock.isWeekendClosed ? "HAFTA SONU KAPALI" : (clock.isInKillzone ? "AKTİF KİLLZONE" : "SONRAKİ KİLLZONE"))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1.1)
                        .foregroundStyle(activeColor)
                }
                Spacer()
                Text(clock.trueOpenStatus)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Palette.muted)
            }

            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(clock.isInKillzone ? L10n.text(clock.activeSessionName ?? "Killzone") : L10n.text(clock.nextSessionName ?? "Seans Bekleniyor"))
                        .font(.system(size: 17, weight: .bold))
                        .tracking(-0.3)
                    if let hours = clock.isInKillzone ? clock.activeSessionHours : clock.nextSessionHours {
                        Text(hours)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Palette.muted)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(KillzoneClockEngine.formatCountdown(clock.isInKillzone ? clock.activeRemainingSeconds : clock.secondsUntilNextSession))
                        .font(.system(size: 19, weight: .bold, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(activeColor)
                    Text(clock.isInKillzone ? "bitime kalan" : "başlangıca kalan")
                        .font(.system(size: 9))
                        .foregroundStyle(Palette.muted)
                }
            }

            // Active Killzone or 90m Micro Quarter progress bar
            GeometryReader { geo in
                let progress = clock.isInKillzone ? clock.activeProgress : clock.microQuarter.progress
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.line.opacity(0.55))
                    Capsule()
                        .fill(LinearGradient(colors: [activeColor, activeColor.opacity(0.65)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(6, geo.size.width * CGFloat(progress)))
                }
            }
            .frame(height: 5)

            // 3-Column Quarterly Theory Live Strip (Daily 6h, 90m Micro, 22.5m Sub)
            HStack(spacing: 8) {
                quarterPill(
                    title: "6S FAZ",
                    code: clock.dailyQuarter.code,
                    detail: clock.dailyQuarter.shortLabel,
                    countdown: KillzoneClockEngine.formatShortCountdown(clock.dailyQuarter.remainingSeconds),
                    accent: quarterColor(clock.dailyQuarter.code)
                )
                quarterPill(
                    title: "90DK",
                    code: clock.microQuarter.code,
                    detail: clock.microQuarter.shortLabel,
                    countdown: KillzoneClockEngine.formatCountdown(clock.microQuarter.remainingSeconds),
                    accent: quarterColor(clock.microQuarter.code)
                )
                quarterPill(
                    title: "22.5DK",
                    code: clock.subQuarterCode,
                    detail: "Giriş",
                    countdown: "NY QT",
                    accent: Palette.cyan
                )
            }
        }
        .padding(12)
        .background(Palette.panelGradient, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(activeColor.opacity(0.32), lineWidth: 1))
    }

    private func quarterPill(title: String, code: String, detail: String, countdown: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 3) {
                Text(title)
                    .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(1)
                Spacer(minLength: 2)
                Text(countdown)
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(accent)
                    .lineLimit(1)
            }
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(code)
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .foregroundStyle(accent)
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Palette.ink.opacity(0.88))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.field.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(accent.opacity(0.24), lineWidth: 0.8))
    }

    private func quarterColor(_ code: String) -> Color {
        switch code {
        case "Q1": return Palette.muted
        case "Q2": return Palette.amber
        case "Q3": return Palette.mint
        default: return Palette.blue
        }
    }

    // MARK: - Section 3: AI Regime, Risk Multiplier & Today Telemetry

    private func aiRegimeAndDailyCard(
        regime: EdgeMLEngine.RegimeReport,
        tilt: EdgeMLEngine.TiltReport,
        validation: EdgeMLEngine.ModelValidationReport,
        brief: EdgeMLEngine.AIDailyPlanBriefing
    ) -> some View {
        let regimeColor: Color = {
            switch regime.state {
            case .hotEdge: return Palette.mint
            case .stable: return Palette.blue
            case .coldVariance: return Palette.amber
            case .regimeDrift: return Palette.red
            }
        }()
        let tiltColor: Color = tilt.level == .elevated ? Palette.red : tilt.level == .caution ? Palette.amber : Palette.mint
        let todayPnL = store.scopedTodayPnL

        return VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI REJİM & RİSK ÇARPANI")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(Palette.muted)
                    Text(regime.state.rawValue)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(regimeColor)
                }
                Spacer()
                Text(String(format: "%.2fx", regime.riskMultiplier))
                    .font(.system(size: 16, weight: .heavy, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(regimeColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(regimeColor.opacity(0.14), in: Capsule())
                    .overlay(Capsule().strokeBorder(regimeColor.opacity(0.38), lineWidth: 0.9))
            }

            HStack(spacing: 8) {
                miniStat(
                    title: "KELLY RİSK",
                    value: Format.percent(brief.recommendedRiskPercent),
                    color: Palette.mint
                )
                miniStat(
                    title: "BUGÜN (\(store.scopedRisk.todayCount))",
                    value: (todayPnL > 0 ? "+" : "") + Format.money(todayPnL, currency: store.accountCurrency),
                    color: Palette.outcome(todayPnL)
                )
                miniStat(
                    title: "TİLT",
                    value: "\(tilt.score)/100",
                    color: tiltColor
                )
                miniStat(
                    title: "OOS AUC",
                    value: validation.isReady ? String(format: "%.2f", validation.rocAUC) : "—",
                    color: validation.isReady ? Palette.blue : Palette.muted
                )
            }

            Text(regime.advice)
                .font(.system(size: 10.5))
                .foregroundStyle(Palette.muted)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Palette.panelGradient, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(regimeColor.opacity(0.28), lineWidth: 1))
    }

    private func miniStat(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                .foregroundStyle(Palette.muted)
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.field.opacity(0.7), in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Palette.line.opacity(0.65), lineWidth: 0.7))
    }

    // MARK: - Section 4: Inline Quick Note (Appends to Today's Daily Plan)

    private func quickNoteCard(clock: KillzoneClockEngine.ClockSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Label("HIZLI SEANS / DİSİPLİN NOTU", systemImage: "square.and.pencil")
                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(Palette.muted)
                Spacer()
                if let noteConfirmation {
                    Text(noteConfirmation)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(Palette.mint)
                }
            }

            HStack(spacing: 8) {
                TextField("Örn: NQ BSL süpürüldü, Q3 teyidi bekleniyor…", text: $quickNote)
                    .textFieldStyle(EdgeTextFieldStyle())
                    .font(.system(size: 11.5))
                    .onSubmit { submitQuickNote(clock: clock) }

                Button {
                    submitQuickNote(clock: clock)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 16))
                }
                .buttonStyle(EdgeButtonStyle(compact: true))
                .disabled(quickNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help("Bugünkü günlük plana ekle")
            }
        }
        .padding(11)
        .background(Palette.panel.opacity(0.78), in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Palette.line.opacity(0.7), lineWidth: 0.8))
    }

    private func submitQuickNote(clock: KillzoneClockEngine.ClockSnapshot) {
        let saved = Self.appendQuickNote(quickNote, into: store, at: clock.now, clock: clock)
        if saved {
            quickNote = ""
            noteConfirmation = "Bugünkü plana kaydedildi ✓"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                noteConfirmation = nil
            }
        }
    }

    /// Appends a timestamped quick observation directly into today's DailyPlan for the active account.
    @MainActor @discardableResult
    static func appendQuickNote(
        _ rawText: String,
        into store: JournalStore,
        at date: Date = Date(),
        clock: KillzoneClockEngine.ClockSnapshot? = nil
    ) -> Bool {
        let cleaned = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return false }

        let snapshot = clock ?? KillzoneClockEngine.snapshot(at: date, preferences: store.preferences)
        let cal = store.preferences.calendar
        let accountID = store.selectedAccount.id
        let sessionTag = snapshot.activeSessionName ?? snapshot.dailyQuarter.code
        let stamp = "[\(snapshot.tradingTimeFormatted.prefix(5)) · \(sessionTag) \(snapshot.microQuarter.code)] \(cleaned)"

        do {
            try store.updateWorkspace { ws in
                if let idx = ws.plans.firstIndex(where: { $0.accountID == accountID && cal.isDate($0.date, inSameDayAs: date) }) {
                    let existing = ws.plans[idx].scenarios.trimmingCharacters(in: .whitespacesAndNewlines)
                    ws.plans[idx].scenarios = existing.isEmpty ? stamp : "\(existing)\n\(stamp)"
                } else {
                    var plan = DailyPlan(accountID: accountID, date: date)
                    plan.scenarios = stamp
                    ws.plans.append(plan)
                }
            }
            return true
        } catch {
            store.report(error)
            return false
        }
    }

    // MARK: - Section 5: Quick Shortcuts Footer

    private var quickActionsFooter: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button(action: openNewTrade) {
                    Label("Yeni İşlem", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(EdgeButtonStyle(compact: true))

                Button(action: openDailyPlan) {
                    Label("Günlük Plan", systemImage: "checklist")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(EdgeButtonStyle(prominent: false, compact: true))
            }

            HStack(spacing: 8) {
                Button(action: openCommandPalette) {
                    Label("AI Koç · ⌘K", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(EdgeButtonStyle(prominent: false, compact: true))

                Button(action: openMainWindow) {
                    Label("Uygulamayı Aç", systemImage: "macwindow")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(EdgeButtonStyle(prominent: false, compact: true))
            }

            Divider().overlay(Palette.line.opacity(0.6))

            HStack {
                Text("Arka planda canlı · %100 Yerel AI")
                    .font(.system(size: 9.5))
                    .foregroundStyle(Palette.muted)
                Spacer()
                Button("Çıkış") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Palette.muted)
            }
        }
    }
}

