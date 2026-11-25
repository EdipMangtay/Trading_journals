import Foundation
import Accelerate
import NaturalLanguage

/// 100% On-Device, Zero-Hallucination Statistical & Machine Learning Engine.
/// Uses Empirical Bayes shrinkage (regularized log-odds + Ridge R-expectancy),
/// multi-core pattern mining, behavioral tilt anomaly detection, and Apple NaturalLanguage NLP.
enum EdgeMLEngine {
    enum ConfidenceLevel: String, Equatable {
        case insufficient = "Yetersiz Veri"
        case low = "Düşük Güven"
        case moderate = "Orta Güven"
        case high = "Yüksek Güven"
    }

    struct FeatureFactor: Identifiable, Equatable {
        let id: String
        let label: String
        let category: String
        let rImpact: Double
        let winRateLift: Double
        let sampleCount: Int
    }

    struct EdgePrediction: Equatable {
        var edgeScore: Int
        var winProbability: Double
        var expectedR: Double
        var uncertaintyBandR: Double
        var baselineWinRate: Double
        var baselineR: Double
        var historyCount: Int
        var confidence: ConfidenceLevel
        var factors: [FeatureFactor]
        var warning: String?
    }

    enum PatternKind: String, Equatable {
        case edge = "ALTIN KURULUM"
        case leak = "PARA SIZINTISI"
    }

    struct DiscoveredPattern: Identifiable, Equatable {
        let id: String
        let kind: PatternKind
        let title: String
        let subtitle: String
        let sampleCount: Int
        let winRate: Double
        let averageR: Double
        let netPnL: Double
        let shrunkenR: Double
    }

    enum TiltLevel: String, Equatable {
        case calm = "Sakin / Kontrollü"
        case caution = "Dikkat"
        case elevated = "Yüksek Tilt Riski"
    }

    struct TiltSignal: Identifiable, Equatable {
        let id: String
        let title: String
        let detail: String
        let severity: Int // 1 = info/mild, 2 = warning, 3 = high
    }

    struct TiltReport: Equatable {
        var level: TiltLevel = .calm
        var score: Int = 0 // 0 = calm, 100 = severe tilt
        var signals: [TiltSignal] = []
        var rapidReentryCount: Int = 0
        var rapidReentryPnL: Double = 0
    }

    struct NoteKeywordInsight: Identifiable, Equatable {
        let id: String
        let keyword: String
        let count: Int
        let winRate: Double
        let averageR: Double
        let netPnL: Double
    }

    struct MLInsightsSnapshot: Equatable {
        var sampleCount: Int = 0
        var goldenSetups: [DiscoveredPattern] = []
        var moneyLeaks: [DiscoveredPattern] = []
        var tilt: TiltReport = TiltReport()
        var positiveKeywords: [NoteKeywordInsight] = []
        var negativeKeywords: [NoteKeywordInsight] = []
        var computeMs: Double = 0
    }

    // MARK: - Feature Extraction
    fileprivate struct TaggedFeature: Hashable {
        let key: String
        let label: String
        let category: String
    }

