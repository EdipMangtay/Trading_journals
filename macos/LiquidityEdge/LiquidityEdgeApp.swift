import SwiftUI
import AppKit

@MainActor @Observable final class AppRuntime {
    var store: JournalStore?
    var launchError: String?
    init() { load(demo: false) }
    func load(demo: Bool) {
        do {
            var storageURL: URL?
            if !demo, let directory = ProcessInfo.processInfo.environment["JOURNAL_TEST_DATA_DIR"] {
                let folder = URL(fileURLWithPath: directory, isDirectory: true)
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                storageURL = folder.appendingPathComponent("Journal.store")
            }
            let newStore = try JournalStore(demo: demo, storageURL: storageURL)
            store = newStore; launchError = nil
            if !demo && storageURL == nil { UserDefaults.standard.set(true, forKey: "journal.started") }
        }
        catch { launchError = error.localizedDescription; store?.report(error) }
    }
}
@MainActor final class JournalApplicationDelegate: NSObject, NSApplicationDelegate {
    var openMainWindow: (() -> Void)?
    let menuBarController = MenuBarController()
    private var menuBarAttached = false

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return false
    }

    func attachMenuBar(runtime: AppRuntime) {
        guard !menuBarAttached else {
            menuBarController.updateStatusButton()
            return
        }
        menuBarAttached = true
        menuBarController.attach(
            storeProvider: { runtime.store },
            openMainWindow: { [weak self] in self?.showMainWindow() },
            openNewTrade: { [weak self] in
                self?.showMainWindow {
                    NotificationCenter.default.post(name: .newTrade, object: nil)
                }
            },
            openDailyPlan: { [weak self] in
                self?.showMainWindow {
                    NotificationCenter.default.post(name: .openPage, object: JournalPage.planning)
                }
            },
            openCommandPalette: { [weak self] in
                self?.showMainWindow {
                    NotificationCenter.default.post(name: .commandPalette, object: nil)
                }
            }
        )
    }

    func showMainWindow(then action: (() -> Void)? = nil) {
        let existing = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" || $0.title == "LIQUIDITY EDGE" })
        if let window = existing {
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            if let action {
                DispatchQueue.main.async { action() }
            }
        } else {
            openMainWindow?()
            NSApp.activate(ignoringOtherApps: true)
            if let action {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) { action() }
            }
        }
    }
}
private struct MainWindowReopenBridge: View {
    let delegate: JournalApplicationDelegate
    let runtime: AppRuntime
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Color.clear.frame(width: 0, height: 0).onAppear {
            let action = openWindow
            delegate.openMainWindow = { action(id: "main") }
            delegate.attachMenuBar(runtime: runtime)
        }
    }
}
@main struct LiquidityEdgeApp: App {
    @NSApplicationDelegateAdaptor(JournalApplicationDelegate.self) private var applicationDelegate
    @State private var runtime = AppRuntime()
    var body: some Scene {
        Window("LIQUIDITY EDGE", id: "main") {
            Group {
                if let store = runtime.store {
                    RootView(startJournal: { runtime.load(demo: false) }, openDemo: { runtime.load(demo: true) })
                        .environment(store).id(ObjectIdentifier(store))
                        .preferredColorScheme(store.preferences.theme == "System" ? nil : store.preferences.theme == "Light" ? .light : .dark)
                        .onChange(of: store.revision) { _, _ in
                            applicationDelegate.menuBarController.updateStatusButton()
                        }
                } else {
                    VStack(spacing: 24) {
                        Image(systemName: "externaldrive.badge.exclamationmark").font(.system(size: 32, weight: .light)).foregroundStyle(Palette.amber)
                            .frame(width: 80, height: 80).background(Palette.amber.opacity(0.08), in: RoundedRectangle(cornerRadius: 22))
                        VStack(spacing: 12) {
                            Text(L10n.text("Unable to open your journal")).font(.system(size: 25, weight: .semibold)).tracking(-0.7)
                            Text(L10n.text(runtime.launchError ?? "Unknown storage error")).font(.system(size: 13)).foregroundStyle(Palette.muted).multilineTextAlignment(.center).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                        }
                        Button { runtime.load(demo: false) } label: { Label(L10n.text("Retry"), systemImage: "arrow.clockwise") }.buttonStyle(EdgeButtonStyle())
                    }.padding(40).frame(maxWidth: 560).background(Palette.panel, in: RoundedRectangle(cornerRadius: 22))
                        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Palette.muted.opacity(0.13)))
                        .frame(maxWidth: .infinity, maxHeight: .infinity).background(Palette.canvas).foregroundStyle(Palette.ink)
                }
            }.background(MainWindowReopenBridge(delegate: applicationDelegate, runtime: runtime)).environment(\.locale, L10n.locale).frame(minWidth: 1060, minHeight: 720)
        }.defaultSize(width: 1440, height: 960).windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .appSettings) { Button(L10n.text("Settings") + "…") { NotificationCenter.default.post(name: .openSettings, object: nil) }.keyboardShortcut(",", modifiers: .command) }
            CommandGroup(replacing: .newItem) { Button(L10n.text("New Trade")) { NotificationCenter.default.post(name: .newTrade, object: nil) }.keyboardShortcut("n", modifiers: .command) }
            CommandGroup(after: .newItem) { Button(L10n.text("Search & Commands")) { NotificationCenter.default.post(name: .commandPalette, object: nil) }.keyboardShortcut("k", modifiers: .command) }
        }
    }
}
