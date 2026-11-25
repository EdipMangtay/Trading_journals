import SwiftUI
import AppKit

struct PlaybookDraft: Identifiable {
    var id = UUID(), name = "", summary = "", conditions = "", entry = "", invalidation = "", target = "", risk = ""
    var images: [ScreenshotDraft] = []
    init() {}
    init(_ setup: Setup) throws { id = setup.id; name = setup.name; summary = setup.summary; if let p = setup.playbook { conditions = p.conditions; entry = p.entryRules; invalidation = p.invalidationRules; target = p.targetRules; risk = p.riskRules; images = try BackupService.decodeImages(p.idealImagesData) } }
}
struct PlaybookView: View {
    @Environment(JournalStore.self) private var store
    var openPlaybook: ((PlaybookDraft) -> Void)? = nil
    @State private var localSheet: PlaybookSheet?

    private enum PlaybookSheet: Identifiable {
        case editor(PlaybookDraft)
        case shot(ScreenshotDraft)
        var id: String {
            switch self {
            case .editor(let d): return "edit-\(d.id.uuidString)"
            case .shot(let s): return "shot-\(s.id.uuidString)"
            }
        }
    }

    private func presentEditor(_ draft: PlaybookDraft) {
        if let openPlaybook { openPlaybook(draft) }
        else { localSheet = .editor(draft) }
    }

