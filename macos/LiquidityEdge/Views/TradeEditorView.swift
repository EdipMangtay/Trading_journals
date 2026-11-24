import SwiftUI
import AppKit

struct TradeEditorView: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.edgeAnimationsEnabled) private var animationsEnabled

    @State private var draft: TradeDraft
    @State private var activeTab: EditorTab = .execution
    @State private var customRule = ""
    @State private var customMarket = ""
    @State private var tags = ""
    @State private var loaded = false
    @State private var quickSetup = ""
    @State private var showQuickSetup = false
    @State private var quickSetupNotice: String?
    @State private var showDetailedReflection = false

    private enum EditorTab: String, CaseIterable, Identifiable {
        case execution = "01 · İşlem & Risk"
        case narrativeQT = "02 · Narrative & QT"
        case models = "03 · Modeller & Teyit"
        case process = "04 · Süreç & Psikoloji"
        case mediaNotes = "05 · Görsel & Not"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .execution: return "bolt.circle"
            case .narrativeQT: return "square.grid.2x2"
            case .models: return "waveform.path"
            case .process: return "checkmark.shield"
            case .mediaNotes: return "photo.on.rectangle"
            }
        }
    }

    init(record: TradeRecord?, initialSection: Int = 0) {
        _draft = State(initialValue: TradeDraft(record: record))
        let tabs = EditorTab.allCases
        _activeTab = State(initialValue: tabs.indices.contains(initialSection) ? tabs[initialSection] : .execution)
    }

    private var animate: Bool { store.preferences.animations && animationsEnabled && !reduceMotion }

    private var activeAccount: TradingAccount {
        store.workspace.accounts.first { $0.id == draft.accountID } ?? store.selectedAccount
    }

    private var isCounterTrendMismatch: Bool {
        (draft.record.direction == "Long" && draft.record.bias == "Bearish") ||
        (draft.record.direction == "Short" && draft.record.bias == "Bullish")
    }

    var body: some View {
        @Bindable var draft = draft
        VStack(spacing: 0) {
            editorHeader
            liveSummaryRibbon
            tabNavigationBar
            Rectangle().fill(Palette.line.opacity(0.7)).frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch activeTab {
                    case .execution:
                        executionAndRiskTab
                    case .narrativeQT:
                        narrativeAndQTTab
                    case .models:
                        modelsAndConfirmationsTab
                    case .process:
                        processAndPsychologyTab
                    case .mediaNotes:
                        screenshotsAndNotesTab
                    }
                }
                .padding(24)
            }
            .id(activeTab)
            .transition(animate ? .opacity.combined(with: .offset(y: 4)) : .identity)
            .animation(animate ? .spring(response: 0.28, dampingFraction: 0.85) : nil, value: activeTab)

            if let error = draft.error {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.circle.fill").foregroundStyle(Palette.amber)
                    Text(L10n.text(error)).font(.system(size: 12)).textSelection(.enabled)
                    Spacer(minLength: 10)
                    Button("Kapat") { draft.error = nil }.buttonStyle(EdgeButtonStyle(prominent: false, compact: true))
                }
                .padding(.horizontal, 24).padding(.vertical, 12)
                .background(Palette.amber.opacity(0.1))
            }

            editorFooter
        }
        .frame(width: sheetSize.width, height: sheetSize.height)
        .background(Palette.canvas)
        .foregroundStyle(Palette.ink)
        .tint(Palette.mint)
        .onAppear {
            guard !loaded else { return }; loaded = true
            draft.loadAttachments(from: store)
            tags = draft.record.tags.joined(separator: ", ")
            if draft.isNew {
                draft.record.riskPercent = store.preferences.defaultRiskPercent
                draft.record.riskDollars = (activeAccount.startingBalance * store.preferences.defaultRiskPercent / 100 * 100).rounded() / 100
            }
        }
        .onChange(of: draft.record.direction) { _, _ in syncBiasRelationIfNeeded() }
        .onChange(of: draft.record.bias) { _, _ in syncBiasRelationIfNeeded() }
    }

    // MARK: - Header & Live Summary
    private var editorHeader: some View {
        HStack(spacing: 14) {
            Image(systemName: draft.isNew ? "square.and.pencil" : "slider.horizontal.3")
                .font(.system(size: 19, weight: .medium)).foregroundStyle(Palette.mint)
                .frame(width: 44, height: 44)
                .background(Palette.mint.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.mint.opacity(0.24)))
            VStack(alignment: .leading, spacing: 4) {
                Text(draft.isNew ? "Yeni İşlem Kaydet" : "İşlemi Düzenle")
                    .font(.system(size: 20, weight: .semibold)).tracking(-0.5)
                Text("İstediğin alanları tek tıkla seç veya tekrar tıklayıp kaldır — yalnızca işine yarayanları doldur.")
                    .font(.system(size: 11)).foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 12)
            Button("Vazgeç") { dismiss() }
                .buttonStyle(EdgeButtonStyle(prominent: false, compact: true))
                .keyboardShortcut(.cancelAction)
            Button { saveAndClose() } label: {
                Label("İşlemi Kaydet", systemImage: "checkmark")
            }
            .buttonStyle(EdgeButtonStyle())
            .keyboardShortcut("s", modifiers: .command)
        }
        .padding(.horizontal, 24).padding(.vertical, 16)
        .background(Palette.panel)
    }

    private var liveSummaryRibbon: some View {
        let t = draft.record
        return HStack(spacing: 14) {
            HStack(spacing: 6) {
                Text(verbatim: t.instrument.isEmpty ? "—" : t.instrument)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                Text(verbatim: t.direction.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(t.direction == "Long" ? Palette.mint : Palette.red)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background((t.direction == "Long" ? Palette.mint : Palette.red).opacity(0.14), in: Capsule())
                if !t.session.isEmpty {
                    Text(verbatim: t.session)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Palette.muted)
                }
            }

            ribbonDivider

            HStack(spacing: 6) {
                Text("Net:").font(.system(size: 10)).foregroundStyle(Palette.muted)
                Text(Format.money(t.netPnL, currency: activeAccount.currency))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(Palette.outcome(t.netPnL))
                Text(Format.r(t.rMultiple))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Palette.outcome(t.rMultiple ?? 0))
            }

            if let rr = t.plannedRR {
                ribbonDivider
                Text("Planned RR: 1:\(Format.number(rr, digits: 2))")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Palette.blue)
            }

            if !t.bias.isEmpty || !t.biasRelation.isEmpty {
                ribbonDivider
                HStack(spacing: 6) {
                    if !t.bias.isEmpty {
                        Text(verbatim: t.bias)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(t.bias == "Bullish" ? Palette.mint : t.bias == "Bearish" ? Palette.red : Palette.muted)
                    }
                    if !t.bias.isEmpty && !t.biasRelation.isEmpty {
                        Text("·").foregroundStyle(Palette.muted)
                    }
                    if !t.biasRelation.isEmpty {
                        Text(verbatim: t.biasRelation)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(t.biasRelation == "Counter-Trend" ? Palette.amber : Palette.blue)
                    }
                }
            }

            if t.qt.enabled {
                ribbonDivider
                let qtParts = [t.qt.profile, [t.qt.dailyQuarter, t.qt.cycle90].filter { !$0.isEmpty }.joined(separator: "/")].filter { !$0.isEmpty }.joined(separator: " · ")
                Text(verbatim: qtParts.isEmpty ? "QT" : "QT \(qtParts)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Palette.mint)
            }

            Spacer(minLength: 8)

            Badge(text: t.classification.rawValue, color: Palette.classification(t.classification))
        }
        .padding(.horizontal, 24).padding(.vertical, 10)
        .background(Palette.field.opacity(0.85))
        .overlay(alignment: .top) { Rectangle().fill(Palette.line.opacity(0.6)).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.line.opacity(0.6)).frame(height: 1) }
    }

    private var ribbonDivider: some View {
        Rectangle().fill(Palette.line.opacity(0.7)).frame(width: 1, height: 14)
    }

    private var tabNavigationBar: some View {
        HStack(spacing: 6) {
            ForEach(EditorTab.allCases) { tab in
                let isSelected = activeTab == tab
                let hasData = tabHasData(tab)
                Button {
                    activeTab = tab
                    if animate { EdgeHaptics.tick() }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? Palette.mint : Palette.muted)
                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                            .foregroundStyle(isSelected ? Palette.ink : Palette.muted)
                        if hasData {
                            Circle().fill(Palette.mint).frame(width: 5, height: 5)
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(isSelected ? Palette.raised : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(isSelected ? Palette.mint.opacity(0.35) : Color.clear, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 10)
        .background(Palette.panel.opacity(0.65))
    }

    private var editorFooter: some View {
        let tabs = EditorTab.allCases
        let idx = tabs.firstIndex(of: activeTab) ?? 0
        return HStack(spacing: 12) {
            Text("⌘S Kaydet · Esc İptal · İngilizce kavramlar analizlerle tam uyumlu saklanır.")
                .font(.system(size: 10))
                .foregroundStyle(Palette.muted)
            Spacer()
            if idx > 0 {
                Button {
                    activeTab = tabs[idx - 1]
                } label: {
                    Label("Önceki", systemImage: "chevron.left")
                }
                .buttonStyle(EdgeButtonStyle(prominent: false, compact: true))
            }
            if idx < tabs.count - 1 {
                Button {
                    activeTab = tabs[idx + 1]
                } label: {
                    HStack(spacing: 5) {
                        Text("Sonraki: \(tabs[idx + 1].rawValue.dropFirst(5))")
                        Image(systemName: "chevron.right")
                    }
                }
                .buttonStyle(EdgeButtonStyle(prominent: false, compact: true))
            } else {
                Button { saveAndClose() } label: {
                    Label("İşlemi Kaydet", systemImage: "checkmark")
                }
                .buttonStyle(EdgeButtonStyle(compact: true))
            }
        }
        .padding(.horizontal, 24).padding(.vertical, 12)
        .background(Palette.panel)
        .overlay(alignment: .top) { Rectangle().fill(Palette.line.opacity(0.7)).frame(height: 1) }
    }

    // MARK: - TAB 01: İşlem & Risk
    private var executionAndRiskTab: some View {
        @Bindable var draft = draft
        let enabledInstruments = Array(Set(store.instruments.filter(\.enabled).map(\.symbol))).sorted()
        let quickInstruments = enabledInstruments.isEmpty ? Catalog.instruments : enabledInstruments

        return VStack(alignment: .leading, spacing: 18) {
            Panel(title: "01 / TEMEL İŞLEM BİLGİLERİ", subtitle: "Parite, yön, seans, hesap ve kurulumu tek tıkla seç") {
                VStack(alignment: .leading, spacing: 18) {
                    // Instrument fast chips + custom text
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            promptLabel("Parite / Enstrüman seç veya yaz")
                            Spacer()
                            TextField("Özel sembol (örn: NQ)", text: $draft.record.instrument)
                                .textFieldStyle(EdgeTextFieldStyle(compact: true))
                                .frame(width: 150)
                        }
                        flowChips(options: quickInstruments, selection: $draft.record.instrument, allowDeselect: false)
                    }

                    HStack(alignment: .top, spacing: 18) {
                        // Direction 1-click colored buttons
                        VStack(alignment: .leading, spacing: 8) {
                            promptLabel("İşlem yönü (Direction)")
                            HStack(spacing: 8) {
                                directionPill("Long", icon: "arrow.up.right", color: Palette.mint)
                                directionPill("Short", icon: "arrow.down.right", color: Palette.red)
                            }
                        }
                        .frame(maxWidth: 230, alignment: .leading)

                        // Session 1-click chips (optional — click again to clear)
                        VStack(alignment: .leading, spacing: 8) {
                            promptLabel("Seans / Killzone (isteğe bağlı — tekrar tıkla kaldır)")
                            flowChips(options: store.preferences.sessions, selection: $draft.record.session, allowDeselect: true)
                        }
                    }

                    HStack(alignment: .top, spacing: 18) {
                        // Account selector
                        VStack(alignment: .leading, spacing: 7) {
                            promptLabel("Hangi hesapta alındı?")
                            Picker("Hesap", selection: Binding(
                                get: { draft.accountID ?? store.selectedAccount.id },
                                set: { id in
                                    draft.accountID = id
                                    if draft.isNew, let acc = store.workspace.accounts.first(where: { $0.id == id }) {
                                        draft.applyRiskPercent(from: acc.startingBalance)
                                    }
                                }
                            )) {
                                ForEach(store.workspace.accounts) { acc in
                                    Text("\(acc.name) (\(acc.currency))").tag(acc.id)
                                }
                            }
                            .labelsHidden().controlSize(.large).frame(maxWidth: .infinity).frame(minHeight: 36)
                        }

                        // Setup selector + always-available quick create trigger
                        VStack(alignment: .leading, spacing: 7) {
                            HStack {
                                promptLabel("Playbook / Setup seç")
                                Spacer()
                                Button {
                                    showQuickSetup.toggle()
                                    quickSetupNotice = nil
                                } label: {
                                    Label(showQuickSetup ? "Kapat" : "Yeni strateji", systemImage: showQuickSetup ? "xmark" : "plus")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(Palette.mint)
                                }
                                .buttonStyle(.plain)
                            }
                            Picker("Setup", selection: $draft.record.setupID) {
                                Text("Unassigned").tag(nil as UUID?)
                                ForEach(store.setups, id: \.id) { Text(verbatim: $0.name).tag(Optional($0.id)) }
                            }
                            .labelsHidden().controlSize(.large).frame(maxWidth: .infinity).frame(minHeight: 36)
                            .onChange(of: draft.record.setupID) { _, value in
                                draft.record.setupName = store.setups.first { $0.id == value }?.name ?? "Unassigned"
                            }
                        }

                        // Grade 1-click pills (toggleable — click again to clear)
                        VStack(alignment: .leading, spacing: 7) {
                            promptLabel("İşlem notu (Grade)")
                            HStack(spacing: 5) {
                                ForEach(["A+", "A", "B", "C", "D", "F"], id: \.self) { g in
                                    rawChip(g, selected: draft.record.grade == g, tint: (g == "A+" || g == "A") ? Palette.mint : g == "B" ? Palette.blue : Palette.amber) {
                                        draft.record.grade = draft.record.grade == g ? "" : g
                                    }
                                }
                            }
                        }
                    }

                    if store.setups.isEmpty || showQuickSetup {
                        HStack(alignment: .bottom, spacing: 10) {
                            VStack(alignment: .leading, spacing: 6) {
                                promptLabel(store.setups.isEmpty ? "Henüz strateji yok — hemen ilk strateji / Setup adını oluştur" : "Yeni strateji / Setup adı gir")
                                TextField("Örn: NY AM QT + SSMT CISD", text: $quickSetup)
                                    .textFieldStyle(EdgeTextFieldStyle())
                                    .onSubmit { createQuickSetup() }
                            }
                            Button("Strateji Oluştur") { createQuickSetup() }
                                .buttonStyle(EdgeButtonStyle(prominent: false))
                                .disabled(quickSetup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        .padding(12)
                        .background(Palette.field.opacity(0.55), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.mint.opacity(0.22)))
                    }
                    if let quickSetupNotice {
                        Label(quickSetupNotice, systemImage: "checkmark.circle.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Palette.mint)
                    }
                }
            }

            Panel(title: "02 / SONUÇ, RİSK & FİYATLAR", subtitle: "Hızlı R seçimi, otomatik Net PnL ve Planned RR hesaplayıcı") {
                VStack(alignment: .leading, spacing: 16) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 14)], spacing: 14) {
                        numberField("Gross PnL (\(activeAccount.currency))", value: $draft.record.grossPnL)
                        numberField("Fees / Komisyon", value: $draft.record.fees)
                        optionalNumberField("R Multiple", value: $draft.record.rMultiple)
                        optionalNumberField("Risk (\(activeAccount.currency))", value: $draft.record.riskDollars)
                        optionalNumberField("Risk %", value: $draft.record.riskPercent)
                        optionalNumberField("Position Size (Lot/Kontrat)", value: $draft.record.positionSize)
                    }

                    // Quick Risk % and Quick R buttons (toggleable)
                    HStack(spacing: 16) {
                        HStack(spacing: 6) {
                            Text("Hızlı Risk %:").font(.system(size: 10, weight: .medium)).foregroundStyle(Palette.muted)
                            ForEach([0.25, 0.5, 1.0, 2.0], id: \.self) { pct in
                                rawChip("\(Format.number(pct, digits: pct == 0.25 ? 2 : 1))%", selected: draft.record.riskPercent == pct, tint: Palette.blue) {
                                    if draft.record.riskPercent == pct {
                                        draft.record.riskPercent = nil
                                        draft.record.riskDollars = nil
                                    } else {
                                        draft.record.riskPercent = pct
                                        draft.applyRiskPercent(from: activeAccount.startingBalance)
                                    }
                                }
                            }
                        }
                        Spacer()
                        HStack(spacing: 6) {
                            Text("Hızlı R:").font(.system(size: 10, weight: .medium)).foregroundStyle(Palette.muted)
                            ForEach([-1.0, -0.5, 0.0, 1.0, 2.0, 3.0], id: \.self) { r in
                                let label = r == 0 ? "BE" : (r > 0 ? "+\(Int(r))R" : "\(Format.number(r, digits: r == -0.5 ? 1 : 0))R")
                                rawChip(label, selected: draft.record.rMultiple == r, tint: Palette.outcome(r)) {
                                    if draft.record.rMultiple == r {
                                        draft.record.rMultiple = nil
                                    } else {
                                        draft.applyRMultiple(r)
                                    }
                                }
                            }
                            Button("Net PnL → R") { draft.calculateR() }
                                .buttonStyle(EdgeButtonStyle(prominent: false, compact: true))
                        }
                    }

                    Rectangle().fill(Palette.line.opacity(0.6)).frame(height: 1)

                    // Prices & Times
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 14)], spacing: 14) {
                        optionalNumberField("Entry Price", value: $draft.record.entryPrice)
                        optionalNumberField("Stop Loss (SL)", value: $draft.record.stopLoss)
                        optionalNumberField("Take Profit (TP)", value: $draft.record.takeProfit)
                        optionalNumberField("Exit Price", value: $draft.record.exitPrice)
                    }

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 5) {
                            promptLabel("Giriş zamanı (Entry Time)")
                            DatePicker("", selection: $draft.record.date).datePickerStyle(.field).labelsHidden()
                        }
                        Toggle("Çıkış zamanı kaydet (Exit Time)", isOn: Binding(
                            get: { draft.record.exitDate != nil },
                            set: { draft.record.exitDate = $0 ? draft.record.date.addingTimeInterval(1800) : nil }
                        ))
                        .toggleStyle(.switch).font(.system(size: 11))

                        if draft.record.exitDate != nil {
                            DatePicker("", selection: Binding(
                                get: { draft.record.exitDate ?? draft.record.date },
                                set: { draft.record.exitDate = $0 }
                            )).datePickerStyle(.field).labelsHidden()

                            HStack(spacing: 4) {
                                ForEach([("5m", 300.0), ("15m", 900.0), ("30m", 1800.0), ("1H", 3600.0)], id: \.0) { label, sec in
                                    rawChip(label, selected: false, tint: Palette.muted) {
                                        draft.record.exitDate = draft.record.date.addingTimeInterval(sec)
                                    }
                                }
                            }
                        }
                        Spacer()
                    }
                }
            }

            Panel(title: "03 / PLAN UYUMU (PROCESS CHECK)", subtitle: "Sonuçtan önce disiplini kaydet") {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle("İşlem planıma %100 uydum (Follows Plan)", isOn: $draft.record.followsPlan)
                        .toggleStyle(.switch)
                        .font(.system(size: 12, weight: .medium))
                        .onChange(of: draft.record.followsPlan) { _, ok in
                            if ok { draft.record.brokenRules.removeAll() }
                        }

                    if !draft.record.followsPlan || !draft.record.brokenRules.isEmpty {
                        promptLabel("İhlal ettiğin kuralları işaretle (Broken Rules)")
                        rawMultiChips(options: Catalog.rules + store.customRules.map(\.name) + draft.record.brokenRules, selection: $draft.record.brokenRules, tint: Palette.amber)
                        HStack(spacing: 10) {
                            TextField("Özel kural ihlali ekle...", text: $customRule).textFieldStyle(EdgeTextFieldStyle(compact: true))
                            Button("Ekle") {
                                let v = customRule.trimmingCharacters(in: .whitespaces)
                                if !v.isEmpty && !draft.record.brokenRules.contains(v) {
                                    draft.record.brokenRules.append(v); customRule = ""
                                }
                            }.buttonStyle(EdgeButtonStyle(prominent: false, compact: true))
                        }
                    }
                }
            }
        }
    }

    // MARK: - TAB 02: Narrative & Quarterly Theory (QT)
    private var narrativeAndQTTab: some View {
        @Bindable var draft = draft
        return VStack(alignment: .leading, spacing: 18) {
            Panel(title: "NARRATIVE & HTF BIAS", subtitle: "Yüksek zaman dilimi yönü, bias ilişkisi ve likidite hikayesini gir") {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            promptLabel("HTF Bias yönü neydi?")
                            HStack(spacing: 6) {
                                rawChip("Bullish", selected: draft.record.bias == "Bullish", tint: Palette.mint) {
                                    draft.record.bias = draft.record.bias == "Bullish" ? "Neutral" : "Bullish"
                                }
                                rawChip("Bearish", selected: draft.record.bias == "Bearish", tint: Palette.red) {
                                    draft.record.bias = draft.record.bias == "Bearish" ? "Neutral" : "Bearish"
                                }
                                rawChip("Neutral", selected: draft.record.bias == "Neutral", tint: Palette.muted) {
                                    draft.record.bias = "Neutral"
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            promptLabel("İşlem HTF Bias yönünde mi, tersine mi?")
                            HStack(spacing: 6) {
                                ForEach(Catalog.biasRelations, id: \.self) { rel in
                                    let tint = rel == "Pro-Trend" ? Palette.mint : rel == "Counter-Trend" ? Palette.amber : Palette.blue
                                    rawChip(rel, selected: draft.record.biasRelation == rel, tint: tint) {
                                        draft.record.biasRelation = draft.record.biasRelation == rel ? "" : rel
                                    }
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            promptLabel("HTF Onayı")
                            Toggle("HTF Alignment var", isOn: $draft.record.htfAligned)
                                .toggleStyle(.switch).font(.system(size: 11))
                        }
                        Spacer()
                    }

                    if isCounterTrendMismatch {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Palette.amber)
                            Text("HTF Bias \(draft.record.bias) iken \(draft.record.direction) girdin (Counter-Trend / Reversal). Bunun bilinçli bir SMR veya Retracement Narrative'i olduğundan emin ol.")
                                .font(.system(size: 11)).foregroundStyle(Palette.amber)
                        }
                        .padding(11).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Palette.amber.opacity(0.09), in: RoundedRectangle(cornerRadius: 9))
                        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Palette.amber.opacity(0.25)))
                    }

                    // Narrative quick chips + text input
                    VStack(alignment: .leading, spacing: 8) {
                        promptLabel("Narrative / Likidite akışını seç veya kendi cümlenle gir")
                        flowChips(options: Catalog.narratives, selection: $draft.record.narrative, minWidth: 175)
                        TextField("Örn: London SSL sweep sonrası TDO altında Discount'tan NY AM Q3 ERL (PDH) hedefi...", text: $draft.record.narrative)
                            .textFieldStyle(EdgeTextFieldStyle())
                    }

                    // News Driver & Context Timeframes
                    HStack(alignment: .top, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            promptLabel("Ekonomik Takvim / Haber Durumu (News Driver)")
                            HStack(spacing: 6) {
                                ForEach(Catalog.newsDrivers, id: \.self) { driver in
                                    rawChip(driver, selected: draft.record.newsDriver == driver, tint: driver == "Clean" ? Palette.mint : Palette.amber) {
                                        draft.record.newsDriver = draft.record.newsDriver == driver ? "" : driver
                                    }
                                }
                            }
                        }
                        Spacer()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        promptLabel("Hangi Timeframe'lerden context okudun?")
                        rawMultiChips(options: Catalog.timeframes, selection: $draft.record.contextTimeframes, tint: Palette.blue)
                    }

                    Rectangle().fill(Palette.line.opacity(0.6)).frame(height: 1)

                    // Draw on Liquidity & Liquidity Swept
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            promptLabel("Hedef Likidite (DOL — Draw on Liquidity) neresi?")
                            Spacer()
                            TextField("Özel DOL (örn: PDH + 4H FVG)", text: $draft.record.drawOnLiquidity)
                                .textFieldStyle(EdgeTextFieldStyle(compact: true))
                                .frame(width: 240)
                        }
                        flowChips(options: Catalog.liquidity, selection: $draft.record.drawOnLiquidity)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            promptLabel("Alınan Likidite (Liquidity Sweep) hangisi?")
                            Spacer()
                            Toggle("Liquidity Sweep geçerli (Valid Sweep)", isOn: $draft.record.sweepValid)
                                .toggleStyle(.switch).font(.system(size: 11))
                        }
                        rawMultiChips(options: Catalog.sweeps, selection: $draft.record.liquidityTaken, tint: Palette.mint)
                    }
                }
            }

            // Quarterly Theory (QT) Dedicated Matrix
            Panel(title: "QUARTERLY THEORY (QT) · DAYE CYCLE MATRIX", subtitle: "AMDX / XAMD profili, çeyrek döngüler ve True Open konumunu gir") {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        Toggle("Bu işlemde Quarterly Theory (QT) kullanıldı", isOn: $draft.record.qt.enabled)
                            .toggleStyle(.switch).font(.system(size: 12, weight: .semibold))
                        Spacer()
                        // 1-click QT quick presets
                        Button("Hızlı: AMDX · Q2 Sweep → Q3") {
                            draft.record.qt.enabled = true
                            draft.record.qt.profile = "AMDX"
                            draft.record.qt.dailyQuarter = "Q3"
                            draft.record.qt.cycle90 = "Q3"
                            draft.record.qt.phase = "Distribution"
                            draft.record.qt.trueOpen = true
                            draft.record.qt.aligned = true
                            draft.record.qt.valid = true
                            if animate { EdgeHaptics.selection() }
                        }.buttonStyle(EdgeButtonStyle(prominent: false, compact: true))

                        Button("Hızlı: XAMD Reversal") {
                            draft.record.qt.enabled = true
                            draft.record.qt.profile = "XAMD"
                            draft.record.qt.dailyQuarter = "Q2"
                            draft.record.qt.cycle90 = "Q2"
                            draft.record.qt.phase = "Manipulation"
                            draft.record.qt.trueOpen = true
                            draft.record.qt.aligned = true
                            draft.record.qt.valid = true
                            if animate { EdgeHaptics.selection() }
                        }.buttonStyle(EdgeButtonStyle(prominent: false, compact: true))

                        if draft.record.qt.enabled {
                            Button("QT Kapat / Sıfırla") {
                                draft.record.qt = QTContext()
                                if animate { EdgeHaptics.tick() }
                            }.buttonStyle(EdgeButtonStyle(prominent: false, compact: true))
                        }
                    }

                    if draft.record.qt.enabled {
                        // Profile + Phase (toggleable)
                        HStack(alignment: .top, spacing: 24) {
                            VStack(alignment: .leading, spacing: 8) {
                                promptLabel("Cycle Profili (AMDX / XAMD)")
                                HStack(spacing: 6) {
                                    ForEach(Catalog.qtProfiles, id: \.self) { prof in
                                        rawChip(prof, selected: draft.record.qt.profile == prof, tint: Palette.mint) {
                                            draft.record.qt.profile = draft.record.qt.profile == prof ? "" : prof
                                        }
                                    }
                                }
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                promptLabel("QT Fazı (Delivery Phase)")
                                HStack(spacing: 6) {
                                    ForEach(["Accumulation", "Manipulation", "Distribution", "Continuation"], id: \.self) { ph in
                                        rawChip(ph, selected: draft.record.qt.phase == ph, tint: Palette.blue) {
                                            draft.record.qt.phase = draft.record.qt.phase == ph ? "" : ph
                                        }
                                    }
                                }
                            }
                            Spacer()
                        }

                        // 4-Level Fractal Quarter Matrix (HTF / Daily / 90m / 22.5m)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                            quarterSelector("HTF Quarter (Yearly / Monthly / Weekly)", selection: $draft.record.qt.higherQuarter, hints: ["Q1", "Q2", "Q3", "Q4"])
                            quarterSelector("Daily 6H Quarter", selection: $draft.record.qt.dailyQuarter, hints: ["Q1 · Asia", "Q2 · London", "Q3 · NY AM", "Q4 · NY PM"])
                            quarterSelector("90-Min Macro Cycle", selection: $draft.record.qt.cycle90, hints: ["Q1", "Q2", "Q3", "Q4"])
                            quarterSelector("22.5-Min Micro Cycle", selection: $draft.record.qt.cycle22, hints: ["Q1", "Q2", "Q3", "Q4"])
                        }

                        // True Open Anchor & Location (toggleable)
                        HStack(alignment: .top, spacing: 24) {
                            VStack(alignment: .leading, spacing: 8) {
                                promptLabel("True Open Referansı")
                                HStack(spacing: 6) {
                                    ForEach([("TDO", "TDO (00:00)"), ("TSO", "TSO (Session)"), ("T90O", "T90O (90m)"), ("TWO", "TWO (Weekly)")], id: \.0) { code, label in
                                        rawChip(label, selected: draft.record.qt.trueOpenAnchor == code, tint: Palette.blue) {
                                            draft.record.qt.trueOpenAnchor = draft.record.qt.trueOpenAnchor == code ? "" : code
                                        }
                                    }
                                }
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                promptLabel("Fiyat True Open'a göre neredeydi?")
                                HStack(spacing: 6) {
                                    ForEach(Catalog.trueOpenLocations, id: \.self) { loc in
                                        rawChip(loc, selected: draft.record.qt.trueOpenLocation == loc, tint: loc == "Discount" ? Palette.mint : loc == "Premium" ? Palette.red : Palette.amber) {
                                            draft.record.qt.trueOpenLocation = draft.record.qt.trueOpenLocation == loc ? "" : loc
                                        }
                                    }
                                }
                            }
                            Spacer()
                        }

                        // Validation switches
                        HStack(spacing: 22) {
                            Toggle("True Open saygı gördü", isOn: $draft.record.qt.trueOpen).toggleStyle(.switch)
                            Toggle("QT Bias uyumlu", isOn: $draft.record.qt.aligned).toggleStyle(.switch)
                            Toggle("QT Model geçerli (Valid QT)", isOn: $draft.record.qt.valid).toggleStyle(.switch)
                        }
                        .font(.system(size: 11, weight: .medium))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Palette.field.opacity(0.65), in: RoundedRectangle(cornerRadius: 10))
                    } else {
                        Text("QT döngülerini kaydetmek için yukarıdaki anahtarı veya hızlı AMDX/XAMD şablonlarından birini seç.")
                            .font(.caption).foregroundStyle(Palette.muted)
                    }
                }
            }
        }
    }

    // MARK: - TAB 03: Modeller & Giriş Teyitleri
    private var modelsAndConfirmationsTab: some View {
        @Bindable var draft = draft
        return VStack(alignment: .leading, spacing: 18) {
            Panel(title: "GİRİŞ MODELİ & TEYİTLER (ENTRY TRIGGERS)", subtitle: "Giriş zaman dilimini ve fiyat hareketi teyitlerini işaretle") {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        promptLabel("Giriş Timeframe'i (Execution TF — tekrar tıkla kaldır)")
                        HStack(spacing: 6) {
                            ForEach(["15M", "5M", "3M", "1M"], id: \.self) { tf in
                                rawChip(tf, selected: draft.record.entryTimeframe == tf, tint: Palette.mint) {
                                    draft.record.entryTimeframe = draft.record.entryTimeframe == tf ? "" : tf
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        promptLabel("Giriş teyitlerini seç (Confirmations)")
                        rawMultiChips(options: ["CISD", "MSS", "IFVG", "FVG", "OB", "Breaker", "Displacement", "SMT", "SSMT", "CRT", "PSP", "OTE", "Turtle Soup", "Liquidity Sweep", "True Open", "Premium / Discount", "Rejection"], selection: $draft.record.confirmations, tint: Palette.mint)
                    }
                }
            }

            Panel(title: "SSMT & TSMO TEYİTLERİ", subtitle: "Korelasyon kırılımı (Sequential SMT) ve zaman bazlı açılış teyidi") {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            promptLabel("SSMT var mı?")
                            HStack(spacing: 6) {
                                ForEach(["Yes", "No", "Not Required"], id: \.self) { val in
                                    rawChip(val, selected: draft.record.ssmt.confirmation == val, tint: val == "Yes" ? Palette.mint : Palette.muted) {
                                        let next = (draft.record.ssmt.confirmation == val && val != "Not Required") ? "Not Required" : val
                                        draft.record.ssmt.confirmation = next
                                        if next != "Yes" { draft.record.ssmt.valid = false }
                                    }
                                }
                            }
                        }
                        if draft.record.ssmt.confirmation == "Yes" {
                            VStack(alignment: .leading, spacing: 8) {
                                promptLabel("Geçerlilik")
                                Toggle("Valid SSMT", isOn: $draft.record.ssmt.valid).toggleStyle(.switch).font(.system(size: 11))
                            }
                        }
                        Spacer()
                        VStack(alignment: .leading, spacing: 8) {
                            promptLabel("TSMO teyidi var mı?")
                            HStack(spacing: 6) {
                                ForEach(["Yes", "No", "Not Required"], id: \.self) { val in
                                    rawChip(val, selected: draft.record.tsmo == val, tint: val == "Yes" ? Palette.mint : Palette.muted) {
                                        let next = (draft.record.tsmo == val && val != "Not Required") ? "Not Required" : val
                                        draft.record.tsmo = next
                                        if next != "Yes" { draft.record.tsmoValid = false }
                                    }
                                }
                                if draft.record.tsmo == "Yes" {
                                    Toggle("Valid", isOn: $draft.record.tsmoValid).toggleStyle(.switch).font(.system(size: 11)).padding(.leading, 6)
                                }
                            }
                        }
                    }

                    if draft.record.ssmt.confirmation == "Yes" {
                        VStack(alignment: .leading, spacing: 8) {
                            promptLabel("SSMT Tipi (Divergence Type)")
                            flowChips(options: ["Sequential SMT (SSMT)", "Wick SMT", "Body / Hidden SMT", "High divergence", "Low divergence", "Intermarket divergence", "Time-based divergence"], selection: $draft.record.ssmt.type, minWidth: 165)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            promptLabel("Korelasyon paritelerini seç (Correlated Markets)")
                            rawMultiChips(options: ["NQ", "ES", "YM", "DXY", "EURUSD", "GBPUSD", "XAUUSD", "XAGUSD"] + draft.record.ssmt.markets, selection: $draft.record.ssmt.markets, tint: Palette.blue)
                            HStack(spacing: 8) {
                                TextField("Başka parite ekle...", text: $customMarket).textFieldStyle(EdgeTextFieldStyle(compact: true)).frame(width: 200)
                                Button("Ekle") {
                                    let t = customMarket.trimmingCharacters(in: .whitespaces)
                                    if !t.isEmpty && !draft.record.ssmt.markets.contains(t) { draft.record.ssmt.markets.append(t); customMarket = "" }
                                }.buttonStyle(EdgeButtonStyle(prominent: false, compact: true))
                            }
                        }
                    }
                }
            }

            // MMXM
            Panel(title: "MMXM · MARKET MAKER MODEL", subtitle: "MMBM / MMSM aşamalarını işaretle") {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        promptLabel("Model tipi:")
                        rawChip("None", selected: draft.record.mmxm.model == "None", tint: Palette.muted) { draft.record.mmxm.model = "None" }
                        rawChip("MMBM (Buy Model)", selected: draft.record.mmxm.model == "Market Maker Buy Model", tint: Palette.mint) {
                            draft.record.mmxm.model = draft.record.mmxm.model == "Market Maker Buy Model" ? "None" : "Market Maker Buy Model"
                        }
                        rawChip("MMSM (Sell Model)", selected: draft.record.mmxm.model == "Market Maker Sell Model", tint: Palette.red) {
                            draft.record.mmxm.model = draft.record.mmxm.model == "Market Maker Sell Model" ? "None" : "Market Maker Sell Model"
                        }
                    }
                    if draft.record.mmxm.model != "None" {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], alignment: .leading, spacing: 10) {
                            togglePill("Original Consolidation", isOn: $draft.record.mmxm.consolidation)
                            togglePill("Manipulation", isOn: $draft.record.mmxm.manipulation)
                            togglePill("Displacement", isOn: $draft.record.mmxm.displacement)
                            togglePill("Repricing", isOn: $draft.record.mmxm.repricing)
                            togglePill("Smart Money Reversal (SMR)", isOn: $draft.record.mmxm.reversal)
                            togglePill("Opposing Liquidity Target", isOn: $draft.record.mmxm.target)
                            togglePill("MMXM Valid ✓", isOn: $draft.record.mmxm.valid, tint: Palette.mint)
                        }
                    }
                }
            }

            // PO3 & CRT side by side
            HStack(alignment: .top, spacing: 18) {
                Panel(title: "PO3 · POWER OF THREE") {
                    VStack(alignment: .leading, spacing: 12) {
                        promptLabel("PO3 Fazı (isteğe bağlı)")
                        HStack(spacing: 6) {
                            ForEach(["Accumulation", "Manipulation", "Distribution"], id: \.self) { ph in
                                rawChip(ph, selected: draft.record.po3.phase == ph, tint: Palette.blue) {
                                    draft.record.po3.phase = draft.record.po3.phase == ph ? "" : ph
                                }
                            }
                        }
                        promptLabel("Manipulation Yönü (Judas Swing)")
                        HStack(spacing: 6) {
                            rawChip("Up (High Sweep)", selected: draft.record.po3.manipulationDirection == "Up", tint: Palette.red) {
                                draft.record.po3.manipulationDirection = draft.record.po3.manipulationDirection == "Up" ? "" : "Up"
                            }
                            rawChip("Down (Low Sweep)", selected: draft.record.po3.manipulationDirection == "Down", tint: Palette.mint) {
                                draft.record.po3.manipulationDirection = draft.record.po3.manipulationDirection == "Down" ? "" : "Down"
                            }
                        }
                        Toggle("PO3 Valid", isOn: $draft.record.po3.valid).toggleStyle(.switch).font(.system(size: 11))
                    }
                }

                Panel(title: "CRT · CANDLE RANGE THEORY") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("CRT Setup kullanıldı", isOn: $draft.record.crt.enabled).toggleStyle(.switch).font(.system(size: 12, weight: .medium))
                        if draft.record.crt.enabled {
                            promptLabel("CRT Timeframe")
                            HStack(spacing: 5) {
                                ForEach(["Daily", "4H", "1H", "15M", "5M"], id: \.self) { tf in
                                    rawChip(tf, selected: draft.record.crt.timeframe == tf, tint: Palette.blue) {
                                        draft.record.crt.timeframe = draft.record.crt.timeframe == tf ? "" : tf
                                    }
                                }
                            }
                            HStack(spacing: 10) {
                                optionalNumberField("CRT High", value: $draft.record.crt.high)
                                optionalNumberField("CRT Low", value: $draft.record.crt.low)
                            }
                            HStack(spacing: 10) {
                                rawChip("High Sweep", selected: draft.record.crt.liquidityTaken == "High", tint: Palette.red) {
                                    draft.record.crt.liquidityTaken = draft.record.crt.liquidityTaken == "High" ? "" : "High"
                                }
                                rawChip("Low Sweep", selected: draft.record.crt.liquidityTaken == "Low", tint: Palette.mint) {
                                    draft.record.crt.liquidityTaken = draft.record.crt.liquidityTaken == "Low" ? "" : "Low"
                                }
                                Toggle("Re-entry", isOn: $draft.record.crt.reentry).toggleStyle(.switch).font(.system(size: 11))
                                Toggle("Confirmed", isOn: $draft.record.crt.confirmed).toggleStyle(.switch).font(.system(size: 11))
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - TAB 04: Süreç & Psikoloji
    private var processAndPsychologyTab: some View {
        @Bindable var draft = draft
        return VStack(alignment: .leading, spacing: 18) {
            Panel(title: "UYGULAMA KALİTESİ (EXECUTION GRADING)", subtitle: "Tek tıkla şablon puan ver veya detayları ayarla") {
                HStack(alignment: .top, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Text("Hızlı Puan:").font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.muted)
                            rawChip("Kusursuz (9)", selected: false, tint: Palette.mint) { applyUniformScore(9) }
                            rawChip("İyi (7)", selected: false, tint: Palette.blue) { applyUniformScore(7) }
                            rawChip("Orta (5)", selected: false, tint: Palette.amber) { applyUniformScore(5) }
                            rawChip("Zayıf (3)", selected: false, tint: Palette.red) { applyUniformScore(3) }
                        }
                        ScoreSlider(title: "Market Read", value: $draft.record.scores.marketRead)
                        ScoreSlider(title: "Entry Execution", value: $draft.record.scores.entry)
                        ScoreSlider(title: "Rule Compliance", value: $draft.record.scores.compliance)
                        ScoreSlider(title: "Risk Management", value: $draft.record.scores.risk)
                        ScoreSlider(title: "Trade Management", value: $draft.record.scores.management)
                        ScoreSlider(title: "Psychology", value: $draft.record.scores.psychology)
                        ScoreSlider(title: "Pattern Recognition", value: $draft.record.scores.recognition)
                    }
                    VStack(spacing: 10) {
                        Text("GENEL SKOR").font(EdgeType.eyebrow).tracking(1.2).foregroundStyle(Palette.muted)
                        ExecutionScoreRing(score: draft.record.scores.overall, size: 128, lineWidth: 9)
                    }
                    .frame(width: 160)
                    .padding(.top, 16)
                }
            }

            Panel(title: "PSİKOLOJİ & DUYGU DURUMU (EMOTIONAL JOURNAL)", subtitle: "İşlem öncesi ve sonrası zihinsel durumunu kaydet") {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 24) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("İŞLEM ÖNCESİ").font(EdgeType.eyebrow).tracking(1.2).foregroundStyle(Palette.muted)
                            ScoreSlider(title: "Confidence", value: $draft.record.emotional.confidence, lower: 1)
                            ScoreSlider(title: "Stress", value: $draft.record.emotional.stress, lower: 1)
                            ScoreSlider(title: "FOMO", value: $draft.record.emotional.fomo, lower: 1)
                            ScoreSlider(title: "Focus", value: $draft.record.emotional.focus, lower: 1)
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            Text("İŞLEM SONRASI").font(EdgeType.eyebrow).tracking(1.2).foregroundStyle(Palette.muted)
                            ScoreSlider(title: "Satisfaction", value: $draft.record.emotional.satisfaction, lower: 1)
                            Toggle("Aynı kurulum gelse tekrar alırdım", isOn: $draft.record.emotional.takeAgain)
                                .toggleStyle(.switch).font(.system(size: 12)).padding(.top, 6)
                        }
                    }
                    Rectangle().fill(Palette.line.opacity(0.6)).frame(height: 1)
                    promptLabel("İşlem sırasında hissettiğin duyguları seç")
                    rawMultiChips(options: Catalog.emotions, selection: $draft.record.emotional.emotions, tint: Palette.blue)
                }
            }
        }
    }

    // MARK: - TAB 05: Görseller & Notlar
    private var screenshotsAndNotesTab: some View {
        @Bindable var draft = draft
        return VStack(alignment: .leading, spacing: 18) {
            Panel(title: "EKRAN GÖRÜNTÜLERİ (CHART SCREENSHOTS)", subtitle: "HTF, Entry ve Post-Trade grafiklerini sürükle-bırak") {
                ScreenshotAttachmentEditor(shots: $draft.screenshots)
            }

            Panel(title: "İŞLEM TEZİ & ÇIKARILAN DERS", subtitle: "En kritik iki notu hızlıca yaz") {
                VStack(alignment: .leading, spacing: 16) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        NoteField(title: "İşlem tezi (Trade Thesis)", text: $draft.record.notes.thesis)
                        NoteField(title: "Çıkarılan kilit ders (Key Lesson)", text: $draft.record.notes.lesson)
                    }

                    DisclosureGroup("Detaylı değerlendirme sorularını aç (Neden girdim / Invalidation / Farklı ne yapardım?)", isExpanded: $showDetailedReflection) {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                            NoteField(title: "Neden girdim? (Why I entered)", text: $draft.record.notes.entry)
                            NoteField(title: "Girişi ne teyit etti? (Confirmation)", text: $draft.record.notes.confirmation)
                            NoteField(title: "Setup'ı ne bozardı? (Invalidation)", text: $draft.record.notes.invalidation)
                            NoteField(title: "Doğru yaptıklarım", text: $draft.record.notes.correct)
                            NoteField(title: "Yanlış yaptıklarım", text: $draft.record.notes.incorrect)
                            NoteField(title: "Bir dahaki sefere neyi farklı yaparım?", text: $draft.record.notes.differently)
                        }
                        .padding(.top, 12)
                    }
                    .font(.system(size: 12, weight: .medium))

                    VStack(alignment: .leading, spacing: 6) {
                        promptLabel("Etiketler (Virgülle ayır — örn: NYAM, Q3, SSMT, A+)")
                        TextField("Etiket ekle...", text: $tags).textFieldStyle(EdgeTextFieldStyle())
                    }
                }
            }
        }
    }

    // MARK: - Helpers & Components
    private func saveAndClose() {
        draft.record.tags = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if draft.save(into: store) {
            if animate { EdgeHaptics.selection() }
            dismiss()
        }
    }

    private func syncBiasRelationIfNeeded() {
        if draft.record.bias == "Neutral" { return }
        if isCounterTrendMismatch && draft.record.biasRelation == "Pro-Trend" {
            draft.record.biasRelation = "Counter-Trend"
        } else if !isCounterTrendMismatch && draft.record.biasRelation == "Counter-Trend" {
            draft.record.biasRelation = "Pro-Trend"
        }
    }

    private func applyUniformScore(_ score: Double) {
        draft.record.scores.marketRead = score
        draft.record.scores.entry = score
        draft.record.scores.compliance = score
        draft.record.scores.risk = score
        draft.record.scores.management = score
        draft.record.scores.psychology = score
        draft.record.scores.recognition = score
        if animate { EdgeHaptics.tick() }
    }

    private func tabHasData(_ tab: EditorTab) -> Bool {
        let t = draft.record
        switch tab {
        case .execution: return !t.instrument.isEmpty && (t.grossPnL != 0 || t.rMultiple != nil)
        case .narrativeQT: return t.qt.enabled || !t.narrative.isEmpty || !t.drawOnLiquidity.isEmpty || t.bias != "Neutral"
        case .models: return !t.confirmations.isEmpty || t.ssmt.confirmation == "Yes" || t.mmxm.model != "None" || t.crt.enabled || t.po3.valid
        case .process: return !t.emotional.emotions.isEmpty || t.scores.overall != 50
        case .mediaNotes: return !draft.screenshots.isEmpty || !t.notes.thesis.isEmpty || !t.notes.lesson.isEmpty
        }
    }

    private var sheetSize: CGSize {
        let visible = (NSApp.keyWindow?.screen ?? NSScreen.main)?.visibleFrame.size ?? CGSize(width: 1280, height: 900)
        return CGSize(width: min(1060, max(820, visible.width - 80)), height: min(880, max(560, visible.height - 70)))
    }

    private func promptLabel(_ text: String) -> some View {
        Text(text).font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.muted)
    }

    private func directionPill(_ value: String, icon: String, color: Color) -> some View {
        let selected = draft.record.direction == value
        return Button {
            draft.record.direction = value
            if animate { EdgeHaptics.tick() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 11, weight: .bold))
                Text(verbatim: value).font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(selected ? color : Palette.muted)
            .frame(maxWidth: .infinity, minHeight: 34)
            .background(selected ? color.opacity(0.15) : Palette.field, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(selected ? color.opacity(0.6) : Palette.line, lineWidth: selected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
    }

    private func quarterSelector(_ title: String, selection: Binding<String>, hints: [String]) -> some View {
        let quarters = ["Q1", "Q2", "Q3", "Q4"]
        return VStack(alignment: .leading, spacing: 8) {
            promptLabel(title)
            HStack(spacing: 6) {
                ForEach(0..<4, id: \.self) { i in
                    let q = quarters[i]
                    rawChip(hints[i], selected: selection.wrappedValue == q, tint: Palette.mint) {
                        selection.wrappedValue = selection.wrappedValue == q ? "" : q
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.field.opacity(0.55), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.line.opacity(0.6)))
    }

    private func rawChip(_ label: String, selected: Bool, tint: Color, action: @escaping () -> Void) -> some View {
        Button {
            action()
            if animate { EdgeHaptics.tick() }
        } label: {
            Text(verbatim: label)
                .font(.system(size: 11, weight: selected ? .semibold : .medium))
                .foregroundStyle(selected ? tint : Palette.ink.opacity(0.85))
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(selected ? tint.opacity(0.16) : Palette.field, in: RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(selected ? tint.opacity(0.6) : Palette.line.opacity(0.8), lineWidth: selected ? 1.2 : 1))
        }
        .buttonStyle(.plain)
    }

    private func flowChips(options: [String], selection: Binding<String>, minWidth: CGFloat = 110, allowDeselect: Bool = true) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: minWidth), spacing: 6, alignment: .leading)], alignment: .leading, spacing: 6) {
            ForEach(options, id: \.self) { opt in
                let isSel = selection.wrappedValue == opt
                Button {
                    selection.wrappedValue = (isSel && allowDeselect) ? "" : opt
                    if animate { EdgeHaptics.tick() }
                } label: {
                    Text(verbatim: opt)
                        .font(.system(size: 11, weight: isSel ? .semibold : .medium))
                        .foregroundStyle(isSel ? Palette.mint : Palette.ink.opacity(0.85))
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .background(isSel ? Palette.mint.opacity(0.15) : Palette.field, in: RoundedRectangle(cornerRadius: 7))
                        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(isSel ? Palette.mint.opacity(0.55) : Palette.line.opacity(0.75)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func rawMultiChips(options: [String], selection: Binding<[String]>, tint: Color) -> some View {
        let unique = Array(NSOrderedSet(array: options)) as? [String] ?? options
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 7, alignment: .leading)], alignment: .leading, spacing: 7) {
            ForEach(unique, id: \.self) { option in
                let isSel = selection.wrappedValue.contains(option)
                Button {
                    if isSel { selection.wrappedValue.removeAll { $0 == option } }
                    else { selection.wrappedValue.append(option) }
                    if animate { EdgeHaptics.tick() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isSel ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 11))
                            .foregroundStyle(isSel ? tint : Palette.muted.opacity(0.6))
                        Text(verbatim: option)
                            .font(.system(size: 11, weight: isSel ? .semibold : .regular))
                            .foregroundStyle(isSel ? Palette.ink : Palette.ink.opacity(0.82))
                            .lineLimit(1).minimumScaleFactor(0.8)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 9).padding(.vertical, 7)
                    .background(isSel ? tint.opacity(0.14) : Palette.field, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(isSel ? tint.opacity(0.55) : Palette.line.opacity(0.75)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func togglePill(_ title: String, isOn: Binding<Bool>, tint: Color = Palette.blue) -> some View {
        Button {
            isOn.wrappedValue.toggle()
            if animate { EdgeHaptics.tick() }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: isOn.wrappedValue ? "checkmark.square.fill" : "square")
                    .foregroundStyle(isOn.wrappedValue ? tint : Palette.muted)
                Text(verbatim: title).font(.system(size: 11, weight: isOn.wrappedValue ? .semibold : .regular))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(isOn.wrappedValue ? tint.opacity(0.13) : Palette.field, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(isOn.wrappedValue ? tint.opacity(0.5) : Palette.line.opacity(0.75)))
        }
        .buttonStyle(.plain)
    }

    private func numberField(_ title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            promptLabel(title)
            TextField(title, value: value, format: .number).textFieldStyle(EdgeTextFieldStyle()).monospacedDigit()
        }
    }

    private func optionalNumberField(_ title: String, value: Binding<Double?>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            promptLabel(title)
            TextField("—", value: value, format: .number).textFieldStyle(EdgeTextFieldStyle()).monospacedDigit()
        }
    }

    private func createQuickSetup() {
        let name = quickSetup.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { draft.error = "Strateji / Setup için bir ad gir."; return }
        if let existing = store.setups.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            draft.record.setupID = existing.id
            draft.record.setupName = existing.name
            quickSetup = ""
            showQuickSetup = false
            quickSetupNotice = "Mevcut '\(existing.name)' stratejisi seçildi."
            return
        }
        do {
            let setup = Setup(name: name)
            try store.commit {
                store.context.insert(setup)
                let book = Playbook()
                store.context.insert(book)
                setup.playbook = book
            }
            draft.record.setupID = setup.id
            draft.record.setupName = name
            quickSetup = ""
            showQuickSetup = false
            draft.error = nil
            quickSetupNotice = "'\(name)' stratejisi oluşturuldu ve seçildi."
            if animate { EdgeHaptics.selection() }
        } catch { draft.error = error.localizedDescription }
    }
}

struct NoteField: View {
    var title: String
    @Binding var text: String
    @FocusState private var focused: Bool
    init(title: String, text: Binding<String>) { self.title = title; _text = text }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.text(title)).font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.muted)
            TextEditor(text: $text).font(.system(size: 13)).lineSpacing(4).scrollContentBackground(.hidden)
                .padding(11).frame(minHeight: 100).focused($focused)
                .background(Palette.canvas.opacity(0.45), in: RoundedRectangle(cornerRadius: 11))
                .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(focused ? Palette.mint.opacity(0.55) : Palette.muted.opacity(0.18)))
                .accessibilityLabel(L10n.text(title))
        }
    }
}
