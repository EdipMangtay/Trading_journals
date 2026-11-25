import Foundation
import Accelerate

struct RiskSnapshot {
    var balance: Double
    var realized: Double
    var today: Double
    var days: Int
    var todayCount: Int
    var floor: Double?
    var remaining: Double?
    var dailyRemaining: Double?
    var consistency: Double?
    var unverified: Bool
    var historicalBreach: Bool
    var oversizedTrades: Int
    var dailyCountBreaches: Int
}
enum WorkstationAnalytics {
    /// Balance limits are based on realized closes; missing exits cannot be
    /// assigned to a settlement day and explicitly make verification incomplete.
    static func risk(_ trades: [TradeRecord], account: TradingAccount, calendar: Calendar, now: Date = Date()) -> RiskSnapshot {
        let closed = trades.filter { $0.exitDate != nil && $0.exitDate! <= now }.sorted { $0.exitDate == $1.exitDate ? $0.id.uuidString < $1.id.uuidString : $0.exitDate! < $1.exitDate! }
        let groups = Dictionary(grouping: closed) { calendar.startOfDay(for: $0.exitDate!) }
        let dayPnL = groups.mapValues { $0.reduce(0) { $0 + $1.netPnL } }
        let today = calendar.startOfDay(for: now), rules = account.rules
        let total = closed.reduce(0) { $0 + $1.netPnL }
        var peak = account.startingBalance, balance = account.startingBalance, breach = false
        for day in groups.keys.sorted() {
            let floor = rules.maximumLoss.map { (rules.drawdownMethod == "End of day" ? peak : account.startingBalance) - $0 }
            var daily = 0.0
            for trade in groups[day]! {
                balance += trade.netPnL; daily += trade.netPnL
                if let floor, balance < floor { breach = true }
                if let loss = rules.dailyLoss, daily < -loss { breach = true }
            }
            // Today's closing balance is not an end-of-day high watermark yet.
            if day < today { peak = max(peak, balance) }
        }
        let floor = rules.drawdownMethod == "Intraday equity" ? nil : rules.maximumLoss.map { (rules.drawdownMethod == "End of day" ? peak : account.startingBalance) - $0 }
        let todayTrades = trades.filter { calendar.isDate($0.date, inSameDayAs: now) }
        let entryGroups = Dictionary(grouping: trades) { calendar.startOfDay(for: $0.date) }
        return RiskSnapshot(balance: account.startingBalance + total, realized: total, today: dayPnL[today] ?? 0, days: groups.count, todayCount: todayTrades.count, floor: floor, remaining: floor.map { account.startingBalance + total - $0 }, dailyRemaining: rules.dailyLoss.map { $0 + (dayPnL[today] ?? 0) }, consistency: total > 0 ? max(0, dayPnL.values.max() ?? 0) / total * 100 : nil, unverified: trades.contains { $0.exitDate == nil } || rules.drawdownMethod == "Intraday equity", historicalBreach: breach && rules.drawdownMethod != "Intraday equity", oversizedTrades: rules.riskPerTrade.map { cap in trades.filter { ($0.riskDollars ?? 0) > cap }.count } ?? 0, dailyCountBreaches: rules.dailyTradeCount.map { cap in entryGroups.values.filter { $0.count > cap }.count } ?? 0)
    }
    struct FillResult {
        var realized: Double
        var openQuantity: Double
        var slippageCost: Double?
        var comparedFills: Int
    }
    static func executions(_ supplement: TradeSupplement, direction: String) throws -> FillResult {
        var quantity = 0.0, cost = 0.0, realized = 0.0, slippage = 0.0, compared = 0
        let sign = direction == "Long" ? 1.0 : -1.0
        guard supplement.pointValue > 0, supplement.pointValue.isFinite else { throw JournalError(message: "Puan değeri pozitif olmalı.") }
        // Stable input order for fills sharing a timestamp; a user can explicitly
        // enter entry before exit without random UUID ordering changing inventory.
        let ordered = supplement.fills.enumerated().sorted { $0.element.date == $1.element.date ? $0.offset < $1.offset : $0.element.date < $1.element.date }
        for (_, f) in ordered {
            guard f.quantity > 0, f.quantity.isFinite, f.price.isFinite, f.fee >= 0, f.fee.isFinite else { throw JournalError(message: "Geçersiz gerçekleşme.") }
            if f.side == "Entry" { cost += sign * f.price * f.quantity * supplement.pointValue + f.fee; quantity += f.quantity }
            else {
                guard f.side == "Exit", f.quantity <= quantity + 1e-9, quantity > 0 else { throw JournalError(message: "Çıkış miktarı açık pozisyonu aşıyor.") }
                let allocated = cost / quantity * f.quantity
                realized += sign * f.price * f.quantity * supplement.pointValue - allocated - f.fee
                cost -= allocated; quantity = max(0, quantity - f.quantity)
            }
            if let expected = f.expectedPrice {
                guard expected.isFinite else { throw JournalError(message: "Beklenen fiyat geçersiz.") }
                slippage += sign * (f.side == "Entry" ? f.price - expected : expected - f.price) * f.quantity * supplement.pointValue; compared += 1
            }
        }
        return FillResult(realized: realized, openQuantity: quantity, slippageCost: compared > 0 ? slippage : nil, comparedFills: compared)
    }
    struct RollingPoint: Identifiable {
        var id: Int; var date: Date; var expectancy: Double; var compliance: Double; var count: Int
    }
    static func rolling(_ trades: [TradeRecord], window: Int = 20) -> [RollingPoint] {
        guard window > 0, !trades.isEmpty else { return [] }
        let data = AnalyticsEngine.ordered(trades)
        var result: [RollingPoint] = []
        result.reserveCapacity(data.count)
        var sumPnL = 0.0
        var validCount = 0
        for i in 0..<data.count {
            let entering = data[i]
            sumPnL += entering.netPnL
            if entering.compliant { validCount += 1 }
            if i >= window {
                let leaving = data[i - window]
                sumPnL -= leaving.netPnL
                if leaving.compliant { validCount -= 1 }
            }
            let currentCount = min(i + 1, window)
            result.append(RollingPoint(
                id: i,
                date: entering.date,
                expectancy: sumPnL / Double(currentCount),
                compliance: Double(validCount) / Double(currentCount) * 100,
                count: currentCount
            ))
        }
        return result
    }
    struct Underwater {
        var longestSeconds = 0.0
        var longestRecoveredSeconds: Double?
        var ongoing = false
    }
    static func underwater(_ trades: [TradeRecord]) -> Underwater {
        let data = AnalyticsEngine.ordered(trades)
        guard let first = data.first else { return Underwater() }
        var value = Underwater(), equity = 0.0, peak = 0.0, peakDate = first.date, start: Date?
        for t in data {
            equity += t.netPnL
            if equity >= peak {
                if let start { let elapsed = t.date.timeIntervalSince(start); value.longestSeconds = max(value.longestSeconds, elapsed); value.longestRecoveredSeconds = max(value.longestRecoveredSeconds ?? 0, elapsed) }
                peak = equity; peakDate = t.date; start = nil
            } else if start == nil { start = peakDate }
        }
        if let start { value.ongoing = true; value.longestSeconds = max(value.longestSeconds, data.last!.date.timeIntervalSince(start)) }
        return value
    }
    struct PercentilePoint: Identifiable { var id: Int; var low: Double; var median: Double; var high: Double }
    struct Simulation {
        var band: [PercentilePoint]
        var drawdowns: [Double]
        var lossFraction: Double
        var runs: Int
        var horizon: Int
        var computeDurationMs: Double = 0
        var workerCores: Int = 1
    }
    struct Generator: RandomNumberGenerator {
        var state: UInt64
        @inline(__always)
        mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
    }
    @inline(__always)
    private static func mixSeed(_ value: UInt64) -> UInt64 {
        var z = value &+ 0x9E3779B97F4A7C15
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    static func percentile(_ sorted: [Double], _ p: Double) -> Double {
        guard !sorted.isEmpty else { return 0 }
        let index = min(1, max(0, p)) * Double(sorted.count - 1), low = Int(index), high = min(sorted.count - 1, low + 1)
        return sorted[low] + (sorted[high] - sorted[low]) * (index - Double(low))
    }
    /// Multi-core deterministic Monte Carlo resampling engine tuned for Apple Silicon (M3 Pro).
    /// Partitioned by cache-isolated run chunks with parallel column percentile sorting.
    static func simulate(_ trades: [TradeRecord], runs: Int = 500, horizon: Int = 100, shuffle: Bool = false, seed: UInt64 = 6) -> Simulation? {
        guard trades.count >= 2, (1...2000).contains(runs), (1...1000).contains(horizon) else { return nil }
        let startTime = CFAbsoluteTimeGetCurrent()
        let outcomes = AnalyticsEngine.ordered(trades).map(\.netPnL)
        guard outcomes.allSatisfy(\.isFinite) else { return nil }
        let steps = shuffle ? min(horizon, outcomes.count) : horizon
        let stride = steps + 1
        let outcomeCount = outcomes.count

        let availableCores = max(1, ProcessInfo.processInfo.activeProcessorCount)
        let workerCount = runs >= 64 ? min(availableCores, max(1, runs / 32)) : 1

        // Row-major per-run equity matrix: each worker owns a disjoint contiguous run range (zero false sharing).
        let runPaths = UnsafeMutableBufferPointer<Double>.allocate(capacity: runs * stride)
        let drawdownsBuf = UnsafeMutableBufferPointer<Double>.allocate(capacity: runs)
        let chunkLosses = UnsafeMutableBufferPointer<Int>.allocate(capacity: workerCount)
        defer {
            runPaths.deallocate()
            drawdownsBuf.deallocate()
            chunkLosses.deallocate()
        }

        let runsPerWorker = (runs + workerCount - 1) / workerCount
        let runWorker: (Int) -> Void = { worker in
            let startRun = worker * runsPerWorker
            let endRun = min(runs, startRun + runsPerWorker)
            guard startRun < endRun else { chunkLosses[worker] = 0; return }
            var localLosses = 0
            var scratch = shuffle ? outcomes : []
            for r in startRun..<endRun {
                var rng = Generator(state: mixSeed(seed ^ (UInt64(r &+ 1) &* 0xD1B54A32D192ED03)))
                var equity = 0.0, peak = 0.0, dd = 0.0
                let base = r * stride
                runPaths[base] = 0.0
                if shuffle {
                    // Partial Fisher-Yates shuffle for only `steps` draws: O(steps) instead of O(outcomeCount)
                    scratch = outcomes
                    for i in 0..<steps {
                        let remaining = outcomeCount - i
                        let j = i + Int(rng.next() % UInt64(remaining))
                        if i != j { scratch.swapAt(i, j) }
                        equity += scratch[i]
                        if equity > peak { peak = equity }
                        let currentDD = peak - equity
                        if currentDD > dd { dd = currentDD }
                        runPaths[base + i + 1] = equity
                    }
                } else {
                    for i in 0..<steps {
                        let pick = Int(rng.next() % UInt64(outcomeCount))
                        equity += outcomes[pick]
                        if equity > peak { peak = equity }
                        let currentDD = peak - equity
                        if currentDD > dd { dd = currentDD }
                        runPaths[base + i + 1] = equity
                    }
                }
                drawdownsBuf[r] = dd
                if equity < 0 { localLosses += 1 }
            }
            chunkLosses[worker] = localLosses
        }

        if workerCount > 1 {
            DispatchQueue.concurrentPerform(iterations: workerCount, execute: runWorker)
        } else {
            runWorker(0)
        }

        var totalLosses = 0
        for w in 0..<workerCount { totalLosses += chunkLosses[w] }

        // Parallel column percentile extraction using Accelerate vDSP_vsortD across all cores
        let bandBuf = UnsafeMutableBufferPointer<PercentilePoint>.allocate(capacity: stride)
        defer { bandBuf.deallocate() }
        bandBuf[0] = PercentilePoint(id: 0, low: 0, median: 0, high: 0)

        let sortSteps = steps
        let sortStepColumn: (Int) -> Void = { offset in
            let step = offset + 1
            var col = [Double](repeating: 0, count: runs)
            for r in 0..<runs { col[r] = runPaths[r * stride + step] }
            vDSP_vsortD(&col, vDSP_Length(runs), 1)
            bandBuf[step] = PercentilePoint(
                id: step,
                low: percentile(col, 0.05),
                median: percentile(col, 0.5),
                high: percentile(col, 0.95)
            )
        }

        if workerCount > 1 && sortSteps >= 8 {
            DispatchQueue.concurrentPerform(iterations: sortSteps, execute: sortStepColumn)
        } else {
            for s in 0..<sortSteps { sortStepColumn(s) }
        }

        var drawdowns = Array(drawdownsBuf)
        vDSP_vsortD(&drawdowns, vDSP_Length(runs), 1)
        let elapsedMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
        return Simulation(
            band: Array(bandBuf),
            drawdowns: drawdowns,
            lossFraction: Double(totalLosses) / Double(runs),
            runs: runs,
            horizon: steps,
            computeDurationMs: elapsedMs,
            workerCores: workerCount
        )
    }
}
