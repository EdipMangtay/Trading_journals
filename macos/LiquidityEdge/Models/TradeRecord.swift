import Foundation

enum Catalog {
    static let instruments = ["NQ", "NASDAQ", "US100", "ES", "SP500", "XAUUSD", "EURUSD", "GBPUSD", "US30"]
    static let sessions = ["Asia", "London", "NY AM", "NY Lunch", "NY PM"]
    static let timeframes = ["Monthly", "Weekly", "Daily", "4H", "1H", "15M", "5M", "3M", "1M"]
    static let liquidity = ["BSL", "SSL", "ERL", "IRL", "PDH", "PDL", "PWH", "PWL", "PMH", "PML", "EQH", "EQL", "Session High", "Session Low", "FVG", "NWOG", "NDOG"]
    static let sweeps = ["BSL Sweep", "SSL Sweep", "Equal Highs", "Equal Lows", "Previous Day High", "Previous Day Low", "Previous Week High", "Previous Week Low", "Session High", "Session Low", "Internal Liquidity", "External Liquidity"]
    static let confirmations = ["CISD", "MSS", "IFVG", "FVG", "OB", "Breaker", "Displacement", "SMT", "SSMT", "CRT", "PSP", "OTE", "Turtle Soup", "Liquidity Sweep", "True Open", "Premium / Discount", "Rejection", "Inverse FVG", "Order Block", "Market Structure Shift", "Opening Price"]
    static let narratives = ["ERL → IRL", "IRL → ERL", "True Open Reversal", "Judas Swing → Distribution", "London Sweep → NY Expansion", "SMR Reversal", "HTF Continuation", "Range Expansion"]
    static let biasRelations = ["Pro-Trend", "Counter-Trend", "Reversal / SMR"]
    static let newsDrivers = ["Clean", "Post-News", "News Judas", "High-Impact"]
    static let qtProfiles = ["AMDX", "XAMD"]
    static let trueOpenAnchors = ["TDO", "TSO", "T90O", "TWO"]
    static let trueOpenLocations = ["Discount", "Premium", "At Open"]
    static let rules = ["Entered before allowed session", "No SSMT", "No TSMO", "No liquidity sweep", "No HTF alignment", "Wrong QT quarter", "No displacement", "Poor location", "Chased entry", "Early entry", "Late entry", "Overtrading", "Revenge trade", "FOMO", "Oversized risk", "Moved stop", "Closed early", "Ignored target", "Pattern recognition override"]
    static let emotions = ["Calm", "Confident", "Focused", "Hesitant", "Fear", "FOMO", "Greed", "Revenge", "Frustrated", "Overconfident", "Impatient"]
    static let screenshotCategories = ["HTF", "Before Entry", "Entry", "During Trade", "Exit", "Post Trade Review"]
}

enum Classification: String, Codable, CaseIterable {
    case validWinner = "VALID WINNER", validLoser = "VALID LOSER", invalidWinner = "INVALID WINNER", invalidLoser = "INVALID LOSER", breakeven = "BREAKEVEN"
    var message: String {
        switch self {
        case .validWinner: return "Good process, positive outcome"
        case .validLoser: return "Good process, normal loss"
        case .invalidWinner: return "Profitable outcome, invalid execution"
        case .invalidLoser: return "Review the process before the outcome"
        case .breakeven: return "Flat outcome. Evaluate execution independently."
        }
    }
}

struct QTContext: Codable, Hashable {
    var enabled = false
    var higherQuarter = "Q1", dailyQuarter = "Q1", cycle90 = "Q1", cycle22 = "Q1"
    var phase = "Accumulation"
    var trueOpen = false, aligned = false, valid = false
    var profile = "AMDX"
    var trueOpenAnchor = "TDO"
    var trueOpenLocation = "Discount"

    enum CodingKeys: String, CodingKey {
        case enabled, higherQuarter, dailyQuarter, cycle90, cycle22, phase, trueOpen, aligned, valid
        case profile, trueOpenAnchor, trueOpenLocation
    }

