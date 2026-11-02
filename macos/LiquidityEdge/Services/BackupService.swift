import Foundation
import SwiftData
import AppKit

struct SetupArchive: Codable, Identifiable {
    var id: UUID, name: String, summary: String
    var playbookID: UUID
    var conditions: String, entry: String, invalidation: String, target: String, risk: String
    var images: [ScreenshotDraft]
}
struct ReviewArchive: Codable, Identifiable {
    var id: UUID, period: String, date: Date, worked: String, didNot: String, repeatNext: String, stop: String, adjustment: String
}
struct InstrumentArchive: Codable { var id: UUID, symbol: String, enabled: Bool }
struct RuleArchive: Codable { var id: UUID, name: String }
struct ScreenshotArchive: Codable { var tradeID: UUID, screenshot: ScreenshotDraft }
struct JournalBackup: Codable {
    var version = 1
    var createdAt = Date()
    var trades: [TradeRecord]
    var screenshots: [ScreenshotArchive]
    var setups: [SetupArchive]
    var reviews: [ReviewArchive]
    var instruments: [InstrumentArchive]
    var rules: [RuleArchive]
    var preferences: JournalPreferences
    var workspace: WorkspaceState?
}
enum BackupService {
    @MainActor static func archive(_ store: JournalStore, legacy: Bool = false) throws -> JournalBackup {
        let screenshots = try store.trades.flatMap { trade in try (store.model(trade.id)?.screenshots ?? []).map { ScreenshotArchive(tradeID: trade.id, screenshot: try ScreenshotDraft($0)) } }
        let setups = try store.setups.map { s in
            let p = s.playbook
            return SetupArchive(id: s.id, name: s.name, summary: s.summary, playbookID: p?.id ?? UUID(), conditions: p?.conditions ?? "", entry: p?.entryRules ?? "", invalidation: p?.invalidationRules ?? "", target: p?.targetRules ?? "", risk: p?.riskRules ?? "", images: try decodeImages(p?.idealImagesData ?? Data()))
        }
        return JournalBackup(version: legacy ? 1 : 2, trades: store.trades, screenshots: screenshots, setups: setups, reviews: store.reviews.map { ReviewArchive(id: $0.id, period: $0.period, date: $0.date, worked: $0.worked, didNot: $0.didNot, repeatNext: $0.repeatNext, stop: $0.stop, adjustment: $0.adjustment) }, instruments: store.instruments.map { InstrumentArchive(id: $0.id, symbol: $0.symbol, enabled: $0.enabled) }, rules: store.customRules.map { RuleArchive(id: $0.id, name: $0.name) }, preferences: store.preferences, workspace: legacy ? nil : store.workspace)
    }
    static func decodeImages(_ data: Data) throws -> [ScreenshotDraft] { data.isEmpty ? [] : try JSONDecoder().decode([ScreenshotDraft].self, from: data) }
    static func encode(_ archive: JournalBackup) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .millisecondsSince1970
        return try encoder.encode(archive)
    }
    static func decode(_ data: Data) throws -> JournalBackup {
        guard data.count <= 512_000_000 else { throw JournalError(message: "Backup exceeds the 512 MB import limit.") }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .millisecondsSince1970
        let backup = try decoder.decode(JournalBackup.self, from: data)
        try validate(backup); return backup
    }
    static func validate(_ backup: JournalBackup) throws {
        guard [1, 2].contains(backup.version), backup.version != 2 || backup.workspace != nil else { throw JournalError(message: "Unsupported or incomplete backup version \(backup.version).") }
        if let workspace = backup.workspace { try workspace.validate(tradeIDs: Set(backup.trades.map(\.id))) }
        func unique(_ ids: [UUID]) -> Bool { Set(ids).count == ids.count }
        guard unique(backup.trades.map(\.id)), unique(backup.setups.map(\.id)), unique(backup.setups.map(\.playbookID)), unique(backup.reviews.map(\.id)), unique(backup.screenshots.map { $0.screenshot.id }), unique(backup.instruments.map(\.id)), unique(backup.rules.map(\.id)) else { throw JournalError(message: "Backup contains duplicate identifiers.") }
        let tradeIDs = Set(backup.trades.map(\.id)), setupIDs = Set(backup.setups.map(\.id))
        for t in backup.trades {
            if let message = t.validationError { throw JournalError(message: "\(t.instrument): \(message)") }
            if let id = t.setupID, !setupIDs.contains(id) { throw JournalError(message: "Backup refers to a missing setup.") }
        }
        for s in backup.screenshots { guard tradeIDs.contains(s.tradeID) else { throw JournalError(message: "Screenshot refers to a missing trade.") } }
        for shot in backup.screenshots.map(\.screenshot) + backup.setups.flatMap(\.images) {
            guard shot.imageData.count <= 30_000_000, NSImage(data: shot.imageData) != nil, NSImage(data: shot.thumbnailData) != nil else { throw JournalError(message: "Backup contains an invalid image.") }
            for mark in shot.annotations {
                guard [mark.x, mark.y, mark.endX, mark.endY].allSatisfy({ $0.isFinite && (0...1).contains($0) }) else { throw JournalError(message: "Backup contains an invalid annotation.") }
            }
        }
        let p = backup.preferences
        guard p.accountSize.isFinite, p.accountSize > 0, p.defaultRiskPercent.isFinite, (0...100).contains(p.defaultRiskPercent), TimeZone(identifier: p.timezone) != nil, p.currency.count == 3 else { throw JournalError(message: "Backup contains invalid preferences.") }
    }
    @MainActor static func restore(_ backup: JournalBackup, into store: JournalStore) throws {
        try validate(backup)
        try store.createRecoverySnapshot(reason: "before-restore")
        let originalPreferences = store.preferences
        do {
            // Persist the already validated preferences before committing the model
            // transaction; a failed model save restores the original preferences.
            store.preferences = backup.preferences
            try store.savePreferences()
            try store.commit {
                if let incoming = backup.workspace {
                    var merged = store.workspace
                    for account in incoming.accounts {
                        merged.accounts.removeAll { $0.id == account.id }; merged.accounts.append(account)
                    }
                    merged.assignments.merge(incoming.assignments) { _, new in new }
                    merged.supplements.merge(incoming.supplements) { _, new in new }
                    for preset in incoming.presets { merged.presets.removeAll { $0.id == preset.id }; merged.presets.append(preset) }
                    for template in incoming.templates { merged.templates.removeAll { $0.id == template.id }; merged.templates.append(template) }
                    for plan in incoming.plans { merged.plans.removeAll { $0.id == plan.id }; merged.plans.append(plan) }
                    merged.widgets = incoming.widgets; merged.hiddenWidgets = incoming.hiddenWidgets
                    merged.compactRows = incoming.compactRows; merged.showProcess = incoming.showProcess; merged.showR = incoming.showR
                    try store.persistWorkspace(merged)
                }
                for archive in backup.setups {
                    let setup = store.setups.first { $0.id == archive.id } ?? Setup(id: archive.id, name: archive.name)
                    store.context.insert(setup); setup.name = archive.name; setup.summary = archive.summary
                    let book = setup.playbook ?? Playbook(id: archive.playbookID); store.context.insert(book); setup.playbook = book
                    book.conditions = archive.conditions; book.entryRules = archive.entry; book.invalidationRules = archive.invalidation; book.targetRules = archive.target; book.riskRules = archive.risk; book.idealImagesData = try JSONEncoder().encode(archive.images)
                }
                let allSetups = try store.context.fetch(FetchDescriptor<Setup>())
                for record in backup.trades {
                    let model = try store.upsert(record); model.setup = allSetups.first { $0.id == record.setupID }
                    for shot in model.screenshots { store.context.delete(shot) }
                }
                for archive in backup.screenshots {
                    let s = archive.screenshot
                    let shot = TradeScreenshot(id: s.id, name: s.name, category: s.category, imageData: s.imageData, thumbnailData: s.thumbnailData, annotationData: try JSONEncoder().encode(s.annotations))
                    store.context.insert(shot); shot.trade = store.model(archive.tradeID)
                }
                for r in backup.reviews {
                    let model = store.reviews.first { $0.id == r.id } ?? Review(id: r.id, period: r.period, date: r.date)
                    store.context.insert(model); model.period = r.period; model.date = r.date; model.worked = r.worked; model.didNot = r.didNot; model.repeatNext = r.repeatNext; model.stop = r.stop; model.adjustment = r.adjustment
                }
                for i in backup.instruments {
                    let model = store.instruments.first { $0.id == i.id } ?? store.instruments.first { $0.symbol == i.symbol } ?? Instrument(id: i.id, symbol: i.symbol)
                    store.context.insert(model); model.symbol = i.symbol; model.enabled = i.enabled
                }
                for r in backup.rules {
                    let model = store.customRules.first { $0.id == r.id } ?? CustomRule(id: r.id, name: r.name); store.context.insert(model); model.name = r.name
                }
            }
        } catch {
            store.preferences = originalPreferences
            try? store.savePreferences()
            throw error
        }
    }
    @MainActor static func importCSV(_ text: String, into store: JournalStore) throws -> Int {
        var records = try CSVCodec.decode(text)
        guard Set(records.map(\.id)).count == records.count else { throw JournalError(message: "CSV contains duplicate trade identifiers.") }
        for i in records.indices {
            if let message = records[i].validationError { throw JournalError(message: "Row \(i + 2): \(message)") }
            if let setup = store.setups.first(where: { $0.id == records[i].setupID || $0.name == records[i].setupName }) { records[i].setupID = setup.id; records[i].setupName = setup.name }
            else { records[i].setupID = nil }
        }
        if !records.isEmpty { try store.createRecoverySnapshot(reason: "before-csv-import") }
        try store.commit { for record in records { try store.upsert(record) } }
        return records.count
    }
}