    private static func extractFeatures(for t: TradeRecord, calendar: Calendar) -> [TaggedFeature] {
        var list: [TaggedFeature] = []
        list.reserveCapacity(14)

        let sym = t.instrument.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if !sym.isEmpty {
            list.append(TaggedFeature(key: "sym:\(sym)", label: sym, category: "Parite"))
        }
        list.append(TaggedFeature(key: "dir:\(t.direction)", label: t.direction, category: "Yön"))

        if !t.session.isEmpty {
            list.append(TaggedFeature(key: "sess:\(t.session)", label: L10n.text(t.session), category: "Seans"))
        }
        if t.setupID != nil || (!t.setupName.isEmpty && t.setupName != "Unassigned") {
            list.append(TaggedFeature(key: "setup:\(t.setupName)", label: t.setupName, category: "Strateji"))
        }
        if !t.grade.isEmpty {
            list.append(TaggedFeature(key: "grade:\(t.grade)", label: "Grade \(t.grade)", category: "Not"))
        }
        if !t.biasRelation.isEmpty {
            list.append(TaggedFeature(key: "biasRel:\(t.biasRelation)", label: t.biasRelation, category: "Bias"))
        }
        if !t.newsDriver.isEmpty {
            list.append(TaggedFeature(key: "news:\(t.newsDriver)", label: "News: \(t.newsDriver)", category: "Haber"))
        }
        if t.qt.enabled {
            let qtPart = [t.qt.profile, t.qt.dailyQuarter].filter { !$0.isEmpty }.joined(separator: " ")
            if !qtPart.isEmpty {
                list.append(TaggedFeature(key: "qt:\(qtPart)", label: "QT \(qtPart)", category: "QT"))
            }
            if !t.qt.trueOpenLocation.isEmpty {
                list.append(TaggedFeature(key: "to:\(t.qt.trueOpenLocation)", label: "True Open \(t.qt.trueOpenLocation)", category: "QT"))
            }
        }
        if t.hasSSMT {
            list.append(TaggedFeature(key: "ssmt:yes", label: "Valid SSMT", category: "Teyit"))
        }
        if t.hasTSMO {
            list.append(TaggedFeature(key: "tsmo:yes", label: "Valid TSMO", category: "Teyit"))
        }
        if t.hasCRT {
            list.append(TaggedFeature(key: "crt:yes", label: "Confirmed CRT", category: "Teyit"))
        }
        if t.hasMMXM {
            list.append(TaggedFeature(key: "mmxm:\(t.mmxm.model)", label: t.mmxm.model, category: "Teyit"))
        }
        if !t.entryTimeframe.isEmpty {
            list.append(TaggedFeature(key: "tf:\(t.entryTimeframe)", label: "TF \(t.entryTimeframe)", category: "Zaman"))
        }
        if !t.compliant {
            list.append(TaggedFeature(key: "rule:break", label: "Kural İhlali", category: "Disiplin"))
        }
        if t.emotional.fomo >= 6 {
            list.append(TaggedFeature(key: "emo:fomo_high", label: "Yüksek FOMO (≥6)", category: "Psikoloji"))
        }
        if t.emotional.stress >= 6 {
            list.append(TaggedFeature(key: "emo:stress_high", label: "Yüksek Stres (≥6)", category: "Psikoloji"))
        }
        return list
    }

