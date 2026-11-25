import SwiftUI
import AppKit

struct ReviewDraft: Identifiable {
    var id = UUID(), period = "Weekly", date = Date(), worked = "", didNot = "", repeatNext = "", stop = "", adjustment = ""
    init() {}
    init(_ review: Review) { id = review.id; period = review.period; date = review.date; worked = review.worked; didNot = review.didNot; repeatNext = review.repeatNext; stop = review.stop; adjustment = review.adjustment }
}
struct ReviewsView: View {
    @Environment(JournalStore.self) private var store
    @State private var draft: ReviewDraft?
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top, spacing: 24) {
                    PageHeader(eyebrow: "Deliberate practice", title: "Turn experience into improvement.", subtitle: "Daily, weekly and monthly reviews anchored in your trade data.")
                    Spacer(minLength: 0)
                    Button { draft = ReviewDraft() } label: { Label(L10n.text("New review"), systemImage: "plus") }
                        .buttonStyle(EdgeButtonStyle()).fixedSize()
                }
                if store.reviews.isEmpty {
                    Panel { EmptyJournal(title: "Close the feedback loop.", subtitle: "Summarize what worked, identify the recurring mistake, and choose one adjustment.", actionTitle: "Start a review", action: { draft = ReviewDraft() }) }
                }
                ForEach(store.reviews, id: \.id) { review in
                    Panel(accent: Palette.blue) {
                        HStack(alignment: .top, spacing: 18) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 13).fill(Palette.blue.opacity(0.08)).frame(width: 48, height: 48)
                                Image(systemName: "checkmark.rectangle").font(.system(size: 22, weight: .light)).foregroundStyle(Palette.blue)
                            }.accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 10) {
                                Badge(text: review.period.uppercased(), color: Palette.blue)
                                Text(Format.date(review.date, calendar: store.preferences.calendar)).font(.system(size: 23, weight: .semibold)).tracking(-0.5)
                            }
                            Spacer(minLength: 0)
                            HStack(spacing: 8) {
                                Button { draft = ReviewDraft(review) } label: { Label(L10n.text("Open review"), systemImage: "arrow.up.right") }
                                    .buttonStyle(EdgeButtonStyle(prominent: false, compact: true))
                                Button(role: .destructive) {
                                    _ = Self.performDeleteReview(review, in: store)
                                } label: { Image(systemName: "trash").frame(width: 14, height: 16) }
                                    .buttonStyle(EdgeButtonStyle(prominent: false, compact: true)).help(L10n.text("Delete review")).accessibilityLabel(L10n.text("Delete review"))
                            }
                        }
                        VStack(alignment: .leading, spacing: 9) {
                            Label("SONRAKİ DÖNEM İÇİN ODAK", systemImage: "scope").font(.system(size: 10, weight: .semibold)).tracking(0.6).foregroundStyle(Palette.blue)
                            Text(verbatim: review.adjustment.isEmpty ? L10n.text("No adjustment recorded.") : review.adjustment)
                                .font(.system(size: 13)).foregroundStyle(review.adjustment.isEmpty ? Palette.muted : Palette.ink).fixedSize(horizontal: false, vertical: true)
                        }.padding(17).frame(maxWidth: .infinity, alignment: .leading).background(Palette.raised.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }.pagePadding()
        }
        .sheet(item: $draft) { initial in ReviewEditor(initial: initial).environment(store) }
    }

    @MainActor @discardableResult
    static func performDeleteReview(_ review: Review, in store: JournalStore) -> Bool {
        if ConfirmDialog.confirm(
            title: "Delete this review?",
            message: "Bu değerlendirme kaydı kalıcı olarak silinecek.",
            confirmTitle: "Delete review",
            destructive: true
        ) {
            do { try store.commit { store.context.delete(review) }; return true } catch { store.report(error) }
        }
        return false
    }
}
struct ReviewEditor: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ReviewDraft
    @State private var error: String?
    init(initial: ReviewDraft) { _draft = State(initialValue: initial) }
    private var interval: DateInterval { store.preferences.calendar.dateInterval(of: draft.period == "Daily" ? .day : draft.period == "Monthly" ? .month : .weekOfYear, for: draft.date)! }
    private var sheetSize: CGSize {
        let screen = (NSApp.keyWindow?.screen ?? NSScreen.main)?.visibleFrame.size ?? CGSize(width: 1200, height: 900)
        return CGSize(width: min(880, max(680, screen.width - 100)), height: min(850, max(480, screen.height - 90)))
    }
    var body: some View {
        let trades = store.scopedTrades.filter { $0.date >= interval.start && $0.date < interval.end }, p = AnalyticsEngine.performance(trades)
        let setups = AnalyticsEngine.groups(trades, by: .setup, calendar: store.preferences.calendar).sorted { ($0.performance.averageR ?? -.infinity) > ($1.performance.averageR ?? -.infinity) }
        let best = trades.max { $0.netPnL < $1.netPnL }, worst = trades.min { $0.netPnL < $1.netPnL }
        VStack(spacing: 0) {
            HStack(spacing: 15) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11).fill(Palette.blue.opacity(0.09)).frame(width: 42, height: 42)
                    Image(systemName: "checkmark.rectangle").font(.system(size: 20, weight: .medium)).foregroundStyle(Palette.blue)
                }.accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.text("Performance review")).font(.system(size: 20, weight: .semibold)).tracking(-0.4)
                    Text("Sonuçları değerlendir, bir sonraki adımı belirle.").font(.system(size: 11)).foregroundStyle(Palette.muted)
                }
                Spacer(minLength: 8)
                Button(L10n.text("Cancel")) { dismiss() }.buttonStyle(EdgeButtonStyle(prominent: false, compact: true)).keyboardShortcut(.cancelAction)
                Button { save() } label: { Label(L10n.text("Save review"), systemImage: "checkmark") }
                    .buttonStyle(EdgeButtonStyle(compact: true)).keyboardShortcut("s", modifiers: .command)
            }.padding(.horizontal, 26).padding(.vertical, 20).background(Palette.panel)
            Rectangle().fill(Palette.muted.opacity(0.12)).frame(height: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Panel {
                        HStack(alignment: .top, spacing: 24) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(L10n.text("Period")).font(.system(size: 12, weight: .medium))
                                Picker(L10n.text("Period"), selection: $draft.period) { ForEach(["Daily", "Weekly", "Monthly"], id: \.self) { Text(L10n.text($0)) } }
                                    .pickerStyle(.segmented).labelsHidden().controlSize(.large)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            VStack(alignment: .leading, spacing: 10) {
                                Text(L10n.text("Contains date")).font(.system(size: 12, weight: .medium))
                                DatePicker(L10n.text("Contains date"), selection: $draft.date, displayedComponents: .date).labelsHidden().controlSize(.large)
                            }
                        }
                        Label(L10n.text("\(Format.date(interval.start, calendar: store.preferences.calendar)) — \(Format.date(interval.end.addingTimeInterval(-1), calendar: store.preferences.calendar)) · Live statistics"), systemImage: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11)).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
                    }
                    HStack(spacing: 14) {
                        MetricCard(title: "Trades", value: "\(p.count)")
                        MetricCard(title: "Net PnL", value: Format.money(p.netPnL, currency: store.accountCurrency), color: Palette.outcome(p.netPnL))
                        MetricCard(title: "R", value: Format.r(p.totalR), color: Palette.outcome(p.totalR))
                    }
                    Panel(title: "REVIEW SNAPSHOT") {
                        VStack(spacing: 0) {
                            row("WR / PF / Expectancy", "\(Format.percent(p.winRate)) / \(Format.factor(p)) / \(Format.r(p.averageR))")
                            row("Best setup", setups.first?.name ?? "—")
                            row("Worst setup", setups.last?.name ?? "—")
                            row("Best trade", best.map { "\($0.instrument) · \(Format.money($0.netPnL, currency: store.accountCurrency))" } ?? "—")
                            row("Worst trade", worst.map { "\($0.instrument) · \(Format.money($0.netPnL, currency: store.accountCurrency))" } ?? "—")
                            row("Most common mistake", AnalyticsEngine.mistakes(trades).first?.name ?? "None recorded")
                            row("Rule compliance / Execution", "\(Format.percent(p.compliance)) / \(Format.number(p.executionScore, digits: 0))/100", separator: false)
                        }
                        Text(L10n.text("Setup ranking uses average recorded R. Statistics update when underlying trades change.")).font(.system(size: 11)).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
                    }
                    Panel(title: "DÖNEM DEĞERLENDİRMESİ") {
                        NoteField(title: "What worked?", text: $draft.worked)
                        NoteField(title: "What didn't?", text: $draft.didNot)
                        NoteField(title: "What should I repeat?", text: $draft.repeatNext)
                        NoteField(title: "What should I stop doing?", text: $draft.stop)
                    }
                    Panel(title: "SONRAKİ ADIM") { NoteField(title: "What is one adjustment for the next period?", text: $draft.adjustment) }
                }.padding(26)
            }
            if let error {
                Label(L10n.text(error), systemImage: "exclamationmark.circle.fill").font(.system(size: 12)).foregroundStyle(Palette.amber)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(14).background(Palette.amber.opacity(0.07)).accessibilityElement(children: .combine)
            }
        }.frame(width: sheetSize.width, height: sheetSize.height).background(Palette.canvas).foregroundStyle(Palette.ink).tint(Palette.mint)
    }
    private func row(_ title: String, _ value: String, separator: Bool = true) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 24) {
            Text(L10n.text(title)).font(.system(size: 12)).foregroundStyle(Palette.muted)
            Spacer(minLength: 16)
            Text(verbatim: value).font(.system(size: 12, weight: .medium)).monospacedDigit().multilineTextAlignment(.trailing).textSelection(.enabled)
        }.padding(.vertical, 12).overlay(alignment: .bottom) { if separator { Rectangle().fill(Palette.muted.opacity(0.1)).frame(height: 1) } }
    }
    private func save() {
        if let err = Self.performSaveDraft(draft, into: store) {
            self.error = err
        } else {
            dismiss()
        }
    }

    @MainActor
    static func performSaveDraft(_ draft: ReviewDraft, into store: JournalStore) -> String? {
        do {
            try store.commit {
                let review: Review
                if let existing = store.reviews.first(where: { $0.id == draft.id }) {
                    review = existing
                } else {
                    review = Review(id: draft.id, period: draft.period, date: draft.date)
                    store.context.insert(review)
                }
                review.period = draft.period
                review.date = draft.date
                review.worked = draft.worked
                review.didNot = draft.didNot
                review.repeatNext = draft.repeatNext
                review.stop = draft.stop
                review.adjustment = draft.adjustment
            }
            return nil
        } catch { return error.localizedDescription }
    }
}
