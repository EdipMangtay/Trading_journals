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
    @State private var editor: PlaybookDraft?
    @State private var deleting: Setup?
    @State private var viewingShot: ScreenshotDraft?
    var body: some View {
        let tradesBySetup = Dictionary(grouping: store.scopedTrades) { $0.setupID }
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top, spacing: 24) {
                    PageHeader(eyebrow: "Your models", title: "Define it. Execute it. Refine it.", subtitle: "A living playbook, linked to the performance of your actual trades.")
                    Spacer(minLength: 0)
                    Button { editor = PlaybookDraft() } label: { Label(L10n.text("New setup"), systemImage: "plus") }
                        .buttonStyle(EdgeButtonStyle()).fixedSize()
                }
                if store.setups.isEmpty {
                    Panel { EmptyJournal(title: "Codify your first setup.", subtitle: "Write the conditions, invalidation and risk rules that make an execution valid.", actionTitle: "Create setup", action: { editor = PlaybookDraft() }) }
                }
                ForEach(Array(store.setups.enumerated()), id: \.element.id) { index, setup in
                    let p = AnalyticsEngine.performance(tradesBySetup[setup.id] ?? [])
                    Panel {
                        HStack(alignment: .top, spacing: 18) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 13).fill(Palette.mint.opacity(0.08)).frame(width: 48, height: 48)
                                Image(systemName: "square.stack.3d.up").font(.system(size: 21, weight: .light)).foregroundStyle(Palette.mint)
                            }.accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 8) {
                                Text(String(format: "MODEL %02d", index + 1)).font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(1.5).foregroundStyle(Palette.mint)
                                Text(verbatim: setup.name).font(.system(size: 23, weight: .semibold)).tracking(-0.5).fixedSize(horizontal: false, vertical: true)
                                if !setup.summary.isEmpty { Text(verbatim: setup.summary).font(.system(size: 12)).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true) }
                            }
                            Spacer(minLength: 0)
                            HStack(spacing: 8) {
                                Button {
                                    do { editor = try PlaybookDraft(setup) } catch { store.report(error) }
                                } label: { Label(L10n.text("Edit"), systemImage: "square.and.pencil") }
                                    .buttonStyle(EdgeButtonStyle(prominent: false, compact: true))
                                Button { deleting = setup } label: { Image(systemName: "trash").frame(width: 14, height: 16) }
                                    .buttonStyle(EdgeButtonStyle(prominent: false, compact: true)).help(L10n.text("Delete setup")).accessibilityLabel(L10n.text("Delete setup"))
                            }
                        }
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 20, alignment: .leading), count: 5), alignment: .leading, spacing: 20) {
                            stat("SAMPLES", "\(p.count)")
                            stat("WIN RATE", Format.percent(p.winRate))
                            stat("AVG R", Format.r(p.averageR))
                            stat("EXPECTANCY", Format.money(p.expectancy, currency: store.accountCurrency))
                            stat("COMPLIANCE", Format.percent(p.compliance))
                        }.padding(17).background(Palette.raised.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
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
                                                    Button { viewingShot = shot } label: {
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
        .sheet(item: $editor) { draft in PlaybookEditor(initial: draft).environment(store) }
        .sheet(item: $viewingShot) { shot in ScreenshotViewer(initial: shot) { _ in } }
        .confirmationDialog(L10n.text("Delete this setup?"), isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button(L10n.text("Delete setup"), role: .destructive) { if let setup = deleting { do { try store.deleteSetup(setup) } catch { store.report(error) } }; deleting = nil }
        } message: { Text(L10n.text("Linked trades remain in your journal and become Unassigned. The playbook and its ideal images are deleted.")) }
    }
    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.text(label)).font(.system(size: 10, weight: .medium)).tracking(0.4).foregroundStyle(Palette.muted)
            Text(verbatim: value).font(.system(size: 20, weight: .semibold, design: .rounded)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
        }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .combine)
    }
    private func textBlock(_ label: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 18) {
            Text(L10n.text(label)).font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.muted).frame(width: 100, alignment: .leading)
            Text(verbatim: text.isEmpty ? L10n.text("Not recorded") : text).font(.system(size: 12)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
struct PlaybookEditor: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var draft: PlaybookDraft
    @State private var error: String?
    init(initial: PlaybookDraft) { _draft = State(initialValue: initial) }
    private var sheetSize: CGSize {
        let screen = (NSApp.keyWindow?.screen ?? NSScreen.main)?.visibleFrame.size ?? CGSize(width: 1200, height: 900)
        return CGSize(width: min(860, max(680, screen.width - 100)), height: min(830, max(480, screen.height - 90)))
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
                    Text("Koşullar, uygulama kuralları ve ideal örnekler").font(.system(size: 11)).foregroundStyle(Palette.muted)
                }
                Spacer(minLength: 8)
                Button(L10n.text("Cancel")) { dismiss() }.buttonStyle(EdgeButtonStyle(prominent: false, compact: true)).keyboardShortcut(.cancelAction)
                Button { save() } label: { Label(L10n.text("Save setup"), systemImage: "checkmark") }
                    .buttonStyle(EdgeButtonStyle(compact: true)).keyboardShortcut("s", modifiers: .command)
            }.padding(.horizontal, 26).padding(.vertical, 20).background(Palette.panel)
            Rectangle().fill(Palette.muted.opacity(0.12)).frame(height: 1)
            if let error {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.circle.fill").foregroundStyle(Palette.amber)
                    Text(L10n.text(error)).font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.amber)
                    Spacer()
                    Button("Kapat") { self.error = nil }.buttonStyle(EdgeButtonStyle(prominent: false, compact: true))
                }
                .padding(.horizontal, 26).padding(.vertical, 12)
                .background(Palette.amber.opacity(0.1))
                .accessibilityElement(children: .combine)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Panel(title: "STRATEJİ KİMLİĞİ") {
                        VStack(alignment: .leading, spacing: 9) {
                            HStack(spacing: 4) {
                                Text(L10n.text("Setup name")).font(.system(size: 12, weight: .medium))
                                Text("*").font(.system(size: 12, weight: .bold)).foregroundStyle(Palette.mint)
                            }
                            TextField("Örn: NY AM QT + SSMT CISD", text: $draft.name)
                                .textFieldStyle(EdgeTextFieldStyle())
                                .onSubmit { save() }
                                .accessibilityLabel(L10n.text("Setup name"))
                        }
                        VStack(alignment: .leading, spacing: 9) {
                            Text(L10n.text("Brief description")).font(.system(size: 12, weight: .medium))
                            TextField("Kısa strateji özeti (isteğe bağlı)", text: $draft.summary)
                                .textFieldStyle(EdgeTextFieldStyle())
                                .accessibilityLabel(L10n.text("Brief description"))
                        }
                    }
                    Panel(title: "Conditions & execution rules") {
                        NoteField(title: "Conditions", text: $draft.conditions)
                        NoteField(title: "Entry rules", text: $draft.entry)
                        NoteField(title: "Invalidation rules", text: $draft.invalidation)
                        NoteField(title: "Target rules", text: $draft.target)
                        NoteField(title: "Risk rules", text: $draft.risk)
                    }
                    Panel(title: "IDEAL EXAMPLES") { ScreenshotAttachmentEditor(shots: $draft.images) }
                }.padding(26)
            }
        }.frame(width: sheetSize.width, height: sheetSize.height).background(Palette.canvas).foregroundStyle(Palette.ink).tint(Palette.mint)
            .onChange(of: draft.name) { _, _ in if error != nil { error = nil } }
    }
    private func save() {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { error = "Give this setup a name."; return }
        guard !store.setups.contains(where: { $0.id != draft.id && $0.name.caseInsensitiveCompare(name) == .orderedSame }) else { error = "A setup with this name already exists."; return }
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
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
