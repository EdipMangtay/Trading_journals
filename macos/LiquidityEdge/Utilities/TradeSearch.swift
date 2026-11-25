import Foundation

enum TradeSearch {
    private static let haystackCache: NSCache<NSString, NSString> = {
        let cache = NSCache<NSString, NSString>()
        cache.countLimit = 8192
        return cache
    }()

    @inline(__always)
    private static func fnv1aMix(_ hash: inout UInt64, _ string: String) {
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001B3
        }
        hash ^= 0xFF
        hash &*= 0x100000001B3
    }

    private static func contentSignature(for trade: TradeRecord) -> String {
        var h: UInt64 = 0xCBF29CE484222325
        fnv1aMix(&h, trade.instrument)
        fnv1aMix(&h, trade.direction)
        fnv1aMix(&h, trade.session)
        fnv1aMix(&h, trade.setupName)
        fnv1aMix(&h, trade.grade)
        fnv1aMix(&h, trade.bias)
        fnv1aMix(&h, trade.biasRelation)
        fnv1aMix(&h, trade.narrative)
        fnv1aMix(&h, trade.newsDriver)
        fnv1aMix(&h, trade.qt.profile)
        fnv1aMix(&h, trade.qt.trueOpenAnchor)
        fnv1aMix(&h, trade.qt.trueOpenLocation)
        fnv1aMix(&h, trade.qt.dailyQuarter)
        fnv1aMix(&h, trade.qt.higherQuarter)
        fnv1aMix(&h, trade.entryTimeframe)
        fnv1aMix(&h, trade.drawOnLiquidity)
        fnv1aMix(&h, trade.notes.thesis)
        fnv1aMix(&h, trade.notes.lesson)
        fnv1aMix(&h, trade.classification.rawValue)
        for item in trade.tags { fnv1aMix(&h, item) }
        for item in trade.brokenRules { fnv1aMix(&h, item) }
        for item in trade.confirmations { fnv1aMix(&h, item) }
        for item in trade.emotional.emotions { fnv1aMix(&h, item) }
        return "\(trade.id.uuidString)-\(String(h, radix: 16))"
    }

    static func cachedHaystack(for trade: TradeRecord) -> String {
        let key = contentSignature(for: trade) as NSString
        if let hit = haystackCache.object(forKey: key) {
            return hit as String
        }
        let aliases = trade.instrument.uppercased() == "XAUUSD" ? "gold altin xauusd" : trade.instrument
        var parts: [String] = []
        parts.reserveCapacity(32 + trade.tags.count + trade.brokenRules.count * 2 + trade.confirmations.count * 2 + trade.emotional.emotions.count * 2)
        parts.append(trade.instrument)
        parts.append(aliases)
        parts.append(trade.direction)
        parts.append(L10n.text(trade.direction))
        parts.append(trade.session)
        parts.append(L10n.text(trade.session))
        parts.append(trade.setupName)
        parts.append(trade.grade)
        parts.append(trade.bias)
        parts.append(trade.biasRelation)
        parts.append(trade.narrative)
        parts.append(trade.newsDriver)
        parts.append(trade.qt.profile)
        parts.append(trade.qt.trueOpenAnchor)
        parts.append(trade.qt.trueOpenLocation)
        parts.append(trade.qt.dailyQuarter)
        parts.append(trade.qt.higherQuarter)
        parts.append(trade.entryTimeframe)
        parts.append(trade.drawOnLiquidity)
        parts.append(trade.notes.thesis)
        parts.append(trade.notes.lesson)
        parts.append(trade.classification.rawValue)
        parts.append(L10n.text(trade.classification.rawValue))
        parts.append(contentsOf: trade.tags)
        for item in trade.brokenRules { parts.append(item); parts.append(L10n.text(item)) }
        for item in trade.confirmations { parts.append(item); parts.append(L10n.text(item)) }
        for item in trade.emotional.emotions { parts.append(item); parts.append(L10n.text(item)) }
        let normalized = normalize(parts.joined(separator: " "))
        haystackCache.setObject(normalized as NSString, forKey: key)
        return normalized
    }

    static func prewarm(_ trades: [TradeRecord]) {
        guard !trades.isEmpty else { return }
        if trades.count >= 64 {
            DispatchQueue.concurrentPerform(iterations: trades.count) { i in
                _ = cachedHaystack(for: trades[i])
            }
        } else {
            for t in trades { _ = cachedHaystack(for: t) }
        }
    }

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
            let haystack = TradeSearch.cachedHaystack(for: trade)
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
    var isEmpty: Bool {
        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && from == nil && to == nil && facets.values.allSatisfy(\.isEmpty)
    }
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
