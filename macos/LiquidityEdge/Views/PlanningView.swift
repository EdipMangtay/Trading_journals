import SwiftUI

struct PlanningView: View {
    @Environment(JournalStore.self) private var store

    @State private var selectedDate = Date()
    @State private var activeTab = "Daily Plan"
    @State private var currentPlan = DailyPlan(accountID: TradingAccount.legacyID)
    @State private var editingTemplate: ChecklistTemplate?
    @State private var showNewTemplate = false
    @State private var newTemplateName = ""
    @State private var saveMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
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
        .sheet(item: $editingTemplate) { tmpl in
            ChecklistTemplateEditor(template: tmpl) { updated in
                saveTemplate(updated)
            }
        }
        .sheet(isPresented: $showNewTemplate) {
            newTemplateSheet
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
                Button {
                    savePlan()
                } label: {
                    Label("Planı Kaydet", systemImage: "checkmark")
                }
                .buttonStyle(EdgeButtonStyle())
            }
        }
    }

    // MARK: - Daily Plan Section
    private var dailyPlanSection: some View {
        VStack(alignment: .leading, spacing: 20) {
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
            .background(Palette.panel, in: RoundedRectangle(cornerRadius: 10))

            HStack(alignment: .top, spacing: 20) {
                VStack(spacing: 18) {
                    Panel(title: "PİYASA SENARYOLARI VE YÖN TAHMİNİ (BIAS)") {
                        TextEditor(text: $currentPlan.scenarios)
                            .font(.system(size: 13))
                            .frame(minHeight: 110)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(Palette.field.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
                    }

                    Panel(title: "ÖNEMLİ LİKİDİTE ALANLARI (DRAW ON LIQUIDITY)") {
                        TextEditor(text: $currentPlan.liquidity)
                            .font(.system(size: 13))
                            .frame(minHeight: 110)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(Palette.field.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
                    }

                    Panel(title: "ODAK ENSTRÜMANLARI VE SEANSLAR") {
                        TextField("Örn: NQ, ES · New York AM Seansı", text: $currentPlan.instruments)
                            .textFieldStyle(EdgeTextFieldStyle())
                    }
                }

                VStack(spacing: 18) {
                    Panel(title: "STRATEJİ ODAĞI (SETUP ODAĞI)") {
                        TextEditor(text: $currentPlan.focus)
                            .font(.system(size: 13))
                            .frame(minHeight: 110)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(Palette.field.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
                    }

                    Panel(title: "GÜNLÜK RİSK SINIRLARI VE STOP SEVİYELERİ") {
                        TextEditor(text: $currentPlan.limits)
                            .font(.system(size: 13))
                            .frame(minHeight: 110)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(Palette.field.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
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
                    showNewTemplate = true
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
                                    editingTemplate = template
                                } label: {
                                    Image(systemName: "pencil")
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(Palette.mint)

                                Button {
                                    deleteTemplate(template)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(Palette.red)
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

    private func addDefaultTemplates() {
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

    private func deleteTemplate(_ tmpl: ChecklistTemplate) {
        do {
            try store.updateWorkspace { ws in
                ws.templates.removeAll { $0.id == tmpl.id }
            }
        } catch {
            store.report(error)
        }
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
            editingTemplate = nil
        } catch {
            store.report(error)
        }
    }

    private var newTemplateSheet: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Yeni Kontrol Şablonu").font(.title2.weight(.bold))
            TextField("Şablon Adı (Örn: London Scalp Checklist)", text: $newTemplateName)
                .textFieldStyle(EdgeTextFieldStyle())

            HStack {
                Spacer()
                Button("İptal") { showNewTemplate = false }.keyboardShortcut(.cancelAction)
                Button("Oluştur") {
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
                    showNewTemplate = false
                }
                .buttonStyle(EdgeButtonStyle())
                .disabled(newTemplateName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 440)
        .background(Palette.canvas)
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
                Button("İptal") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Kaydet") {
                    onSave(template)
                    dismiss()
                }
                .buttonStyle(EdgeButtonStyle())
            }

            TextField("Şablon Adı", text: $template.name)
                .textFieldStyle(EdgeTextFieldStyle())

            Divider()

            Text("Kontrol Maddeleri").font(.headline)

            HStack(spacing: 12) {
                TextField("Yeni madde (örn: Stop Loss belirlendi)", text: $newItemLabel)
                    .textFieldStyle(EdgeTextFieldStyle())
                Picker("Aşama", selection: $newItemPhase) {
                    Text("Öncesi").tag("Öncesi")
                    Text("Sonrası").tag("Sonrası")
                }
                .frame(width: 110)

                Button("Ekle") {
                    let clean = newItemLabel.trimmingCharacters(in: .whitespaces)
                    guard !clean.isEmpty else { return }
                    template.items.append(ChecklistAnswer(label: clean, phase: newItemPhase))
                    newItemLabel = ""
                }
                .buttonStyle(EdgeButtonStyle(prominent: false))
                .disabled(newItemLabel.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            List {
                ForEach(template.items) { item in
                    HStack {
                        Badge(text: item.phase, color: item.phase == "Öncesi" ? Palette.blue : Palette.mint)
                        Text(item.label)
                        Spacer()
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
    }
}

