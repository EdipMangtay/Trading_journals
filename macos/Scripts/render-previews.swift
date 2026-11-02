import SwiftUI
import AppKit

@main struct RenderPreviews {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        NSApp.appearance = NSAppearance(named: .darkAqua)
        let store = try JournalStore(demo: true)
        store.preferences.animations = false
        let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        func render<V: View>(_ name: String, _ view: V, width: CGFloat = 1440, height: CGFloat = 1000, workspace: JournalStore? = nil, scheme: ColorScheme = .dark) throws {
            NSApp.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
            let content = view.environment(workspace ?? store).environment(\.locale, L10n.locale).environment(\.edgeAnimationsEnabled, false).environment(\.colorScheme, scheme).environment(\.timeZone, store.preferences.calendar.timeZone).frame(width: width, height: height).background(Palette.canvas)
            let host = NSHostingView(rootView: content)
            host.frame = NSRect(x: 0, y: 0, width: width, height: height)
            host.layoutSubtreeIfNeeded()
            guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw JournalError(message: "Could not allocate \(name)") }
            host.cacheDisplay(in: host.bounds, to: bitmap)
            guard let data = bitmap.representation(using: .png, properties: [:]) else { throw JournalError(message: "Could not render \(name)") }
            try data.write(to: output.appendingPathComponent(name + ".png"))
            print("Rendered \(name)")
        }
        try render("scatter", TradeScatterChart(trades: store.trades).padding(24), width: 1060, height: 680)
        try render("scatter-light", TradeScatterChart(trades: store.trades).padding(24), width: 1060, height: 680, scheme: .light)
        try render("chart-hero", EquityChart(points: AnalyticsEngine.curve(store.trades), height: 310, presentation: .dashboard).padding(24), width: 1060, height: 360)
        try render("chart-companions", HStack(spacing: 18) { EquityChart(points: AnalyticsEngine.curve(store.trades), mode: .r, height: 220, presentation: .dashboard); EquityChart(points: AnalyticsEngine.curve(store.trades), mode: .drawdown, height: 220, presentation: .dashboard) }.padding(24), width: 1060, height: 270)
        try render("chart-groups", Panel(title: "Strateji karşılaştırması") { GroupBarChart(groups: AnalyticsEngine.groups(store.trades, by: .setup, calendar: store.preferences.calendar), metric: .pnl) }.padding(24), width: 1060, height: 410)
        try render("chart-heatmap", PerformanceHeatmap(trades: store.trades, calendar: store.preferences.calendar).padding(24), width: 1060, height: 520)
        try render("dashboard", RootView(startJournal: {}, openDemo: {}))
        try render("dashboard-compact", RootView(startJournal: {}, openDemo: {}), width: 1060, height: 760)
        let testFolder = FileManager.default.temporaryDirectory.appendingPathComponent("liquidityedge-preview-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: testFolder) }
        let empty = try JournalStore(demo: false, storageURL: testFolder.appendingPathComponent("Journal.store"))
        empty.preferences.animations = false
        try render("welcome", DashboardView(openTrade: { _ in }, newTrade: {}, openDemo: {}), width: 1060, height: 900, workspace: empty)
        try render("dashboard-light", DashboardView(openTrade: { _ in }, newTrade: {}), width: 1225, scheme: .light)
        try render("trades", TradesView(initialQuery: "", openTrade: { _ in }, newTrade: {}), width: 1060)
        try render("analytics", AnalyticsView(mode: .analytics), width: 1225)
        try render("calendar", CalendarView(openTrade: { _ in }), width: 1225)
        let chartImage = try Data(contentsOf: output.appendingPathComponent("chart-hero.png"))
        let visualFixture = ScreenshotDraft(name: "Grafik önizlemesi.png", category: "Entry", imageData: chartImage, thumbnailData: chartImage, annotations: [ImageAnnotation(kind: "Arrow", x: 0.2, y: 0.7, endX: 0.75, endY: 0.25)])
        try store.save(store.trades[0], screenshots: [visualFixture])
        try render("image-viewer", ScreenshotViewer(initial: visualFixture, onSave: { _ in }), width: 1250, height: 960)
        try render("review-editor", ReviewEditor(initial: ReviewDraft()), width: 980, height: 960)
        try render("playbook-editor", PlaybookEditor(initial: try PlaybookDraft(store.setups[0])), width: 980, height: 960)
        try render("settings-light", SettingsView(openDemo: {}), width: 1060, height: 1100, scheme: .light)
        try render("settings-local", SettingsView(openDemo: {}), width: 1225, height: 2400, workspace: empty)
        try render("trade-editor", TradeEditorView(record: store.trades.first), width: 960, height: 860)
        try render("trade-detail", TradeDetailView(tradeID: store.trades[0].id, edit: { _ in }), width: 1040, height: 860)
        try render("playbook", PlaybookView(), width: 1225)
        try render("reviews", ReviewsView(), width: 1225)
        try render("settings", SettingsView(openDemo: {}), width: 1225)
        try render("screenshots", ScreenshotLibraryView(openTrade: { _ in }), width: 1225)
        try render("mistakes", MistakesView(), width: 1225)
        try render("statistics", AnalyticsView(mode: .statistics), width: 1225)
        try render("research-lab", ResearchLabView(openTrade: { _ in }), width: 1225)
        try render("quant-lab", QuantView(), width: 1225)
        try render("planning", PlanningView(), width: 1225)
        try render("csv-import", CSVImportView(), width: 1225)
        try render("accounts-risk", AccountRiskView(), width: 1225)
    }
}
