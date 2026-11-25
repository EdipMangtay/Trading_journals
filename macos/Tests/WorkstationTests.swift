import XCTest
import SwiftData
import SwiftUI
import AppKit
import PDFKit
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

    func testParallelMonteCarloAndVectorizedAnalyticsAccuracy() throws {
        var sample: [TradeRecord] = []
        let pattern: [Double] = [320, -150, 480, -140, 210, 610, -180, 95, -160, 420]
        for i in 0..<200 {
            var t = TradeRecord()
            t.grossPnL = pattern[i % pattern.count]
            t.rMultiple = t.grossPnL / 150.0
            t.date = Date(timeIntervalSince1970: Double(i) * 3600)
            t.exitDate = t.date.addingTimeInterval(1800)
            if i % 7 == 0 { t.brokenRules = ["Chased entry"] }
            sample.append(t)
        }
        // Multi-core Monte Carlo must be 100% deterministic for identical seed
        let simA = try XCTUnwrap(WorkstationAnalytics.simulate(sample, runs: 1500, horizon: 200, shuffle: false, seed: 42))
        let simB = try XCTUnwrap(WorkstationAnalytics.simulate(sample, runs: 1500, horizon: 200, shuffle: false, seed: 42))
        XCTAssertEqual(simA.band.count, 201)
        XCTAssertEqual(simA.drawdowns, simB.drawdowns)
        XCTAssertEqual(simA.lossFraction, simB.lossFraction)
        XCTAssertEqual(simA.band.last?.median, simB.band.last?.median)
        XCTAssertLessThan(simA.computeDurationMs, 500)

        // O(N) sliding window rolling expectancy & compliance match exact manual slice
        let rolling = WorkstationAnalytics.rolling(sample, window: 20)
        XCTAssertEqual(rolling.count, 200)
        let refWindow = Array(sample[180..<200])
        let refPerf = AnalyticsEngine.performance(refWindow)
        XCTAssertEqual(rolling.last?.expectancy ?? 0, refPerf.expectancy, accuracy: 0.0001)
        XCTAssertEqual(rolling.last?.compliance ?? 0, refPerf.compliance, accuracy: 0.0001)

        // vDSP correlation & R standard deviation
        let perfectCorr = try XCTUnwrap(AnalyticsEngine.correlation([(1, 2), (2, 4), (3, 6), (4, 8)]))
        XCTAssertEqual(perfectCorr, 1.0, accuracy: 0.000001)
        XCTAssertGreaterThan(AnalyticsEngine.rStandardDeviation(sample), 1.5)
    }

    func testOnDeviceMLEdgePredictionDiscoveryTiltAndNLP() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        var history: [TradeRecord] = []

        // 12 strong NY AM QT + Valid SSMT winners
        for i in 0..<12 {
            var t = TradeRecord()
            t.instrument = "NQ"
            t.direction = "Long"
            t.session = "New York AM"
            t.setupName = "QT + SSMT"
            t.biasRelation = "Pro-Trend"
            t.qt.enabled = true; t.qt.profile = "AMDX"; t.qt.dailyQuarter = "Q3"; t.qt.aligned = true
            t.ssmt.confirmation = "Yes"; t.ssmt.valid = true
            t.grossPnL = 450; t.rMultiple = 2.25; t.riskDollars = 200
            t.notes.thesis = "Sabırla bekledim teyit geldi temiz giriş"
            t.date = base.addingTimeInterval(Double(i) * 86400)
            t.exitDate = t.date.addingTimeInterval(1800)
            history.append(t)
        }

        // 6 losing Counter-Trend FOMO + rapid revenge entries with risk escalation
        for i in 0..<6 {
            var t = TradeRecord()
            t.instrument = "ES"
            t.direction = "Short"
            t.session = "London"
            t.setupName = "Unassigned"
            t.biasRelation = "Counter-Trend"
            t.ssmt.confirmation = "No"; t.ssmt.valid = false
            t.brokenRules = ["Early entry"]
            t.emotional.fomo = 8; t.emotional.stress = 8
            t.grossPnL = -300; t.rMultiple = -1.5
            t.riskDollars = i == 0 ? 200 : 350 // >25% risk jump after loss
            t.notes.lesson = "Sabırsız erken giriş yaptım fomo hatası"
            // Rapid 5-minute spacing after previous exit to trigger revenge detector
            let tDate = base.addingTimeInterval(12 * 86400 + Double(i) * 600)
            t.date = tDate
            t.exitDate = tDate.addingTimeInterval(300)
            history.append(t)
        }

        // 1. Live Edge Prediction must score strong setup materially higher than risky FOMO setup
        var strongDraft = TradeRecord()
        strongDraft.instrument = "NQ"; strongDraft.direction = "Long"; strongDraft.session = "New York AM"
        strongDraft.setupName = "QT + SSMT"; strongDraft.biasRelation = "Pro-Trend"
        strongDraft.qt.enabled = true; strongDraft.qt.profile = "AMDX"; strongDraft.qt.dailyQuarter = "Q3"
        strongDraft.ssmt.confirmation = "Yes"; strongDraft.ssmt.valid = true

        var weakDraft = TradeRecord()
        weakDraft.instrument = "ES"; weakDraft.direction = "Short"; weakDraft.session = "London"
        weakDraft.biasRelation = "Counter-Trend"; weakDraft.brokenRules = ["Early entry"]
        weakDraft.emotional.fomo = 8; weakDraft.emotional.stress = 8

        let strongPred = EdgeMLEngine.predict(candidate: strongDraft, history: history, calendar: cal)
        let weakPred = EdgeMLEngine.predict(candidate: weakDraft, history: history, calendar: cal)
        XCTAssertGreaterThan(strongPred.edgeScore, weakPred.edgeScore + 25)
        XCTAssertGreaterThan(strongPred.winProbability, weakPred.winProbability)
        XCTAssertGreaterThan(strongPred.expectedR, weakPred.expectedR)
        XCTAssertFalse(strongPred.factors.isEmpty)
        XCTAssertNotNil(weakPred.warning)

        // 2. Full ML analysis discovers golden setups, money leaks, elevated tilt, and NLP keywords
        let insights = EdgeMLEngine.analyze(history, calendar: cal)
        XCTAssertEqual(insights.sampleCount, 18)
        XCTAssertFalse(insights.goldenSetups.isEmpty)
        XCTAssertFalse(insights.moneyLeaks.isEmpty)
        XCTAssertEqual(insights.tilt.level, .elevated)
        XCTAssertGreaterThanOrEqual(insights.tilt.rapidReentryCount, 4)
        XCTAssertFalse(insights.positiveKeywords.isEmpty)
        XCTAssertFalse(insights.negativeKeywords.isEmpty)

        // 3. Module 1: AI Trade Notes Synthesizer, Optimal Risk %, and What-If Booster
        XCTAssertGreaterThan(strongPred.recommendedRiskPercent, weakPred.recommendedRiskPercent)
        let synthNotes = EdgeMLEngine.synthesizeTradeNotes(for: strongDraft, prediction: strongPred)
        XCTAssertFalse(synthNotes.thesis.isEmpty)
        XCTAssertFalse(synthNotes.entry.isEmpty)
        XCTAssertFalse(synthNotes.confirmation.isEmpty)
        XCTAssertFalse(synthNotes.lesson.isEmpty)

        // 4. Module 2: Post-Trade AI Autopsy (with Execution Grade & Counterfactuals) & k-NN Similar Trades
        let winnerAutopsy = EdgeMLEngine.autopsy(for: history[0], history: history, calendar: cal)
        let loserAutopsy = EdgeMLEngine.autopsy(for: history[15], history: history, calendar: cal)
        XCTAssertEqual(winnerAutopsy.tone, .optimal)
        XCTAssertEqual(loserAutopsy.tone, .leak)
        XCTAssertFalse(loserAutopsy.counterfactuals.isEmpty)
        XCTAssertGreaterThan(winnerAutopsy.edgeAlignmentPercent, loserAutopsy.edgeAlignmentPercent)
        XCTAssertEqual(winnerAutopsy.similarTrades.count, 5)
        XCTAssertGreaterThanOrEqual(winnerAutopsy.similarTrades[0].similarityPercent, 85)

        // 5. Module 3: AI Review Draft & AI Daily Plan Kelly Briefing (with Weekday Edge Summary)
        let aiReview = EdgeMLEngine.generateReviewDraft(existing: ReviewDraft( Review(period: "Monthly", date: history[5].date) ), trades: history, calendar: cal)
        XCTAssertFalse(aiReview.worked.isEmpty)
        XCTAssertFalse(aiReview.didNot.isEmpty)
        XCTAssertFalse(aiReview.adjustment.isEmpty)

        let account = TradingAccount(name: "Test 50K", currency: "USD", startingBalance: 50_000)
        let risk = WorkstationAnalytics.risk(history, account: account, calendar: cal, now: history.last!.date)
        let planBrief = EdgeMLEngine.generateDailyPlanBriefing(for: history.last!.date, account: account, trades: history, setups: [Setup(name: "QT + SSMT")], risk: risk, calendar: cal)
        XCTAssertGreaterThan(planBrief.recommendedRiskPercent, 0)
        XCTAssertGreaterThan(planBrief.recommendedRiskDollars, 0)
        XCTAssertFalse(planBrief.weekdayEdgeSummary.isEmpty)
        XCTAssertFalse(planBrief.plan.scenarios.isEmpty)
        XCTAssertFalse(planBrief.plan.focus.isEmpty)

        // 6. Module 4: Natural-Language AI Trading Coach across all specialized intents
        let lossReply = EdgeMLEngine.askCoach(question: "En çok neden ve hangi hatalardan para kaybediyorum?", trades: history, setups: [], account: account, risk: risk, calendar: cal)
        let qtReply = EdgeMLEngine.askCoach(question: "QT ve SSMT performansım nasıl?", trades: history, setups: [], account: account, risk: risk, calendar: cal)
        let riskReply = EdgeMLEngine.askCoach(question: "Bugün ne kadar risk almalıyım?", trades: history, setups: [], account: account, risk: risk, calendar: cal)
        let sessReply = EdgeMLEngine.askCoach(question: "Hangi seans ve saat dilimlerinde işlem açmayı bırakmalıyım?", trades: history, setups: [], account: account, risk: risk, calendar: cal)
        let instReply = EdgeMLEngine.askCoach(question: "Parite bazlı NQ ve ES performans karşılaştırmam nasıl?", trades: history, setups: [], account: account, risk: risk, calendar: cal)
        XCTAssertFalse(lossReply.answer.isEmpty)
        XCTAssertFalse(qtReply.answer.isEmpty)
        XCTAssertFalse(riskReply.answer.isEmpty)
        XCTAssertFalse(sessReply.answer.isEmpty)
        XCTAssertFalse(instReply.answer.isEmpty)

        // 7. Module 5: Playbook AI Model Optimizer (with Stability Score, Best Instrument, and Optimal Risk %)
        let opt = EdgeMLEngine.optimizeSetup(Setup(name: "QT + SSMT"), trades: history, calendar: cal)
        XCTAssertEqual(opt.sampleCount, 12)
        XCTAssertGreaterThanOrEqual(opt.edgeStabilityScore, 70)
        XCTAssertTrue(opt.bestInstrument.contains("NQ"))
        XCTAssertTrue(opt.bestSession.contains("New York"))
        XCTAssertGreaterThan(opt.recommendedRiskPercent, 0.25)
    }

    // MARK: - Exhaustive Ultra-AI Calibration, Stress, Regime, Counterfactual & Scale Tests

    private func makeSyntheticUltraJournal(count: Int, calendar: Calendar) -> [TradeRecord] {
        let base = Date(timeIntervalSince1970: 1_710_000_000)
        var list: [TradeRecord] = []
        list.reserveCapacity(count)

        for i in 0..<count {
            var t = TradeRecord()
            t.date = base.addingTimeInterval(Double(i) * 14400)
            t.exitDate = t.date.addingTimeInterval(1800)
            t.riskDollars = 250

            let bucket = i % 5
            if bucket == 0 || bucket == 1 || bucket == 2 {
                // High-Edge Institutional A+ Cohort (80% win rate, +2.2R on win, -1.0R on loss)
                t.instrument = bucket == 2 ? "ES" : "NQ"
                t.direction = "Long"
                t.session = "New York AM"
                t.setupName = "QT + SSMT"
                t.bias = "Bullish"
                t.biasRelation = "Pro-Trend"
                t.htfAligned = true
                t.grade = "A+"
                t.qt.enabled = true; t.qt.profile = "AMDX"; t.qt.dailyQuarter = "Q3"; t.qt.aligned = true; t.qt.valid = true
                t.ssmt.confirmation = "Yes"; t.ssmt.valid = true
                t.confirmations = ["CISD", "FVG", "Displacement"]
                t.followsPlan = true
                t.emotional.fomo = 2; t.emotional.stress = 3
                let isWin = (i % 10 != 6) // ~83% WR
                t.rMultiple = isWin ? 2.2 : -1.0
                t.grossPnL = isWin ? 550 : -250
                t.notes.thesis = "Sabırla NY AM Q3 SSMT CISD teyidi beklendi temiz giriş"
            } else {
                // Low-Edge Leak Cohort (15% win rate, Counter-Trend without SSMT, broken rules, high FOMO)
                t.instrument = "EURUSD"
                t.direction = "Short"
                t.session = "London"
                t.setupName = "Impulsive Scalp"
                t.bias = "Bullish"
                t.biasRelation = "Counter-Trend"
                t.htfAligned = false
                t.grade = "D"
                t.qt.enabled = false
                t.ssmt.confirmation = "No"; t.ssmt.valid = false
                t.followsPlan = false
                t.brokenRules = ["Early entry", "FOMO chase"]
                t.emotional.fomo = 8; t.emotional.stress = 8
                let isWin = (i % 15 == 4)
                t.rMultiple = isWin ? 0.8 : -1.4
                t.grossPnL = isWin ? 200 : -350
                t.notes.lesson = "Sabırsız erken fomo girişi kural ihlali zararı"
                // Create rapid re-entry on every second leak trade
                if i > 0 && bucket == 4 {
                    t.date = list[i - 1].exitDate!.addingTimeInterval(300)
                    t.exitDate = t.date.addingTimeInterval(600)
                }
            }
            list.append(t)
        }
        return list
    }

    func testUltraMLOutOfSampleWalkForwardROCAUCAndBrierSkill() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let journal = makeSyntheticUltraJournal(count: 120, calendar: cal)

        let snap = EdgeMLEngine.analyze(journal, calendar: cal)
        XCTAssertEqual(snap.sampleCount, 120)

        // 1. Out-of-Sample Walk-Forward ROC-AUC & Brier Skill MUST prove genuine discrimination
        XCTAssertTrue(snap.validation.isReady)
        XCTAssertGreaterThanOrEqual(snap.validation.evaluatedCount, 100)
        XCTAssertGreaterThanOrEqual(snap.validation.rocAUC, 0.80, "Walk-forward ROC-AUC must strongly separate winners from losers")
        XCTAssertLessThan(snap.validation.brierScore, snap.validation.baselineBrierScore, "Trained L2 Logistic+Bayes ensemble must beat naive base-rate Brier score")
        XCTAssertGreaterThan(snap.validation.brierSkillPercent, 15.0)
        XCTAssertGreaterThan(snap.validation.highEdgeWinRate, snap.validation.lowEdgeWinRate + 35.0)
        XCTAssertGreaterThan(snap.validation.highEdgeAvgR, snap.validation.lowEdgeAvgR + 1.5)

        // 2. Counterfactual AI Filter Simulator MUST demonstrate substantial capital saved & DD reduction
        let fs = snap.filterSimulation
        XCTAssertGreaterThan(fs.skippedTrades, 30)
        XCTAssertGreaterThan(fs.savedCapital, 5_000)
        XCTAssertGreaterThan(fs.filteredNetPnL, fs.actualNetPnL)
        XCTAssertGreaterThan(fs.filteredWinRate, fs.actualWinRate + 15.0)
        XCTAssertLessThan(fs.filteredMaxDrawdown, fs.actualMaxDrawdown)
        XCTAssertGreaterThan(fs.drawdownReductionPercent, 25.0)
    }

    func testUltraMLTimeDecayAdaptationAndAllFourCUSUMRegimes() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let base = Date(timeIntervalSince1970: 1_715_000_000)

        func makeSeries(rList: [Double], compliant: [Bool]) -> [TradeRecord] {
            rList.enumerated().map { idx, r in
                var t = TradeRecord()
                t.instrument = "NQ"; t.direction = "Long"; t.session = "New York AM"; t.setupName = "QT + SSMT"
                t.date = base.addingTimeInterval(Double(idx) * 86400)
                t.exitDate = t.date.addingTimeInterval(3600)
                t.rMultiple = r
                t.grossPnL = r * 250
                t.riskDollars = 250
                t.followsPlan = compliant[idx]
                if !compliant[idx] { t.brokenRules = ["Chased entry"] }
                return t
            }
        }

        // Regime 1: Hot Edge (consistent recent winners + 100% discipline)
        let hotR = [0.2, -0.5, 0.4, -0.3, 0.5, 1.5, 2.0, 2.2, 1.8, 2.5, 2.1, 1.9]
        let hotRegime = EdgeMLEngine.detectRegime(makeSeries(rList: hotR, compliant: Array(repeating: true, count: hotR.count)))
        XCTAssertEqual(hotRegime.state, .hotEdge)
        XCTAssertEqual(hotRegime.riskMultiplier, 1.10, accuracy: 0.001)

        // Regime 2: Stable (balanced variance around baseline + compliant)
        let stableR = [1.5, -1.0, 1.4, -1.0, 1.5, -1.0, 1.2, -0.8, 1.1, -0.8, 1.0, -0.7]
        let stableRegime = EdgeMLEngine.detectRegime(makeSeries(rList: stableR, compliant: Array(repeating: true, count: stableR.count)))
        XCTAssertEqual(stableRegime.state, .stable)
        XCTAssertEqual(stableRegime.riskMultiplier, 1.00, accuracy: 0.001)

        // Regime 3: Cold Variance (100% compliant process, temporary cold streak)
        let coldR = [2.0, 1.8, 2.2, 1.5, 2.0, 1.6, -1.0, -1.0, -0.8, -1.0, -0.9, -1.0]
        let coldRegime = EdgeMLEngine.detectRegime(makeSeries(rList: coldR, compliant: Array(repeating: true, count: coldR.count)))
        XCTAssertEqual(coldRegime.state, .coldVariance)
        XCTAssertEqual(coldRegime.riskMultiplier, 0.75, accuracy: 0.001)

        // Regime 4: Regime Drift (losses + broken compliance + CUSUM drift)
        let driftR = [2.0, 1.8, 2.2, 1.5, 2.0, 1.6, -1.5, -1.4, -1.2, -1.5, -1.3, -1.6]
        let driftComp = [true, true, true, true, true, true, false, false, false, false, false, false]
        let driftTrades = makeSeries(rList: driftR, compliant: driftComp)
        let driftRegime = EdgeMLEngine.detectRegime(driftTrades)
        XCTAssertEqual(driftRegime.state, .regimeDrift)
        XCTAssertEqual(driftRegime.riskMultiplier, 0.50, accuracy: 0.001)

        // Time-Decay Adaptation: recent losses on NQ Long must pull expected R well below older wins
        var oldWinsThenLosses: [TradeRecord] = []
        for i in 0..<30 {
            var t = TradeRecord()
            t.instrument = "NQ"; t.direction = "Long"; t.session = "New York AM"; t.setupName = "OldEdge"
            t.date = base.addingTimeInterval(Double(i) * 86400)
            t.exitDate = t.date.addingTimeInterval(1800)
            let isOld = i < 15
            t.rMultiple = isOld ? 1.5 : -1.5
            t.grossPnL = isOld ? 300 : -300
            oldWinsThenLosses.append(t)
        }
        var probe = TradeRecord()
        probe.instrument = "NQ"; probe.direction = "Long"; probe.session = "New York AM"; probe.setupName = "OldEdge"
        let decayedPred = EdgeMLEngine.predict(candidate: probe, history: oldWinsThenLosses, calendar: cal)
        XCTAssertLessThan(decayedPred.expectedR, -0.10, "Time-decay weighting must prioritize recent regime deterioration over stale wins")
    }

    func testUltraMLNumericalStabilityMonotonicityAndExtremeEdgeCases() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let account = TradingAccount(name: "EdgeTest", currency: "USD", startingBalance: 50_000)

        // Edge Cases: 0, 1, 2, 3 trades, 100% wins, 100% losses, all breakevens, missing R, extreme PnL
        let emptySnap = EdgeMLEngine.analyze([], calendar: cal)
        XCTAssertEqual(emptySnap.sampleCount, 0)
        XCTAssertFalse(emptySnap.validation.isReady)

        for count in [0, 1, 2, 3, 10] {
            var extreme: [TradeRecord] = []
            for i in 0..<count {
                var t = TradeRecord()
                t.instrument = ""; t.session = ""; t.grade = ""; t.biasRelation = ""
                t.grossPnL = i % 2 == 0 ? 10_000_000 : -10_000_000
                t.rMultiple = nil // missing R
                t.date = Date(timeIntervalSince1970: Double(i) * 3600)
                extreme.append(t)
            }
            let snap = EdgeMLEngine.analyze(extreme, calendar: cal)
            XCTAssertFalse(snap.validation.rocAUC.isNaN)
            XCTAssertFalse(snap.validation.brierScore.isNaN)
            XCTAssertFalse(snap.regime.ewmaR.isNaN)
            XCTAssertFalse(snap.filterSimulation.savedCapital.isNaN)

            let pred = EdgeMLEngine.predict(candidate: TradeRecord(), history: extreme, calendar: cal)
            XCTAssertTrue((5...99).contains(pred.edgeScore))
            XCTAssertTrue(pred.winProbability.isFinite && pred.winProbability >= 0 && pred.winProbability <= 100)
            XCTAssertTrue(pred.expectedR.isFinite)
            XCTAssertTrue(pred.uncertaintyBandR.isFinite && pred.uncertaintyBandR > 0)
            XCTAssertTrue(pred.recommendedRiskPercent.isFinite && pred.recommendedRiskPercent >= 0.20 && pred.recommendedRiskPercent <= 1.50)

            let risk = WorkstationAnalytics.risk(extreme, account: account, calendar: cal)
            let coach = EdgeMLEngine.askCoach(question: "Genel durumum ne?", trades: extreme, setups: [], account: account, risk: risk, calendar: cal)
            XCTAssertFalse(coach.headline.isEmpty)
        }

        // Strict Monotonicity: Adding rule breaks & FOMO=9 MUST reduce edgeScore and recommendedRiskPercent
        let journal = makeSyntheticUltraJournal(count: 60, calendar: cal)
        var cleanCandidate = journal[0]
        cleanCandidate.id = UUID()
        var dirtyCandidate = cleanCandidate
        dirtyCandidate.id = UUID()
        dirtyCandidate.followsPlan = false
        dirtyCandidate.brokenRules = ["Early entry", "FOMO chase"]
        dirtyCandidate.emotional.fomo = 9
        dirtyCandidate.emotional.stress = 9

        let cleanPred = EdgeMLEngine.predict(candidate: cleanCandidate, history: journal, calendar: cal)
        let dirtyPred = EdgeMLEngine.predict(candidate: dirtyCandidate, history: journal, calendar: cal)
        XCTAssertGreaterThan(cleanPred.edgeScore, dirtyPred.edgeScore + 20)
        XCTAssertGreaterThan(cleanPred.recommendedRiskPercent, dirtyPred.recommendedRiskPercent)
    }

    func testUltraMLCosineKNNInvariantsAndAutopsyCounterfactuals() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let journal = makeSyntheticUltraJournal(count: 40, calendar: cal)

        let target = journal[0]
        var exactClone = target
        exactClone.id = UUID()
        var opposite = TradeRecord()
        opposite.instrument = "XAUUSD"; opposite.direction = "Short"; opposite.session = "Asia"
        opposite.setupName = "Unrelated"; opposite.biasRelation = "Counter-Trend"
        opposite.qt.enabled = false; opposite.ssmt.valid = false; opposite.followsPlan = false; opposite.brokenRules = ["FOMO"]
        opposite.emotional.fomo = 9; opposite.emotional.stress = 9

        let matches = EdgeMLEngine.similarTrades(to: target, in: [target, exactClone, opposite] + journal, limit: 5)
        XCTAssertEqual(matches.count, 5)
        XCTAssertFalse(matches.contains { $0.id == target.id }, "k-NN must never return the target trade itself")
        XCTAssertGreaterThanOrEqual(matches[0].similarityPercent, 95, "Exact clone must score >= 95% Cosine similarity")
        for i in 1..<matches.count {
            XCTAssertGreaterThanOrEqual(matches[i - 1].similarityPercent, matches[i].similarityPercent, "k-NN matches must be strictly sorted descending")
        }

        // Autopsy counterfactuals on a broken-rule high-FOMO losing trade
        let leakTrade = try XCTUnwrap(journal.first { !$0.compliant && $0.netPnL < 0 })
        let autopsy = EdgeMLEngine.autopsy(for: leakTrade, history: journal, calendar: cal)
        XCTAssertEqual(autopsy.tone, .leak)
        XCTAssertFalse(autopsy.counterfactuals.isEmpty)
        XCTAssertTrue(["S+", "A", "B", "C", "D"].contains(autopsy.executionGrade))
        XCTAssertTrue((10...99).contains(autopsy.edgeAlignmentPercent))
    }

    func testUltraMLEntityAwareCoachAcrossAllTenIntents() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let journal = makeSyntheticUltraJournal(count: 50, calendar: cal)
        let setup = Setup(name: "QT + SSMT")
        let account = TradingAccount(name: "Funded 100K", currency: "USD", startingBalance: 100_000)
        let risk = WorkstationAnalytics.risk(journal, account: account, calendar: cal, now: journal.last!.date)

        let queries: [(query: String, expectedHeadlineFragment: String)] = [
            ("AI filtresi kullansaydım ne kadar para kurtarırdım?", "Filtre"),
            ("AI modelinin doğruluk oranı AUC ve rejim durumu ne?", "Walk-Forward"),
            ("QT + SSMT stratejim nasıl gidiyor?", "QT + SSMT"),
            ("NQ performansım nasıl?", "NQ"),
            ("Hangi seans ve saat dilimlerinde işlem açmayı bırakmalıyım?", "Seans"),
            ("Parite bazlı performans karşılaştırmam nasıl?", "Parite"),
            ("En çok neden ve hangi hatalardan para kaybediyorum?", "Kayıp"),
            ("QT Çeyrek ve SSMT onaylı işlemlerimin performansı nasıl?", "QT"),
            ("Bugün ne kadar risk almalıyım?", "Risk"),
            ("Bana genel bir performans özeti çıkar", "Edge")
        ]

        for (q, expected) in queries {
            let reply = EdgeMLEngine.askCoach(question: q, trades: journal, setups: [setup], account: account, risk: risk, calendar: cal)
            XCTAssertTrue(reply.headline.localizedCaseInsensitiveContains(expected), "Query '\(q)' produced unexpected headline '\(reply.headline)'")
            XCTAssertFalse(reply.answer.isEmpty)
            XCTAssertFalse(reply.metrics.isEmpty)
            XCTAssertFalse(reply.actionItems.isEmpty)
        }
    }

    func testUltraMLThousandTradeM3ProScaleAndDeterminismBenchmark() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let bigJournal = makeSyntheticUltraJournal(count: 1_000, calendar: cal)

        let snapA = EdgeMLEngine.analyze(bigJournal, calendar: cal)
        let tCachedStart = CFAbsoluteTimeGetCurrent()
        let snapB = EdgeMLEngine.analyze(bigJournal, calendar: cal)
        let cachedMs = (CFAbsoluteTimeGetCurrent() - tCachedStart) * 1000.0

        XCTAssertEqual(snapA.sampleCount, 1_000)
        XCTAssertEqual(snapA.validation, snapB.validation, "Walk-Forward validation must be 100% deterministic")
        XCTAssertEqual(snapA.regime, snapB.regime, "CUSUM regime detection must be 100% deterministic")
        XCTAssertEqual(snapA.filterSimulation, snapB.filterSimulation, "AI Filter simulation must be 100% deterministic")
        XCTAssertEqual(snapA.goldenSetups, snapB.goldenSetups)
        XCTAssertGreaterThanOrEqual(snapA.validation.rocAUC, 0.80)
        XCTAssertLessThan(snapA.computeMs, 600.0, "Full 1,000-trade Ultra ML pipeline must finish under 600ms on M3 Pro (took \(snapA.computeMs)ms)")
        XCTAssertLessThan(cachedMs, 5.0, "FNV-1a cached 1,000-trade analyze lookup must be sub-5ms (took \(cachedMs)ms)")

        // Verify live TradeEditorView keystroke prediction latency against 1,000-trade history
        var candidate = bigJournal[0]
        candidate.id = UUID()
        _ = EdgeMLEngine.predict(candidate: candidate, history: bigJournal, calendar: cal) // warm modelCache
        let tPredStart = CFAbsoluteTimeGetCurrent()
        for _ in 0..<50 {
            _ = EdgeMLEngine.predict(candidate: candidate, history: bigJournal, calendar: cal)
        }
        let avgKeystrokePredMs = ((CFAbsoluteTimeGetCurrent() - tPredStart) * 1000.0) / 50.0
        XCTAssertLessThan(avgKeystrokePredMs, 2.0, "Per-keystroke live ML prediction on 1,000 trades must be < 2ms (took \(avgKeystrokePredMs)ms)")
    }

    // MARK: - Automated Full-App Page, Tab, Modal & Button Verification

    @MainActor
    private static let sharedTestWindow: NSWindow = {
        _ = NSApplication.shared
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1440, height: 960),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.isReleasedWhenClosed = false
        return win
    }()

    @MainActor
    private func hostView<V: View>(
        _ name: String,
        _ view: V,
        store: JournalStore,
        width: CGFloat = 1440,
        height: CGFloat = 960,
        scheme: ColorScheme = .dark,
        rasterize: Bool = false
    ) throws -> NSView {
        _ = NSApplication.shared
        NSApp.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        let content = view
            .environment(store)
            .environment(\.locale, L10n.locale)
            .environment(\.edgeAnimationsEnabled, false)
            .environment(\.colorScheme, scheme)
            .environment(\.timeZone, store.preferences.calendar.timeZone)
            .frame(width: width, height: height)
            .background(Palette.canvas)
        let host = NSHostingView(rootView: content)
        host.frame = NSRect(x: 0, y: 0, width: width, height: height)
        let window = Self.sharedTestWindow
        window.setContentSize(NSSize(width: width, height: height))
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        XCTAssertEqual(host.bounds.width, width, "Width mismatch on \(name)")
        XCTAssertEqual(host.bounds.height, height, "Height mismatch on \(name)")
        if rasterize {
            guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
                XCTFail("Failed to allocate display bitmap for \(name)")
                throw JournalError(message: "Bitmap allocation failed for \(name)")
            }
            host.cacheDisplay(in: host.bounds, to: bitmap)
            XCTAssertGreaterThan(bitmap.pixelsWide, 0, "Zero bitmap width on \(name)")
            XCTAssertGreaterThan(bitmap.pixelsHigh, 0, "Zero bitmap height on \(name)")
        }
        return host
    }

    @MainActor
    func testEveryPageTabAndModalSheetRendersAndLaysOutCleanly() throws {
        UIControlProbe.isTracking = true
        UIControlProbe.reset()
        defer {
            UIControlProbe.isTracking = false
            UIControlProbe.reset()
        }

        let store = try JournalStore(demo: true)
        store.preferences.animations = false

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("liquidityedge-ui-test-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        let emptyStore = try JournalStore(demo: false, storageURL: tempDir.appendingPathComponent("Empty.store"))
        emptyStore.preferences.animations = false

        var renderedCount = 0

        // 1. All 17 JournalPage cases hosted inside RootView
        for page in JournalPage.allCases {
            let beforeButtons = UIControlProbe.totalControls
            _ = try hostView("RootView(\(page.rawValue))", RootView(startJournal: {}, openDemo: {}, initialPage: page), store: store)
            XCTAssertGreaterThan(UIControlProbe.totalControls, beforeButtons, "RootView(\(page.rawValue)) must mount interactive controls")
            renderedCount += 1
        }
        XCTAssertEqual(JournalPage.allCases.count, 17)

        // 2. Dashboard (populated dark, populated light, empty welcome) + DashboardLayoutEditor
        _ = try hostView("DashboardView-Dark", DashboardView(openTrade: { _ in }, newTrade: {}), store: store, rasterize: true)
        _ = try hostView("DashboardView-Light", DashboardView(openTrade: { _ in }, newTrade: {}), store: store, scheme: .light)
        _ = try hostView("DashboardView-Empty", DashboardView(openTrade: { _ in }, newTrade: {}, openDemo: {}), store: emptyStore)
        _ = try hostView("DashboardLayoutEditor", DashboardLayoutEditor(), store: store, width: 520, height: 640)
        renderedCount += 4

        // 3. TradesView, TradeRows, TradeDetailView, TradeSupplementEditor
        let firstTrade = try XCTUnwrap(store.trades.first)
        _ = try hostView("TradesView", TradesView(initialQuery: "", openTrade: { _ in }, newTrade: {}), store: store)
        let destructiveBeforeRows = UIControlProbe.renderedDestructiveButtons
        _ = try hostView("TradeRows", TradeRows(trades: Array(store.trades.prefix(6)), openTrade: { _ in }), store: store, width: 1080, height: 520)
        XCTAssertGreaterThanOrEqual(UIControlProbe.renderedDestructiveButtons - destructiveBeforeRows, 6, "Every trade row must render a clickable destructive delete button")
        let destructiveBeforeDetail = UIControlProbe.renderedDestructiveButtons
        _ = try hostView("TradeDetailView", TradeDetailView(tradeID: firstTrade.id, edit: { _ in }), store: store, width: 1040, height: 860)
        XCTAssertGreaterThanOrEqual(UIControlProbe.renderedDestructiveButtons - destructiveBeforeDetail, 1, "TradeDetailView must render a clickable destructive Delete button")
        _ = try hostView("TradeSupplementEditor", TradeSupplementEditor(tradeID: firstTrade.id), store: store, width: 700, height: 700)
        renderedCount += 4

        // 4. TradeEditorView across all 5 sections (both existing trade and new trade)
        for section in 0..<5 {
            _ = try hostView("TradeEditorView-Existing-Tab\(section)", TradeEditorView(record: firstTrade, initialSection: section), store: store, width: 1060, height: 880)
            _ = try hostView("TradeEditorView-New-Tab\(section)", TradeEditorView(record: nil, initialSection: section), store: store, width: 1060, height: 880)
            renderedCount += 2
        }

        // 5. PlaybookView (populated & empty) + PlaybookEditor across all 3 tabs
        let firstSetup = try XCTUnwrap(store.setups.first)
        _ = try hostView("PlaybookView-Populated", PlaybookView(), store: store)
        _ = try hostView("PlaybookView-Empty", PlaybookView(), store: emptyStore)
        for tab in 0..<3 {
            _ = try hostView("PlaybookEditor-Tab\(tab)", PlaybookEditor(initial: try PlaybookDraft(firstSetup), initialTab: tab), store: store, width: 980, height: 820)
        }
        renderedCount += 5

        // 6. AnalyticsView in all 3 modes (.analytics, .setups, .statistics)
        for mode in [AnalyticsMode.analytics, .setups, .statistics] {
            _ = try hostView("AnalyticsView-\(mode)", AnalyticsView(mode: mode), store: store)
            renderedCount += 1
        }

        // 7. ResearchLabView across all 7 tabs (including "ML Keşif")
        let researchTabs = ["Matrix", "ML Keşif", "Setup × Session", "Confirmations", "Risk & Process", "Day & Time", "Related Trades"]
        for tab in researchTabs {
            _ = try hostView("ResearchLabView-\(tab)", ResearchLabView(openTrade: { _ in }, initialTab: tab), store: store)
            renderedCount += 1
        }

        // 8. PlanningView across all 3 tabs + ChecklistTemplateEditor
        for tab in ["Daily Plan", "Checklist Templates", "Workflow Discipline"] {
            _ = try hostView("PlanningView-\(tab)", PlanningView(initialTab: tab), store: store)
            renderedCount += 1
        }
        let sampleTemplate = ChecklistTemplate(name: "QT Test", items: [ChecklistAnswer(label: "TDO Check", phase: "Öncesi")])
        _ = try hostView("ChecklistTemplateEditor", ChecklistTemplateEditor(template: sampleTemplate, onSave: { _ in }), store: store, width: 550, height: 500)
        renderedCount += 1

        // 9. ReviewsView (populated & empty) + ReviewEditor
        _ = try hostView("ReviewsView-Populated", ReviewsView(), store: store)
        _ = try hostView("ReviewsView-Empty", ReviewsView(), store: emptyStore)
        _ = try hostView("ReviewEditor", ReviewEditor(initial: ReviewDraft()), store: store, width: 980, height: 860)
        renderedCount += 3

        // 10. AccountRiskView + AccountEditor + CalendarView + QuantView + MistakesView + CSVImportView + ScreenshotLibraryView + ScreenshotViewer + SettingsView
        _ = try hostView("AccountRiskView", AccountRiskView(), store: store)
        _ = try hostView("AccountEditor", AccountEditor(initial: store.selectedAccount), store: store, width: 620, height: 680)
        _ = try hostView("CalendarView", CalendarView(openTrade: { _ in }), store: store)
        _ = try hostView("QuantView", QuantView(), store: store)
        _ = try hostView("MistakesView", MistakesView(), store: store)
        _ = try hostView("CSVImportView", CSVImportView(), store: store)
        _ = try hostView("ScreenshotLibraryView", ScreenshotLibraryView(openTrade: { _ in }), store: store)
        let dummyShot = ScreenshotDraft(name: "Test.png", category: "Entry", imageData: Data(), thumbnailData: Data())
        _ = try hostView("ScreenshotViewer", ScreenshotViewer(initial: dummyShot, onSave: { _ in }), store: store, width: 1200, height: 860)
        _ = try hostView("SettingsView-Demo", SettingsView(openDemo: {}), store: store)
        _ = try hostView("SettingsView-Local", SettingsView(openDemo: {}), store: emptyStore)
        _ = try hostView("SettingsView-Light", SettingsView(openDemo: {}), store: store, scheme: .light)
        renderedCount += 11

        XCTAssertEqual(renderedCount, 68)
        XCTAssertGreaterThan(UIControlProbe.renderedEdgeButtons, 150, "Must mount all primary/secondary EdgeButtonStyle buttons across 68 screens")
        XCTAssertGreaterThan(UIControlProbe.renderedDestructiveButtons, 15, "Must mount all destructive delete buttons across screens")
        XCTAssertGreaterThan(UIControlProbe.renderedSidebarButtons, 200, "Must mount sidebar navigation buttons across all 17 RootView pages")
        XCTAssertGreaterThan(UIControlProbe.renderedSegmentedTabItems, 40, "Must mount SegmentedTabs across pages")
        XCTAssertGreaterThan(UIControlProbe.renderedChipButtons, 15, "Must mount ChipSelection buttons in TradeEditorView")
    }

    @MainActor
    func testAllInteractiveButtonsDeleteFlowsAndSheetCallbacksExecuteProperly() throws {
        UIControlProbe.isTracking = true
        UIControlProbe.reset()
        defer {
            ConfirmDialog.testHandler = nil
            UIControlProbe.isTracking = false
            UIControlProbe.reset()
        }

        let store = try JournalStore(demo: true)
        store.preferences.animations = false
        let initialTradeCount = store.trades.count
        XCTAssertGreaterThan(initialTradeCount, 5)

        // 1. TradeRows: verify both row render and trash delete button action (with cancel AND confirm!)
        let targetTrade = store.trades[0]
        var openedTradeID: UUID?
        let openCallback: (TradeRecord) -> Void = { openedTradeID = $0.id }
        _ = try hostView(
            "TradeRows-ActionTest",
            TradeRows(trades: [targetTrade], openTrade: openCallback),
            store: store,
            width: 1080,
            height: 240
        )
        openCallback(targetTrade)
        XCTAssertEqual(openedTradeID, targetTrade.id)

        // Trigger TradeRows delete button handler with Cancel (false) -> trade must NOT be deleted
        var dialogCapturedTitle = ""
        ConfirmDialog.testHandler = { title, _, destructive in
            dialogCapturedTitle = title
            XCTAssertTrue(destructive)
            return false
        }
        XCTAssertFalse(TradeRows.performDeleteTrade(targetTrade, in: store))
        XCTAssertEqual(dialogCapturedTitle, "Delete this trade and its screenshots?")
        XCTAssertEqual(store.trades.count, initialTradeCount, "Cancelled delete must preserve trade")

        // Trigger TradeRows delete button handler with Confirm (true) -> trade MUST be deleted
        ConfirmDialog.testHandler = { _, _, destructive in
            XCTAssertTrue(destructive)
            return true
        }
        XCTAssertTrue(TradeRows.performDeleteTrade(targetTrade, in: store))
        XCTAssertEqual(store.trades.count, initialTradeCount - 1, "Confirmed delete on TradeRows must delete trade from store")
        XCTAssertNil(store.trades.first { $0.id == targetTrade.id })

        // 2. TradeDetailView: verify Edit callback and Delete button confirmation flow
        let secondTrade = store.trades[0]
        var editedTradeID: UUID?
        let editCallback: (TradeRecord) -> Void = { editedTradeID = $0.id }
        _ = try hostView(
            "TradeDetailView-ActionTest",
            TradeDetailView(tradeID: secondTrade.id, edit: editCallback),
            store: store,
            width: 1040,
            height: 860
        )
        editCallback(secondTrade)
        XCTAssertEqual(editedTradeID, secondTrade.id)

        let countBeforeDetailDelete = store.trades.count
        XCTAssertTrue(TradeDetailView.performDeleteTrade(tradeID: secondTrade.id, in: store))
        XCTAssertEqual(store.trades.count, countBeforeDetailDelete - 1, "Confirmed delete in TradeDetailView must delete trade")
        XCTAssertNil(store.trades.first { $0.id == secondTrade.id })

        // 3. TradeDraft & TradeEditorView: verify R calculation, risk % calculation, and Save button handler
        let draft = TradeDraft(record: nil)
        draft.loadAttachments(from: store)
        draft.record.instrument = "NQ"
        draft.record.direction = "Long"
        draft.record.riskPercent = 1.0
        draft.applyRiskPercent(from: 50_000)
        XCTAssertEqual(draft.record.riskDollars, 500)
        draft.record.grossPnL = 1020
        draft.record.fees = 20
        draft.calculateR()
        XCTAssertEqual(draft.record.rMultiple, 2.0)
        draft.applyRMultiple(3.0)
        XCTAssertEqual(draft.record.grossPnL, 1520)
        let countBeforeSave = store.trades.count
        XCTAssertTrue(draft.save(into: store))
        XCTAssertEqual(store.trades.count, countBeforeSave + 1)

        // 4. PlaybookView & PlaybookEditor: verify New Setup, Save Setup, Duplicate Validation, Edit Setup, and Delete Setup
        var newSetupDraft = PlaybookDraft()
        XCTAssertEqual(PlaybookEditor.performSaveDraft(newSetupDraft, into: store), "Give this setup a name.")
        newSetupDraft.name = "M3 Pro Liquidity Model"
        newSetupDraft.summary = "NY AM Q3 Sweep + CISD"
        newSetupDraft.conditions = "HTF IRL -> ERL"
        newSetupDraft.entry = "1M CISD + FVG"
        let setupsBeforeAdd = store.setups.count
        XCTAssertNil(PlaybookEditor.performSaveDraft(newSetupDraft, into: store))
        XCTAssertEqual(store.setups.count, setupsBeforeAdd + 1)

        // Duplicate name check on a distinct ID
        var dupDraft = PlaybookDraft()
        dupDraft.name = "m3 pro liquidity model"
        XCTAssertEqual(PlaybookEditor.performSaveDraft(dupDraft, into: store), "A setup with this name already exists.")

        // Edit existing setup via PlaybookEditor.performSaveDraft
        newSetupDraft.summary = "Updated summary"
        XCTAssertNil(PlaybookEditor.performSaveDraft(newSetupDraft, into: store))
        let createdSetup = try XCTUnwrap(store.setups.first { $0.id == newSetupDraft.id })
        XCTAssertEqual(createdSetup.summary, "Updated summary")

        // Delete setup via PlaybookView.performDeleteSetup (Cancel first, then Confirm)
        ConfirmDialog.testHandler = { _, _, _ in false }
        XCTAssertFalse(PlaybookView.performDeleteSetup(createdSetup, in: store))
        XCTAssertEqual(store.setups.count, setupsBeforeAdd + 1)
        ConfirmDialog.testHandler = { _, _, _ in true }
        XCTAssertTrue(PlaybookView.performDeleteSetup(createdSetup, in: store))
        XCTAssertEqual(store.setups.count, setupsBeforeAdd)

        // 5. ReviewsView & ReviewEditor: verify Create Review, Edit Review, and Delete Review via ConfirmDialog
        var reviewDraft = ReviewDraft()
        reviewDraft.period = "Weekly"
        reviewDraft.worked = "Waited for NY AM Q3 manipulation"
        reviewDraft.adjustment = "Strictly avoid London counter-trend entries"
        let reviewsBeforeAdd = store.reviews.count
        XCTAssertNil(ReviewEditor.performSaveDraft(reviewDraft, into: store))
        XCTAssertEqual(store.reviews.count, reviewsBeforeAdd + 1)

        reviewDraft.adjustment = "Updated adjustment"
        XCTAssertNil(ReviewEditor.performSaveDraft(reviewDraft, into: store))
        let savedReview = try XCTUnwrap(store.reviews.first { $0.id == reviewDraft.id })
        XCTAssertEqual(savedReview.adjustment, "Updated adjustment")

        ConfirmDialog.testHandler = { _, _, _ in false }
        XCTAssertFalse(ReviewsView.performDeleteReview(savedReview, in: store))
        XCTAssertEqual(store.reviews.count, reviewsBeforeAdd + 1)
        ConfirmDialog.testHandler = { _, _, _ in true }
        XCTAssertTrue(ReviewsView.performDeleteReview(savedReview, in: store))
        XCTAssertEqual(store.reviews.count, reviewsBeforeAdd)

        // 6. PlanningView: verify Default Templates installation & Template Deletion via ConfirmDialog
        PlanningView.performAddDefaultTemplates(into: store)
        XCTAssertGreaterThanOrEqual(store.workspace.templates.count, 3)
        let templatesCountAfterAdd = store.workspace.templates.count
        let firstTemplate = try XCTUnwrap(store.workspace.templates.first)

        ConfirmDialog.testHandler = { _, _, _ in false }
        XCTAssertFalse(PlanningView.performDeleteTemplate(firstTemplate, in: store))
        XCTAssertEqual(store.workspace.templates.count, templatesCountAfterAdd)

        ConfirmDialog.testHandler = { _, _, _ in true }
        XCTAssertTrue(PlanningView.performDeleteTemplate(firstTemplate, in: store))
        XCTAssertEqual(store.workspace.templates.count, templatesCountAfterAdd - 1)

        // 7. TradeSupplementEditor & ChecklistTemplateEditor workflows
        let activeTrade = try XCTUnwrap(store.trades.first)
        var supplement = TradeSupplement()
        supplement.pointValue = 20
        supplement.fills = [
            ExecutionFill(side: "Entry", quantity: 1, price: 20100, fee: 2, expectedPrice: 20099),
            ExecutionFill(side: "Exit", quantity: 1, price: 20125, fee: 2)
        ]
        supplement.checklist = [ChecklistAnswer(label: "True Open Saygı Gördü", phase: "Öncesi", answer: true)]
        try store.updateWorkspace { $0.supplements[activeTrade.id] = supplement }
        XCTAssertEqual(store.workspace.supplements[activeTrade.id]?.fills.count, 2)
        XCTAssertEqual(store.workspace.supplements[activeTrade.id]?.checklist.first?.answer, true)

        // 8. AccountRiskView & AccountEditor workflows (Add account, switch active account, verify risk engine)
        var fundedAccount = TradingAccount(name: "Apex 50K", currency: "USD", startingBalance: 50_000, category: "Funded")
        fundedAccount.rules.profitTarget = 3_000
        fundedAccount.rules.maximumLoss = 2_500
        fundedAccount.rules.dailyLoss = 1_250
        try store.updateWorkspace {
            $0.accounts.append(fundedAccount)
            $0.selectedAccountID = fundedAccount.id
        }
        XCTAssertEqual(store.selectedAccount.id, fundedAccount.id)
        XCTAssertEqual(store.scopedRisk.balance, 50_000)

        // 9. ResearchLabView preset save/apply/delete & DashboardLayoutEditor widget toggle/reorder/reset
        let preset = ResearchPreset(name: "NY AM Winners", filter: TradeFilter(query: "NY AM"))
        try store.updateWorkspace { $0.presets.append(preset) }
        XCTAssertTrue(store.workspace.presets.contains { $0.id == preset.id })
        try store.updateWorkspace { $0.presets.removeAll { $0.id == preset.id } }
        XCTAssertFalse(store.workspace.presets.contains { $0.id == preset.id })

        try store.updateWorkspace {
            $0.hiddenWidgets = ["Süreç / disiplin"]
            if $0.widgets.count >= 2 { $0.widgets.swapAt(0, 1) }
        }
        XCTAssertFalse(store.workspace.hiddenWidgets.isEmpty)
        try store.updateWorkspace {
            $0.widgets = WorkspaceState().widgets
            $0.hiddenWidgets = []
        }
        XCTAssertTrue(store.workspace.hiddenWidgets.isEmpty)
        XCTAssertEqual(store.workspace.widgets, WorkspaceState().widgets)

        // 10. SettingsView workflows: Custom Instrument, Custom Rule, Custom Session, Preferences Save
        let instrumentsBefore = store.instruments.count
        try store.commit { store.context.insert(Instrument(symbol: "BTCUSD")) }
        XCTAssertEqual(store.instruments.count, instrumentsBefore + 1)

        let rulesBefore = store.customRules.count
        let customRule = CustomRule(name: "Never enter during red folder news")
        try store.commit { store.context.insert(customRule) }
        XCTAssertEqual(store.customRules.count, rulesBefore + 1)
        try store.commit { store.context.delete(customRule) }
        XCTAssertEqual(store.customRules.count, rulesBefore)

        // 11. Verify ReviewEditor "AI ile Otomatik Doldur" button action handler on live store
        let filledReview = ReviewEditor.performGenerateAIDraft(ReviewDraft(), in: store)
        XCTAssertFalse(filledReview.worked.isEmpty)
        XCTAssertFalse(filledReview.didNot.isEmpty)
        XCTAssertFalse(filledReview.repeatNext.isEmpty)
        XCTAssertFalse(filledReview.stop.isEmpty)
        XCTAssertFalse(filledReview.adjustment.isEmpty)
    }

    // MARK: - Institutional PDFKit Report Tests

    @MainActor func testPDFReportServiceGeneratesValidMultiPageInstitutionalPDF() throws {
        let store = try JournalStore(demo: true)
        XCTAssertGreaterThanOrEqual(store.scopedTrades.count, 20)

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("pdf-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            PDFReportService.testSaveHandler = nil
            try? FileManager.default.removeItem(at: tempDir)
        }

        var capturedFiles: [(name: String, data: Data)] = []
        PDFReportService.testSaveHandler = { suggestedName, data in
            capturedFiles.append((suggestedName, data))
            let url = tempDir.appendingPathComponent(suggestedName)
            try? data.write(to: url, options: .atomic)
            return url
        }

        // 1. Export from ReviewsView with rich review notes
        var reviewDraft = ReviewDraft()
        reviewDraft.period = "Monthly"
        reviewDraft.date = store.scopedTrades.first?.date ?? Date()
        reviewDraft.worked = "NY AM Q3 manipülasyon sonrası SSMT teyidi yüksek beklenti üretti."
        reviewDraft.didNot = "NY Lunch saatlerinde düşük hacimde acele girişler zarar yazdı."
        reviewDraft.repeatNext = "Sadece True Open sonrası onaylı kurulumlara gir."
        reviewDraft.stop = "Peş peşe iki kayıptan sonra 15 dakika ekranı kapat."
        reviewDraft.adjustment = "Risk çarpanını aktif AI CUSUM rejimine göre uygula."

        let start = CFAbsoluteTimeGetCurrent()
        let reviewPDFURL = ReviewsView.performExportPDF(for: reviewDraft, in: store)
        let elapsedMs = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
        XCTAssertNotNil(reviewPDFURL)
        XCTAssertLessThan(elapsedMs, 1500.0, "PDF generation should complete rapidly on-device")

        let reviewData = try XCTUnwrap(capturedFiles.last?.data)
        XCTAssertTrue(reviewData.starts(with: Data("%PDF-".utf8)), "Output must be a valid PDF binary")
        let reviewDoc = try XCTUnwrap(PDFDocument(data: reviewData))
        XCTAssertEqual(reviewDoc.pageCount, 2, "Review report with notes and trades should render 2 crisp A4 pages")
        let reviewText = (0..<reviewDoc.pageCount).compactMap { reviewDoc.page(at: $0)?.string }.joined(separator: "\n")
        XCTAssertTrue(reviewText.contains("LIQUIDITY EDGE"))
        XCTAssertTrue(reviewText.contains("Aylık Performans Karnesi"))
        XCTAssertTrue(reviewText.contains("DİSİPLİN NOTU"))
        XCTAssertTrue(reviewText.contains("WALK-FORWARD"))
        XCTAssertTrue(reviewText.contains("NY AM Q3 manipülasyon"))
        XCTAssertEqual(reviewDoc.documentAttributes?[PDFDocumentAttribute.authorAttribute] as? String, "LIQUIDITY EDGE")

        // 2. Export from AnalyticsView across all 3 modes (analytics, setups, statistics)
        for mode in [AnalyticsMode.analytics, .setups, .statistics] {
            let url = AnalyticsView.performExportPDF(mode: mode, filter: TradeFilter(), trades: store.scopedTrades, in: store)
            XCTAssertNotNil(url)
            let data = try XCTUnwrap(capturedFiles.last?.data)
            let doc = try XCTUnwrap(PDFDocument(data: data))
            XCTAssertEqual(doc.pageCount, 2)
            let page1Text = doc.page(at: 0)?.string ?? ""
            XCTAssertTrue(page1Text.contains("SERMAYE & KÜMÜLATİF PERFORMANS EĞRİSİ"))
            XCTAssertTrue(page1Text.contains("AKTİF REJİM"))
        }

        // 3. Empty period fallback renders a clean single-page PDF without crashing
        let emptyRequest = PDFReportService.ReportRequest(
            title: "Boş Dönem Raporu",
            subtitle: "Test",
            periodLabel: "01.01.2020 – 07.01.2020",
            accountName: store.selectedAccount.name,
            currency: "USD",
            startingBalance: 50_000,
            trades: [],
            allAccountTrades: [],
            calendar: store.preferences.calendar,
            reviewNotes: nil
        )
        let emptyDoc = try PDFReportService.generateDocument(for: emptyRequest)
        XCTAssertEqual(emptyDoc.pageCount, 1)
        XCTAssertTrue((emptyDoc.page(at: 0)?.string ?? "").contains("Boş Dönem Raporu"))
    }

    // MARK: - Killzone & Quarterly Theory Live Clock Tests

    func testKillzoneClockEngineAllQuartersSessionsAndWeekends() throws {
        var prefs = JournalPreferences()
        prefs.timezone = "America/New_York"
        let nyTZ = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        var nyCal = Calendar(identifier: .gregorian)
        nyCal.timeZone = nyTZ

        func makeNYDate(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int = 0) throws -> Date {
            var comps = DateComponents()
            comps.year = year; comps.month = month; comps.day = day
            comps.hour = hour; comps.minute = minute; comps.second = second
            comps.timeZone = nyTZ
            return try XCTUnwrap(nyCal.date(from: comps))
        }

        // Wednesday 2026-06-10 20:30 NY -> Asia Killzone (20:00–00:00), Daily Q1, Micro Q2 (150m into True Day)
        let asiaDate = try makeNYDate(year: 2026, month: 6, day: 10, hour: 20, minute: 30)
        let asiaSnap = KillzoneClockEngine.snapshot(at: asiaDate, preferences: prefs)
        XCTAssertFalse(asiaSnap.isWeekendClosed)
        XCTAssertTrue(asiaSnap.isInKillzone)
        XCTAssertEqual(asiaSnap.activeSessionName, "Asia")
        XCTAssertEqual(asiaSnap.dailyQuarter.code, "Q1")
        XCTAssertEqual(asiaSnap.microQuarter.code, "Q2")
        XCTAssertEqual(asiaSnap.activeRemainingSeconds, 3.5 * 3600, accuracy: 1.0)

        // Thursday 2026-06-11 02:30 NY -> London Killzone (02:00–05:00), Daily Q2, Micro Q2
        let londonDate = try makeNYDate(year: 2026, month: 6, day: 11, hour: 2, minute: 30)
        let londonSnap = KillzoneClockEngine.snapshot(at: londonDate, preferences: prefs)
        XCTAssertTrue(londonSnap.isInKillzone)
        XCTAssertEqual(londonSnap.activeSessionName, "London")
        XCTAssertEqual(londonSnap.dailyQuarter.code, "Q2")
        XCTAssertEqual(londonSnap.microQuarter.code, "Q2")

        // Thursday 2026-06-11 10:00 NY -> NY AM Killzone (09:30–11:00), Daily Q3 (06:00–12:00), Micro Q3 (09:00–10:30)
        let nyAmDate = try makeNYDate(year: 2026, month: 6, day: 11, hour: 10, minute: 0)
        let nyAmSnap = KillzoneClockEngine.snapshot(at: nyAmDate, preferences: prefs)
        XCTAssertTrue(nyAmSnap.isInKillzone)
        XCTAssertEqual(nyAmSnap.activeSessionName, "NY AM")
        XCTAssertEqual(nyAmSnap.dailyQuarter.code, "Q3")
        XCTAssertEqual(nyAmSnap.microQuarter.code, "Q3")
        XCTAssertEqual(nyAmSnap.activeRemainingSeconds, 3600, accuracy: 1.0)
        XCTAssertTrue(nyAmSnap.trueOpenStatus.contains("TDO Aktif"))

        let fullLabel = nyAmSnap.menuBarLabel(riskMultiplier: 1.10, regimeState: .hotEdge, compact: false)
        XCTAssertTrue(fullLabel.contains("NY AM"))
        XCTAssertTrue(fullLabel.contains("Q3"))
        XCTAssertTrue(fullLabel.contains("1.10x"))

        let compactLabel = nyAmSnap.menuBarLabel(riskMultiplier: 0.75, regimeState: .coldVariance, compact: true)
        XCTAssertEqual(compactLabel, "Q3·Q3 0.75x")

        // Thursday 2026-06-11 14:15 NY -> NY PM Killzone (13:00–16:00), Daily Q4 (12:00–18:00), Micro Q2 (13:30–15:00)
        let nyPmDate = try makeNYDate(year: 2026, month: 6, day: 11, hour: 14, minute: 15)
        let nyPmSnap = KillzoneClockEngine.snapshot(at: nyPmDate, preferences: prefs)
        XCTAssertTrue(nyPmSnap.isInKillzone)
        XCTAssertEqual(nyPmSnap.activeSessionName, "NY PM")
        XCTAssertEqual(nyPmSnap.dailyQuarter.code, "Q4")
        XCTAssertEqual(nyPmSnap.microQuarter.code, "Q2")

        // Thursday 2026-06-11 06:30 NY -> Dead Zone, next Killzone is NY AM in 3 hours (09:30 NY)
        let deadZoneDate = try makeNYDate(year: 2026, month: 6, day: 11, hour: 6, minute: 30)
        let deadSnap = KillzoneClockEngine.snapshot(at: deadZoneDate, preferences: prefs)
        XCTAssertFalse(deadSnap.isInKillzone)
        XCTAssertEqual(deadSnap.nextSessionName, "NY AM")
        XCTAssertEqual(deadSnap.secondsUntilNextSession, 3 * 3600, accuracy: 1.0)

        // Saturday 2026-06-13 14:00 NY -> Weekend market closed
        let weekendDate = try makeNYDate(year: 2026, month: 6, day: 13, hour: 14, minute: 0)
        let weekendSnap = KillzoneClockEngine.snapshot(at: weekendDate, preferences: prefs)
        XCTAssertTrue(weekendSnap.isWeekendClosed)
        XCTAssertFalse(weekendSnap.isInKillzone)
        XCTAssertTrue(weekendSnap.menuBarLabel(riskMultiplier: 1.0, regimeState: .stable, compact: false).contains("Hafta Sonu"))

        // Overnight session wrap parser verification (e.g. 22:00–02:00)
        let overnight = try XCTUnwrap(KillzoneClockEngine.parseWindow(name: "Custom Night", raw: "22:00–02:00"))
        XCTAssertEqual(overnight.durationMinutes, 240)
        XCTAssertTrue(overnight.contains(minuteOfDay: 23 * 60 + 30))
        XCTAssertTrue(overnight.contains(minuteOfDay: 1 * 60 + 15))
        XCTAssertFalse(overnight.contains(minuteOfDay: 12 * 60))
    }

    // MARK: - macOS Menu Bar Assistant Rendering & Quick Note Persistence Tests

    @MainActor func testMenuBarAssistantRenderingAndQuickNotePersistence() throws {
        let store = try JournalStore(demo: true)

        // 1. Render both MenuBarStatusLabel and MenuBarAssistantView via NSHostingView
        let labelHost = NSHostingView(rootView: MenuBarStatusLabel().environment(store))
        labelHost.frame = NSRect(x: 0, y: 0, width: 220, height: 24)
        labelHost.layoutSubtreeIfNeeded()
        XCTAssertGreaterThan(labelHost.fittingSize.width, 0)

        let popoverHost = NSHostingView(
            rootView: MenuBarAssistantView(
                openMainWindow: {},
                openNewTrade: {},
                openDailyPlan: {},
                openCommandPalette: {}
            ).environment(store)
        )
        popoverHost.frame = NSRect(x: 0, y: 0, width: 372, height: 580)
        popoverHost.layoutSubtreeIfNeeded()
        XCTAssertGreaterThan(popoverHost.fittingSize.height, 200)

        // 2. Verify inline Quick Note saves & appends timestamped entries to today's DailyPlan
        let now = Date()
        XCTAssertFalse(MenuBarAssistantView.appendQuickNote("   \n  ", into: store, at: now))

        XCTAssertTrue(MenuBarAssistantView.appendQuickNote("NQ PDH likiditesi alındı, Q3 teyidi bekleniyor.", into: store, at: now))
        let cal = store.preferences.calendar
        let plan1 = try XCTUnwrap(store.workspace.plans.first { $0.accountID == store.selectedAccount.id && cal.isDate($0.date, inSameDayAs: now) })
        XCTAssertTrue(plan1.scenarios.contains("NQ PDH likiditesi alındı"))
        XCTAssertTrue(plan1.scenarios.hasPrefix("["))

        XCTAssertTrue(MenuBarAssistantView.appendQuickNote("SSMT onaylandı, risk %0.50 sabit.", into: store, at: now))
        let plan2 = try XCTUnwrap(store.workspace.plans.first { $0.accountID == store.selectedAccount.id && cal.isDate($0.date, inSameDayAs: now) })
        XCTAssertTrue(plan2.scenarios.contains("NQ PDH likiditesi alındı"))
        XCTAssertTrue(plan2.scenarios.contains("SSMT onaylandı"))
        XCTAssertEqual(plan2.scenarios.components(separatedBy: "\n").count, 2)
    }
}
