import SwiftUI

struct AccountPicker: View {
    @Environment(JournalStore.self) private var store
    var body: some View {
        Picker("Hesap", selection: Binding(get: { store.selectedAccount.id }, set: { id in
            do { try store.updateWorkspace { $0.selectedAccountID = id } } catch { store.report(error) }
        })) {
            ForEach(store.workspace.accounts) { account in Text(account.name + (account.active ? "" : " · Arşiv")).tag(account.id) }
        }.labelsHidden().frame(maxWidth: 210).help("Tüm performans ekranları seçili hesaba göre filtrelenir.")
    }
}
struct AccountRiskView: View {
    @Environment(JournalStore.self) private var store
    @State private var editing: TradingAccount?
    var body: some View {
        let account = store.selectedAccount
        let risk = store.scopedRisk
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                HStack {
                    PageHeader(eyebrow: "ACCOUNTS / RISK", title: "Sermayeni tanı. Sınırlarını izle.", subtitle: "Kayıtlı kapanışlar üzerinden hesap bazlı risk değerlendirmesi.")
                    Spacer()
                    Button("Hesap ekle") { editing = TradingAccount() }.buttonStyle(EdgeButtonStyle())
                }
                HStack {
                    AccountPicker()
                    Badge(text: account.category, color: Palette.blue)
                    Spacer()
                    Button("Hesabı ve kuralları düzenle") { editing = account }.buttonStyle(EdgeButtonStyle(prominent: false))
                }
                GlassRibbon(accent: Palette.outcome(risk.realized)) {
                    HStack(spacing: 0) {
                        TerminalMetric(title: "KAYITLI BAKİYE", value: Format.money(risk.balance, currency: account.currency), subtitle: "Başlangıç " + Format.money(account.startingBalance, currency: account.currency))
                        riskDivider
                        TerminalMetric(title: "GERÇEKLEŞEN NET", value: Format.money(risk.realized, currency: account.currency), color: Palette.outcome(risk.realized), subtitle: "Bugün " + Format.money(risk.today, currency: account.currency))
                        riskDivider
                        TerminalMetric(title: "KAYIP SINIRINA MESAFE", value: risk.remaining.map { Format.money($0, currency: account.currency) } ?? "Tanımlı değil", color: (risk.remaining ?? 0) < 0 ? Palette.red : Palette.ink, subtitle: account.rules.drawdownMethod)
                        riskDivider
                        TerminalMetric(title: "İŞLEM GÜNÜ", value: "\(risk.days) / \(account.rules.minimumDays.map(String.init) ?? "—")", subtitle: "Bugün \(risk.todayCount) giriş")
                    }
                }
                .edgeEntrance(delay: 0.03)
                if risk.unverified { Label("Doğrulanamadı: çıkış zamanı eksik veya kural gün içi equity verisi gerektiriyor. Canlı denetim yapılmaz.", systemImage: "exclamationmark.shield").foregroundStyle(Palette.amber).font(.callout) }
                if risk.historicalBreach { Label("Kayıtlı kapanışlarda tanımlı kayıp sınırı aşıldı. Geçmiş ihlal sonraki kazançla silinmez.", systemImage: "exclamationmark.triangle").foregroundStyle(Palette.red).font(.callout) }
                HStack(alignment: .top, spacing: 24) {
                    Panel(title: "HESAP PERFORMANSI", subtitle: "İşlem kayıtları · Net sonuç", accent: Palette.outcome(risk.realized)) {
                        EquityChart(points: store.scopedCurve, height: 295)
                    }
                    Panel(title: "KURAL PANOSU", accent: Palette.blue) {
                        VStack(alignment: .leading, spacing: 12) {
                            if let target = account.rules.profitTarget, target > 0 {
                                riskGauge("Kâr hedefi", value: "\(Format.money(risk.realized, currency: account.currency)) / \(Format.money(target, currency: account.currency))", progress: max(0, min(1, risk.realized / target)), tint: Palette.mint)
                            } else {
                                riskRow("Kâr hedefi", value: "Tanımlanmadı")
                            }
                            if let maxLoss = account.rules.maximumLoss, maxLoss > 0, let rem = risk.remaining {
                                riskGauge("Kayıp sınırı tamponu", value: Format.money(rem, currency: account.currency), progress: max(0, min(1, rem / maxLoss)), tint: rem < maxLoss * 0.25 ? Palette.red : Palette.mint)
                            }
                            if let dailyCap = account.rules.dailyLoss, dailyCap > 0, let dailyRem = risk.dailyRemaining {
                                riskGauge("Günlük kalan pay", value: Format.money(dailyRem, currency: account.currency), progress: max(0, min(1, dailyRem / dailyCap)), tint: dailyRem < dailyCap * 0.25 ? Palette.red : Palette.blue)
                            } else {
                                riskRow("Günlük kalan pay", value: "Tanımlanmadı")
                            }
                            riskRow("Bugünkü net sonuç", value: Format.money(risk.today, currency: account.currency), color: Palette.outcome(risk.today))
                            riskRow("Drawdown yöntemi", value: account.rules.drawdownMethod)
                            riskRow("Bakiye alt sınırı", value: risk.floor.map { Format.money($0, currency: account.currency) } ?? "Kullanılamıyor")
                            riskRow("Bugünkü giriş sayısı", value: "\(risk.todayCount) / \(account.rules.dailyTradeCount.map(String.init) ?? "—")")
                            if let cons = risk.consistency {
                                let cap = account.rules.consistencyPercent ?? 100
                                riskGauge("En iyi gün / toplam kâr", value: Format.percent(cons) + (account.rules.consistencyPercent.map { cons > $0 ? " · Aşıldı" : " / \(Format.percent($0))" } ?? ""), progress: max(0, min(1, cons / max(1, cap))), tint: (account.rules.consistencyPercent.map { cons > $0 } ?? false) ? Palette.amber : Palette.blue)
                            } else {
                                riskRow("En iyi gün / toplam kâr", value: "Pozitif net kâr gerekli")
                            }
                            riskRow("Risk miktarı sınır aşımı", value: "\(risk.oversizedTrades) işlem", color: risk.oversizedTrades > 0 ? Palette.amber : Palette.ink)
                            riskRow("Günlük sayı sınır aşımı", value: "\(risk.dailyCountBreaches) gün", color: risk.dailyCountBreaches > 0 ? Palette.amber : Palette.ink)
                        }
                    }.frame(maxWidth: 350)
                }
                Panel(title: "HESAPLARI KARŞILAŞTIR", subtitle: "Para birimleri ayrı tutulur; döviz dönüşümü yapılmaz.") {
                    let tradesByAccount = Dictionary(grouping: store.trades) { store.accountID(for: $0.id) }
                    ForEach(store.workspace.accounts) { a in
                        let isSelected = a.id == account.id
                        let p = isSelected ? store.scopedPerformance : AnalyticsEngine.performance(tradesByAccount[a.id] ?? [])
                        Button { do { try store.updateWorkspace { $0.selectedAccountID = a.id } } catch { store.report(error) } } label: {
                            HStack(spacing: 12) {
                                Circle().fill(isSelected ? Palette.mint : Palette.muted.opacity(0.35)).frame(width: 7, height: 7)
                                    .shadow(color: isSelected ? Palette.mint.opacity(0.6) : .clear, radius: 3)
                                Text(a.name).fontWeight(.semibold).foregroundStyle(isSelected ? Palette.mint : Palette.ink)
                                Badge(text: a.active ? a.category : "Arşiv", color: isSelected ? Palette.mint : Palette.muted)
                                Spacer()
                                Text("n = \(p.count)").foregroundStyle(Palette.muted)
                                Text(Format.r(p.averageR)).foregroundStyle(Palette.outcome(p.averageR ?? 0)).frame(width: 85, alignment: .trailing)
                                Text(Format.money(p.netPnL, currency: a.currency)).fontWeight(.semibold).foregroundStyle(Palette.outcome(p.netPnL)).frame(width: 145, alignment: .trailing)
                            }
                            .font(.system(size: 12)).monospacedDigit()
                            .padding(.horizontal, 12).padding(.vertical, 10)
                            .background(isSelected ? Palette.mint.opacity(0.08) : Palette.field.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(isSelected ? Palette.mint.opacity(0.3) : Palette.line.opacity(0.6), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text("Yöntem: statik alt sınır = başlangıç − maksimum kayıp. Gün sonu takip = önceki tamamlanmış günlerin en yüksek kapanışı − maksimum kayıp; üst tavan uygulanmaz. Günlük pay = günlük limit + bugünkü gerçekleşen net. Günler seçili saat diliminde çıkış tarihine göre sayılır. Para yatırma/çekme ve açık pozisyonlar dahil değildir. Eksik risk tutarı ihlal olarak varsayılmaz.").font(.caption).foregroundStyle(Palette.muted)
            }.pagePadding()
        }.sheet(item: $editing) { AccountEditor(initial: $0).environment(store) }
    }
    private var riskDivider: some View {
        Rectangle().fill(Palette.line.opacity(0.7)).frame(width: 1, height: 40).padding(.horizontal, 16)
    }
    private func riskRow(_ title: String, value: String, color: Color = Palette.ink) -> some View {
        HStack {
            Text(title).foregroundStyle(Palette.muted)
            Spacer(minLength: 8)
            Text(value).fontWeight(.semibold).foregroundStyle(color).monospacedDigit()
        }.font(.system(size: 11)).padding(.vertical, 2)
    }
    private func riskGauge(_ title: String, value: String, progress: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).foregroundStyle(Palette.muted)
                Spacer(minLength: 8)
                Text(value).fontWeight(.semibold).foregroundStyle(tint).monospacedDigit()
            }.font(.system(size: 11))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.raised)
                    Capsule().fill(LinearGradient(colors: [tint.opacity(0.65), tint], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(4, geo.size.width * progress))
                }
            }.frame(height: 5)
        }.padding(.vertical, 2)
    }
}
struct AccountEditor: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var account: TradingAccount
    @State private var error: String?
    init(initial: TradingAccount) { _account = State(initialValue: initial) }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Hesap ve risk kuralları").font(.title2.weight(.semibold))
                Spacer()
                Button("İptal") { dismiss() }.buttonStyle(EdgeButtonStyle(prominent: false, compact: true)).keyboardShortcut(.cancelAction)
                Button("Kaydet", action: save).buttonStyle(EdgeButtonStyle(compact: true)).keyboardShortcut("s", modifiers: .command)
            }
            Form {
                TextField("Hesap adı", text: $account.name)
                TextField("Para birimi (ISO)", text: $account.currency)
                TextField("Başlangıç bakiyesi", value: $account.startingBalance, format: .number)
                Picker("Hesap tipi", selection: $account.category) { ForEach(["Personal", "Evaluation", "Funded", "Other"], id: \.self) { Text($0) } }
                Toggle("Aktif hesap", isOn: $account.active)
                Section("İsteğe bağlı kurallar · boş = tanımlanmamış") {
                    TextField("Kâr hedefi", value: $account.rules.profitTarget, format: .number)
                    TextField("Günlük kayıp tutarı", value: $account.rules.dailyLoss, format: .number)
                    TextField("Maksimum kayıp tutarı", value: $account.rules.maximumLoss, format: .number)
                    Picker("Drawdown yöntemi", selection: $account.rules.drawdownMethod) { ForEach(["Static", "End of day", "Intraday equity"], id: \.self) { Text($0) } }
                    TextField("Minimum işlem günü", value: $account.rules.minimumDays, format: .number)
                    TextField("En iyi gün / net kâr üst sınırı (%)", value: $account.rules.consistencyPercent, format: .number)
                    TextField("İşlem başına risk tutarı", value: $account.rules.riskPerTrade, format: .number)
                    TextField("Günlük işlem sayısı", value: $account.rules.dailyTradeCount, format: .number)
                }
            }.formStyle(.grouped)
            Text("Hesabı pasifleştirmek geçmiş işlemleri korur. Para birimini değiştirmek tutarları dönüştürmez.").font(.caption).foregroundStyle(Palette.muted)
            if let error { Text(error).foregroundStyle(Palette.red).font(.caption) }
        }.padding(24).frame(width: 620, height: 680).background(Palette.canvas).foregroundStyle(Palette.ink).tint(Palette.mint)
    }
    private func save() {
        do {
            account.name = account.name.trimmingCharacters(in: .whitespacesAndNewlines)
            account.currency = account.currency.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            try store.updateWorkspace { state in
                if let index = state.accounts.firstIndex(where: { $0.id == account.id }) { state.accounts[index] = account }
                else { state.accounts.append(account) }
            }; dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
struct TerminalMetric: View {
    var title: String
    var value: String
    var color: Color = Palette.ink
    var subtitle: String = ""
    @State private var hovering = false
    @Environment(\.edgeAnimationsEnabled) private var animationsEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        let shouldAnimate = animationsEnabled && !reduceMotion
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                if hovering {
                    Circle().fill(Palette.mint).frame(width: 4, height: 4)
                        .transition(.scale.combined(with: .opacity))
                }
                Text(title).font(.system(size: 9, weight: .semibold)).tracking(1.0).foregroundStyle(hovering ? Palette.mint : Palette.muted)
            }
            Text(value)
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(shouldAnimate ? .numericText() : .identity)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Palette.muted.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .animation(shouldAnimate ? .easeOut(duration: 0.14) : nil, value: hovering)
        .accessibilityElement(children: .combine)
    }
}
