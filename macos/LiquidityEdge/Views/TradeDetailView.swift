import SwiftUI
import AppKit

struct TradeDetailView: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var tradeID: UUID
    var edit: (TradeRecord) -> Void
    @State private var deleting = false
    @State private var selectedImage: ScreenshotDraft?
    @State private var showSupplementEditor = false
    private var trade: TradeRecord? { store.trades.first { $0.id == tradeID } }
    private var supplement: TradeSupplement? { store.workspace.supplements[tradeID] }
    var body: some View {
        VStack(spacing: 0) {
            if let t = trade {
                HStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass").font(.system(size: 18, weight: .medium)).foregroundStyle(Palette.blue)
                        .frame(width: 42, height: 42).background(Palette.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    Text(L10n.text("EXECUTION REVIEW")).font(.system(size: 11, weight: .semibold)).tracking(1.4).foregroundStyle(Palette.muted)
                    Spacer(minLength: 8)
                    Button(role: .destructive) { deleting = true } label: { Label(L10n.text("Delete"), systemImage: "trash") }
                        .buttonStyle(.plain).font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.red).padding(.horizontal, 12).padding(.vertical, 10)
                        .background(Palette.red.opacity(0.07), in: RoundedRectangle(cornerRadius: 9))
                    Button { showSupplementEditor = true } label: { Label("Fills & Checklist", systemImage: "list.bullet.clipboard") }.buttonStyle(EdgeButtonStyle(prominent: false))
                    Button { edit(t) } label: { Label(L10n.text("Edit trade"), systemImage: "pencil") }.buttonStyle(EdgeButtonStyle(prominent: false))
                    Button(L10n.text("Done")) { dismiss() }.buttonStyle(EdgeButtonStyle()).keyboardShortcut(.cancelAction)
                }.padding(.horizontal, 24).padding(.vertical, 18).background(Palette.panel)
                Rectangle().fill(Palette.muted.opacity(0.12)).frame(height: 1)
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        HStack(alignment: .top, spacing: 24) {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 10) {
                                    Text(verbatim: t.instrument).font(.system(size: 40, weight: .semibold, design: .rounded)).tracking(-1.5)
                                    let isLong = t.direction == "Long"
                                    let dirColor = isLong ? Palette.mint : Palette.red
                                    Text(verbatim: t.direction.uppercased())
                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(dirColor)
                                        .padding(.horizontal, 9).padding(.vertical, 5)
                                        .background(dirColor.opacity(0.11), in: Capsule())
                                        .overlay(Capsule().strokeBorder(dirColor.opacity(0.24)))
                                    if !t.grade.isEmpty {
                                        Badge(text: t.grade, color: t.grade == "A+" ? Palette.mint : Palette.blue)
                                    }
                                    if t.qt.enabled {
                                        let qtLabel = [t.qt.profile, t.qt.dailyQuarter].filter { !$0.isEmpty }.joined(separator: " · ")
                                        Text(verbatim: qtLabel.isEmpty ? "QT" : qtLabel)
                                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(Palette.blue)
                                            .padding(.horizontal, 9).padding(.vertical, 5)
                                            .background(Palette.blue.opacity(0.11), in: Capsule())
                                            .overlay(Capsule().strokeBorder(Palette.blue.opacity(0.22)))
                                    }
                                }
                                Text(t.setupID == nil ? L10n.text(t.setupName) : t.setupName).font(.system(size: 15, weight: .medium)).foregroundStyle(Palette.muted)
                                HStack(spacing: 8) {
                                    Image(systemName: "calendar")
                                    Text(Format.date(t.date, calendar: store.preferences.calendar, time: true))
                                    if !t.session.isEmpty { Text("· " + L10n.text(t.session)) }
                                    if !t.bias.isEmpty {
                                        let relText = t.biasRelation.isEmpty ? "" : " (\(t.biasRelation))"
                                        Text("· \(t.bias)\(relText)")
                                            .foregroundStyle(t.bias == "Bullish" ? Palette.mint : t.bias == "Bearish" ? Palette.red : Palette.muted)
                                    }
                                }.font(.system(size: 11)).foregroundStyle(Palette.muted)
                            }
                            Spacer(minLength: 0)
                            VStack(alignment: .trailing, spacing: 8) {
                                Text(L10n.text("Net PnL")).font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(1).foregroundStyle(Palette.muted)
                                Text(Format.money(t.netPnL, currency: store.currency(for: t.id))).font(.system(size: 34, weight: .semibold, design: .rounded)).tracking(-1).monospacedDigit().foregroundStyle(Palette.outcome(t.netPnL)).lineLimit(1).minimumScaleFactor(0.7)
                                Text(Format.r(t.rMultiple)).font(.system(size: 19, weight: .medium, design: .rounded)).monospacedDigit().foregroundStyle(Palette.outcome(t.rMultiple ?? 0))
                            }.padding(.top, 4)
                        }
                        .padding(22)
                        .background(
                            ZStack(alignment: .topTrailing) {
                                RoundedRectangle(cornerRadius: 16).fill(Palette.panel)
                                RadialGradient(colors: [Palette.outcome(t.netPnL).opacity(0.08), .clear], center: .topTrailing, startRadius: 4, endRadius: 280)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                        )
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Palette.line.opacity(0.85), lineWidth: 1))
                        .overlay(alignment: .top) {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(LinearGradient(colors: [Palette.outcome(t.netPnL).opacity(0.38), .clear], startPoint: .trailing, endPoint: .leading))
                                .frame(height: 1.5).padding(.horizontal, 18)
                        }
                        Panel {
                            HStack(spacing: 12) {
                                Image(systemName: t.compliant ? "checkmark.shield" : "exclamationmark.shield").font(.system(size: 22, weight: .light)).foregroundStyle(Palette.classification(t.classification))
                                Badge(text: t.classification.rawValue, color: Palette.classification(t.classification))
                                Text(L10n.text(t.classification.message)).font(.system(size: 12)).foregroundStyle(Palette.muted)
                                Spacer(minLength: 0)
                            }
                            if !t.compliant { Text(t.brokenRules.map(L10n.text).joined(separator: " · ")).font(.caption).foregroundStyle(Palette.amber) }
                        }
                        Panel(title: "EXECUTION SEQUENCE") {
                            ScrollView(.horizontal) {
                                HStack(spacing: 0) {
                                    node("HTF BIAS", t.bias.isEmpty ? "None" : t.bias, t.htfAligned)
                                    node("LIQUIDITY", t.liquidityTaken.first ?? "None", t.sweepValid)
                                    let qtNode = [t.qt.profile, t.qt.dailyQuarter].filter { !$0.isEmpty }.joined(separator: " ")
                                    node("QT CYCLE", t.qt.enabled ? (qtNode.isEmpty ? "QT" : qtNode) : "Off", t.hasQT)
                                    node("SSMT", t.ssmt.confirmation, t.hasSSMT)
                                    node("CRT", t.crt.enabled ? (t.crt.timeframe.isEmpty ? "On" : t.crt.timeframe) : "Off", t.hasCRT)
                                    node("CISD", t.entryTimeframe.isEmpty ? "—" : t.entryTimeframe, t.confirmations.contains("CISD"))
                                    node("ENTRY", t.direction, t.compliant)
                                    node("TARGET", t.drawOnLiquidity.isEmpty ? "None" : t.drawOnLiquidity, !t.brokenRules.contains("Ignored target"), last: true)
                                }.padding(.vertical, 4)
                            }
                            Text(L10n.text("Green: confirmed · Amber: absent or unconfirmed · Red: broken execution. These are your recorded observations.")).font(.system(size: 10)).foregroundStyle(Palette.muted)
                        }
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4), spacing: 14) { MetricCard(title: "Overall process", value: "\(Format.number(t.scores.overall, digits: 0))/100"); MetricCard(title: "Risk", value: t.riskDollars.map { Format.money($0, currency: store.currency(for: t.id)) } ?? "—"); MetricCard(title: "Planned RR", value: t.plannedRR.map { Format.number($0) } ?? "—"); MetricCard(title: "Duration", value: t.duration.map { "\(Int($0 / 60)) min" } ?? "—") }
                        Panel(title: "THESIS & LESSON") {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 310), spacing: 16)], alignment: .leading, spacing: 16) {
                                readNote("Trade thesis", t.notes.thesis); readNote("Key lesson", t.notes.lesson)
                            }
                        }
                        Panel(title: "VISUAL REVIEW") {
                            let shots = store.model(t.id)?.screenshots ?? []
                            if shots.isEmpty { Text(L10n.text("No screenshots attached. Use Edit trade to add images.")).font(.caption).foregroundStyle(Palette.muted) }
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250))], spacing: 14) {
                                ForEach(shots, id: \.id) { shot in
                                    Button { do { selectedImage = try ScreenshotDraft(shot) } catch { store.report(error) } } label: {
                                        VStack(alignment: .leading, spacing: 12) {
                                            ScreenshotThumbnail(data: shot.thumbnailData, cacheKey: "thumb-\(shot.id.uuidString)").frame(height: 170).clipShape(RoundedRectangle(cornerRadius: 11))
                                            HStack { Badge(text: shot.category); Spacer(); Image(systemName: "arrow.up.left.and.arrow.down.right").font(.system(size: 11)).foregroundStyle(Palette.muted) }
                                            Text(verbatim: shot.name).font(.system(size: 10)).foregroundStyle(Palette.muted).lineLimit(1)
                                        }.padding(11).background(Palette.raised.opacity(0.4), in: RoundedRectangle(cornerRadius: 13))
                                    }.buttonStyle(.plain).help(shot.name).accessibilityHint("Görsel incelemesini aç")
                                }
                            }
                        }
                        Panel(title: "CONTEXT & EXECUTION") {
                            detailRow("Prices", "Giriş \(numeric(t.entryPrice)) · Stop \(numeric(t.stopLoss)) · Kâr al \(numeric(t.takeProfit)) · Çıkış \(numeric(t.exitPrice))")
                            detailRow("Size / fees", "\(numeric(t.positionSize)) · \(Format.money(t.fees, currency: store.currency(for: t.id))) masraf")
                            let biasParts = [t.bias, t.biasRelation, t.newsDriver.isEmpty ? "" : "News: \(t.newsDriver)"].filter { !$0.isEmpty }
                            detailRow("HTF Bias & İlişki", biasParts.joined(separator: " · "))
                            if !t.narrative.isEmpty { detailRow("Narrative", t.narrative) }
                            detailRow("Context timeframes", t.contextTimeframes.joined(separator: ", "))
                            detailRow("Draw on Liquidity", t.drawOnLiquidity)
                            detailRow("Liquidity taken", t.liquidityTaken.joined(separator: ", "))
                            let qtParts = [
                                t.qt.profile,
                                t.qt.higherQuarter.isEmpty ? "" : "HTF \(t.qt.higherQuarter)",
                                t.qt.dailyQuarter.isEmpty ? "" : "Daily \(t.qt.dailyQuarter)",
                                t.qt.cycle90.isEmpty ? "" : "90m \(t.qt.cycle90)",
                                t.qt.cycle22.isEmpty ? "" : "22.5m \(t.qt.cycle22)",
                                t.qt.phase,
                                [t.qt.trueOpenAnchor, t.qt.trueOpenLocation.isEmpty ? "" : "(\(t.qt.trueOpenLocation))"].filter { !$0.isEmpty }.joined(separator: " ")
                            ].filter { !$0.isEmpty }
                            detailRow("QT", t.qt.enabled ? (qtParts.isEmpty ? "Enabled" : qtParts.joined(separator: " · ")) : "Off")
                            detailRow("MMXM", t.mmxm.model == "None" ? "None" : t.mmxm.model + (t.mmxm.valid ? " · Valid" : " · Unconfirmed"))
                            let po3Parts = [t.po3.phase, t.po3.manipulationDirection.isEmpty ? "" : "Manipulation \(t.po3.manipulationDirection)", t.po3.valid ? "Valid" : ""].filter { !$0.isEmpty }
                            detailRow("PO3", po3Parts.joined(separator: " · "))
                            let ssmtParts = [t.ssmt.confirmation == "Yes" ? t.ssmt.type : t.ssmt.confirmation, t.ssmt.markets.joined(separator: ", "), t.ssmt.confirmation == "Yes" ? (t.hasSSMT ? "Valid" : "Unconfirmed") : ""].filter { !$0.isEmpty }
                            detailRow("SSMT", ssmtParts.joined(separator: " · "))
                            detailRow("TSMO", t.tsmo == "Yes" ? (t.tsmo + (t.tsmoValid ? " · Valid" : " · Unconfirmed")) : t.tsmo)
                            let crtParts = [t.crt.timeframe, (t.crt.low != nil || t.crt.high != nil) ? "Range \(numeric(t.crt.low)) – \(numeric(t.crt.high))" : "", t.crt.liquidityTaken.isEmpty ? "" : "\(t.crt.liquidityTaken) Sweep"].filter { !$0.isEmpty }
                            detailRow("CRT", t.crt.enabled ? (crtParts.isEmpty ? "Enabled" : crtParts.joined(separator: " · ")) : "Off")
                            detailRow("Confirmations", t.confirmations.joined(separator: ", "))
                            detailRow("Tags", t.tags.joined(separator: ", "))
                        }
                        Panel(title: "EXECUTION SCORES") {
                            detailRow("Market / Entry / Rules", "\(Int(t.scores.marketRead)) / \(Int(t.scores.entry)) / \(Int(t.scores.compliance))")
                            detailRow("Risk / Management", "\(Int(t.scores.risk)) / \(Int(t.scores.management))")
                            detailRow("Psychology / Recognition", "\(Int(t.scores.psychology)) / \(Int(t.scores.recognition))")
                        }
                        Panel(title: "EMOTIONAL JOURNAL") {
                            detailRow("Before", "Güven \(Int(t.emotional.confidence)) · Stres \(Int(t.emotional.stress)) · FOMO \(Int(t.emotional.fomo)) · Odak \(Int(t.emotional.focus))")
                            detailRow("After", "Uygulamadan memnuniyet \(Int(t.emotional.satisfaction))/10 · Tekrar yaparım: \(t.emotional.takeAgain ? "Evet" : "Hayır")")
                            detailRow("Emotions", t.emotional.emotions.map(L10n.text).joined(separator: ", "))
                        }
                        if let supp = supplement, !supp.fills.isEmpty {
                            Panel(title: "EXECUTION LEDGER & FILLS", subtitle: "Gerçekleşen emirler, kademeli giriş/çıkış ve slippage analizi") {
                                VStack(alignment: .leading, spacing: 12) {
                                    if let res = try? WorkstationAnalytics.executions(supp, direction: t.direction) {
                                        HStack(spacing: 20) {
                                            TerminalMetric(title: "HESAPLANAN NET GERÇEKLEŞME", value: Format.money(res.realized, currency: store.accountCurrency), color: Palette.outcome(res.realized))
                                            TerminalMetric(title: "KALAN AÇIK POZİSYON", value: "\(res.openQuantity) kontrat")
                                            if let slip = res.slippageCost {
                                                TerminalMetric(title: "KAYMA MALİYETİ (SLIPPAGE)", value: Format.money(slip, currency: store.accountCurrency), color: slip > 0 ? Palette.red : Palette.mint)
                                            }
                                        }
                                        .padding(12)
                                        .background(Palette.raised.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
                                    }

                                    ForEach(supp.fills) { fill in
                                        HStack {
                                            Badge(text: fill.side.uppercased(), color: fill.side == "Entry" ? Palette.mint : Palette.blue)
                                            Text(Format.date(fill.date, calendar: store.preferences.calendar, time: true)).font(.caption)
                                            Spacer()
                                            Text("\(fill.quantity, specifier: "%.1f") kontrat @ \(fill.price, specifier: "%.2f")").font(.caption.monospacedDigit())
                                            if let exp = fill.expectedPrice {
                                                Text("Beklenen: \(exp, specifier: "%.2f")").font(.caption2).foregroundStyle(Palette.muted)
                                            }
                                            Text("Komisyon: \(Format.money(fill.fee, currency: store.accountCurrency))").font(.caption2).foregroundStyle(Palette.muted)
                                        }
                                        .padding(.vertical, 4)
                                        Divider()
                                    }

                                    Text("Önemli Not: Kaydedilmiş birincil Net P&L (\(Format.money(t.netPnL, currency: store.accountCurrency))) otoriterdir. Gerçekleşme defteri ikincil doğrulama ve detay inceleme amacıyla tutulur.")
                                        .font(.caption2)
                                        .foregroundStyle(Palette.muted)
                                }
                            }
                        }
                        if let supp = supplement, !supp.checklist.isEmpty {
                            Panel(title: "STRUCTURED CHECKLIST", subtitle: "İşlem öncesi ve sonrası kontrol listesi yanıtları") {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(supp.checklist) { item in
                                        HStack {
                                            Image(systemName: item.answer == true ? "checkmark.circle.fill" : item.answer == false ? "xmark.circle.fill" : "circle")
                                                .foregroundStyle(item.answer == true ? Palette.mint : item.answer == false ? Palette.red : Palette.muted)
                                            Text(item.label).font(.system(size: 12))
                                            Spacer()
                                            Badge(text: item.phase, color: item.phase == "Öncesi" ? Palette.blue : Palette.mint)
                                        }
                                        .padding(.vertical, 3)
                                        Divider()
                                    }
                                }
                            }
                        }
                        Panel(title: "REFLECTION") {
                            readNote("Why I entered", t.notes.entry); readNote("What confirmed the trade", t.notes.confirmation); readNote("What invalidated the setup", t.notes.invalidation); readNote("What I did correctly", t.notes.correct); readNote("What I did incorrectly", t.notes.incorrect); readNote("What I would do differently", t.notes.differently)
                        }
                    }.padding(24)
                }
            }
        }.frame(width: sheetSize.width, height: sheetSize.height).background(Palette.canvas).foregroundStyle(Palette.ink).tint(Palette.mint)
        .confirmationDialog(L10n.text("Delete this trade and its screenshots?"), isPresented: $deleting) { Button(L10n.text("Delete trade"), role: .destructive) { do { try store.deleteTrade(tradeID); dismiss() } catch { store.report(error) } } } message: { Text(L10n.text("This action cannot be undone. A saved backup can restore the trade.")) }
        .sheet(item: $selectedImage) { shot in ScreenshotViewer(initial: shot) { changed in
            guard let t = trade else { return }; do { var all = try (store.model(t.id)?.screenshots ?? []).map(ScreenshotDraft.init); if let index = all.firstIndex(where: { $0.id == changed.id }) { all[index] = changed }; try store.save(t, screenshots: all) } catch { store.report(error) }
        } }
        .sheet(isPresented: $showSupplementEditor) {
            TradeSupplementEditor(tradeID: tradeID).environment(store)
        }
    }
    private var sheetSize: CGSize {
        let visible = (NSApp.keyWindow?.screen ?? NSScreen.main)?.visibleFrame.size ?? CGSize(width: 1200, height: 900)
        return CGSize(width: min(1040, max(720, visible.width - 96)), height: min(860, max(480, visible.height - 80)))
    }
    private func numeric(_ value: Double?) -> String { value.map { Format.number($0) } ?? "—" }
    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 20) {
            Text(L10n.text(title)).font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.muted).frame(width: 155, alignment: .leading)
            Text(verbatim: value.isEmpty ? L10n.text("Not recorded") : value).font(.system(size: 12)).lineSpacing(4).textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }.padding(.vertical, 2)
    }
    private func readNote(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.text(title)).font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.muted)
            Text(verbatim: text.isEmpty ? L10n.text("Not recorded") : text).font(.system(size: 13)).lineSpacing(5).textSelection(.enabled)
        }.padding(16).frame(maxWidth: .infinity, alignment: .topLeading)
            .background(Palette.raised.opacity(0.35), in: RoundedRectangle(cornerRadius: 11))
    }
    private func node(_ title: String, _ text: String, _ valid: Bool, last: Bool = false) -> some View {
        let color = valid ? Palette.mint : title == "ENTRY" ? Palette.red : Palette.amber
        return VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 0) {
                Circle()
                    .strokeBorder(color.opacity(valid ? 0.9 : 0.7), lineWidth: 1.5)
                    .background(Circle().fill(color.opacity(valid ? 0.16 : 0.08)))
                    .frame(width: 30, height: 30)
                    .overlay(Image(systemName: valid ? "checkmark" : "minus").font(.system(size: 10, weight: .bold)).foregroundStyle(color))
                    .shadow(color: valid ? color.opacity(0.28) : .clear, radius: 5, x: 0, y: 0)
                if !last {
                    Rectangle()
                        .fill(LinearGradient(colors: [color.opacity(valid ? 0.5 : 0.2), Palette.line.opacity(0.45)], startPoint: .leading, endPoint: .trailing))
                        .frame(height: 1.5)
                }
            }
            Text(verbatim: title).font(.system(size: 9, weight: .semibold, design: .monospaced)).tracking(0.6).foregroundStyle(Palette.ink.opacity(0.9))
            Text(verbatim: text).font(.system(size: 10, weight: .medium)).foregroundStyle(valid ? Palette.ink.opacity(0.8) : Palette.muted).lineLimit(2).frame(height: 28, alignment: .top)
        }.frame(width: 112, alignment: .leading)
    }
}

