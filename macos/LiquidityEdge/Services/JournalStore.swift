import Foundation
import SwiftData
import Observation

struct JournalError: LocalizedError {
    var message: String
    var errorDescription: String? { message }
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
    var selectedAccount: TradingAccount { workspace.accounts.first { $0.id == workspace.selectedAccountID } ?? TradingAccount(id: TradingAccount.legacyID, name: "Eski günlük", currency: preferences.currency, startingBalance: preferences.accountSize) }
    var scopedTrades: [TradeRecord] { trades.filter { accountID(for: $0.id) == selectedAccount.id } }
    var accountCurrency: String { selectedAccount.currency }
    func accountID(for tradeID: UUID) -> UUID { workspace.assignments[tradeID] ?? TradingAccount.legacyID }
    func currency(for tradeID: UUID) -> String { workspace.accounts.first { $0.id == accountID(for: tradeID) }?.currency ?? preferences.currency }
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
        let decoded = try fetched.map { try $0.record() }
        models = Dictionary(uniqueKeysWithValues: fetched.map { ($0.id, $0) }); trades = decoded
        setups = try context.fetch(FetchDescriptor<Setup>(sortBy: [SortDescriptor(\.name)]))
        instruments = try context.fetch(FetchDescriptor<Instrument>(sortBy: [SortDescriptor(\.symbol)]))
        customRules = try context.fetch(FetchDescriptor<CustomRule>(sortBy: [SortDescriptor(\.name)]))
        reviews = try context.fetch(FetchDescriptor<Review>(sortBy: [SortDescriptor(\.date, order: .reverse)]))
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
    private static func backupDay(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.string(from: date)
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
