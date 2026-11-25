import Foundation

/// Pure, deterministic, timezone-aware ICT Killzone & Quarterly Theory (Q1–Q4) live clock engine.
/// Powers the macOS Menu Bar live widget and supports user-configured session windows plus
/// canonical New York (America/New_York) 18:00 True Day Quarterly Theory phases.
enum KillzoneClockEngine {
    struct SessionInterval: Equatable {
        let name: String
        let startMinute: Int // 0..<1440 in trading timezone
        let endMinute: Int   // 0..<1440 (can be < startMinute for overnight wrap e.g. 20:00–00:00)
        let rawLabel: String

        var durationMinutes: Int {
            if endMinute > startMinute { return endMinute - startMinute }
            if endMinute < startMinute { return (1440 - startMinute) + endMinute }
            return 1440
        }

        func contains(minuteOfDay: Int) -> Bool {
            if endMinute > startMinute {
                return minuteOfDay >= startMinute && minuteOfDay < endMinute
            } else if endMinute < startMinute {
                return minuteOfDay >= startMinute || minuteOfDay < endMinute
            }
            return true
        }

        func elapsedSeconds(at minuteOfDay: Int, secondOfMinute: Int) -> TimeInterval {
            let elapsedMinutes: Int
            if endMinute >= startMinute {
                elapsedMinutes = max(0, minuteOfDay - startMinute)
            } else {
                elapsedMinutes = minuteOfDay >= startMinute ? (minuteOfDay - startMinute) : ((1440 - startMinute) + minuteOfDay)
            }
            return TimeInterval(elapsedMinutes * 60 + secondOfMinute)
        }

        func remainingSeconds(at minuteOfDay: Int, secondOfMinute: Int) -> TimeInterval {
            let total = TimeInterval(durationMinutes * 60)
            return max(0, total - elapsedSeconds(at: minuteOfDay, secondOfMinute: secondOfMinute))
        }

        func secondsUntilStart(from minuteOfDay: Int, secondOfMinute: Int) -> TimeInterval {
            let currentSec = minuteOfDay * 60 + secondOfMinute
            let startSec = startMinute * 60
            let delta = startSec > currentSec ? (startSec - currentSec) : (86400 - currentSec + startSec)
            return TimeInterval(delta)
        }
    }

    struct QuarterPhase: Equatable {
        let code: String       // "Q1", "Q2", "Q3", "Q4"
        let amdxName: String   // "Accumulation", "Manipulation", "Distribution", "Continuation / X"
        let sessionHint: String
        let remainingSeconds: TimeInterval
        let progress: Double   // 0.0...1.0
    }

    struct ClockSnapshot: Equatable {
        let now: Date
        let tradingTimeFormatted: String
        let nyTimeFormatted: String
        let timezoneAbbreviation: String
        let isWeekendClosed: Bool

        // Killzone status
        let isInKillzone: Bool
        let activeSessionName: String?
        let activeSessionHours: String?
        let activeRemainingSeconds: TimeInterval
        let activeProgress: Double

        let nextSessionName: String?
        let nextSessionHours: String?
        let secondsUntilNextSession: TimeInterval

        // Canonical ICT Quarterly Theory (18:00 NY True Day anchor)
        let dailyQuarter: QuarterPhase   // 6-hour blocks (Q1 Asia, Q2 London, Q3 NY AM, Q4 NY PM)
        let microQuarter: QuarterPhase   // 90-minute blocks inside the active 6-hour Daily Quarter
        let subQuarterCode: String       // 22.5-minute precision sub-quarter (Q1..Q4)
        let trueOpenStatus: String       // "TDO Sonrası (00:00 NY+)" or "TDO Bekleniyor"

        /// Compact menu-bar badge shown right next to the macOS clock.
        func menuBarLabel(riskMultiplier: Double, regimeState: EdgeMLEngine.RegimeState, compact: Bool) -> String {
            let mult = String(format: "%.2fx", riskMultiplier)
            if compact {
                return "\(dailyQuarter.code)·\(microQuarter.code) \(mult)"
            }
            if isWeekendClosed {
                return "Hafta Sonu · \(mult)"
            }
            if isInKillzone, let active = activeSessionName {
                let shortTime = KillzoneClockEngine.formatShortCountdown(activeRemainingSeconds)
                return "\(active) · \(microQuarter.code) · \(shortTime) · \(mult)"
            } else if let next = nextSessionName {
                let shortTime = KillzoneClockEngine.formatShortCountdown(secondsUntilNextSession)
                return "\(dailyQuarter.code)·\(microQuarter.code) · \(next) -\(shortTime) · \(mult)"
            }
            return "\(dailyQuarter.code)·\(microQuarter.code) · \(mult)"
        }
    }