struct TradeSupplementEditor: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var tradeID: UUID

    @State private var supplement = TradeSupplement()
    @State private var newFill = ExecutionFill()
    @State private var newChecklistLabel = ""
    @State private var newChecklistPhase = "Öncesi"
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Gerçekleşmeler (Fills) & Kontrol Listesi").font(.title2.weight(.bold))
                Spacer()
                Button("İptal") { dismiss() }
                    .buttonStyle(EdgeButtonStyle(prominent: false, compact: true))
                    .keyboardShortcut(.cancelAction)
                Button("Kaydet") {
                    if save() { dismiss() }
                }
                .buttonStyle(EdgeButtonStyle(compact: true))
                .keyboardShortcut("s", modifiers: .command)
            }

            if let errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Palette.amber)
                    Text(errorMessage).font(.caption).foregroundStyle(Palette.amber)
                    Spacer()
                    Button("Kapat") { self.errorMessage = nil }.buttonStyle(.plain).font(.caption2)
                }
                .padding(10)
                .background(Palette.amber.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Puan / Kontrat Değeri (Point Value)").font(.caption).foregroundStyle(Palette.muted)
                    TextField("Point Value", value: $supplement.pointValue, format: .number)
                        .textFieldStyle(EdgeTextFieldStyle())
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tik Büyüklüğü (Tick Size)").font(.caption).foregroundStyle(Palette.muted)
                    TextField("Tick Size", value: $supplement.tickSize, format: .number)
                        .textFieldStyle(EdgeTextFieldStyle())
                }
            }

            Divider()

            Text("Emir Gerçekleşmeleri (Fills)").font(.headline)
            HStack(spacing: 8) {
                Picker("Yön", selection: $newFill.side) {
                    Text("Entry (Giriş)").tag("Entry")
                    Text("Exit (Çıkış)").tag("Exit")
                }
                .frame(width: 120)

                TextField("Miktar", value: $newFill.quantity, format: .number)
                    .textFieldStyle(EdgeTextFieldStyle())
                    .frame(width: 70)

                TextField("Fiyat", value: $newFill.price, format: .number)
                    .textFieldStyle(EdgeTextFieldStyle())
                    .frame(width: 90)

                TextField("Komisyon", value: $newFill.fee, format: .number)
                    .textFieldStyle(EdgeTextFieldStyle())
                    .frame(width: 80)

                TextField("Beklenen Fiyat", value: $newFill.expectedPrice, format: .number)
                    .textFieldStyle(EdgeTextFieldStyle())
                    .frame(width: 100)

                Button("Ekle") {
                    guard newFill.quantity.isFinite, newFill.quantity > 0, newFill.price.isFinite, newFill.price > 0, newFill.fee.isFinite, newFill.fee >= 0 else {
                        errorMessage = "Emir eklemek için pozitif miktar, pozitif fiyat ve negatif olmayan komisyon girin."
                        return
                    }
                    errorMessage = nil
                    supplement.fills.append(newFill)
                    newFill = ExecutionFill()
                }
                .buttonStyle(EdgeButtonStyle(prominent: false, compact: true))
            }

            List {
                ForEach(supplement.fills) { fill in
                    HStack {
                        Badge(text: fill.side, color: fill.side == "Entry" ? Palette.mint : Palette.blue)
                        Text("\(fill.quantity, specifier: "%.1f") adet @ \(fill.price, specifier: "%.2f")")
                        if let exp = fill.expectedPrice {
                            Text("(Beklenen: \(exp, specifier: "%.2f"))").foregroundStyle(Palette.muted).font(.caption)
                        }
                        Spacer()
                        Text("Masraf: \(fill.fee, specifier: "%.2f")").font(.caption)
                        Button {
                            supplement.fills.removeAll { $0.id == fill.id }
                        } label: {
                            Image(systemName: "trash").font(.caption).foregroundStyle(Palette.red)
                        }
                        .buttonStyle(.plain)
                        .help("Gerçekleşmeyi sil")
                    }
                }
                .onDelete { idx in
                    supplement.fills.remove(atOffsets: idx)
                }
            }
            .listStyle(.plain)
            .frame(height: 130)

            Divider()

            HStack {
                Text("Kontrol Listesi Yanıtları").font(.headline)
                Spacer()
                if !store.workspace.templates.isEmpty {
                    Menu {
                        ForEach(store.workspace.templates) { template in
                            Button(template.name) {
                                for item in template.items {
                                    if !supplement.checklist.contains(where: { $0.label == item.label && $0.phase == item.phase }) {
                                        supplement.checklist.append(ChecklistAnswer(label: item.label, phase: item.phase, answer: true))
                                    }
                                }
                            }
                        }
                    } label: {
                        Label("Şablondan Yükle", systemImage: "checklist")
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }
            HStack(spacing: 8) {
                TextField("Kontrol maddesi", text: $newChecklistLabel)
                    .textFieldStyle(EdgeTextFieldStyle())
                    .onSubmit { addChecklistItem() }

                Picker("Aşama", selection: $newChecklistPhase) {
                    Text("Öncesi").tag("Öncesi")
                    Text("Sonrası").tag("Sonrası")
                }
                .frame(width: 100)

                Button("Madde Ekle") { addChecklistItem() }
                    .buttonStyle(EdgeButtonStyle(prominent: false, compact: true))
                    .disabled(newChecklistLabel.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            List {
                ForEach($supplement.checklist) { $item in
                    HStack {
                        Toggle(isOn: Binding(
                            get: { item.answer ?? false },
                            set: { item.answer = $0 }
                        )) {
                            Text(item.label)
                        }
                        Spacer()
                        Badge(text: item.phase, color: item.phase == "Öncesi" ? Palette.blue : Palette.mint)
                        Button {
                            supplement.checklist.removeAll { $0.id == item.id }
                        } label: {
                            Image(systemName: "trash").font(.caption).foregroundStyle(Palette.red)
                        }
                        .buttonStyle(.plain)
                        .help("Maddeyi sil")
                    }
                }
                .onDelete { idx in
                    supplement.checklist.remove(atOffsets: idx)
                }
            }
            .listStyle(.plain)
            .frame(height: 130)
        }
        .padding(24)
        .frame(width: 700, height: 700)
        .background(Palette.canvas)
        .foregroundStyle(Palette.ink)
        .tint(Palette.mint)
        .onAppear {
            if let existing = store.workspace.supplements[tradeID] {
                supplement = existing
            }
        }
    }

    private func addChecklistItem() {
        let clean = newChecklistLabel.trimmingCharacters(in: .whitespaces)
        guard !clean.isEmpty else { return }
        supplement.checklist.append(ChecklistAnswer(label: clean, phase: newChecklistPhase, answer: true))
        newChecklistLabel = ""
    }

    private func save() -> Bool {
        do {
            try store.updateWorkspace { ws in
                ws.supplements[tradeID] = supplement
            }
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
