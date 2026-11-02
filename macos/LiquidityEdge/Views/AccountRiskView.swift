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
        let risk = WorkstationAnalytics.risk(store.scopedTrades, account: account, calendar: store.preferences.calendar)
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
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
                HStack(spacing: 20) {
                    TerminalMetric(title: "KAYITLI BAKİYE", value: Format.money(risk.balance, currency: account.currency))
                    TerminalMetric(title: "GERÇEKLEŞEN NET", value: Format.money(risk.realized, currency: account.currency), color: Palette.outcome(risk.realized))
                    TerminalMetric(title: "KAYIP SINIRINA MESAFE", value: risk.remaining.map { Format.money($0, currency: account.currency) } ?? "Tanımlı değil", color: (risk.remaining ?? 0) < 0 ? Palette.red : Palette.ink)
                    TerminalMetric(title: "İŞLEM GÜNÜ", value: "\(risk.days) / \(account.rules.minimumDays.map(String.init) ?? "—")")
                }.padding(22).background(Palette.panel, in: RoundedRectangle(cornerRadius: 14))
                if risk.unverified { Label("Doğrulanamadı: çıkış zamanı eksik veya kural gün içi equity verisi gerektiriyor. Canlı denetim yapılmaz.", systemImage: "exclamationmark.shield").foregroundStyle(Palette.amber).font(.callout) }
                if risk.historicalBreach { Label("Kayıtlı kapanışlarda tanımlı kayıp sınırı aşıldı. Geçmiş ihlal sonraki kazançla silinmez.", systemImage: "exclamationmark.triangle").foregroundStyle(Palette.red).font(.callout) }
                HStack(alignment: .top, spacing: 24) {
                    Panel(title: "HESAP PERFORMANSI", subtitle: "İşlem kayıtları · Net sonuç") {
                        EquityChart(points: AnalyticsEngine.curve(store.scopedTrades), height: 280)
                    }
                    Panel(title: "KURAL PANOSU") {
                        riskRow("Kâr hedefi", value: account.rules.profitTarget.map { "\(Format.money(risk.realized, currency: account.currency)) / \(Format.money($0, currency: account.currency))" } ?? "Tanımlanmadı")
                        riskRow("Bugünkü net sonuç", value: Format.money(risk.today, currency: account.currency))
                        riskRow("Günlük kalan pay", value: risk.dailyRemaining.map { Format.money($0, currency: account.currency) } ?? "Tanımlanmadı")
                        riskRow("Drawdown yöntemi", value: account.rules.drawdownMethod)
                        riskRow("Bakiye alt sınırı", value: risk.floor.map { Format.money($0, currency: account.currency) } ?? "Kullanılamıyor")
                        riskRow("Bugünkü giriş sayısı", value: "\(risk.todayCount) / \(account.rules.dailyTradeCount.map(String.init) ?? "—")")
                        riskRow("En iyi gün / toplam kâr", value: risk.consistency.map(Format.percent) ?? "Pozitif net kâr gerekli")
                        if let cap = account.rules.consistencyPercent { riskRow("Tutarlılık üst sınırı", value: Format.percent(cap) + ((risk.consistency ?? 0) > cap ? " · Aşıldı" : "")) }
                        riskRow("Risk miktarı sınır aşımı", value: "\(risk.oversizedTrades) işlem")
                        riskRow("Günlük sayı sınır aşımı", value: "\(risk.dailyCountBreaches) gün")
                    }.frame(maxWidth: 340)
                }
                Panel(title: "HESAPLARI KARŞILAŞTIR", subtitle: "Para birimleri ayrı tutulur; döviz dönüşümü yapılmaz.") {
                    ForEach(store.workspace.accounts) { a in
                        let data = store.trades.filter { store.accountID(for: $0.id) == a.id }
                        let p = AnalyticsEngine.performance(data)
                        HStack {
                            Button(a.name) { do { try store.updateWorkspace { $0.selectedAccountID = a.id } } catch { store.report(error) } }.buttonStyle(.plain).foregroundStyle(Palette.mint)
                            Text(a.active ? a.category : "Arşiv").foregroundStyle(Palette.muted)
                            Spacer(); Text("n = \(p.count)"); Text(Format.r(p.averageR)).frame(width: 85, alignment: .trailing)
                            Text(Format.money(p.netPnL, currency: a.currency)).frame(width: 145, alignment: .trailing)
                        }.font(.system(size: 12)).monospacedDigit().padding(.vertical, 8)
                        Divider()
                    }
                }
                Text("Yöntem: statik alt sınır = başlangıç − maksimum kayıp. Gün sonu takip = önceki tamamlanmış günlerin en yüksek kapanışı − maksimum kayıp; üst tavan uygulanmaz. Günlük pay = günlük limit + bugünkü gerçekleşen net. Günler seçili saat diliminde çıkış tarihine göre sayılır. Para yatırma/çekme ve açık pozisyonlar dahil değildir. Eksik risk tutarı ihlal olarak varsayılmaz.").font(.caption).foregroundStyle(Palette.muted)
            }.pagePadding()
        }.sheet(item: $editing) { AccountEditor(initial: $0).environment(store) }
    }
    private func riskRow(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) { Text(title).foregroundStyle(Palette.muted); Text(value).fontWeight(.medium).monospacedDigit() }.font(.system(size: 11)).frame(maxWidth: .infinity, alignment: .leading)
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
            HStack { Text("Hesap ve risk kuralları").font(.title2); Spacer(); Button("İptal") { dismiss() }.keyboardShortcut(.cancelAction); Button("Kaydet", action: save).buttonStyle(EdgeButtonStyle()) }
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
            if let error { Text(error).foregroundStyle(Palette.red) }
        }.padding(24).frame(width: 620, height: 680).background(Palette.canvas)
    }
    private func save() {
        do {
            account.currency = account.currency.uppercased()
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
    @State private var hovering = false
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title).font(.system(size: 9, weight: .semibold)).tracking(1.0).foregroundStyle(hovering ? Palette.mint : Palette.muted)
            Text(value)
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.14), value: hovering)
        .accessibilityElement(children: .combine)
    }
}
