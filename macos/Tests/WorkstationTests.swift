import XCTest
import SwiftData
@testable import LiquidityEdge

final class WorkstationTests: XCTestCase {
    func trades(_ outcomes: [Double]) -> [TradeRecord] {
        outcomes.enumerated().map { i, n in var t = TradeRecord(); t.grossPnL = n; t.date = Date(timeIntervalSince1970: Double(i) * 86400); t.exitDate = t.date.addingTimeInterval(3600); return t }
    }
    @MainActor func testV1MigrationPreservesPayloadRelationshipsAndAccountsAcrossRestart() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("V1.store")
        var t = trades([123.45])[0]; t.notes.lesson = "Legacy timestamps and manual R"; t.rMultiple = -0.25
        var original: Data!
        do {
            let schema = Schema(versionedSchema: JournalSchemaV1.self)
            let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none))
            let context = ModelContext(container)
            let setup = Setup(name: "CRT legacy"); let book = Playbook(); book.entryRules = "Wait"; setup.playbook = book
            t.setupID = setup.id; t.setupName = setup.name
            let model = try Trade(record: t); original = model.recordData; model.setup = setup
            context.insert(setup); context.insert(book); context.insert(model)
            let shot = TradeScreenshot(name: "fixture", category: "Entry", imageData: Data([1,2,3]), thumbnailData: Data([4]), annotationData: Data([5])); shot.trade = model; context.insert(shot)
            let review = Review(period: "Weekly", date: t.date); review.adjustment = "Preserve"; context.insert(review)
            try context.save()
        }
        do {
            let store = try JournalStore(demo: false, storageURL: url)
            XCTAssertEqual(store.trades, [t]); XCTAssertEqual(store.model(t.id)?.recordData, original)
            XCTAssertEqual(store.model(t.id)?.screenshots.first?.annotationData, Data([5]))
            XCTAssertEqual(store.setups.first?.playbook?.entryRules, "Wait")
            XCTAssertEqual(store.reviews.first?.adjustment, "Preserve")
            XCTAssertEqual(store.accountID(for: t.id), TradingAccount.legacyID)
            let account = TradingAccount(name: "Evaluation", currency: "EUR")
            try store.updateWorkspace { $0.accounts.append(account); $0.assignments[t.id] = account.id; $0.selectedAccountID = account.id }
            XCTAssertEqual(store.scopedTrades.count, 1)
            XCTAssertThrowsError(try store.updateWorkspace { $0.accounts.removeAll { $0.id == account.id } })
            XCTAssertEqual(store.workspace.accounts.count, 2)
        }
        let reopened = try JournalStore(demo: false, storageURL: url)
        XCTAssertEqual(reopened.scopedTrades, [t]); XCTAssertEqual(reopened.accountCurrency, "EUR")
    }
    @MainActor func testExtendedBackupAndLegacyImportPreserveNewMetadata() throws {
        let store = try JournalStore(demo: true), t = store.trades[0]
        var supplement = TradeSupplement(); supplement.checklist = [ChecklistAnswer(label: "Risk checked", answer: true)]
        try store.updateWorkspace { $0.supplements[t.id] = supplement; $0.presets.append(ResearchPreset(name: "CRT", filter: TradeFilter(query: "CRT"))) }
        let full = try BackupService.decode(BackupService.encode(BackupService.archive(store)))
        XCTAssertEqual(full.version, 2); XCTAssertEqual(full.workspace?.supplements[t.id], supplement)
        let legacy = try BackupService.decode(BackupService.encode(BackupService.archive(store, legacy: true)))
        XCTAssertEqual(legacy.version, 1); XCTAssertNil(legacy.workspace)
        try BackupService.restore(legacy, into: store)
        XCTAssertEqual(store.workspace.supplements[t.id], supplement)
        try BackupService.restore(full, into: store)
        XCTAssertEqual(store.workspace.presets.count, 1)
    }
    func testRiskStaticTrailingMissingExitAndDayBoundary() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(secondsFromGMT: 0)!
        var account = TradingAccount(startingBalance: 1000); account.rules.maximumLoss = 100; account.rules.dailyLoss = 50
        let ts = trades([100, -60, -50])
        let now = Date(timeIntervalSince1970: 2 * 86400 + 7200)
        let p = WorkstationAnalytics.risk(ts, account: account, calendar: cal, now: now)
        XCTAssertEqual(p.balance, 990); XCTAssertEqual(p.remaining, 90); XCTAssertEqual(p.dailyRemaining, 0); XCTAssertTrue(p.historicalBreach)
        account.rules.drawdownMethod = "End of day"
        XCTAssertEqual(WorkstationAnalytics.risk(ts, account: account, calendar: cal, now: now).floor, 1000)
        account.rules.drawdownMethod = "Intraday equity"
        let intra = WorkstationAnalytics.risk(ts, account: account, calendar: cal, now: now)
        XCTAssertNil(intra.floor); XCTAssertTrue(intra.unverified)
        var incomplete = ts; incomplete[0].exitDate = nil
        XCTAssertTrue(WorkstationAnalytics.risk(incomplete, account: account, calendar: cal, now: now).unverified)
    }
    func testScaleInOutFeesSlippageAndOverExit() throws {
        let date = Date(timeIntervalSince1970: 0)
        var s = TradeSupplement(); s.pointValue = 10
        s.fills = [ExecutionFill(date: date, quantity: 2, price: 100, fee: 2, expectedPrice: 99), ExecutionFill(date: date.addingTimeInterval(1), quantity: 1, price: 103, fee: 1), ExecutionFill(date: date.addingTimeInterval(2), side: "Exit", quantity: 2, price: 105, fee: 2)]
        let result = try WorkstationAnalytics.executions(s, direction: "Long")
        XCTAssertEqual(result.realized, 76, accuracy: 0.001); XCTAssertEqual(result.openQuantity, 1); XCTAssertEqual(result.slippageCost, 20)
        s.fills.append(ExecutionFill(date: date.addingTimeInterval(3), side: "Exit", quantity: 2, price: 105))
        XCTAssertThrowsError(try WorkstationAnalytics.executions(s, direction: "Long"))
        s.fills = [ExecutionFill(date: date, price: 100), ExecutionFill(date: date.addingTimeInterval(1), side: "Exit", price: 90)]
        XCTAssertEqual(try WorkstationAnalytics.executions(s, direction: "Short").realized, 100)
    }
    func testRollingDurationAndSeededResampling() {
        let ts = trades([100, -50, -25, 100])
        XCTAssertEqual(WorkstationAnalytics.rolling(ts, window: 2).last?.expectancy, 37.5)
        XCTAssertEqual(WorkstationAnalytics.underwater(ts).longestRecoveredSeconds, 3 * 86400)
        XCTAssertFalse(WorkstationAnalytics.underwater(ts).ongoing)
        XCTAssertTrue(WorkstationAnalytics.underwater(Array(ts.prefix(3))).ongoing)
        let a = WorkstationAnalytics.simulate(ts, runs: 100, horizon: 4, shuffle: true)!
        XCTAssertEqual(a.band.last?.low, 125); XCTAssertEqual(a.band.last?.high, 125)
        XCTAssertEqual(a.lossFraction, 0)
        let b = WorkstationAnalytics.simulate(ts, runs: 100, horizon: 4, shuffle: true)!
        XCTAssertEqual(a.drawdowns, b.drawdowns)
        XCTAssertNil(WorkstationAnalytics.simulate([]))
        XCTAssertEqual(WorkstationAnalytics.percentile([0, 100], 0.25), 25)
    }
}
