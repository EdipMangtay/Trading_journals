import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct SettingsView: View {
    @Environment(JournalStore.self) private var store
    var openDemo: () -> Void
    @State private var preferences = JournalPreferences()
    @State private var customInstrument = ""
    @State private var customRule = ""
    @State private var customSession = ""
    @State private var message: String?
    @State private var loaded = false
    var body: some View {
        ScrollView { LazyVStack(alignment: .leading, spacing: 24) {
            PageHeader(eyebrow: "Workspace preferences", title: "Make it your journal.", subtitle: "Local storage, clear defaults and data you control.")
            appearancePanel
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 20) {
                    sessionsPanel.frame(minWidth: 420)
                    VStack(spacing: 20) { instrumentsPanel; rulesPanel }.frame(minWidth: 360)
                }
                VStack(spacing: 20) { sessionsPanel; instrumentsPanel; rulesPanel }
            }
            Panel(title: "DATA & BACKUP", subtitle: "NO CLOUD · NO ACCOUNT REQUIRED") {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: store.isDemo ? "sparkles" : "internaldrive.fill").font(.system(size: 25)).foregroundStyle(store.isDemo ? Palette.amber : Palette.mint).frame(width: 48, height: 48).background(Palette.mint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(store.isDemo ? "Örnek çalışma alanı" : "Verilerin bu Mac’te, senin kontrolünde.").font(.headline)
                        Text(store.isDemo ? "Bu alan geçicidir. Gerçek günlüğün ayrı tutulur." : "İşlemler ve görseller kaydettiğin anda yerel diske yazılır. Uygulama kayıtlarını kendiliğinden silmez.").font(.callout).foregroundStyle(Palette.muted)
                    }
                    Spacer(minLength: 0)
                    Badge(text: store.isDemo ? "DEMO" : "YEREL KAYIT", color: store.isDemo ? Palette.amber : Palette.mint)
                }
                if let url = store.storageURL {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("KAYIT KONUMU").font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(1).foregroundStyle(Palette.muted)
                        Text(url.path).font(.system(size: 11, design: .monospaced)).foregroundStyle(Palette.muted).textSelection(.enabled).lineLimit(3)
                        Button { NSWorkspace.shared.activateFileViewerSelecting([url]) } label: { Label("Finder’da göster", systemImage: "folder") }.buttonStyle(EdgeButtonStyle(prominent: false))
                    }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(Palette.raised.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
                }
                if !store.isDemo {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath").foregroundStyle(Palette.blue)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Otomatik yerel yedekler").font(.system(size: 13, weight: .semibold))
                            Text("Günlük kurtarma kopyaları ve silme / içe aktarma öncesi yedekler saklanır. Yedekler otomatik temizlenmez.").font(.caption).foregroundStyle(Palette.muted)
                            if let date = store.lastBackupDate { Text("Son yedek: " + Format.date(date, calendar: store.preferences.calendar, time: true)).font(.caption).foregroundStyle(Palette.mint) }
                            if let error = store.backupErrorMessage { Text(error).font(.caption).foregroundStyle(Palette.amber).textSelection(.enabled) }
                        }
                        Spacer(minLength: 0)
                    }
                    HStack {
                        Button { createLocalBackup() } label: { Label("Şimdi yedekle", systemImage: "externaldrive.badge.plus") }.buttonStyle(EdgeButtonStyle(prominent: false))
                        if let folder = store.backupDirectoryURL {
                            Button { openBackupFolder(folder) } label: { Label("Yedek klasörü", systemImage: "folder") }.buttonStyle(EdgeButtonStyle(prominent: false))
                        }
                    }
                }
                Divider().overlay(Palette.muted.opacity(0.12))
                Text(L10n.text("A JSON backup includes every trade, screenshot, annotation, playbook, review, instrument, custom rule and saved preference.")).font(.callout)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), alignment: .leading)], alignment: .leading, spacing: 10) {
                    Button { export(csv: false) } label: { Label("JSON yedeği dışa aktar", systemImage: "square.and.arrow.up") }.buttonStyle(EdgeButtonStyle(prominent: false))
                    Button { export(csv: true) } label: { Label(L10n.text("Export CSV"), systemImage: "tablecells") }.buttonStyle(EdgeButtonStyle(prominent: false))
                    Button { openImportPanel(csv: false) } label: { Label(L10n.text("Restore backup…"), systemImage: "arrow.counterclockwise") }.buttonStyle(EdgeButtonStyle(prominent: false))
                    Button { openImportPanel(csv: true) } label: { Label(L10n.text("Import CSV…"), systemImage: "square.and.arrow.down") }.buttonStyle(EdgeButtonStyle(prominent: false))
                }
                Text(L10n.text("Restore merges by trade ID and replaces matching records. Other trades remain. Review the import count before applying. CSV preserves all trade fields in record_json; screenshots and playbooks require JSON backup.")).font(.caption).foregroundStyle(Palette.muted)
                if store.isDemo { Badge(text: "DEMO EXPORT CONTAINS SAMPLE DATA", color: Palette.amber) } else { Button(L10n.text("Explore isolated demo"), action: openDemo).buttonStyle(EdgeButtonStyle(prominent: false)) }
            }
            if let message {
                Label(L10n.text(message), systemImage: "checkmark.circle.fill").font(.system(size: 12)).foregroundStyle(Palette.mint).textSelection(.enabled)
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading).background(Palette.mint.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
            }
            Panel(title: "LIQUIDITY EDGE / v6.0", subtitle: "NATIVE MACOS · METAL & ACCELERATE ENGINE", accent: Palette.mint) {
                HStack(alignment: .center, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.text("Professional Trading Performance Journal\nBuilt around discipline, pattern recognition and execution quality.")).font(.callout).foregroundStyle(Palette.muted)
                        HStack(spacing: 8) {
                            Image(systemName: "cpu.fill").font(.system(size: 11)).foregroundStyle(Palette.mint)
                            Text(verbatim: HardwareProfile.badgeLabel)
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Palette.ink.opacity(0.9))
                        }
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Palette.mint.opacity(0.08), in: Capsule())
                        .overlay(Capsule().strokeBorder(Palette.mint.opacity(0.24), lineWidth: 0.8))
                    }
                    Spacer(minLength: 12)
                    HStack(spacing: 10) {
                        Badge(text: "\(store.trades.count) işlem", color: Palette.mint)
                        Badge(text: "\(store.workspace.accounts.count) hesap", color: Palette.blue)
                        Badge(text: "\(store.setups.count) playbook", color: Palette.muted)
                    }
                }
            }
        }.pagePadding() }
        .onAppear { if !loaded { preferences = store.preferences; loaded = true } }
    }
    private func openImportPanel(csv: Bool) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = csv ? [.commaSeparatedText, .plainText] : [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= 512_000_000 else { throw JournalError(message: "Import is limited to 512 MB.") }
            let data = try Data(contentsOf: url)
            if csv {
                guard let text = String(data: data, encoding: .utf8) else { throw JournalError(message: "CSV must use UTF-8 encoding.") }
                let records = try CSVCodec.decode(text)
                for record in records { if let error = record.validationError { throw JournalError(message: error) } }
                if ConfirmDialog.confirm(
                    title: "Import \(records.count) trades into \(store.isDemo ? "the demo workspace" : "your journal")?",
                    message: "Matching IDs will be updated. Other trades remain. Keep a current backup before updating existing records.",
                    confirmTitle: "Import and merge"
                ) {
                    _ = try BackupService.importCSV(text, into: store)
                    message = "Imported \(records.count) trades successfully."
                }
            } else {
                let backup = try BackupService.decode(data)
                if ConfirmDialog.confirm(
                    title: "Import \(backup.trades.count) trades into \(store.isDemo ? "the demo workspace" : "your journal")?",
                    message: "Matching IDs will be updated. Other trades remain. JSON restore also merges playbooks and reviews and applies saved preferences. Keep a current backup before updating existing records.",
                    confirmTitle: "Import and merge"
                ) {
                    try BackupService.restore(backup, into: store)
                    preferences = store.preferences
                    message = "Imported \(backup.trades.count) trades successfully."
                }
            }
        } catch { store.report(error) }
    }
    private var appearancePanel: some View {
        Panel(title: "ACCOUNT & APPEARANCE", subtitle: "Hesap varsayılanları ve çalışma ortamı") {
            HStack(alignment: .top, spacing: 16) {
                settingsField("Default account size") { TextField(L10n.text("Default account size"), value: $preferences.accountSize, format: .number) }
                settingsField("Default risk %") { TextField(L10n.text("Default risk %"), value: $preferences.defaultRiskPercent, format: .number) }
                settingsField("Currency") { TextField(L10n.text("Currency"), text: $preferences.currency) }.frame(width: 130)
            }
            Rectangle().fill(Palette.muted.opacity(0.1)).frame(height: 1)
            HStack(alignment: .center, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Label(L10n.text("Theme"), systemImage: "circle.lefthalf.filled").font(.system(size: 12, weight: .medium))
                    SegmentedTabs(options: ["Dark", "Light", "System"], selection: $preferences.theme, title: { $0 })
                }
                Spacer(minLength: 16)
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(L10n.text("Animations"), isOn: $preferences.animations).toggleStyle(.switch).font(.system(size: 12))
                    Text("Azaltılmış hareket tercihinize uyulur.").font(.system(size: 10)).foregroundStyle(Palette.muted)
                }
            }
            settingsField("Trading time zone") { TextField(L10n.text("Trading time zone"), text: $preferences.timezone) }
            Text(L10n.text("Use an IANA time zone, such as America/New_York or Europe/Istanbul. Calendar and hour analytics use this zone; timestamps are stored as absolute instants. Currency changes display units and does not convert values."))
                .font(.system(size: 11)).foregroundStyle(Palette.muted).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
            HStack {
                Button(action: savePreferences) { Label(L10n.text("Save preferences"), systemImage: "checkmark") }.buttonStyle(EdgeButtonStyle())
                Spacer()
                Label("Bu çalışma alanına uygulanır", systemImage: "slider.horizontal.3").font(.system(size: 10)).foregroundStyle(Palette.muted)
            }
        }
    }
    private var sessionsPanel: some View {
        Panel(title: "TRADING SESSIONS", subtitle: "Seans adları ve referans saatleri") {
            VStack(spacing: 10) {
                ForEach(preferences.sessions, id: \.self) { session in
                    HStack(spacing: 12) {
                        Image(systemName: "clock").font(.system(size: 13)).foregroundStyle(Palette.blue).frame(width: 30, height: 34).background(Palette.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 7) {
                            Text(L10n.text(session)).font(.system(size: 12, weight: .medium)).lineLimit(2)
                            TextField(L10n.text("Session hours"), text: Binding(get: { preferences.sessionHours[session] ?? "" }, set: { preferences.sessionHours[session] = $0 })).textFieldStyle(EdgeTextFieldStyle()).accessibilityLabel(L10n.text(session) + " · " + L10n.text("Session hours"))
                        }
                        Button { preferences.sessions.removeAll { $0 == session }; preferences.sessionHours.removeValue(forKey: session) } label: { Image(systemName: "minus.circle").foregroundStyle(Palette.muted) }.buttonStyle(EdgeButtonStyle(prominent: false, compact: true)).disabled(preferences.sessions.count <= 1).help(L10n.text(session) + " seansını kaldır")
                    }
                }
            }
            HStack(spacing: 10) {
                TextField(L10n.text("Custom session"), text: $customSession).textFieldStyle(EdgeTextFieldStyle()).onSubmit { addSession() }
                Button(action: addSession) { Label(L10n.text("Add session"), systemImage: "plus") }.buttonStyle(EdgeButtonStyle(prominent: false, compact: true)).disabled(customSession.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            Text(L10n.text("Session hours are your reference schedule. Choose the session explicitly on each trade. Save preferences to apply changes.")).font(.system(size: 11)).foregroundStyle(Palette.muted).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
        }
    }
    private var instrumentsPanel: some View {
        Panel(title: "ALLOWED INSTRUMENTS", subtitle: "İşlem formundaki seçenekler") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), alignment: .leading)], alignment: .leading, spacing: 10) {
                ForEach(store.instruments, id: \.id) { instrument in
                    Toggle(instrument.symbol, isOn: Binding(get: { instrument.enabled }, set: { value in do { try store.commit { instrument.enabled = value } } catch { store.report(error) } }))
                        .toggleStyle(.checkbox).font(.system(size: 12, weight: .medium)).frame(maxWidth: .infinity, alignment: .leading).padding(11)
                        .background(instrument.enabled ? Palette.mint.opacity(0.055) : Palette.canvas.opacity(0.4), in: RoundedRectangle(cornerRadius: 9))
                        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(instrument.enabled ? Palette.mint.opacity(0.15) : Palette.muted.opacity(0.08)))
                }
            }
            HStack(spacing: 10) {
                TextField(L10n.text("Custom symbol"), text: $customInstrument).textFieldStyle(EdgeTextFieldStyle()).onSubmit { addInstrument() }
                Button(action: addInstrument) { Label(L10n.text("Add instrument"), systemImage: "plus") }.buttonStyle(EdgeButtonStyle(prominent: false, compact: true)).disabled(customInstrument.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
    private var rulesPanel: some View {
        Panel(title: "CUSTOM RULES", subtitle: "Kişisel süreç kontrol listeniz") {
            if store.customRules.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.shield").foregroundStyle(Palette.blue)
                    Text("Kendi işlem kurallarınızı ekleyin; işlem kaydında ve süreç incelemesinde kullanın.").font(.system(size: 11)).foregroundStyle(Palette.muted).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                }.padding(.vertical, 4)
            }
            ForEach(store.customRules, id: \.id) { rule in
                HStack(spacing: 10) {
                    Circle().fill(Palette.mint).frame(width: 5, height: 5)
                    Text(verbatim: rule.name).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    Button { do { try store.commit { store.context.delete(rule) } } catch { store.report(error) } } label: { Image(systemName: "trash").foregroundStyle(Palette.muted) }.buttonStyle(EdgeButtonStyle(prominent: false, compact: true)).help(rule.name + " kuralını kaldır")
                }.padding(10).background(Palette.canvas.opacity(0.3), in: RoundedRectangle(cornerRadius: 9))
            }
            HStack(spacing: 10) {
                TextField(L10n.text("Rule name"), text: $customRule).textFieldStyle(EdgeTextFieldStyle()).onSubmit { addRule() }
                Button(action: addRule) { Label(L10n.text("Add rule"), systemImage: "plus") }.buttonStyle(EdgeButtonStyle(prominent: false, compact: true)).disabled(customRule.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Text(L10n.text("Custom setups and their rule definitions are managed in Playbook.")).font(.system(size: 11)).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
        }
    }
    private func settingsField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.text(title)).font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.muted)
            content().textFieldStyle(EdgeTextFieldStyle())
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func openBackupFolder(_ url: URL) {
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            if !NSWorkspace.shared.open(url) { throw JournalError(message: "Yedek klasörü açılamadı.") }
        } catch { store.report(error) }
    }
    private func createLocalBackup() {
        do {
            if let url = try store.createRecoverySnapshot(reason: "manual") { message = "Yerel yedek oluşturuldu: \(url.lastPathComponent)" }
        } catch { store.report(error) }
    }
    private func addSession() {
        let name = customSession.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty && !preferences.sessions.contains(name) {
            preferences.sessions.append(name)
            preferences.sessionHours[name] = ""
            customSession = ""
        }
    }
    private func savePreferences() {
        let original = store.preferences
        preferences.currency = preferences.currency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        preferences.timezone = preferences.timezone.trimmingCharacters(in: .whitespacesAndNewlines)
        do { store.preferences = preferences; try store.savePreferences(); message = "Preferences saved." } catch { store.preferences = original; store.report(error) }
    }
    private func addInstrument() {
        let symbol = customInstrument.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !symbol.isEmpty, !store.instruments.contains(where: { $0.symbol == symbol }) else { return }
        do { try store.commit { store.context.insert(Instrument(symbol: symbol)) }; customInstrument = "" } catch { store.report(error) }
    }
    private func addRule() {
        let name = customRule.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !store.customRules.contains(where: { $0.name == name }), !Catalog.rules.contains(name) else { return }
        do { try store.commit { store.context.insert(CustomRule(name: name)) }; customRule = "" } catch { store.report(error) }
    }
    private func export(csv: Bool) {
        do {
            let data = csv ? Data(try CSVCodec.export(store.trades).utf8) : try BackupService.encode(BackupService.archive(store))
            let panel = NSSavePanel(); panel.allowedContentTypes = csv ? [.commaSeparatedText] : [.json]; panel.nameFieldStringValue = "LiquidityEdge-\(Date().formatted(.iso8601.year().month().day().dateSeparator(.dash)))\(csv ? ".csv" : ".json")"
            guard panel.runModal() == .OK, let url = panel.url else { return }
            try data.write(to: url, options: .atomic); message = "Exported \(store.trades.count) trades to \(url.lastPathComponent)."
        } catch { store.report(error) }
    }
}