    init(enabled: Bool = false, higherQuarter: String = "Q1", dailyQuarter: String = "Q1", cycle90: String = "Q1", cycle22: String = "Q1", phase: String = "Accumulation", trueOpen: Bool = false, aligned: Bool = false, valid: Bool = false, profile: String = "AMDX", trueOpenAnchor: String = "TDO", trueOpenLocation: String = "Discount") {
        self.enabled = enabled; self.higherQuarter = higherQuarter; self.dailyQuarter = dailyQuarter
        self.cycle90 = cycle90; self.cycle22 = cycle22; self.phase = phase
        self.trueOpen = trueOpen; self.aligned = aligned; self.valid = valid
        self.profile = profile; self.trueOpenAnchor = trueOpenAnchor; self.trueOpenLocation = trueOpenLocation
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        higherQuarter = try c.decodeIfPresent(String.self, forKey: .higherQuarter) ?? "Q1"
        dailyQuarter = try c.decodeIfPresent(String.self, forKey: .dailyQuarter) ?? "Q1"
        cycle90 = try c.decodeIfPresent(String.self, forKey: .cycle90) ?? "Q1"
        cycle22 = try c.decodeIfPresent(String.self, forKey: .cycle22) ?? "Q1"
        phase = try c.decodeIfPresent(String.self, forKey: .phase) ?? "Accumulation"
        trueOpen = try c.decodeIfPresent(Bool.self, forKey: .trueOpen) ?? false
        aligned = try c.decodeIfPresent(Bool.self, forKey: .aligned) ?? false
        valid = try c.decodeIfPresent(Bool.self, forKey: .valid) ?? false
        profile = try c.decodeIfPresent(String.self, forKey: .profile) ?? "AMDX"
        trueOpenAnchor = try c.decodeIfPresent(String.self, forKey: .trueOpenAnchor) ?? "TDO"
        trueOpenLocation = try c.decodeIfPresent(String.self, forKey: .trueOpenLocation) ?? "Discount"
    }
}
struct MMXMContext: Codable, Hashable {
    var model = "None"
    var consolidation = false, manipulation = false, displacement = false, repricing = false, reversal = false, target = false, valid = false
}
struct PO3Context: Codable, Hashable {
    var phase = "Accumulation", manipulationDirection = "Up"
    var valid = false
}
struct SSMTContext: Codable, Hashable {
    var confirmation = "Not Required", type = "High divergence"
    var markets: [String] = []
    var valid = false
}
struct CRTContext: Codable, Hashable {
    var enabled = false, reentry = false, confirmed = false
    var timeframe = "15M", liquidityTaken = "High"
    var high: Double?, low: Double?
}
struct ProcessScores: Codable, Hashable {
    var marketRead = 5.0, entry = 5.0, compliance = 5.0, risk = 5.0, management = 5.0, psychology = 5.0, recognition = 5.0
    var overall: Double { (marketRead + entry + compliance + risk + management + psychology + recognition) / 7 * 10 }
}
struct EmotionalState: Codable, Hashable {
    var confidence = 5.0, stress = 5.0, fomo = 1.0, focus = 5.0, satisfaction = 5.0
    var takeAgain = true
    var emotions: [String] = []
}
struct TradeNotes: Codable, Hashable {
    var thesis = "", entry = "", confirmation = "", invalidation = "", correct = "", incorrect = "", differently = "", lesson = ""
}
struct TradeRecord: Codable, Identifiable, Hashable {
    var id = UUID()
    var date = Date()
    var exitDate: Date?
    var instrument = "NQ", direction = "Long", session = "NY AM"
    var setupID: UUID?
    var setupName = "Unassigned"
    var entryPrice: Double?, stopLoss: Double?, takeProfit: Double?, exitPrice: Double?, positionSize: Double?
    var riskDollars: Double?, riskPercent: Double?, grossPnL = 0.0, fees = 0.0, rMultiple: Double?
    var bias = "Neutral", contextTimeframes: [String] = [], drawOnLiquidity = "", liquidityTaken: [String] = []
    var narrative = "", biasRelation = "Pro-Trend", newsDriver = "Clean"
    var sweepValid = false, htfAligned = false
    var qt = QTContext(), mmxm = MMXMContext(), po3 = PO3Context(), ssmt = SSMTContext(), crt = CRTContext()
    var tsmo = "Not Required", tsmoValid = false
    var entryTimeframe = "1M", confirmations: [String] = []
    var followsPlan = true, brokenRules: [String] = [], grade = "B"
    var scores = ProcessScores(), emotional = EmotionalState(), notes = TradeNotes()
    var tags: [String] = []

