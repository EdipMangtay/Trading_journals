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
    static let hourLabels: [String] = (0..<24).map { String(format: "%02d:00", $0) }
    func keys(_ t: TradeRecord, calendar: Calendar) -> [String] {
        switch self {
        case .setup: return [t.setupName]
        case .instrument: return [t.instrument]
        case .session: return [t.session.isEmpty ? "Unspecified" : t.session]
        case .day: return [calendar.weekdaySymbols[calendar.component(.weekday, from: t.date) - 1]]
        case .hour: return [Self.hourLabels[calendar.component(.hour, from: t.date)]]
        case .direction: return [t.direction]
        case .quarter: return [t.qt.enabled ? (t.qt.dailyQuarter.isEmpty ? "Unspecified" : t.qt.dailyQuarter) : "No QT"]
        case .mmxm: return [t.mmxm.model]
        case .ssmt: return [t.hasSSMT ? "Valid SSMT" : "Without valid SSMT"]
        case .tsmo: return [t.hasTSMO ? "Valid TSMO" : "Without valid TSMO"]
        case .crt: return [t.hasCRT ? "Confirmed CRT" : "Without confirmed CRT"]
        case .sweep: return t.liquidityTaken.isEmpty ? ["Unspecified"] : t.liquidityTaken
        case .bias: return [t.htfAligned ? "Aligned" : "Not aligned"]
        case .timeframe: return [t.entryTimeframe.isEmpty ? "Unspecified" : t.entryTimeframe]
        case .grade: return [t.grade.isEmpty ? "Unspecified" : t.grade]
        case .compliance: return [t.compliant ? "Fully valid" : "Rule break"]
        case .emotion: return t.emotional.emotions.isEmpty ? ["Unspecified"] : t.emotional.emotions
        case .classification: return [t.classification.rawValue]
        case .qt: return [t.hasQT ? "Valid & aligned" : "Not valid / aligned"]
        case .liquidity: return [t.drawOnLiquidity.isEmpty ? "Unspecified" : t.drawOnLiquidity]
        }
    }
    /// Fast zero-array single-key lookup for single-valued dimensions (18 of 20 dimensions).
    @inline(__always)
    func singleKey(_ t: TradeRecord, calendar: Calendar, weekdays: [String]) -> String? {
        switch self {
        case .setup: return t.setupName
        case .instrument: return t.instrument
        case .session: return t.session.isEmpty ? "Unspecified" : t.session
        case .day: return weekdays[calendar.component(.weekday, from: t.date) - 1]
        case .hour: return Self.hourLabels[calendar.component(.hour, from: t.date)]
        case .direction: return t.direction
        case .quarter: return t.qt.enabled ? (t.qt.dailyQuarter.isEmpty ? "Unspecified" : t.qt.dailyQuarter) : "No QT"
        case .mmxm: return t.mmxm.model
        case .ssmt: return t.hasSSMT ? "Valid SSMT" : "Without valid SSMT"
        case .tsmo: return t.hasTSMO ? "Valid TSMO" : "Without valid TSMO"
        case .crt: return t.hasCRT ? "Confirmed CRT" : "Without confirmed CRT"
        case .bias: return t.htfAligned ? "Aligned" : "Not aligned"
        case .timeframe: return t.entryTimeframe.isEmpty ? "Unspecified" : t.entryTimeframe
        case .grade: return t.grade.isEmpty ? "Unspecified" : t.grade
        case .compliance: return t.compliant ? "Fully valid" : "Rule break"
        case .classification: return t.classification.rawValue
        case .qt: return t.hasQT ? "Valid & aligned" : "Not valid / aligned"
        case .liquidity: return t.drawOnLiquidity.isEmpty ? "Unspecified" : t.drawOnLiquidity
        case .sweep, .emotion: return nil
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

    /// Zero-allocation in-place accumulator for pre-sorted TradeRecord streams.
    /// Eliminates copying ~500-byte TradeRecord structs into intermediate bucket arrays.
    private struct PerformanceAccumulator {
        var count = 0, wins = 0, losses = 0, rCount = 0
        var netPnL = 0.0, totalR = 0.0, grossProfit = 0.0, grossLoss = 0.0
        var best = -Double.infinity, worst = Double.infinity, maxDrawdown = 0.0
        var equity = 0.0, peak = 0.0
        var currentWinStreak = 0, currentLossStreak = 0, longestWinStreak = 0, longestLossStreak = 0
        var valid = 0, executionScore = 0.0
        var winRSum = 0.0, winRCount = 0
        var durationSum = 0.0, durationCount = 0
        var aPlusCount = 0, aPlusWins = 0

        @inline(__always)
        mutating func add(_ t: TradeRecord) {
            count += 1
            let n = t.netPnL
            netPnL += n
            if n > best { best = n }
            if n < worst { worst = n }
            if n >= 0.005 {
                wins += 1; grossProfit += n
                currentWinStreak += 1; currentLossStreak = 0
                if let r = t.rMultiple { winRSum += r; winRCount += 1 }
            } else if n <= -0.005 {
                losses += 1; grossLoss += abs(n)
                currentLossStreak += 1; currentWinStreak = 0
            } else {
                currentWinStreak = 0; currentLossStreak = 0
            }
            if currentWinStreak > longestWinStreak { longestWinStreak = currentWinStreak }
            if currentLossStreak > longestLossStreak { longestLossStreak = currentLossStreak }
            if let r = t.rMultiple { totalR += r; rCount += 1 }
            equity += n
            if equity > peak { peak = equity }
            let dd = peak - equity
            if dd > maxDrawdown { maxDrawdown = dd }
            if t.compliant { valid += 1 }
            executionScore += t.scores.overall
            if let duration = t.duration, duration >= 0 { durationSum += duration; durationCount += 1 }
            if t.grade == "A+" {
                aPlusCount += 1
                if n >= 0.005 { aPlusWins += 1 }
            }
        }

        func build() -> Performance {
            guard count > 0 else { return Performance() }
            var p = Performance()
            p.count = count; p.wins = wins; p.losses = losses; p.rCount = rCount
            p.netPnL = netPnL; p.totalR = totalR; p.grossProfit = grossProfit; p.grossLoss = grossLoss
            p.averageWinner = wins > 0 ? grossProfit / Double(wins) : 0
            p.averageLoser = losses > 0 ? -grossLoss / Double(losses) : 0
            p.bestTrade = best.isFinite ? best : 0
            p.worstTrade = worst.isFinite ? worst : 0
            p.maxDrawdown = maxDrawdown
            p.currentWinStreak = currentWinStreak; p.currentLossStreak = currentLossStreak
            p.longestWinStreak = longestWinStreak; p.longestLossStreak = longestLossStreak
            p.compliance = Double(valid) / Double(count) * 100
            p.executionScore = executionScore / Double(count)
            p.averageWinningR = winRCount == 0 ? nil : winRSum / Double(winRCount)
            p.averageDuration = durationCount == 0 ? nil : durationSum / Double(durationCount)
            p.aPlusWinRate = aPlusCount == 0 ? nil : Double(aPlusWins) / Double(aPlusCount) * 100
            return p
        }
    }

    static func performance(_ trades: [TradeRecord]) -> Performance {
        guard !trades.isEmpty else { return Performance() }
        var acc = PerformanceAccumulator()
        for t in ordered(trades) { acc.add(t) }
        return acc.build()
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
        guard !trades.isEmpty else { return [] }
        let sorted = ordered(trades)
        let weekdays = dimension == .day ? calendar.weekdaySymbols : []
        var buckets: [String: PerformanceAccumulator] = [:]
        buckets.reserveCapacity(16)
        if dimension != .sweep && dimension != .emotion {
            for t in sorted {
                if let key = dimension.singleKey(t, calendar: calendar, weekdays: weekdays) {
                    buckets[key, default: PerformanceAccumulator()].add(t)
                }
            }
        } else {
            for t in sorted {
                let raw = dimension == .sweep ? t.liquidityTaken : t.emotional.emotions
                if raw.isEmpty {
                    buckets["Unspecified", default: PerformanceAccumulator()].add(t)
                } else if raw.count == 1 {
                    buckets[raw[0], default: PerformanceAccumulator()].add(t)
                } else {
                    for key in Set(raw) {
                        buckets[key, default: PerformanceAccumulator()].add(t)
                    }
                }
            }
        }
        return buckets.map { MetricGroup(name: $0.key, performance: $0.value.build()) }.sorted { $0.name < $1.name }
    }

    static func comparisons(_ trades: [TradeRecord]) -> [Comparison] {
        let sorted = ordered(trades)
        var ssmtYes = PerformanceAccumulator(), ssmtNo = PerformanceAccumulator()
        var tsmoYes = PerformanceAccumulator(), tsmoNo = PerformanceAccumulator()
        var qtAligned = PerformanceAccumulator(), qtNotAligned = PerformanceAccumulator()
        var sweepYes = PerformanceAccumulator(), sweepNo = PerformanceAccumulator()
        var crtSsmt = PerformanceAccumulator(), crtNoSsmt = PerformanceAccumulator()
        var mmxmQt = PerformanceAccumulator(), mmxmNoQt = PerformanceAccumulator()
        var compYes = PerformanceAccumulator(), compNo = PerformanceAccumulator()
        for t in sorted {
            if t.hasSSMT { ssmtYes.add(t) } else { ssmtNo.add(t) }
            if t.hasTSMO { tsmoYes.add(t) } else { tsmoNo.add(t) }
            if t.qt.enabled { if t.qt.aligned { qtAligned.add(t) } else { qtNotAligned.add(t) } }
            if t.sweepValid { sweepYes.add(t) } else { sweepNo.add(t) }
            if t.hasCRT { if t.hasSSMT { crtSsmt.add(t) } else { crtNoSsmt.add(t) } }
            if t.hasMMXM { if t.hasQT { mmxmQt.add(t) } else { mmxmNoQt.add(t) } }
            if t.compliant { compYes.add(t) } else { compNo.add(t) }
        }
        return [
            Comparison(title: "SSMT contribution", left: MetricGroup(name: "With valid SSMT", performance: ssmtYes.build()), right: MetricGroup(name: "Without valid SSMT", performance: ssmtNo.build())),
            Comparison(title: "TSMO contribution", left: MetricGroup(name: "With valid TSMO", performance: tsmoYes.build()), right: MetricGroup(name: "Without valid TSMO", performance: tsmoNo.build())),
            Comparison(title: "Quarter alignment", left: MetricGroup(name: "QT aligned", performance: qtAligned.build()), right: MetricGroup(name: "QT not aligned", performance: qtNotAligned.build())),
            Comparison(title: "Liquidity sweep", left: MetricGroup(name: "Valid sweep", performance: sweepYes.build()), right: MetricGroup(name: "No valid sweep", performance: sweepNo.build())),
            Comparison(title: "CRT × SSMT", left: MetricGroup(name: "CRT + SSMT", performance: crtSsmt.build()), right: MetricGroup(name: "CRT without SSMT", performance: crtNoSsmt.build())),
            Comparison(title: "MMXM × QT", left: MetricGroup(name: "MMXM + QT", performance: mmxmQt.build()), right: MetricGroup(name: "MMXM without QT", performance: mmxmNoQt.build())),
            Comparison(title: "Process advantage", left: MetricGroup(name: "Fully valid trades", performance: compYes.build()), right: MetricGroup(name: "Rule break trades", performance: compNo.build()))
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
        guard !trades.isEmpty else { return [] }
        let sorted = ordered(trades)
        var groups: [String: PerformanceAccumulator] = [:]
        for t in sorted {
            let bits = (t.hasQT ? 1 : 0) | (t.hasMMXM ? 2 : 0) | (t.hasSSMT ? 4 : 0) | (t.hasTSMO ? 8 : 0) | (t.hasCRT ? 16 : 0)
            guard bits != 0 else { continue }
            if bits.nonzeroBitCount == 1 {
                for (mask, name) in singleModelMasks where bits == mask {
                    groups[name, default: PerformanceAccumulator()].add(t)
                    break
                }
            } else {
                for (mask, name) in multiModelMasks where (bits & mask) == mask {
                    groups[name, default: PerformanceAccumulator()].add(t)
                }
            }
        }
        return groups.map { EdgeCombination(name: $0.key, performance: $0.value.build()) }.sorted { $0.performance.count == $1.performance.count ? $0.name < $1.name : $0.performance.count > $1.performance.count }
    }

    static func mistakes(_ trades: [TradeRecord]) -> [MetricGroup] {
        guard !trades.isEmpty else { return [] }
        let sorted = ordered(trades)
        var groups: [String: PerformanceAccumulator] = [:]
        for t in sorted {
            if t.brokenRules.count == 1 {
                groups[t.brokenRules[0], default: PerformanceAccumulator()].add(t)
            } else if !t.brokenRules.isEmpty {
                for rule in Set(t.brokenRules) { groups[rule, default: PerformanceAccumulator()].add(t) }
            }
        }
        return groups.map { MetricGroup(name: $0.key, performance: $0.value.build()) }.sorted { $0.performance.count > $1.performance.count }
    }

    static func monthlyProcess(_ trades: [TradeRecord], calendar: Calendar) -> [MonthlyProcess] {
        guard !trades.isEmpty else { return [] }
        let sorted = ordered(trades)
        var groups: [Date: PerformanceAccumulator] = [:]
        for t in sorted {
            if let start = calendar.dateInterval(of: .month, for: t.date)?.start {
                groups[start, default: PerformanceAccumulator()].add(t)
            }
        }
        return groups.map { MonthlyProcess(date: $0.key, performance: $0.value.build()) }.sorted { $0.date < $1.date }
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
