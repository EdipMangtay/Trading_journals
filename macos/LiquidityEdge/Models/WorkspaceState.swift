import Foundation

struct TradingAccount: Codable, Identifiable, Equatable {
    static let legacyID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    var id = UUID()
    var name = "Yeni hesap"
    var currency = "USD"
    var startingBalance = 50000.0
    var category = "Personal"
    var active = true
    var rules = RiskRules()
}
struct RiskRules: Codable, Equatable {
    var profitTarget: Double?
    var dailyLoss: Double?
    var maximumLoss: Double?
    var drawdownMethod = "Static"
    var minimumDays: Int?
    var consistencyPercent: Double?
    var riskPerTrade: Double?
    var dailyTradeCount: Int?
}
struct ExecutionFill: Codable, Identifiable, Equatable {
    var id = UUID()
    var date = Date()
    var side = "Entry"
    var quantity = 1.0
    var price = 0.0
    var fee = 0.0
    var expectedPrice: Double?
}
struct ChecklistAnswer: Codable, Identifiable, Equatable {
    var id = UUID()
    var label: String
    var phase = "Öncesi"
    var answer: Bool?
}
struct TradeSupplement: Codable, Equatable {
    var fills: [ExecutionFill] = []
    var pointValue = 1.0
    var tickSize = 0.01
    var checklist: [ChecklistAnswer] = []
}
struct ChecklistTemplate: Codable, Identifiable {
    var id = UUID()
    var name: String
    var setupID: UUID?
    var items: [ChecklistAnswer]
}
struct ResearchPreset: Codable, Identifiable {
    var id = UUID()
    var name: String
    var query: String
    var facets: [String: String]
    var from: Date?
    var to: Date?
    var filter: TradeFilter {
        TradeFilter(query: query, from: from, to: to, facets: Dictionary(uniqueKeysWithValues: facets.compactMap { key, value in AnalysisDimension(rawValue: key).map { ($0, value) } }))
    }
    init(name: String, filter: TradeFilter) {
        self.name = name; query = filter.query; from = filter.from; to = filter.to
        facets = Dictionary(uniqueKeysWithValues: filter.facets.map { ($0.key.rawValue, $0.value) })
    }
}
struct DailyPlan: Codable, Identifiable {
    var id = UUID()
    var accountID: UUID
    var date = Date()
    var scenarios = "", instruments = "", liquidity = "", focus = "", limits = "", objectives = ""
}
struct WorkspaceState: Codable {
    var accounts: [TradingAccount] = []
    var assignments: [UUID: UUID] = [:]
    var supplements: [UUID: TradeSupplement] = [:]
    var templates: [ChecklistTemplate] = []
    var presets: [ResearchPreset] = []
    var plans: [DailyPlan] = []
    var selectedAccountID = TradingAccount.legacyID
    var widgets = ["Risk & R", "Rolling", "Timing", "Recent", "Metrics"]
    var hiddenWidgets: [String] = []
    var compactRows = false
    var showProcess = true
    var showR = true

    func validate(tradeIDs: Set<UUID>? = nil) throws {
        func fail(_ text: String) throws { throw JournalError(message: text) }
        let ids = Set(accounts.map(\.id))
        guard ids.count == accounts.count, ids.contains(TradingAccount.legacyID), ids.contains(selectedAccountID) else { try fail("Hesap kimlikleri geçersiz."); return }
        for a in accounts {
            guard !a.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, a.currency.count == 3, a.currency.allSatisfy({ $0.isASCII && $0.isUppercase }), a.startingBalance.isFinite, a.startingBalance > 0 else { try fail("Hesap adı, para birimi ve başlangıç bakiyesini kontrol edin."); return }
            let r = a.rules
            guard [r.profitTarget, r.dailyLoss, r.maximumLoss, r.riskPerTrade].compactMap({ $0 }).allSatisfy({ $0.isFinite && $0 > 0 }), r.consistencyPercent.map({ $0.isFinite && $0 > 0 && $0 <= 100 }) ?? true, [r.minimumDays, r.dailyTradeCount].compactMap({ $0 }).allSatisfy({ $0 > 0 }), ["Static", "End of day", "Intraday equity"].contains(r.drawdownMethod) else { try fail("Risk sınırları pozitif olmalı; tutarlılık yüzdesi 0–100 aralığında olmalı."); return }
        }
        guard assignments.values.allSatisfy({ ids.contains($0) }), plans.allSatisfy({ ids.contains($0.accountID) }) else { try fail("Kayıt bulunmayan bir hesaba bağlı."); return }
        if let tradeIDs {
            guard Set(assignments.keys).isSubset(of: tradeIDs), Set(supplements.keys).isSubset(of: tradeIDs) else { try fail("Ek bilgiler bulunmayan bir işleme bağlı."); return }
        }
        for s in supplements.values {
            guard s.pointValue.isFinite, s.pointValue > 0, s.tickSize.isFinite, s.tickSize > 0, Set(s.fills.map(\.id)).count == s.fills.count, Set(s.checklist.map(\.id)).count == s.checklist.count else { try fail("Kontrat veya kayıt kimliği geçersiz."); return }
            for f in s.fills {
                guard f.quantity.isFinite, f.quantity > 0, f.price.isFinite, f.fee.isFinite, f.fee >= 0, f.expectedPrice?.isFinite ?? true, ["Entry", "Exit"].contains(f.side) else { try fail("Gerçekleşme fiyatı, miktarı veya masrafı geçersiz."); return }
            }
        }
        guard Set(presets.map(\.id)).count == presets.count, Set(templates.map(\.id)).count == templates.count, Set(plans.map(\.id)).count == plans.count else { try fail("Yinelenen çalışma alanı kaydı."); return }
    }
}
