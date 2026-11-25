import SwiftUI

struct PlanningView: View {
    @Environment(JournalStore.self) private var store

    @State private var selectedDate = Date()
    @State private var activeTab = "Daily Plan"
    @State private var currentPlan = DailyPlan(accountID: TradingAccount.legacyID)
    @State private var activeSheet: PlanningSheet?
    @State private var newTemplateName = ""
    @State private var saveMessage: String?

    init(initialTab: String = "Daily Plan") {
        _activeTab = State(initialValue: initialTab)
    }

    private enum PlanningSheet: Identifiable {
        case editTemplate(ChecklistTemplate)
        case newTemplate
        var id: String {
            switch self {
            case .editTemplate(let t): return "edit-\(t.id.uuidString)"
            case .newTemplate: return "new-template"
            }
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                headerView

                SegmentedTabs(
                    options: ["Daily Plan", "Checklist Templates", "Workflow Discipline"],
                    selection: $activeTab,
                    title: { $0 }
                )

                switch activeTab {
                case "Daily Plan":
                    dailyPlanSection
                case "Checklist Templates":
                    checklistTemplatesSection
                case "Workflow Discipline":
                    workflowDisciplineSection
                default:
                    EmptyView()
                }
            }
            .pagePadding()
        }
        .onAppear(perform: loadPlan)
        .onChange(of: selectedDate) { _, _ in loadPlan() }
        .onChange(of: store.selectedAccount.id) { _, _ in loadPlan() }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .editTemplate(let tmpl):
                ChecklistTemplateEditor(template: tmpl) { updated in
                    saveTemplate(updated)
                }
            case .newTemplate:
                newTemplateSheet
            }
        }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack(alignment: .top) {
            PageHeader(
                eyebrow: "WORKFLOW / 03",
                title: "İşlem Planı & Süreç Kontrolü",
                subtitle: "Piyasa öncesi hazırlık, model bazlı kontrol listeleri ve seans hedefleri."
            )
            Spacer()
            if activeTab == "Daily Plan" {
                HStack(spacing: 10) {
                    Button {
                        applyAIDailyBriefing()
                    } label: {
                        Label("AI Seans Brifingi ile Doldur", systemImage: "sparkles")
                    }
                    .buttonStyle(EdgeButtonStyle(prominent: false))

                    Button {
                        savePlan()
                    } label: {
                        Label("Planı Kaydet", systemImage: "checkmark")
                    }
                    .buttonStyle(EdgeButtonStyle())
                }
            }
        }
    }

    // MARK: - Daily Plan Section
    private var dailyPlanSection: some View {
        let aiBrief = EdgeMLEngine.generateDailyPlanBriefing(
            for: selectedDate,
            account: store.selectedAccount,
            trades: store.scopedTrades,
            setups: store.setups,
            risk: store.scopedRisk,
            calendar: store.preferences.calendar
        )
        let tiltColor: Color = aiBrief.tiltLevel == .elevated ? Palette.red : aiBrief.tiltLevel == .caution ? Palette.amber : Palette.mint
        return VStack(alignment: .leading, spacing: 20) {
            GlassRibbon(accent: Palette.mint) {
                HStack(spacing: 0) {
                    TerminalMetric(
                        title: "AI ÖNERİLEN RİSK (KELLY)",
                        value: "\(Format.percent(aiBrief.recommendedRiskPercent)) (\(Format.money(aiBrief.recommendedRiskDollars, currency: store.accountCurrency)))",
                        color: Palette.mint,
                        subtitle: "Quarter-Kelly \(Format.percent(aiBrief.quarterKellyPercent)) × \(String(format: "%.2fx", aiBrief.regimeRiskMultiplier)) Rejim"
                    )
                    Rectangle().fill(Palette.line.opacity(0.7)).frame(width: 1, height: 38).padding(.horizontal, 16)
                    TerminalMetric(
                        title: "EN VERİMLİ SEANS",
                        value: aiBrief.bestSessionLabel,
                        color: Palette.blue,
                        subtitle: aiBrief.weekdayEdgeSummary
                    )
                    Rectangle().fill(Palette.line.opacity(0.7)).frame(width: 1, height: 38).padding(.horizontal, 16)
                    TerminalMetric(
                        title: "AKTİF REJİM (CUSUM)",
                        value: aiBrief.regimeState.rawValue,
                        color: aiBrief.regimeState == .regimeDrift ? Palette.red : aiBrief.regimeState == .hotEdge ? Palette.mint : Palette.blue,
                        subtitle: "Odak: \(aiBrief.primarySetupLabel)"
                    )
                    Rectangle().fill(Palette.line.opacity(0.7)).frame(width: 1, height: 38).padding(.horizontal, 16)
                    TerminalMetric(
                        title: "TİLT & DİSİPLİN DURUMU",
                        value: aiBrief.tiltLevel.rawValue,
                        color: tiltColor,
                        subtitle: "Tilt Skoru: \(aiBrief.tiltScore)/100"
                    )
                }
            }

            HStack(spacing: 16) {
                DatePicker(
                    "Plan Tarihi",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.field)
                .frame(maxWidth: 200)

                AccountPicker()

                Spacer()

                if let msg = saveMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(Palette.mint)
                        .transition(.opacity)
                }
            }
            .padding(14)
            .background(Palette.panelGradient, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.line.opacity(0.85), lineWidth: 1))

            HStack(alignment: .top, spacing: 20) {
                VStack(spacing: 18) {
                    Panel(title: "PİYASA SENARYOLARI VE YÖN TAHMİNİ (BIAS)", accent: Palette.mint) {
                        TextEditor(text: $currentPlan.scenarios)
                            .font(.system(size: 13))
                            .frame(height: 112)
                            .scrollContentBackground(.hidden)
                            .padding(10)
                            .background(Palette.field.opacity(0.65), in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.line.opacity(0.75), lineWidth: 1))
                    }

                    Panel(title: "ÖNEMLİ LİKİDİTE ALANLARI (DRAW ON LIQUIDITY)", accent: Palette.blue) {
                        TextEditor(text: $currentPlan.liquidity)
                            .font(.system(size: 13))
                            .frame(height: 112)
                            .scrollContentBackground(.hidden)
                            .padding(10)
                            .background(Palette.field.opacity(0.65), in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.line.opacity(0.75), lineWidth: 1))
                    }

                    Panel(title: "ODAK ENSTRÜMANLARI VE SEANSLAR") {
                        TextField("Örn: NQ, ES · New York AM Seansı", text: $currentPlan.instruments)
                            .textFieldStyle(EdgeTextFieldStyle())
                    }
                }

                VStack(spacing: 18) {
                    Panel(title: "STRATEJİ ODAĞI (SETUP ODAĞI)", accent: Palette.cyan) {
                        TextEditor(text: $currentPlan.focus)
                            .font(.system(size: 13))
                            .frame(height: 112)
                            .scrollContentBackground(.hidden)
                            .padding(10)
                            .background(Palette.field.opacity(0.65), in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.line.opacity(0.75), lineWidth: 1))
                    }

                    Panel(title: "GÜNLÜK RİSK SINIRLARI VE STOP SEVİYELERİ", accent: Palette.amber) {
                        TextEditor(text: $currentPlan.limits)
                            .font(.system(size: 13))
                            .frame(height: 112)
                            .scrollContentBackground(.hidden)
                            .padding(10)
                            .background(Palette.field.opacity(0.65), in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.line.opacity(0.75), lineWidth: 1))
                    }

                    Panel(title: "SEANS HEDEFLERİ VE DİSİPLİN KURALLARI") {
                        TextField("Örn: En fazla 2 işlem, revenge trade kesinlikle yasak", text: $currentPlan.objectives)
                            .textFieldStyle(EdgeTextFieldStyle())
                    }
                }
            }
        }
    }

    // MARK: - Checklist Templates Section
    private var checklistTemplatesSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Model & Strateji Kontrol Şablonları")
                    .font(.headline)
                Spacer()
                Button("Varsayılan Şablonları Ekle") {
                    addDefaultTemplates()
                }
                .buttonStyle(EdgeButtonStyle(prominent: false, compact: true))

                Button("Yeni Şablon Oluştur") {
                    activeSheet = .newTemplate
                }
                .buttonStyle(EdgeButtonStyle(compact: true))
            }

            if store.workspace.templates.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checklist")
                        .font(.system(size: 36))
                        .foregroundStyle(Palette.mint)
                    Text("Henüz kontrol listesi şablonu tanımlanmamış.")
                        .font(.headline)
                    Text("İşlem öncesi ve sonrası disiplin adımlarınızı standardize etmek için QT, MMXM, CRT veya özel şablonlar ekleyin.")
                        .font(.caption)
                        .foregroundStyle(Palette.muted)
                    Button("Varsayılan Şablonları Yükle") {
                        addDefaultTemplates()
                    }
                    .buttonStyle(EdgeButtonStyle())
                }
                .padding(40)
                .frame(maxWidth: .infinity)
                .background(Palette.panel, in: RoundedRectangle(cornerRadius: 14))
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 340), spacing: 18)], spacing: 18) {
                    ForEach(store.workspace.templates) { template in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(template.name)
                                    .font(.headline)
                                Spacer()
                                Button {
                                    activeSheet = .editTemplate(template)
                                } label: {
                                    Image(systemName: "pencil")
                                        .font(.caption)
                                        .foregroundStyle(Palette.mint)
                                        .frame(width: 28, height: 28)
                                        .background(Palette.mint.opacity(0.09), in: RoundedRectangle(cornerRadius: 7))
                                        .contentShape(RoundedRectangle(cornerRadius: 7))
                                }
                                .buttonStyle(.plain)
                                .help("Şablonu düzenle")

                                Button(role: .destructive) {
                                    _ = Self.performDeleteTemplate(template, in: store)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                        .foregroundStyle(Palette.red)
                                        .frame(width: 28, height: 28)
                                        .background(Palette.red.opacity(0.09), in: RoundedRectangle(cornerRadius: 7))
                                        .contentShape(RoundedRectangle(cornerRadius: 7))
                                }
                                .buttonStyle(.plain)
                                .help("Şablonu sil")
                            }

                            Divider()

                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(template.items) { item in
                                    HStack(spacing: 8) {
                                        Image(systemName: item.phase == "Öncesi" ? "arrow.right.circle" : "checkmark.circle")
                                            .font(.caption)
                                            .foregroundStyle(item.phase == "Öncesi" ? Palette.blue : Palette.mint)
                                        Text(item.label)
                                            .font(.system(size: 12))
                                        Spacer()
                                        Text(item.phase)
                                            .font(.system(size: 10))
                                            .foregroundStyle(Palette.muted)
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .background(Palette.panel, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.line))
                    }
                }
            }
        }
    }

    // MARK: - Workflow Discipline Section
    private var workflowDisciplineSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Panel(title: "PROFESYONEL İŞLEM DÖNGÜSÜ (3 ADIM)") {
                HStack(alignment: .top, spacing: 20) {
                    workflowStepCard(
                        step: "01",
                        title: "Piyasa Öncesi Hazırlık",
                        icon: "sun.max",
                        items: [
                            "Ekonomik takvim ve haber saatlerini incele",
                            "HTF likidite havuzlarını ve bias'ı belirle",
                            "Günlük risk sınırını (max 2R) belirle",
                            "Kabul edilebilir kurulum modelini seç"
                        ]
                    )

                    workflowStepCard(
                        step: "02",
                        title: "İşlem Esnası Uygulama",
                        icon: "scope",
                        items: [
                            "Giriş teyidi (CISD/Sweep) oluşmadan girme",
                            "Stop Loss seviyesini asla geriye çekme",
                            "Planlanan hedef likiditeye sadık kal",
                            "Grafik ekran görüntüsünü anında kaydet"
                        ]
                    )

                    workflowStepCard(
                        step: "03",
                        title: "Seans Sonrası Değerlendirme",
                        icon: "chart.bar.doc.horizontal",
                        items: [
                            "Kural ve plan uyumunu dürüstçe puanla",
                            "Duygusal durumunu (FOMO/Stres) kaydet",
                            "Kilit dersi ve iyileştirme adımını yaz",
                            "Gerekirse günlük inceleme raporunu oluştur"
                        ]
                    )
                }
            }
        }
    }

    private func workflowStepCard(step: String, title: String, icon: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(step).font(.caption.weight(.bold)).foregroundStyle(Palette.mint)
                Spacer()
                Image(systemName: icon).foregroundStyle(Palette.mint)
            }
            Text(title).font(.headline)
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 6) {
                        Text("•").foregroundStyle(Palette.muted)
                        Text(item).font(.caption).foregroundStyle(Palette.ink)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Palette.field.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.line))
    }

    // MARK: - Logic
    private func loadPlan() {
        let cal = store.preferences.calendar
        let accountID = store.selectedAccount.id
        if let plan = store.workspace.plans.first(where: {
            $0.accountID == accountID && cal.isDate($0.date, inSameDayAs: selectedDate)
        }) {
            currentPlan = plan
        } else {
            currentPlan = DailyPlan(accountID: accountID, date: selectedDate)
        }
    }

    private func savePlan() {
        currentPlan.accountID = store.selectedAccount.id
        currentPlan.date = selectedDate
        do {
            try store.updateWorkspace { ws in
                ws.plans.removeAll { $0.id == currentPlan.id || (store.preferences.calendar.isDate($0.date, inSameDayAs: currentPlan.date) && $0.accountID == currentPlan.accountID) }
                ws.plans.append(currentPlan)
            }
            saveMessage = "Plan kaydedildi."
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                saveMessage = nil
            }
        } catch {
            store.report(error)
        }
    }

    private func applyAIDailyBriefing() {
        let briefing = EdgeMLEngine.generateDailyPlanBriefing(
            for: selectedDate,
            account: store.selectedAccount,
            trades: store.scopedTrades,
            setups: store.setups,
            risk: store.scopedRisk,
            calendar: store.preferences.calendar
        )
        currentPlan = briefing.plan
        saveMessage = "AI Seans Brifingi uygulandı (\(Format.percent(briefing.recommendedRiskPercent)) risk)."
    }

    private func addDefaultTemplates() {
        Self.performAddDefaultTemplates(into: store)
    }

    @MainActor
    static func performAddDefaultTemplates(into store: JournalStore) {
        let qt = ChecklistTemplate(
            name: "Quarterly Theory (QT) Şablonu",
            items: [
                ChecklistAnswer(label: "HTF Çeyrek Yönü Teyit Edildi", phase: "Öncesi"),
                ChecklistAnswer(label: "Günlük / 90 Dk Çeyrek Fazı Uyumlu", phase: "Öncesi"),
                ChecklistAnswer(label: "True Open (New York 00:00 / 08:30) Saygı Gördü", phase: "Öncesi"),
                ChecklistAnswer(label: "Likidite Hedefi Net Tanımlandı", phase: "Öncesi"),
                ChecklistAnswer(label: "Planlanan Hedefe Kadar Pozisyon Korundu", phase: "Sonrası")
            ]
        )

        let mmxm = ChecklistTemplate(
            name: "Market Maker Modeli (MMXM) Şablonu",
            items: [
                ChecklistAnswer(label: "Orijinal Konsolidasyon Tespit Edildi", phase: "Öncesi"),
                ChecklistAnswer(label: "Manipülasyon / Turtle Soup Gerçekleşti", phase: "Öncesi"),
                ChecklistAnswer(label: "Smart Money Reversal (SMR) Teyit Edildi", phase: "Öncesi"),
                ChecklistAnswer(label: "Karşıt Likiditeye Ulaşıldı", phase: "Sonrası")
            ]
        )

        let crt = ChecklistTemplate(
            name: "Candle Range Theory (CRT) Şablonu",
            items: [
                ChecklistAnswer(label: "Zaman Dilimi CRT Aralığı Çizildi", phase: "Öncesi"),
                ChecklistAnswer(label: "Aralık Sınırı Likiditesi Süpürüldü", phase: "Öncesi"),
                ChecklistAnswer(label: "CISD / İç Yapı Kırılımı Oluştu", phase: "Öncesi"),
                ChecklistAnswer(label: "Stop Loss Aralık Dışına Konuldu", phase: "Öncesi")
            ]
        )

        do {
            try store.updateWorkspace { ws in
                if !ws.templates.contains(where: { $0.name == qt.name }) { ws.templates.append(qt) }
                if !ws.templates.contains(where: { $0.name == mmxm.name }) { ws.templates.append(mmxm) }
                if !ws.templates.contains(where: { $0.name == crt.name }) { ws.templates.append(crt) }
            }
        } catch {
            store.report(error)
        }
    }

    @MainActor @discardableResult
    static func performDeleteTemplate(_ tmpl: ChecklistTemplate, in store: JournalStore) -> Bool {
        if ConfirmDialog.confirm(
            title: "Şablonu sil?",
            message: "'\(tmpl.name)' kontrol listesi şablonu silinecek.",
            confirmTitle: "Sil",
            destructive: true
        ) {
            do {
                try store.updateWorkspace { ws in
                    ws.templates.removeAll { $0.id == tmpl.id }
                }
                return true
            } catch {
                store.report(error)
            }
        }
        return false
    }

    private func saveTemplate(_ updated: ChecklistTemplate) {
        do {
            try store.updateWorkspace { ws in
                if let idx = ws.templates.firstIndex(where: { $0.id == updated.id }) {
                    ws.templates[idx] = updated
                } else {
                    ws.templates.append(updated)
                }
            }
            activeSheet = nil
        } catch {
            store.report(error)
        }
    }

    private var newTemplateSheet: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Yeni Kontrol Şablonu").font(.title2.weight(.bold))
            TextField("Şablon Adı (Örn: London Scalp Checklist)", text: $newTemplateName)
                .textFieldStyle(EdgeTextFieldStyle())
                .onSubmit { createNewTemplate() }

            HStack {
                Spacer()
                Button("İptal") { activeSheet = nil }
                    .buttonStyle(EdgeButtonStyle(prominent: false, compact: true))
                    .keyboardShortcut(.cancelAction)
                Button("Oluştur") { createNewTemplate() }
                    .buttonStyle(EdgeButtonStyle(compact: true))
                    .disabled(newTemplateName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 440)
        .background(Palette.canvas)
        .foregroundStyle(Palette.ink)
        .tint(Palette.mint)
    }

    private func createNewTemplate() {
        let clean = newTemplateName.trimmingCharacters(in: .whitespaces)
        guard !clean.isEmpty else { return }
        let tmpl = ChecklistTemplate(
            name: clean,
            items: [
                ChecklistAnswer(label: "Kurulum teyidi hazır", phase: "Öncesi"),
                ChecklistAnswer(label: "Risk %1 altında", phase: "Öncesi"),
                ChecklistAnswer(label: "Plana tam uyuldu", phase: "Sonrası")
            ]
        )
        saveTemplate(tmpl)
        newTemplateName = ""
        activeSheet = nil
    }
}

