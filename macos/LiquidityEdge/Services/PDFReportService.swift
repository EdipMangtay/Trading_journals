import Foundation
import CoreGraphics
import PDFKit
import AppKit
import UniformTypeIdentifiers

/// Institutional-grade local PDFKit report generator (100% vector CoreGraphics + PDFKit, zero cloud/network).
/// Produces a crisp A4 multi-page performance tearsheet containing:
/// - Executive KPI strip & Discipline / Execution grade badge
/// - Vector Equity & Drawdown curve
/// - On-Device AI Regime (CUSUM/EWMA), Walk-Forward ROC-AUC & Counterfactual AI Filter telemetry
/// - Top Setups & AI Golden Edges / Money Leaks
/// - Session breakdown, Process Audit (rule violation costs), and Review narrative / trade ledger
enum PDFReportService {
    struct ReviewNotesSection: Equatable {
        var period: String
        var worked: String
        var didNot: String
        var repeatNext: String
        var stop: String
        var adjustment: String

        var hasAnyContent: Bool {
            ![worked, didNot, repeatNext, stop, adjustment]
                .allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }
    }

    struct ReportRequest {
        var title: String
        var subtitle: String
        var periodLabel: String
        var accountName: String
        var currency: String
        var startingBalance: Double
        var trades: [TradeRecord]
        var allAccountTrades: [TradeRecord]
        var calendar: Calendar
        var reviewNotes: ReviewNotesSection? = nil
        var generatedAt: Date = Date()
    }

    /// Optional test hook allowing automated tests to verify export wiring without modal NSSavePanel.
    @MainActor
    static var testSaveHandler: ((_ suggestedFileName: String, _ data: Data) -> URL?)?

    // MARK: - A4 Layout Geometry & Palette

    private static let pageWidth: CGFloat = 595.2   // A4 width in points (210 mm)
    private static let pageHeight: CGFloat = 841.8  // A4 height in points (297 mm)
    private static let marginX: CGFloat = 38.0
    private static let contentWidth: CGFloat = pageWidth - marginX * 2

    private static let cHeaderBg = NSColor(srgbRed: 0.043, green: 0.071, blue: 0.125, alpha: 1.0)
    private static let cPaper = NSColor.white
    private static let cCardBg = NSColor(srgbRed: 0.968, green: 0.976, blue: 0.988, alpha: 1.0)
    private static let cCardBorder = NSColor(srgbRed: 0.855, green: 0.886, blue: 0.925, alpha: 1.0)
    private static let cRowAlt = NSColor(srgbRed: 0.978, green: 0.984, blue: 0.992, alpha: 1.0)
    private static let cInk = NSColor(srgbRed: 0.075, green: 0.114, blue: 0.165, alpha: 1.0)
    private static let cMuted = NSColor(srgbRed: 0.355, green: 0.420, blue: 0.502, alpha: 1.0)
    private static let cMint = NSColor(srgbRed: 0.020, green: 0.478, blue: 0.333, alpha: 1.0)
    private static let cMintBright = NSColor(srgbRed: 0.310, green: 0.902, blue: 0.706, alpha: 1.0)
    private static let cRed = NSColor(srgbRed: 0.753, green: 0.165, blue: 0.239, alpha: 1.0)
    private static let cAmber = NSColor(srgbRed: 0.655, green: 0.408, blue: 0.055, alpha: 1.0)
    private static let cBlue = NSColor(srgbRed: 0.157, green: 0.341, blue: 0.659, alpha: 1.0)

    // MARK: - Public API

    static func generateDocument(for request: ReportRequest) throws -> PDFDocument {
        let data = try generatePDFData(for: request)
        guard let document = PDFDocument(data: data) else {
            throw JournalError(message: "PDF belgesi oluşturulamadı.")
        }
        return document
    }

    static func generatePDFData(for request: ReportRequest) throws -> Data {
        let ordered = AnalyticsEngine.ordered(request.trades)
        let performance = AnalyticsEngine.performance(ordered)
        let curve = AnalyticsEngine.curve(ordered)
        let setups = AnalyticsEngine.groups(ordered, by: .setup, calendar: request.calendar)
            .sorted {
                let lhs = $0.performance.averageR ?? ($0.performance.netPnL / max(1, request.startingBalance * 0.01))
                let rhs = $1.performance.averageR ?? ($1.performance.netPnL / max(1, request.startingBalance * 0.01))
                if abs(lhs - rhs) > 1e-6 { return lhs > rhs }
                return $0.performance.count > $1.performance.count
            }
        let sessions = AnalyticsEngine.groups(ordered, by: .session, calendar: request.calendar)
            .sorted { $0.performance.netPnL > $1.performance.netPnL }
        let mistakes = AnalyticsEngine.mistakes(ordered)

        // Use period-scoped ML snapshot when sufficient observations exist, otherwise use full account ML insights
        let usesAccountMLFallback = ordered.count < 8 && request.allAccountTrades.count >= ordered.count
        let mlSource = usesAccountMLFallback ? request.allAccountTrades : ordered
        let ml = EdgeMLEngine.analyze(mlSource, calendar: request.calendar)
        let mlScopeTag = usesAccountMLFallback ? "HESAP GENELİ ML (n=\(mlSource.count))" : "DÖNEM ML (n=\(mlSource.count))"

        let disciplineGrade = computeDisciplineGrade(performance: performance)

        let rawData = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let auxInfo: [CFString: Any] = [
            kCGPDFContextTitle: request.title,
            kCGPDFContextAuthor: "LIQUIDITY EDGE",
            kCGPDFContextCreator: "LIQUIDITY EDGE Native PDFKit Engine",
            kCGPDFContextSubject: "\(request.accountName) · \(request.periodLabel)"
        ]
        guard let consumer = CGDataConsumer(data: rawData as CFMutableData),
              let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, auxInfo as CFDictionary) else {
            throw JournalError(message: "PDF grafik bağlamı başlatılamadı.")
        }

        let hasSecondPage = (request.reviewNotes?.hasAnyContent == true) || !sessions.isEmpty || !mistakes.isEmpty || !ordered.isEmpty
        let totalPages = hasSecondPage ? 2 : 1

        // MARK: Page 1 — Executive Summary, Equity Curve, AI Telemetry & Top Setups
        ctx.beginPDFPage(nil)
        drawPageBackground(ctx)
        var y = pageHeight

        y = drawHeaderBanner(ctx, request: request, grade: disciplineGrade, performance: performance)
        y -= 16
        y = drawKPIGrid(ctx, topY: y, performance: performance, request: request)
        y -= 16
        y = drawEquityCurveSection(ctx, topY: y, curve: curve, performance: performance, request: request)
        y -= 16
        y = drawAITelemetrySection(ctx, topY: y, ml: ml, mlScopeTag: mlScopeTag, currency: request.currency)
        y -= 16
        _ = drawSetupsAndPatternsSection(ctx, topY: y, setups: setups, ml: ml, currency: request.currency)

