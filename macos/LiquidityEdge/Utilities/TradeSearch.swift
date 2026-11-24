import Foundation

enum TradeSearch {
    private static func normalize(_ value: String) -> String {
        value.lowercased().replacingOccurrences(of: "ı", with: "i").folding(options: .diacriticInsensitive, locale: L10n.locale)
    }

    private struct SpecialPhrase {
        let tokens: [String]
        let predicate: (TradeRecord) -> Bool
    }

    private static let specialPhrases: [SpecialPhrase] = [
        SpecialPhrase(tokens: ["kuralsiz", "kazanc"]) { $0.classification == .invalidWinner },
        SpecialPhrase(tokens: ["kuralsiz", "zarar"]) { $0.classification == .invalidLoser },
        SpecialPhrase(tokens: ["kuralli", "kazanc"]) { $0.classification == .validWinner },
        SpecialPhrase(tokens: ["kuralli", "zarar"]) { $0.classification == .validLoser },
        SpecialPhrase(tokens: ["yalniz", "crt"]) { $0.hasCRT && !$0.hasSSMT && !$0.hasTSMO && !$0.hasQT && !$0.hasMMXM },
        SpecialPhrase(tokens: ["ssmt", "yok"]) { !$0.hasSSMT },
        SpecialPhrase(tokens: ["tsmo", "yok"]) { !$0.hasTSMO },
        SpecialPhrase(tokens: ["kuralli"]) { $0.compliant },
        SpecialPhrase(tokens: ["kuralsiz"]) { !$0.compliant },
        SpecialPhrase(tokens: ["kazanc"]) { $0.netPnL >= 0.005 },
        SpecialPhrase(tokens: ["zarar"]) { $0.netPnL <= -0.005 },
        SpecialPhrase(tokens: ["invalid", "winner"]) { $0.classification == .invalidWinner },
        SpecialPhrase(tokens: ["invalid", "loser"]) { $0.classification == .invalidLoser },
        SpecialPhrase(tokens: ["valid", "winner"]) { $0.classification == .validWinner },
        SpecialPhrase(tokens: ["valid", "loser"]) { $0.classification == .validLoser },
        SpecialPhrase(tokens: ["crt", "only"]) { $0.hasCRT && !$0.hasSSMT && !$0.hasTSMO && !$0.hasQT && !$0.hasMMXM },
        SpecialPhrase(tokens: ["no", "ssmt"]) { !$0.hasSSMT },
        SpecialPhrase(tokens: ["no", "tsmo"]) { !$0.hasTSMO },
        SpecialPhrase(tokens: ["ssmt"]) { $0.hasSSMT },
        SpecialPhrase(tokens: ["tsmo"]) { $0.hasTSMO },
        SpecialPhrase(tokens: ["crt"]) { $0.hasCRT },
        SpecialPhrase(tokens: ["qt"]) { $0.qt.enabled },
        SpecialPhrase(tokens: ["mmxm"]) { $0.mmxm.model != "None" },
        SpecialPhrase(tokens: ["loser"]) { $0.netPnL <= -0.005 },
        SpecialPhrase(tokens: ["winner"]) { $0.netPnL >= 0.005 }
    ]

    struct PreparedQuery {
        let predicates: [(TradeRecord) -> Bool]
        let remainingTokens: [String]
        let isEmpty: Bool

        init(_ raw: String) {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                predicates = []; remainingTokens = []; isEmpty = true
                return
            }
            var tokens = TradeSearch.normalize(trimmed).split(whereSeparator: { $0.isWhitespace }).map(String.init)
            var matched: [(TradeRecord) -> Bool] = []
            for phrase in TradeSearch.specialPhrases {
                let pCount = phrase.tokens.count
                guard tokens.count >= pCount else { continue }
                for start in 0...(tokens.count - pCount) {
                    var ok = true
                    for offset in 0..<pCount where tokens[start + offset] != phrase.tokens[offset] { ok = false; break }
                    if ok {
                        matched.append(phrase.predicate)
                        tokens.removeSubrange(start..<(start + pCount))
                        break
                    }
                }
            }
            predicates = matched
            remainingTokens = tokens
            isEmpty = false
        }

        func matches(_ trade: TradeRecord) -> Bool {
            guard !isEmpty else { return true }
            for pred in predicates where !pred(trade) { return false }
            guard !remainingTokens.isEmpty else { return true }
            let aliases = trade.instrument.uppercased() == "XAUUSD" ? "gold altin xauusd" : trade.instrument
            let localized = ([trade.direction, trade.session, trade.classification.rawValue] + trade.brokenRules + trade.confirmations + trade.emotional.emotions).map(L10n.text)
            let haystack = TradeSearch.normalize(([trade.instrument, aliases, trade.direction, trade.session, trade.setupName, trade.grade, trade.bias, trade.biasRelation, trade.narrative, trade.newsDriver, trade.qt.profile, trade.qt.trueOpenAnchor, trade.qt.trueOpenLocation, trade.qt.dailyQuarter, trade.qt.higherQuarter, trade.entryTimeframe, trade.drawOnLiquidity, trade.notes.thesis, trade.notes.lesson, trade.classification.rawValue] + trade.tags + trade.brokenRules + trade.confirmations + trade.emotional.emotions + localized).joined(separator: " "))
            return remainingTokens.allSatisfy { haystack.contains($0) }
        }
    }

    static func matches(_ trade: TradeRecord, query: String) -> Bool {
        PreparedQuery(query).matches(trade)
    }
}
struct TradeFilter {
    var query = ""
    var from: Date?, to: Date?
    var facets: [AnalysisDimension: String] = [:]
    func apply(_ trades: [TradeRecord], calendar: Calendar) -> [TradeRecord] {
        let prepared = TradeSearch.PreparedQuery(query)
        let startBound = from.map { calendar.startOfDay(for: $0) }
        let endBound = to.flatMap { calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: $0)) }
        let activeFacets = facets.filter { !$0.value.isEmpty }
        if prepared.isEmpty && startBound == nil && endBound == nil && activeFacets.isEmpty { return trades }
        return trades.filter { t in
            if let startBound, t.date < startBound { return false }
            if let endBound, t.date >= endBound { return false }
            guard prepared.matches(t) else { return false }
            return activeFacets.allSatisfy { dimension, value in dimension.keys(t, calendar: calendar).contains(value) }
        }
    }
}
