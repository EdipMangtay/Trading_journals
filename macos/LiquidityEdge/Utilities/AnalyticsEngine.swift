import Foundation

struct Performance: Equatable {
    var count = 0, wins = 0, losses = 0, rCount = 0
    var netPnL = 0.0, totalR = 0.0, grossProfit = 0.0, grossLoss = 0.0
    var averageWinner = 0.0, averageLoser = 0.0, averageWinningR: Double?
    var bestTrade = 0.0, worstTrade = 0.0, maxDrawdown = 0.0
    var currentWinStreak = 0, currentLossStreak = 0, longestWinStreak = 0, longestLossStreak = 0
    var compliance = 0.0, executionScore = 0.0, aPlusWinRate: Double?, averageDuration: Double?
    var winRate: Double { count > 0 ? Double(wins) / Double(count) * 100 : 0 }
    var lossRate: Double { count > 0 ? Double(losses) / Double(count) * 100 : 0 }
    var profitFactor: Double? { grossLoss > 0 ? grossProfit / grossLoss : nil }
    var expectancy: Double { count > 0 ? netPnL / Double(count) : 0 }
    var averageR: Double? { rCount > 0 ? totalR / Double(rCount) : nil }
    var recoveryFactor: Double? { maxDrawdown > 0 ? netPnL / maxDrawdown : nil }
    var payoffRatio: Double? { averageLoser < 0 ? averageWinner / abs(averageLoser) : nil }
}
struct CurvePoint: Identifiable {
    var id: Int, date: Date, equity: Double, r: Double, drawdown: Double, rollingWinRate: Double
}
struct MetricGroup: Identifiable {
    var name: String, performance: Performance
    var id: String { name }
}
enum AnalysisDimension: String, CaseIterable, Identifiable {
    case setup = "Setup", instrument = "Instrument", session = "Session", day = "Day of week", hour = "Hour", direction = "Direction", quarter = "QT quarter", mmxm = "MMXM", ssmt = "SSMT", tsmo = "TSMO", crt = "CRT", sweep = "Liquidity taken", bias = "HTF alignment", timeframe = "Entry timeframe", grade = "Grade", compliance = "Rule compliance", emotion = "Emotion", classification = "Classification", qt = "QT validity", liquidity = "Draw on liquidity"
    var id: String { rawValue }
    func keys(_ t: TradeRecord, calendar: Calendar) -> [String] {
        switch self {
        case .setup: return [t.setupName]
        case .instrument: return [t.instrument]
        case .session: return [t.session]
        case .day: return [calendar.weekdaySymbols[calendar.component(.weekday, from: t.date) - 1]]
        case .hour: return [String(format: "%02d:00", calendar.component(.hour, from: t.date))]
        case .direction: return [t.direction]
        case .quarter: return [t.qt.enabled ? t.qt.dailyQuarter : "No QT"]
        case .mmxm: return [t.mmxm.model]
        case .ssmt: return [t.hasSSMT ? "Valid SSMT" : "Without valid SSMT"]
        case .tsmo: return [t.hasTSMO ? "Valid TSMO" : "Without valid TSMO"]
        case .crt: return [t.hasCRT ? "Confirmed CRT" : "Without confirmed CRT"]
        case .sweep: return t.liquidityTaken.isEmpty ? ["Unspecified"] : t.liquidityTaken
        case .bias: return [t.htfAligned ? "Aligned" : "Not aligned"]
        case .timeframe: return [t.entryTimeframe]
        case .grade: return [t.grade]
        case .compliance: return [t.compliant ? "Fully valid" : "Rule break"]
        case .emotion: return t.emotional.emotions.isEmpty ? ["Unspecified"] : t.emotional.emotions
        case .classification: return [t.classification.rawValue]
        case .qt: return [t.hasQT ? "Valid & aligned" : "Not valid / aligned"]
        case .liquidity: return [t.drawOnLiquidity.isEmpty ? "Unspecified" : t.drawOnLiquidity]
        }
    }
}
struct EdgeCombination: Identifiable {
    var name: String, performance: Performance
    var id: String { name }
    var sampleLabel: String { performance.count < 30 ? "LOW SAMPLE SIZE" : performance.count < 50 ? "30+ SAMPLES" : "50+ SAMPLES" }
}
struct Comparison: Identifiable {
    var title: String, left: MetricGroup, right: MetricGroup
    var id: String { title }
}
struct MonthlyProcess: Identifiable {
    var date: Date, performance: Performance
    var id: Date { date }
}
enum AnalyticsEngine {
    @inline(__always)
    private static func compareUUID(_ a: UUID, _ b: UUID) -> Bool {
        withUnsafeBytes(of: a.uuid) { lhs in
            withUnsafeBytes(of: b.uuid) { rhs in
                for i in 0..<16 {
                    if lhs[i] != rhs[i] { return lhs[i] < rhs[i] }
                }
                return false
            }
        }
    }