    // MARK: - Canonical Session Parsing

    private static let fallbackSessionHours: [String: String] = [
        "Asia": "20:00–00:00",
        "London": "02:00–05:00",
        "NY AM": "09:30–11:00",
        "NY Lunch": "11:00–13:00",
        "NY PM": "13:00–16:00"
    ]

    static func parseSessions(from preferences: JournalPreferences) -> [SessionInterval] {
        var intervals: [SessionInterval] = []
        for name in preferences.sessions {
            let raw = (preferences.sessionHours[name] ?? fallbackSessionHours[name] ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let parsed = parseWindow(name: name, raw: raw) {
                intervals.append(parsed)
            }
        }
        if intervals.isEmpty {
            for (name, raw) in fallbackSessionHours {
                if let parsed = parseWindow(name: name, raw: raw) {
                    intervals.append(parsed)
                }
            }
        }
        return intervals
    }

    static func parseWindow(name: String, raw: String) -> SessionInterval? {
        let normalized = raw
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: " ", with: "")
        let parts = normalized.split(separator: "-")
        guard parts.count == 2,
              let start = parseClockMinute(String(parts[0])),
              let end = parseClockMinute(String(parts[1])) else {
            return nil
        }
        return SessionInterval(name: name, startMinute: start, endMinute: end, rawLabel: raw)
    }

    private static func parseClockMinute(_ token: String) -> Int? {
        let parts = token.split(separator: ":")
        guard parts.count == 2,
              let h = Int(parts[0]),
              let m = Int(parts[1]),
              (0...24).contains(h), (0..<60).contains(m) else {
            return nil
        }
        let clampedHour = h == 24 ? 0 : h
        return clampedHour * 60 + m
    }

    // MARK: - Live Snapshot Computation