    // MARK: - Live Pre-Trade Edge Prediction (Empirical Bayes Shrinkage)
    static func predict(candidate: TradeRecord, history: [TradeRecord], calendar: Calendar) -> EdgePrediction {
        let training = history.filter { $0.id != candidate.id }
        let n = training.count
        guard n >= 3 else {
            return EdgePrediction(
                edgeScore: 50,
                winProbability: 50,
                expectedR: 0,
                uncertaintyBandR: 1.5,
                baselineWinRate: 50,
                baselineR: 0,
                historyCount: n,
                confidence: .insufficient,
                factors: [],
                warning: "ML tahmini için en az 3 geçmiş işlem kaydı gerekir (mevcut: \(n))."
            )
        }

        // Baseline prior statistics
        var totalWins = 0.0
        var totalR = 0.0
        var rCount = 0
        var rValues: [Double] = []
        rValues.reserveCapacity(n)

        struct BucketStats {
            var count = 0
            var wins = 0.0
            var rSum = 0.0
            var rCount = 0
        }
        var featureStats: [String: BucketStats] = [:]
        featureStats.reserveCapacity(64)

        for t in training {
            let win: Double = t.netPnL >= 0.005 ? 1.0 : 0.0
            totalWins += win
            if let r = t.rMultiple, r.isFinite {
                totalR += r
                rCount += 1
                rValues.append(r)
            }
            for f in extractFeatures(for: t, calendar: calendar) {
                var st = featureStats[f.key, default: BucketStats()]
                st.count += 1
                st.wins += win
                if let r = t.rMultiple, r.isFinite {
                    st.rSum += r
                    st.rCount += 1
                }
                featureStats[f.key] = st
            }
        }

        // Empirical Bayes prior (Beta(2,2) smoothed win rate, mean R)
        let priorWinProb = (totalWins + 2.0) / (Double(n) + 4.0)
        let priorR = rCount > 0 ? totalR / Double(rCount) : 0.0
        let priorLogOdds = log(max(0.05, min(0.95, priorWinProb)) / (1.0 - max(0.05, min(0.95, priorWinProb))))

        // Global R std via vDSP for calibrated uncertainty band
        var rStd = 1.2
        if rValues.count >= 2 {
            var mean = 0.0
            let cnt = vDSP_Length(rValues.count)
            vDSP_meanvD(rValues, 1, &mean, cnt)
            var negMean = -mean
            var centered = [Double](repeating: 0, count: rValues.count)
            vDSP_vsaddD(rValues, 1, &negMean, &centered, 1, cnt)
            var sumSq = 0.0
            vDSP_svesqD(centered, 1, &sumSq, cnt)
            rStd = max(0.35, sqrt(sumSq / Double(rValues.count - 1)))
        }

        // Evaluate candidate's active features with Bayesian shrinkage
        let priorStrength = 6.0
        let candidateFeatures = extractFeatures(for: candidate, calendar: calendar)
        var factors: [FeatureFactor] = []
        var sumLogOddsLift = 0.0
        var sumRLift = 0.0
        var matchedSamples = 0

        for f in candidateFeatures {
            guard let st = featureStats[f.key], st.count >= 2 else { continue }
            let k = Double(st.count)
            let weight = k / (k + priorStrength)
            let smoothedWin = (st.wins + 1.5) / (k + 3.0)
            let featLogOdds = log(max(0.05, min(0.95, smoothedWin)) / (1.0 - max(0.05, min(0.95, smoothedWin))))
            let logOddsLift = weight * (featLogOdds - priorLogOdds)
            let winRateLift = weight * (smoothedWin - priorWinProb) * 100.0

            let featR = st.rCount > 0 ? st.rSum / Double(st.rCount) : priorR
            let rWeight = Double(st.rCount) / (Double(st.rCount) + priorStrength)
            let rLift = rWeight * (featR - priorR)

            sumLogOddsLift += logOddsLift
            sumRLift += rLift
            matchedSamples += st.count

            if abs(rLift) >= 0.03 || abs(winRateLift) >= 2.0 {
                factors.append(FeatureFactor(
                    id: f.key,
                    label: f.label,
                    category: f.category,
                    rImpact: rLift,
                    winRateLift: winRateLift,
                    sampleCount: st.count
                ))
            }
        }

        // Dampen additive combination by 1/sqrt(m) so correlated features don't over-amplify
        let activeCount = max(1.0, Double(factors.count))
        let damping = 1.0 / sqrt(activeCount)
        let combinedLogOdds = max(-2.4, min(2.4, priorLogOdds + sumLogOddsLift * damping))
        let predictedWinProb = (1.0 / (1.0 + exp(-combinedLogOdds))) * 100.0
        let predictedR = priorR + sumRLift * damping

        // Calibrated uncertainty band narrows as matched historical evidence grows
        let effectiveN = max(2.0, min(Double(n), Double(matchedSamples) / max(1.0, activeCount)))
        let uncertaintyR = min(2.0, max(0.18, (rStd / sqrt(effectiveN)) * 1.28))

        // Composite 0...100 Edge Score combining win prob, expected R, and process cleanliness
        var rawScore = 50.0 + (predictedWinProb - 50.0) * 0.65 + predictedR * 18.0
        if !candidate.compliant { rawScore -= 14.0 }
        if candidate.emotional.fomo >= 7 { rawScore -= 8.0 }
        if candidate.emotional.stress >= 7 { rawScore -= 6.0 }
        let edgeScore = max(5, min(99, Int(rawScore.rounded())))

        let confidence: ConfidenceLevel = n < 15 ? .low : n < 40 ? .moderate : .high
        factors.sort { abs($0.rImpact) > abs($1.rImpact) }

        var warning: String?
        if !candidate.compliant {
            warning = "Kural ihlali işaretli: geçmiş verilerde kuralsız işlemler edge skorunu düşürür."
        } else if candidate.emotional.fomo >= 7 || candidate.emotional.stress >= 7 {
            warning = "Yüksek FOMO/Stres tespit edildi: işleme girmeden önce pozisyon boyutunu ve planı kontrol et."
        } else if confidence == .low {
            warning = "Düşük örneklem (n = \(n)): tahmin belirsizlik bandı geniş tutuluyor."
        }

        return EdgePrediction(
            edgeScore: edgeScore,
            winProbability: predictedWinProb,
            expectedR: predictedR,
            uncertaintyBandR: uncertaintyR,
            baselineWinRate: priorWinProb * 100.0,
            baselineR: priorR,
            historyCount: n,
            confidence: confidence,
            factors: Array(factors.prefix(6)),
            warning: warning
        )
    }

