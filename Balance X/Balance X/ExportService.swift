import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum ExportService {

    // MARK: - CSV / Excel

    static func makeCSV(
        transactions: [AccountingTransaction],
        companyName: String,
        currencyCode: String,
        profile: OnboardingProfile? = nil
    ) throws -> ExportDocument {
        let p = profile
        let dateLabel  = p?.text(en: "Date",     es: "Fecha",      pt: "Data",      fr: "Date", ar: "التاريخ", de: "Datum", it: "Data", nl: "Datum", ja: "日付", ko: "날짜")     ?? "Date"
        let typeLabel  = p?.text(en: "Type",     es: "Tipo",       pt: "Tipo",      fr: "Type", ar: "النوع", de: "Typ", it: "Tipo", nl: "Type", ja: "種類", ko: "유형")     ?? "Type"
        let vendorLabel = p?.text(en: "Vendor",  es: "Comercio",   pt: "Fornecedor",fr: "Fournisseur", ar: "البائع", de: "Anbieter", it: "Fornitore", nl: "Leverancier", ja: "店舗", ko: "판매처") ?? "Vendor"
        let catLabel   = p?.text(en: "Category", es: "Categoría",  pt: "Categoria", fr: "Catégorie", ar: "الفئة", de: "Kategorie", it: "Categoria", nl: "Categorie", ja: "カテゴリ", ko: "카테고리") ?? "Category"
        let amtLabel   = p?.text(en: "Amount",   es: "Monto",      pt: "Valor",     fr: "Montant", ar: "المبلغ", de: "Betrag", it: "Importo", nl: "Bedrag", ja: "金額", ko: "금액")  ?? "Amount"
        let notesLabel = p?.text(en: "Notes",    es: "Notas",      pt: "Notas",     fr: "Notes", ar: "ملاحظات", de: "Notizen", it: "Note", nl: "Notities", ja: "メモ", ko: "메모")    ?? "Notes"
        let incomeLabel = p?.text(en: "Income", es: "Ingreso", pt: "Receita", fr: "Revenu", ar: "دخل", de: "Einnahme", it: "Entrata", nl: "Inkomst", ja: "収入", ko: "수입") ?? "Income"
        let expenseLabel = p?.text(en: "Expense", es: "Gasto", pt: "Despesa", fr: "Dépense", ar: "مصروف", de: "Ausgabe", it: "Spesa", nl: "Uitgave", ja: "支出", ko: "지출") ?? "Expense"
        let reportFilenameLabel = p?.text(en: "Report", es: "Reporte", pt: "Relatorio", fr: "Rapport", ar: "تقرير", de: "Bericht", it: "Report", nl: "Rapport", ja: "レポート", ko: "보고서") ?? "Report"
        let exportTitle = p?.text(en: "Excel Export", es: "Exportación Excel", pt: "Exportação Excel", fr: "Export Excel", ar: "تصدير Excel", de: "Excel-Export", it: "Esportazione Excel", nl: "Excel-export", ja: "Excelエクスポート", ko: "Excel 내보내기") ?? "Excel Export"

        let header = "\(dateLabel),\(typeLabel),\(vendorLabel),\(catLabel),\(amtLabel),\(notesLabel)\n"
        let rows = transactions.map { t in
            [
                csvValue(t.date.formatted(date: .numeric, time: .omitted)),
                csvValue(t.type == .income ? incomeLabel : expenseLabel),
                csvValue(t.vendor),
                csvValue(t.category),
                csvValue(t.amount.currencyString(code: currencyCode)),
                csvValue(t.notes ?? "")
            ].joined(separator: ",")
        }
        let output = header + rows.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safeFilename(companyName)) \(reportFilenameLabel).csv")
        try output.write(to: url, atomically: true, encoding: .utf8)
        return ExportDocument(title: exportTitle, fileURL: url)
    }

    // MARK: - PDF

    #if canImport(UIKit)
    static func makePDF(
        transactions: [AccountingTransaction],
        companyName: String,
        currencyCode: String,
        profile: OnboardingProfile? = nil
    ) throws -> ExportDocument {
        let pageW: CGFloat = 612
        let pageH: CGFloat = 842
        let margin: CGFloat = 48
        let contentW = pageW - margin * 2

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH))

        // Localized labels
        let p = profile
        func loc(
            en: String,
            es: String,
            pt: String,
            fr: String,
            ar: String? = nil,
            de: String? = nil,
            it: String? = nil,
            nl: String? = nil,
            ja: String? = nil,
            ko: String? = nil
        ) -> String {
            p?.text(en: en, es: es, pt: pt, fr: fr, ar: ar, de: de, it: it, nl: nl, ja: ja, ko: ko) ?? en
        }

        let reportFilenameLabel = loc(en: "Report", es: "Reporte", pt: "Relatorio", fr: "Rapport", ar: "تقرير", de: "Bericht", it: "Report", nl: "Rapport", ja: "レポート", ko: "보고서")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safeFilename(companyName)) \(reportFilenameLabel).pdf")

        // Colors
        let darkBG  = UIColor(red: 0.05, green: 0.05, blue: 0.07, alpha: 1)
        let cardBG  = UIColor(red: 0.10, green: 0.10, blue: 0.13, alpha: 1)
        let accent  = UIColor(red: 0.20, green: 0.48, blue: 0.90, alpha: 1)
        let green   = UIColor(red: 0.16, green: 0.78, blue: 0.38, alpha: 1)
        let red     = UIColor(red: 0.91, green: 0.26, blue: 0.26, alpha: 1)
        let textPrimary   = UIColor.white
        let textSecondary = UIColor(white: 0.68, alpha: 1)
        let textTertiary  = UIColor(white: 0.50, alpha: 1)
        let divider       = UIColor(white: 1, alpha: 0.07)

        // Typography helpers
        func attrs(_ size: CGFloat, weight: UIFont.Weight = .regular, color: UIColor = UIColor.white, mono: Bool = false) -> [NSAttributedString.Key: Any] {
            let font: UIFont = mono
                ? UIFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
                : UIFont.systemFont(ofSize: size, weight: weight)
            return [.font: font, .foregroundColor: color]
        }
        func drawText(_ str: String, at point: CGPoint, attrs: [NSAttributedString.Key: Any]) {
            str.draw(at: point, withAttributes: attrs)
        }
        func drawText(_ str: String, in rect: CGRect, attrs: [NSAttributedString.Key: Any]) {
            let nsStr = str as NSString
            nsStr.draw(in: rect, withAttributes: attrs)
        }
        func fillRect(_ rect: CGRect, color: UIColor, cornerRadius: CGFloat = 0) {
            let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
            color.setFill()
            path.fill()
        }
        func strokeLine(from: CGPoint, to: CGPoint, color: UIColor, width: CGFloat = 0.5) {
            let path = UIBezierPath()
            path.move(to: from)
            path.addLine(to: to)
            color.setStroke()
            path.lineWidth = width
            path.stroke()
        }

        // Summary values
        let totalIncome   = transactions.totalIncome
        let totalExpenses = transactions.totalExpenses
        let netProfit     = transactions.profit
        let taxRate       = p?.estimatedTaxRate(on: max(netProfit, .zero)) ?? 0
        let taxEstimate   = netProfit > .zero ? netProfit * taxRate : .zero

        // Country tax name
        let taxLabel = p.flatMap { pr in
            BXSupportedCountries.first { $0.name == pr.country }?.taxName
        } ?? loc(en: "Estimated Tax", es: "Impuesto Estimado", pt: "Imposto Estimado", fr: "Impôt Estimé", ar: "الضريبة التقديرية", de: "Geschätzte Steuer", it: "Imposta stimata", nl: "Geschatte belasting", ja: "推定税額", ko: "예상 세금")

        // Category breakdown (top 8)
        let expensesByCat = Dictionary(grouping: transactions.filter { $0.type == .expense }, by: \.category)
            .mapValues { $0.reduce(into: Decimal.zero) { $0 += $1.amount } }
            .sorted { $0.value > $1.value }
            .prefix(8)

        try renderer.writePDF(to: url) { ctx in
            var currentY: CGFloat = 0
            var pageIndex = 0

            func beginPage() {
                ctx.beginPage()
                pageIndex += 1
                // Dark background
                fillRect(CGRect(x: 0, y: 0, width: pageW, height: pageH), color: darkBG)

                // Header bar
                fillRect(CGRect(x: 0, y: 0, width: pageW, height: 64), color: cardBG)

                // Accent left strip
                fillRect(CGRect(x: 0, y: 0, width: 4, height: 64), color: accent, cornerRadius: 0)

                // Company name
                drawText(companyName, at: CGPoint(x: margin, y: 18), attrs: attrs(18, weight: .bold))

                // "Balance X Report" subtitle
                let subtitle = "Balance X · \(Date.now.formatted(date: .abbreviated, time: .omitted))"
                drawText(subtitle, at: CGPoint(x: margin, y: 40), attrs: attrs(10, color: textSecondary))

                // Page number (right side)
                if pageIndex > 1 {
                    let pageStr = loc(en: "p. \(pageIndex)", es: "p. \(pageIndex)", pt: "p. \(pageIndex)", fr: "p. \(pageIndex)", ar: "ص. \(pageIndex)", de: "S. \(pageIndex)", it: "p. \(pageIndex)", nl: "p. \(pageIndex)", ja: "\(pageIndex)ページ", ko: "\(pageIndex)쪽")
                    let strSize = (pageStr as NSString).size(withAttributes: attrs(10, color: textTertiary))
                    drawText(pageStr, at: CGPoint(x: pageW - margin - strSize.width, y: 26), attrs: attrs(10, color: textTertiary))
                }

                currentY = 80
            }

            func ensureSpace(_ needed: CGFloat) {
                if currentY + needed > pageH - 40 {
                    beginPage()
                }
            }

            // ── Page 1 ──────────────────────────────────────────────────────
            beginPage()
            currentY = 88

            // Report title
            let reportTitle = loc(en: "Financial Report", es: "Reporte Financiero",
                                  pt: "Relatório Financeiro", fr: "Rapport Financier",
                                  ar: "تقرير مالي", de: "Finanzbericht",
                                  it: "Report finanziario", nl: "Financieel rapport",
                                  ja: "財務レポート", ko: "재무 보고서")
            drawText(reportTitle, at: CGPoint(x: margin, y: currentY), attrs: attrs(28, weight: .bold))
            currentY += 36

            // Date subtitle
            let dateRange = loc(en: "Generated on", es: "Generado el",
                                pt: "Gerado em", fr: "Généré le",
                                ar: "تم الإنشاء في", de: "Erstellt am",
                                it: "Generato il", nl: "Gegenereerd op",
                                ja: "生成日", ko: "생성일")
                + " \(Date.now.formatted(date: .complete, time: .shortened))"
            drawText(dateRange, at: CGPoint(x: margin, y: currentY), attrs: attrs(11, color: textSecondary))
            currentY += 28

            // ── Summary Cards ────────────────────────────────────────────────
            let cardH: CGFloat = 72
            let cardSpacing: CGFloat = 8
            let cardW = (contentW - cardSpacing * 2) / 3

            let summaryData: [(String, String, UIColor)] = [
                (loc(en: "Total Income", es: "Ingresos Totales", pt: "Receita Total", fr: "Revenus Totaux", ar: "إجمالي الدخل", de: "Gesamteinnahmen", it: "Entrate totali", nl: "Totale inkomsten", ja: "総収入", ko: "총수입"),
                 totalIncome.currencyString(code: currencyCode), green),
                (loc(en: "Total Expenses", es: "Gastos Totales", pt: "Despesas Totais", fr: "Dépenses Totales", ar: "إجمالي المصروفات", de: "Gesamtausgaben", it: "Spese totali", nl: "Totale uitgaven", ja: "総支出", ko: "총지출"),
                 totalExpenses.currencyString(code: currencyCode), red),
                (loc(en: "Net Balance", es: "Balance Neto", pt: "Saldo Líquido", fr: "Solde Net", ar: "الرصيد الصافي", de: "Nettosaldo", it: "Saldo netto", nl: "Nettosaldo", ja: "純残高", ko: "순잔액"),
                 (netProfit >= 0 ? "+" : "") + netProfit.currencyString(code: currencyCode),
                 netProfit >= 0 ? green : red)
            ]

            for (idx, (label, value, color)) in summaryData.enumerated() {
                let x = margin + CGFloat(idx) * (cardW + cardSpacing)
                let cardRect = CGRect(x: x, y: currentY, width: cardW, height: cardH)
                fillRect(cardRect, color: cardBG, cornerRadius: 10)
                // Color left strip
                fillRect(CGRect(x: x, y: currentY, width: 3, height: cardH), color: color, cornerRadius: 0)

                drawText(label, in: CGRect(x: x + 12, y: currentY + 10, width: cardW - 16, height: 16),
                         attrs: attrs(10, color: textSecondary))
                drawText(value, in: CGRect(x: x + 12, y: currentY + 30, width: cardW - 16, height: 22),
                         attrs: attrs(15, weight: .bold, color: color, mono: true))
            }
            currentY += cardH + 20

            // ── Tax Estimate Card ────────────────────────────────────────────
            let taxCardH: CGFloat = 52
            let taxCardRect = CGRect(x: margin, y: currentY, width: contentW, height: taxCardH)
            fillRect(taxCardRect, color: UIColor(red: 0.91, green: 0.26, blue: 0.26, alpha: 0.12), cornerRadius: 10)
            UIColor(red: 0.91, green: 0.26, blue: 0.26, alpha: 0.40).setStroke()
            UIBezierPath(roundedRect: taxCardRect, cornerRadius: 10).stroke()

            drawText(taxLabel, at: CGPoint(x: margin + 14, y: currentY + 10), attrs: attrs(11, color: textSecondary))
            let taxStr = taxEstimate.currencyString(code: currencyCode)
            let taxStrSize = (taxStr as NSString).size(withAttributes: attrs(15, weight: .bold, color: red, mono: true))
            drawText(taxStr,
                     at: CGPoint(x: pageW - margin - taxStrSize.width - 14, y: currentY + 8),
                     attrs: attrs(15, weight: .bold, color: red, mono: true))
            let taxNote = loc(en: "approx. \(Int((taxRate as NSDecimalNumber).doubleValue * 100))% rate",
                              es: "aprox. \(Int((taxRate as NSDecimalNumber).doubleValue * 100))% tasa",
                              pt: "aprox. \(Int((taxRate as NSDecimalNumber).doubleValue * 100))%",
                              fr: "env. \(Int((taxRate as NSDecimalNumber).doubleValue * 100))% taux",
                              ar: "حوالي \(Int((taxRate as NSDecimalNumber).doubleValue * 100))% معدل",
                              de: "ca. \(Int((taxRate as NSDecimalNumber).doubleValue * 100))% Steuersatz",
                              it: "circa \(Int((taxRate as NSDecimalNumber).doubleValue * 100))% aliquota",
                              nl: "ca. \(Int((taxRate as NSDecimalNumber).doubleValue * 100))% tarief",
                              ja: "約\(Int((taxRate as NSDecimalNumber).doubleValue * 100))%税率",
                              ko: "약 \(Int((taxRate as NSDecimalNumber).doubleValue * 100))% 세율")
            drawText(taxNote, at: CGPoint(x: margin + 14, y: currentY + 28), attrs: attrs(9, color: textTertiary))
            currentY += taxCardH + 24

            // ── Category Breakdown ───────────────────────────────────────────
            if !expensesByCat.isEmpty {
                let catTitle = loc(en: "Expenses by Category", es: "Gastos por Categoría",
                                   pt: "Despesas por Categoria", fr: "Dépenses par Catégorie",
                                   ar: "المصروفات حسب الفئة", de: "Ausgaben nach Kategorie",
                                   it: "Spese per categoria", nl: "Uitgaven per categorie",
                                   ja: "カテゴリ別支出", ko: "카테고리별 지출")
                drawText(catTitle, at: CGPoint(x: margin, y: currentY), attrs: attrs(14, weight: .semibold))
                currentY += 22

                let catTotal = expensesByCat.reduce(Decimal.zero) { $0 + $1.value }

                for (cat, amt) in expensesByCat {
                    ensureSpace(26)

                    let pct = catTotal > 0
                        ? Double(truncating: (amt / catTotal * 100) as NSDecimalNumber)
                        : 0.0
                    let barMaxW = contentW * 0.45
                    let barW = CGFloat(pct / 100.0) * barMaxW

                    // Bar background
                    let barBGRect = CGRect(x: margin, y: currentY + 5, width: barMaxW, height: 10)
                    fillRect(barBGRect, color: UIColor(white: 1, alpha: 0.06), cornerRadius: 5)
                    // Bar fill
                    if barW > 0 {
                        let barFillRect = CGRect(x: margin, y: currentY + 5, width: barW, height: 10)
                        fillRect(barFillRect, color: red.withAlphaComponent(0.75), cornerRadius: 5)
                    }

                    // Category name
                    drawText(cat, in: CGRect(x: margin + barMaxW + 10, y: currentY, width: contentW * 0.32, height: 20),
                             attrs: attrs(10, color: textSecondary))
                    // Amount
                    let amtStr = amt.currencyString(code: currencyCode)
                    let amtSize = (amtStr as NSString).size(withAttributes: attrs(10, weight: .medium, color: textPrimary, mono: true))
                    drawText(amtStr,
                             at: CGPoint(x: pageW - margin - amtSize.width, y: currentY),
                             attrs: attrs(10, weight: .medium, color: textPrimary, mono: true))
                    // Percentage
                    let pctStr = String(format: "%.0f%%", pct)
                    let pctSize = (pctStr as NSString).size(withAttributes: attrs(9, color: textTertiary))
                    drawText(pctStr,
                             at: CGPoint(x: pageW - margin - amtSize.width - pctSize.width - 8, y: currentY + 1),
                             attrs: attrs(9, color: textTertiary))

                    currentY += 22
                    strokeLine(from: CGPoint(x: margin, y: currentY - 2),
                               to: CGPoint(x: margin + contentW, y: currentY - 2),
                               color: divider)
                }
                currentY += 12
            }

            // ── Transactions Table ───────────────────────────────────────────
            ensureSpace(60)

            let txTitle = loc(en: "Transaction Detail", es: "Detalle de Movimientos",
                              pt: "Detalhe de Transações", fr: "Détail des Transactions",
                              ar: "تفاصيل المعاملات", de: "Transaktionsdetails",
                              it: "Dettaglio transazioni", nl: "Transactiedetails",
                              ja: "取引詳細", ko: "거래 상세")
            drawText(txTitle, at: CGPoint(x: margin, y: currentY), attrs: attrs(14, weight: .semibold))
            currentY += 8

            // Column widths
            let colDate: CGFloat = 70
            let colType: CGFloat = 50
            let colCat: CGFloat = 80
            let colVendor: CGFloat = contentW - colDate - colType - colCat - 72
            let colAmt: CGFloat = 72

            let colXDate   = margin
            let colXType   = colXDate + colDate
            let colXVendor = colXType + colType
            let colXCat    = colXVendor + colVendor
            let colXAmt    = colXCat + colCat

            // Header row
            currentY += 10
            let headerRowH: CGFloat = 20
            fillRect(CGRect(x: margin, y: currentY, width: contentW, height: headerRowH), color: cardBG, cornerRadius: 4)

            let hAttrs = attrs(9, weight: .semibold, color: textTertiary)
            drawText(loc(en: "DATE", es: "FECHA", pt: "DATA", fr: "DATE",
                         ar: "التاريخ", de: "DATUM", it: "DATA", nl: "DATUM",
                         ja: "日付", ko: "날짜"),
                     at: CGPoint(x: colXDate + 4, y: currentY + 4), attrs: hAttrs)
            drawText(loc(en: "TYPE", es: "TIPO", pt: "TIPO", fr: "TYPE",
                         ar: "النوع", de: "TYP", it: "TIPO", nl: "TYPE",
                         ja: "種類", ko: "유형"),
                     at: CGPoint(x: colXType + 4, y: currentY + 4), attrs: hAttrs)
            drawText(loc(en: "VENDOR", es: "COMERCIO", pt: "FORNECEDOR", fr: "FOURNISSEUR",
                         ar: "التاجر", de: "HÄNDLER", it: "ESERCENTE", nl: "LEVERANCIER",
                         ja: "店舗", ko: "거래처"),
                     at: CGPoint(x: colXVendor + 4, y: currentY + 4), attrs: hAttrs)
            drawText(loc(en: "CATEGORY", es: "CATEGORÍA", pt: "CATEGORIA", fr: "CATÉGORIE",
                         ar: "الفئة", de: "KATEGORIE", it: "CATEGORIA", nl: "CATEGORIE",
                         ja: "カテゴリ", ko: "카테고리"),
                     at: CGPoint(x: colXCat + 4, y: currentY + 4), attrs: hAttrs)
            let amtHeader = loc(en: "AMOUNT", es: "MONTO", pt: "VALOR", fr: "MONTANT",
                                ar: "المبلغ", de: "BETRAG", it: "IMPORTO", nl: "BEDRAG",
                                ja: "金額", ko: "금액")
            let amtHeaderSize = (amtHeader as NSString).size(withAttributes: hAttrs)
            drawText(amtHeader,
                     at: CGPoint(x: colXAmt + colAmt - amtHeaderSize.width - 4, y: currentY + 4),
                     attrs: hAttrs)
            currentY += headerRowH + 2

            // Transaction rows
            let rowH: CGFloat = 20
            var rowOdd = false

            for tx in transactions {
                ensureSpace(rowH + 4)

                rowOdd.toggle()
                if rowOdd {
                    fillRect(CGRect(x: margin, y: currentY, width: contentW, height: rowH),
                             color: UIColor(white: 1, alpha: 0.025), cornerRadius: 3)
                }

                let dateStr = tx.date.formatted(date: .numeric, time: .omitted)
                let typeStr = tx.type == .income
                    ? loc(en: "Income", es: "Ingreso", pt: "Receita", fr: "Revenu",
                          ar: "دخل", de: "Einnahme", it: "Entrata", nl: "Inkomst",
                          ja: "収入", ko: "수입")
                    : loc(en: "Expense", es: "Gasto", pt: "Despesa", fr: "Dépense",
                          ar: "مصروف", de: "Ausgabe", it: "Spesa", nl: "Uitgave",
                          ja: "支出", ko: "지출")
                let typeColor: UIColor = tx.type == .income ? green : red
                let amtStr = (tx.type == .income ? "+" : "-") + tx.amount.currencyString(code: currencyCode)
                let amtColor: UIColor = tx.type == .income ? green : red

                drawText(dateStr, in: CGRect(x: colXDate + 4, y: currentY + 3, width: colDate - 6, height: rowH),
                         attrs: attrs(9, color: textSecondary, mono: true))
                drawText(typeStr, in: CGRect(x: colXType + 4, y: currentY + 3, width: colType - 6, height: rowH),
                         attrs: attrs(9, weight: .medium, color: typeColor))
                drawText(tx.vendor, in: CGRect(x: colXVendor + 4, y: currentY + 3, width: colVendor - 6, height: rowH),
                         attrs: attrs(9, color: textPrimary))
                drawText(tx.category, in: CGRect(x: colXCat + 4, y: currentY + 3, width: colCat - 6, height: rowH),
                         attrs: attrs(9, color: textSecondary))
                let amtSize = (amtStr as NSString).size(withAttributes: attrs(9, weight: .semibold, color: amtColor, mono: true))
                drawText(amtStr,
                         at: CGPoint(x: colXAmt + colAmt - amtSize.width - 4, y: currentY + 3),
                         attrs: attrs(9, weight: .semibold, color: amtColor, mono: true))

                currentY += rowH
                strokeLine(from: CGPoint(x: margin, y: currentY),
                           to: CGPoint(x: margin + contentW, y: currentY),
                           color: divider, width: 0.3)
            }

            // ── Footer ───────────────────────────────────────────────────────
            ensureSpace(40)
            currentY += 20
            strokeLine(from: CGPoint(x: margin, y: currentY),
                       to: CGPoint(x: margin + contentW, y: currentY),
                       color: divider)
            currentY += 8

            let footerStr = "Balance X · \(companyName) · \(Date.now.formatted(date: .complete, time: .omitted))"
            let footerAttrs = attrs(8, color: textTertiary)
            let footerSize = (footerStr as NSString).size(withAttributes: footerAttrs)
            drawText(footerStr,
                     at: CGPoint(x: (pageW - footerSize.width) / 2, y: currentY),
                     attrs: footerAttrs)

            let totalStr = loc(en: "\(transactions.count) transactions",
                               es: "\(transactions.count) movimientos",
                               pt: "\(transactions.count) transações",
                               fr: "\(transactions.count) transactions",
                               ar: "\(transactions.count) معاملة",
                               de: "\(transactions.count) Transaktionen",
                               it: "\(transactions.count) transazioni",
                               nl: "\(transactions.count) transacties",
                               ja: "\(transactions.count)件の取引",
                               ko: "\(transactions.count)건 거래")
            let totalAttrs = attrs(8, color: textTertiary)
            let totalSize = (totalStr as NSString).size(withAttributes: totalAttrs)
            drawText(totalStr,
                     at: CGPoint(x: (pageW - totalSize.width) / 2, y: currentY + 14),
                     attrs: totalAttrs)
        }

        return ExportDocument(title: loc(en: "PDF Export", es: "Exportación PDF", pt: "Exportação PDF", fr: "Export PDF", ar: "تصدير PDF", de: "PDF-Export", it: "Esportazione PDF", nl: "PDF-export", ja: "PDFエクスポート", ko: "PDF 내보내기"), fileURL: url)
    }
    #endif

    // MARK: - Helpers

    private static func csvValue(_ string: String) -> String {
        "\"\(string.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static func safeFilename(_ value: String) -> String {
        value.replacingOccurrences(of: "/", with: "-")
    }
}
