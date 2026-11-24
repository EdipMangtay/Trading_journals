import Foundation
import Observation

@MainActor @Observable final class TradeDraft {
    var record: TradeRecord
    var screenshots: [ScreenshotDraft] = []
    var accountID: UUID?
    var error: String?
    let isNew: Bool
    init(record: TradeRecord?) { self.record = record ?? TradeRecord(); isNew = record == nil }
    func loadAttachments(from store: JournalStore) {
        accountID = isNew ? store.selectedAccount.id : store.accountID(for: record.id)
        do { screenshots = try (store.model(record.id)?.screenshots ?? []).map(ScreenshotDraft.init) }
        catch { self.error = error.localizedDescription }
    }
    func calculateR() {
        guard let risk = record.riskDollars, risk > 0 else { error = "R hesaplamak için pozitif risk tutarı gir."; return }
        record.rMultiple = (record.netPnL / risk * 100).rounded() / 100
    }
    func applyRiskPercent(from accountBalance: Double) {
        guard let pct = record.riskPercent, pct >= 0, accountBalance > 0 else { return }
        record.riskDollars = (accountBalance * pct / 100 * 100).rounded() / 100
    }
    func applyRMultiple(_ r: Double) {
        record.rMultiple = r
        if let risk = record.riskDollars, risk > 0 {
            record.grossPnL = ((r * risk + record.fees) * 100).rounded() / 100
        }
    }
    func save(into store: JournalStore) -> Bool {
        do { try store.save(record, screenshots: screenshots, accountID: accountID); return true }
        catch { self.error = error.localizedDescription; return false }
    }
}