    static func ordered(_ trades: [TradeRecord]) -> [TradeRecord] {
        guard trades.count > 1 else { return trades }
        // Fast path: check if already sorted ascending before allocating a sorted copy
        var isSorted = true
        for i in 1..<trades.count {
            let prev = trades[i - 1], curr = trades[i]
            if prev.date > curr.date || (prev.date == curr.date && compareUUID(curr.id, prev.id)) {
                isSorted = false
                break
            }
        }
        if isSorted { return trades }
        return trades.sorted { $0.date == $1.date ? compareUUID($0.id, $1.id) : $0.date < $1.date }
    }

    static func performance(_ trades: [TradeRecord]) -> Performance {
        var p = Performance()
        p.count = trades.count
        guard !trades.isEmpty else { return p }
        var equity = 0.0, peak = 0.0, valid = 0
        var winRSum = 0.0, winRCount = 0
        var durationSum = 0.0, durationCount = 0
        var best = -Double.infinity, worst = Double.infinity
        var aPlusCount = 0, aPlusWins = 0
        for t in ordered(trades) {
            let n = t.netPnL
            p.netPnL += n
            if n > best { best = n }
            if n < worst { worst = n }
            if n >= 0.005 {
                p.wins += 1; p.grossProfit += n
                p.currentWinStreak += 1; p.currentLossStreak = 0
                if let r = t.rMultiple { winRSum += r; winRCount += 1 }
            } else if n <= -0.005 {
                p.losses += 1; p.grossLoss += abs(n)
                p.currentLossStreak += 1; p.currentWinStreak = 0
            } else { p.currentWinStreak = 0; p.currentLossStreak = 0 }
            if p.currentWinStreak > p.longestWinStreak { p.longestWinStreak = p.currentWinStreak }
            if p.currentLossStreak > p.longestLossStreak { p.longestLossStreak = p.currentLossStreak }
            if let r = t.rMultiple { p.totalR += r; p.rCount += 1 }
            equity += n
            if equity > peak { peak = equity }
            let dd = peak - equity
            if dd > p.maxDrawdown { p.maxDrawdown = dd }
            if t.compliant { valid += 1 }
            p.executionScore += t.scores.overall
            if let duration = t.duration, duration >= 0 { durationSum += duration; durationCount += 1 }
            if t.grade == "A+" {
                aPlusCount += 1
                if n >= 0.005 { aPlusWins += 1 }
            }
        }
        p.averageWinner = p.wins > 0 ? p.grossProfit / Double(p.wins) : 0
        p.averageLoser = p.losses > 0 ? -p.grossLoss / Double(p.losses) : 0
        p.bestTrade = best.isFinite ? best : 0
        p.worstTrade = worst.isFinite ? worst : 0
        p.compliance = Double(valid) / Double(p.count) * 100
        p.executionScore /= Double(p.count)
        p.averageWinningR = winRCount == 0 ? nil : winRSum / Double(winRCount)
        p.averageDuration = durationCount == 0 ? nil : durationSum / Double(durationCount)
        p.aPlusWinRate = aPlusCount == 0 ? nil : Double(aPlusWins) / Double(aPlusCount) * 100
        return p
    }

    static func curve(_ trades: [TradeRecord]) -> [CurvePoint] {
        let sorted = ordered(trades)
        guard let first = sorted.first else { return [] }
        var result: [CurvePoint] = []
        result.reserveCapacity(sorted.count + 1)
        result.append(CurvePoint(id: 0, date: first.date.addingTimeInterval(-1), equity: 0, r: 0, drawdown: 0, rollingWinRate: 0))
        var equity = 0.0, r = 0.0, peak = 0.0
        var ring = Array(repeating: false, count: 20)
        var ringHead = 0, windowCount = 0, windowWins = 0
        for (index, t) in sorted.enumerated() {
            equity += t.netPnL; r += t.rMultiple ?? 0
            if equity > peak { peak = equity }
            let isWin = t.netPnL >= 0.005
            if windowCount == 20 {
                if ring[ringHead] { windowWins -= 1 }
            } else {
                windowCount += 1
            }
            ring[ringHead] = isWin
            if isWin { windowWins += 1 }
            ringHead = (ringHead + 1) % 20
            result.append(CurvePoint(id: index + 1, date: t.date, equity: equity, r: r, drawdown: equity - peak, rollingWinRate: Double(windowWins) / Double(windowCount) * 100))
        }
        return result
    }