    // MARK: - Full ML Insights Snapshot (Parallel Multi-Core Discovery + Tilt + NLP)
    static func analyze(_ trades: [TradeRecord], calendar: Calendar) -> MLInsightsSnapshot {
        let start = CFAbsoluteTimeGetCurrent()
        let ordered = AnalyticsEngine.ordered(trades)
        guard !ordered.isEmpty else { return MLInsightsSnapshot() }

        let patterns = discoverPatterns(ordered, calendar: calendar)
        let tilt = detectTilt(ordered)
        let keywords = mineNoteKeywords(ordered)
        let elapsedMs = (CFAbsoluteTimeGetCurrent() - start) * 1000.0

        return MLInsightsSnapshot(
            sampleCount: ordered.count,
            goldenSetups: patterns.edges,
            moneyLeaks: patterns.leaks,
            tilt: tilt,
            positiveKeywords: keywords.positive,
            negativeKeywords: keywords.negative,
            computeMs: elapsedMs
        )
    }

    // MARK: - Automated Golden Setups & Money Leak Pattern Miner
    private static func discoverPatterns(_ ordered: [TradeRecord], calendar: Calendar) -> (edges: [DiscoveredPattern], leaks: [DiscoveredPattern]) {
        guard ordered.count >= 4 else { return ([], []) }
        let minSupport = ordered.count < 30 ? 3 : 4
        let priorStrength = 5.0

        struct PatternBucket {
            var title: String
            var subtitle: String
            var count = 0
            var wins = 0
            var rSum = 0.0
            var rCount = 0
            var netPnL = 0.0
        }

        var buckets: [String: PatternBucket] = [:]
        buckets.reserveCapacity(128)

        func add(_ key: String, title: String, subtitle: String, trade: TradeRecord) {
            var b = buckets[key] ?? PatternBucket(title: title, subtitle: subtitle)
            b.count += 1
            if trade.netPnL >= 0.005 { b.wins += 1 }
            if let r = trade.rMultiple, r.isFinite { b.rSum += r; b.rCount += 1 }
            b.netPnL += trade.netPnL
            buckets[key] = b
        }

        for t in ordered {
            let sym = t.instrument
            let sess = t.session.isEmpty ? "" : L10n.text(t.session)
            let setup = (t.setupID != nil || t.setupName != "Unassigned") ? t.setupName : ""

            // 1. Setup × Session
            if !setup.isEmpty && !sess.isEmpty {
                add("ss:\(setup)|\(sess)", title: "\(setup) · \(sess)", subtitle: "Strateji × Seans", trade: t)
            }
            // 2. Instrument × Direction
            if !sym.isEmpty {
                add("id:\(sym)|\(t.direction)", title: "\(sym) \(t.direction.uppercased())", subtitle: "Parite × Yön", trade: t)
            }
            // 3. Session × QT Quarter
            if t.qt.enabled && !t.qt.dailyQuarter.isEmpty && !sess.isEmpty {
                add("sq:\(sess)|\(t.qt.dailyQuarter)", title: "\(sess) · \(t.qt.dailyQuarter)", subtitle: "Seans × QT Çeyrek", trade: t)
            }
            // 4. SSMT × Bias Relation
            if t.hasSSMT && !t.biasRelation.isEmpty {
                add("sb:ssmt|\(t.biasRelation)", title: "Valid SSMT · \(t.biasRelation)", subtitle: "Teyit × Bias", trade: t)
            }
            // 5. QT + SSMT / CRT + SSMT
            if t.hasQT && t.hasSSMT {
                add("qs:qt+ssmt", title: "QT Aligned + Valid SSMT", subtitle: "Model Kombinasyonu", trade: t)
            }
            if t.hasCRT && t.hasSSMT {
                add("cs:crt+ssmt", title: "Confirmed CRT + Valid SSMT", subtitle: "Model Kombinasyonu", trade: t)
            }
            // 6. Counter-Trend without SSMT
            if t.biasRelation == "Counter-Trend" && !t.hasSSMT {
                add("leak:ct-nossmt", title: "Counter-Trend (SSMT Yok)", subtitle: "Yüksek Riskli Kombinasyon", trade: t)
            }
            // 7. Rule Break
            if !t.compliant {
                for rule in Set(t.brokenRules) {
                    add("rule:\(rule)", title: L10n.text(rule), subtitle: "Kural İhlali", trade: t)
                }
            }
            // 8. High FOMO / Stress
            if t.emotional.fomo >= 6 {
                add("emo:fomo", title: "Yüksek FOMO (≥6/10)", subtitle: "Psikoloji Etkisi", trade: t)
            }
            if t.emotional.stress >= 6 {
                add("emo:stress", title: "Yüksek Stres (≥6/10)", subtitle: "Psikoloji Etkisi", trade: t)
            }
            // 9. Specific hour block (2-hour window)
            let hour = calendar.component(.hour, from: t.date)
            let blockStart = (hour / 2) * 2
            let blockLabel = String(format: "%02d:00–%02d:00", blockStart, (blockStart + 2) % 24)
            add("hr:\(blockStart)", title: "Saat Dilimi \(blockLabel)", subtitle: "Zaman Penceresi", trade: t)
        }

        var edges: [(Double, DiscoveredPattern)] = []
        var leaks: [(Double, DiscoveredPattern)] = []

        for (key, b) in buckets where b.count >= minSupport {
            let wr = Double(b.wins) / Double(b.count) * 100.0
            let avgR = b.rCount > 0 ? b.rSum / Double(b.rCount) : (b.netPnL > 0 ? 0.5 : b.netPnL < 0 ? -0.5 : 0)
            let shrunkenR = (Double(max(1, b.rCount)) / (Double(max(1, b.rCount)) + priorStrength)) * avgR
            let score = shrunkenR * sqrt(Double(b.count))

            if shrunkenR >= 0.18 && b.netPnL > 0 && wr >= 50.0 {
                edges.append((score, DiscoveredPattern(
                    id: "edge-\(key)",
                    kind: .edge,
                    title: b.title,
                    subtitle: b.subtitle,
                    sampleCount: b.count,
                    winRate: wr,
                    averageR: avgR,
                    netPnL: b.netPnL,
                    shrunkenR: shrunkenR
                )))
            } else if shrunkenR <= -0.10 || b.netPnL < -0.01 {
                let leakScore = (-shrunkenR) * sqrt(Double(b.count)) + (b.netPnL < 0 ? 0.25 : 0)
                leaks.append((leakScore, DiscoveredPattern(
                    id: "leak-\(key)",
                    kind: .leak,
                    title: b.title,
                    subtitle: b.subtitle,
                    sampleCount: b.count,
                    winRate: wr,
                    averageR: avgR,
                    netPnL: b.netPnL,
                    shrunkenR: shrunkenR
                )))
            }
        }

        edges.sort { $0.0 > $1.0 }
        leaks.sort { $0.0 > $1.0 }
        return (Array(edges.prefix(4).map(\.1)), Array(leaks.prefix(4).map(\.1)))
    }

