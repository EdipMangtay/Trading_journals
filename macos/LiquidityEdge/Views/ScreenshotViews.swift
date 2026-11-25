import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct ScreenshotAttachmentEditor: View {
    @Binding var shots: [ScreenshotDraft]
    @State private var importing = false
    @State private var targeted = false
    @State private var category = "Entry"
    @State private var selected: ScreenshotDraft?
    @State private var error: String?
    @State private var loading = false
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Picker(L10n.text("Category"), selection: $category) { ForEach(Catalog.screenshotCategories, id: \.self) { Text(L10n.text($0)) } }.controlSize(.large).frame(width: 270)
                Spacer(minLength: 8)
                if loading { ProgressView().controlSize(.small) }
                Button { importing = true } label: { Label(L10n.text("Add images…"), systemImage: "photo.badge.plus") }.buttonStyle(EdgeButtonStyle(prominent: false))
            }
            VStack(spacing: 11) {
                Image(systemName: "photo.badge.plus").font(.system(size: 25, weight: .light)).foregroundStyle(Palette.mint)
                    .frame(width: 56, height: 56).background(Palette.mint.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                Text(L10n.text("Drop screenshots from Finder")).font(.system(size: 13, weight: .medium))
                Text(L10n.text("PNG, JPEG, HEIC, TIFF · up to 30 MB each")).font(.system(size: 10)).foregroundStyle(Palette.muted)
            }.frame(maxWidth: .infinity).padding(28)
                .background(targeted ? Palette.mint.opacity(0.1) : Palette.canvas.opacity(0.4), in: RoundedRectangle(cornerRadius: 13))
                .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(targeted ? Palette.mint.opacity(0.7) : Palette.muted.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [5, 5])))
                .dropDestination(for: URL.self) { urls, _ in importURLs(urls); return !urls.isEmpty } isTargeted: { targeted = $0 }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180))], spacing: 14) {
                ForEach(shots) { shot in
                    VStack(alignment: .leading, spacing: 8) {
                        Button { selected = shot } label: {
                            ScreenshotThumbnail(data: shot.thumbnailData, cacheKey: "thumb-\(shot.id.uuidString)").frame(height: 130).clipShape(RoundedRectangle(cornerRadius: 9))
                                .overlay(alignment: .bottomTrailing) { Image(systemName: "arrow.up.left.and.arrow.down.right").font(.system(size: 10)).padding(7).foregroundStyle(Palette.ink).background(Palette.panel.opacity(0.9), in: RoundedRectangle(cornerRadius: 6)).padding(7) }
                        }.buttonStyle(.plain).help(shot.name).accessibilityHint("Görseli incele ve işaretle")
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(L10n.text(shot.category)).font(.system(size: 11, weight: .medium))
                                Text(verbatim: shot.name).font(.system(size: 9)).foregroundStyle(Palette.muted).lineLimit(1)
                            }
                            Spacer(minLength: 0)
                            Button { shots.removeAll { $0.id == shot.id } } label: { Image(systemName: "trash").font(.system(size: 11)).foregroundStyle(Palette.red).frame(width: 28, height: 28).background(Palette.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 7)) }.buttonStyle(.plain).help(L10n.text("Remove attachment")).accessibilityLabel(L10n.text("Remove attachment"))
                        }
                    }.padding(10).background(Palette.raised.opacity(0.45), in: RoundedRectangle(cornerRadius: 13))
                        .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(Palette.muted.opacity(0.1)))
                }
            }
            if let error { Label(L10n.text(error), systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(Palette.amber).textSelection(.enabled) }
        }.fileImporter(isPresented: $importing, allowedContentTypes: [.image], allowsMultipleSelection: true) { result in
            switch result { case .success(let urls): importURLs(urls); case .failure(let failure): error = failure.localizedDescription }
        }.sheet(item: $selected) { shot in ScreenshotViewer(initial: shot) { changed in if let index = shots.firstIndex(where: { $0.id == changed.id }) { shots[index] = changed } } }
    }
    private func importURLs(_ urls: [URL]) {
        loading = true
        let selectedCategory = category
        Task {
            let result = await withTaskGroup(of: (Int, Result<ScreenshotDraft, Error>).self) { group -> ([ScreenshotDraft], [String]) in
                for (index, url) in urls.enumerated() {
                    group.addTask(priority: .userInitiated) {
                        (index, Result { try ScreenshotService.load(url, category: selectedCategory) })
                    }
                }
                var collected: [(Int, Result<ScreenshotDraft, Error>)] = []
                for await pair in group { collected.append(pair) }
                collected.sort { $0.0 < $1.0 }
                var imported: [ScreenshotDraft] = [], errors: [String] = []
                for (_, res) in collected {
                    switch res {
                    case .success(let shot): imported.append(shot)
                    case .failure(let err): errors.append(err.localizedDescription)
                    }
                }
                return (imported, errors)
            }
            shots.append(contentsOf: result.0); error = result.1.isEmpty ? nil : result.1.joined(separator: "\n"); loading = false
        }
    }
}
struct ScreenshotThumbnail: View {
    var data: Data
    var cacheKey: String? = nil
    var body: some View {
        Group {
            if let image = ImageCache.shared.image(for: data, key: cacheKey) {
                Image(nsImage: image).resizable().scaledToFit()
            } else {
                Image(systemName: "photo").font(.largeTitle).foregroundStyle(Palette.muted)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Palette.canvas)
    }
}
struct ScreenshotViewer: View {
    @Environment(\.dismiss) private var dismiss
    @State private var shot: ScreenshotDraft
    @State private var zoom = 1.0
    @State private var tool = "Pan"
    @State private var label = "Likidite"
    @State private var pending: ImageAnnotation?
    let onSave: (ScreenshotDraft) -> Void
    init(initial: ScreenshotDraft, onSave: @escaping (ScreenshotDraft) -> Void) { _shot = State(initialValue: initial); self.onSave = onSave }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: "photo").font(.system(size: 19)).foregroundStyle(Palette.blue)
                    .frame(width: 42, height: 42).background(Palette.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 5) {
                    Text("GÖRSEL İNCELEME").font(.system(size: 9, weight: .semibold)).tracking(1.4).foregroundStyle(Palette.muted)
                    Text(verbatim: shot.name).font(.system(size: 13, weight: .semibold)).lineLimit(1).help(shot.name)
                }
                Spacer(minLength: 8)
                Picker(L10n.text("Category"), selection: $shot.category) { ForEach(Catalog.screenshotCategories, id: \.self) { Text(L10n.text($0)) } }.controlSize(.large).frame(width: 225)
                Button(L10n.text("Cancel")) { dismiss() }.buttonStyle(EdgeButtonStyle(prominent: false)).keyboardShortcut(.cancelAction)
                Button(L10n.text("Save review")) { onSave(shot); dismiss() }.buttonStyle(EdgeButtonStyle())
            }.padding(20)
            Rectangle().fill(Palette.muted.opacity(0.12)).frame(height: 1)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Picker(L10n.text("Tool"), selection: $tool) {
                        ForEach(["Pan", "Arrow", "Rectangle", "Text", "Liquidity marker"], id: \.self) { Text(L10n.text($0)) }
                    }.pickerStyle(.segmented).labelsHidden().controlSize(.large).frame(maxWidth: 620)
                        .accessibilityLabel(L10n.text("Tool"))
                    Spacer(minLength: 0)
                }
                HStack(spacing: 12) {
                    if tool == "Text" || tool == "Liquidity marker" {
                        Text(L10n.text("Label")).font(.system(size: 11, weight: .medium)).foregroundStyle(Palette.muted)
                        TextField(L10n.text("Label"), text: $label).textFieldStyle(EdgeTextFieldStyle()).frame(width: 200)
                    }
                    Spacer(minLength: 0)
                    Button { if !shot.annotations.isEmpty { shot.annotations.removeLast() } } label: { Image(systemName: "arrow.uturn.backward") }
                        .buttonStyle(EdgeButtonStyle(prominent: false, compact: true)).disabled(shot.annotations.isEmpty)
                        .help(L10n.text("Undo last annotation")).accessibilityLabel(L10n.text("Undo last annotation"))
                    HStack(spacing: 9) {
                        Image(systemName: "minus.magnifyingglass").font(.system(size: 12)).foregroundStyle(Palette.muted)
                        Slider(value: $zoom, in: 0.5...4).tint(Palette.mint).frame(width: 140).accessibilityLabel("Görsel yakınlaştırma")
                        Text(L10n.text("\(Int(zoom * 100))%")).font(.system(size: 11, weight: .medium, design: .monospaced)).frame(width: 47, alignment: .trailing)
                    }.padding(.horizontal, 8)
                    Button { NSApp.keyWindow?.toggleFullScreen(nil) } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                        .buttonStyle(EdgeButtonStyle(prominent: false, compact: true)).help(L10n.text("Toggle full screen")).accessibilityLabel(L10n.text("Toggle full screen"))
                }.frame(minHeight: 36)
            }.padding(.horizontal, 20).padding(.vertical, 14).background(Palette.raised.opacity(0.2))
            Rectangle().fill(Palette.muted.opacity(0.12)).frame(height: 1)
            GeometryReader { available in
                ScrollView([.horizontal, .vertical]) {
                    if let image = ImageCache.shared.image(for: shot.imageData, key: "full-\(shot.id.uuidString)") {
                        let scale = min(available.size.width / max(image.size.width, 1), available.size.height / max(image.size.height, 1))
                        let size = CGSize(width: image.size.width * scale * zoom, height: image.size.height * scale * zoom)
                        ZStack(alignment: .topLeading) {
                            Image(nsImage: image).resizable().frame(width: size.width, height: size.height)
                            AnnotationLayer(annotations: shot.annotations + (pending.map { [$0] } ?? [])).frame(width: size.width, height: size.height).allowsHitTesting(false)
                            if tool != "Pan" {
                                Color.clear.contentShape(Rectangle()).frame(width: size.width, height: size.height).gesture(DragGesture(minimumDistance: 0).onChanged { value in pending = annotation(value, size: size) }.onEnded { value in shot.annotations.append(annotation(value, size: size)); pending = nil })
                            }
                        }.frame(minWidth: available.size.width, minHeight: available.size.height)
                    }
                }
            }.background(Palette.canvas)
            HStack(spacing: 16) {
                Label(L10n.text("\(shot.annotations.count) annotations · Drag to draw; choose Pan to scroll."), systemImage: "pencil.tip.crop.circle")
                Spacer(minLength: 8)
                Text(L10n.text("Original image remains intact."))
            }.font(.system(size: 10)).foregroundStyle(Palette.muted).padding(.horizontal, 20).padding(.vertical, 14)
        }.frame(width: sheetSize.width, height: sheetSize.height).background(Palette.panel).foregroundStyle(Palette.ink).tint(Palette.mint)
    }
    private var sheetSize: CGSize {
        let visible = (NSApp.keyWindow?.screen ?? NSScreen.main)?.visibleFrame.size ?? CGSize(width: 1280, height: 900)
        return CGSize(width: min(1120, max(780, visible.width - 96)), height: min(860, max(480, visible.height - 80)))
    }
    private func annotation(_ value: DragGesture.Value, size: CGSize) -> ImageAnnotation {
        func clamp(_ value: Double) -> Double { min(1, max(0, value)) }
        return ImageAnnotation(kind: tool, x: clamp(value.startLocation.x / size.width), y: clamp(value.startLocation.y / size.height), endX: clamp(value.location.x / size.width), endY: clamp(value.location.y / size.height), text: label)
    }
}
struct AnnotationLayer: View {
    var annotations: [ImageAnnotation]
    var body: some View {
        Canvas { context, size in
            for a in annotations {
                let start = CGPoint(x: a.x * size.width, y: a.y * size.height), end = CGPoint(x: a.endX * size.width, y: a.endY * size.height)
                var path = Path()
                if a.kind == "Rectangle" { path.addRect(CGRect(x: min(start.x, end.x), y: min(start.y, end.y), width: abs(end.x - start.x), height: abs(end.y - start.y))) }
                else if a.kind == "Arrow" {
                    path.move(to: start); path.addLine(to: end)
                    let angle = atan2(end.y - start.y, end.x - start.x)
                    for delta in [-0.5, 0.5] { path.move(to: end); path.addLine(to: CGPoint(x: end.x - 14 * cos(angle + delta), y: end.y - 14 * sin(angle + delta))) }
                } else if a.kind == "Liquidity marker" { path.move(to: start); path.addLine(to: CGPoint(x: end.x, y: start.y)) }
                context.stroke(path, with: .color(Palette.amber), lineWidth: 2)
                if a.kind == "Text" || a.kind == "Liquidity marker" { context.draw(Text(a.text).font(.system(size: 14, weight: .semibold)).foregroundColor(Palette.amber), at: CGPoint(x: start.x, y: max(12, start.y - 12)), anchor: .leading) }
            }
        }
        .drawingGroup()
    }
}
struct ScreenshotLibraryView: View {
    @Environment(JournalStore.self) private var store
    var openTrade: (TradeRecord) -> Void
    @State private var category = "All"
    @State private var selected: ScreenshotDraft?
    @State private var selectedTradeID: UUID?
    private var items: [(TradeRecord, TradeScreenshot)] { store.scopedTrades.flatMap { trade in (store.model(trade.id)?.screenshots ?? []).filter { category == "All" || $0.category == category }.map { (trade, $0) } } }
    var body: some View {
        let visibleItems = items
        ScrollView { LazyVStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top, spacing: 24) {
                PageHeader(eyebrow: "Visual memory", title: "Build your pattern library.", subtitle: "Context, entry and review images linked to real executions.")
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 10) {
                    Picker(L10n.text("Category"), selection: $category) { ForEach(["All"] + Catalog.screenshotCategories, id: \.self) { Text(L10n.text($0)) } }.controlSize(.large).frame(width: 235)
                    Text("\(visibleItems.count) görsel").font(.system(size: 10, weight: .medium)).foregroundStyle(Palette.muted)
                }
            }
            if visibleItems.isEmpty { EmptyJournal(title: "Your visual library is empty.", subtitle: "Attach screenshots to a trade. Review them here by stage.") }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260))], spacing: 18) {
                ForEach(visibleItems, id: \.1.id) { trade, shot in
                    Panel {
                        Button { do { selected = try ScreenshotDraft(shot); selectedTradeID = trade.id } catch { store.report(error) } } label: {
                            ScreenshotThumbnail(data: shot.thumbnailData, cacheKey: "thumb-\(shot.id.uuidString)").frame(height: 190).clipShape(RoundedRectangle(cornerRadius: 11))
                                .overlay(alignment: .bottomTrailing) { Image(systemName: "arrow.up.left.and.arrow.down.right").font(.system(size: 11)).padding(8).foregroundStyle(Palette.ink).background(Palette.panel.opacity(0.9), in: RoundedRectangle(cornerRadius: 7)).padding(9) }
                        }.buttonStyle(.plain).help(shot.name).accessibilityHint("Görsel incelemesini aç")
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 10) {
                                Text(verbatim: trade.instrument).font(.system(size: 15, weight: .semibold))
                                Spacer(minLength: 0)
                                Text(Format.r(trade.rMultiple)).font(.system(size: 15, weight: .medium, design: .rounded)).monospacedDigit().foregroundStyle(Palette.outcome(trade.netPnL))
                            }
                            HStack { Badge(text: shot.category); Spacer(minLength: 0); Text(Format.date(trade.date, calendar: store.preferences.calendar)).font(.system(size: 9)).foregroundStyle(Palette.muted) }
                            Text(verbatim: shot.name).font(.system(size: 10)).foregroundStyle(Palette.muted).lineLimit(1)
                        }
                        Button(L10n.text("Open trade →")) { openTrade(trade) }.buttonStyle(EdgeButtonStyle(prominent: false, compact: true))
                    }
                }
            }
        }.pagePadding() }
        .onAppear {
            let entries = visibleItems.prefix(40).map { (data: $0.1.thumbnailData, key: "thumb-\($0.1.id.uuidString)") }
            ImageCache.shared.prewarm(entries)
        }
        .sheet(item: $selected) { shot in ScreenshotViewer(initial: shot) { changed in
            guard let id = selectedTradeID, let record = store.trades.first(where: { $0.id == id }) else { return }
            do { var all = try (store.model(id)?.screenshots ?? []).map(ScreenshotDraft.init); if let index = all.firstIndex(where: { $0.id == changed.id }) { all[index] = changed }; try store.save(record, screenshots: all) } catch { store.report(error) }
        } }
    }
}