struct ChecklistTemplateEditor: View {
    @State var template: ChecklistTemplate
    var onSave: (ChecklistTemplate) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var newItemLabel = ""
    @State private var newItemPhase = "Öncesi"

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Şablonu Düzenle").font(.title2.weight(.bold))
                Spacer()
                Button("İptal") { dismiss() }
                    .buttonStyle(EdgeButtonStyle(prominent: false, compact: true))
                    .keyboardShortcut(.cancelAction)
                Button("Kaydet") {
                    let cleanName = template.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !cleanName.isEmpty else { return }
                    template.name = cleanName
                    onSave(template)
                    dismiss()
                }
                .buttonStyle(EdgeButtonStyle(compact: true))
                .disabled(template.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut("s", modifiers: .command)
            }

            TextField("Şablon Adı", text: $template.name)
                .textFieldStyle(EdgeTextFieldStyle())

            Divider()

            Text("Kontrol Maddeleri").font(.headline)

            HStack(spacing: 12) {
                TextField("Yeni madde (örn: Stop Loss belirlendi)", text: $newItemLabel)
                    .textFieldStyle(EdgeTextFieldStyle())
                    .onSubmit { addItem() }
                Picker("Aşama", selection: $newItemPhase) {
                    Text("Öncesi").tag("Öncesi")
                    Text("Sonrası").tag("Sonrası")
                }
                .frame(width: 110)

                Button("Ekle") { addItem() }
                    .buttonStyle(EdgeButtonStyle(prominent: false, compact: true))
                    .disabled(newItemLabel.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            List {
                ForEach(template.items) { item in
                    HStack {
                        Badge(text: item.phase, color: item.phase == "Öncesi" ? Palette.blue : Palette.mint)
                        Text(item.label)
                        Spacer()
                        Button {
                            template.items.removeAll { $0.id == item.id }
                        } label: {
                            Image(systemName: "trash").font(.caption).foregroundStyle(Palette.red)
                                .frame(width: 26, height: 26)
                                .background(Palette.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                                .contentShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .help("Maddeyi sil")
                    }
                }
                .onDelete { idx in
                    template.items.remove(atOffsets: idx)
                }
            }
            .listStyle(.plain)
            .frame(height: 220)
        }
        .padding(24)
        .frame(width: 550, height: 500)
        .background(Palette.canvas)
        .foregroundStyle(Palette.ink)
        .tint(Palette.mint)
    }

    private func addItem() {
        let clean = newItemLabel.trimmingCharacters(in: .whitespaces)
        guard !clean.isEmpty else { return }
        template.items.append(ChecklistAnswer(label: clean, phase: newItemPhase))
        newItemLabel = ""
    }
}

