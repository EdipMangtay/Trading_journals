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
    func testQTNarrativeDefaultsAndLegacyTradeRecordDecoding() throws {
        var record = TradeRecord()
        record.bias = "Bearish"; record.direction = "Long"; record.biasRelation = "Counter-Trend"
        record.narrative = "London SSL sweep -> NY AM Q3 ERL"
        record.newsDriver = "Post-News"
        record.qt.enabled = true; record.qt.profile = "XAMD"; record.qt.trueOpenAnchor = "T90O"; record.qt.trueOpenLocation = "Discount"
        let encoded = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(TradeRecord.self, from: encoded)
        XCTAssertEqual(decoded, record)
        XCTAssertTrue(TradeSearch.matches(decoded, query: "counter-trend xamd t90o"))
        // Simulate legacy V1 JSON missing new QT/Narrative keys
        var object = try XCTUnwrap(try JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "narrative"); object.removeValue(forKey: "biasRelation"); object.removeValue(forKey: "newsDriver")
        if var qt = object["qt"] as? [String: Any] {
            qt.removeValue(forKey: "profile"); qt.removeValue(forKey: "trueOpenAnchor"); qt.removeValue(forKey: "trueOpenLocation")
            object["qt"] = qt
        }
        let legacyData = try JSONSerialization.data(withJSONObject: object)
        let legacyDecoded = try JSONDecoder().decode(TradeRecord.self, from: legacyData)
        XCTAssertEqual(legacyDecoded.narrative, "")
        XCTAssertEqual(legacyDecoded.biasRelation, "Pro-Trend")
        XCTAssertEqual(legacyDecoded.newsDriver, "Clean")
        XCTAssertEqual(legacyDecoded.qt.profile, "AMDX")
        XCTAssertEqual(legacyDecoded.qt.trueOpenAnchor, "TDO")
        XCTAssertEqual(legacyDecoded.qt.trueOpenLocation, "Discount")
    }
    @MainActor func testFullEndToEndWorkspaceAndPlaybookCRUD() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("CRUD.store")
        let store = try JournalStore(demo: false, storageURL: url)

        // 1. Create Setup + Playbook
        let setupID = UUID()
        try store.commit {
            let setup = Setup(id: setupID, name: "NY AM QT", summary: "AMDX Q3 CISD")
            store.context.insert(setup)
            let book = Playbook()
            book.conditions = "HTF DOL + Q2 Sweep"
            book.entryRules = "1M CISD + FVG"
            book.idealImagesData = try JSONEncoder().encode([ScreenshotDraft]())
            store.context.insert(book)
            setup.playbook = book
        }
        XCTAssertEqual(store.setups.count, 1)
        XCTAssertEqual(store.setups[0].playbook?.entryRules, "1M CISD + FVG")

        // 2. Create Trade linked to Setup via saveBatch
        var t1 = TradeRecord(); t1.instrument = "NQ"; t1.grossPnL = 400; t1.rMultiple = 2.0; t1.setupID = setupID; t1.setupName = "NY AM QT"
        var t2 = TradeRecord(); t2.instrument = "ES"; t2.grossPnL = -200; t2.rMultiple = -1.0; t2.setupID = setupID; t2.setupName = "NY AM QT"
        try store.saveBatch([t1, t2], accountID: TradingAccount.legacyID)
        XCTAssertEqual(store.trades.count, 2)
        XCTAssertEqual(store.scopedPerformance.netPnL, 200)

        // 3. Edit existing Setup without double-inserting and verify linked trades rename
        try store.commit {
            let existing = try XCTUnwrap(store.setups.first { $0.id == setupID })
            existing.name = "NY AM QT v2"
            existing.playbook?.conditions = "Updated conditions"
            for trade in store.trades where trade.setupID == setupID {
                var changed = trade; changed.setupName = "NY AM QT v2"; try store.upsert(changed)
            }
        }
        XCTAssertEqual(store.setups.count, 1)
        XCTAssertEqual(store.setups[0].name, "NY AM QT v2")
        XCTAssertTrue(store.trades.allSatisfy { $0.setupName == "NY AM QT v2" })

        // 4. Create & Edit Review without double-insert
        let reviewID = UUID()
        try store.commit {
            let review = Review(id: reviewID, period: "Weekly", date: Date())
            review.adjustment = "Wait for Q3"
            store.context.insert(review)
        }
        try store.commit {
            let review = try XCTUnwrap(store.reviews.first { $0.id == reviewID })
            review.adjustment = "Wait for Q3 + SSMT"
        }
        XCTAssertEqual(store.reviews.count, 1)
        XCTAssertEqual(store.reviews[0].adjustment, "Wait for Q3 + SSMT")

        // 5. Daily Plan, Checklist Template, Research Preset, and Trade Supplement
        var plan = DailyPlan(accountID: TradingAccount.legacyID); plan.scenarios = "Bearish below TDO"
        let tmpl = ChecklistTemplate(name: "QT Check", items: [ChecklistAnswer(label: "True Open", phase: "Öncesi")])
        let preset = ResearchPreset(name: "NQ Only", filter: TradeFilter(query: "NQ"))
        var supp = TradeSupplement(); supp.fills = [ExecutionFill(side: "Entry", quantity: 1, price: 20000), ExecutionFill(side: "Exit", quantity: 1, price: 20020)]
        try store.updateWorkspace { ws in
            ws.plans.append(plan); ws.templates.append(tmpl); ws.presets.append(preset); ws.supplements[t1.id] = supp
        }

        // 6. Reopen from disk and verify everything survived
        let reopened = try JournalStore(demo: false, storageURL: url)
        XCTAssertEqual(reopened.setups.count, 1)
        XCTAssertEqual(reopened.setups[0].name, "NY AM QT v2")
        XCTAssertEqual(reopened.setups[0].playbook?.conditions, "Updated conditions")
        XCTAssertEqual(reopened.trades.count, 2)
        XCTAssertEqual(reopened.reviews.first?.adjustment, "Wait for Q3 + SSMT")
        XCTAssertEqual(reopened.workspace.plans.count, 1)
        XCTAssertEqual(reopened.workspace.templates.count, 1)
        XCTAssertEqual(reopened.workspace.presets.count, 1)
        XCTAssertEqual(reopened.workspace.supplements[t1.id]?.fills.count, 2)

        // 7. Delete setup cleanly unassigns linked trades
        try reopened.deleteSetup(reopened.setups[0])
        XCTAssertEqual(reopened.setups.count, 0)
        XCTAssertTrue(reopened.trades.allSatisfy { $0.setupID == nil && $0.setupName == "Unassigned" })

        // 8. Flexible minimal trade with deselected optional fields validates, saves, and groups cleanly
        var minimal = TradeRecord()
        minimal.instrument = "NQ"
        minimal.session = ""
        minimal.grade = ""
        minimal.biasRelation = ""
        minimal.newsDriver = ""
        minimal.entryTimeframe = ""
        minimal.rMultiple = nil
        minimal.riskDollars = nil
        minimal.riskPercent = nil
        minimal.qt.enabled = false
        XCTAssertNil(minimal.validationError)
        try reopened.save(minimal, screenshots: [])
        XCTAssertEqual(AnalyticsEngine.groups([minimal], by: .session, calendar: .current).first?.name, "Unspecified")
        XCTAssertEqual(AnalyticsEngine.groups([minimal], by: .grade, calendar: .current).first?.name, "Unspecified")
        XCTAssertEqual(AnalyticsEngine.groups([minimal], by: .timeframe, calendar: .current).first?.name, "Unspecified")
    }
}