    static func snapshot(at date: Date = Date(), preferences: JournalPreferences) -> ClockSnapshot {
        let tradingTZ = TimeZone(identifier: preferences.timezone) ?? TimeZone(identifier: "America/New_York") ?? .current
        let nyTZ = TimeZone(identifier: "America/New_York") ?? tradingTZ

        var tradingCal = Calendar(identifier: .gregorian)
        tradingCal.timeZone = tradingTZ

        var nyCal = Calendar(identifier: .gregorian)
        nyCal.timeZone = nyTZ

        let tComps = tradingCal.dateComponents([.hour, .minute, .second], from: date)
        let tHour = tComps.hour ?? 0
        let tMin = tComps.minute ?? 0
        let tSec = tComps.second ?? 0
        let tradingMinuteOfDay = tHour * 60 + tMin

        let nyComps = nyCal.dateComponents([.weekday, .hour, .minute, .second], from: date)
        let nyWeekday = nyComps.weekday ?? 2 // 1 = Sun, 7 = Sat
        let nyHour = nyComps.hour ?? 0
        let nyMin = nyComps.minute ?? 0
        let nySec = nyComps.second ?? 0

        // FX / Index Futures weekend window: Friday 17:00 NY -> Sunday 18:00 NY
        let isWeekendClosed: Bool = {
            if nyWeekday == 7 { return true }
            if nyWeekday == 6 && nyHour >= 17 { return true }
            if nyWeekday == 1 && nyHour < 18 { return true }
            return false
        }()

        // Resolve Active & Next Killzone in user's trading timezone
        let sessions = parseSessions(from: preferences)
        let activeSession = isWeekendClosed ? nil : sessions.first(where: { $0.contains(minuteOfDay: tradingMinuteOfDay) })

        let activeRem: TimeInterval
        let activeProg: Double
        if let active = activeSession {
            activeRem = active.remainingSeconds(at: tradingMinuteOfDay, secondOfMinute: tSec)
            let total = max(60.0, TimeInterval(active.durationMinutes * 60))
            activeProg = min(1.0, max(0.0, 1.0 - (activeRem / total)))
        } else {
            activeRem = 0
            activeProg = 0
        }

        // Next session (excluding currently active)
        let nextCandidate = sessions
            .filter { $0.name != activeSession?.name }
            .map { (session: $0, wait: $0.secondsUntilStart(from: tradingMinuteOfDay, secondOfMinute: tSec)) }
            .min(by: { $0.wait < $1.wait })

        // Canonical ICT Quarterly Theory (True Day anchored at 18:00 America/New_York)
        let nySecondsSinceMidnight = nyHour * 3600 + nyMin * 60 + nySec
        let secondsSinceTrueDayStart = (nySecondsSinceMidnight - 18 * 3600 + 86400) % 86400

        // 1. Daily 6-hour Quarter (21600 sec each)
        let dailyIdx = secondsSinceTrueDayStart / 21600 // 0=Q1, 1=Q2, 2=Q3, 3=Q4
        let dailyElapsed = secondsSinceTrueDayStart % 21600
        let dailyRem = TimeInterval(21600 - dailyElapsed)
        let dailyProg = Double(dailyElapsed) / 21600.0
        let dailyMeta = quarterMetadata(index: dailyIdx, isDaily: true)
        let dailyQuarter = QuarterPhase(
            code: dailyMeta.code,
            amdxName: dailyMeta.amdx,
            sessionHint: dailyMeta.hint,
            remainingSeconds: dailyRem,
            progress: dailyProg
        )

        // 2. 90-Minute Micro Quarter (5400 sec each inside the 6-hour Daily Quarter)
        let microIdx = dailyElapsed / 5400 // 0..3
        let microElapsed = dailyElapsed % 5400
        let microRem = TimeInterval(5400 - microElapsed)
        let microProg = Double(microElapsed) / 5400.0
        let microMeta = quarterMetadata(index: microIdx, isDaily: false)
        let microQuarter = QuarterPhase(
            code: microMeta.code,
            amdxName: microMeta.amdx,
            sessionHint: microMeta.hint,
            remainingSeconds: microRem,
            progress: microProg
        )

        // 3. 22.5-Minute Sub-Quarter (1350 sec each inside the 90-min quarter)
        let subIdx = min(3, microElapsed / 1350)
        let subQuarterCode = "Q\(subIdx + 1)"

        let trueOpenStatus = nyHour < 18
            ? "TDO Aktif (00:00 NY sonrası)"
            : "Yeni Gün Akümülasyonu (18:00–00:00 NY)"

        return ClockSnapshot(
            now: date,
            tradingTimeFormatted: String(format: "%02d:%02d:%02d", tHour, tMin, tSec),
            nyTimeFormatted: String(format: "%02d:%02d NY", nyHour, nyMin),
            timezoneAbbreviation: tradingTZ.abbreviation(for: date) ?? preferences.timezone,
            isWeekendClosed: isWeekendClosed,
            isInKillzone: activeSession != nil,
            activeSessionName: activeSession?.name,
            activeSessionHours: activeSession?.rawLabel,
            activeRemainingSeconds: activeRem,
            activeProgress: activeProg,
            nextSessionName: nextCandidate?.session.name,
            nextSessionHours: nextCandidate?.session.rawLabel,
            secondsUntilNextSession: nextCandidate?.wait ?? 0,
            dailyQuarter: dailyQuarter,
            microQuarter: microQuarter,
            subQuarterCode: subQuarterCode,
            trueOpenStatus: trueOpenStatus
        )
    }

    private static func quarterMetadata(index: Int, isDaily: Bool) -> (code: String, amdx: String, hint: String) {
        switch index {
        case 0: return ("Q1", "Accumulation", isDaily ? "Asia (18:00–00:00 NY)" : "90dk Akümülasyon")
        case 1: return ("Q2", "Manipulation", isDaily ? "London (00:00–06:00 NY)" : "90dk Manipülasyon / Judas")
        case 2: return ("Q3", "Distribution", isDaily ? "NY AM (06:00–12:00 NY)" : "90dk Dağıtım / Ana Hareket")
        default: return ("Q4", "Continuation / X", isDaily ? "NY PM (12:00–18:00 NY)" : "90dk Devam / Dönüş")
        }
    }

    // MARK: - Countdown Formatting

    static func formatCountdown(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%02d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    static func formatShortCountdown(_ seconds: TimeInterval) -> String {
        let totalMinutes = max(1, Int((seconds / 60.0).rounded(.up)))
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        if h > 0 && m > 0 { return "\(h)s \(m)d" }
        if h > 0 { return "\(h)s" }
        return "\(m)d"
    }
}