    var body: some View {
        let perfBySetup = store.scopedSetupPerformances
        let bestSetup: (Setup, Performance)? = store.setups
            .compactMap { s in perfBySetup[s.id].map { (s, $0) } }
            .filter { $0.1.count > 0 && $0.1.averageR != nil }
            .max { ($0.1.averageR ?? -.infinity) < ($1.1.averageR ?? -.infinity) }
        let linkedTotal = store.setups.reduce(0) { $0 + (perfBySetup[$1.id]?.count ?? 0) }
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top, spacing: 24) {
                    PageHeader(eyebrow: "Your models", title: "Define it. Execute it. Refine it.", subtitle: "A living playbook, linked to the performance of your actual trades.")
                    Spacer(minLength: 0)
                    Button { presentEditor(PlaybookDraft()) } label: { Label(L10n.text("New setup"), systemImage: "plus") }
                        .buttonStyle(EdgeButtonStyle())
                }
                if !store.setups.isEmpty {
                    GlassRibbon(accent: Palette.mint) {
                        HStack(spacing: 0) {
                            TerminalMetric(title: "TOPLAM MODEL", value: "\(store.setups.count)", subtitle: "\(linkedTotal) bağlı işlem")
                            Rectangle().fill(Palette.line.opacity(0.7)).frame(width: 1, height: 38).padding(.horizontal, 16)
                            TerminalMetric(
                                title: "EN GÜÇLÜ MODEL",
                                value: bestSetup?.0.name ?? "—",
                                color: Palette.mint,
                                subtitle: bestSetup.map { "Ort. \(Format.r($0.1.averageR)) · WR \(Format.percent($0.1.winRate))" } ?? "Henüz yeterli R kaydı yok"
                            )
                            Rectangle().fill(Palette.line.opacity(0.7)).frame(width: 1, height: 38).padding(.horizontal, 16)
                            TerminalMetric(
                                title: "GENEL UYUM",
                                value: Format.percent(store.scopedPerformance.compliance),
                                color: store.scopedPerformance.compliance >= 80 ? Palette.mint : Palette.amber,
                                subtitle: "Aktif hesap ortalaması"
                            )
                        }
                    }
                    .edgeEntrance(delay: 0.02)
                }
                if store.setups.isEmpty {
                    Panel { EmptyJournal(title: "Codify your first setup.", subtitle: "Write the conditions, invalidation and risk rules that make an execution valid.", actionTitle: "Create setup", action: { presentEditor(PlaybookDraft()) }) }
                }
                ForEach(Array(store.setups.enumerated()), id: \.element.id) { index, setup in
                    let p = perfBySetup[setup.id] ?? Performance()
                    let modelAccent = p.count > 0 ? Palette.outcome(p.averageR ?? p.netPnL) : Palette.mint
                    Panel(accent: modelAccent) {
                        HStack(alignment: .top, spacing: 18) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 13).fill(modelAccent.opacity(0.11)).frame(width: 48, height: 48)
                                RoundedRectangle(cornerRadius: 13).strokeBorder(modelAccent.opacity(0.26), lineWidth: 1).frame(width: 48, height: 48)
                                Image(systemName: "square.stack.3d.up").font(.system(size: 21, weight: .light)).foregroundStyle(modelAccent)
                            }.accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 7) {
                                HStack(spacing: 8) {
                                    Text(String(format: "MODEL %02d", index + 1)).font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.5).foregroundStyle(modelAccent)
                                    if let book = setup.playbook {
                                        let ruleCount = [book.conditions, book.entryRules, book.invalidationRules, book.targetRules, book.riskRules].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
                                        if ruleCount > 0 {
                                            Text("\(ruleCount)/5 kural")
                                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                                .foregroundStyle(Palette.muted)
                                                .padding(.horizontal, 6).padding(.vertical, 2)
                                                .background(Palette.raised.opacity(0.7), in: Capsule())
                                        }
                                    }
                                }
                                Text(verbatim: setup.name).font(.system(size: 23, weight: .bold)).tracking(-0.5).fixedSize(horizontal: false, vertical: true)
                                if !setup.summary.isEmpty { Text(verbatim: setup.summary).font(.system(size: 12)).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true) }
                            }
                            Spacer(minLength: 0)
                            HStack(spacing: 8) {
                                Button {
                                    do { presentEditor(try PlaybookDraft(setup)) } catch { store.report(error) }
                                } label: { Label(L10n.text("Edit"), systemImage: "square.and.pencil") }
                                    .buttonStyle(EdgeButtonStyle(prominent: false, compact: true))
                                Button(role: .destructive) {
                                    _ = Self.performDeleteSetup(setup, in: store)
                                } label: { Image(systemName: "trash").frame(width: 14, height: 16) }
                                    .buttonStyle(EdgeButtonStyle(prominent: false, compact: true)).help(L10n.text("Delete setup")).accessibilityLabel(L10n.text("Delete setup"))
                            }
                        }
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 20, alignment: .leading), count: 5), alignment: .leading, spacing: 20) {
                            stat("SAMPLES", "\(p.count)", color: Palette.ink)
                            stat("WIN RATE", p.count == 0 ? "—" : Format.percent(p.winRate), color: p.winRate >= 50 ? Palette.mint : Palette.ink)
                            stat("AVG R", Format.r(p.averageR), color: p.averageR.map(Palette.outcome) ?? Palette.muted)
                            stat("EXPECTANCY", p.count == 0 ? "—" : Format.money(p.expectancy, currency: store.accountCurrency), color: p.count == 0 ? Palette.muted : Palette.outcome(p.expectancy))
                            stat("COMPLIANCE", p.count == 0 ? "—" : Format.percent(p.compliance), color: p.count == 0 ? Palette.muted : (p.compliance >= 80 ? Palette.mint : Palette.amber))
                        }
                        .padding(17)
                        .background(Palette.field.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.line.opacity(0.65), lineWidth: 1))
                        let aiOpt = EdgeMLEngine.optimizeSetup(setup, trades: store.scopedTrades, calendar: store.preferences.calendar)
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 12) {
                                Label("AI MODEL OPTİMİZASYONU", systemImage: "brain.head.profile")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(Palette.mint)
                                Badge(text: "İSTİKRAR \(aiOpt.edgeStabilityScore)/100", color: aiOpt.edgeStabilityScore >= 65 ? Palette.mint : Palette.blue)
                                Badge(text: "ÖNERİLEN RİSK \(Format.percent(aiOpt.recommendedRiskPercent))", color: Palette.mint)
                                Spacer()
                                Text("Lider Parite: \(aiOpt.bestInstrument)")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(Palette.ink)
                            }
                            HStack(spacing: 14) {
                                Text("En İyi Seans: \(aiOpt.bestSession)")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(Palette.ink)
                                Text("·").foregroundStyle(Palette.muted)
                                Text("En Güçlü Teyit: \(aiOpt.bestConfirmation)")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(Palette.blue)
                                Spacer()
                                Text("Sızıntı: \(aiOpt.primaryLeak)")
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundStyle(Palette.amber)
                            }
                            Text(aiOpt.recommendation)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Palette.muted)
                        }
                        .padding(12)
                        .background(Palette.mint.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.mint.opacity(0.20), lineWidth: 0.9))
                        if let book = setup.playbook {
                            let idealImages = (try? BackupService.decodeImages(book.idealImagesData)) ?? []
                            DisclosureGroup {
                                VStack(alignment: .leading, spacing: 18) {
                                    textBlock("Conditions", book.conditions)
                                    textBlock("Entry", book.entryRules)
                                    textBlock("Invalidation", book.invalidationRules)
                                    textBlock("Targets", book.targetRules)
                                    textBlock("Risk", book.riskRules)
                                    if !idealImages.isEmpty {
                                        VStack(alignment: .leading, spacing: 10) {
                                            Text(L10n.text("IDEAL EXAMPLES")).font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(1).foregroundStyle(Palette.muted)
                                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                                                ForEach(idealImages) { shot in
                                                    Button { localSheet = .shot(shot) } label: {
                                                        VStack(alignment: .leading, spacing: 6) {
                                                            ScreenshotThumbnail(data: shot.thumbnailData, cacheKey: "pb-\(shot.id.uuidString)").frame(height: 120).clipShape(RoundedRectangle(cornerRadius: 8))
                                                            Text(verbatim: shot.name).font(.system(size: 10)).foregroundStyle(Palette.muted).lineLimit(1)
                                                        }.padding(8).background(Palette.raised.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
                                                    }.buttonStyle(.plain)
                                                }
                                            }
                                        }
                                    }
                                }.padding(.top, 16)
                            } label: {
                                Label(L10n.text("Conditions & execution rules"), systemImage: "list.bullet.clipboard")
                                    .font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.ink)
                            }.tint(Palette.muted)
                        }
                    }
                }
            }.pagePadding()
        }
        .sheet(item: $localSheet) { sheet in
            switch sheet {
            case .editor(let draft): PlaybookEditor(initial: draft).environment(store)
            case .shot(let shot): ScreenshotViewer(initial: shot) { _ in }
            }
        }
    }
    private func stat(_ label: String, _ value: String, color: Color = Palette.ink) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.text(label)).font(.system(size: 9, weight: .semibold, design: .monospaced)).tracking(0.6).foregroundStyle(Palette.muted)
            Text(verbatim: value).font(.system(size: 21, weight: .bold, design: .rounded)).foregroundStyle(color).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
        }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .combine)
    }
    private func textBlock(_ label: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 18) {
            Text(L10n.text(label)).font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.muted).frame(width: 100, alignment: .leading)
            Text(verbatim: text.isEmpty ? L10n.text("Not recorded") : text).font(.system(size: 12)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @MainActor @discardableResult
    static func performDeleteSetup(_ setup: Setup, in store: JournalStore) -> Bool {
        if ConfirmDialog.confirm(
            title: "Delete this setup?",
            message: "Linked trades remain in your journal and become Unassigned. The playbook and its ideal images are deleted.",
            confirmTitle: "Delete setup",
            destructive: true
        ) {
            do { try store.deleteSetup(setup); return true } catch { store.report(error) }
        }
        return false
    }
}
struct PlaybookEditor: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var draft: PlaybookDraft
    @State private var activeTab: PlaybookTab = .identity
    @State private var error: String?

    private enum PlaybookTab: String, CaseIterable, Identifiable {
        case identity = "01 · Kimlik & Giriş"
        case risk = "02 · Risk & Hedefler"
        case examples = "03 · İdeal Örnekler"
        var id: String { rawValue }
    }

    init(initial: PlaybookDraft, initialTab: Int = 0) {
        _draft = State(initialValue: initial)
        let tabs = PlaybookTab.allCases
        _activeTab = State(initialValue: tabs.indices.contains(initialTab) ? tabs[initialTab] : .identity)
    }
    private var sheetSize: CGSize {
        let screen = (NSApp.keyWindow?.screen ?? NSScreen.main)?.visibleFrame.size ?? CGSize(width: 1200, height: 900)
        return CGSize(width: min(820, max(640, screen.width - 100)), height: min(740, max(480, screen.height - 90)))
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 15) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11).fill(Palette.mint.opacity(0.09)).frame(width: 42, height: 42)
                    Image(systemName: "book.closed").font(.system(size: 19, weight: .medium)).foregroundStyle(Palette.mint)
                }.accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.text("Setup playbook")).font(.system(size: 20, weight: .semibold)).tracking(-0.4)
                    Text("Sadece adını yazıp anında kaydedebilir, kuralları ve görselleri istediğin zaman doldurabilirsin.").font(.system(size: 11)).foregroundStyle(Palette.muted)
                }
                Spacer(minLength: 8)
                Button(L10n.text("Cancel")) { dismiss() }.buttonStyle(EdgeButtonStyle(prominent: false, compact: true)).keyboardShortcut(.cancelAction)
                Button { save() } label: { Label(L10n.text("Save setup"), systemImage: "checkmark") }
                    .buttonStyle(EdgeButtonStyle(compact: true)).keyboardShortcut("s", modifiers: .command)
            }.padding(.horizontal, 24).padding(.vertical, 16).background(Palette.panel)

            HStack(spacing: 6) {
                ForEach(PlaybookTab.allCases) { tab in
                    let isSelected = activeTab == tab
                    Button {
                        activeTab = tab
                    } label: {
                        Text(tab.rawValue)
                            .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                            .foregroundStyle(isSelected ? Palette.ink : Palette.muted)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(isSelected ? Palette.raised : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(isSelected ? Palette.mint.opacity(0.35) : Color.clear, lineWidth: 1))
                            .contentShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 10)
            .background(Palette.panel.opacity(0.6))
            Rectangle().fill(Palette.line.opacity(0.7)).frame(height: 1)

            if let error {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.circle.fill").foregroundStyle(Palette.amber)
                    Text(L10n.text(error)).font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.amber)
                    Spacer()
                    Button("Kapat") { self.error = nil }.buttonStyle(EdgeButtonStyle(prominent: false, compact: true))
                }
                .padding(.horizontal, 24).padding(.vertical, 10)
                .background(Palette.amber.opacity(0.1))
                .accessibilityElement(children: .combine)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch activeTab {
                    case .identity:
                        Panel(title: "STRATEJİ KİMLİĞİ") {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 4) {
                                    Text(L10n.text("Setup name")).font(.system(size: 12, weight: .medium))
                                    Text("*").font(.system(size: 12, weight: .bold)).foregroundStyle(Palette.mint)
                                }
                                TextField("Örn: NY AM QT + SSMT CISD", text: $draft.name)
                                    .textFieldStyle(EdgeTextFieldStyle())
                                    .onSubmit { save() }
                                    .accessibilityLabel(L10n.text("Setup name"))
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Text(L10n.text("Brief description")).font(.system(size: 12, weight: .medium))
                                TextField("Kısa strateji özeti (isteğe bağlı)", text: $draft.summary)
                                    .textFieldStyle(EdgeTextFieldStyle())
                                    .accessibilityLabel(L10n.text("Brief description"))
                            }
                        }
                        Panel(title: "KOŞULLAR VE GİRİŞ KURALLARI (İSTEĞE BAĞLI)") {
                            NoteField(title: "Conditions", text: $draft.conditions)
                            NoteField(title: "Entry rules", text: $draft.entry)
                        }
                    case .risk:
                        Panel(title: "GEÇERSİZLİK, HEDEF VE RİSK (İSTEĞE BAĞLI)") {
                            NoteField(title: "Invalidation rules", text: $draft.invalidation)
                            NoteField(title: "Target rules", text: $draft.target)
                            NoteField(title: "Risk rules", text: $draft.risk)
                        }
                    case .examples:
                        Panel(title: "IDEAL EXAMPLES") { ScreenshotAttachmentEditor(shots: $draft.images) }
                    }
                }.padding(24)
            }
        }.frame(width: sheetSize.width, height: sheetSize.height).background(Palette.canvas).foregroundStyle(Palette.ink).tint(Palette.mint)
            .onChange(of: draft.name) { _, _ in if error != nil { error = nil } }
    }
    private func save() {
        if let err = Self.performSaveDraft(draft, into: store) {
            self.error = err
        } else {
            dismiss()
        }
    }

    @MainActor
    static func performSaveDraft(_ draft: PlaybookDraft, into store: JournalStore) -> String? {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return "Give this setup a name." }
        guard !store.setups.contains(where: { $0.id != draft.id && $0.name.caseInsensitiveCompare(name) == .orderedSame }) else { return "A setup with this name already exists." }
        do {
            try store.commit {
                let setup: Setup
                if let existing = store.setups.first(where: { $0.id == draft.id }) {
                    setup = existing
                } else {
                    setup = Setup(id: draft.id, name: name)
                    store.context.insert(setup)
                }
                setup.name = name
                setup.summary = draft.summary.trimmingCharacters(in: .whitespacesAndNewlines)
                let p: Playbook
                if let existingBook = setup.playbook {
                    p = existingBook
                } else {
                    p = Playbook()
                    store.context.insert(p)
                    setup.playbook = p
                }
                p.conditions = draft.conditions
                p.entryRules = draft.entry
                p.invalidationRules = draft.invalidation
                p.targetRules = draft.target
                p.riskRules = draft.risk
                p.idealImagesData = try JSONEncoder().encode(draft.images)
                for trade in store.trades where trade.setupID == setup.id {
                    var changed = trade
                    changed.setupName = name
                    try store.upsert(changed)
                }
            }
            return nil
        } catch { return error.localizedDescription }
    }
}