    enum CodingKeys: String, CodingKey {
        case id, date, exitDate, instrument, direction, session, setupID, setupName
        case entryPrice, stopLoss, takeProfit, exitPrice, positionSize
        case riskDollars, riskPercent, grossPnL, fees, rMultiple
        case bias, contextTimeframes, drawOnLiquidity, liquidityTaken
        case narrative, biasRelation, newsDriver
        case sweepValid, htfAligned, qt, mmxm, po3, ssmt, crt
        case tsmo, tsmoValid, entryTimeframe, confirmations
        case followsPlan, brokenRules, grade, scores, emotional, notes, tags
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        date = try c.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        exitDate = try c.decodeIfPresent(Date.self, forKey: .exitDate)
        instrument = try c.decodeIfPresent(String.self, forKey: .instrument) ?? "NQ"
        direction = try c.decodeIfPresent(String.self, forKey: .direction) ?? "Long"
        session = try c.decodeIfPresent(String.self, forKey: .session) ?? "NY AM"
        setupID = try c.decodeIfPresent(UUID.self, forKey: .setupID)
        setupName = try c.decodeIfPresent(String.self, forKey: .setupName) ?? "Unassigned"
        entryPrice = try c.decodeIfPresent(Double.self, forKey: .entryPrice)
        stopLoss = try c.decodeIfPresent(Double.self, forKey: .stopLoss)
        takeProfit = try c.decodeIfPresent(Double.self, forKey: .takeProfit)
        exitPrice = try c.decodeIfPresent(Double.self, forKey: .exitPrice)
        positionSize = try c.decodeIfPresent(Double.self, forKey: .positionSize)
        riskDollars = try c.decodeIfPresent(Double.self, forKey: .riskDollars)
        riskPercent = try c.decodeIfPresent(Double.self, forKey: .riskPercent)
        grossPnL = try c.decodeIfPresent(Double.self, forKey: .grossPnL) ?? 0.0
        fees = try c.decodeIfPresent(Double.self, forKey: .fees) ?? 0.0
        rMultiple = try c.decodeIfPresent(Double.self, forKey: .rMultiple)
        bias = try c.decodeIfPresent(String.self, forKey: .bias) ?? "Neutral"
        contextTimeframes = try c.decodeIfPresent([String].self, forKey: .contextTimeframes) ?? []
        drawOnLiquidity = try c.decodeIfPresent(String.self, forKey: .drawOnLiquidity) ?? ""
        liquidityTaken = try c.decodeIfPresent([String].self, forKey: .liquidityTaken) ?? []
        narrative = try c.decodeIfPresent(String.self, forKey: .narrative) ?? ""
        biasRelation = try c.decodeIfPresent(String.self, forKey: .biasRelation) ?? "Pro-Trend"
        newsDriver = try c.decodeIfPresent(String.self, forKey: .newsDriver) ?? "Clean"
        sweepValid = try c.decodeIfPresent(Bool.self, forKey: .sweepValid) ?? false
        htfAligned = try c.decodeIfPresent(Bool.self, forKey: .htfAligned) ?? false
        qt = try c.decodeIfPresent(QTContext.self, forKey: .qt) ?? QTContext()
        mmxm = try c.decodeIfPresent(MMXMContext.self, forKey: .mmxm) ?? MMXMContext()
        po3 = try c.decodeIfPresent(PO3Context.self, forKey: .po3) ?? PO3Context()
        ssmt = try c.decodeIfPresent(SSMTContext.self, forKey: .ssmt) ?? SSMTContext()
        crt = try c.decodeIfPresent(CRTContext.self, forKey: .crt) ?? CRTContext()
        tsmo = try c.decodeIfPresent(String.self, forKey: .tsmo) ?? "Not Required"
        tsmoValid = try c.decodeIfPresent(Bool.self, forKey: .tsmoValid) ?? false
        entryTimeframe = try c.decodeIfPresent(String.self, forKey: .entryTimeframe) ?? "1M"
        confirmations = try c.decodeIfPresent([String].self, forKey: .confirmations) ?? []
        followsPlan = try c.decodeIfPresent(Bool.self, forKey: .followsPlan) ?? true
        brokenRules = try c.decodeIfPresent([String].self, forKey: .brokenRules) ?? []
        grade = try c.decodeIfPresent(String.self, forKey: .grade) ?? "B"
        scores = try c.decodeIfPresent(ProcessScores.self, forKey: .scores) ?? ProcessScores()
        emotional = try c.decodeIfPresent(EmotionalState.self, forKey: .emotional) ?? EmotionalState()
        notes = try c.decodeIfPresent(TradeNotes.self, forKey: .notes) ?? TradeNotes()
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
    }
    var netPnL: Double { grossPnL - fees }
    var compliant: Bool { followsPlan && brokenRules.isEmpty }
    var hasSSMT: Bool { ssmt.confirmation == "Yes" && ssmt.valid }
    var hasTSMO: Bool { tsmo == "Yes" && tsmoValid }
    var hasCRT: Bool { crt.enabled && crt.confirmed }
    var hasQT: Bool { qt.enabled && qt.valid && qt.aligned }
    var hasMMXM: Bool { mmxm.model != "None" && mmxm.valid }
    var classification: Classification {
        if abs(netPnL) < 0.005 { return .breakeven }
        return netPnL > 0 ? (compliant ? .validWinner : .invalidWinner) : (compliant ? .validLoser : .invalidLoser)
    }
    var plannedRR: Double? {
        guard let entryPrice, let stopLoss, let takeProfit, abs(entryPrice - stopLoss) > 0 else { return nil }
        return abs(takeProfit - entryPrice) / abs(entryPrice - stopLoss)
    }
    var duration: TimeInterval? { exitDate.map { $0.timeIntervalSince(date) } }
    var validationError: String? {
        if instrument.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Enter an instrument." }
        let numbers = [entryPrice, stopLoss, takeProfit, exitPrice, positionSize, riskDollars, riskPercent, grossPnL, fees, rMultiple, crt.high, crt.low].compactMap { $0 }
        if numbers.contains(where: { !$0.isFinite }) { return "Numeric values must be finite." }
        if fees < 0 || (riskDollars ?? 0) < 0 || (riskPercent ?? 0) < 0 || (positionSize ?? 0) < 0 { return "Fees, size and risk cannot be negative." }
        if let exitDate, exitDate < date { return "Exit time must be after entry time." }
        if let high = crt.high, let low = crt.low, high < low { return "CRT range high must be above range low." }
        let scoresToCheck = [scores.marketRead, scores.entry, scores.compliance, scores.risk, scores.management, scores.psychology, scores.recognition]
        if scoresToCheck.contains(where: { !$0.isFinite || !(0...10).contains($0) }) { return "Process scores must be between 0 and 10." }
        if [emotional.confidence, emotional.stress, emotional.fomo, emotional.focus, emotional.satisfaction].contains(where: { !$0.isFinite || !(1...10).contains($0) }) { return "Emotion scores must be between 1 and 10." }
        if !["Long", "Short"].contains(direction) { return "Direction must be Long or Short." }
        if !["A+", "A", "B", "C", "D", "F"].contains(grade) { return "Choose a valid trade grade." }
        if followsPlan && !brokenRules.isEmpty { return "Clear broken rules or mark this trade as outside your plan." }
        if !followsPlan && brokenRules.isEmpty { return "Select at least one broken rule, or add a custom rule." }
        return nil
    }
}

struct JournalPreferences: Codable, Equatable {
    var accountSize = 50000.0, defaultRiskPercent = 0.5
    var currency = "USD", theme = "Dark", animations = true
    var timezone = "America/New_York"
    var sessions = Catalog.sessions
    var sessionHours = ["Asia": "20:00–00:00", "London": "02:00–05:00", "NY AM": "09:30–11:00", "NY Lunch": "11:00–13:00", "NY PM": "13:00–16:00"]
    var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: timezone) ?? .current
        value.firstWeekday = 2
        return value
    }
}