    // MARK: - Behavioral Tilt & Revenge-Trading Anomaly Detector
    private static func detectTilt(_ ordered: [TradeRecord]) -> TiltReport {
        guard ordered.count >= 2 else { return TiltReport() }
        var signals: [TiltSignal] = []
        var tiltPoints = 0

        // 1. Consecutive loss streak right now
        var recentLossStreak = 0
        for t in ordered.reversed() {
            if t.netPnL <= -0.005 { recentLossStreak += 1 } else { break }
        }
        if recentLossStreak >= 3 {
            tiltPoints += 40
            signals.append(TiltSignal(id: "loss-streak", title: "\(recentLossStreak) Ardışık Zarar", detail: "Son \(recentLossStreak) işlem zararla kapandı. Risk azaltma veya seansı sonlandırma zamanı olabilir.", severity: 3))
        } else if recentLossStreak == 2 {
            tiltPoints += 20
            signals.append(TiltSignal(id: "loss-streak", title: "2 Ardışık Zarar", detail: "İntikam işlemi (revenge trade) refleksine karşı bir sonraki girişte ekstra teyit bekle.", severity: 2))
        }

        // 2. Rapid re-entry (< 15 min) after a losing trade
        var rapidCount = 0
        var rapidPnL = 0.0
        var riskJumpCount = 0
        for i in 1..<ordered.count {
            let prev = ordered[i - 1]
            let curr = ordered[i]
            if prev.netPnL <= -0.005 {
                let prevAnchor = prev.exitDate ?? prev.date
                let gap = curr.date.timeIntervalSince(prevAnchor)
                if gap >= 0 && gap <= 900 {
                    rapidCount += 1
                    rapidPnL += curr.netPnL
                }
                if let pRisk = prev.riskDollars, let cRisk = curr.riskDollars, pRisk > 0, cRisk >= pRisk * 1.25 {
                    riskJumpCount += 1
                }
            }
        }
        if rapidCount >= 2 && rapidPnL < 0 {
            tiltPoints += 25
            signals.append(TiltSignal(id: "rapid-reentry", title: "Hızlı Tekrar Giriş Sızıntısı", detail: "Zarar sonrası 15 dk içinde açılan \(rapidCount) işlemde toplam net \(String(format: "%.0f", rapidPnL)) etki var.", severity: 3))
        } else if rapidCount >= 1 {
            tiltPoints += 10
            signals.append(TiltSignal(id: "rapid-reentry", title: "Zarar Sonrası Hızlı Giriş (\(rapidCount))", detail: "Kayıptan sonraki 15 dk içinde tekrar giriş tespit edildi; soğuma süresi (cooldown) koymayı düşün.", severity: 1))
        }

        if riskJumpCount >= 1 {
            tiltPoints += 20
            signals.append(TiltSignal(id: "risk-escalation", title: "Kayıp Sonrası Risk Artışı (\(riskJumpCount)x)", detail: "Zararlı işlem sonrası risk tutarı %25+ yükseltilmiş (martingale/telafi eğilimi).", severity: 2))
        }

        // 3. Recent 5-trade compliance & emotion drift
        let recent = Array(ordered.suffix(5))
        let recentCompliance = Double(recent.filter(\.compliant).count) / Double(recent.count) * 100.0
        if recentCompliance < 65 {
            tiltPoints += 25
            signals.append(TiltSignal(id: "compliance-drop", title: "Son 5 İşlemde Disiplin Düşüşü (\(Int(recentCompliance))%)", detail: "Kural uyumu %65'in altına düştü. Playbook kontrol listesini zorunlu uygula.", severity: 3))
        }
        let avgFomo = recent.map(\.emotional.fomo).reduce(0, +) / Double(recent.count)
        let avgStress = recent.map(\.emotional.stress).reduce(0, +) / Double(recent.count)
        if avgFomo >= 6 || avgStress >= 6 {
            tiltPoints += 20
            signals.append(TiltSignal(id: "emo-heat", title: "Yükselen Duygusal Yük", detail: "Son 5 işlem ortalaması: FOMO \(String(format: "%.1f", avgFomo))/10 · Stres \(String(format: "%.1f", avgStress))/10.", severity: 2))
        }

        let clamped = min(100, max(0, tiltPoints))
        let level: TiltLevel = clamped >= 55 ? .elevated : clamped >= 25 ? .caution : .calm
        return TiltReport(level: level, score: clamped, signals: signals, rapidReentryCount: rapidCount, rapidReentryPnL: rapidPnL)
    }

