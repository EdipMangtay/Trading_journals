import Foundation
import SwiftData
import Observation

struct JournalError: LocalizedError {
    var message: String
    var errorDescription: String? { message }
}
private final class ParallelBuffer<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) { self.value = value }
}
@MainActor @Observable final class JournalStore {
    let container: ModelContainer
    let context: ModelContext
    let isDemo: Bool
    private(set) var trades: [TradeRecord] = []
    private(set) var setups: [Setup] = []
    private(set) var instruments: [Instrument] = []
    private(set) var customRules: [CustomRule] = []
    private(set) var reviews: [Review] = []
    private(set) var revision = 0
    var preferences: JournalPreferences
    var errorMessage: String?
    private var models: [UUID: Trade] = [:]
    /// Stable Application Support location, independent from the application bundle.
    let storageURL: URL?
    let backupDirectoryURL: URL?
    private let preferencesURL: URL?
    private let usesLegacyPreferences: Bool
    private(set) var lastBackupDate: Date?
    private(set) var backupErrorMessage: String?
    private var dailyBackupDay: String?
    private(set) var workspace = WorkspaceState()
    private(set) var selectedAccount: TradingAccount = TradingAccount(id: TradingAccount.legacyID, name: "Eski günlük", currency: "USD", startingBalance: 50000)
    private(set) var scopedTrades: [TradeRecord] = []
    private(set) var scopedPerformance = Performance()
    private(set) var scopedCurve: [CurvePoint] = []
    private(set) var scopedTodayPnL = 0.0
    private(set) var scopedClassifications: [Classification: Int] = [:]
    private(set) var scopedComparisons: [Comparison] = []
    private(set) var scopedEdgeMatrix: [EdgeCombination] = []
    private(set) var scopedSessionGroups: [MetricGroup] = []
    private(set) var scopedMonthlyProcess: [MonthlyProcess] = []
    private(set) var scopedMistakes: [MetricGroup] = []
    private(set) var scopedHeatmapBuckets: [Int: Performance] = [:]
    private(set) var scopedSetupPerformances: [UUID?: Performance] = [:]
    private(set) var scopedRisk = RiskSnapshot(balance: 50000, realized: 0, today: 0, days: 0, todayCount: 0, floor: nil, remaining: nil, dailyRemaining: nil, consistency: nil, unverified: false, historicalBreach: false, oversizedTrades: 0, dailyCountBreaches: 0)
    private(set) var scopedUnderwater = WorkstationAnalytics.Underwater()
    private(set) var scopedRStability = 0.0
    private(set) var scopedMLInsights = EdgeMLEngine.MLInsightsSnapshot()
    @ObservationIgnored private var accountsByID: [UUID: TradingAccount] = [:]
    var accountCurrency: String { selectedAccount.currency }
    func accountID(for tradeID: UUID) -> UUID { workspace.assignments[tradeID] ?? TradingAccount.legacyID }
    func currency(for tradeID: UUID) -> String { accountsByID[accountID(for: tradeID)]?.currency ?? preferences.currency }
    private func rebuildWorkspaceCaches() {
        accountsByID = Dictionary(uniqueKeysWithValues: workspace.accounts.map { ($0.id, $0) })
        let active = accountsByID[workspace.selectedAccountID] ?? TradingAccount(id: TradingAccount.legacyID, name: "Eski günlük", currency: preferences.currency, startingBalance: preferences.accountSize)
        selectedAccount = active
        let targetID = active.id
        let filtered: [TradeRecord]
        if workspace.accounts.count <= 1 && targetID == TradingAccount.legacyID && workspace.assignments.values.allSatisfy({ $0 == targetID }) {
            filtered = trades
        } else {
            filtered = trades.filter { (workspace.assignments[$0.id] ?? TradingAccount.legacyID) == targetID }
        }
        scopedTrades = filtered
        let cal = preferences.calendar
        let now = Date()
        let ordered = AnalyticsEngine.ordered(filtered)

        // Fan out independent O(N) analytics across Apple Silicon performance cores when dataset warrants parallelism.
        let perfBox = ParallelBuffer(Performance())
        let curveBox = ParallelBuffer([CurvePoint]())
        let comparisonsBox = ParallelBuffer([Comparison]())
        let edgesBox = ParallelBuffer([EdgeCombination]())
        let sessionsBox = ParallelBuffer([MetricGroup]())
        let monthlyBox = ParallelBuffer([MonthlyProcess]())
        let mistakesBox = ParallelBuffer([MetricGroup]())
        let heatmapBox = ParallelBuffer([Int: Performance]())
        let setupPerfsBox = ParallelBuffer([UUID?: Performance]())
        let riskBox = ParallelBuffer(RiskSnapshot(balance: active.startingBalance, realized: 0, today: 0, days: 0, todayCount: 0, floor: nil, remaining: nil, dailyRemaining: nil, consistency: nil, unverified: false, historicalBreach: false, oversizedTrades: 0, dailyCountBreaches: 0))
        let underwaterBox = ParallelBuffer(WorkstationAnalytics.Underwater())
        let rStabBox = ParallelBuffer(0.0)
        let mlBox = ParallelBuffer(EdgeMLEngine.MLInsightsSnapshot())
        let todayBox = ParallelBuffer(0.0)
        let countsBox = ParallelBuffer([Classification: Int]())

        let runTask: @Sendable (Int) -> Void = { task in
            switch task {
            case 0:
                perfBox.value = AnalyticsEngine.performance(ordered)
                rStabBox.value = AnalyticsEngine.rStandardDeviation(ordered)
            case 1:
                curveBox.value = AnalyticsEngine.curve(ordered)
            case 2:
                comparisonsBox.value = AnalyticsEngine.comparisons(ordered)
            case 3:
                edgesBox.value = AnalyticsEngine.edgeMatrix(ordered)
            case 4:
                sessionsBox.value = AnalyticsEngine.groups(ordered, by: .session, calendar: cal)
                monthlyBox.value = AnalyticsEngine.monthlyProcess(ordered, calendar: cal)
            case 5:
                mistakesBox.value = AnalyticsEngine.mistakes(ordered)
                setupPerfsBox.value = AnalyticsEngine.setupPerformances(ordered)
            case 6:
                heatmapBox.value = AnalyticsEngine.heatmapBuckets(ordered, calendar: cal)
            case 7:
                riskBox.value = WorkstationAnalytics.risk(ordered, account: active, calendar: cal, now: now)
                underwaterBox.value = WorkstationAnalytics.underwater(ordered)
            case 8:
                mlBox.value = EdgeMLEngine.analyze(ordered, calendar: cal)
            default:
                var localToday = 0.0
                var localCounts: [Classification: Int] = [:]
                for t in ordered {
                    localCounts[t.classification, default: 0] += 1
                    if cal.isDate(t.date, inSameDayAs: now) { localToday += t.netPnL }
                }
                todayBox.value = localToday
                countsBox.value = localCounts
            }
        }

        if ordered.count >= 48 && HardwareProfile.coreCount >= 4 {
            DispatchQueue.concurrentPerform(iterations: 10, execute: runTask)
        } else {
            for i in 0..<10 { runTask(i) }
        }

        scopedPerformance = perfBox.value
        scopedCurve = curveBox.value
        scopedTodayPnL = todayBox.value
        scopedClassifications = countsBox.value
        scopedComparisons = comparisonsBox.value
        scopedEdgeMatrix = edgesBox.value
        scopedSessionGroups = sessionsBox.value
        scopedMonthlyProcess = monthlyBox.value
        scopedMistakes = mistakesBox.value
        scopedHeatmapBuckets = heatmapBox.value
        scopedSetupPerformances = setupPerfsBox.value
        scopedRisk = riskBox.value
        scopedUnderwater = underwaterBox.value
        scopedRStability = rStabBox.value
        scopedMLInsights = mlBox.value

        // Asynchronously warm search index in the background on Apple Silicon efficiency/performance cores
        let snapshot = ordered
        DispatchQueue.global(qos: .utility).async {
            TradeSearch.prewarm(snapshot)
        }
    }
    func updateWorkspace(_ change: (inout WorkspaceState) throws -> Void) throws {
        var next = workspace; try change(&next); try next.validate(tradeIDs: Set(trades.map(\.id)))
        try commit { try persistWorkspace(next) }
    }
    func persistWorkspace(_ value: WorkspaceState) throws {
        let data = try JSONEncoder().encode(value)
        if let model = try context.fetch(FetchDescriptor<WorkspaceDocument>()).first { model.payload = data }
        else { context.insert(WorkspaceDocument(payload: data)) }
    }
    static let schema = Schema(versionedSchema: JournalSchemaV2.self)
    init(demo: Bool, storageURL: URL? = nil) throws {
        isDemo = demo
        usesLegacyPreferences = !demo && storageURL == nil
        let resolvedURL: URL?
        if demo { resolvedURL = nil }
        else { resolvedURL = try storageURL ?? Self.defaultStoreURL() }
        self.storageURL = resolvedURL
        backupDirectoryURL = resolvedURL.map { $0.deletingLastPathComponent().appendingPathComponent($0.deletingPathExtension().lastPathComponent + "-Backups", isDirectory: true) }
        preferencesURL = resolvedURL?.deletingPathExtension().appendingPathExtension("preferences.json")
        if let preferencesURL, FileManager.default.fileExists(atPath: preferencesURL.path) {
            // Never replace an unreadable preferences file with defaults.
            preferences = try JSONDecoder().decode(JournalPreferences.self, from: Data(contentsOf: preferencesURL))
        } else if usesLegacyPreferences, let data = UserDefaults.standard.data(forKey: "journal.preferences"), let saved = try? JSONDecoder().decode(JournalPreferences.self, from: data) {
            preferences = saved
        } else { preferences = JournalPreferences() }
        let configuration: ModelConfiguration
        if demo { configuration = ModelConfiguration(schema: Self.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none) }
        else {
            guard let resolvedURL else { throw JournalError(message: "Yerel günlük konumu belirlenemedi.") }
            try FileManager.default.createDirectory(at: resolvedURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            configuration = ModelConfiguration(schema: Self.schema, url: resolvedURL, cloudKitDatabase: .none)
        }
        // A failed open is reported to the user. There is intentionally no empty-store fallback.
        container = try ModelContainer(for: Self.schema, migrationPlan: JournalMigrationPlan.self, configurations: configuration)
        context = ModelContext(container); context.autosaveEnabled = false
        try refresh()
        if instruments.isEmpty {
            for symbol in Catalog.instruments { context.insert(Instrument(symbol: symbol)) }
            try context.save(); try refresh()
        }
        if workspace.accounts.isEmpty {
            var initial = WorkspaceState()
            initial.accounts = [TradingAccount(id: TradingAccount.legacyID, name: "Eski günlük / varsayılan", currency: preferences.currency, startingBalance: preferences.accountSize)]
            try persistWorkspace(initial); try context.save(); try refresh()
        }
        if demo { try DemoData.populate(self) }
        else {
            reloadBackupMetadata()
            ensureDailyRecoverySnapshot()
        }
    }
    static func defaultStoreURL() throws -> URL {
        let folder = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("LiquidityEdge", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("Journal.store")
    }
    func refresh() throws {
        if let document = try context.fetch(FetchDescriptor<WorkspaceDocument>()).first {
            workspace = try JSONDecoder().decode(WorkspaceState.self, from: document.payload)
        }
        let fetched = try context.fetch(FetchDescriptor<Trade>(sortBy: [SortDescriptor(\.date, order: .reverse)]))
        let decoded: [TradeRecord]
        if fetched.count >= 64 && HardwareProfile.coreCount >= 4 {
            // Copy raw Data blobs on MainActor, then decode TradeRecord JSON in parallel across Apple Silicon cores
            let payloads = fetched.map(\.recordData)
            let rawResults = UnsafeMutableBufferPointer<Result<TradeRecord, Error>?>.allocate(capacity: payloads.count)
            rawResults.initialize(repeating: nil)
            defer { rawResults.deinitialize(); rawResults.deallocate() }
            let box = ParallelBuffer(rawResults)
            let workers = min(HardwareProfile.coreCount, max(1, payloads.count / 16))
            let chunk = (payloads.count + workers - 1) / workers
            DispatchQueue.concurrentPerform(iterations: workers) { w in
                let start = w * chunk
                let end = min(payloads.count, start + chunk)
                guard start < end else { return }
                let decoder = JSONDecoder()
                let buffer = box.value
                for i in start..<end {
                    buffer[i] = Result { try decoder.decode(TradeRecord.self, from: payloads[i]) }
                }
            }
            var parsed: [TradeRecord] = []
            parsed.reserveCapacity(payloads.count)
            for i in 0..<payloads.count {
                parsed.append(try rawResults[i]!.get())
            }
            decoded = parsed
        } else {
            decoded = try fetched.map { try $0.record() }
        }
        models = Dictionary(uniqueKeysWithValues: fetched.map { ($0.id, $0) }); trades = decoded
        setups = try context.fetch(FetchDescriptor<Setup>(sortBy: [SortDescriptor(\.name)]))
        instruments = try context.fetch(FetchDescriptor<Instrument>(sortBy: [SortDescriptor(\.symbol)]))
        customRules = try context.fetch(FetchDescriptor<CustomRule>(sortBy: [SortDescriptor(\.name)]))
        reviews = try context.fetch(FetchDescriptor<Review>(sortBy: [SortDescriptor(\.date, order: .reverse)]))
        rebuildWorkspaceCaches()
        revision += 1
    }
    func model(_ id: UUID) -> Trade? { models[id] }
    func commit(_ operation: () throws -> Void) throws {
        do {
            try operation()
            // Decode the view snapshot before committing, so a malformed
            // record cannot be persisted and then reported as an unsuccessful save.
            try refresh()
            try context.save()
        } catch { context.rollback(); try? refresh(); throw error }
        ensureDailyRecoverySnapshot()
    }
    func save(_ record: TradeRecord, screenshots: [ScreenshotDraft], accountID: UUID? = nil) throws {
        if let error = record.validationError { throw JournalError(message: error) }
        let assigned = accountID ?? (models[record.id] == nil ? selectedAccount.id : self.accountID(for: record.id))
        guard workspace.accounts.contains(where: { $0.id == assigned }) else { throw JournalError(message: "Hesap bulunamadı.") }
        try commit {
            let model = try upsert(record)
            var next = workspace; next.assignments[record.id] = assigned; try persistWorkspace(next)
            let retained = Set(screenshots.map(\.id))
            for shot in model.screenshots where !retained.contains(shot.id) { context.delete(shot) }
            for shot in screenshots {
                if let existing = model.screenshots.first(where: { $0.id == shot.id }) {
                    existing.category = shot.category; existing.annotationData = try JSONEncoder().encode(shot.annotations)
                } else {
                    let image = TradeScreenshot(id: shot.id, name: shot.name, category: shot.category, imageData: shot.imageData, thumbnailData: shot.thumbnailData, annotationData: try JSONEncoder().encode(shot.annotations))
                    context.insert(image); image.trade = model
                }
            }
        }
    }
    func saveBatch(_ records: [TradeRecord], accountID: UUID? = nil) throws {
        guard !records.isEmpty else { return }
        for record in records { if let error = record.validationError { throw JournalError(message: error) } }
        let assigned = accountID ?? selectedAccount.id
        guard workspace.accounts.contains(where: { $0.id == assigned }) else { throw JournalError(message: "Hesap bulunamadı.") }
        try commit {
            var next = workspace
            for record in records {
                _ = try upsert(record)
                next.assignments[record.id] = assigned
            }
            try persistWorkspace(next)
        }
    }
    @discardableResult func upsert(_ record: TradeRecord) throws -> Trade {
        if let message = record.validationError { throw JournalError(message: message) }
        let model: Trade
        if let existing = models[record.id] { model = existing; try model.update(record) }
        else { model = try Trade(record: record); context.insert(model); models[record.id] = model }
        model.setup = setups.first { $0.id == record.setupID }
        for violation in model.violations { context.delete(violation) }
        for name in Set(record.brokenRules) { let violation = RuleViolation(name: name); context.insert(violation); violation.trade = model }
        let tags = try context.fetch(FetchDescriptor<TradeTag>())
        model.tags = Array(Set(record.tags)).sorted().map { name in
            if let existing = tags.first(where: { $0.name == name }) { return existing }
            let tag = TradeTag(name: name); context.insert(tag); return tag
        }
        return model
    }
    func deleteTrade(_ id: UUID) throws {
        guard let trade = models[id] else { return }
        try createRecoverySnapshot(reason: "before-delete-trade")
        try commit {
            var next = workspace; next.assignments[id] = nil; next.supplements[id] = nil
            try persistWorkspace(next); context.delete(trade)
        }
    }
    func deleteSetup(_ setup: Setup) throws {
        try createRecoverySnapshot(reason: "before-delete-setup")
        try commit {
            for trade in trades where trade.setupID == setup.id { var changed = trade; changed.setupID = nil; changed.setupName = "Unassigned"; try upsert(changed) }
            context.delete(setup)
        }
    }
    func savePreferences() throws {
        guard preferences.accountSize > 0, preferences.accountSize.isFinite, preferences.defaultRiskPercent >= 0, preferences.defaultRiskPercent <= 100, TimeZone(identifier: preferences.timezone) != nil, preferences.currency.count == 3 else { throw JournalError(message: "Check account size, risk percentage, three-letter currency and time zone.") }
        let encoded = try JSONEncoder().encode(preferences)
        if let preferencesURL { try encoded.write(to: preferencesURL, options: .atomic) }
        if usesLegacyPreferences { UserDefaults.standard.set(encoded, forKey: "journal.preferences") }
        rebuildWorkspaceCaches()
        revision += 1
    }
    /// A portable, immutable snapshot. Snapshots live alongside the database and
    /// are never pruned automatically; they survive application replacement.
    @discardableResult func createRecoverySnapshot(reason: String = "manual") throws -> URL? {
        guard let backupDirectoryURL else { return nil }
        try FileManager.default.createDirectory(at: backupDirectoryURL, withIntermediateDirectories: true)
        let archive = try BackupService.archive(self)
        let data = try BackupService.encode(archive)
        let stamp = ISO8601DateFormatter().string(from: archive.createdAt).replacingOccurrences(of: ":", with: "-")
        let safeReason = reason.filter { $0.isLetter || $0.isNumber || $0 == "-" }
        let file = backupDirectoryURL.appendingPathComponent("journal-\(Self.backupDay(archive.createdAt))-\(safeReason)-\(stamp)-\(UUID().uuidString).json")
        try data.write(to: file, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        lastBackupDate = archive.createdAt
        backupErrorMessage = nil
        return file
    }
    private static let dayFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter
    }()
    private static func backupDay(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }
    private func reloadBackupMetadata() {
        guard let backupDirectoryURL else { return }
        let files = (try? FileManager.default.contentsOfDirectory(at: backupDirectoryURL, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles])) ?? []
        lastBackupDate = files.filter { $0.pathExtension == "json" }.compactMap { try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate }.max()
    }
    private func ensureDailyRecoverySnapshot() {
        guard let backupDirectoryURL, !trades.isEmpty || !setups.isEmpty || !reviews.isEmpty || !customRules.isEmpty else { return }
        let today = Self.backupDay(Date())
        guard dailyBackupDay != today else { return }
        let prefix = "journal-\(today)-daily-"
        let names = (try? FileManager.default.contentsOfDirectory(atPath: backupDirectoryURL.path)) ?? []
        if names.contains(where: { $0.hasPrefix(prefix) && $0.hasSuffix(".json") }) { dailyBackupDay = today; return }
        do { try createRecoverySnapshot(reason: "daily"); dailyBackupDay = today }
        catch { backupErrorMessage = "Günlük kaydedildi, ancak yerel kurtarma kopyası oluşturulamadı: " + error.localizedDescription }
    }
    func report(_ error: Error) { errorMessage = error.localizedDescription }
}