    static func groups(_ trades: [TradeRecord], by dimension: AnalysisDimension, calendar: Calendar) -> [MetricGroup] {
        var buckets: [String: [TradeRecord]] = [:]
        for t in trades {
            let keys = dimension.keys(t, calendar: calendar)
            if keys.count == 1 {
                buckets[keys[0], default: []].append(t)
            } else {
                for key in Set(keys) { buckets[key, default: []].append(t) }
            }
        }
        return buckets.map { MetricGroup(name: $0.key, performance: performance($0.value)) }.sorted { $0.name < $1.name }
    }

    static func comparisons(_ trades: [TradeRecord]) -> [Comparison] {
        func compare(_ title: String, _ a: String, _ b: String, _ left: (TradeRecord) -> Bool, _ right: (TradeRecord) -> Bool) -> Comparison {
            Comparison(title: title, left: MetricGroup(name: a, performance: performance(trades.filter(left))), right: MetricGroup(name: b, performance: performance(trades.filter(right))))
        }
        return [
            compare("SSMT contribution", "With valid SSMT", "Without valid SSMT", { $0.hasSSMT }, { !$0.hasSSMT }),
            compare("TSMO contribution", "With valid TSMO", "Without valid TSMO", { $0.hasTSMO }, { !$0.hasTSMO }),
            compare("Quarter alignment", "QT aligned", "QT not aligned", { $0.qt.enabled && $0.qt.aligned }, { $0.qt.enabled && !$0.qt.aligned }),
            compare("Liquidity sweep", "Valid sweep", "No valid sweep", { $0.sweepValid }, { !$0.sweepValid }),
            compare("CRT × SSMT", "CRT + SSMT", "CRT without SSMT", { $0.hasCRT && $0.hasSSMT }, { $0.hasCRT && !$0.hasSSMT }),
            compare("MMXM × QT", "MMXM + QT", "MMXM without QT", { $0.hasMMXM && $0.hasQT }, { $0.hasMMXM && !$0.hasQT }),
            compare("Process advantage", "Fully valid trades", "Rule break trades", { $0.compliant }, { !$0.compliant })
        ]
    }

    private static let modelNames = ["QT", "MMXM", "SSMT", "TSMO", "CRT"]
    private static let multiModelMasks: [(Int, String)] = (1..<32).compactMap { mask in
        guard mask.nonzeroBitCount >= 2 else { return nil }
        let label = (0..<5).compactMap { (mask & (1 << $0)) != 0 ? modelNames[$0] : nil }.joined(separator: " + ")
        return (mask, label)
    }
    private static let singleModelMasks: [(Int, String)] = (0..<5).map { (1 << $0, modelNames[$0] + " Only") }

    static func edgeMatrix(_ trades: [TradeRecord]) -> [EdgeCombination] {
        var groups: [String: [TradeRecord]] = [:]
        for t in trades {
            let bits = (t.hasQT ? 1 : 0) | (t.hasMMXM ? 2 : 0) | (t.hasSSMT ? 4 : 0) | (t.hasTSMO ? 8 : 0) | (t.hasCRT ? 16 : 0)
            guard bits != 0 else { continue }
            if bits.nonzeroBitCount == 1 {
                for (mask, name) in singleModelMasks where bits == mask {
                    groups[name, default: []].append(t)
                    break
                }
            } else {
                for (mask, name) in multiModelMasks where (bits & mask) == mask {
                    groups[name, default: []].append(t)
                }
            }
        }
        return groups.map { EdgeCombination(name: $0.key, performance: performance($0.value)) }.sorted { $0.performance.count == $1.performance.count ? $0.name < $1.name : $0.performance.count > $1.performance.count }
    }
    static func mistakes(_ trades: [TradeRecord]) -> [MetricGroup] {
        var groups: [String: [TradeRecord]] = [:]
        for t in trades { for rule in Set(t.brokenRules) { groups[rule, default: []].append(t) } }
        return groups.map { MetricGroup(name: $0.key, performance: performance($0.value)) }.sorted { $0.performance.count > $1.performance.count }
    }
    static func monthlyProcess(_ trades: [TradeRecord], calendar: Calendar) -> [MonthlyProcess] {
        let groups = Dictionary(grouping: trades) { calendar.dateInterval(of: .month, for: $0.date)!.start }
        return groups.map { MonthlyProcess(date: $0.key, performance: performance($0.value)) }.sorted { $0.date < $1.date }
    }
    static func correlation(_ points: [(Double, Double)]) -> Double? {
        guard points.count >= 3 else { return nil }
        let n = Double(points.count), mx = points.map { $0.0 }.reduce(0,+) / n, my = points.map { $0.1 }.reduce(0,+) / n
        let dx = points.map { $0.0 - mx }, dy = points.map { $0.1 - my }
        let denominator = sqrt(dx.map { $0 * $0 }.reduce(0,+) * dy.map { $0 * $0 }.reduce(0,+))
        guard denominator > 0 else { return nil }
        return zip(dx, dy).map(*).reduce(0,+) / denominator
    }
}
