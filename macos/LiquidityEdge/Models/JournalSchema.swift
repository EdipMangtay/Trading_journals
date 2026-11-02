import SwiftData
import Foundation

enum JournalSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Trade.self, TradeScreenshot.self, TradeTag.self, Setup.self, Playbook.self, Review.self, RuleViolation.self, Instrument.self, CustomRule.self]
    }
}
enum JournalMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [JournalSchemaV1.self, JournalSchemaV2.self] }
    static var stages: [MigrationStage] { [.lightweight(fromVersion: JournalSchemaV1.self, toVersion: JournalSchemaV2.self)] }
}
enum JournalSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] { JournalSchemaV1.models + [WorkspaceDocument.self] }
}
@Model final class WorkspaceDocument {
    @Attribute(.unique) var key: String
    var payload: Data
    init(payload: Data) { key = "workspace-v6"; self.payload = payload }
}