        drawFooter(ctx, pageNumber: 1, totalPages: totalPages, request: request)
        ctx.endPDFPage()

        // MARK: Page 2 — Discipline & Review Notes, Session/Mistake Audit, Notable Trades
        if hasSecondPage {
            ctx.beginPDFPage(nil)
            drawPageBackground(ctx)
            var y2 = drawCompactSubheader(ctx, request: request, subtitle: "DİSİPLİN, SEANS ANALİZİ & İŞLEM DEFTERİ")
            y2 -= 16

            if let notes = request.reviewNotes, notes.hasAnyContent {
                y2 = drawReviewNotesSection(ctx, topY: y2, notes: notes)
                y2 -= 16
            }

            y2 = drawSessionAndMistakesSection(ctx, topY: y2, sessions: sessions, mistakes: mistakes, currency: request.currency)
            y2 -= 16

            if !ordered.isEmpty {
                _ = drawNotableTradesSection(ctx, topY: y2, trades: ordered, request: request)
            }

            drawFooter(ctx, pageNumber: 2, totalPages: totalPages, request: request)
            ctx.endPDFPage()
        }

        ctx.closePDF()

        let finalData = rawData as Data
        // Attach PDFDocument attributes and round-trip through PDFKit to guarantee valid PDFKit structure
        guard let pdfDoc = PDFDocument(data: finalData) else {
            throw JournalError(message: "Oluşturulan PDF PDFKit tarafından doğrulanamadı.")
        }
        var attrs = pdfDoc.documentAttributes ?? [:]
        attrs[PDFDocumentAttribute.titleAttribute] = request.title
        attrs[PDFDocumentAttribute.authorAttribute] = "LIQUIDITY EDGE"
        attrs[PDFDocumentAttribute.creatorAttribute] = "LIQUIDITY EDGE macOS"
        attrs[PDFDocumentAttribute.subjectAttribute] = "\(request.accountName) — \(request.periodLabel)"
        attrs[PDFDocumentAttribute.creationDateAttribute] = request.generatedAt
        pdfDoc.documentAttributes = attrs
        return pdfDoc.dataRepresentation() ?? finalData
    }

    @MainActor
    static func exportWithSavePanel(request: ReportRequest, suggestedFileName: String) -> Result<URL, Error>? {
        do {
            let data = try generatePDFData(for: request)
            let safeName = suggestedFileName.hasSuffix(".pdf") ? suggestedFileName : "\(suggestedFileName).pdf"
            if let testSaveHandler {
                if let url = testSaveHandler(safeName, data) {
                    return .success(url)
                }
                return nil
            }
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.pdf]
            panel.canCreateDirectories = true
            panel.isExtensionHidden = false
            panel.nameFieldStringValue = safeName
            panel.title = "Kurumsal PDF Performans Karnesi Dışa Aktar"
            panel.message = "Raporun kaydedileceği konumu seçin."
            guard panel.runModal() == .OK, let url = panel.url else { return nil }
            try data.write(to: url, options: .atomic)
            return .success(url)
        } catch {
            return .failure(error)
        }
    }

    static func sanitizedFileName(prefix: String, period: String, date: Date = Date()) -> String {
        let stamp = date.formatted(.iso8601.year().month().day().dateSeparator(.dash))
        let cleaned = "\(prefix)-\(period)-\(stamp)"
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: " ", with: "_")
        return "\(cleaned).pdf"
    }

    // MARK: - Grade Computation

    struct DisciplineGrade {
        let letter: String
        let label: String
        let color: NSColor
    }

    static func computeDisciplineGrade(performance p: Performance) -> DisciplineGrade {
        guard p.count > 0 else {
            return DisciplineGrade(letter: "—", label: "VERİ YOK", color: cMuted)
        }
        let compliancePart = p.compliance * 0.55
        let executionPart = p.executionScore * 0.35
        let expectancyBonus: Double
        if let avgR = p.averageR {
            expectancyBonus = max(0, min(10, (avgR + 0.5) * 6.0))
        } else {
            expectancyBonus = p.netPnL >= 0 ? 7.0 : 3.0
        }
        let total = compliancePart + executionPart + expectancyBonus
        switch total {
        case 90...: return DisciplineGrade(letter: "S+", label: "KURUMSAL DİSİPLİN", color: cMintBright)
        case 80..<90: return DisciplineGrade(letter: "A", label: "YÜKSEK STANDART", color: cMintBright)
        case 68..<80: return DisciplineGrade(letter: "B", label: "KONTROLLÜ SÜREÇ", color: NSColor(srgbRed: 0.43, green: 0.66, blue: 1.0, alpha: 1))
        case 54..<68: return DisciplineGrade(letter: "C", label: "GELİŞTİRME GEREKLİ", color: NSColor(srgbRed: 0.96, green: 0.74, blue: 0.38, alpha: 1))
        default: return DisciplineGrade(letter: "D", label: "SÜREÇ RİSKİ", color: NSColor(srgbRed: 0.97, green: 0.43, blue: 0.49, alpha: 1))
        }
    }

    // MARK: - Section Drawing Helpers

    private static func drawPageBackground(_ ctx: CGContext) {
        ctx.saveGState()
        ctx.setFillColor(cPaper.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
        ctx.restoreGState()
    }

    private static func drawHeaderBanner(_ ctx: CGContext, request: ReportRequest, grade: DisciplineGrade, performance: Performance) -> CGFloat {
        let bannerH: CGFloat = 104
        let bannerY = pageHeight - bannerH
        ctx.saveGState()
        ctx.setFillColor(cHeaderBg.cgColor)
        ctx.fill(CGRect(x: 0, y: bannerY, width: pageWidth, height: bannerH))

        // Mint top accent stripe
        ctx.setFillColor(cMintBright.cgColor)
        ctx.fill(CGRect(x: 0, y: pageHeight - 3.5, width: pageWidth, height: 3.5))
        ctx.restoreGState()

        // Eyebrow
        drawText(
            ctx,
            "LIQUIDITY EDGE  //  KURUMSAL PERFORMANS KARNESİ",
            rect: CGRect(x: marginX, y: pageHeight - 28, width: contentWidth - 135, height: 14),
            font: .monospacedSystemFont(ofSize: 8.5, weight: .bold),
            color: cMintBright
        )

        // Main Title
        drawText(
            ctx,
            request.title,
            rect: CGRect(x: marginX, y: pageHeight - 58, width: contentWidth - 140, height: 28),
            font: .systemFont(ofSize: 20, weight: .bold),
            color: .white
        )

        // Subtitle & Period Metadata
        let dateStamp = Format.date(request.generatedAt, calendar: request.calendar, time: true)
        let meta = "\(request.accountName)  ·  \(request.periodLabel)  ·  Oluşturma: \(dateStamp)"
        drawText(
            ctx,
            meta,
            rect: CGRect(x: marginX, y: bannerY + 14, width: contentWidth - 140, height: 24),
            font: .systemFont(ofSize: 9.5, weight: .medium),
            color: NSColor(white: 0.78, alpha: 1.0)
        )

        // Right-side Discipline Grade Card
        let badgeW: CGFloat = 122
        let badgeH: CGFloat = 68
        let badgeRect = CGRect(x: pageWidth - marginX - badgeW, y: bannerY + 18, width: badgeW, height: badgeH)
        drawRoundedRect(ctx, rect: badgeRect, radius: 10, fill: NSColor(white: 1.0, alpha: 0.06), stroke: grade.color.withAlphaComponent(0.55), lineWidth: 1.0)

        drawText(
            ctx,
            "DİSİPLİN NOTU",
            rect: CGRect(x: badgeRect.minX + 8, y: badgeRect.maxY - 18, width: badgeW - 16, height: 12),
            font: .monospacedSystemFont(ofSize: 7.5, weight: .bold),
            color: NSColor(white: 0.72, alpha: 1.0),
            alignment: .center
        )
        drawText(
            ctx,
            grade.letter,
            rect: CGRect(x: badgeRect.minX + 8, y: badgeRect.minY + 20, width: badgeW - 16, height: 28),
            font: .systemFont(ofSize: 24, weight: .heavy),
            color: grade.color,
            alignment: .center
        )
        drawText(
            ctx,
            grade.label,
            rect: CGRect(x: badgeRect.minX + 4, y: badgeRect.minY + 6, width: badgeW - 8, height: 12),
            font: .monospacedSystemFont(ofSize: 6.8, weight: .semibold),
            color: NSColor(white: 0.86, alpha: 1.0),
            alignment: .center
        )

        return bannerY
    }

    private static func drawCompactSubheader(_ ctx: CGContext, request: ReportRequest, subtitle: String) -> CGFloat {
        let bannerH: CGFloat = 54
        let bannerY = pageHeight - bannerH
        ctx.saveGState()
        ctx.setFillColor(cHeaderBg.cgColor)
        ctx.fill(CGRect(x: 0, y: bannerY, width: pageWidth, height: bannerH))
        ctx.setFillColor(cMintBright.cgColor)
        ctx.fill(CGRect(x: 0, y: pageHeight - 3.0, width: pageWidth, height: 3.0))
        ctx.restoreGState()

        drawText(
            ctx,
            "LIQUIDITY EDGE  //  \(subtitle)",
            rect: CGRect(x: marginX, y: pageHeight - 25, width: contentWidth - 160, height: 14),
            font: .monospacedSystemFont(ofSize: 8.5, weight: .bold),
            color: cMintBright
        )
        drawText(
            ctx,
            "\(request.title)  ·  \(request.periodLabel)",
            rect: CGRect(x: marginX, y: bannerY + 10, width: contentWidth, height: 16),
            font: .systemFont(ofSize: 10.5, weight: .semibold),
            color: .white
        )
        return bannerY
    }

    private static func drawKPIGrid(_ ctx: CGContext, topY: CGFloat, performance p: Performance, request: ReportRequest) -> CGFloat {
        let gap: CGFloat = 10
        let cardW = (contentWidth - gap * 2) / 3
        let cardH: CGFloat = 56
        let ddPct = request.startingBalance > 0 ? (p.maxDrawdown / request.startingBalance) * 100 : 0

        let items: [(String, String, String, NSColor)] = [
            (
                "NET K/Z",
                Format.money(p.netPnL, currency: request.currency),
                "Beklenti: \(Format.money(p.expectancy, currency: request.currency)) / işlem",
                p.netPnL > 0 ? cMint : p.netPnL < 0 ? cRed : cInk
            ),
            (
                "TOPLAM R / ORT. R",
                "\(Format.r(p.totalR))  (\(Format.r(p.averageR)))",
                "R Kayıtlı: \(p.rCount) / \(p.count) işlem",
                p.totalR > 0 ? cMint : p.totalR < 0 ? cRed : cInk
            ),
            (
                "KAZANMA ORANI (WR)",
                Format.percent(p.winRate),
                "\(p.wins) Kazanç · \(p.losses) Kayıp · \(max(0, p.count - p.wins - p.losses)) BE",
                p.winRate >= 50 ? cMint : cInk
            ),
            (
                "KÂR FAKTÖRÜ (PF)",
                Format.factor(p),
                "En İyi: \(Format.money(p.bestTrade, currency: request.currency))",
                (p.profitFactor ?? 0) >= 1.5 ? cMint : cBlue
            ),
            (
                "MAKS. DRAWDOWN",
                Format.money(-abs(p.maxDrawdown), currency: request.currency),
                "Başlangıç bakiyesinin %\(String(format: "%.1f", ddPct))'i",
                p.maxDrawdown > 0 ? cAmber : cMint
            ),
            (
                "PLAN UYUMU & SÜREÇ",
                Format.percent(p.compliance),
                "İcra Skoru: \(Format.number(p.executionScore, digits: 0))/100",
                p.compliance >= 80 ? cMint : p.compliance >= 60 ? cAmber : cRed
            )
        ]

        for (index, item) in items.enumerated() {
            let row = index / 3
            let col = index % 3
            let x = marginX + CGFloat(col) * (cardW + gap)
            let y = topY - CGFloat(row + 1) * cardH - CGFloat(row) * gap
            let rect = CGRect(x: x, y: y, width: cardW, height: cardH)
            drawRoundedRect(ctx, rect: rect, radius: 8, fill: cCardBg, stroke: cCardBorder, lineWidth: 0.75)

            // Left vertical accent pill
            drawRoundedRect(ctx, rect: CGRect(x: x + 1, y: y + 10, width: 3, height: cardH - 20), radius: 1.5, fill: item.3, stroke: nil)

            drawText(
                ctx, item.0,
                rect: CGRect(x: x + 12, y: rect.maxY - 17, width: cardW - 18, height: 11),
                font: .monospacedSystemFont(ofSize: 7.2, weight: .bold),
                color: cMuted
            )
            drawText(
                ctx, item.1,
                rect: CGRect(x: x + 12, y: y + 19, width: cardW - 18, height: 20),
                font: .systemFont(ofSize: 13.5, weight: .bold),
                color: item.3
            )
            drawText(
                ctx, item.2,
                rect: CGRect(x: x + 12, y: y + 6, width: cardW - 18, height: 12),
                font: .systemFont(ofSize: 7.8, weight: .regular),
                color: cMuted
            )
        }

        return topY - (cardH * 2 + gap)
    }

    private static func drawEquityCurveSection(_ ctx: CGContext, topY: CGFloat, curve: [CurvePoint], performance: Performance, request: ReportRequest) -> CGFloat {
        let boxH: CGFloat = 156
        let boxY = topY - boxH
        let boxRect = CGRect(x: marginX, y: boxY, width: contentWidth, height: boxH)
        drawRoundedRect(ctx, rect: boxRect, radius: 9, fill: .white, stroke: cCardBorder, lineWidth: 0.8)

        drawText(
            ctx,
            "SERMAYE & KÜMÜLATİF PERFORMANS EĞRİSİ (NET K/Z)",
            rect: CGRect(x: marginX + 14, y: boxRect.maxY - 22, width: 320, height: 14),
            font: .monospacedSystemFont(ofSize: 8.2, weight: .bold),
            color: cInk
        )

        let summaryTag = "Başlangıç: \(Format.money(request.startingBalance, currency: request.currency))  ·  Bitiş: \(Format.money(request.startingBalance + performance.netPnL, currency: request.currency))"
        drawText(
            ctx,
            summaryTag,
            rect: CGRect(x: marginX + 260, y: boxRect.maxY - 22, width: contentWidth - 274, height: 14),
            font: .monospacedSystemFont(ofSize: 7.8, weight: .medium),
            color: cMuted,
            alignment: .right
        )

        let plotRect = CGRect(x: marginX + 54, y: boxY + 20, width: contentWidth - 70, height: boxH - 50)
        guard curve.count >= 2 else {
            drawText(
                ctx,
                "Eğri çizimi için bu dönemde en az 1 tamamlanmış işlem kaydı gerekir.",
                rect: CGRect(x: plotRect.minX, y: plotRect.midY - 8, width: plotRect.width, height: 18),
                font: .systemFont(ofSize: 9.5, weight: .medium),
                color: cMuted,
                alignment: .center
            )
            return boxY
        }

        let values = curve.map(\.equity)
        let rawMin = min(0, values.min() ?? 0)
        let rawMax = max(0, values.max() ?? 0)
        let span = max(1.0, rawMax - rawMin)
        let pad = span * 0.12
        let minV = rawMin - pad
        let maxV = rawMax + pad
        let rangeV = max(1.0, maxV - minV)

        func point(at index: Int, value: Double) -> CGPoint {
            let xRatio = CGFloat(index) / CGFloat(max(1, curve.count - 1))
            let yRatio = CGFloat((value - minV) / rangeV)
            return CGPoint(
                x: plotRect.minX + xRatio * plotRect.width,
                y: plotRect.minY + yRatio * plotRect.height
            )
        }

        // Horizontal gridlines & Y axis labels
        ctx.saveGState()
        for step in 0...3 {
            let frac = CGFloat(step) / 3.0
            let yPos = plotRect.minY + frac * plotRect.height
            let val = minV + Double(frac) * rangeV
            ctx.setStrokeColor(cCardBorder.withAlphaComponent(0.7).cgColor)
            ctx.setLineWidth(0.5)
            ctx.setLineDash(phase: 0, lengths: [2, 3])
            ctx.move(to: CGPoint(x: plotRect.minX, y: yPos))
            ctx.addLine(to: CGPoint(x: plotRect.maxX, y: yPos))
            ctx.strokePath()

            drawText(
                ctx,
                compactMoney(val, currency: request.currency),
                rect: CGRect(x: marginX + 6, y: yPos - 6, width: 44, height: 12),
                font: .monospacedSystemFont(ofSize: 7.0, weight: .regular),
                color: cMuted,
                alignment: .right
            )
        }

        // Zero baseline
        let zeroY = plotRect.minY + CGFloat((0 - minV) / rangeV) * plotRect.height
        ctx.setLineDash(phase: 0, lengths: [])
        ctx.setStrokeColor(cMuted.withAlphaComponent(0.45).cgColor)
        ctx.setLineWidth(0.75)
        ctx.move(to: CGPoint(x: plotRect.minX, y: zeroY))
        ctx.addLine(to: CGPoint(x: plotRect.maxX, y: zeroY))
        ctx.strokePath()

        let strokeColor = (values.last ?? 0) >= 0 ? cMint : cRed

        // Soft area fill between zero line and curve
        let fillPath = CGMutablePath()
        let firstPt = point(at: 0, value: values[0])
        fillPath.move(to: CGPoint(x: firstPt.x, y: zeroY))
        for i in 0..<values.count {
            fillPath.addLine(to: point(at: i, value: values[i]))
        }
        let lastPt = point(at: values.count - 1, value: values[values.count - 1])
        fillPath.addLine(to: CGPoint(x: lastPt.x, y: zeroY))
        fillPath.closeSubpath()
        ctx.addPath(fillPath)
        ctx.setFillColor(strokeColor.withAlphaComponent(0.11).cgColor)
        ctx.fillPath()

        // Main vector equity stroke
        let linePath = CGMutablePath()
        linePath.move(to: firstPt)
        for i in 1..<values.count {
            linePath.addLine(to: point(at: i, value: values[i]))
        }
        ctx.addPath(linePath)
        ctx.setStrokeColor(strokeColor.cgColor)
        ctx.setLineWidth(2.0)
        ctx.setLineJoin(.round)
        ctx.setLineCap(.round)
        ctx.strokePath()

        // Highlight final point marker
        ctx.setFillColor(strokeColor.cgColor)
        ctx.fillEllipse(in: CGRect(x: lastPt.x - 3.2, y: lastPt.y - 3.2, width: 6.4, height: 6.4))
        ctx.restoreGState()

        // Bottom X axis start/end markers
        drawText(
            ctx,
            "İşlem #0",
            rect: CGRect(x: plotRect.minX, y: boxY + 5, width: 80, height: 11),
            font: .monospacedSystemFont(ofSize: 7.0, weight: .regular),
            color: cMuted
        )
        drawText(
            ctx,
            "İşlem #\(max(0, curve.count - 1)) · Son: \(Format.money(values.last ?? 0, currency: request.currency))",
            rect: CGRect(x: plotRect.maxX - 180, y: boxY + 5, width: 180, height: 11),
            font: .monospacedSystemFont(ofSize: 7.0, weight: .semibold),
            color: strokeColor,
            alignment: .right
        )

        return boxY
    }

    private static func drawAITelemetrySection(_ ctx: CGContext, topY: CGFloat, ml: EdgeMLEngine.MLInsightsSnapshot, mlScopeTag: String, currency: String) -> CGFloat {
        let headerH: CGFloat = 16
        drawText(
            ctx,
            "CİHAZ İÇİ AI TELEMETRİSİ  ·  \(mlScopeTag)",
            rect: CGRect(x: marginX, y: topY - headerH, width: contentWidth, height: 14),
            font: .monospacedSystemFont(ofSize: 8.4, weight: .bold),
            color: cMint
        )

        let cardTop = topY - headerH - 6
        let gap: CGFloat = 10
        let cardW = (contentWidth - gap * 2) / 3
        let cardH: CGFloat = 94
        let cardY = cardTop - cardH

        // Card 1: CUSUM Market Regime
        let r1 = CGRect(x: marginX, y: cardY, width: cardW, height: cardH)
        let regColor: NSColor = {
            switch ml.regime.state {
            case .hotEdge: return cMint
            case .stable: return cBlue
            case .coldVariance: return cAmber
            case .regimeDrift: return cRed
            }
        }()
        drawRoundedRect(ctx, rect: r1, radius: 8, fill: cCardBg, stroke: regColor.withAlphaComponent(0.45), lineWidth: 0.9)
        drawText(ctx, "AKTİF REJİM (CUSUM)", rect: CGRect(x: r1.minX + 10, y: r1.maxY - 17, width: cardW - 20, height: 11), font: .monospacedSystemFont(ofSize: 7.0, weight: .bold), color: cMuted)
        drawText(ctx, ml.regime.state.rawValue, rect: CGRect(x: r1.minX + 10, y: r1.maxY - 36, width: cardW - 20, height: 16), font: .systemFont(ofSize: 10.5, weight: .bold), color: regColor)
        drawText(ctx, "Risk Çarpanı: \(String(format: "%.2fx", ml.regime.riskMultiplier))  ·  EWMA \(Format.r(ml.regime.ewmaR))", rect: CGRect(x: r1.minX + 10, y: r1.maxY - 52, width: cardW - 20, height: 13), font: .monospacedSystemFont(ofSize: 7.6, weight: .semibold), color: cInk)
        drawText(ctx, ml.regime.advice, rect: CGRect(x: r1.minX + 10, y: r1.minY + 7, width: cardW - 20, height: 32), font: .systemFont(ofSize: 7.5, weight: .regular), color: cMuted)

        // Card 2: Walk-Forward OOS Validation
        let r2 = CGRect(x: marginX + cardW + gap, y: cardY, width: cardW, height: cardH)
        let aucColor = ml.validation.isReady ? (ml.validation.rocAUC >= 0.65 ? cMint : cBlue) : cMuted
        drawRoundedRect(ctx, rect: r2, radius: 8, fill: cCardBg, stroke: aucColor.withAlphaComponent(0.45), lineWidth: 0.9)
        drawText(ctx, "WALK-FORWARD DOĞRULUK (OOS)", rect: CGRect(x: r2.minX + 10, y: r2.maxY - 17, width: cardW - 20, height: 11), font: .monospacedSystemFont(ofSize: 7.0, weight: .bold), color: cMuted)
        let aucText = ml.validation.isReady ? "ROC-AUC \(String(format: "%.3f", ml.validation.rocAUC))" : "Veri Birikiyor"
        drawText(ctx, aucText, rect: CGRect(x: r2.minX + 10, y: r2.maxY - 36, width: cardW - 20, height: 16), font: .systemFont(ofSize: 11.5, weight: .bold), color: aucColor)
        let liftStr = ml.validation.isReady
            ? "Brier Beceri: %\(String(format: "%.1f", ml.validation.brierSkillPercent)) · WR Fark: +\(String(format: "%.1f", ml.validation.winRateLiftPoints))p"
            : "En az 12 işlemle OOS doğrulama açılır."
        drawText(ctx, liftStr, rect: CGRect(x: r2.minX + 10, y: r2.maxY - 52, width: cardW - 20, height: 13), font: .monospacedSystemFont(ofSize: 7.3, weight: .semibold), color: cInk)
        drawText(ctx, "\(ml.validation.qualityLabel) (\(ml.validation.evaluatedCount) kronolojik test).", rect: CGRect(x: r2.minX + 10, y: r2.minY + 7, width: cardW - 20, height: 32), font: .systemFont(ofSize: 7.5, weight: .regular), color: cMuted)

        // Card 3: AI Filter Counterfactual & Tilt
        let r3 = CGRect(x: marginX + (cardW + gap) * 2, y: cardY, width: cardW, height: cardH)
        let sim = ml.filterSimulation
        let tiltColor = ml.tilt.level == .elevated ? cRed : ml.tilt.level == .caution ? cAmber : cMint
        drawRoundedRect(ctx, rect: r3, radius: 8, fill: cCardBg, stroke: tiltColor.withAlphaComponent(0.45), lineWidth: 0.9)
        drawText(ctx, "AI FİLTRE ETKİSİ & TİLT", rect: CGRect(x: r3.minX + 10, y: r3.maxY - 17, width: cardW - 20, height: 11), font: .monospacedSystemFont(ofSize: 7.0, weight: .bold), color: cMuted)
        let savedPrefix = sim.savedCapital >= 0 ? "+" : ""
        drawText(ctx, "\(savedPrefix)\(Format.money(sim.savedCapital, currency: currency))", rect: CGRect(x: r3.minX + 10, y: r3.maxY - 36, width: cardW - 20, height: 16), font: .systemFont(ofSize: 11.5, weight: .bold), color: sim.savedCapital >= 0 ? cMint : cAmber)
        drawText(ctx, "Tilt: \(ml.tilt.level.rawValue) (\(ml.tilt.score)/100)", rect: CGRect(x: r3.minX + 10, y: r3.maxY - 52, width: cardW - 20, height: 13), font: .monospacedSystemFont(ofSize: 7.4, weight: .semibold), color: tiltColor)
        let simNote = sim.skippedTrades > 0
            ? "\(sim.skippedTrades) düşük kaliteli işlem elenerek DD %\(String(format: "%.0f", sim.drawdownReductionPercent)) azaltılır."
            : "Mevcut kayıtlar AI disiplin eşiğinin üzerinde."
        drawText(ctx, simNote, rect: CGRect(x: r3.minX + 10, y: r3.minY + 7, width: cardW - 20, height: 32), font: .systemFont(ofSize: 7.5, weight: .regular), color: cMuted)

        return cardY
    }

    private static func drawSetupsAndPatternsSection(_ ctx: CGContext, topY: CGFloat, setups: [MetricGroup], ml: EdgeMLEngine.MLInsightsSnapshot, currency: String) -> CGFloat {
        drawText(
            ctx,
            "EN GÜÇLÜ KURULUMLAR & AI ÖRÜNTÜ KEŞFİ",
            rect: CGRect(x: marginX, y: topY - 15, width: contentWidth, height: 14),
            font: .monospacedSystemFont(ofSize: 8.4, weight: .bold),
            color: cInk
        )

        var y = topY - 22
        let visibleSetups = Array(setups.prefix(6))
        let rowH: CGFloat = 20
        let tableH = CGFloat(max(1, visibleSetups.count) + 1) * rowH
        let tableRect = CGRect(x: marginX, y: y - tableH, width: contentWidth, height: tableH)
        drawRoundedRect(ctx, rect: tableRect, radius: 7, fill: .white, stroke: cCardBorder, lineWidth: 0.75)

        // Header strip
        let headerRect = CGRect(x: tableRect.minX, y: tableRect.maxY - rowH, width: tableRect.width, height: rowH)
        drawRoundedRect(ctx, rect: headerRect, radius: 0, fill: cCardBg, stroke: nil)

        let cols: [(String, CGFloat, CGFloat, NSTextAlignment)] = [
            ("KURULUM / STRATEJİ", 12, 185, .left),
            ("İŞLEM", 200, 44, .right),
            ("WR %", 250, 56, .right),
            ("ORT. R", 312, 62, .right),
            ("NET K/Z", 380, 74, .right),
            ("UYUM %", 458, 50, .right)
        ]
        for col in cols {
            drawText(ctx, col.0, rect: CGRect(x: tableRect.minX + col.1, y: headerRect.minY + 4, width: col.2, height: 12), font: .monospacedSystemFont(ofSize: 7.2, weight: .bold), color: cMuted, alignment: col.3)
        }

        if visibleSetups.isEmpty {
            drawText(ctx, "Bu dönem için kayıtlı kurulum bulunamadı.", rect: CGRect(x: tableRect.minX + 12, y: tableRect.minY + 4, width: tableRect.width - 24, height: 13), font: .systemFont(ofSize: 8.5), color: cMuted)
        } else {
            for (idx, group) in visibleSetups.enumerated() {
                let rowY = tableRect.maxY - CGFloat(idx + 2) * rowH
                if idx.isMultiple(of: 2) {
                    ctx.saveGState()
                    ctx.setFillColor(cRowAlt.cgColor)
                    ctx.fill(CGRect(x: tableRect.minX + 0.5, y: rowY, width: tableRect.width - 1, height: rowH))
                    ctx.restoreGState()
                }
                let p = group.performance
                drawText(ctx, group.name, rect: CGRect(x: tableRect.minX + 12, y: rowY + 4, width: 185, height: 13), font: .systemFont(ofSize: 8.5, weight: .semibold), color: cInk)
                drawText(ctx, "\(p.count)", rect: CGRect(x: tableRect.minX + 200, y: rowY + 4, width: 44, height: 13), font: .monospacedSystemFont(ofSize: 8.2, weight: .regular), color: cMuted, alignment: .right)
                drawText(ctx, Format.percent(p.winRate), rect: CGRect(x: tableRect.minX + 250, y: rowY + 4, width: 56, height: 13), font: .monospacedSystemFont(ofSize: 8.2, weight: .medium), color: cInk, alignment: .right)
                drawText(ctx, Format.r(p.averageR), rect: CGRect(x: tableRect.minX + 312, y: rowY + 4, width: 62, height: 13), font: .monospacedSystemFont(ofSize: 8.2, weight: .bold), color: (p.averageR ?? 0) >= 0 ? cMint : cRed, alignment: .right)
                drawText(ctx, Format.money(p.netPnL, currency: currency), rect: CGRect(x: tableRect.minX + 380, y: rowY + 4, width: 74, height: 13), font: .monospacedSystemFont(ofSize: 8.2, weight: .semibold), color: p.netPnL >= 0 ? cMint : cRed, alignment: .right)
                drawText(ctx, Format.percent(p.compliance), rect: CGRect(x: tableRect.minX + 458, y: rowY + 4, width: 50, height: 13), font: .monospacedSystemFont(ofSize: 8.2, weight: .regular), color: p.compliance >= 80 ? cMint : cAmber, alignment: .right)
            }
        }

        y = tableRect.minY - 12

        // Compact AI Golden Edges & Money Leaks Strip
        let stripH: CGFloat = 62
        if y - stripH >= 48 {
            let halfW = (contentWidth - 10) / 2
            let leftRect = CGRect(x: marginX, y: y - stripH, width: halfW, height: stripH)
            let rightRect = CGRect(x: marginX + halfW + 10, y: y - stripH, width: halfW, height: stripH)

            drawRoundedRect(ctx, rect: leftRect, radius: 7, fill: cMint.withAlphaComponent(0.055), stroke: cMint.withAlphaComponent(0.32), lineWidth: 0.75)
            drawText(ctx, "AI ALTIN KURULUMLAR (EN YÜKSEK EDGE)", rect: CGRect(x: leftRect.minX + 10, y: leftRect.maxY - 16, width: halfW - 20, height: 11), font: .monospacedSystemFont(ofSize: 7.0, weight: .bold), color: cMint)
            let edgeLines = ml.goldenSetups.prefix(2).map { "• \($0.title): \(Format.percent($0.winRate)) WR · \(Format.r($0.averageR)) (n=\($0.sampleCount))" }
            let edgeBody = edgeLines.isEmpty ? "Yeterli pozitif örüntü biriktikçe burada listelenir." : edgeLines.joined(separator: "\n")
            drawText(ctx, edgeBody, rect: CGRect(x: leftRect.minX + 10, y: leftRect.minY + 6, width: halfW - 20, height: 38), font: .systemFont(ofSize: 7.8, weight: .medium), color: cInk)

            drawRoundedRect(ctx, rect: rightRect, radius: 7, fill: cRed.withAlphaComponent(0.055), stroke: cRed.withAlphaComponent(0.32), lineWidth: 0.75)
            drawText(ctx, "AI SERMAYE SIZINTILARI (KAÇINILMASI GEREKENLER)", rect: CGRect(x: rightRect.minX + 10, y: rightRect.maxY - 16, width: halfW - 20, height: 11), font: .monospacedSystemFont(ofSize: 7.0, weight: .bold), color: cRed)
            let leakLines = ml.moneyLeaks.prefix(2).map { "• \($0.title): \(Format.percent($0.winRate)) WR · \(Format.r($0.averageR)) (n=\($0.sampleCount))" }
            let leakBody = leakLines.isEmpty ? "Kritik istatistiksel para sızıntısı tespit edilmedi." : leakLines.joined(separator: "\n")
            drawText(ctx, leakBody, rect: CGRect(x: rightRect.minX + 10, y: rightRect.minY + 6, width: halfW - 20, height: 38), font: .systemFont(ofSize: 7.8, weight: .medium), color: cInk)

            y = leftRect.minY
        }

        return y
    }

    // MARK: - Page 2 Sections

    private static func drawReviewNotesSection(_ ctx: CGContext, topY: CGFloat, notes: ReviewNotesSection) -> CGFloat {
        drawText(
            ctx,
            "DÖNEM DEĞERLENDİRMESİ & SONRAKİ DÖNEM EYLEM PLANI (\(notes.period.uppercased()))",
            rect: CGRect(x: marginX, y: topY - 15, width: contentWidth, height: 14),
            font: .monospacedSystemFont(ofSize: 8.4, weight: .bold),
            color: cBlue
        )

        let cards: [(String, String, NSColor)] = [
            ("NELER İŞE YARADI?", notes.worked, cMint),
            ("NELER İŞE YARAMADI?", notes.didNot, cRed),
            ("TEKRAR EDİLECEKLER", notes.repeatNext, cBlue),
            ("BIRAKILACAKLAR", notes.stop, cAmber)
        ]

        let gap: CGFloat = 10
        let colW = (contentWidth - gap) / 2
        let cellH: CGFloat = 68
        var y = topY - 22

        for (i, item) in cards.enumerated() {
            let row = i / 2
            let col = i % 2
            let x = marginX + CGFloat(col) * (colW + gap)
            let cellY = y - CGFloat(row + 1) * cellH - CGFloat(row) * gap
            let rect = CGRect(x: x, y: cellY, width: colW, height: cellH)
            drawRoundedRect(ctx, rect: rect, radius: 8, fill: cCardBg, stroke: item.2.withAlphaComponent(0.35), lineWidth: 0.75)
            drawText(ctx, item.0, rect: CGRect(x: x + 10, y: rect.maxY - 16, width: colW - 20, height: 11), font: .monospacedSystemFont(ofSize: 7.2, weight: .bold), color: item.2)
            let textVal = item.1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Kayıt girilmedi." : item.1
            drawText(ctx, textVal, rect: CGRect(x: x + 10, y: cellY + 6, width: colW - 20, height: cellH - 25), font: .systemFont(ofSize: 8.0), color: cInk)
        }

        y -= (cellH * 2 + gap + 10)
        let adjH: CGFloat = 52
        let adjRect = CGRect(x: marginX, y: y - adjH, width: contentWidth, height: adjH)
        drawRoundedRect(ctx, rect: adjRect, radius: 8, fill: cBlue.withAlphaComponent(0.06), stroke: cBlue.withAlphaComponent(0.42), lineWidth: 0.9)
        drawText(ctx, "SONRAKİ DÖNEM İÇİN ANA ODAK / DÜZELTME", rect: CGRect(x: adjRect.minX + 12, y: adjRect.maxY - 16, width: contentWidth - 24, height: 11), font: .monospacedSystemFont(ofSize: 7.4, weight: .bold), color: cBlue)
        let adjText = notes.adjustment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Belirtilmedi." : notes.adjustment
        drawText(ctx, adjText, rect: CGRect(x: adjRect.minX + 12, y: adjRect.minY + 6, width: contentWidth - 24, height: 28), font: .systemFont(ofSize: 8.6, weight: .medium), color: cInk)

        return adjRect.minY
    }

    private static func drawSessionAndMistakesSection(_ ctx: CGContext, topY: CGFloat, sessions: [MetricGroup], mistakes: [MetricGroup], currency: String) -> CGFloat {
        let gap: CGFloat = 12
        let halfW = (contentWidth - gap) / 2
        let boxH: CGFloat = 148
        let boxY = topY - boxH

        // Left: Session Breakdown
        let leftRect = CGRect(x: marginX, y: boxY, width: halfW, height: boxH)
        drawRoundedRect(ctx, rect: leftRect, radius: 8, fill: .white, stroke: cCardBorder, lineWidth: 0.75)
        drawText(ctx, "SEANS PERFORMANS DAĞILIMI", rect: CGRect(x: leftRect.minX + 12, y: leftRect.maxY - 20, width: halfW - 24, height: 12), font: .monospacedSystemFont(ofSize: 7.8, weight: .bold), color: cInk)

        if sessions.isEmpty {
            drawText(ctx, "Seans verisi bulunamadı.", rect: CGRect(x: leftRect.minX + 12, y: leftRect.midY - 8, width: halfW - 24, height: 14), font: .systemFont(ofSize: 8.5), color: cMuted)
        } else {
            for (idx, s) in sessions.prefix(5).enumerated() {
                let rowY = leftRect.maxY - 42 - CGFloat(idx) * 21
                if idx.isMultiple(of: 2) {
                    ctx.saveGState()
                    ctx.setFillColor(cRowAlt.cgColor)
                    ctx.fill(CGRect(x: leftRect.minX + 6, y: rowY - 2, width: halfW - 12, height: 18))
                    ctx.restoreGState()
                }
                drawText(ctx, L10n.text(s.name), rect: CGRect(x: leftRect.minX + 12, y: rowY, width: 92, height: 14), font: .systemFont(ofSize: 8.2, weight: .semibold), color: cInk)
                drawText(ctx, "n=\(s.performance.count) · \(Format.percent(s.performance.winRate))", rect: CGRect(x: leftRect.minX + 104, y: rowY, width: 72, height: 14), font: .monospacedSystemFont(ofSize: 7.4, weight: .regular), color: cMuted)
                drawText(ctx, Format.money(s.performance.netPnL, currency: currency), rect: CGRect(x: leftRect.maxX - 78, y: rowY, width: 66, height: 14), font: .monospacedSystemFont(ofSize: 8.0, weight: .bold), color: s.performance.netPnL >= 0 ? cMint : cRed, alignment: .right)
            }
        }

        // Right: Rule Violation / Process Audit
        let rightRect = CGRect(x: marginX + halfW + gap, y: boxY, width: halfW, height: boxH)
        drawRoundedRect(ctx, rect: rightRect, radius: 8, fill: .white, stroke: cCardBorder, lineWidth: 0.75)
        drawText(ctx, "SÜREÇ DENETİMİ (KURAL İHLAL MALİYETİ)", rect: CGRect(x: rightRect.minX + 12, y: rightRect.maxY - 20, width: halfW - 24, height: 12), font: .monospacedSystemFont(ofSize: 7.8, weight: .bold), color: cAmber)

        if mistakes.isEmpty {
            drawText(ctx, "Kural ihlali kaydedilmedi — tam plan disiplini korundu.", rect: CGRect(x: rightRect.minX + 12, y: rightRect.midY - 8, width: halfW - 24, height: 24), font: .systemFont(ofSize: 8.5, weight: .medium), color: cMint)
        } else {
            for (idx, m) in mistakes.prefix(5).enumerated() {
                let rowY = rightRect.maxY - 42 - CGFloat(idx) * 21
                if idx.isMultiple(of: 2) {
                    ctx.saveGState()
                    ctx.setFillColor(cRowAlt.cgColor)
                    ctx.fill(CGRect(x: rightRect.minX + 6, y: rowY - 2, width: halfW - 12, height: 18))
                    ctx.restoreGState()
                }
                drawText(ctx, L10n.text(m.name), rect: CGRect(x: rightRect.minX + 12, y: rowY, width: 120, height: 14), font: .systemFont(ofSize: 8.0, weight: .semibold), color: cInk)
                drawText(ctx, "\(m.performance.count)x · \(Format.r(m.performance.totalR))", rect: CGRect(x: rightRect.minX + 132, y: rowY, width: 54, height: 14), font: .monospacedSystemFont(ofSize: 7.4, weight: .medium), color: cAmber)
                drawText(ctx, Format.money(m.performance.netPnL, currency: currency), rect: CGRect(x: rightRect.maxX - 70, y: rowY, width: 58, height: 14), font: .monospacedSystemFont(ofSize: 7.8, weight: .bold), color: m.performance.netPnL >= 0 ? cAmber : cRed, alignment: .right)
            }
        }

        return boxY
    }

    private static func drawNotableTradesSection(_ ctx: CGContext, topY: CGFloat, trades: [TradeRecord], request: ReportRequest) -> CGFloat {
        let minBottomY: CGFloat = 54
        let availableH = topY - minBottomY
        guard availableH >= 80 else { return topY }

        drawText(
            ctx,
            "DÖNEM İŞLEM ÖZETİ (SON İŞLEMLER · TOPLAM \(trades.count))",
            rect: CGRect(x: marginX, y: topY - 15, width: contentWidth, height: 14),
            font: .monospacedSystemFont(ofSize: 8.2, weight: .bold),
            color: cInk
        )

        let rowH: CGFloat = 19
        let maxRows = max(1, min(14, Int((availableH - 26) / rowH) - 1))
        let displayTrades = Array(trades.reversed().prefix(maxRows))
        let tableH = CGFloat(displayTrades.count + 1) * rowH
        let tableRect = CGRect(x: marginX, y: topY - 22 - tableH, width: contentWidth, height: tableH)
        drawRoundedRect(ctx, rect: tableRect, radius: 7, fill: .white, stroke: cCardBorder, lineWidth: 0.75)

        let headerRect = CGRect(x: tableRect.minX, y: tableRect.maxY - rowH, width: tableRect.width, height: rowH)
        drawRoundedRect(ctx, rect: headerRect, radius: 0, fill: cCardBg, stroke: nil)

        let cols: [(String, CGFloat, CGFloat, NSTextAlignment)] = [
            ("TARİH", 10, 74, .left),
            ("PARİTE", 86, 56, .left),
            ("YÖN", 144, 38, .left),
            ("SEANS", 184, 58, .left),
            ("KURULUM", 244, 108, .left),
            ("R", 354, 44, .right),
            ("NET K/Z", 400, 68, .right),
            ("NOT", 472, 38, .right)
        ]
        for col in cols {
            drawText(ctx, col.0, rect: CGRect(x: tableRect.minX + col.1, y: headerRect.minY + 4, width: col.2, height: 11), font: .monospacedSystemFont(ofSize: 6.9, weight: .bold), color: cMuted, alignment: col.3)
        }

        for (idx, t) in displayTrades.enumerated() {
            let rowY = tableRect.maxY - CGFloat(idx + 2) * rowH
            if idx.isMultiple(of: 2) {
                ctx.saveGState()
                ctx.setFillColor(cRowAlt.cgColor)
                ctx.fill(CGRect(x: tableRect.minX + 0.5, y: rowY, width: tableRect.width - 1, height: rowH))
                ctx.restoreGState()
            }
            let dateStr = Format.date(t.date, calendar: request.calendar)
            drawText(ctx, dateStr, rect: CGRect(x: tableRect.minX + 10, y: rowY + 3.5, width: 74, height: 12), font: .monospacedSystemFont(ofSize: 7.2, weight: .regular), color: cMuted)
            drawText(ctx, t.instrument, rect: CGRect(x: tableRect.minX + 86, y: rowY + 3.5, width: 56, height: 12), font: .systemFont(ofSize: 7.8, weight: .bold), color: cInk)
            drawText(ctx, t.direction, rect: CGRect(x: tableRect.minX + 144, y: rowY + 3.5, width: 38, height: 12), font: .monospacedSystemFont(ofSize: 7.2, weight: .semibold), color: t.direction == "Long" ? cMint : cRed)
            drawText(ctx, L10n.text(t.session), rect: CGRect(x: tableRect.minX + 184, y: rowY + 3.5, width: 58, height: 12), font: .systemFont(ofSize: 7.4), color: cMuted)
            drawText(ctx, t.setupName, rect: CGRect(x: tableRect.minX + 244, y: rowY + 3.5, width: 108, height: 12), font: .systemFont(ofSize: 7.6), color: cInk)
            drawText(ctx, Format.r(t.rMultiple), rect: CGRect(x: tableRect.minX + 354, y: rowY + 3.5, width: 44, height: 12), font: .monospacedSystemFont(ofSize: 7.6, weight: .semibold), color: (t.rMultiple ?? 0) >= 0 ? cMint : cRed, alignment: .right)
            drawText(ctx, Format.money(t.netPnL, currency: request.currency), rect: CGRect(x: tableRect.minX + 400, y: rowY + 3.5, width: 68, height: 12), font: .monospacedSystemFont(ofSize: 7.6, weight: .bold), color: t.netPnL >= 0 ? cMint : cRed, alignment: .right)
            drawText(ctx, t.compliant ? (t.grade.isEmpty ? "✓" : t.grade) : "İHLAL", rect: CGRect(x: tableRect.minX + 472, y: rowY + 3.5, width: 38, height: 12), font: .monospacedSystemFont(ofSize: 7.2, weight: .bold), color: t.compliant ? cMint : cAmber, alignment: .right)
        }

        return tableRect.minY
    }

    private static func drawFooter(_ ctx: CGContext, pageNumber: Int, totalPages: Int, request: ReportRequest) {
        ctx.saveGState()
        ctx.setStrokeColor(cCardBorder.cgColor)
        ctx.setLineWidth(0.6)
        ctx.move(to: CGPoint(x: marginX, y: 36))
        ctx.addLine(to: CGPoint(x: pageWidth - marginX, y: 36))
        ctx.strokePath()
        ctx.restoreGState()

        drawText(
            ctx,
            "LIQUIDITY EDGE · %100 Yerel Cihaz İçi PDFKit & AI Raporu · Gizli Kişisel İşlem Kaydı",
            rect: CGRect(x: marginX, y: 18, width: contentWidth - 90, height: 12),
            font: .systemFont(ofSize: 7.5),
            color: cMuted
        )
        drawText(
            ctx,
            "Sayfa \(pageNumber) / \(totalPages)",
            rect: CGRect(x: pageWidth - marginX - 80, y: 18, width: 80, height: 12),
            font: .monospacedSystemFont(ofSize: 7.5, weight: .semibold),
            color: cMuted,
            alignment: .right
        )
    }

    // MARK: - Low-Level CoreGraphics + NSAttributedString Primitives

    private static func drawRoundedRect(_ ctx: CGContext, rect: CGRect, radius: CGFloat, fill: NSColor?, stroke: NSColor?, lineWidth: CGFloat = 1.0) {
        ctx.saveGState()
        let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        if let fill {
            ctx.addPath(path)
            ctx.setFillColor(fill.cgColor)
            ctx.fillPath()
        }
        if let stroke {
            ctx.addPath(path)
            ctx.setStrokeColor(stroke.cgColor)
            ctx.setLineWidth(lineWidth)
            ctx.strokePath()
        }
        ctx.restoreGState()
    }

    private static func drawText(_ ctx: CGContext, _ string: String, rect: CGRect, font: NSFont, color: NSColor, alignment: NSTextAlignment = .left) {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.lineBreakMode = .byWordWrapping
        style.lineSpacing = 1.6
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: style
        ]
        let attrStr = NSAttributedString(string: string, attributes: attrs)
        ctx.saveGState()
        NSGraphicsContext.saveGraphicsState()
        let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.current = nsCtx
        attrStr.draw(with: rect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])
        NSGraphicsContext.restoreGraphicsState()
        ctx.restoreGState()
    }

    private static func compactMoney(_ value: Double, currency: String) -> String {
        let sign = value < 0 ? "-" : ""
        let absVal = abs(value)
        let sym = currency == "USD" ? "$" : currency == "EUR" ? "€" : currency == "GBP" ? "£" : "\(currency) "
        if absVal >= 1000 {
            return String(format: "%@%@%.1fk", sign, sym, absVal / 1000.0)
        }
        return String(format: "%@%@%.0f", sign, sym, absVal)
    }
}
