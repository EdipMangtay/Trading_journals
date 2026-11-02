import Foundation

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
        guard window > 0 else { return [] }
        let data = AnalyticsEngine.ordered(trades)
        return data.indices.map { i in
            let sample = Array(data[max(0, i - window + 1)...i]), p = AnalyticsEngine.performance(sample)
            return RollingPoint(id: i, date: data[i].date, expectancy: p.expectancy, compliance: p.compliance, count: p.count)
        }
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
    }
    struct Generator: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
    }
    static func percentile(_ sorted: [Double], _ p: Double) -> Double {
        guard !sorted.isEmpty else { return 0 }
        let index = min(1, max(0, p)) * Double(sorted.count - 1), low = Int(index), high = min(sorted.count - 1, low + 1)
        return sorted[low] + (sorted[high] - sorted[low]) * (index - Double(low))
    }
    static func simulate(_ trades: [TradeRecord], runs: Int = 500, horizon: Int = 100, shuffle: Bool = false, seed: UInt64 = 6) -> Simulation? {
        guard trades.count >= 2, (1...2000).contains(runs), (1...1000).contains(horizon) else { return nil }
        let outcomes = AnalyticsEngine.ordered(trades).map(\.netPnL)
        guard outcomes.allSatisfy(\.isFinite) else { return nil }
        let steps = shuffle ? min(horizon, outcomes.count) : horizon
        var columns = Array(repeating: [Double](), count: steps + 1), drawdowns: [Double] = [], losses = 0, random = Generator(state: seed)
        for _ in 0..<runs {
            let values = shuffle ? outcomes.shuffled(using: &random) : (0..<steps).map { _ in outcomes[Int.random(in: outcomes.indices, using: &random)] }
            var equity = 0.0, peak = 0.0, dd = 0.0
            columns[0].append(0)
            for i in 0..<steps { equity += values[i]; peak = max(peak, equity); dd = max(dd, peak - equity); columns[i + 1].append(equity) }
            drawdowns.append(dd); if equity < 0 { losses += 1 }
        }
        let band = columns.enumerated().map { i, values -> PercentilePoint in let s = values.sorted(); return PercentilePoint(id: i, low: percentile(s, 0.05), median: percentile(s, 0.5), high: percentile(s, 0.95)) }
        return Simulation(band: band, drawdowns: drawdowns.sorted(), lossFraction: Double(losses) / Double(runs), runs: runs, horizon: steps)
    }
}
