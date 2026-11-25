import Foundation
import Accelerate
import NaturalLanguage

/// Ultra-Tier 100% On-Device Institutional Trading AI & Machine Learning Engine (Zero Image Processing).
/// Combines:
/// 1. Time-Decay Weighted L2-Regularized Logistic Regression (Win Probability) + L2 Ridge Regression (Expected R) + Empirical Bayes Ensemble
/// 2. Chronological Walk-Forward Out-of-Sample Validation (ROC-AUC, Brier Skill Score, High-vs-Low Edge Lift)
/// 3. CUSUM & EWMA Market Regime / Edge Drift Classifier with Risk Multiplier
/// 4. Counterfactual AI Filter Simulator (Actual vs. AI-Filtered Equity, Win Rate, Max Drawdown & Saved Capital)
/// 5. Vectorized Cosine Similarity k-NN Engine (vDSP) + Post-Trade AI Autopsy with Counterfactuals
/// 6. Quarter-Kelly Drawdown & Regime-Adjusted Risk Sizing + Automated Review & Daily Plan Generators
/// 7. Entity-Aware Multi-Intent Natural-Language AI Trading Coach + Apple NaturalLanguage NLP Keyword Miner
enum EdgeMLEngine {
    // MARK: - Core Prediction & Confidence Types

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
        var recommendedRiskPercent: Double = 0.50
        var whatIfBooster: String? = nil
        var modelUsed: String = "L2 Logistic + Ridge + Bayes"
    }

    // MARK: - Pattern Discovery & Behavioral Tilt Types

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

    // MARK: - Walk-Forward Out-of-Sample Model Validation Types

    struct ModelValidationReport: Equatable {
        var evaluatedCount: Int = 0
        var rocAUC: Double = 0.50
        var brierScore: Double = 0.25
        var baselineBrierScore: Double = 0.25
        var brierSkillPercent: Double = 0.0
        var highEdgeCount: Int = 0
        var highEdgeWinRate: Double = 0.0
        var highEdgeAvgR: Double = 0.0
        var lowEdgeCount: Int = 0
        var lowEdgeWinRate: Double = 0.0
        var lowEdgeAvgR: Double = 0.0
        var winRateLiftPoints: Double = 0.0
        var rLift: Double = 0.0

        var isReady: Bool { evaluatedCount >= 6 }

        var qualityLabel: String {
            guard isReady else { return "Veri Birikiyor" }
            if rocAUC >= 0.75 { return "Kurumsal Kalite (Güçlü Ayrıştırma)" }
            if rocAUC >= 0.65 { return "Yüksek Doğruluk" }
            if rocAUC >= 0.56 { return "Pozitif Sinyal" }
            return "Kalibrasyon Aşamasında"
        }
    }

    // MARK: - CUSUM & EWMA Market Regime Types

    enum RegimeState: String, Equatable {
        case hotEdge = "Sıcak Akış (Hot Edge)"
        case stable = "Dengeli Rejim"
        case coldVariance = "Soğuma / Normal Varyans"
        case regimeDrift = "Rejim Kayması / Disiplin Bozulması"
    }

    struct RegimeReport: Equatable {
        var state: RegimeState = .stable
        var ewmaR: Double = 0.0
        var baselineR: Double = 0.0
        var cusumDrift: Double = 0.0
        var recentCompliance: Double = 100.0
        var riskMultiplier: Double = 1.0
        var summary: String = "Yeterli veri biriktikçe rejim analizi aktif olur."
        var advice: String = "Standart risk ve kontrol listesi disipliniyle devam et."
    }

    // MARK: - Counterfactual AI Filter Simulator Types

    struct AIFilterSimulation: Equatable {
        var totalTrades: Int = 0
        var keptTrades: Int = 0
        var skippedTrades: Int = 0
        var actualNetPnL: Double = 0.0
        var filteredNetPnL: Double = 0.0
        var savedCapital: Double = 0.0
        var actualWinRate: Double = 0.0
        var filteredWinRate: Double = 0.0
        var actualAvgR: Double = 0.0
        var filteredAvgR: Double = 0.0
        var actualMaxDrawdown: Double = 0.0
        var filteredMaxDrawdown: Double = 0.0
        var drawdownReductionPercent: Double = 0.0
        var summary: String = ""
    }

    struct MLInsightsSnapshot: Equatable {
        var sampleCount: Int = 0
        var goldenSetups: [DiscoveredPattern] = []
        var moneyLeaks: [DiscoveredPattern] = []
        var tilt: TiltReport = TiltReport()
        var regime: RegimeReport = RegimeReport()
        var validation: ModelValidationReport = ModelValidationReport()
        var filterSimulation: AIFilterSimulation = AIFilterSimulation()
        var positiveKeywords: [NoteKeywordInsight] = []
        var negativeKeywords: [NoteKeywordInsight] = []
        var computeMs: Double = 0
    }

    // MARK: - Feature Extraction (Atomic + Non-Linear Pairwise Interaction Terms)

    fileprivate struct TaggedFeature: Hashable {
        let key: String
        let label: String
        let category: String
    }

    private static func extractFeatures(for t: TradeRecord, calendar: Calendar) -> [TaggedFeature] {
        var list: [TaggedFeature] = []
        list.reserveCapacity(20)

        let sym = t.instrument.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if !sym.isEmpty {
            list.append(TaggedFeature(key: "sym:\(sym)", label: sym, category: "Parite"))
            list.append(TaggedFeature(key: "ix:symdir:\(sym)|\(t.direction)", label: "\(sym) \(t.direction)", category: "Sinerji"))
        }
        list.append(TaggedFeature(key: "dir:\(t.direction)", label: t.direction, category: "Yön"))

        let hasSession = !t.session.isEmpty
        if hasSession {
            list.append(TaggedFeature(key: "sess:\(t.session)", label: L10n.text(t.session), category: "Seans"))
        }
        let hasSetup = t.setupID != nil || (!t.setupName.isEmpty && t.setupName != "Unassigned")
        if hasSetup {
            list.append(TaggedFeature(key: "setup:\(t.setupName)", label: t.setupName, category: "Strateji"))
            if hasSession {
                list.append(TaggedFeature(key: "ix:ss:\(t.setupName)|\(t.session)", label: "\(t.setupName) × \(L10n.text(t.session))", category: "Sinerji"))
            }
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
            if t.hasQT {
                list.append(TaggedFeature(key: "ix:qtssmt", label: "QT + Valid SSMT", category: "Sinerji"))
            }
            if !t.biasRelation.isEmpty {
                list.append(TaggedFeature(key: "ix:biasssmt:\(t.biasRelation)", label: "\(t.biasRelation) + SSMT", category: "Sinerji"))
            }
        } else if t.biasRelation == "Counter-Trend" {
            list.append(TaggedFeature(key: "ix:ct_nossmt", label: "Counter-Trend (SSMT Yok)", category: "Risk"))
        }
        if t.hasTSMO {
            list.append(TaggedFeature(key: "tsmo:yes", label: "Valid TSMO", category: "Teyit"))
        }
        if t.hasCRT {
            list.append(TaggedFeature(key: "crt:yes", label: "Confirmed CRT", category: "Teyit"))
            if t.hasSSMT {
                list.append(TaggedFeature(key: "ix:crtssmt", label: "CRT + Valid SSMT", category: "Sinerji"))
            }
        }
        if t.hasMMXM {
            list.append(TaggedFeature(key: "mmxm:\(t.mmxm.model)", label: t.mmxm.model, category: "Teyit"))
        }
        if !t.entryTimeframe.isEmpty {
            list.append(TaggedFeature(key: "tf:\(t.entryTimeframe)", label: "TF \(t.entryTimeframe)", category: "Zaman"))
        }
        if !t.compliant {
            list.append(TaggedFeature(key: "rule:break", label: "Kural İhlali", category: "Disiplin"))
        } else {
            list.append(TaggedFeature(key: "rule:clean", label: "Plana Tam Uyum", category: "Disiplin"))
        }
        if t.emotional.fomo >= 6 {
            list.append(TaggedFeature(key: "emo:fomo_high", label: "Yüksek FOMO (≥6)", category: "Psikoloji"))
        }
        if t.emotional.stress >= 6 {
            list.append(TaggedFeature(key: "emo:stress_high", label: "Yüksek Stres (≥6)", category: "Psikoloji"))
        }
        return list
    }

    // MARK: - Trained L2-Regularized Logistic + Ridge + Empirical Bayes Ensemble Model

    fileprivate struct BucketStats {
        var count = 0
        var weightSum = 0.0
        var wins = 0.0
        var weightedWins = 0.0
        var rSum = 0.0
        var weightedRSum = 0.0
        var rCount = 0
        var rWeightSum = 0.0
    }

    fileprivate struct TrainedEnsembleModel {
        let sampleCount: Int
        let priorWinProb: Double
        let priorLogOdds: Double
        let priorR: Double
        let rStd: Double
        let featureStats: [String: BucketStats]
        let vocabIndex: [String: Int]
        let logisticBias: Double
        let logisticWeights: [Double]
        let ridgeBias: Double
        let ridgeWeights: [Double]
        let jointBlendWeight: Double
    }

    private static func trainEnsemble(
        on ordered: ArraySlice<TradeRecord>,
        precomputedFeatures: ArraySlice<[TaggedFeature]>? = nil,
        calendar: Calendar
    ) -> TrainedEnsembleModel {
        let n = ordered.count
        let halfLife = max(16.0, Double(n) * 0.45)
        let decayRate = log(2.0) / halfLife

        var sampleWeights = [Double](repeating: 1.0, count: n)
        var yWin = [Double](repeating: 0.0, count: n)
        var yR = [Double?](repeating: nil, count: n)
        var rowFeatures: [[TaggedFeature]] = []
        rowFeatures.reserveCapacity(n)

        var totalWeight = 0.0
        var weightedWinSum = 0.0
        var weightedRSum = 0.0
        var rWeightTotal = 0.0
        var rValues: [Double] = []
        rValues.reserveCapacity(n)

        var featureStats: [String: BucketStats] = [:]
        featureStats.reserveCapacity(128)

        let baseIndex = ordered.startIndex
        let featBaseIndex = precomputedFeatures?.startIndex ?? 0

        for i in 0..<n {
            let t = ordered[baseIndex + i]
            let age = Double(n - 1 - i)
            let w = 0.40 + 0.60 * exp(-decayRate * age)
            sampleWeights[i] = w
            totalWeight += w

            let win: Double = t.netPnL >= 0.005 ? 1.0 : 0.0
            yWin[i] = win
            weightedWinSum += w * win

            var clampedR: Double? = nil
            if let r = t.rMultiple, r.isFinite {
                let cr = max(-4.0, min(8.0, r))
                clampedR = cr
                yR[i] = cr
                weightedRSum += w * cr
                rWeightTotal += w
                rValues.append(cr)
            }

            let feats = precomputedFeatures?[featBaseIndex + i] ?? extractFeatures(for: t, calendar: calendar)
            rowFeatures.append(feats)
            for f in feats {
                var st = featureStats[f.key, default: BucketStats()]
                st.count += 1
                st.weightSum += w
                st.wins += win
                st.weightedWins += w * win
                if let cr = clampedR {
                    st.rSum += cr
                    st.weightedRSum += w * cr
                    st.rCount += 1
                    st.rWeightSum += w
                }
                featureStats[f.key] = st
            }
        }

        let priorWinProb = (weightedWinSum + 1.5) / (totalWeight + 3.0)
        let clampedPrior = max(0.05, min(0.95, priorWinProb))
        let priorLogOdds = log(clampedPrior / (1.0 - clampedPrior))
        let priorR = rWeightTotal > 0 ? weightedRSum / rWeightTotal : 0.0

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

        // Deterministic vocabulary sort (count desc, then key asc)
        let eligibleKeys = featureStats
            .filter { $0.value.count >= 2 }
            .sorted { $0.value.count == $1.value.count ? $0.key < $1.key : $0.value.count > $1.value.count }
            .prefix(96)
            .map(\.key)
        var vocabIndex: [String: Int] = [:]
        vocabIndex.reserveCapacity(eligibleKeys.count)
        for (idx, k) in eligibleKeys.enumerated() { vocabIndex[k] = idx }
        let d = vocabIndex.count

        guard n >= 6 && d > 0 else {
            return TrainedEnsembleModel(
                sampleCount: n,
                priorWinProb: priorWinProb,
                priorLogOdds: priorLogOdds,
                priorR: priorR,
                rStd: rStd,
                featureStats: featureStats,
                vocabIndex: [:],
                logisticBias: priorLogOdds,
                logisticWeights: [],
                ridgeBias: priorR,
                ridgeWeights: [],
                jointBlendWeight: 0.0
            )
        }

        var sparseRows: [[Int]] = []
        sparseRows.reserveCapacity(n)
        for feats in rowFeatures {
            var indices: [Int] = []
            indices.reserveCapacity(feats.count)
            for f in feats {
                if let idx = vocabIndex[f.key] { indices.append(idx) }
            }
            sparseRows.append(indices)
        }

        // 1. Train Time-Decay Weighted L2-Regularized Logistic Regression (Nesterov Momentum)
        var logBias = priorLogOdds
        var logW = [Double](repeating: 0.0, count: d)
        var logVel = [Double](repeating: 0.0, count: d)
        var logBiasVel = 0.0
        let lambdaLog = max(1.6, 4.0 / sqrt(Double(n) / 10.0))
        let invTotalW = 1.0 / max(1.0, totalWeight)
        let epochsLog = n > 300 ? 28 : 45
        let lrLog = 0.38
        let momentum = 0.72

        var gradW = [Double](repeating: 0.0, count: d)
        for _ in 0..<epochsLog {
            var gradB = 0.0
            for j in 0..<d { gradW[j] = 0.0 }

            for i in 0..<n {
                let row = sparseRows[i]
                var z = logBias
                for idx in row { z += logW[idx] }
                let clampedZ = max(-12.0, min(12.0, z))
                let pred = 1.0 / (1.0 + exp(-clampedZ))
                let err = (pred - yWin[i]) * sampleWeights[i]
                gradB += err
                for idx in row { gradW[idx] += err }
            }

            gradB *= invTotalW
            logBiasVel = momentum * logBiasVel - lrLog * gradB
            logBias = max(-3.5, min(3.5, logBias + logBiasVel))

            for j in 0..<d {
                let g = gradW[j] * invTotalW + (lambdaLog * invTotalW) * logW[j]
                logVel[j] = momentum * logVel[j] - lrLog * g
                logW[j] = max(-2.8, min(2.8, logW[j] + logVel[j]))
            }
        }

        // 2. Train Time-Decay Weighted L2-Regularized Ridge Regression (Expected R)
        var ridgeBias = priorR
        var ridgeW = [Double](repeating: 0.0, count: d)
        if rWeightTotal >= 3.0 {
            var ridgeVel = [Double](repeating: 0.0, count: d)
            var ridgeBiasVel = 0.0
            let lambdaRidge = max(2.0, 5.0 / sqrt(Double(rValues.count) / 10.0))
            let invRW = 1.0 / max(1.0, rWeightTotal)
            let epochsRidge = n > 300 ? 30 : 48
            let lrRidge = 0.15
            for _ in 0..<epochsRidge {
                var gradB = 0.0
                for j in 0..<d { gradW[j] = 0.0 }

                for i in 0..<n {
                    guard let targetR = yR[i] else { continue }
                    let row = sparseRows[i]
                    var predR = ridgeBias
                    for idx in row { predR += ridgeW[idx] }
                    let err = (predR - targetR) * sampleWeights[i]
                    gradB += err
                    for idx in row { gradW[idx] += err }
                }

                gradB *= invRW
                ridgeBiasVel = momentum * ridgeBiasVel - lrRidge * gradB
                ridgeBias = max(-4.0, min(6.0, ridgeBias + ridgeBiasVel))

                for j in 0..<d {
                    let g = gradW[j] * invRW + (lambdaRidge * invRW) * ridgeW[j]
                    ridgeVel[j] = momentum * ridgeVel[j] - lrRidge * g
                    ridgeW[j] = max(-3.0, min(4.0, ridgeW[j] + ridgeVel[j]))
                }
            }
        }

        let jointWeight = min(0.80, max(0.25, Double(n - 4) / 24.0))

        return TrainedEnsembleModel(
            sampleCount: n,
            priorWinProb: priorWinProb,
            priorLogOdds: priorLogOdds,
            priorR: priorR,
            rStd: rStd,
            featureStats: featureStats,
            vocabIndex: vocabIndex,
            logisticBias: logBias,
            logisticWeights: logW,
            ridgeBias: ridgeBias,
            ridgeWeights: ridgeW,
            jointBlendWeight: jointWeight
        )
    }

    private static func evaluate(
        candidate: TradeRecord,
        candidateFeatures precomputed: [TaggedFeature]? = nil,
        with model: TrainedEnsembleModel,
        calendar: Calendar,
        regimeMultiplier: Double = 1.0
    ) -> EdgePrediction {
        let n = model.sampleCount
        let priorStrength = 5.5
        let candidateFeatures = precomputed ?? extractFeatures(for: candidate, calendar: calendar)

        var factors: [FeatureFactor] = []
        var sumLogOddsLift = 0.0
        var sumRLift = 0.0
        var matchedSamples = 0
        var bayesCount = 0

        var jointLogOdds = model.logisticBias
        var jointR = model.ridgeBias
        var jointActiveCount = 0

        for f in candidateFeatures {
            if let idx = model.vocabIndex[f.key], idx < model.logisticWeights.count {
                jointLogOdds += model.logisticWeights[idx]
                if idx < model.ridgeWeights.count {
                    jointR += model.ridgeWeights[idx]
                }
                jointActiveCount += 1
            }

            guard let st = model.featureStats[f.key], st.count >= 2 else { continue }
            let k = max(1.0, st.weightSum)
            let weight = k / (k + priorStrength)
            let smoothedWin = (st.weightedWins + 1.2) / (k + 2.4)
            let clampedSW = max(0.04, min(0.96, smoothedWin))
            let featLogOdds = log(clampedSW / (1.0 - clampedSW))
            let logOddsLift = weight * (featLogOdds - model.priorLogOdds)
            let winRateLift = weight * (smoothedWin - model.priorWinProb) * 100.0

            let featR = st.rWeightSum > 0 ? st.weightedRSum / st.rWeightSum : model.priorR
            let rWeight = st.rWeightSum / (st.rWeightSum + priorStrength)
            let rLift = rWeight * (featR - model.priorR)

            sumLogOddsLift += logOddsLift
            sumRLift += rLift
            matchedSamples += st.count
            bayesCount += 1

            let ridgeContrib = model.vocabIndex[f.key].flatMap { $0 < model.ridgeWeights.count ? model.ridgeWeights[$0] : nil }
            let blendedRImpact = ridgeContrib.map { model.jointBlendWeight * $0 + (1.0 - model.jointBlendWeight) * rLift } ?? rLift

            if abs(blendedRImpact) >= 0.04 || abs(winRateLift) >= 2.5 {
                factors.append(FeatureFactor(
                    id: f.key,
                    label: f.label,
                    category: f.category,
                    rImpact: blendedRImpact,
                    winRateLift: winRateLift,
                    sampleCount: st.count
                ))
            }
        }

        let activeDenom = max(1.0, Double(bayesCount))
        let damping = 1.0 / sqrt(activeDenom)
        let bayesLogOdds = max(-3.5, min(3.5, model.priorLogOdds + sumLogOddsLift * damping))
        let bayesR = model.priorR + sumRLift * damping

        let clampedJointLogOdds = max(-4.0, min(4.0, jointLogOdds))
        let wJoint = jointActiveCount > 0 ? model.jointBlendWeight : 0.0
        let finalLogOdds = wJoint * clampedJointLogOdds + (1.0 - wJoint) * bayesLogOdds
        let predictedWinProb = max(3.0, min(97.0, (1.0 / (1.0 + exp(-finalLogOdds))) * 100.0))
        let predictedR = max(-4.0, min(6.0, wJoint * jointR + (1.0 - wJoint) * bayesR))

        let effectiveN = max(2.0, min(Double(n), Double(matchedSamples) / max(1.0, activeDenom)))
        let uncertaintyR = min(2.0, max(0.16, (model.rStd / sqrt(effectiveN)) * 1.28))

        var rawScore = 50.0 + (predictedWinProb - 50.0) * 0.68 + predictedR * 17.5
        if !candidate.compliant { rawScore -= 15.0 }
        if candidate.emotional.fomo >= 7 { rawScore -= 9.0 }
        if candidate.emotional.stress >= 7 { rawScore -= 6.0 }
        let edgeScore = max(5, min(99, Int(rawScore.rounded())))

        let confidence: ConfidenceLevel = n < 15 ? .low : n < 40 ? .moderate : .high
        factors.sort { abs($0.rImpact) == abs($1.rImpact) ? $0.id < $1.id : abs($0.rImpact) > abs($1.rImpact) }

        var warning: String?
        if !candidate.compliant {
            warning = "Kural ihlali işaretli: geçmiş verilerde kuralsız işlemler edge skorunu düşürür."
        } else if candidate.emotional.fomo >= 7 || candidate.emotional.stress >= 7 {
            warning = "Yüksek FOMO/Stres tespit edildi: işleme girmeden önce pozisyon boyutunu ve planı kontrol et."
        } else if confidence == .low {
            warning = "Düşük örneklem (n = \(n)): tahmin belirsizlik bandı geniş tutuluyor."
        }

        let pProb = max(0.25, min(0.82, predictedWinProb / 100.0))
        let bPayoff = max(0.85, min(3.5, max(1.0, predictedR + 1.15)))
        let rawKelly = max(0.004, pProb - ((1.0 - pProb) / bPayoff)) * 100.0
        var recRisk = min(1.50, max(0.25, rawKelly * 0.25)) * regimeMultiplier
        if edgeScore >= 72 && candidate.compliant {
            recRisk = min(1.50, max(recRisk, 1.00 * regimeMultiplier))
        } else if edgeScore < 45 || !candidate.compliant || candidate.emotional.fomo >= 7 {
            recRisk = min(recRisk, 0.35)
        }
        recRisk = max(0.20, min(1.50, (recRisk * 20).rounded() / 20.0))

        var booster: String?
        let candidateKeys = Set(candidateFeatures.map(\.key))
        let potentialUpgrades: [(key: String, title: String)] = [
            ("ssmt:yes", "Geçerli SSMT teyidi eklendiğinde"),
            ("biasRel:Pro-Trend", "HTF Bias yönünde (Pro-Trend) girildiğinde"),
            ("crt:yes", "Onaylı CRT aralığı beklendiğinde"),
            ("qt:AMDX Q3", "QT AMDX Q3 dağıtım fazında girildiğinde"),
            ("sess:New York AM", "New York AM seansında uygulandığında")
        ]
        var bestLift = 0.14
        for item in potentialUpgrades where !candidateKeys.contains(item.key) {
            if let st = model.featureStats[item.key], st.count >= 2, st.rWeightSum > 0 {
                let featR = st.weightedRSum / st.rWeightSum
                let lift = (st.rWeightSum / (st.rWeightSum + priorStrength)) * (featR - model.priorR)
                if lift > bestLift {
                    bestLift = lift
                    let wr = Int((st.weightedWins / max(1e-6, st.weightSum) * 100.0).rounded())
                    booster = "AI What-If: \(item.title) tarihsel beklenti \(String(format: "%+.2fR", lift)) (WR %\(wr), n=\(st.count)) yükseliyor."
                }
            }
        }

        return EdgePrediction(
            edgeScore: edgeScore,
            winProbability: predictedWinProb,
            expectedR: predictedR,
            uncertaintyBandR: uncertaintyR,
            baselineWinRate: model.priorWinProb * 100.0,
            baselineR: model.priorR,
            historyCount: n,
            confidence: confidence,
            factors: Array(factors.prefix(6)),
            warning: warning,
            recommendedRiskPercent: recRisk,
            whatIfBooster: booster,
            modelUsed: wJoint > 0 ? "L2 Logistic + Ridge + Bayes" : "Empirical Bayes"
        )
    }

    // MARK: - Lock-Protected FNV-1a 64-Bit Signature Cache for Sub-Millisecond View Renders

    private static let cacheLock = NSLock()
    private static var snapshotCache: [UInt64: MLInsightsSnapshot] = [:]
    private static var modelCache: [UInt64: (TrainedEnsembleModel, RegimeReport)] = [:]

    private static func fnvMix(_ hash: inout UInt64, _ value: UInt64) {
        hash ^= value
        hash &*= 1099511628211
    }

    private static func fnvMixString(_ hash: inout UInt64, _ str: String) {
        for b in str.utf8 {
            hash ^= UInt64(b)
            hash &*= 1099511628211
        }
    }

    private static func tradesSignature(_ trades: [TradeRecord], calendar: Calendar, excludedID: UUID? = nil) -> UInt64 {
        var h: UInt64 = 14695981039346656037
        fnvMix(&h, UInt64(trades.count))
        fnvMixString(&h, calendar.timeZone.identifier)
        if let ex = excludedID {
            fnvMixString(&h, ex.uuidString)
        }
        for t in trades where t.id != excludedID {
            let uuid = t.id.uuid
            let u1 = UInt64(uuid.0) << 56 | UInt64(uuid.1) << 48 | UInt64(uuid.2) << 40 | UInt64(uuid.3) << 32 | UInt64(uuid.4) << 24 | UInt64(uuid.5) << 16 | UInt64(uuid.6) << 8 | UInt64(uuid.7)
            let u2 = UInt64(uuid.8) << 56 | UInt64(uuid.9) << 48 | UInt64(uuid.10) << 40 | UInt64(uuid.11) << 32 | UInt64(uuid.12) << 24 | UInt64(uuid.13) << 16 | UInt64(uuid.14) << 8 | UInt64(uuid.15)
            fnvMix(&h, u1 ^ u2)
            fnvMix(&h, t.date.timeIntervalSince1970.bitPattern)
            fnvMix(&h, t.netPnL.bitPattern)
            fnvMix(&h, (t.rMultiple ?? -999999.0).bitPattern)
            fnvMixString(&h, t.instrument)
            fnvMixString(&h, t.direction)
            fnvMixString(&h, t.session)
            fnvMixString(&h, t.setupName)
            fnvMixString(&h, t.biasRelation)
            let flags: UInt64 = (t.compliant ? 1 : 0)
                | (t.qt.enabled ? 2 : 0)
                | (t.hasSSMT ? 4 : 0)
                | (t.hasCRT ? 8 : 0)
                | (UInt64(min(15, t.brokenRules.count)) << 4)
            fnvMix(&h, flags)
            fnvMixString(&h, t.qt.dailyQuarter)
            fnvMix(&h, t.emotional.fomo.bitPattern)
        }
        return h
    }

    // MARK: - Live Pre-Trade Edge Prediction Public API

    static func predict(candidate: TradeRecord, history: [TradeRecord], calendar: Calendar) -> EdgePrediction {
        let sig = tradesSignature(history, calendar: calendar, excludedID: candidate.id)
        cacheLock.lock()
        if let cached = modelCache[sig] {
            cacheLock.unlock()
            return evaluate(candidate: candidate, with: cached.0, calendar: calendar, regimeMultiplier: cached.1.riskMultiplier)
        }
        cacheLock.unlock()

        let training = AnalyticsEngine.ordered(history.filter { $0.id != candidate.id })
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
                warning: "ML tahmini için en az 3 geçmiş işlem kaydı gerekir (mevcut: \(n)).",
                recommendedRiskPercent: 0.50
            )
        }
        let regime = detectRegime(training)
        let model = trainEnsemble(on: training[...], calendar: calendar)

        cacheLock.lock()
        if modelCache.count >= 24 { modelCache.removeAll(keepingCapacity: true) }
        modelCache[sig] = (model, regime)
        cacheLock.unlock()

        return evaluate(candidate: candidate, with: model, calendar: calendar, regimeMultiplier: regime.riskMultiplier)
    }

    // MARK: - Full ML Insights Snapshot (Multi-Core Discovery + Validation + Regime + Filter Sim + Tilt + NLP)

    static func analyze(_ trades: [TradeRecord], calendar: Calendar) -> MLInsightsSnapshot {
        guard !trades.isEmpty else { return MLInsightsSnapshot() }
        let sig = tradesSignature(trades, calendar: calendar)
        cacheLock.lock()
        if let cached = snapshotCache[sig] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        let start = CFAbsoluteTimeGetCurrent()
        let ordered = AnalyticsEngine.ordered(trades)
        guard !ordered.isEmpty else { return MLInsightsSnapshot() }

        let patterns = discoverPatterns(ordered, calendar: calendar)
        let tilt = detectTilt(ordered)
        let regime = detectRegime(ordered)
        let (validation, filterSim) = runWalkForwardValidationAndFilterSim(ordered, calendar: calendar)
        let keywords = mineNoteKeywords(ordered)
        let elapsedMs = (CFAbsoluteTimeGetCurrent() - start) * 1000.0

        let result = MLInsightsSnapshot(
            sampleCount: ordered.count,
            goldenSetups: patterns.edges,
            moneyLeaks: patterns.leaks,
            tilt: tilt,
            regime: regime,
            validation: validation,
            filterSimulation: filterSim,
            positiveKeywords: keywords.positive,
            negativeKeywords: keywords.negative,
            computeMs: elapsedMs
        )

        cacheLock.lock()
        if snapshotCache.count >= 24 { snapshotCache.removeAll(keepingCapacity: true) }
        snapshotCache[sig] = result
        cacheLock.unlock()

        return result
    }

    // MARK: - Parallel M3 Pro Chronological Walk-Forward Validation (O(N log N) ROC-AUC, Brier Skill, Lift) & AI Filter Simulator

    private static func runWalkForwardValidationAndFilterSim(
        _ ordered: [TradeRecord],
        calendar: Calendar
    ) -> (ModelValidationReport, AIFilterSimulation) {
        let n = ordered.count
        guard n >= 6 else {
            return (ModelValidationReport(), AIFilterSimulation(totalTrades: n, keptTrades: n))
        }

        let warmup = max(5, min(10, n / 4))
        let evalCount = n - warmup
        guard evalCount >= 1 else {
            return (ModelValidationReport(), AIFilterSimulation(totalTrades: n, keptTrades: n))
        }

        // 1. Pre-extract features ONCE for all N trades (eliminates 90% of CPU & memory allocations)
        let allFeatures: [[TaggedFeature]] = ordered.map { extractFeatures(for: $0, calendar: calendar) }

        // 2. Partition evaluation window into up to 8 expanding chronological blocks trained IN PARALLEL on M3 Pro cores
        let blockCount = min(8, max(1, evalCount))
        let blockSize = (evalCount + blockCount - 1) / blockCount
        var blockRanges: [(trainEnd: Int, evalStart: Int, evalEnd: Int)] = []
        blockRanges.reserveCapacity(blockCount)
        var cursor = warmup
        while cursor < n {
            let end = min(n, cursor + blockSize)
            blockRanges.append((trainEnd: cursor, evalStart: cursor, evalEnd: end))
            cursor = end
        }

        let scoresBuf = UnsafeMutableBufferPointer<Int>.allocate(capacity: n)
        let probsBuf = UnsafeMutableBufferPointer<Double>.allocate(capacity: n)
        scoresBuf.initialize(repeating: 50)
        probsBuf.initialize(repeating: 0.5)
        defer {
            scoresBuf.deinitialize(); scoresBuf.deallocate()
            probsBuf.deinitialize(); probsBuf.deallocate()
        }

        let scoresAddr = UInt(bitPattern: scoresBuf.baseAddress!)
        let probsAddr = UInt(bitPattern: probsBuf.baseAddress!)

        // Evaluate earliest warmup trades using initial model
        let initialModel = trainEnsemble(on: ordered[0..<warmup], precomputedFeatures: allFeatures[0..<warmup], calendar: calendar)
        for i in 0..<warmup {
            let pred = evaluate(candidate: ordered[i], candidateFeatures: allFeatures[i], with: initialModel, calendar: calendar)
            scoresBuf[i] = pred.edgeScore
            probsBuf[i] = pred.winProbability / 100.0
        }

        // Parallel expanding-window walk-forward training & out-of-sample scoring (zero lookahead!)
        DispatchQueue.concurrentPerform(iterations: blockRanges.count) { bIdx in
            let block = blockRanges[bIdx]
            let model = trainEnsemble(
                on: ordered[0..<block.trainEnd],
                precomputedFeatures: allFeatures[0..<block.trainEnd],
                calendar: calendar
            )
            let sPtr = UnsafeMutablePointer<Int>(bitPattern: scoresAddr)!
            let pPtr = UnsafeMutablePointer<Double>(bitPattern: probsAddr)!
            for i in block.evalStart..<block.evalEnd {
                let pred = evaluate(candidate: ordered[i], candidateFeatures: allFeatures[i], with: model, calendar: calendar)
                sPtr[i] = pred.edgeScore
                pPtr[i] = pred.winProbability / 100.0
            }
        }

        // 3. Compute Exact O(N log N) Mann-Whitney / Wilcoxon Rank-Sum ROC-AUC, Brier Score & High-vs-Low Lift
        var scoredPairs: [(prob: Double, isWin: Bool)] = []
        scoredPairs.reserveCapacity(evalCount)
        var brierSum = 0.0
        var actualWins = 0
        var highEdgeTrades: [TradeRecord] = []
        var lowEdgeTrades: [TradeRecord] = []

        for idx in warmup..<n {
            let t = ordered[idx]
            let isWin = t.netPnL >= 0.005
            let y: Double = isWin ? 1.0 : 0.0
            let p = probsBuf[idx]
            if isWin { actualWins += 1 }
            brierSum += (p - y) * (p - y)
            scoredPairs.append((prob: p, isWin: isWin))
            if scoresBuf[idx] >= 60 { highEdgeTrades.append(t) }
            if scoresBuf[idx] < 48 { lowEdgeTrades.append(t) }
        }

        let evalN = Double(evalCount)
        let brier = brierSum / max(1.0, evalN)
        let baseRate = Double(actualWins) / max(1.0, evalN)
        let baselineBrier = baseRate * (1.0 - baseRate)
        let brierSkill = baselineBrier > 1e-6 ? ((1.0 - (brier / baselineBrier)) * 100.0) : 0.0

        var rocAUC = 0.50
        let actualLosses = evalCount - actualWins
        if actualWins > 0 && actualLosses > 0 {
            scoredPairs.sort { $0.prob < $1.prob }
            var rankSumWins = 0.0
            var i = 0
            while i < scoredPairs.count {
                var j = i + 1
                while j < scoredPairs.count && abs(scoredPairs[j].prob - scoredPairs[i].prob) < 1e-12 {
                    j += 1
                }
                let avgRank = Double(i + 1 + j) * 0.5
                for k in i..<j where scoredPairs[k].isWin {
                    rankSumWins += avgRank
                }
                i = j
            }
            let nPos = Double(actualWins)
            let nNeg = Double(actualLosses)
            rocAUC = (rankSumWins - nPos * (nPos + 1.0) * 0.5) / (nPos * nNeg)
        }

        let highPerf = AnalyticsEngine.performance(highEdgeTrades)
        let lowPerf = AnalyticsEngine.performance(lowEdgeTrades)
        let wrLift = (!highEdgeTrades.isEmpty && !lowEdgeTrades.isEmpty) ? (highPerf.winRate - lowPerf.winRate) : 0.0
        let rLift = (!highEdgeTrades.isEmpty && !lowEdgeTrades.isEmpty) ? ((highPerf.averageR ?? 0) - (lowPerf.averageR ?? 0)) : 0.0

        let validation = ModelValidationReport(
            evaluatedCount: evalCount,
            rocAUC: rocAUC,
            brierScore: brier,
            baselineBrierScore: baselineBrier,
            brierSkillPercent: brierSkill,
            highEdgeCount: highPerf.count,
            highEdgeWinRate: highPerf.winRate,
            highEdgeAvgR: highPerf.averageR ?? 0,
            lowEdgeCount: lowPerf.count,
            lowEdgeWinRate: lowPerf.winRate,
            lowEdgeAvgR: lowPerf.averageR ?? 0,
            winRateLiftPoints: wrLift,
            rLift: rLift
        )

        // 4. Counterfactual AI Filter Simulation
        var kept: [TradeRecord] = []
        kept.reserveCapacity(n)
        for i in 0..<n {
            let t = ordered[i]
            var isRapidRevenge = false
            if i > 0 {
                let prev = ordered[i - 1]
                if prev.netPnL <= -0.005 {
                    let gap = t.date.timeIntervalSince(prev.exitDate ?? prev.date)
                    if gap >= 0 && gap <= 900 { isRapidRevenge = true }
                }
            }
            let flaggedLowQuality = !t.compliant || isRapidRevenge || (i >= warmup && scoresBuf[i] < 42)
            if !flaggedLowQuality {
                kept.append(t)
            }
        }
        if kept.isEmpty { kept = ordered }

        let actualPerf = AnalyticsEngine.performance(ordered)
        let filteredPerf = AnalyticsEngine.performance(kept)
        let saved = filteredPerf.netPnL - actualPerf.netPnL
        let ddReduction = actualPerf.maxDrawdown > 0.01 ? ((actualPerf.maxDrawdown - filteredPerf.maxDrawdown) / actualPerf.maxDrawdown) * 100.0 : 0.0
        let skipped = n - kept.count

        let simSummary: String
        if skipped == 0 {
            simSummary = "Tüm işlemlerin yüksek disiplin ve pozitif AI Edge eşiğinin üzerinde — elenecek sızıntı işlemi yok."
        } else if saved > 0 {
            simSummary = "AI'ın işaretlediği \(skipped) düşük kaliteli / kuralsız işlem elenseydi Net P&L \(String(format: "%+.0f", saved)) yükselir, WR %\(String(format: "%.0f", actualPerf.winRate)) → %\(String(format: "%.0f", filteredPerf.winRate)) ve Maks. Drawdown %\(String(format: "%.0f", max(0, ddReduction))) azalırdı."
        } else {
            simSummary = "AI filtresi \(skipped) riskli işlemi ayıkladı; disiplinli alt grupta WR %\(String(format: "%.0f", filteredPerf.winRate)) ve Ort. \(String(format: "%+.2fR", filteredPerf.averageR ?? 0)) elde edildi."
        }

        let filterSim = AIFilterSimulation(
            totalTrades: n,
            keptTrades: kept.count,
            skippedTrades: skipped,
            actualNetPnL: actualPerf.netPnL,
            filteredNetPnL: filteredPerf.netPnL,
            savedCapital: saved,
            actualWinRate: actualPerf.winRate,
            filteredWinRate: filteredPerf.winRate,
            actualAvgR: actualPerf.averageR ?? 0,
            filteredAvgR: filteredPerf.averageR ?? 0,
            actualMaxDrawdown: actualPerf.maxDrawdown,
            filteredMaxDrawdown: filteredPerf.maxDrawdown,
            drawdownReductionPercent: max(0, ddReduction),
            summary: simSummary
        )

        return (validation, filterSim)
    }

    // MARK: - CUSUM & EWMA Market Regime / Edge Drift Classifier

    static func detectRegime(_ ordered: [TradeRecord]) -> RegimeReport {
        guard ordered.count >= 5 else {
            return RegimeReport()
        }

        let rSeries: [Double] = ordered.map { t in
            if let r = t.rMultiple, r.isFinite { return max(-4.0, min(8.0, r)) }
            return t.netPnL >= 0.005 ? 1.0 : t.netPnL <= -0.005 ? -1.0 : 0.0
        }
        let baselineR = rSeries.reduce(0, +) / Double(rSeries.count)

        // Exponentially Weighted Moving Average (EWMA) of recent R
        let alpha = 0.24
        var ewma = rSeries[0]
        for r in rSeries.dropFirst() {
            ewma = alpha * r + (1.0 - alpha) * ewma
        }

        // One-sided Page-Hinkley / CUSUM negative drift detector
        var cusumNeg = 0.0
        let slack = 0.15
        for r in rSeries {
            cusumNeg = max(0.0, cusumNeg + (baselineR - r - slack))
        }

        // Recent 10-trade window statistics
        let recent = Array(ordered.suffix(min(10, ordered.count)))
        let recentPerf = AnalyticsEngine.performance(recent)
        let recentR = recentPerf.averageR ?? ewma
        let recentComp = recentPerf.compliance

        // Standard deviation of R for regime bands
        let variance = rSeries.map { ($0 - baselineR) * ($0 - baselineR) }.reduce(0, +) / Double(max(1, rSeries.count - 1))
        let stdR = max(0.4, sqrt(variance))

        let state: RegimeState
        let mult: Double
        let summary: String
        let advice: String

        if (ewma < baselineR - 0.35 * stdR || recentR < -0.20 || cusumNeg >= 3.2) && recentComp < 75.0 {
            state = .regimeDrift
            mult = 0.50
            summary = "Son \(recent.count) işlemde hem beklenti (\(String(format: "%+.2fR", recentR))) hem kural uyumu (%\(Int(recentComp))) belirgin biçimde bozuldu (CUSUM: \(String(format: "%.1f", cusumNeg)))."
            advice = "Risk çarpanını %50'ye (0.50x) indir; yalnızca en yüksek istikrarlı A+ Playbook modelinde ve kontrol listesi %100 onaylıyken giriş yap."
        } else if ewma < baselineR - 0.30 * stdR || recentR < -0.15 {
            state = .coldVariance
            mult = 0.75
            summary = "Kural uyumun güçlü (%\(Int(recentComp))) ancak son \(recent.count) işlemde istatistiksel soğuma (\(String(format: "%+.2fR", recentR))) görülüyor."
            advice = "Stratejini değiştirme; normal dağılım varyansını korumalı geçmek için riski geçici olarak 0.75x seviyesinde tut."
        } else if ewma >= max(0.35, baselineR + 0.25 * stdR) && recentComp >= 80.0 {
            state = .hotEdge
            mult = 1.10
            summary = "Güçlü momentum: EWMA \(String(format: "%+.2fR", ewma)) (Baz: \(String(format: "%+.2fR", baselineR))) ve son \(recent.count) işlemde %\(Int(recentComp)) disiplin."
            advice = "Aşırı özgüven (overconfidence) tuzağına düşmeden A+ kurulumlarda standart/1.10x riskle seriyi koru."
        } else {
            state = .stable
            mult = 1.00
            summary = "Performans ve kural uyumu (%\(Int(recentComp))) uzun vadeli istatistiksel beklenti bandı (\(String(format: "%+.2fR", baselineR))) içinde dengeli."
            advice = "Standart Quarter-Kelly risk (1.00x) ve mevcut seans filtreleriyle istikrarı sürdür."
        }

        return RegimeReport(
            state: state,
            ewmaR: ewma,
            baselineR: baselineR,
            cusumDrift: cusumNeg,
            recentCompliance: recentComp,
            riskMultiplier: mult,
            summary: summary,
            advice: advice
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

            if !setup.isEmpty && !sess.isEmpty {
                add("ss:\(setup)|\(sess)", title: "\(setup) · \(sess)", subtitle: "Strateji × Seans", trade: t)
            }
            if !sym.isEmpty {
                add("id:\(sym)|\(t.direction)", title: "\(sym) \(t.direction.uppercased())", subtitle: "Parite × Yön", trade: t)
            }
            if t.qt.enabled && !t.qt.dailyQuarter.isEmpty && !sess.isEmpty {
                add("sq:\(sess)|\(t.qt.dailyQuarter)", title: "\(sess) · \(t.qt.dailyQuarter)", subtitle: "Seans × QT Çeyrek", trade: t)
            }
            if t.hasSSMT && !t.biasRelation.isEmpty {
                add("sb:ssmt|\(t.biasRelation)", title: "Valid SSMT · \(t.biasRelation)", subtitle: "Teyit × Bias", trade: t)
            }
            if t.hasQT && t.hasSSMT {
                add("qs:qt+ssmt", title: "QT Aligned + Valid SSMT", subtitle: "Model Kombinasyonu", trade: t)
            }
            if t.hasCRT && t.hasSSMT {
                add("cs:crt+ssmt", title: "Confirmed CRT + Valid SSMT", subtitle: "Model Kombinasyonu", trade: t)
            }
            if t.biasRelation == "Counter-Trend" && !t.hasSSMT {
                add("leak:ct-nossmt", title: "Counter-Trend (SSMT Yok)", subtitle: "Yüksek Riskli Kombinasyon", trade: t)
            }
            if !t.compliant {
                for rule in Set(t.brokenRules) {
                    add("rule:\(rule)", title: L10n.text(rule), subtitle: "Kural İhlali", trade: t)
                }
            }
            if t.emotional.fomo >= 6 {
                add("emo:fomo", title: "Yüksek FOMO (≥6/10)", subtitle: "Psikoloji Etkisi", trade: t)
            }
            if t.emotional.stress >= 6 {
                add("emo:stress", title: "Yüksek Stres (≥6/10)", subtitle: "Psikoloji Etkisi", trade: t)
            }
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

        edges.sort { abs($0.0 - $1.0) < 1e-9 ? $0.1.id < $1.1.id : $0.0 > $1.0 }
        leaks.sort { abs($0.0 - $1.0) < 1e-9 ? $0.1.id < $1.1.id : $0.0 > $1.0 }
        return (Array(edges.prefix(4).map(\.1)), Array(leaks.prefix(4).map(\.1)))
    }

    // MARK: - Behavioral Tilt & Revenge-Trading Anomaly Detector

    private static func detectTilt(_ ordered: [TradeRecord]) -> TiltReport {
        guard ordered.count >= 2 else { return TiltReport() }
        var signals: [TiltSignal] = []
        var tiltPoints = 0

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

    // MARK: - On-Device NLP Keyword Mining (Apple NaturalLanguage)

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

        let positive = insights.filter { $0.averageR > 0.15 && $0.netPnL > 0 }.sorted {
            let a = $0.averageR * sqrt(Double($0.count)), b = $1.averageR * sqrt(Double($1.count))
            return abs(a - b) < 1e-9 ? $0.keyword < $1.keyword : a > b
        }
        let negative = insights.filter { $0.averageR < -0.05 || $0.netPnL < 0 }.sorted {
            let a = (-$0.averageR) * sqrt(Double($0.count)), b = (-$1.averageR) * sqrt(Double($1.count))
            return abs(a - b) < 1e-9 ? $0.keyword < $1.keyword : a > b
        }
        return (Array(positive.prefix(4)), Array(negative.prefix(4)))
    }

    // MARK: - MODULE 1: One-Click AI Trade Thesis & Lesson Synthesizer (From Manual Selections)

    static func synthesizeTradeNotes(for t: TradeRecord, prediction: EdgePrediction) -> TradeNotes {
        var notes = t.notes
        let sessText = t.session.isEmpty ? "aktif seans" : L10n.text(t.session)
        let setupText = (t.setupName.isEmpty || t.setupName == "Unassigned") ? "temel fiyat aksiyonu" : t.setupName
        let biasText = t.bias.isEmpty ? "Neutral" : "\(t.bias) (\(t.biasRelation.isEmpty ? "Pro-Trend" : t.biasRelation))"
        let liqTaken = t.liquidityTaken.isEmpty ? "likidite süpürmesi" : t.liquidityTaken.joined(separator: " + ")
        let dolText = t.drawOnLiquidity.isEmpty ? "karşıt likidite havuzu (DOL)" : t.drawOnLiquidity
        let qtText = t.qt.enabled ? "QT \(t.qt.profile) \(t.qt.dailyQuarter) (\(t.qt.trueOpenAnchor) \(t.qt.trueOpenLocation))" : ""
        let confList: [String] = [
            qtText,
            t.hasSSMT ? "Valid SSMT (\(t.ssmt.type))" : "",
            t.hasCRT ? "Onaylı CRT (\(t.crt.timeframe))" : "",
            t.hasMMXM ? t.mmxm.model : "",
            t.confirmations.joined(separator: " + ")
        ].filter { !$0.isEmpty }
        let confSummary = confList.isEmpty ? "fiyat yapısı teyidi" : confList.joined(separator: " · ")
        let tfText = t.entryTimeframe.isEmpty ? "LTF" : t.entryTimeframe

        if !t.narrative.isEmpty {
            notes.thesis = "\(t.instrument) \(t.direction) (\(sessText)): \(t.narrative). HTF Bias \(biasText) çerçevesinde \(liqTaken) sonrasında \(dolText) hedeflendi. [\(setupText) · ML Edge \(prediction.edgeScore)/100]"
        } else {
            notes.thesis = "\(t.instrument) paritesinde \(sessText) seansında HTF \(biasText) yönünde \(liqTaken) tamamlandıktan sonra '\(setupText)' kurulumu ile \(dolText) likidite hedefine \(t.direction) pozisyon alındı."
        }

        notes.entry = "\(tfText) zaman diliminde \(liqTaken) sonrası \(confSummary) tetikleyicisiyle giriş yapıldı."
        notes.confirmation = confSummary
        notes.invalidation = t.stopLoss.map { "Manipülasyon ekstremumu (\(String(format: "%.2f", $0))) ötesinde kapanış ve yapı bozulması." } ?? "Manipülasyon ekstremumu ötesinde mum kapanışı ve ters CISD oluşumu."

        if t.compliant {
            notes.correct = "Plana %100 sadık kalındı, \(confSummary) teyidi beklendi ve risk kurallarına uyuldu."
            notes.incorrect = t.emotional.fomo >= 6 ? "FOMO seviyesi (\(Int(t.emotional.fomo))/10) ortalamanın üzerindeydi; giriş öncesi nefes kontrolü yapılmalı." : "Belirgin bir uygulama veya disiplin hatası yapılmadı."
            if t.netPnL >= 0.005 {
                notes.lesson = "Sabırla \(setupText) ve \(confSummary) birleşimini beklemek pozitif beklenti (\(t.rMultiple.map { String(format: "%+.2fR", $0) } ?? "Kazanç")) üretti. Bu standart korunmalı."
            } else {
                notes.lesson = "Kurallara tam uyulan geçerli kurulumda normal olasılık dağılımı kaybı yaşandı; süreç doğru olduğu için kural değiştirilmemeli."
            }
        } else {
            let broken = t.brokenRules.map(L10n.text).joined(separator: ", ")
            notes.correct = "İşlem kaydı ve ihlal edilen kurallar şeffaf biçimde günlüğe işlendi."
            notes.incorrect = "İhlal edilen kurallar: \(broken.isEmpty ? "Plan dışı giriş" : broken)."
            notes.differently = "Bir sonraki işlemde '\(broken.isEmpty ? "Giriş teyidi" : broken)' kontrol maddesi tamamlanmadan emir gönderilmeyecek."
            notes.lesson = "Disiplin ihlali (\(broken)) istatistiksel edge'i bozuyor. Sonuçtan bağımsız olarak yalnızca Playbook kriterleri %100 sağlandığında işleme girilmeli."
        }
        return notes
    }

    // MARK: - MODULE 2: Post-Trade AI Autopsy, Counterfactuals & Vectorized Cosine k-NN Engine (vDSP)

    struct SimilarTradeMatch: Identifiable, Equatable {
        let id: UUID
        let trade: TradeRecord
        let similarityPercent: Int
        let matchedFeatures: [String]
    }

    enum AutopsyTone: String, Equatable {
        case optimal = "KUSURSUZ UYGULAMA"
        case warning = "SÜREÇ UYARISI"
        case leak = "KRİTİK SIZINTI"
        case neutral = "STANDART İŞLEM"
    }

    struct TradeAutopsy: Equatable {
        var tone: AutopsyTone
        var verdictTitle: String
        var executionGrade: String
        var edgeAlignmentPercent: Int
        var preTradeEdgeScore: Int
        var preTradeWinProb: Double
        var preTradeExpectedR: Double
        var diagnosis: String
        var strengths: [String]
        var weaknesses: [String]
        var counterfactuals: [String]
        var prescription: String
        var similarTrades: [SimilarTradeMatch]
        var similarCohortWinRate: Double
        var similarCohortAvgR: Double
    }

    static func similarTrades(to target: TradeRecord, in history: [TradeRecord], limit: Int = 5) -> [SimilarTradeMatch] {
        let candidates = history.filter { $0.id != target.id }
        guard !candidates.isEmpty else { return [] }

        // Build target reference vector for vDSP Cosine Similarity + semantic feature overlap
        let targetConf = Set(target.confirmations)
        let targetHour = Double(Calendar.current.component(.hour, from: target.date))
        let tSin = sin(2.0 * .pi * targetHour / 24.0)
        let tCos = cos(2.0 * .pi * targetHour / 24.0)

        var scored: [SimilarTradeMatch] = []
        scored.reserveCapacity(candidates.count)

        for other in candidates {
            var tags: [String] = []

            let sameInst: Double = (!target.instrument.isEmpty && target.instrument.caseInsensitiveCompare(other.instrument) == .orderedSame) ? 1.0 : 0.0
            if sameInst > 0.5 { tags.append(target.instrument) }

            let sameSetup: Double = (target.setupName != "Unassigned" && !target.setupName.isEmpty && target.setupName == other.setupName) ? 1.0 : (target.setupName == other.setupName ? 0.45 : 0.0)
            if sameSetup >= 0.9 { tags.append(target.setupName) }

            let sameSess: Double = (!target.session.isEmpty && target.session == other.session) ? 1.0 : 0.0
            if sameSess > 0.5 { tags.append(L10n.text(target.session)) }

            let sameDir: Double = (target.direction == other.direction) ? 1.0 : 0.0
            if sameDir > 0.5 { tags.append(target.direction) }

            let sameBias: Double = (!target.biasRelation.isEmpty && target.biasRelation == other.biasRelation) ? 1.0 : 0.0
            if sameBias > 0.5 { tags.append(target.biasRelation) }

            let qtMatch: Double
            if target.qt.enabled && other.qt.enabled {
                let qBonus = (!target.qt.dailyQuarter.isEmpty && target.qt.dailyQuarter == other.qt.dailyQuarter) ? 0.55 : 0.0
                let pBonus = (!target.qt.profile.isEmpty && target.qt.profile == other.qt.profile) ? 0.25 : 0.0
                qtMatch = 0.20 + qBonus + pBonus
                if qBonus > 0 { tags.append("QT \(target.qt.dailyQuarter)") }
            } else if !target.qt.enabled && !other.qt.enabled {
                qtMatch = 0.55
            } else {
                qtMatch = 0.0
            }

            let ssmtMatch: Double = (target.hasSSMT == other.hasSSMT) ? 1.0 : 0.0
            if target.hasSSMT && other.hasSSMT { tags.append("SSMT") }

            let crtMatch: Double = (target.hasCRT == other.hasCRT) ? 1.0 : 0.0
            if target.hasCRT && other.hasCRT { tags.append("CRT") }

            let otherConf = Set(other.confirmations)
            let confOverlap: Double
            if !targetConf.isEmpty || !otherConf.isEmpty {
                confOverlap = Double(targetConf.intersection(otherConf).count) / Double(max(1, targetConf.union(otherConf).count))
            } else {
                confOverlap = 0.5
            }

            let oHour = Double(Calendar.current.component(.hour, from: other.date))
            let hourSim = max(0.0, (tSin * sin(2.0 * .pi * oHour / 24.0) + tCos * cos(2.0 * .pi * oHour / 24.0) + 1.0) * 0.5)
            let emoProx = max(0.0, 1.0 - (abs(target.emotional.fomo - other.emotional.fomo) + abs(target.emotional.stress - other.emotional.stress)) / 18.0)
            let compMatch: Double = (target.compliant == other.compliant) ? 1.0 : 0.0

            // Weighted feature vectors evaluated with Accelerate vDSP_dotprD
            let weights: [Double] = [2.4, 2.2, 1.5, 1.0, 0.9, 1.1, 0.8, 0.6, 0.8, 0.4, 0.4, 0.6]
            let matchVec: [Double] = [sameInst, sameSetup, sameSess, sameDir, sameBias, qtMatch, ssmtMatch, crtMatch, confOverlap, hourSim, emoProx, compMatch]
            var dot = 0.0
            var wSum = 0.0
            vDSP_dotprD(weights, 1, matchVec, 1, &dot, vDSP_Length(weights.count))
            vDSP_sveD(weights, 1, &wSum, vDSP_Length(weights.count))

            let pct = max(5, min(99, Int((dot / max(1e-6, wSum) * 100.0).rounded())))
            if pct >= 38 {
                scored.append(SimilarTradeMatch(
                    id: other.id,
                    trade: other,
                    similarityPercent: pct,
                    matchedFeatures: Array(tags.prefix(4))
                ))
            }
        }

        scored.sort { a, b in
            if a.similarityPercent != b.similarityPercent { return a.similarityPercent > b.similarityPercent }
            return a.trade.date > b.trade.date
        }
        return Array(scored.prefix(limit))
    }

    static func autopsy(for trade: TradeRecord, history: [TradeRecord], calendar: Calendar) -> TradeAutopsy {
        let prediction = predict(candidate: trade, history: history, calendar: calendar)
        let matches = similarTrades(to: trade, in: history, limit: 5)
        let matchTrades = matches.map(\.trade)
        let matchPerf = AnalyticsEngine.performance(matchTrades)
        let others = history.filter { $0.id != trade.id }

        var strengths: [String] = []
        var weaknesses: [String] = []
        var counterfactuals: [String] = []

        if trade.compliant {
            strengths.append("İşlem planına %100 uyum sağlandı (kural ihlali yok).")
        } else {
            let broken = trade.brokenRules.map(L10n.text).joined(separator: ", ")
            weaknesses.append("Kural ihlali yapıldı: \(broken.isEmpty ? "Plan dışı işlem" : broken).")
            let compliantSameSetup = others.filter { $0.compliant && ($0.setupName == trade.setupName || $0.instrument == trade.instrument) }
            if !compliantSameSetup.isEmpty {
                let compPerf = AnalyticsEngine.performance(compliantSameSetup)
                counterfactuals.append("Eğer Kural İhlali Olmasaydı: Aynı parite/kurulumda kurallı işlemlerinin ortalama sonucu \(String(format: "%+.2fR", compPerf.averageR ?? 0)) (WR %\(String(format: "%.0f", compPerf.winRate)), n=\(compPerf.count)).")
            }
        }

        if trade.biasRelation == "Pro-Trend" && trade.htfAligned {
            strengths.append("HTF Bias ile aynı yönde (Pro-Trend) likidite akışına girildi.")
        } else if trade.biasRelation == "Counter-Trend" {
            if !trade.hasSSMT {
                weaknesses.append("Counter-Trend girişte SSMT onayı bulunmuyor.")
            }
            let proTrendCohort = others.filter { $0.instrument == trade.instrument && $0.biasRelation == "Pro-Trend" }
            if proTrendCohort.count >= 2 {
                let ptPerf = AnalyticsEngine.performance(proTrendCohort)
                counterfactuals.append("Eğer Pro-Trend Girilseydi: \(trade.instrument) paritesinde Pro-Trend işlemlerin %\(String(format: "%.0f", ptPerf.winRate)) kazanma oranı ve \(String(format: "%+.2fR", ptPerf.averageR ?? 0)) ortalama üretiyor.")
            }
        }

        if !trade.hasSSMT {
            let ssmtCohort = others.filter { $0.hasSSMT && ($0.setupName == trade.setupName || $0.instrument == trade.instrument) }
            if ssmtCohort.count >= 2 {
                let sPerf = AnalyticsEngine.performance(ssmtCohort)
                counterfactuals.append("Eğer SSMT Onayı Beklenseydi: SSMT teyitli benzer işlemlerinde ortalama beklenti \(String(format: "%+.2fR", sPerf.averageR ?? 0)) (WR %\(String(format: "%.0f", sPerf.winRate))).")
            }
        }

        if trade.hasQT {
            strengths.append("Quarterly Theory (\(trade.qt.profile) \(trade.qt.dailyQuarter)) zamanlaması doğrulandı.")
        }
        if trade.hasSSMT {
            strengths.append("Geçerli SSMT korelasyon uyumsuzluğu teyit edildi.")
        }
        if trade.hasCRT {
            strengths.append("Candle Range Theory (CRT) aralığı ve yeniden girişi onaylandı.")
        }
        if trade.emotional.fomo >= 6 {
            weaknesses.append("Yüksek FOMO (\(Int(trade.emotional.fomo))/10) altında giriş yapıldı.")
            let calmCohort = others.filter { $0.emotional.fomo <= 4 }
            if calmCohort.count >= 3 {
                let cPerf = AnalyticsEngine.performance(calmCohort)
                counterfactuals.append("Düşük FOMO Karşılaştırması: FOMO ≤ 4 olduğu sakin işlemlerinde ortalama beklenti \(String(format: "%+.2fR", cPerf.averageR ?? 0)) (WR %\(String(format: "%.0f", cPerf.winRate))).")
            }
        }
        if trade.emotional.stress >= 6 {
            weaknesses.append("Yüksek stres (\(Int(trade.emotional.stress))/10) altında karar verildi.")
        }

        let ordered = AnalyticsEngine.ordered(history)
        if let idx = ordered.firstIndex(where: { $0.id == trade.id }), idx > 0 {
            let prev = ordered[idx - 1]
            if prev.netPnL <= -0.005 {
                let prevExit = prev.exitDate ?? prev.date
                let gap = trade.date.timeIntervalSince(prevExit)
                if gap >= 0 && gap <= 900 {
                    weaknesses.append("Önceki zarardan yalnızca \(Int(max(1, gap / 60))) dk sonra hızlı tekrar giriş (revenge riski) yapıldı.")
                }
                if let pRisk = prev.riskDollars, let cRisk = trade.riskDollars, pRisk > 0, cRisk >= pRisk * 1.25 {
                    weaknesses.append("Kayıp sonrasında risk tutarı %\(Int(((cRisk / pRisk) - 1) * 100)) artırıldı.")
                }
            }
        }

        for factor in prediction.factors {
            if factor.rImpact >= 0.20 && strengths.count < 4 {
                strengths.append("\(factor.label) geçmişte ortalamaya +\(String(format: "%.2f", factor.rImpact))R katkı sağlıyor.")
            } else if factor.rImpact <= -0.20 && weaknesses.count < 4 {
                weaknesses.append("\(factor.label) geçmişte ortalamayı \(String(format: "%.2f", factor.rImpact))R aşağı çekiyor.")
            }
        }

        if let booster = prediction.whatIfBooster, counterfactuals.count < 3 {
            counterfactuals.append(booster)
        }

        var alignScore = Double(prediction.edgeScore) * 0.55 + (trade.compliant ? 28.0 : -15.0) + (trade.scores.overall * 0.20)
        if trade.emotional.fomo >= 7 { alignScore -= 10 }
        let edgeAlignmentPercent = max(10, min(99, Int(alignScore.rounded())))
        let executionGrade: String = edgeAlignmentPercent >= 82 ? "S+" : edgeAlignmentPercent >= 70 ? "A" : edgeAlignmentPercent >= 56 ? "B" : edgeAlignmentPercent >= 42 ? "C" : "D"

        let isWin = trade.netPnL >= 0.005
        let isLoss = trade.netPnL <= -0.005
        let tone: AutopsyTone
        let verdictTitle: String
        let prescription: String

        if isWin && trade.compliant && prediction.edgeScore >= 55 {
            tone = .optimal
            verdictTitle = "Yüksek Edge & Disiplinli Kazanç"
            prescription = "Bu kurulum ve uygulama standardını koru; en yüksek beklentili kombinasyonlarından biri."
        } else if isWin && (!trade.compliant || prediction.edgeScore < 42) {
            tone = .warning
            verdictTitle = "Sonuç Pozitif Ancak Süreç Riski Var"
            prescription = "İşlem kârla kapansa da kural ihlali veya düşük istatistiksel edge içeriyor; bu davranışı ödüllendirme."
        } else if isLoss && trade.compliant && prediction.edgeScore >= 55 {
            tone = .neutral
            verdictTitle = "Geçerli Kurulumda Normal Dağılım Kaybı"
            prescription = "Kurallara tam uydun ve kurulumun pozitif beklentili (Edge \(prediction.edgeScore)/100). Hiçbir kuralı değiştirme."
        } else {
            tone = .leak
            verdictTitle = "Önlenebilir Süreç / Kurulum Sızıntısı"
            prescription = weaknesses.first ?? "Giriş öncesi kontrol listesini ve seans/model filtresini zorunlu uygula."
        }

        let rText = trade.rMultiple.map { String(format: "%+.2fR", $0) } ?? String(format: "%+.0f", trade.netPnL)
        let simText = matches.isEmpty ? "" : " Geçmişteki en benzer \(matches.count) işlemde kazanma oranı %\(String(format: "%.0f", matchPerf.winRate)) ve ortalama sonuç \(String(format: "%+.2fR", matchPerf.averageR ?? 0))."
        let diagnosis = "\(trade.instrument) \(trade.direction) işlemi \(rText) ile tamamlandı (Uygulama Notu: \(executionGrade) · Edge Uyumu: %\(edgeAlignmentPercent)). İşlem öncesi \(prediction.modelUsed) Edge Skoru \(prediction.edgeScore)/100 (Beklenen \(String(format: "%+.2fR", prediction.expectedR)), WR %\(String(format: "%.0f", prediction.winProbability))).\(simText)"

        return TradeAutopsy(
            tone: tone,
            verdictTitle: verdictTitle,
            executionGrade: executionGrade,
            edgeAlignmentPercent: edgeAlignmentPercent,
            preTradeEdgeScore: prediction.edgeScore,
            preTradeWinProb: prediction.winProbability,
            preTradeExpectedR: prediction.expectedR,
            diagnosis: diagnosis,
            strengths: strengths,
            weaknesses: weaknesses,
            counterfactuals: counterfactuals,
            prescription: prescription,
            similarTrades: matches,
            similarCohortWinRate: matchPerf.winRate,
            similarCohortAvgR: matchPerf.averageR ?? 0
        )
    }

    // MARK: - MODULE 3: One-Click AI Draft Generators (ReviewEditor & PlanningView)

    static func generateReviewDraft(existing: ReviewDraft, trades: [TradeRecord], calendar: Calendar) -> ReviewDraft {
        var draft = existing
        let interval = calendar.dateInterval(
            of: draft.period == "Daily" ? .day : draft.period == "Monthly" ? .month : .weekOfYear,
            for: draft.date
        ) ?? DateInterval(start: draft.date.addingTimeInterval(-7 * 86400), duration: 7 * 86400)

        let periodTrades = trades.filter { $0.date >= interval.start && $0.date < interval.end }
        let sample = periodTrades.isEmpty ? trades : periodTrades
        guard !sample.isEmpty else {
            draft.worked = "Henüz bu dönemde analiz edilecek işlem kaydı bulunmuyor."
            draft.didNot = "İşlem girdikçe AI değerlendirme motoru otomatik istatistiksel sentez üretecektir."
            draft.repeatNext = "Her işlemi ekran görüntüsü ve R değeriyle kaydet."
            draft.stop = "Plansız işlem açmaktan kaçın."
            draft.adjustment = "Her işlem öncesi Playbook kontrol listesini uygula."
            return draft
        }

        let perf = AnalyticsEngine.performance(sample)
        let ml = analyze(sample, calendar: calendar)
        let setupGroups = AnalyticsEngine.groups(sample, by: .setup, calendar: calendar)
            .sorted { ($0.performance.averageR ?? $0.performance.netPnL) > ($1.performance.averageR ?? $1.performance.netPnL) }
        let sessionGroups = AnalyticsEngine.groups(sample, by: .session, calendar: calendar)
            .sorted { ($0.performance.averageR ?? $0.performance.netPnL) > ($1.performance.averageR ?? $1.performance.netPnL) }
        let mistakes = AnalyticsEngine.mistakes(sample)

        var workedLines: [String] = []
        if let bestSetup = setupGroups.first, bestSetup.performance.netPnL > 0 {
            workedLines.append("• En güçlü model '\(bestSetup.name)' oldu (n=\(bestSetup.performance.count), WR %\(String(format: "%.0f", bestSetup.performance.winRate)), Ort. \(String(format: "%+.2fR", bestSetup.performance.averageR ?? 0))).")
        }
        if let bestSession = sessionGroups.first, bestSession.performance.netPnL > 0 {
            workedLines.append("• '\(L10n.text(bestSession.name))' seansı en yüksek verimi üretti (WR %\(String(format: "%.0f", bestSession.performance.winRate))).")
        }
        if let golden = ml.goldenSetups.first {
            workedLines.append("• ML Altın Kombinasyon: \(golden.title) (\(String(format: "%+.2fR", golden.averageR)) ort., n=\(golden.sampleCount)).")
        }
        let compliantTrades = sample.filter(\.compliant)
        if !compliantTrades.isEmpty {
            let compPerf = AnalyticsEngine.performance(compliantTrades)
            workedLines.append("• Plana tam uyulan \(compliantTrades.count) işlemde kazanma oranı %\(String(format: "%.0f", compPerf.winRate)) ve ortalama \(String(format: "%+.2fR", compPerf.averageR ?? 0)) gerçekleşti.")
        }
        draft.worked = workedLines.isEmpty ? "Genel kural uyumu %\(String(format: "%.0f", perf.compliance)) seviyesinde korundu." : workedLines.joined(separator: "\n")

        var didNotLines: [String] = []
        if let leak = ml.moneyLeaks.first {
            didNotLines.append("• ML Para Sızıntısı: \(leak.title) (n=\(leak.sampleCount), Ort. \(String(format: "%+.2fR", leak.averageR)), Net \(String(format: "%+.0f", leak.netPnL))).")
        }
        if let worstSetup = setupGroups.last, worstSetup.performance.netPnL < 0 {
            didNotLines.append("• '\(worstSetup.name)' kurulumu negatif beklenti üretti (WR %\(String(format: "%.0f", worstSetup.performance.winRate)), Ort. \(String(format: "%+.2fR", worstSetup.performance.averageR ?? 0))).")
        }
        if let topMistake = mistakes.first {
            didNotLines.append("• En sık tekrarlanan hata: '\(L10n.text(topMistake.name))' (\(topMistake.performance.count) işlemde toplam \(String(format: "%+.0f", topMistake.performance.netPnL)) etki).")
        }
        if ml.filterSimulation.savedCapital > 10 && ml.filterSimulation.skippedTrades > 0 {
            didNotLines.append("• AI Filtre Analizi: Düşük kaliteli / kuralsız \(ml.filterSimulation.skippedTrades) işlem elenseydi +\(String(format: "%.0f", ml.filterSimulation.savedCapital)) ekstra sermaye korunurdu.")
        }
        draft.didNot = didNotLines.isEmpty ? "Belirgin bir sistemik sızıntı görülmedi; kayıplar standart kurulum dağılımı içinde kaldı." : didNotLines.joined(separator: "\n")

        var repeatLines: [String] = []
        if let golden = ml.goldenSetups.first {
            repeatLines.append("• \(golden.title) kombinasyonuna A+ odaklanmayı sürdür.")
        } else if let bestSetup = setupGroups.first {
            repeatLines.append("• '\(bestSetup.name)' modelinde yalnızca tüm teyitler (CISD/SSMT/QT) oluştuğunda pozisyon al.")
        }
        if let posKw = ml.positiveKeywords.first {
            repeatLines.append("• Notlarda “\(posKw.keyword)” disipliniyle işaretlenen kurulum kalitesini koru.")
        }
        repeatLines.append("• İşlem öncesi risk ve likidite hedefini (DOL) grafik üzerinde net tanımla.")
        draft.repeatNext = repeatLines.joined(separator: "\n")

        var stopLines: [String] = []
        if let topMistake = mistakes.first {
            stopLines.append("• '\(L10n.text(topMistake.name))' kural ihlalini tamamen sıfırla.")
        }
        if let leak = ml.moneyLeaks.first {
            stopLines.append("• \(leak.title) koşulunda işlem açmayı durdur veya riski yarıya indir.")
        }
        if ml.tilt.rapidReentryCount > 0 {
            stopLines.append("• Zararlı kapanıştan sonra en az 15 dakika zorunlu bekleme süresi (cooldown) olmadan yeni işlem açma.")
        }
        if stopLines.isEmpty {
            stopLines.append("• Düşük hacimli saatlerde ve haber anlarında zorlama kurulum aramayı bırak.")
        }
        draft.stop = stopLines.joined(separator: "\n")

        if let topMistake = mistakes.first {
            draft.adjustment = "Tek Odak: '\(L10n.text(topMistake.name))' ihlalini önlemek için giriş öncesi kontrol listesini %100 tamamlamadan emir gönderme (Aktif Rejim: \(ml.regime.state.rawValue))."
        } else if let golden = ml.goldenSetups.first {
            draft.adjustment = "Tek Odak: Sermaye ve dikkati '\(golden.title)' kurulumuna yoğunlaştır; C-grade işlemleri ele (Risk Çarpanı: \(String(format: "%.2fx", ml.regime.riskMultiplier)))."
        } else {
            draft.adjustment = "Tek Odak: Günlük maksimum 2 A+ işlem ve sabit %0.50–%1.00 risk disipliniyle uygulama kalitesini 85+/100 üzerinde tut."
        }
        return draft
    }

    struct AIDailyPlanBriefing {
        var plan: DailyPlan
        var recommendedRiskPercent: Double
        var recommendedRiskDollars: Double
        var quarterKellyPercent: Double
        var tiltLevel: TiltLevel
        var tiltScore: Int
        var regimeState: RegimeState
        var regimeRiskMultiplier: Double
        var bestSessionLabel: String
        var primarySetupLabel: String
        var weekdayEdgeSummary: String
        var rationale: String
    }

    static func generateDailyPlanBriefing(
        for date: Date,
        account: TradingAccount,
        trades: [TradeRecord],
        setups: [Setup],
        risk: RiskSnapshot,
        calendar: Calendar
    ) -> AIDailyPlanBriefing {
        let perf = AnalyticsEngine.performance(trades)
        let ordered = AnalyticsEngine.ordered(trades)
        let ml = analyze(ordered, calendar: calendar)

        // Regime & Tilt-Adjusted Fractional (Quarter) Kelly Criterion
        let p = max(0.30, min(0.75, (perf.count >= 5 ? perf.winRate / 100.0 : 0.52)))
        let b = max(0.8, min(4.0, perf.payoffRatio ?? 1.6))
        let fullKelly = max(0.005, p - ((1.0 - p) / b)) * 100.0
        let quarterKelly = (fullKelly * 0.25 * 100).rounded() / 100

        var recPct = min(1.35, max(0.25, quarterKelly)) * ml.regime.riskMultiplier
        if ml.tilt.level == .elevated {
            recPct *= 0.65
        } else if ml.tilt.level == .caution {
            recPct *= 0.85
        }
        if let maxLoss = account.rules.maximumLoss, maxLoss > 0, let rem = risk.remaining, rem < maxLoss * 0.4 {
            recPct = min(recPct, 0.35)
        }
        recPct = max(0.20, min(1.50, (recPct * 20).rounded() / 20.0))
        let baseBalance = max(1000, risk.balance > 0 ? risk.balance : account.startingBalance)
        var recDollars = (baseBalance * recPct / 100.0).rounded()
        if let ruleCap = account.rules.riskPerTrade, ruleCap > 0 {
            recDollars = min(recDollars, ruleCap)
            recPct = ((recDollars / baseBalance) * 100.0 * 100).rounded() / 100
        }

        let sessionGroups = AnalyticsEngine.groups(trades, by: .session, calendar: calendar)
            .filter { $0.name != "Unspecified" }
            .sorted { ($0.performance.averageR ?? 0) > ($1.performance.averageR ?? 0) }
        let bestSess = sessionGroups.first.map { L10n.text($0.name) } ?? "New York AM"

        let setupGroups = AnalyticsEngine.groups(trades, by: .setup, calendar: calendar)
            .filter { $0.name != "Unassigned" }
            .sorted { ($0.performance.averageR ?? 0) > ($1.performance.averageR ?? 0) }
        let bestSetup = setupGroups.first?.name ?? setups.first?.name ?? "QT + SSMT + CISD"

        let instGroups = AnalyticsEngine.groups(trades, by: .instrument, calendar: calendar)
            .sorted { ($0.performance.averageR ?? 0) > ($1.performance.averageR ?? 0) }
        let topInstruments = instGroups.prefix(2).map(\.name)
        let instText = topInstruments.isEmpty ? "NQ, ES" : topInstruments.joined(separator: ", ")

        let weekdayIdx = calendar.component(.weekday, from: date)
        let weekdayName = calendar.weekdaySymbols[max(0, min(calendar.weekdaySymbols.count - 1, weekdayIdx - 1))]
        let sameWeekdayTrades = trades.filter { calendar.component(.weekday, from: $0.date) == weekdayIdx }
        let weekdaySummary: String
        if !sameWeekdayTrades.isEmpty {
            let wPerf = AnalyticsEngine.performance(sameWeekdayTrades)
            weekdaySummary = "\(L10n.text(weekdayName)): n=\(wPerf.count) · WR %\(String(format: "%.0f", wPerf.winRate)) · \(String(format: "%+.2fR", wPerf.averageR ?? 0))"
        } else {
            weekdaySummary = "\(L10n.text(weekdayName)): Standart Risk"
        }

        var plan = DailyPlan(accountID: account.id, date: date)
        plan.instruments = "\(instText) · \(bestSess) Seansı (\(weekdaySummary))"
        plan.scenarios = "• Ana Senaryo (Pro-Trend): True Open (TDO / T90O) konumuna göre Q2 manipülasyonu (BSL/SSL Sweep) sonrasında Q3 dağıtım fazında yön teyidi bekle.\n• Rejim Notu (\(ml.regime.state.rawValue)): \(ml.regime.advice)"
        plan.liquidity = "• Dış Likidite (ERL): PDH / PDL ve Asya-Londra seans zirve/dip seviyeleri.\n• İç Likidite (IRL): HTF Fair Value Gap (FVG) ve 15M CRT sınırları."
        if let golden = ml.goldenSetups.first {
            plan.focus = "• Birincil Model: \(bestSetup)\n• ML Altın Kombinasyon Odağı: \(golden.title) (Tarihsel WR %\(String(format: "%.0f", golden.winRate)), Ort. \(String(format: "%+.2fR", golden.averageR))).\n• Giriş Teyidi: Likidite süpürmesi + SSMT / CISD + FVG yeniden testi."
        } else {
            plan.focus = "• Birincil Model: \(bestSetup)\n• Yalnızca A / A+ kalite, HTF hizalı ve temiz teyitli (CISD + FVG) kurulumları uygula."
        }

        let dailyCapText = account.rules.dailyLoss.map { String(format: "%.0f %@", $0, account.currency) } ?? String(format: "%.0f %@ (2R)", recDollars * 2, account.currency)
        plan.limits = "• Önerilen İşlem Başına Risk (AI Quarter-Kelly × \(String(format: "%.2fx", ml.regime.riskMultiplier)) Rejim): %\(String(format: "%.2f", recPct)) (\(String(format: "%.0f %@", recDollars, account.currency)))\n• Günlük Maksimum Kayıp Limiti: \(dailyCapText)\n• Stop Kuralı: Art arda 2 kayıp veya ilk kural ihlalinde ekranı kapat."

        let leakWarning = ml.moneyLeaks.first.map { "'\($0.title)' sızıntısından uzak dur." } ?? "Zarar sonrası 15 dk soğuma kuralına uy."
        plan.objectives = "En fazla 2 A+ işlem · \(leakWarning) · Rejim: \(ml.regime.state.rawValue) · Tilt: \(ml.tilt.score)/100"

        let rationale = "Quarter-Kelly (%\(String(format: "%.2f", quarterKelly))) × Rejim Çarpanı (\(String(format: "%.2fx", ml.regime.riskMultiplier))) ile işlem başına %\(String(format: "%.2f", recPct)) (\(String(format: "%.0f %@", recDollars, account.currency))) risk önerildi."

        return AIDailyPlanBriefing(
            plan: plan,
            recommendedRiskPercent: recPct,
            recommendedRiskDollars: recDollars,
            quarterKellyPercent: quarterKelly,
            tiltLevel: ml.tilt.level,
            tiltScore: ml.tilt.score,
            regimeState: ml.regime.state,
            regimeRiskMultiplier: ml.regime.riskMultiplier,
            bestSessionLabel: bestSess,
            primarySetupLabel: bestSetup,
            weekdayEdgeSummary: weekdaySummary,
            rationale: rationale
        )
    }

    // MARK: - MODULE 4: Entity-Aware Multi-Intent AI Trading Coach ("AI Koç — Günlüğüne Sor")

    struct AICoachMetric: Identifiable, Equatable {
        let id = UUID()
        let label: String
        let value: String
    }

    struct AICoachResponse: Identifiable, Equatable {
        let id = UUID()
        var question: String
        var headline: String
        var answer: String
        var metrics: [AICoachMetric]
        var actionItems: [String]
    }

    static let suggestedCoachQuestions: [String] = [
        "AI filtresi kullansaydım ne kadar para kurtarırdım?",
        "AI modelinin doğruluk oranı (AUC) ve rejim durumu ne?",
        "En çok neden ve hangi hatalardan para kaybediyorum?",
        "En kârlı strateji, seans ve parite kombinasyonum hangisi?",
        "QT Çeyrek (Q1-Q4) ve SSMT onaylı işlemlerimin performansı nasıl?",
        "Bugün ne kadar risk almalıyım ve psikolojik tilt durumum ne?",
        "Hangi seans ve saat dilimlerinde işlem açmayı bırakmalıyım?",
        "Parite bazlı performans karşılaştırmam nasıl?"
    ]

    static func askCoach(
        question: String,
        trades: [TradeRecord],
        setups: [Setup],
        account: TradingAccount,
        risk: RiskSnapshot,
        calendar: Calendar
    ) -> AICoachResponse {
        let cleanQ = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let q = cleanQ.lowercased()
        let perf = AnalyticsEngine.performance(trades)
        let ml = analyze(trades, calendar: calendar)
        let briefing = generateDailyPlanBriefing(for: Date(), account: account, trades: trades, setups: setups, risk: risk, calendar: calendar)

        guard !trades.isEmpty else {
            return AICoachResponse(
                question: cleanQ,
                headline: "Günlüğünde henüz analiz edilecek işlem kaydı yok",
                answer: "En az 3–5 işlem kaydettiğinde AI Koç; stratejilerini, seanslarını, QT/SSMT teyitlerini, Walk-Forward AUC doğruluğunu ve psikolojik kalıplarını gerçek verilerin üzerinden analiz etmeye başlayacak.",
                metrics: [AICoachMetric(label: "KAYITLI İŞLEM", value: "0")],
                actionItems: ["İlk işlemini kaydet veya Ayarlar'dan Örnek Çalışma Alanı'nı incele."]
            )
        }

        let setupGroups = AnalyticsEngine.groups(trades, by: .setup, calendar: calendar)
            .sorted { ($0.performance.averageR ?? $0.performance.netPnL) > ($1.performance.averageR ?? $1.performance.netPnL) }
        let sessionGroups = AnalyticsEngine.groups(trades, by: .session, calendar: calendar)
            .sorted { ($0.performance.averageR ?? $0.performance.netPnL) > ($1.performance.averageR ?? $1.performance.netPnL) }
        let instGroups = AnalyticsEngine.groups(trades, by: .instrument, calendar: calendar)
            .sorted { ($0.performance.averageR ?? $0.performance.netPnL) > ($1.performance.averageR ?? $1.performance.netPnL) }
        let mistakes = AnalyticsEngine.mistakes(trades)

        // Intent 1: Counterfactual AI Filter Simulation ("filtre", "kurtar", "kullansaydım", "atla", "simülasyon", "what-if")
        if q.contains("filtre") || q.contains("kurtar") || q.contains("kullansaydım") || q.contains("simülasyon") || q.contains("what-if") || q.contains("what if") {
            let fs = ml.filterSimulation
            return AICoachResponse(
                question: cleanQ,
                headline: "AI Filtre Karşı-Olgusal Simülasyon Raporu",
                answer: "• **Sermaye Etkisi:** Gerçek Net P&L **\(String(format: "%+.0f %@", fs.actualNetPnL, account.currency))** iken, AI'ın uyardığı **\(fs.skippedTrades)** düşük kaliteli / kuralsız işlem elenseydi Net P&L **\(String(format: "%+.0f %@", fs.filteredNetPnL, account.currency))** (**\(String(format: "%+.0f %@", fs.savedCapital, account.currency))** fark) olurdu.\n• **Kazanma Oranı & R:** WR **%\(String(format: "%.0f", fs.actualWinRate))** → **%\(String(format: "%.0f", fs.filteredWinRate))** · Ortalama R **\(String(format: "%+.2fR", fs.actualAvgR))** → **\(String(format: "%+.2fR", fs.filteredAvgR))**.\n• **Drawdown Koruması:** Maks. Drawdown **\(String(format: "%.0f %@", fs.actualMaxDrawdown, account.currency))** → **\(String(format: "%.0f %@", fs.filteredMaxDrawdown, account.currency))** (**%\(String(format: "%.0f", fs.drawdownReductionPercent))** azalma).",
                metrics: [
                    AICoachMetric(label: "KURTARILAN SERMAYE", value: String(format: "%+.0f %@", fs.savedCapital, account.currency)),
                    AICoachMetric(label: "FİLTRELİ WR", value: String(format: "%%%.0f", fs.filteredWinRate)),
                    AICoachMetric(label: "DD AZALMASI", value: String(format: "-%%%.0f", fs.drawdownReductionPercent))
                ],
                actionItems: [
                    "İşlem formunda canlı AI Edge Skoru < 42 uyarısı gördüğünde girişi pas geç.",
                    "Kural ihlali veya zarar sonrası <15 dk hızlı girişleri kesin olarak yasakla.",
                    "Yalnızca AI Edge ≥ 60 ve tam kurallı A+ işlemlerde standart risk kullan."
                ]
            )
        }

        // Intent 2: Model Validation / ROC-AUC / Brier / Regime / Drift
        if q.contains("auc") || q.contains("doğruluk") || q.contains("brier") || q.contains("rejim") || q.contains("drift") || q.contains("backtest") || q.contains("modelin") || q.contains("güvenilir") {
            let v = ml.validation
            let r = ml.regime
            return AICoachResponse(
                question: cleanQ,
                headline: "AI Model Doğrulaması (Walk-Forward) & Aktif Rejim",
                answer: "• **Out-of-Sample Model Ayrıştırma (ROC-AUC):** **\(String(format: "%.2f", v.rocAUC))** (\(v.qualityLabel), n=\(v.evaluatedCount) kronolojik test).\n• **Yüksek vs. Düşük Edge Ayrımı:** AI'ın **≥60** puan verdiği işlemlerde gerçek WR **%\(String(format: "%.0f", v.highEdgeWinRate))** (**\(String(format: "%+.2fR", v.highEdgeAvgR))**), **<48** uyardığı işlemlerde gerçek WR **%\(String(format: "%.0f", v.lowEdgeWinRate))** (**\(String(format: "%+.2fR", v.lowEdgeAvgR))**) — **\(String(format: "%+.0f", v.winRateLiftPoints)) puan WR farkı**.\n• **Aktif Piyasa / Disiplin Rejimi:** **\(r.state.rawValue)** (EWMA \(String(format: "%+.2fR", r.ewmaR)), CUSUM \(String(format: "%.1f", r.cusumDrift)), Risk Çarpanı **\(String(format: "%.2fx", r.riskMultiplier))**). \(r.summary)",
                metrics: [
                    AICoachMetric(label: "WALK-FORWARD AUC", value: String(format: "%.2f", v.rocAUC)),
                    AICoachMetric(label: "WR LIFT", value: String(format: "%+.0f puan", v.winRateLiftPoints)),
                    AICoachMetric(label: "REJİM ÇARPANI", value: String(format: "%.2fx", r.riskMultiplier))
                ],
                actionItems: [
                    r.advice,
                    "Model her yeni işlemle L2 Logistic + Ridge ağırlıklarını zaman-ağırlıklı olarak otomatik günceller.",
                    "İşlem girerken 'AI Optimal Riski Uygula' butonuyla rejim çarpanını doğrudan pozisyon boyutuna yansıt."
                ]
            )
        }

        // Entity-Aware Specific Setup Match (e.g. user names one of their playbooks)
        if let matchedSetup = setups.first(where: { !$0.name.isEmpty && q.contains($0.name.lowercased()) }) {
            let opt = optimizeSetup(matchedSetup, trades: trades, calendar: calendar)
            let linked = trades.filter { $0.setupID == matchedSetup.id || $0.setupName == matchedSetup.name }
            let sp = AnalyticsEngine.performance(linked)
            return AICoachResponse(
                question: cleanQ,
                headline: "Strateji Derin Analizi: \(matchedSetup.name)",
                answer: "• **Genel Performans:** n=\(sp.count) işlem · WR **%\(String(format: "%.0f", sp.winRate))** · Ort. **\(String(format: "%+.2fR", sp.averageR ?? 0))** · Net **\(String(format: "%+.0f %@", sp.netPnL, account.currency))** · İstikrar **\(opt.edgeStabilityScore)/100**.\n• **En İyi Koşullar:** Lider Parite **\(opt.bestInstrument)** · En İyi Seans **\(opt.bestSession)** · En Güçlü Teyit **\(opt.bestConfirmation)**.\n• **Ana Sızıntı:** \(opt.primaryLeak).",
                metrics: [
                    AICoachMetric(label: "İSTİKRAR SKORU", value: "\(opt.edgeStabilityScore)/100"),
                    AICoachMetric(label: "ORT. R", value: String(format: "%+.2fR", sp.averageR ?? 0)),
                    AICoachMetric(label: "ÖNERİLEN RİSK", value: String(format: "%%%.2f", opt.recommendedRiskPercent))
                ],
                actionItems: [
                    opt.recommendation,
                    "Bu modelde '\(opt.primaryLeak)' hatasına karşı kontrol listesi adımlarını sıkılaştır.",
                    "Lider parite ve seans dışında düşük olasılıklı versiyonları ele."
                ]
            )
        }

        // Entity-Aware Specific Instrument Match (e.g. "NQ", "ES", "EURUSD", "BTCUSD" mentioned directly without general comparison words)
        let tokens = Set(q.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count >= 2 })
        if !q.contains("karşılaştır") && !q.contains("parite bazlı"),
           let matchedInst = instGroups.first(where: { tokens.contains($0.name.lowercased()) }) {
            let scoped = trades.filter { $0.instrument.caseInsensitiveCompare(matchedInst.name) == .orderedSame }
            let ip = AnalyticsEngine.performance(scoped)
            let iSess = AnalyticsEngine.groups(scoped, by: .session, calendar: calendar).sorted { ($0.performance.averageR ?? 0) > ($1.performance.averageR ?? 0) }
            let iDir = AnalyticsEngine.groups(scoped, by: .direction, calendar: calendar).sorted { ($0.performance.averageR ?? 0) > ($1.performance.averageR ?? 0) }
            return AICoachResponse(
                question: cleanQ,
                headline: "\(matchedInst.name) Paritesi Derin AI Raporu (n = \(ip.count))",
                answer: "• **Genel Sonuç:** WR **%\(String(format: "%.0f", ip.winRate))** · Ort. **\(String(format: "%+.2fR", ip.averageR ?? 0))** · Net **\(String(format: "%+.0f %@", ip.netPnL, account.currency))** · Kural Uyumu **%\(String(format: "%.0f", ip.compliance))**.\n• **En Güçlü Yön & Seans:** **\(iDir.first?.name ?? "Long")** (\(String(format: "%+.2fR", iDir.first?.performance.averageR ?? 0))) · En verimli seans **\(iSess.first.map { L10n.text($0.name) } ?? "NY AM")** (\(String(format: "%+.2fR", iSess.first?.performance.averageR ?? 0))).",
                metrics: [
                    AICoachMetric(label: "\(matchedInst.name) WR", value: String(format: "%%%.0f", ip.winRate)),
                    AICoachMetric(label: "\(matchedInst.name) ORT. R", value: String(format: "%+.2fR", ip.averageR ?? 0)),
                    AICoachMetric(label: "EN İYİ YÖN", value: iDir.first?.name ?? "—")
                ],
                actionItems: [
                    "\(matchedInst.name) işlemlerini özellikle \(iSess.first.map { L10n.text($0.name) } ?? "NY AM") seansına yoğunlaştır.",
                    "Zayıf yönde (\(iDir.last?.name ?? "ters yön")) yalnızca geçerli SSMT teyidi varsa giriş yap.",
                    "Bu paritede kural uyumunu %90+ seviyesinde tut."
                ]
            )
        }

        // Intent 3: Session / Timing / Hours / Days
        if q.contains("seans") || q.contains("saat") || q.contains("zaman") || q.contains("london") || q.contains("new york") || q.contains("asia") || q.contains("bırakmalıyım") {
            let dayGroups = AnalyticsEngine.groups(trades, by: .day, calendar: calendar)
                .sorted { ($0.performance.averageR ?? $0.performance.netPnL) > ($1.performance.averageR ?? $1.performance.netPnL) }
            let bestS = sessionGroups.first
            let worstS = sessionGroups.last
            var lines: [String] = []
            if let bs = bestS {
                lines.append("• **En Verimli Seansın:** **\(L10n.text(bs.name))** (n=\(bs.performance.count), WR **%\(String(format: "%.0f", bs.performance.winRate))**, Ort. **\(String(format: "%+.2fR", bs.performance.averageR ?? 0))**, Net **\(String(format: "%+.0f %@", bs.performance.netPnL, account.currency))**).")
            }
            if let ws = worstS, ws.name != bestS?.name {
                lines.append("• **En Zayıf Seansın:** **\(L10n.text(ws.name))** (n=\(ws.performance.count), WR **%\(String(format: "%.0f", ws.performance.winRate))**, Ort. **\(String(format: "%+.2fR", ws.performance.averageR ?? 0))**, Net **\(String(format: "%+.0f %@", ws.performance.netPnL, account.currency))**).")
            }
            if let bd = dayGroups.first, let wd = dayGroups.last {
                lines.append("• **Gün Bazlı Dağılım:** En güçlü günün **\(L10n.text(bd.name))** (\(String(format: "%+.2fR", bd.performance.averageR ?? 0))), en zayıf günün **\(L10n.text(wd.name))** (\(String(format: "%+.2fR", wd.performance.averageR ?? 0))).")
            }
            return AICoachResponse(
                question: cleanQ,
                headline: "Seans & Zamanlama Edge Analizi",
                answer: lines.joined(separator: "\n"),
                metrics: [
                    AICoachMetric(label: "EN İYİ SEANS", value: bestS.map { L10n.text($0.name) } ?? "—"),
                    AICoachMetric(label: "EN İYİ SEANS R", value: String(format: "%+.2fR", bestS?.performance.averageR ?? 0)),
                    AICoachMetric(label: "EN ZAYIF SEANS", value: worstS.map { L10n.text($0.name) } ?? "—")
                ],
                actionItems: [
                    bestS.map { "Birincil işlem pencereni '\(L10n.text($0.name))' seansına sabitle." } ?? "Ana likidite saatlerinde işlem aç.",
                    (worstS?.performance.netPnL ?? 0) < 0 ? "'\(L10n.text(worstS!.name))' seansında işlem açmayı durdur veya riski %50 düşür." : "Seans dışı düşük hacimli saatlerde ekranı kapat.",
                    "Girişten önce True Open (00:00 / 08:30 NY) ve Q2 manipülasyonunun tamamlanmasını bekle."
                ]
            )
        }

        // Intent 4: Instrument Comparison
        if q.contains("parite") || q.contains("enstrüman") || q.contains("sembol") || q.contains("karşılaştır") {
            var lines: [String] = []
            for g in instGroups.prefix(4) {
                lines.append("• **\(g.name):** n=\(g.performance.count) işlem · WR **%\(String(format: "%.0f", g.performance.winRate))** · Ort. **\(String(format: "%+.2fR", g.performance.averageR ?? 0))** · PF **\(Format.factor(g.performance))** · Net **\(String(format: "%+.0f %@", g.performance.netPnL, account.currency))**.")
            }
            return AICoachResponse(
                question: cleanQ,
                headline: "Parite & Enstrüman Performans Karşılaştırması",
                answer: lines.joined(separator: "\n"),
                metrics: [
                    AICoachMetric(label: "LİDER PARİTE", value: instGroups.first?.name ?? "—"),
                    AICoachMetric(label: "LİDER ORT. R", value: String(format: "%+.2fR", instGroups.first?.performance.averageR ?? 0)),
                    AICoachMetric(label: "PARİTE SAYISI", value: "\(instGroups.count)")
                ],
                actionItems: [
                    instGroups.first.map { "Risk bütçenin %75'ini en yüksek beklentili pariten olan '\($0.name)' üzerinde yoğunlaştır." } ?? "Tek bir ana paritede uzmanlaş.",
                    (instGroups.last?.performance.netPnL ?? 0) < 0 ? "Negatif beklenti üreten '\(instGroups.last!.name)' paritesini izleme listesinden çıkar." : "Korelasyonlu paritelerde (örn. NQ ve ES) aynı anda çift pozisyon açarak riski ikiye katlama.",
                    "Pariteler arası SSMT uyumsuzluğunu giriş filtresi olarak kullan."
                ]
            )
        }

        // Intent 5: Mistakes / Losses / Psychology / Tilt / FOMO
        if q.contains("hata") || q.contains("kayb") || q.contains("kaybed") || q.contains("zarar") || q.contains("kural") || q.contains("fomo") || q.contains("tilt") || q.contains("psikoloji") || q.contains("sızıntı") || q.contains("neden") {
            let compliantPerf = AnalyticsEngine.performance(trades.filter(\.compliant))
            let brokenPerf = AnalyticsEngine.performance(trades.filter { !$0.compliant })
            var lines: [String] = []
            lines.append("• **Kural Uyumu Farkı:** Plana uyduğun **\(compliantPerf.count)** işlemde ortalama **\(String(format: "%+.2fR", compliantPerf.averageR ?? 0))** (WR %\(String(format: "%.0f", compliantPerf.winRate))) üretirken, kural ihlali yaptığın **\(brokenPerf.count)** işlemde ortalama **\(String(format: "%+.2fR", brokenPerf.averageR ?? 0))** (Net \(String(format: "%+.0f %@", brokenPerf.netPnL, account.currency))) sonuç aldın.")
            if let topM = mistakes.first {
                lines.append("• **Birincil Hata Kalıbı:** En maliyetli kural ihlalin **'\(L10n.text(topM.name))'** (\(topM.performance.count) işlem, toplam **\(String(format: "%+.0f %@", topM.performance.netPnL, account.currency))**).")
            }
            if !ml.moneyLeaks.isEmpty {
                let leakSummary = ml.moneyLeaks.prefix(2).map { "\($0.title) (\(String(format: "%+.2fR", $0.averageR)))" }.joined(separator: " ve ")
                lines.append("• **ML Tespit Edilen Sızıntılar:** \(leakSummary).")
            }
            if ml.tilt.rapidReentryCount > 0 {
                lines.append("• **İntikam İşlemi (Revenge) Etkisi:** Zarar sonrası 15 dk içinde açılan **\(ml.tilt.rapidReentryCount)** işlemde toplam **\(String(format: "%+.0f %@", ml.tilt.rapidReentryPnL, account.currency))** etki oluştu.")
            }
            return AICoachResponse(
                question: cleanQ,
                headline: "Kayıp & Sızıntı Kök Neden Analizi",
                answer: lines.joined(separator: "\n"),
                metrics: [
                    AICoachMetric(label: "KURALLI ORT. R", value: String(format: "%+.2fR", compliantPerf.averageR ?? 0)),
                    AICoachMetric(label: "İHLALLİ ORT. R", value: String(format: "%+.2fR", brokenPerf.averageR ?? 0)),
                    AICoachMetric(label: "TİLT SKORU", value: "\(ml.tilt.score)/100")
                ],
                actionItems: [
                    mistakes.first.map { "'\(L10n.text($0.name))' ihlalini sıfırlamak için giriş öncesi kontrol listesini zorunlu tut." } ?? "Kural uyumunu %90 üzerinde tut.",
                    "Zararlı kapanıştan sonra 15 dakika ekran başından kalk (zorunlu soğuma kuralı).",
                    ml.moneyLeaks.first.map { "'\($0.title)' koşulunda işlem açmayı bırak." } ?? "FOMO ≥ 6 olduğunda pozisyon büyüklüğünü yarıya indir."
                ]
            )
        }

        // Intent 6: QT / SSMT / CRT / Confirmations
        if q.contains("qt") || q.contains("çeyrek") || q.contains("ssmt") || q.contains("smt") || q.contains("crt") || q.contains("cisd") || q.contains("fvg") || q.contains("teyit") || q.contains("amdx") || q.contains("xamd") {
            let ssmtYes = AnalyticsEngine.performance(trades.filter(\.hasSSMT))
            let ssmtNo = AnalyticsEngine.performance(trades.filter { !$0.hasSSMT })
            let qtYes = AnalyticsEngine.performance(trades.filter(\.hasQT))
            let crtYes = AnalyticsEngine.performance(trades.filter(\.hasCRT))
            let qGroups = AnalyticsEngine.groups(trades, by: .quarter, calendar: calendar)
                .sorted { ($0.performance.averageR ?? 0) > ($1.performance.averageR ?? 0) }
            var lines: [String] = []
            lines.append("• **SSMT Etkisi:** Geçerli SSMT onayı olan **\(ssmtYes.count)** işlemde WR **%\(String(format: "%.0f", ssmtYes.winRate))** ve ortalama **\(String(format: "%+.2fR", ssmtYes.averageR ?? 0))** iken; SSMT olmayan işlemlerde ortalama **\(String(format: "%+.2fR", ssmtNo.averageR ?? 0))**.")
            lines.append("• **Quarterly Theory (QT) Hizalaması:** QT uyumlu **\(qtYes.count)** işlemde ortalama **\(String(format: "%+.2fR", qtYes.averageR ?? 0))** (WR %\(String(format: "%.0f", qtYes.winRate))). En verimli çeyrek: **\(qGroups.first?.name ?? "Q3")**.")
            lines.append("• **CRT & İç Yapı:** Onaylı CRT kurulumlarında (**n=\(crtYes.count)**) ortalama **\(String(format: "%+.2fR", crtYes.averageR ?? 0))** gerçekleşti.")
            return AICoachResponse(
                question: cleanQ,
                headline: "QT · SSMT · CRT Teyit Katkı Analizi",
                answer: lines.joined(separator: "\n"),
                metrics: [
                    AICoachMetric(label: "VALID SSMT R", value: String(format: "%+.2fR", ssmtYes.averageR ?? 0)),
                    AICoachMetric(label: "QT ALIGNED R", value: String(format: "%+.2fR", qtYes.averageR ?? 0)),
                    AICoachMetric(label: "CONFIRMED CRT R", value: String(format: "%+.2fR", crtYes.averageR ?? 0))
                ],
                actionItems: [
                    "Counter-Trend veya manipülasyon dönüşlerinde SSMT teyidi olmadan giriş yapma.",
                    "Giriş zamanlamasını True Open (TDO/T90O) ve \(qGroups.first?.name ?? "Q3") dağıtım fazıyla hizala.",
                    "1M/5M CISD + FVG birleşimini birincil tetikleyici olarak koru."
                ]
            )
        }

        // Intent 7: Risk / Kelly / Today's Plan
        if q.contains("risk") || q.contains("kelly") || q.contains("bugün") || q.contains("lot") || q.contains("bakiye") || q.contains("drawdown") {
            return AICoachResponse(
                question: cleanQ,
                headline: "Optimal Risk & Bugünün Seans Brifingi",
                answer: "• **AI Önerilen Risk:** Quarter-Kelly (**%\(String(format: "%.2f", briefing.quarterKellyPercent))**) × Rejim Çarpanı (**\(String(format: "%.2fx", briefing.regimeRiskMultiplier))**) ile işlem başına **%\(String(format: "%.2f", briefing.recommendedRiskPercent))** (**\(String(format: "%.0f %@", briefing.recommendedRiskDollars, account.currency))**) risk önerilir.\n• **Hesap & Rejim Durumu:** Bakiye **\(String(format: "%.0f %@", risk.balance, account.currency))**, aktif rejim **\(briefing.regimeState.rawValue)**, kayıp sınırına kalan mesafe **\(risk.remaining.map { String(format: "%.0f %@", $0, account.currency) } ?? "Açık")**.\n• **Gün & Seans Odağı:** \(briefing.weekdayEdgeSummary) · Bugün **\(briefing.bestSessionLabel)** seansında **\(briefing.primarySetupLabel)** kurulumuna odaklan.",
                metrics: [
                    AICoachMetric(label: "ÖNERİLEN RİSK", value: String(format: "%%%.2f (%.0f %@)", briefing.recommendedRiskPercent, briefing.recommendedRiskDollars, account.currency)),
                    AICoachMetric(label: "REJİM ÇARPANI", value: String(format: "%.2fx", briefing.regimeRiskMultiplier)),
                    AICoachMetric(label: "TİLT SEVİYESİ", value: briefing.tiltLevel.rawValue)
                ],
                actionItems: [
                    "İşlem başına riski \(String(format: "%.0f %@", briefing.recommendedRiskDollars, account.currency)) üstüne çıkarma.",
                    "Günlük 2R kayıp sınırına ulaşırsan seansı derhal kapat.",
                    "Günlük Plan sayfasındaki 'AI Seans Brifingi ile Doldur' butonuyla bugünün planını kaydet."
                ]
            )
        }

        // Intent 8: Executive Edge Synthesis (Default)
        let topSetup = setupGroups.first
        let topSess = sessionGroups.first
        let topInst = instGroups.first
        var summaryLines: [String] = []
        if let s = topSetup {
            summaryLines.append("• **En Kârlı Strateji:** **\(s.name)** (n=\(s.performance.count), WR **%\(String(format: "%.0f", s.performance.winRate))**, Ort. **\(String(format: "%+.2fR", s.performance.averageR ?? 0))**, Net **\(String(format: "%+.0f %@", s.performance.netPnL, account.currency))**).")
        }
        if let sess = topSess {
            summaryLines.append("• **En Güçlü Seans:** **\(L10n.text(sess.name))** (n=\(sess.performance.count), WR **%\(String(format: "%.0f", sess.performance.winRate))**, Ort. **\(String(format: "%+.2fR", sess.performance.averageR ?? 0))**).")
        }
        if let inst = topInst {
            summaryLines.append("• **En İyi Enstrüman:** **\(inst.name)** (n=\(inst.performance.count), Ort. **\(String(format: "%+.2fR", inst.performance.averageR ?? 0))**).")
        }
        if let golden = ml.goldenSetups.first {
            summaryLines.append("• **ML Altın Kombinasyon:** **\(golden.title)** (\(String(format: "%+.2fR", golden.averageR)) ortalama R, WR %\(String(format: "%.0f", golden.winRate))).")
        }
        if ml.filterSimulation.savedCapital > 0 {
            summaryLines.append("• **AI Filtre Potansiyeli:** Düşük kaliteli/kuralsız \(ml.filterSimulation.skippedTrades) işlem elenseydi **\(String(format: "%+.0f %@", ml.filterSimulation.savedCapital, account.currency))** ek sermaye korunurdu.")
        }

        return AICoachResponse(
            question: cleanQ,
            headline: "Kişisel Edge & Performans Sentezi (n = \(perf.count))",
            answer: summaryLines.joined(separator: "\n"),
            metrics: [
                AICoachMetric(label: "EN İYİ MODEL", value: topSetup?.name ?? "—"),
                AICoachMetric(label: "WALK-FORWARD AUC", value: ml.validation.isReady ? String(format: "%.2f", ml.validation.rocAUC) : "—"),
                AICoachMetric(label: "REJİM", value: ml.regime.state.rawValue),
                AICoachMetric(label: "ÖNERİLEN RİSK", value: String(format: "%%%.2f", briefing.recommendedRiskPercent))
            ],
            actionItems: [
                topSetup.map { "İşlemlerinin %80'ini '\($0.name)' modeline ve '\(topSess.map { L10n.text($0.name) } ?? "NY AM")' seansına odakla." } ?? "En yüksek R üreten kurulumunu Playbook'ta standartlaştır.",
                ml.moneyLeaks.first.map { "'\($0.title)' sızıntısını ele; bu kalıp toplam kârını aşağı çekiyor." } ?? "Kural uyumunu %\(String(format: "%.0f", perf.compliance)) seviyesinden %90+ seviyesine taşı.",
                "İşlem başına riski %\(String(format: "%.2f", briefing.recommendedRiskPercent)) (\(String(format: "%.0f %@", briefing.recommendedRiskDollars, account.currency))) olarak sabitle."
            ]
        )
    }

    // MARK: - MODULE 5: Playbook AI Model Optimizer

    struct SetupAIOptimization: Equatable {
        var sampleCount: Int
        var edgeStabilityScore: Int
        var bestInstrument: String
        var bestSession: String
        var bestConfirmation: String
        var recommendedRiskPercent: Double
        var primaryLeak: String
        var recommendation: String
    }

    static func optimizeSetup(_ setup: Setup, trades: [TradeRecord], calendar: Calendar) -> SetupAIOptimization {
        let linked = trades.filter { $0.setupID == setup.id || $0.setupName == setup.name }
        guard !linked.isEmpty else {
            return SetupAIOptimization(
                sampleCount: 0,
                edgeStabilityScore: 50,
                bestInstrument: "Veri bekleniyor",
                bestSession: "Veri bekleniyor",
                bestConfirmation: "Veri bekleniyor",
                recommendedRiskPercent: 0.50,
                primaryLeak: "Kayıtlı işlem yok",
                recommendation: "Bu stratejiyle işlem kaydettiğinde AI; en verimli seansı, pariteyi, en güçlü teyidi ve optimal risk yüzdesini otomatik çıkarır."
            )
        }

        let perf = AnalyticsEngine.performance(linked)
        let byInst = AnalyticsEngine.groups(linked, by: .instrument, calendar: calendar)
            .sorted { ($0.performance.averageR ?? $0.performance.netPnL) > ($1.performance.averageR ?? $1.performance.netPnL) }
        let bestInstText = byInst.first.map {
            "\($0.name) (\(String(format: "%+.2fR", $0.performance.averageR ?? 0)))"
        } ?? "Tüm Pariteler"

        let bySession = AnalyticsEngine.groups(linked, by: .session, calendar: calendar)
            .filter { $0.name != "Unspecified" }
            .sorted { ($0.performance.averageR ?? $0.performance.netPnL) > ($1.performance.averageR ?? $1.performance.netPnL) }
        let bestSessText = bySession.first.map {
            "\(L10n.text($0.name)) (\(String(format: "%+.2fR", $0.performance.averageR ?? 0)) · WR %\(String(format: "%.0f", $0.performance.winRate)))"
        } ?? "Tüm Seanslar"

        let byEdge = AnalyticsEngine.edgeMatrix(linked)
            .sorted { ($0.performance.averageR ?? $0.performance.netPnL) > ($1.performance.averageR ?? $1.performance.netPnL) }
        let bestConfText = byEdge.first.map {
            "\($0.name) (\(String(format: "%+.2fR", $0.performance.averageR ?? 0)))"
        } ?? (linked.filter(\.hasSSMT).count > 0 ? "Valid SSMT" : "CISD + FVG")

        let mistakes = AnalyticsEngine.mistakes(linked)
        let leakText = mistakes.first.map {
            "\(L10n.text($0.name)) (\( $0.performance.count )x · \(String(format: "%+.2fR", $0.performance.averageR ?? 0)))"
        } ?? "Belirgin kural sızıntısı yok (%100 uyum)"

        let avgR = perf.averageR ?? 0
        let rawStability = 45.0 + (perf.winRate - 50.0) * 0.55 + avgR * 16.0 + (perf.compliance - 75.0) * 0.35 + min(12.0, Double(linked.count) * 0.6)
        let stabilityScore = max(10, min(99, Int(rawStability.rounded())))

        let p = max(0.30, min(0.78, perf.winRate / 100.0))
        let b = max(0.9, min(3.5, perf.payoffRatio ?? 1.6))
        let qKelly = max(0.25, min(1.50, (p - ((1.0 - p) / b)) * 25.0))
        let recRisk = (qKelly * 20).rounded() / 20.0

        let rec: String
        if let s = bySession.first, let c = byEdge.first {
            rec = "AI Önerisi: '\(setup.name)' modelini \(byInst.first?.name ?? "ana paritede") · \(L10n.text(s.name)) seansında ve '\(c.name)' teyidiyle %\(String(format: "%.2f", recRisk)) riskle uygula."
        } else {
            rec = "AI Önerisi: '\(setup.name)' modelinde kural uyumunu koruyarak işlem başına %\(String(format: "%.2f", recRisk)) riskle örneklem sayısını 20+ işleme taşı."
        }

        return SetupAIOptimization(
            sampleCount: linked.count,
            edgeStabilityScore: stabilityScore,
            bestInstrument: bestInstText,
            bestSession: bestSessText,
            bestConfirmation: bestConfText,
            recommendedRiskPercent: recRisk,
            primaryLeak: leakText,
            recommendation: rec
        )
    }
}