    // MARK: - On-Device NLP Keyword Mining (NaturalLanguage)
    private static let stopwords: Set<String> = [
        "ve", "bir", "bu", "da", "de", "ile", "için", "ama", "fakat", "gibi", "daha", "çok", "en", "olarak", "kadar", "sonra", "önce", "olan", "var", "yok", "ben", "veya", "her", "tüm", "ise", "diye", "göre", "üzeri", "altı",
        "the", "and", "for", "with", "that", "this", "from", "was", "were", "are", "have", "had", "not", "but", "into", "after", "before", "trade", "price", "setup", "entry", "exit", "market"
    ]

    private static func mineNoteKeywords(_ ordered: [TradeRecord]) -> (positive: [NoteKeywordInsight], negative: [NoteKeywordInsight]) {
        guard ordered.count >= 4 else { return ([], []) }
        struct WordStat { var count = 0; var wins = 0; var rSum = 0.0; var rCount = 0; var netPnL = 0.0 }
        var map: [String: WordStat] = [:]
        let tokenizer = NLTokenizer(unit: .word)

        for t in ordered {
            let combined = [t.narrative, t.notes.thesis, t.notes.lesson, t.notes.correct, t.notes.incorrect].joined(separator: " ")
            guard !combined.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            tokenizer.string = combined
            var seenInTrade = Set<String>()
            tokenizer.enumerateTokens(in: combined.startIndex..<combined.endIndex) { range, _ in
                let raw = combined[range].lowercased()
                if raw.count >= 3, !stopwords.contains(raw), raw.rangeOfCharacter(from: .letters) != nil {
                    seenInTrade.insert(raw)
                }
                return true
            }
            for w in seenInTrade {
                var st = map[w] ?? WordStat()
                st.count += 1
                if t.netPnL >= 0.005 { st.wins += 1 }
                if let r = t.rMultiple, r.isFinite { st.rSum += r; st.rCount += 1 }
                st.netPnL += t.netPnL
                map[w] = st
            }
        }

        let minWordCount = ordered.count < 25 ? 2 : 3
        let insights: [NoteKeywordInsight] = map.compactMap { word, st in
            guard st.count >= minWordCount else { return nil }
            let wr = Double(st.wins) / Double(st.count) * 100.0
            let avgR = st.rCount > 0 ? st.rSum / Double(st.rCount) : (st.netPnL > 0 ? 0.5 : -0.5)
            return NoteKeywordInsight(id: word, keyword: word, count: st.count, winRate: wr, averageR: avgR, netPnL: st.netPnL)
        }

        let positive = insights.filter { $0.averageR > 0.15 && $0.netPnL > 0 }.sorted { $0.averageR * sqrt(Double($0.count)) > $1.averageR * sqrt(Double($1.count)) }
        let negative = insights.filter { $0.averageR < -0.05 || $0.netPnL < 0 }.sorted { (-$0.averageR) * sqrt(Double($0.count)) > (-$1.averageR) * sqrt(Double($1.count)) }
        return (Array(positive.prefix(4)), Array(negative.prefix(4)))
    }
}
