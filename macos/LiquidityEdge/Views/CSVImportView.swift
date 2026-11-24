import SwiftUI
import AppKit

struct CSVImportView: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    enum Step { case fileSelection, columnMapping, previewAndImport, completed }

    @State private var step: Step = .fileSelection
    @State private var rawCSVText = ""
    @State private var selectedFileURL: URL?
    @State private var detectedHeaders: [String] = []
    @State private var parsedRows: [[String]] = []
    @State private var mappings: [String: String] = [:] // FieldKey -> CSVHeader
    @State private var parsedTrades: [TradeRecord] = []
    @State private var validationErrors: [String] = []
    @State private var duplicateCount = 0
    @State private var importedCount = 0
    @State private var targetAccountID: UUID = TradingAccount.legacyID
    @State private var isProcessing = false

    // Canonical fields to map
    private let targetFields: [(key: String, label: String, required: Bool)] = [
        ("date", "İşlem Tarihi / Zamanı", true),
        ("instrument", "Enstrüman (örn: NQ, ES)", true),
        ("direction", "Yön (Long / Short)", false),
        ("grossPnL", "Brüt Kâr/Zarar (Gross P&L)", true),
        ("fees", "Komisyon / Masraf", false),
        ("netPnL", "Net Kâr/Zarar", false),
        ("rMultiple", "R Çarpanı (R Multiple)", false),
        ("setupName", "Kurulum / Setup Adı", false),
        ("session", "Seans (London, NY AM vb.)", false),
        ("entryPrice", "Giriş Fiyatı", false),
        ("exitPrice", "Çıkış Fiyatı", false),
        ("stopLoss", "Stop Loss Fiyatı", false),
        ("takeProfit", "Kâr Al Fiyatı", false),
        ("positionSize", "Pozisyon Büyüklüğü (Lot/Kontrat)", false),
        ("riskDollars", "Risk Tutarı", false),
        ("thesis", "İşlem Tezi / Notlar", false),
        ("tags", "Etiketler (Virgülle ayrılmış)", false)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerView
                wizardStepIndicator

                switch step {
                case .fileSelection:
                    fileSelectionStep
                case .columnMapping:
                    columnMappingStep
                case .previewAndImport:
                    previewAndImportStep
                case .completed:
                    completedStep
                }
            }
            .pagePadding()
        }
        .onAppear {
            targetAccountID = store.selectedAccount.id
        }
    }

    // MARK: - Header
    private var headerView: some View {
        PageHeader(
            eyebrow: "DATA MANAGEMENT / 05",
            title: "CSV Aktarım Sihirbazı",
            subtitle: "Harici broker veya platform kayıtlarını haritalayarak güvenle günlüğünüze aktarın."
        )
    }

    // MARK: - Step Indicator
    private var wizardStepIndicator: some View {
        HStack(spacing: 12) {
            stepBadge(number: "1", title: "Dosya Seçimi", active: step == .fileSelection, done: step != .fileSelection)
            Rectangle().fill(Palette.line).frame(height: 1)
            stepBadge(number: "2", title: "Sütun Eşleme", active: step == .columnMapping, done: step == .previewAndImport || step == .completed)
            Rectangle().fill(Palette.line).frame(height: 1)
            stepBadge(number: "3", title: "Önizleme & Onay", active: step == .previewAndImport, done: step == .completed)
            Rectangle().fill(Palette.line).frame(height: 1)
            stepBadge(number: "4", title: "Tamamlandı", active: step == .completed, done: false)
        }
        .padding(.vertical, 8)
    }

    private func stepBadge(number: String, title: String, active: Bool, done: Bool) -> some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(done ? Palette.mint : active ? Palette.blue : Palette.field)
                    .frame(width: 22, height: 22)
                if done {
                    Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(Palette.canvas)
                } else {
                    Text(number).font(.system(size: 11, weight: .bold)).foregroundStyle(active ? Color.white : Palette.muted)
                }
            }
            Text(title).font(.caption.weight(active ? .bold : .regular)).foregroundStyle(active ? Palette.ink : Palette.muted)
        }
    }

    // MARK: - Step 1: File Selection
    private var fileSelectionStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Panel(title: "CSV DOSYASI YÜKLE VEYA YAPIŞTIR") {
                VStack(spacing: 20) {
                    HStack(spacing: 16) {
                        Button {
                            selectCSVFile()
                        } label: {
                            Label("CSV Dosyası Seç (.csv)...", systemImage: "doc.badge.plus")
                        }
                        .buttonStyle(EdgeButtonStyle())

                        if let url = selectedFileURL {
                            Text(url.lastPathComponent)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Palette.mint)
                        }
                        Spacer()
                    }

                    Text("Veya CSV metnini doğrudan buraya yapıştırın:")
                        .font(.caption)
                        .foregroundStyle(Palette.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextEditor(text: $rawCSVText)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(height: 180)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(Palette.field.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))

                    HStack {
                        Spacer()
                        Button("Sütunları Analiz Et") {
                            parseHeadersAndAdvance()
                        }
                        .buttonStyle(EdgeButtonStyle())
                        .disabled(rawCSVText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }

    // MARK: - Step 2: Column Mapping
    private var columnMappingStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Panel(title: "SÜTUNLARI EŞLEŞTİRİN", subtitle: "CSV başlıklarını Liquidity Edge işlem alanlarıyla eşleyin.") {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(targetFields, id: \.key) { field in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(field.label).font(.system(size: 12, weight: .medium))
                                    if field.required {
                                        Text("*").foregroundStyle(Palette.red)
                                    }
                                }
                                Text("Alan: \(field.key)").font(.caption2).foregroundStyle(Palette.muted)
                            }
                            .frame(width: 240, alignment: .leading)

                            Picker("Eşleşen CSV Sütunu", selection: Binding(
                                get: { mappings[field.key] ?? "" },
                                set: { mappings[field.key] = $0.isEmpty ? nil : $0 }
                            )) {
                                Text("— Eşleme Yok —").tag("")
                                ForEach(detectedHeaders, id: \.self) { header in
                                    Text(header).tag(header)
                                }
                            }
                            .frame(maxWidth: 240)

                            Spacer()
                        }
                        Divider()
                    }

                    HStack {
                        Button("Geri") {
                            step = .fileSelection
                        }
                        .buttonStyle(EdgeButtonStyle(prominent: false))

                        Spacer()

                        Button("Önizleme ve Doğrulama") {
                            buildPreviewTrades()
                        }
                        .buttonStyle(EdgeButtonStyle())
                    }
                }
            }
        }
    }

    // MARK: - Step 3: Preview and Import
    private var previewAndImportStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Panel(title: "KAYIT ÖNİZLEMESİ VE DOĞRULAMA") {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 24) {
                        TerminalMetric(title: "OKUNAN KAYIT", value: "\(parsedTrades.count)")
                        TerminalMetric(title: "YİNELENEN (MEVCUT)", value: "\(duplicateCount)", color: duplicateCount > 0 ? Palette.amber : Palette.ink)
                        TerminalMetric(title: "AKTARILACAK YENİ", value: "\(parsedTrades.count - duplicateCount)", color: Palette.mint)
                    }
                    .padding(14)
                    .background(Palette.field.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))

                    HStack(spacing: 12) {
                        Text("Hedef Hesap:").font(.caption.weight(.medium))
                        Picker("Hedef Hesap", selection: $targetAccountID) {
                            ForEach(store.workspace.accounts) { acc in
                                Text(acc.name + " (\(acc.currency))").tag(acc.id)
                            }
                        }
                        .frame(maxWidth: 240)
                    }

                    if !validationErrors.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Uyarılar:").font(.caption.weight(.bold)).foregroundStyle(Palette.amber)
                            ForEach(validationErrors.prefix(5), id: \.self) { err in
                                Text("• " + err).font(.caption2).foregroundStyle(Palette.muted)
                            }
                        }
                        .padding(10)
                        .background(Palette.amber.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                    }

                    // Table preview
                    ScrollView(.horizontal) {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                Text("TARİH").font(.caption.weight(.bold)).frame(width: 140, alignment: .leading)
                                Text("ENSTRÜMAN").font(.caption.weight(.bold)).frame(width: 90, alignment: .leading)
                                Text("YÖN").font(.caption.weight(.bold)).frame(width: 70, alignment: .leading)
                                Text("BRÜT PNL").font(.caption.weight(.bold)).frame(width: 100, alignment: .trailing)
                                Text("R").font(.caption.weight(.bold)).frame(width: 70, alignment: .trailing)
                                Text("SETUP").font(.caption.weight(.bold)).frame(width: 120, alignment: .leading)
                            }
                            .padding(.vertical, 8)
                            Divider()

                        ForEach(parsedTrades.prefix(15)) { t in
                                let targetCurrency = store.workspace.accounts.first(where: { $0.id == targetAccountID })?.currency ?? store.accountCurrency
                                HStack {
                                    Text(Format.date(t.date, calendar: store.preferences.calendar, time: true))
                                        .font(.caption).frame(width: 140, alignment: .leading)
                                    Text(t.instrument).font(.caption.weight(.medium)).frame(width: 90, alignment: .leading)
                                    Badge(text: t.direction).frame(width: 70, alignment: .leading)
                                    Text(Format.money(t.grossPnL, currency: targetCurrency))
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(Palette.outcome(t.grossPnL))
                                        .frame(width: 100, alignment: .trailing)
                                    Text(Format.r(t.rMultiple)).font(.caption.monospacedDigit()).frame(width: 70, alignment: .trailing)
                                    Text(t.setupName).font(.caption).frame(width: 120, alignment: .leading)
                                }
                                .padding(.vertical, 4)
                                Divider()
                            }
                        }
                    }

                    HStack {
                        Button("Geri (Eşlemeyi Düzenle)") {
                            step = .columnMapping
                        }
                        .buttonStyle(EdgeButtonStyle(prominent: false))

                        Spacer()

                        Button("İşlemleri İçe Aktar (\(parsedTrades.count - duplicateCount))") {
                            executeImport()
                        }
                        .buttonStyle(EdgeButtonStyle())
                        .disabled(parsedTrades.isEmpty || (parsedTrades.count - duplicateCount) == 0)
                    }
                }
            }
        }
    }

    // MARK: - Step 4: Completed
    private var completedStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Palette.mint)
            Text("İçe Aktarım Başarıyla Tamamlandı")
                .font(.title2.weight(.bold))
            Text("\(importedCount) işlem seçilen hesaba eklendi. Otomatik kurtarma yedeği oluşturuldu.")
                .font(.caption)
                .foregroundStyle(Palette.muted)

            Button("Yeni Aktarım Başlat") {
                step = .fileSelection
                rawCSVText = ""
                selectedFileURL = nil
                parsedTrades = []
                validationErrors = []
                mappings = [:]
            }
            .buttonStyle(EdgeButtonStyle())
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(Palette.panel, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Logic
    private func selectCSVFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.commaSeparatedText, .plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            selectedFileURL = url
            do {
                rawCSVText = try String(contentsOf: url, encoding: .utf8)
            } catch {
                store.report(error)
            }
        }
    }

    private func splitCSVLine(_ line: String, delimiter: Character) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        let chars = Array(line)
        var i = 0
        while i < chars.count {
            let ch = chars[i]
            if ch == "\"" {
                if inQuotes, i + 1 < chars.count, chars[i + 1] == "\"" {
                    current.append("\"")
                    i += 2
                    continue
                }
                inQuotes.toggle()
            } else if ch == delimiter && !inQuotes {
                fields.append(current.trimmingCharacters(in: CharacterSet(charactersIn: " \r\t")))
                current = ""
            } else {
                current.append(ch)
            }
            i += 1
        }
        fields.append(current.trimmingCharacters(in: CharacterSet(charactersIn: " \r\t")))
        return fields
    }

    private func parseNumber(_ raw: String) -> Double? {
        var clean = raw
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: "£", with: "")
            .replacingOccurrences(of: "₺", with: "")
            .replacingOccurrences(of: "R", with: "")
            .replacingOccurrences(of: "r", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        if clean.contains(",") && clean.contains(".") {
            // 1,250.50 vs 1.250,50
            if let lastComma = clean.lastIndex(of: ","), let lastDot = clean.lastIndex(of: "."), lastComma > lastDot {
                clean = clean.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
            } else {
                clean = clean.replacingOccurrences(of: ",", with: "")
            }
        } else if clean.contains(",") {
            let parts = clean.split(separator: ",")
            if parts.count == 2 && parts[1].count <= 2 {
                clean = clean.replacingOccurrences(of: ",", with: ".")
            } else {
                clean = clean.replacingOccurrences(of: ",", with: "")
            }
        }
        return Double(clean)
    }

    private func parseHeadersAndAdvance() {
        let cleaned = rawCSVText.replacingOccurrences(of: "\u{FEFF}", with: "")
        let lines = cleaned.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard let first = lines.first else { return }

        // Delimiter detection
        let delimiter: Character = first.contains(";") ? ";" : first.contains("\t") ? "\t" : ","
        detectedHeaders = splitCSVLine(first, delimiter: delimiter)
        mappings = [:]

        // Pre-fill smart guesses
        for (key, _, _) in targetFields {
            if let matched = detectedHeaders.first(where: { h in
                let lower = h.lowercased()
                switch key {
                case "date": return lower.contains("date") || lower.contains("time") || lower.contains("tarih")
                case "instrument": return lower.contains("symbol") || lower.contains("instrument") || lower.contains("ticker") || lower.contains("sembol")
                case "direction": return lower.contains("side") || lower.contains("direction") || lower.contains("type") || lower.contains("yön")
                case "grossPnL": return lower.contains("gross") || lower == "pnl" || lower.contains("profit") || lower.contains("kâr")
                case "fees": return lower.contains("fee") || lower.contains("commission") || lower.contains("komisyon")
                case "netPnL": return lower == "net" || lower.contains("net pnl") || lower.contains("netpnl") || lower.contains("net k")
                case "rMultiple": return lower.contains("r multiple") || lower == "r" || lower.contains("rmultiple")
                case "setupName": return lower.contains("setup") || lower.contains("strategy") || lower.contains("model")
                case "session": return lower.contains("session") || lower.contains("seans")
                case "entryPrice": return lower.contains("entry") || lower.contains("open price")
                case "exitPrice": return lower.contains("exit") || lower.contains("close price")
                case "stopLoss": return lower.contains("stop") || lower == "sl"
                case "takeProfit": return lower.contains("target") || lower == "tp" || lower.contains("take profit")
                case "positionSize": return lower.contains("qty") || lower.contains("quantity") || lower.contains("size") || lower.contains("kontrat")
                case "riskDollars": return lower.contains("risk $") || lower.contains("risk dollar") || lower == "risk"
                case "thesis": return lower.contains("notes") || lower.contains("thesis") || lower.contains("not")
                case "tags": return lower.contains("tag") || lower.contains("etiket")
                default: return false
                }
            }) {
                mappings[key] = matched
            }
        }

        step = .columnMapping
    }

    private func buildPreviewTrades() {
        let cleaned = rawCSVText.replacingOccurrences(of: "\u{FEFF}", with: "")
        let lines = cleaned.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard lines.count > 1 else {
            validationErrors = ["CSV en az bir başlık satırı ve bir veri satırı içermelidir."]
            parsedTrades = []
            duplicateCount = 0
            step = .previewAndImport
            return
        }

        let first = lines[0]
        let delimiter: Character = first.contains(";") ? ";" : first.contains("\t") ? "\t" : ","
        let headers = splitCSVLine(first, delimiter: delimiter)

        var result: [TradeRecord] = []
        var errors: [String] = []

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        let formats = [
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd",
            "dd.MM.yyyy HH:mm:ss",
            "dd.MM.yyyy HH:mm",
            "dd.MM.yyyy",
            "dd/MM/yyyy HH:mm",
            "MM/dd/yyyy HH:mm:ss",
            "MM/dd/yyyy"
        ]

        func parseDate(_ str: String) -> Date? {
            let clean = str.trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
            if let iso = ISO8601DateFormatter().date(from: clean) { return iso }
            for fmt in formats {
                dateFormatter.dateFormat = fmt
                if let d = dateFormatter.date(from: clean) { return d }
            }
            if let interval = Double(clean) {
                return Date(timeIntervalSince1970: interval > 1e11 ? interval / 1000 : interval)
            }
            return nil
        }

        func cell(_ key: String, in cols: [String]) -> String? {
            guard let header = mappings[key], let colIdx = headers.firstIndex(of: header), colIdx < cols.count else { return nil }
            return cols[colIdx]
        }

        for (idx, line) in lines.dropFirst().enumerated() {
            let cols = splitCSVLine(line, delimiter: delimiter)
            guard cols.count == headers.count else {
                errors.append("Satır \(idx + 2): Sütun sayısı başlıkla eşleşmiyor (\(cols.count) / \(headers.count))")
                continue
            }

            var record = TradeRecord()
            var valid = true

            if let dateStr = cell("date", in: cols) {
                if let d = parseDate(dateStr) { record.date = d }
                else {
                    valid = false
                    errors.append("Satır \(idx + 2): Tarih ayrıştırılamadı '\(dateStr)'")
                }
            }

            if let symStr = cell("instrument", in: cols) {
                let sym = symStr.trimmingCharacters(in: .whitespaces)
                record.instrument = sym.isEmpty ? "NQ" : sym.uppercased()
            }

            if let dirStr = cell("direction", in: cols) {
                let dir = dirStr.lowercased()
                record.direction = (dir.contains("short") || dir.contains("sell") || dir.contains("sat") || dir == "s") ? "Short" : "Long"
            }

            if let feeStr = cell("fees", in: cols), let feeVal = parseNumber(feeStr) {
                record.fees = abs(feeVal)
            }

            if let grossStr = cell("grossPnL", in: cols), let grossVal = parseNumber(grossStr) {
                record.grossPnL = grossVal
            } else if let netStr = cell("netPnL", in: cols), let netVal = parseNumber(netStr) {
                record.grossPnL = netVal + record.fees
            }

            if let rStr = cell("rMultiple", in: cols) { record.rMultiple = parseNumber(rStr) }
            if let entryStr = cell("entryPrice", in: cols) { record.entryPrice = parseNumber(entryStr) }
            if let exitStr = cell("exitPrice", in: cols) { record.exitPrice = parseNumber(exitStr) }
            if let slStr = cell("stopLoss", in: cols) { record.stopLoss = parseNumber(slStr) }
            if let tpStr = cell("takeProfit", in: cols) { record.takeProfit = parseNumber(tpStr) }
            if let sizeStr = cell("positionSize", in: cols), let sz = parseNumber(sizeStr), sz >= 0 { record.positionSize = sz }
            if let riskStr = cell("riskDollars", in: cols), let rk = parseNumber(riskStr), rk >= 0 { record.riskDollars = rk }

            if let setupStr = cell("setupName", in: cols) {
                let s = setupStr.trimmingCharacters(in: .whitespaces)
                if !s.isEmpty {
                    if let matched = store.setups.first(where: { $0.name.caseInsensitiveCompare(s) == .orderedSame }) {
                        record.setupID = matched.id
                        record.setupName = matched.name
                    } else {
                        record.setupName = s
                    }
                }
            }

            if let sessStr = cell("session", in: cols) {
                let s = sessStr.trimmingCharacters(in: .whitespaces)
                if !s.isEmpty { record.session = s }
            }

            if let thesisStr = cell("thesis", in: cols) { record.notes.thesis = thesisStr }

            if let tagStr = cell("tags", in: cols) {
                record.tags = tagStr.components(separatedBy: CharacterSet(charactersIn: ",;|"))
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            }

            if valid {
                if let validationErr = record.validationError {
                    errors.append("Satır \(idx + 2): \(L10n.text(validationErr))")
                } else {
                    result.append(record)
                }
            }
        }

        // Check duplicates against existing store
        let existing = store.trades
        duplicateCount = result.filter { r in
            existing.contains { e in
                e.instrument == r.instrument &&
                abs(e.date.timeIntervalSince(r.date)) < 60 &&
                abs(e.grossPnL - r.grossPnL) < 0.01
            }
        }.count

        parsedTrades = result
        validationErrors = errors
        step = .previewAndImport
    }

    private func executeImport() {
        isProcessing = true
        let existing = store.trades
        let toImport = parsedTrades.filter { r in
            !existing.contains { e in
                e.instrument == r.instrument &&
                abs(e.date.timeIntervalSince(r.date)) < 60 &&
                abs(e.grossPnL - r.grossPnL) < 0.01
            }
        }

        do {
            try store.createRecoverySnapshot(reason: "before-csv-import")
            try store.saveBatch(toImport, accountID: targetAccountID)
            importedCount = toImport.count
            step = .completed
        } catch {
            store.report(error)
        }
        isProcessing = false
    }
}

