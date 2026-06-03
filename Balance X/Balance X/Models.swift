import Foundation

enum AuthState {
    case loading
    case signedOut
    case signedIn
}

enum MemberRole: String, Codable {
    case owner
    case accountant
    case viewer
}

enum TransactionType: String, Codable {
    case income
    case expense
}

struct Company: Identifiable, Codable, Hashable {
    let id: UUID
    let ownerID: UUID
    let name: String
    let logoURL: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case ownerID = "owner_id"
        case name
        case logoURL = "logo_url"
        case createdAt = "created_at"
    }
}

struct Member: Identifiable, Codable, Hashable {
    let id: UUID
    let userID: UUID
    let companyID: UUID
    let role: MemberRole
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case companyID = "company_id"
        case role
        case createdAt = "created_at"
    }
}

enum TeamInvitationStatus: String, Codable, CaseIterable, Identifiable {
    case pending
    case accepted
    case revoked

    var id: String { rawValue }
}

struct TeamInvitation: Identifiable, Codable, Hashable {
    let id: UUID
    let companyID: UUID
    var email: String
    var role: MemberRole
    var status: TeamInvitationStatus
    let createdAt: Date
    var respondedAt: Date?
}

struct CustomCategory: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var isHidden: Bool
    let createdAt: Date
}

enum ReconciliationStatus: String, Codable, CaseIterable, Identifiable {
    case pending
    case reviewed
    case reconciled

    var id: String { rawValue }
}

struct TransactionAuditEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let transactionID: UUID
    let action: String
    let detail: String
    let createdAt: Date
}

struct AccountingTransaction: Identifiable, Codable, Hashable {
    let id: UUID
    let companyID: UUID
    let type: TransactionType
    let amount: Decimal
    let vendor: String
    let category: String
    let date: Date
    let notes: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case companyID = "company_id"
        case type
        case amount
        case vendor
        case category
        case date
        case notes
        case createdAt = "created_at"
    }
}

struct Receipt: Identifiable, Codable, Hashable {
    let id: UUID
    let transactionID: UUID
    let imageURL: String
    let vendor: String
    let amount: Decimal
    let date: Date
    let rawText: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case transactionID = "transaction_id"
        case imageURL = "image_url"
        case vendor
        case amount
        case date
        case rawText = "raw_text"
        case createdAt = "created_at"
    }
}

struct OCRReceiptResponse: Codable {
    let vendor: String
    let amount: Double
    let date: String
}

struct OCRVisionScanResult {
    let response: OCRReceiptResponse
    let rawText: String
    let currencyCode: String?
    let documentType: OCRDocumentType
    let suggestedCategory: String?
    let suggestedTransactionType: TransactionType?
}

enum OCRDocumentType: String {
    case receipt
    case transfer
    case invoice
    case unknown
}

struct LearnedReceiptCorrection: Codable, Hashable, Identifiable {
    let id: UUID
    let signature: String
    let correctedVendor: String
    let correctedCategory: String
    let correctedTransactionType: TransactionType
    let updatedAt: Date
}

struct NewTransactionPayload: Codable {
    let companyID: UUID
    let type: TransactionType
    let amount: Decimal
    let vendor: String
    let category: String
    let date: Date
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case companyID = "company_id"
        case type
        case amount
        case vendor
        case category
        case date
        case notes
    }
}

struct NewReceiptPayload: Codable {
    let transactionID: UUID
    let imageURL: String
    let vendor: String
    let amount: Decimal
    let date: Date
    let rawText: String?

    enum CodingKeys: String, CodingKey {
        case transactionID = "transaction_id"
        case imageURL = "image_url"
        case vendor
        case amount
        case date
        case rawText = "raw_text"
    }
}

struct LocalSandboxAccount: Codable, Identifiable, Hashable {
    let id: UUID
    let email: String
    let password: String
    let company: Company
    let createdAt: Date
}

struct OnboardingProfile: Codable, Hashable {
    let country: String
    let language: String
    let currencyCode: String
    let workspaceType: WorkspaceType
    let personName: String
    let workspaceName: String

    static var `default`: OnboardingProfile {
        OnboardingProfile(
            country: "United States",
            language: "English",
            currencyCode: "USD",
            workspaceType: .personal,
            personName: "",
            workspaceName: ""
        )
    }
}

struct AppNotificationItem: Identifiable, Codable, Hashable {
    enum Kind: String, Codable {
        case reminder
        case tax
        case subscription
        case insight
    }

    let id: UUID
    let title: String
    let message: String
    let date: Date
    let kind: Kind
}

struct CurrencyConversionResult {
    let amount: Decimal
    let sourceCurrencyCode: String?
}

enum MonthlyPaymentCategory: String, Codable, CaseIterable, Identifiable {
    case rent = "Rent"
    case installment = "Installment"
    case subscription = "Subscription"
    case service = "Service"
    case other = "Other"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .rent: return "house.fill"
        case .installment: return "creditcard.fill"
        case .subscription: return "repeat.circle.fill"
        case .service: return "bolt.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }

    func label(_ profile: OnboardingProfile) -> String {
        switch self {
        case .rent:
            return profile.text(en: "Rent", es: "Renta", pt: "Aluguel", fr: "Loyer", ar: "إيجار", de: "Miete", it: "Affitto", nl: "Huur", ja: "家賃", ko: "임대료")
        case .installment:
            return profile.text(en: "Installment", es: "Cuota/Abono", pt: "Parcela", fr: "Versement", ar: "قسط", de: "Rate", it: "Rata", nl: "Termijn", ja: "分割払い", ko: "할부")
        case .subscription:
            return profile.text(en: "Subscription", es: "Suscripción", pt: "Assinatura", fr: "Abonnement", ar: "اشتراك", de: "Abonnement", it: "Abbonamento", nl: "Abonnement", ja: "サブスクリプション", ko: "구독")
        case .service:
            return profile.text(en: "Service", es: "Servicio", pt: "Serviço", fr: "Service", ar: "خدمة", de: "Dienstleistung", it: "Servizio", nl: "Dienst", ja: "サービス", ko: "서비스")
        case .other:
            return profile.text(en: "Other", es: "Otro", pt: "Outro", fr: "Autre", ar: "أخرى", de: "Sonstiges", it: "Altro", nl: "Overig", ja: "その他", ko: "기타")
        }
    }
}

struct SubscriptionItem: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let amount: Decimal
    let dueDay: Int
    var category: MonthlyPaymentCategory
    let notes: String?
    let createdAt: Date
    /// Months marked as paid, stored as "YYYY-MM" strings
    var paidMonths: [String]

    init(id: UUID, name: String, amount: Decimal, dueDay: Int, category: MonthlyPaymentCategory = .subscription, notes: String?, createdAt: Date, paidMonths: [String] = []) {
        self.id = id; self.name = name; self.amount = amount
        self.dueDay = dueDay; self.category = category
        self.notes = notes; self.createdAt = createdAt
        self.paidMonths = paidMonths
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        amount = try c.decode(Decimal.self, forKey: .amount)
        dueDay = try c.decode(Int.self, forKey: .dueDay)
        category = try c.decodeIfPresent(MonthlyPaymentCategory.self, forKey: .category) ?? .subscription
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        paidMonths = (try? c.decodeIfPresent([String].self, forKey: .paidMonths)) ?? []
    }

    /// Whether this subscription has been marked paid for the current month
    var isPaidThisMonth: Bool {
        let key = Self.monthKey(for: .now)
        return paidMonths.contains(key)
    }

    /// Whether the due day has already passed this month (payment is overdue if not paid)
    var isDueOrOverdue: Bool {
        let today = Calendar.current.component(.day, from: .now)
        return today >= dueDay && !isPaidThisMonth
    }

    static func monthKey(for date: Date) -> String {
        let cal = Calendar.current
        let y = cal.component(.year, from: date)
        let m = cal.component(.month, from: date)
        return String(format: "%04d-%02d", y, m)
    }
}

struct BudgetItem: Identifiable, Codable, Hashable {
    let id: UUID
    let category: String
    let monthlyLimit: Decimal
    let createdAt: Date
}

struct SavingsGoal: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let targetAmount: Decimal
    var savedAmount: Decimal
    var targetDate: Date?
    let createdAt: Date
}

enum WorkspaceType: String, Codable, CaseIterable, Identifiable {
    case personal = "Personal"
    case business = "Business"

    var id: String { rawValue }
}

struct ExportDocument: Identifiable {
    let id = UUID()
    let title: String
    let fileURL: URL
}

extension Decimal {
    var currencyString: String {
        currencyString()
    }

    /// Formats this decimal as a currency string using the system locale.
    func currencyString(code: String = Locale.current.currency?.identifier ?? "USD") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        return formatter.string(from: self as NSDecimalNumber) ?? "\(code) 0"
    }

    /// Formats using the locale that matches the user's app language + country.
    /// Produces region-correct formatting: R$ 1.234,56 (BR), 1.234,56 € (DE), ¥1,235 (JP).
    func currencyString(code: String, localeID: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.locale = Locale(identifier: localeID)
        // Japanese yen and Korean won have no decimal places
        if code == "JPY" || code == "KRW" {
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 0
        }
        return formatter.string(from: self as NSDecimalNumber) ?? "\(code) 0"
    }

    /// Formats using an OnboardingProfile for full locale-awareness.
    func currencyString(profile: OnboardingProfile) -> String {
        currencyString(code: profile.currencyCode, localeID: profile.localeIdentifier)
    }

    /// Smart formatted string that abbreviates large values (K, M, B) to fit on one line.
    func smartCurrencyString(code: String = Locale.current.currency?.identifier ?? "USD") -> String {
        let absValue = abs((self as NSDecimalNumber).doubleValue)
        let symbol = currencySymbol(for: code)

        let formatted: String
        if absValue >= 1_000_000_000 {
            formatted = String(format: "%.1fB", (self as NSDecimalNumber).doubleValue / 1_000_000_000)
        } else if absValue >= 1_000_000 {
            formatted = String(format: "%.1fM", (self as NSDecimalNumber).doubleValue / 1_000_000)
        } else if absValue >= 100_000 {
            formatted = String(format: "%.1fK", (self as NSDecimalNumber).doubleValue / 1_000)
        } else {
            return currencyString(code: code)
        }

        return "\(symbol)\(formatted)"
    }

    private func currencySymbol(for code: String) -> String {
        let locale = Locale.availableIdentifiers
            .map { Locale(identifier: $0) }
            .first { $0.currency?.identifier == code }
        return locale?.currencySymbol ?? "$"
    }
}

enum DashboardPeriod: String, CaseIterable, Identifiable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"

    var id: String { rawValue }
}

struct InsightCardModel: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let message: String
    let systemImage: String
}

extension Array where Element == AccountingTransaction {
    var totalIncome: Decimal {
        filter { $0.type == .income }.reduce(into: Decimal.zero) { partialResult, transaction in
            partialResult += transaction.amount
        }
    }

    var totalExpenses: Decimal {
        filter { $0.type == .expense }.reduce(into: Decimal.zero) { partialResult, transaction in
            partialResult += transaction.amount
        }
    }

    var profit: Decimal {
        totalIncome - totalExpenses
    }

    func chartPoints(for period: DashboardPeriod) -> [Decimal] {
        let calendar = Calendar.current
        let now = Date.now
        let range: Int
        let component: Calendar.Component

        switch period {
        case .daily:
            range = 7
            component = .day
        case .weekly:
            range = 8
            component = .weekOfYear
        case .monthly:
            range = 6
            component = .month
        }

        return (0..<range).map { offset in
            guard let targetDate = calendar.date(byAdding: component, value: -(range - offset - 1), to: now) else {
                return .zero
            }

            return filter { transaction in
                switch period {
                case .daily:
                    return calendar.isDate(transaction.date, inSameDayAs: targetDate)
                case .weekly:
                    return calendar.isDate(transaction.date, equalTo: targetDate, toGranularity: .weekOfYear)
                case .monthly:
                    return calendar.isDate(transaction.date, equalTo: targetDate, toGranularity: .month)
                }
            }
            .reduce(into: Decimal.zero) { partialResult, transaction in
                partialResult += transaction.type == .income ? transaction.amount : -transaction.amount
            }
        }
    }

    // swiftlint:disable function_body_length
    func topInsights(period: DashboardPeriod, profile: OnboardingProfile, currencyCode: String = "USD") -> [InsightCardModel] {
        let calendar = Calendar.current
        let now = Date.now

        let periodExpenses = recentTransactions(period: period).filter { $0.type == .expense }
        let periodIncome  = recentTransactions(period: period).filter { $0.type == .income }
        let prevExpenses  = previousTransactions(period: period).filter { $0.type == .expense }
        let prevIncome    = previousTransactions(period: period).filter { $0.type == .income }

        let periodExpTotal = periodExpenses.reduce(into: Decimal.zero) { $0 += $1.amount }
        let periodIncTotal = periodIncome.reduce(into: Decimal.zero) { $0 += $1.amount }
        let prevExpTotal   = prevExpenses.reduce(into: Decimal.zero) { $0 += $1.amount }
        let prevIncTotal   = prevIncome.reduce(into: Decimal.zero) { $0 += $1.amount }

        let allIncTotal = filter { $0.type == .income }.reduce(into: Decimal.zero) { $0 += $1.amount }
        let allExpTotal = filter { $0.type == .expense }.reduce(into: Decimal.zero) { $0 += $1.amount }

        func pct(_ num: Decimal, _ den: Decimal) -> Int {
            guard den > .zero else { return 0 }
            return Int(((num as NSDecimalNumber).doubleValue / (den as NSDecimalNumber).doubleValue * 100).rounded())
        }
        func dbl(_ d: Decimal) -> Double { (d as NSDecimalNumber).doubleValue }
        func loc(
            en: String,
            es: String,
            pt: String? = nil,
            fr: String? = nil,
            ar: String? = nil,
            de: String? = nil,
            it: String? = nil,
            nl: String? = nil,
            ja: String? = nil,
            ko: String? = nil
        ) -> String {
            profile.text(en: en, es: es, pt: pt, fr: fr, ar: ar, de: de, it: it, nl: nl, ja: ja, ko: ko)
        }

        var pool: [InsightCardModel] = []

        // 1. Top spending category this period
        let catTotals = Dictionary(grouping: periodExpenses, by: \.category)
            .mapValues { $0.reduce(into: Decimal.zero) { $0 += $1.amount } }
        if let topCat = catTotals.max(by: { $0.value < $1.value }), periodExpTotal > .zero {
            let p = pct(topCat.value, periodExpTotal)
            pool.append(InsightCardModel(
                title: loc(en: "Top Spending Category", es: "Mayor categoría de gasto", pt: "Principal categoria de gasto", fr: "Catégorie de dépense principale", ar: "أعلى فئة إنفاق", de: "Top-Ausgabenkategorie", it: "Categoria di spesa principale", nl: "Belangrijkste uitgavencategorie", ja: "支出上位カテゴリ", ko: "최대 지출 카테고리"),
                message: loc(en: "\(topCat.key) is \(p)% of your expenses — \(topCat.value.smartCurrencyString(code: currencyCode)) this period.", es: "\(topCat.key) representa el \(p)% de tus gastos — \(topCat.value.smartCurrencyString(code: currencyCode)) en este período.", pt: "\(topCat.key) representa \(p)% das suas despesas — \(topCat.value.smartCurrencyString(code: currencyCode)) neste período.", fr: "\(topCat.key) représente \(p)% de vos dépenses — \(topCat.value.smartCurrencyString(code: currencyCode)) sur cette période.", ar: "يمثل \(topCat.key) نسبة \(p)% من مصروفاتك — \(topCat.value.smartCurrencyString(code: currencyCode)) خلال هذه الفترة.", de: "\(topCat.key) macht \(p)% deiner Ausgaben aus — \(topCat.value.smartCurrencyString(code: currencyCode)) in diesem Zeitraum.", it: "\(topCat.key) rappresenta il \(p)% delle tue spese — \(topCat.value.smartCurrencyString(code: currencyCode)) in questo periodo.", nl: "\(topCat.key) is \(p)% van je uitgaven — \(topCat.value.smartCurrencyString(code: currencyCode)) in deze periode.", ja: "\(topCat.key) はこの期間の支出の \(p)% を占めます — \(topCat.value.smartCurrencyString(code: currencyCode))。", ko: "\(topCat.key)은(는) 이번 기간 지출의 \(p)%이며 금액은 \(topCat.value.smartCurrencyString(code: currencyCode))입니다."),
                systemImage: "tag.fill"
            ))
        }

        // 2. Income vs expense coverage
        if periodExpTotal > .zero && periodIncTotal > .zero {
            let p = pct(periodIncTotal, periodExpTotal)
            let surplus = periodIncTotal >= periodExpTotal
            pool.append(InsightCardModel(
                title: surplus
                    ? loc(en: "Positive Cash Flow", es: "Flujo positivo", pt: "Fluxo de caixa positivo", fr: "Flux de trésorerie positif", ar: "تدفق نقدي إيجابي", de: "Positiver Cashflow", it: "Flusso di cassa positivo", nl: "Positieve kasstroom", ja: "キャッシュフローはプラス", ko: "긍정적인 현금 흐름")
                    : loc(en: "Expenses Exceed Income", es: "Gastos superan ingresos", pt: "Despesas superam a receita", fr: "Les dépenses dépassent les revenus", ar: "المصروفات تتجاوز الدخل", de: "Ausgaben übersteigen Einnahmen", it: "Le spese superano le entrate", nl: "Uitgaven hoger dan inkomsten", ja: "支出が収入を上回っています", ko: "지출이 수입을 초과합니다"),
                message: loc(en: "Income covers \(p)% of expenses this period. \(surplus ? "Keep it up." : "Review where you can cut back.")", es: "Tus ingresos cubren el \(p)% de tus gastos este período. \(surplus ? "Mantén el ritmo." : "Revisa dónde puedes recortar.")", pt: "Sua receita cobre \(p)% das despesas neste período. \(surplus ? "Continue assim." : "Revise onde pode reduzir.")", fr: "Vos revenus couvrent \(p)% des dépenses sur cette période. \(surplus ? "Continuez ainsi." : "Voyez où vous pouvez réduire.")", ar: "يغطي دخلك \(p)% من مصروفاتك في هذه الفترة. \(surplus ? "استمر هكذا." : "راجع أين يمكنك التقليل.")", de: "Deine Einnahmen decken in diesem Zeitraum \(p)% der Ausgaben. \(surplus ? "Weiter so." : "Prüfe, wo du kürzen kannst.")", it: "Le tue entrate coprono il \(p)% delle spese in questo periodo. \(surplus ? "Continua così." : "Controlla dove puoi ridurre.")", nl: "Je inkomsten dekken \(p)% van de uitgaven in deze periode. \(surplus ? "Ga zo door." : "Kijk waar je kunt besparen.")", ja: "この期間、収入は支出の \(p)% をカバーしています。\(surplus ? "この調子を維持しましょう。" : "どこを削減できるか見直しましょう。")", ko: "이번 기간 수입은 지출의 \(p)%를 충당합니다. \(surplus ? "이 흐름을 유지하세요." : "줄일 수 있는 부분을 검토하세요.")"),
                systemImage: surplus ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"
            ))
        }

        // 3. Period-over-period spend change
        if prevExpTotal > .zero && periodExpTotal > .zero {
            let delta = (dbl(periodExpTotal) - dbl(prevExpTotal)) / dbl(prevExpTotal)
            let p = Int((abs(delta) * 100).rounded())
            let up = delta >= 0
            pool.append(InsightCardModel(
                title: loc(en: "Spending Trend", es: "Tendencia de gastos", pt: "Tendência de gastos", fr: "Tendance des dépenses", ar: "اتجاه الإنفاق", de: "Ausgabentrend", it: "Andamento delle spese", nl: "Uitgaventrend", ja: "支出トレンド", ko: "지출 추세"),
                message: loc(en: "You spent \(p)% \(up ? "more" : "less") than last period. \(up ? "Check which category grew." : "Good job controlling spending.")", es: "Gastaste \(p)% \(up ? "más" : "menos") que el período anterior. \(up ? "Identifica qué categoría creció." : "Buen trabajo controlando los gastos.")", pt: "Você gastou \(p)% \(up ? "mais" : "menos") do que no período anterior. \(up ? "Veja qual categoria cresceu." : "Bom trabalho controlando os gastos.")", fr: "Vous avez dépensé \(p)% \(up ? "de plus" : "de moins") que sur la période précédente. \(up ? "Vérifiez quelle catégorie a augmenté." : "Bon travail sur le contrôle des dépenses.")", ar: "أنفقت \(p)% \(up ? "أكثر" : "أقل") من الفترة السابقة. \(up ? "تحقق من الفئة التي ارتفعت." : "عمل جيد في ضبط الإنفاق.")", de: "Du hast \(p)% \(up ? "mehr" : "weniger") als im vorherigen Zeitraum ausgegeben. \(up ? "Prüfe, welche Kategorie gewachsen ist." : "Gute Arbeit beim Kontrollieren der Ausgaben.")", it: "Hai speso il \(p)% \(up ? "in più" : "in meno") rispetto al periodo precedente. \(up ? "Controlla quale categoria è cresciuta." : "Ottimo lavoro nel controllo delle spese.")", nl: "Je gaf \(p)% \(up ? "meer" : "minder") uit dan in de vorige periode. \(up ? "Bekijk welke categorie is gestegen." : "Goed gedaan met het beheersen van de uitgaven.")", ja: "前期間より \(p)% \(up ? "多く" : "少なく") 支出しました。\(up ? "どのカテゴリが増えたか確認しましょう。" : "支出管理がうまくできています。")", ko: "이전 기간보다 \(p)% \(up ? "더 많이" : "더 적게") 지출했습니다. \(up ? "어떤 카테고리가 늘었는지 확인하세요." : "지출을 잘 관리하고 있습니다.")"),
                systemImage: up ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill"
            ))
        }

        // 4. Period-over-period income change
        if prevIncTotal > .zero && periodIncTotal > .zero {
            let delta = (dbl(periodIncTotal) - dbl(prevIncTotal)) / dbl(prevIncTotal)
            let p = Int((abs(delta) * 100).rounded())
            let up = delta >= 0
            pool.append(InsightCardModel(
                title: loc(en: "Income Trend", es: "Tendencia de ingresos", pt: "Tendência da receita", fr: "Tendance des revenus", ar: "اتجاه الدخل", de: "Einnahmentrend", it: "Andamento delle entrate", nl: "Inkomstentrend", ja: "収入トレンド", ko: "수입 추세"),
                message: loc(en: "Your income \(up ? "grew" : "dropped") \(p)% vs the previous period.", es: "Tus ingresos \(up ? "subieron" : "bajaron") un \(p)% vs el período anterior.", pt: "Sua receita \(up ? "aumentou" : "caiu") \(p)% em relação ao período anterior.", fr: "Vos revenus ont \(up ? "augmenté" : "baissé") de \(p)% par rapport à la période précédente.", ar: "لقد \(up ? "زاد" : "انخفض") دخلك بنسبة \(p)% مقارنة بالفترة السابقة.", de: "Deine Einnahmen sind im Vergleich zum vorherigen Zeitraum um \(p)% \(up ? "gestiegen" : "gesunken").", it: "Le tue entrate \(up ? "sono aumentate" : "sono diminuite") del \(p)% rispetto al periodo precedente.", nl: "Je inkomsten zijn \(up ? "gestegen" : "gedaald") met \(p)% ten opzichte van de vorige periode.", ja: "収入は前期間比で \(p)% \(up ? "増加" : "減少") しました。", ko: "수입이 이전 기간 대비 \(p)% \(up ? "증가" : "감소") 했습니다."),
                systemImage: up ? "chart.line.uptrend.xyaxis" : "chart.line.downtrend.xyaxis"
            ))
        }

        // 5. Biggest single expense
        if let biggest = periodExpenses.max(by: { $0.amount < $1.amount }) {
            let dateStr = DateFormatter.localizedString(from: biggest.date, dateStyle: .short, timeStyle: .none)
            pool.append(InsightCardModel(
                title: loc(en: "Largest Single Expense", es: "Mayor gasto individual", pt: "Maior despesa individual", fr: "Plus grosse dépense", ar: "أكبر مصروف فردي", de: "Größte Einzel-Ausgabe", it: "Spesa singola più alta", nl: "Grootste enkele uitgave", ja: "最大の単発支出", ko: "가장 큰 단일 지출"),
                message: loc(en: "\(biggest.vendor) on \(dateStr): \(biggest.amount.smartCurrencyString(code: currencyCode)). Is this recurring or a one-off?", es: "\(biggest.vendor) el \(dateStr): \(biggest.amount.smartCurrencyString(code: currencyCode)). ¿Es recurrente o extraordinario?", pt: "\(biggest.vendor) em \(dateStr): \(biggest.amount.smartCurrencyString(code: currencyCode)). Isso é recorrente ou pontual?", fr: "\(biggest.vendor) le \(dateStr) : \(biggest.amount.smartCurrencyString(code: currencyCode)). Est-ce récurrent ou exceptionnel ?", ar: "\(biggest.vendor) في \(dateStr): \(biggest.amount.smartCurrencyString(code: currencyCode)). هل هذا متكرر أم لمرة واحدة؟", de: "\(biggest.vendor) am \(dateStr): \(biggest.amount.smartCurrencyString(code: currencyCode)). Ist das wiederkehrend oder einmalig?", it: "\(biggest.vendor) il \(dateStr): \(biggest.amount.smartCurrencyString(code: currencyCode)). È ricorrente o occasionale?", nl: "\(biggest.vendor) op \(dateStr): \(biggest.amount.smartCurrencyString(code: currencyCode)). Is dit terugkerend of eenmalig?", ja: "\(biggest.vendor) \(dateStr): \(biggest.amount.smartCurrencyString(code: currencyCode))。継続的な支出ですか、それとも一度きりですか？", ko: "\(biggest.vendor) \(dateStr): \(biggest.amount.smartCurrencyString(code: currencyCode)). 반복 지출인가요, 일회성인가요?"),
                systemImage: "arrow.up.forward.circle.fill"
            ))
        }

        // 6. Most frequent vendor (≥ 2 appearances)
        let vendorCounts = Dictionary(grouping: periodExpenses, by: \.vendor).mapValues { $0.count }
        if let topVendor = vendorCounts.filter({ $0.value >= 2 }).max(by: { $0.value < $1.value }) {
            let total = periodExpenses.filter { $0.vendor == topVendor.key }.reduce(into: Decimal.zero) { $0 += $1.amount }
            pool.append(InsightCardModel(
                title: loc(en: "Most Frequent Vendor", es: "Proveedor más frecuente", pt: "Fornecedor mais frequente", fr: "Fournisseur le plus fréquent", ar: "البائع الأكثر تكرارًا", de: "Häufigster Anbieter", it: "Fornitore più frequente", nl: "Meest voorkomende leverancier", ja: "最も多い店舗", ko: "가장 자주 이용한 판매처"),
                message: loc(en: "\(topVendor.key): \(topVendor.value) transactions — \(total.smartCurrencyString(code: currencyCode)) this period.", es: "\(topVendor.key): \(topVendor.value) transacciones — \(total.smartCurrencyString(code: currencyCode)) en este período.", pt: "\(topVendor.key): \(topVendor.value) transações — \(total.smartCurrencyString(code: currencyCode)) neste período.", fr: "\(topVendor.key) : \(topVendor.value) transactions — \(total.smartCurrencyString(code: currencyCode)) sur cette période.", ar: "\(topVendor.key): \(topVendor.value) معاملات — \(total.smartCurrencyString(code: currencyCode)) خلال هذه الفترة.", de: "\(topVendor.key): \(topVendor.value) Transaktionen — \(total.smartCurrencyString(code: currencyCode)) in diesem Zeitraum.", it: "\(topVendor.key): \(topVendor.value) transazioni — \(total.smartCurrencyString(code: currencyCode)) in questo periodo.", nl: "\(topVendor.key): \(topVendor.value) transacties — \(total.smartCurrencyString(code: currencyCode)) in deze periode.", ja: "\(topVendor.key): \(topVendor.value) 件の取引 — この期間で \(total.smartCurrencyString(code: currencyCode))。", ko: "\(topVendor.key): 거래 \(topVendor.value)건 — 이번 기간 \(total.smartCurrencyString(code: currencyCode))."),
                systemImage: "repeat.circle.fill"
            ))
        }

        // 7. Savings rate (all-time)
        if allIncTotal > .zero {
            let net = allIncTotal - allExpTotal
            let p = pct(net, allIncTotal)
            let positive = net >= .zero
            pool.append(InsightCardModel(
                title: loc(en: "Savings Rate", es: "Tasa de ahorro", pt: "Taxa de poupança", fr: "Taux d'épargne", ar: "معدل الادخار", de: "Sparquote", it: "Tasso di risparmio", nl: "Spaarpercentage", ja: "貯蓄率", ko: "저축률"),
                message: positive
                    ? loc(en: "Saving \(p)% of total income (\(net.smartCurrencyString(code: currencyCode)) net).", es: "Estás ahorrando el \(p)% de tus ingresos totales (\(net.smartCurrencyString(code: currencyCode)) neto).", pt: "Você está economizando \(p)% da receita total (\(net.smartCurrencyString(code: currencyCode)) líquidos).", fr: "Vous épargnez \(p)% de vos revenus totaux (\(net.smartCurrencyString(code: currencyCode)) nets).", ar: "أنت تدخر \(p)% من إجمالي دخلك (\(net.smartCurrencyString(code: currencyCode)) صافيًا).", de: "Du sparst \(p)% deiner Gesamteinnahmen (\(net.smartCurrencyString(code: currencyCode)) netto).", it: "Stai risparmiando il \(p)% delle entrate totali (\(net.smartCurrencyString(code: currencyCode)) netti).", nl: "Je spaart \(p)% van je totale inkomen (\(net.smartCurrencyString(code: currencyCode)) netto).", ja: "総収入の \(p)% を貯蓄しています（純額 \(net.smartCurrencyString(code: currencyCode))）。", ko: "총수입의 \(p)%를 저축하고 있습니다(순액 \(net.smartCurrencyString(code: currencyCode))).")
                    : loc(en: "Expenses exceed income by \((-net).smartCurrencyString(code: currencyCode)). Review your budget.", es: "Los gastos superan los ingresos por \((-net).smartCurrencyString(code: currencyCode)). Revisa tu presupuesto.", pt: "As despesas superam a receita em \((-net).smartCurrencyString(code: currencyCode)). Revise seu orçamento.", fr: "Les dépenses dépassent les revenus de \((-net).smartCurrencyString(code: currencyCode)). Révisez votre budget.", ar: "المصروفات تتجاوز الدخل بمقدار \((-net).smartCurrencyString(code: currencyCode)). راجع ميزانيتك.", de: "Die Ausgaben übersteigen die Einnahmen um \((-net).smartCurrencyString(code: currencyCode)). Prüfe dein Budget.", it: "Le spese superano le entrate di \((-net).smartCurrencyString(code: currencyCode)). Rivedi il tuo budget.", nl: "Uitgaven overschrijden inkomsten met \((-net).smartCurrencyString(code: currencyCode)). Bekijk je budget.", ja: "支出が収入を \((-net).smartCurrencyString(code: currencyCode)) 上回っています。予算を見直しましょう。", ko: "지출이 수입보다 \((-net).smartCurrencyString(code: currencyCode)) 많습니다. 예산을 점검하세요."),
                systemImage: positive ? "banknote.fill" : "exclamationmark.circle.fill"
            ))
        }

        // 8. Uncategorized expenses
        let uncat = periodExpenses.filter { profile.isUncategorizedCategory($0.category) }
        if !uncat.isEmpty {
            let uncatTotal = uncat.reduce(into: Decimal.zero) { $0 += $1.amount }
            pool.append(InsightCardModel(
                title: loc(en: "Uncategorized Expenses", es: "Gastos sin categorizar", pt: "Despesas sem categoria", fr: "Dépenses non catégorisées", ar: "مصروفات غير مصنفة", de: "Nicht kategorisierte Ausgaben", it: "Spese senza categoria", nl: "Niet-gecategoriseerde uitgaven", ja: "未分類の支出", ko: "미분류 지출"),
                message: loc(en: "\(uncat.count) expense(s) totaling \(uncatTotal.smartCurrencyString(code: currencyCode)) have no category. Tagging them improves your reports.", es: "\(uncat.count) gasto(s) por \(uncatTotal.smartCurrencyString(code: currencyCode)) sin categoría. Categorizarlos mejora tus reportes.", pt: "\(uncat.count) despesa(s), totalizando \(uncatTotal.smartCurrencyString(code: currencyCode)), estão sem categoria. Classificá-las melhora seus relatórios.", fr: "\(uncat.count) dépense(s), pour un total de \(uncatTotal.smartCurrencyString(code: currencyCode)), n'ont pas de catégorie. Les catégoriser améliore vos rapports.", ar: "هناك \(uncat.count) مصروف/مصروفات بقيمة \(uncatTotal.smartCurrencyString(code: currencyCode)) بدون فئة. تصنيفها يحسن تقاريرك.", de: "\(uncat.count) Ausgabe(n) über insgesamt \(uncatTotal.smartCurrencyString(code: currencyCode)) haben keine Kategorie. Das Kategorisieren verbessert deine Berichte.", it: "\(uncat.count) spesa/e per un totale di \(uncatTotal.smartCurrencyString(code: currencyCode)) non hanno categoria. Classificarle migliora i report.", nl: "\(uncat.count) uitgave(n) ter waarde van \(uncatTotal.smartCurrencyString(code: currencyCode)) hebben geen categorie. Categoriseren verbetert je rapporten.", ja: "\(uncat.count) 件の支出（合計 \(uncatTotal.smartCurrencyString(code: currencyCode))）にカテゴリがありません。分類するとレポート精度が上がります。", ko: "\(uncat.count)건의 지출(총 \(uncatTotal.smartCurrencyString(code: currencyCode)))에 카테고리가 없습니다. 분류하면 보고서 품질이 좋아집니다."),
                systemImage: "folder.badge.questionmark"
            ))
        }

        // 9. Average daily spend
        let daysInPeriod: Double
        switch period {
        case .daily: daysInPeriod = 7
        case .weekly: daysInPeriod = 56
        case .monthly: daysInPeriod = 180
        }
        if periodExpTotal > .zero {
            let avg = Decimal(dbl(periodExpTotal) / daysInPeriod)
            pool.append(InsightCardModel(
                title: loc(en: "Average Daily Spend", es: "Gasto promedio diario", pt: "Gasto médio diário", fr: "Dépense quotidienne moyenne", ar: "متوسط الإنفاق اليومي", de: "Durchschnittliche Tagesausgaben", it: "Spesa media giornaliera", nl: "Gemiddelde dagelijkse uitgave", ja: "1日あたり平均支出", ko: "일평균 지출"),
                message: loc(en: "You average \(avg.smartCurrencyString(code: currencyCode)) per day in spending this period.", es: "Gastas en promedio \(avg.smartCurrencyString(code: currencyCode)) por día en este período.", pt: "Você gasta em média \(avg.smartCurrencyString(code: currencyCode)) por dia neste período.", fr: "Vous dépensez en moyenne \(avg.smartCurrencyString(code: currencyCode)) par jour sur cette période.", ar: "متوسط إنفاقك اليومي في هذه الفترة هو \(avg.smartCurrencyString(code: currencyCode)).", de: "Du gibst in diesem Zeitraum durchschnittlich \(avg.smartCurrencyString(code: currencyCode)) pro Tag aus.", it: "In questo periodo spendi in media \(avg.smartCurrencyString(code: currencyCode)) al giorno.", nl: "Je geeft in deze periode gemiddeld \(avg.smartCurrencyString(code: currencyCode)) per dag uit.", ja: "この期間の1日あたり平均支出は \(avg.smartCurrencyString(code: currencyCode)) です。", ko: "이번 기간 하루 평균 지출은 \(avg.smartCurrencyString(code: currencyCode))입니다."),
                systemImage: "calendar.badge.clock"
            ))
        }

        // 10. Day of week with highest transaction count
        let dayGroups = Dictionary(grouping: periodExpenses) { calendar.component(.weekday, from: $0.date) }
        if let busyDay = dayGroups.max(by: { $0.value.count < $1.value.count }) {
            let idx = busyDay.key
            let weekdayFormatter = DateFormatter()
            weekdayFormatter.locale = Locale(identifier: profile.localeIdentifier)
            let weekdayNames = weekdayFormatter.weekdaySymbols ?? []
            let dayName = idx > 0 && idx - 1 < weekdayNames.count ? weekdayNames[idx - 1] : ""
            if !dayName.isEmpty {
                let dayTotal = busyDay.value.reduce(into: Decimal.zero) { $0 += $1.amount }
                pool.append(InsightCardModel(
                    title: loc(en: "Busiest Spending Day", es: "Día de mayor gasto", pt: "Dia com maior gasto", fr: "Jour le plus dépensier", ar: "أكثر يوم إنفاقًا", de: "Tag mit den höchsten Ausgaben", it: "Giorno con più spese", nl: "Drukste uitgavendag", ja: "最も支出が多い曜日", ko: "지출이 가장 많은 요일"),
                    message: loc(en: "\(dayName)s have the most spending (\(dayTotal.smartCurrencyString(code: currencyCode))). Plan purchases ahead.", es: "Los \(dayName)s concentran más gastos (\(dayTotal.smartCurrencyString(code: currencyCode))). Planifica compras con anticipación.", pt: "Os \(dayName)s concentram mais gastos (\(dayTotal.smartCurrencyString(code: currencyCode))). Planeje compras com antecedência.", fr: "Les \(dayName)s concentrent le plus de dépenses (\(dayTotal.smartCurrencyString(code: currencyCode))). Planifiez vos achats à l'avance.", ar: "تشهد أيام \(dayName) أعلى إنفاق (\(dayTotal.smartCurrencyString(code: currencyCode))). خطط للمشتريات مسبقًا.", de: "An \(dayName) gibt es die meisten Ausgaben (\(dayTotal.smartCurrencyString(code: currencyCode))). Plane Einkäufe im Voraus.", it: "I \(dayName) concentrano più spese (\(dayTotal.smartCurrencyString(code: currencyCode))). Pianifica gli acquisti in anticipo.", nl: "Op \(dayName) wordt het meest uitgegeven (\(dayTotal.smartCurrencyString(code: currencyCode))). Plan aankopen vooruit.", ja: "\(dayName) は支出が最も多い曜日です（\(dayTotal.smartCurrencyString(code: currencyCode))）。事前に買い物計画を立てましょう。", ko: "\(dayName)에 지출이 가장 많습니다(\(dayTotal.smartCurrencyString(code: currencyCode))). 구매 계획을 미리 세우세요."),
                    systemImage: "calendar"
                ))
            }
        }

        // 11. Net cash flow this period
        if periodIncTotal > .zero || periodExpTotal > .zero {
            let net = periodIncTotal - periodExpTotal
            let positive = net >= .zero
            pool.append(InsightCardModel(
                title: loc(en: "Net Cash Flow", es: "Flujo neto del período", pt: "Fluxo líquido do período", fr: "Flux net de la période", ar: "صافي التدفق للفترة", de: "Netto-Cashflow des Zeitraums", it: "Flusso netto del periodo", nl: "Netto kasstroom van de periode", ja: "期間の純キャッシュフロー", ko: "기간 순현금흐름"),
                message: positive
                    ? loc(en: "Net flow: +\(net.smartCurrencyString(code: currencyCode)). Income exceeds expenses.", es: "Flujo neto: +\(net.smartCurrencyString(code: currencyCode)). Los ingresos superan los gastos.", pt: "Fluxo líquido: +\(net.smartCurrencyString(code: currencyCode)). A receita supera as despesas.", fr: "Flux net : +\(net.smartCurrencyString(code: currencyCode)). Les revenus dépassent les dépenses.", ar: "صافي التدفق: +\(net.smartCurrencyString(code: currencyCode)). الدخل يتجاوز المصروفات.", de: "Nettofluss: +\(net.smartCurrencyString(code: currencyCode)). Einnahmen übersteigen Ausgaben.", it: "Flusso netto: +\(net.smartCurrencyString(code: currencyCode)). Le entrate superano le spese.", nl: "Netto stroom: +\(net.smartCurrencyString(code: currencyCode)). Inkomsten zijn hoger dan uitgaven.", ja: "純フロー: +\(net.smartCurrencyString(code: currencyCode))。収入が支出を上回っています。", ko: "순흐름: +\(net.smartCurrencyString(code: currencyCode)). 수입이 지출을 초과합니다.")
                    : loc(en: "Net flow: \(net.smartCurrencyString(code: currencyCode)). Expenses exceed income.", es: "Flujo neto: \(net.smartCurrencyString(code: currencyCode)). Los gastos superan los ingresos.", pt: "Fluxo líquido: \(net.smartCurrencyString(code: currencyCode)). As despesas superam a receita.", fr: "Flux net : \(net.smartCurrencyString(code: currencyCode)). Les dépenses dépassent les revenus.", ar: "صافي التدفق: \(net.smartCurrencyString(code: currencyCode)). المصروفات تتجاوز الدخل.", de: "Nettofluss: \(net.smartCurrencyString(code: currencyCode)). Ausgaben übersteigen Einnahmen.", it: "Flusso netto: \(net.smartCurrencyString(code: currencyCode)). Le spese superano le entrate.", nl: "Netto stroom: \(net.smartCurrencyString(code: currencyCode)). Uitgaven zijn hoger dan inkomsten.", ja: "純フロー: \(net.smartCurrencyString(code: currencyCode))。支出が収入を上回っています。", ko: "순흐름: \(net.smartCurrencyString(code: currencyCode)). 지출이 수입을 초과합니다."),
                systemImage: positive ? "chart.bar.fill" : "chart.bar"
            ))
        }

        // Fallback — no data at all
        if pool.isEmpty {
            return [InsightCardModel(
                title: loc(en: "No Data Yet", es: "Aún sin datos", pt: "Ainda sem dados", fr: "Pas encore de données", ar: "لا توجد بيانات بعد", de: "Noch keine Daten", it: "Nessun dato ancora", nl: "Nog geen gegevens", ja: "まだデータがありません", ko: "아직 데이터가 없습니다"),
                message: loc(en: "Log income and expenses to see real insights here.", es: "Registra ingresos y gastos para ver análisis reales aquí.", pt: "Registre receitas e despesas para ver análises reais aqui.", fr: "Enregistrez revenus et dépenses pour voir de vraies analyses ici.", ar: "سجل الدخل والمصروفات لرؤية تحليلات حقيقية هنا.", de: "Erfasse Einnahmen und Ausgaben, um hier echte Einblicke zu sehen.", it: "Registra entrate e spese per vedere qui analisi reali.", nl: "Registreer inkomsten en uitgaven om hier echte inzichten te zien.", ja: "収入と支出を記録すると、ここに実際の分析が表示されます。", ko: "수입과 지출을 기록하면 여기에서 실제 인사이트를 볼 수 있습니다."),
                systemImage: "chart.bar.xaxis"
            )]
        }

        // Rotate pool daily so insights change each day
        let dayIndex = calendar.ordinality(of: .day, in: .year, for: now) ?? 1
        let offset = (dayIndex - 1) % pool.count
        var rotated = [InsightCardModel]()
        for i in offset..<pool.count { rotated.append(pool[i]) }
        for i in 0..<offset { rotated.append(pool[i]) }
        return rotated.count > 3 ? [InsightCardModel](rotated[..<3]) : rotated
    }
    // swiftlint:enable function_body_length

    private func recentTransactions(period: DashboardPeriod) -> [AccountingTransaction] {
        let calendar = Calendar.current
        let now = Date.now
        let startDate: Date

        switch period {
        case .daily:
            startDate = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        case .weekly:
            startDate = calendar.date(byAdding: .weekOfYear, value: -8, to: now) ?? now
        case .monthly:
            startDate = calendar.date(byAdding: .month, value: -6, to: now) ?? now
        }

        return filter { $0.date >= startDate && $0.date <= now }
    }

    private func previousTransactions(period: DashboardPeriod) -> [AccountingTransaction] {
        let calendar = Calendar.current
        let now = Date.now
        let recentStart: Date
        let previousStart: Date

        switch period {
        case .daily:
            recentStart = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            previousStart = calendar.date(byAdding: .day, value: -14, to: now) ?? now
        case .weekly:
            recentStart = calendar.date(byAdding: .weekOfYear, value: -8, to: now) ?? now
            previousStart = calendar.date(byAdding: .weekOfYear, value: -16, to: now) ?? now
        case .monthly:
            recentStart = calendar.date(byAdding: .month, value: -6, to: now) ?? now
            previousStart = calendar.date(byAdding: .month, value: -12, to: now) ?? now
        }

        return filter { $0.date >= previousStart && $0.date < recentStart }
    }
}

// MARK: - International Country Registry

/// Overall compliance burden for operating a business in a country.
enum BXComplianceLevel: String, Codable, Hashable {
    case low      = "Low"
    case medium   = "Medium"
    case high     = "High"
    case veryHigh = "Very High"
}

/// Primary calendar system used in a country.
enum BXCalendarType: String, Codable, Hashable {
    case gregorian    // Standard worldwide
    case islamicCivil // Middle East (alongside Gregorian)
    case japanese     // Japan era system (Reiwa, etc.)
}

/// Canonical metadata for every country supported by Balance X.
struct BXCountryInfo {
    // ── Core ──────────────────────────────────────────────────────
    let name: String             // Display name (English)
    let code: String             // ISO 3166-1 alpha-2
    let defaultCurrency: String  // ISO 4217 default currency

    // ── Tax schedule ──────────────────────────────────────────────
    let taxFilingMonths: [Int]    // Months taxes are typically due (1=Jan)
    let taxDayOfMonth: Int        // Day of month tax payment is due
    let taxFrequencyLabel: String // "Monthly" | "Quarterly" | "Annual"
    let businessTaxRate: Decimal  // Approx corporate / business tax rate
    let personalTaxRate: Decimal  // Approx personal income tax rate (effective)
    let taxName: String           // Income/profit tax acronym (ISR, Income Tax, IRPF…)
    let salesTaxName: String      // Consumption/sales tax name (IVA, VAT, GST…)
    let salesTaxRate: Decimal     // Standard sales/VAT rate
    let taxIdName: String         // Business tax ID name (RFC, NIT, CNPJ, EIN…)

    // ── E-Invoicing ───────────────────────────────────────────────
    let eInvoicingMandatory: Bool
    let eInvoicingSystem: String? // CFDI, NF-e, FATOORA, DTE, FEL…

    // ── Localization ──────────────────────────────────────────────
    let languages: [String]      // Spoken language codes (en, es, pt, ar…)
    let defaultLanguage: String  // Recommended default app language
    let rtlRequired: Bool        // Right-to-left UI layout required
    let numberLocale: String     // Locale ID for number formatting (es_MX, pt_BR…)
    let calendarType: BXCalendarType

    // ── Compliance ────────────────────────────────────────────────
    let complianceComplexity: BXComplianceLevel
}

let BXSupportedCountries: [BXCountryInfo] = [

    // ── North America ──────────────────────────────────────────────────────────
    BXCountryInfo(
        name: "United States", code: "US", defaultCurrency: "USD",
        taxFilingMonths: [4,6,9,1], taxDayOfMonth: 15, taxFrequencyLabel: "Quarterly",
        businessTaxRate: 0.21, personalTaxRate: 0.22,
        taxName: "Income Tax", salesTaxName: "Sales Tax", salesTaxRate: 0.08,
        taxIdName: "EIN", eInvoicingMandatory: false, eInvoicingSystem: nil,
        languages: ["en"], defaultLanguage: "English", rtlRequired: false,
        numberLocale: "en_US", calendarType: .gregorian, complianceComplexity: .medium
    ),
    BXCountryInfo(
        name: "Canada", code: "CA", defaultCurrency: "CAD",
        taxFilingMonths: [4], taxDayOfMonth: 30, taxFrequencyLabel: "Annual",
        businessTaxRate: 0.265, personalTaxRate: 0.20,
        taxName: "Income Tax", salesTaxName: "GST/HST", salesTaxRate: 0.05,
        taxIdName: "BN", eInvoicingMandatory: false, eInvoicingSystem: nil,
        languages: ["en", "fr"], defaultLanguage: "English", rtlRequired: false,
        numberLocale: "en_CA", calendarType: .gregorian, complianceComplexity: .medium
    ),
    BXCountryInfo(
        name: "Mexico", code: "MX", defaultCurrency: "MXN",
        taxFilingMonths: [1,2,3,4,5,6,7,8,9,10,11,12], taxDayOfMonth: 17, taxFrequencyLabel: "Monthly",
        businessTaxRate: 0.30, personalTaxRate: 0.25,
        taxName: "ISR", salesTaxName: "IVA", salesTaxRate: 0.16,
        taxIdName: "RFC", eInvoicingMandatory: true, eInvoicingSystem: "CFDI",
        languages: ["es"], defaultLanguage: "Espanol", rtlRequired: false,
        numberLocale: "es_MX", calendarType: .gregorian, complianceComplexity: .high
    ),

    // ── Central America ────────────────────────────────────────────────────────
    BXCountryInfo(
        name: "Honduras", code: "HN", defaultCurrency: "HNL",
        taxFilingMonths: [1,2,3,4,5,6,7,8,9,10,11,12], taxDayOfMonth: 10, taxFrequencyLabel: "Monthly",
        businessTaxRate: 0.25, personalTaxRate: 0.20,
        taxName: "ISR", salesTaxName: "ISV", salesTaxRate: 0.15,
        taxIdName: "RTN", eInvoicingMandatory: false, eInvoicingSystem: "FEL",
        languages: ["es"], defaultLanguage: "Espanol", rtlRequired: false,
        numberLocale: "es_HN", calendarType: .gregorian, complianceComplexity: .medium
    ),
    BXCountryInfo(
        name: "Guatemala", code: "GT", defaultCurrency: "GTQ",
        taxFilingMonths: [1,2,3,4,5,6,7,8,9,10,11,12], taxDayOfMonth: 10, taxFrequencyLabel: "Monthly",
        businessTaxRate: 0.25, personalTaxRate: 0.15,
        taxName: "ISR", salesTaxName: "IVA", salesTaxRate: 0.12,
        taxIdName: "NIT", eInvoicingMandatory: true, eInvoicingSystem: "FEL",
        languages: ["es"], defaultLanguage: "Espanol", rtlRequired: false,
        numberLocale: "es_GT", calendarType: .gregorian, complianceComplexity: .medium
    ),
    BXCountryInfo(
        name: "El Salvador", code: "SV", defaultCurrency: "USD",
        taxFilingMonths: [4], taxDayOfMonth: 30, taxFrequencyLabel: "Annual",
        businessTaxRate: 0.25, personalTaxRate: 0.20,
        taxName: "ISR", salesTaxName: "IVA", salesTaxRate: 0.13,
        taxIdName: "NIT", eInvoicingMandatory: true, eInvoicingSystem: "DTE",
        languages: ["es"], defaultLanguage: "Espanol", rtlRequired: false,
        numberLocale: "es_SV", calendarType: .gregorian, complianceComplexity: .medium
    ),
    BXCountryInfo(
        name: "Costa Rica", code: "CR", defaultCurrency: "CRC",
        taxFilingMonths: [3], taxDayOfMonth: 15, taxFrequencyLabel: "Annual",
        businessTaxRate: 0.30, personalTaxRate: 0.25,
        taxName: "ISR", salesTaxName: "IVA", salesTaxRate: 0.13,
        taxIdName: "Cédula Jurídica", eInvoicingMandatory: true, eInvoicingSystem: "FE",
        languages: ["es"], defaultLanguage: "Espanol", rtlRequired: false,
        numberLocale: "es_CR", calendarType: .gregorian, complianceComplexity: .medium
    ),
    BXCountryInfo(
        name: "Panama", code: "PA", defaultCurrency: "USD",
        taxFilingMonths: [3], taxDayOfMonth: 15, taxFrequencyLabel: "Annual",
        businessTaxRate: 0.25, personalTaxRate: 0.20,
        taxName: "ISR", salesTaxName: "ITBMS", salesTaxRate: 0.07,
        taxIdName: "RUC", eInvoicingMandatory: false, eInvoicingSystem: "FE",
        languages: ["es"], defaultLanguage: "Espanol", rtlRequired: false,
        numberLocale: "es_PA", calendarType: .gregorian, complianceComplexity: .low
    ),
    BXCountryInfo(
        name: "Nicaragua", code: "NI", defaultCurrency: "NIO",
        taxFilingMonths: [1,2,3,4,5,6,7,8,9,10,11,12], taxDayOfMonth: 15, taxFrequencyLabel: "Monthly",
        businessTaxRate: 0.30, personalTaxRate: 0.25,
        taxName: "IR", salesTaxName: "IVA", salesTaxRate: 0.15,
        taxIdName: "RUC", eInvoicingMandatory: false, eInvoicingSystem: nil,
        languages: ["es"], defaultLanguage: "Espanol", rtlRequired: false,
        numberLocale: "es_NI", calendarType: .gregorian, complianceComplexity: .low
    ),

    // ── South America ──────────────────────────────────────────────────────────
    BXCountryInfo(
        name: "Colombia", code: "CO", defaultCurrency: "COP",
        taxFilingMonths: [4], taxDayOfMonth: 30, taxFrequencyLabel: "Annual",
        businessTaxRate: 0.35, personalTaxRate: 0.33,
        taxName: "Impuesto Renta", salesTaxName: "IVA", salesTaxRate: 0.19,
        taxIdName: "NIT", eInvoicingMandatory: true, eInvoicingSystem: "DIAN",
        languages: ["es"], defaultLanguage: "Espanol", rtlRequired: false,
        numberLocale: "es_CO", calendarType: .gregorian, complianceComplexity: .high
    ),
    BXCountryInfo(
        name: "Argentina", code: "AR", defaultCurrency: "ARS",
        taxFilingMonths: [6], taxDayOfMonth: 30, taxFrequencyLabel: "Annual",
        businessTaxRate: 0.35, personalTaxRate: 0.27,
        taxName: "Ganancias", salesTaxName: "IVA", salesTaxRate: 0.21,
        taxIdName: "CUIT", eInvoicingMandatory: true, eInvoicingSystem: "AFIP",
        languages: ["es"], defaultLanguage: "Espanol", rtlRequired: false,
        numberLocale: "es_AR", calendarType: .gregorian, complianceComplexity: .veryHigh
    ),
    BXCountryInfo(
        name: "Chile", code: "CL", defaultCurrency: "CLP",
        taxFilingMonths: [4], taxDayOfMonth: 30, taxFrequencyLabel: "Annual",
        businessTaxRate: 0.27, personalTaxRate: 0.25,
        taxName: "Impuesto Renta", salesTaxName: "IVA", salesTaxRate: 0.19,
        taxIdName: "RUT", eInvoicingMandatory: true, eInvoicingSystem: "DTE",
        languages: ["es"], defaultLanguage: "Espanol", rtlRequired: false,
        numberLocale: "es_CL", calendarType: .gregorian, complianceComplexity: .high
    ),
    BXCountryInfo(
        name: "Peru", code: "PE", defaultCurrency: "PEN",
        taxFilingMonths: [3,4], taxDayOfMonth: 31, taxFrequencyLabel: "Annual",
        businessTaxRate: 0.295, personalTaxRate: 0.28,
        taxName: "Impuesto Renta", salesTaxName: "IGV", salesTaxRate: 0.18,
        taxIdName: "RUC", eInvoicingMandatory: true, eInvoicingSystem: "CPE",
        languages: ["es"], defaultLanguage: "Espanol", rtlRequired: false,
        numberLocale: "es_PE", calendarType: .gregorian, complianceComplexity: .high
    ),
    BXCountryInfo(
        name: "Venezuela", code: "VE", defaultCurrency: "VED",
        taxFilingMonths: [3], taxDayOfMonth: 31, taxFrequencyLabel: "Annual",
        businessTaxRate: 0.34, personalTaxRate: 0.34,
        taxName: "ISLR", salesTaxName: "IVA", salesTaxRate: 0.16,
        taxIdName: "RIF", eInvoicingMandatory: false, eInvoicingSystem: nil,
        languages: ["es"], defaultLanguage: "Espanol", rtlRequired: false,
        numberLocale: "es_VE", calendarType: .gregorian, complianceComplexity: .veryHigh
    ),
    BXCountryInfo(
        name: "Ecuador", code: "EC", defaultCurrency: "USD",
        taxFilingMonths: [4,5], taxDayOfMonth: 28, taxFrequencyLabel: "Annual",
        businessTaxRate: 0.25, personalTaxRate: 0.25,
        taxName: "IR", salesTaxName: "IVA", salesTaxRate: 0.15,
        taxIdName: "RUC", eInvoicingMandatory: true, eInvoicingSystem: "SRI",
        languages: ["es"], defaultLanguage: "Espanol", rtlRequired: false,
        numberLocale: "es_EC", calendarType: .gregorian, complianceComplexity: .high
    ),
    BXCountryInfo(
        name: "Bolivia", code: "BO", defaultCurrency: "BOB",
        taxFilingMonths: [6], taxDayOfMonth: 29, taxFrequencyLabel: "Annual",
        businessTaxRate: 0.25, personalTaxRate: 0.25,
        taxName: "IUE", salesTaxName: "IVA", salesTaxRate: 0.13,
        taxIdName: "NIT", eInvoicingMandatory: false, eInvoicingSystem: "SIAT",
        languages: ["es"], defaultLanguage: "Espanol", rtlRequired: false,
        numberLocale: "es_BO", calendarType: .gregorian, complianceComplexity: .medium
    ),
    BXCountryInfo(
        name: "Paraguay", code: "PY", defaultCurrency: "PYG",
        taxFilingMonths: [4], taxDayOfMonth: 30, taxFrequencyLabel: "Annual",
        businessTaxRate: 0.10, personalTaxRate: 0.10,
        taxName: "IRACIS", salesTaxName: "IVA", salesTaxRate: 0.10,
        taxIdName: "RUC", eInvoicingMandatory: false, eInvoicingSystem: nil,
        languages: ["es"], defaultLanguage: "Espanol", rtlRequired: false,
        numberLocale: "es_PY", calendarType: .gregorian, complianceComplexity: .low
    ),
    BXCountryInfo(
        name: "Uruguay", code: "UY", defaultCurrency: "UYU",
        taxFilingMonths: [4], taxDayOfMonth: 30, taxFrequencyLabel: "Annual",
        businessTaxRate: 0.25, personalTaxRate: 0.25,
        taxName: "IRAE", salesTaxName: "IVA", salesTaxRate: 0.22,
        taxIdName: "RUT", eInvoicingMandatory: true, eInvoicingSystem: "e-Factura",
        languages: ["es"], defaultLanguage: "Espanol", rtlRequired: false,
        numberLocale: "es_UY", calendarType: .gregorian, complianceComplexity: .medium
    ),
    BXCountryInfo(
        name: "Brazil", code: "BR", defaultCurrency: "BRL",
        taxFilingMonths: [3,4,5,6,7,8,9,10,11,12,1,2], taxDayOfMonth: 20, taxFrequencyLabel: "Monthly",
        businessTaxRate: 0.34, personalTaxRate: 0.275,
        taxName: "IRPJ", salesTaxName: "ICMS/ISS", salesTaxRate: 0.18,
        taxIdName: "CNPJ", eInvoicingMandatory: true, eInvoicingSystem: "NF-e",
        languages: ["pt"], defaultLanguage: "Portugues", rtlRequired: false,
        numberLocale: "pt_BR", calendarType: .gregorian, complianceComplexity: .veryHigh
    ),

    // ── Caribbean ──────────────────────────────────────────────────────────────
    BXCountryInfo(
        name: "Dominican Republic", code: "DO", defaultCurrency: "DOP",
        taxFilingMonths: [4], taxDayOfMonth: 30, taxFrequencyLabel: "Annual",
        businessTaxRate: 0.27, personalTaxRate: 0.25,
        taxName: "ISR", salesTaxName: "ITBIS", salesTaxRate: 0.18,
        taxIdName: "RNC", eInvoicingMandatory: false, eInvoicingSystem: "e-CF",
        languages: ["es"], defaultLanguage: "Espanol", rtlRequired: false,
        numberLocale: "es_DO", calendarType: .gregorian, complianceComplexity: .medium
    ),
    BXCountryInfo(
        name: "Puerto Rico", code: "PR", defaultCurrency: "USD",
        taxFilingMonths: [4], taxDayOfMonth: 15, taxFrequencyLabel: "Annual",
        businessTaxRate: 0.185, personalTaxRate: 0.22,
        taxName: "Income Tax", salesTaxName: "IVU", salesTaxRate: 0.115,
        taxIdName: "EIN", eInvoicingMandatory: false, eInvoicingSystem: nil,
        languages: ["es", "en"], defaultLanguage: "Espanol", rtlRequired: false,
        numberLocale: "es_PR", calendarType: .gregorian, complianceComplexity: .medium
    ),
    BXCountryInfo(
        name: "Cuba", code: "CU", defaultCurrency: "CUP",
        taxFilingMonths: [4], taxDayOfMonth: 30, taxFrequencyLabel: "Annual",
        businessTaxRate: 0.35, personalTaxRate: 0.50,
        taxName: "Impuesto Renta", salesTaxName: "—", salesTaxRate: 0.00,
        taxIdName: "NIT", eInvoicingMandatory: false, eInvoicingSystem: nil,
        languages: ["es"], defaultLanguage: "Espanol", rtlRequired: false,
        numberLocale: "es_CU", calendarType: .gregorian, complianceComplexity: .veryHigh
    ),

    // ── Europe ─────────────────────────────────────────────────────────────────
    BXCountryInfo(
        name: "Spain", code: "ES", defaultCurrency: "EUR",
        taxFilingMonths: [4,5,6], taxDayOfMonth: 30, taxFrequencyLabel: "Quarterly",
        businessTaxRate: 0.25, personalTaxRate: 0.24,
        taxName: "IRPF/IS", salesTaxName: "IVA", salesTaxRate: 0.21,
        taxIdName: "CIF/NIF", eInvoicingMandatory: true, eInvoicingSystem: "VeriFactu",
        languages: ["es"], defaultLanguage: "Espanol", rtlRequired: false,
        numberLocale: "es_ES", calendarType: .gregorian, complianceComplexity: .high
    ),
    BXCountryInfo(
        name: "Germany", code: "DE", defaultCurrency: "EUR",
        taxFilingMonths: [4], taxDayOfMonth: 30, taxFrequencyLabel: "Annual",
        businessTaxRate: 0.30, personalTaxRate: 0.42,
        taxName: "Einkommensteuer", salesTaxName: "MwSt", salesTaxRate: 0.19,
        taxIdName: "Steuernummer", eInvoicingMandatory: true, eInvoicingSystem: "XRechnung",
        languages: ["de"], defaultLanguage: "Deutsch", rtlRequired: false,
        numberLocale: "de_DE", calendarType: .gregorian, complianceComplexity: .veryHigh
    ),
    BXCountryInfo(
        name: "France", code: "FR", defaultCurrency: "EUR",
        taxFilingMonths: [5,6], taxDayOfMonth: 31, taxFrequencyLabel: "Annual",
        businessTaxRate: 0.25, personalTaxRate: 0.30,
        taxName: "Impôt sur revenu", salesTaxName: "TVA", salesTaxRate: 0.20,
        taxIdName: "SIRET", eInvoicingMandatory: true, eInvoicingSystem: "Factur-X",
        languages: ["fr"], defaultLanguage: "Francais", rtlRequired: false,
        numberLocale: "fr_FR", calendarType: .gregorian, complianceComplexity: .high
    ),
    BXCountryInfo(
        name: "United Kingdom", code: "GB", defaultCurrency: "GBP",
        taxFilingMonths: [1], taxDayOfMonth: 31, taxFrequencyLabel: "Annual",
        businessTaxRate: 0.25, personalTaxRate: 0.20,
        taxName: "Income Tax", salesTaxName: "VAT", salesTaxRate: 0.20,
        taxIdName: "UTR", eInvoicingMandatory: true, eInvoicingSystem: "MTD",
        languages: ["en"], defaultLanguage: "English", rtlRequired: false,
        numberLocale: "en_GB", calendarType: .gregorian, complianceComplexity: .high
    ),
    BXCountryInfo(
        name: "Italy", code: "IT", defaultCurrency: "EUR",
        taxFilingMonths: [6,7], taxDayOfMonth: 30, taxFrequencyLabel: "Annual",
        businessTaxRate: 0.245, personalTaxRate: 0.23,
        taxName: "IRPEF/IRES", salesTaxName: "IVA", salesTaxRate: 0.22,
        taxIdName: "Partita IVA", eInvoicingMandatory: true, eInvoicingSystem: "FatturaPA",
        languages: ["it"], defaultLanguage: "Italiano", rtlRequired: false,
        numberLocale: "it_IT", calendarType: .gregorian, complianceComplexity: .veryHigh
    ),
    BXCountryInfo(
        name: "Portugal", code: "PT", defaultCurrency: "EUR",
        taxFilingMonths: [4,5,6], taxDayOfMonth: 30, taxFrequencyLabel: "Annual",
        businessTaxRate: 0.21, personalTaxRate: 0.24,
        taxName: "IRS/IRC", salesTaxName: "IVA", salesTaxRate: 0.23,
        taxIdName: "NIF/NIPC", eInvoicingMandatory: true, eInvoicingSystem: "SAFT-PT",
        languages: ["pt"], defaultLanguage: "Portugues", rtlRequired: false,
        numberLocale: "pt_PT", calendarType: .gregorian, complianceComplexity: .high
    ),
    BXCountryInfo(
        name: "Netherlands", code: "NL", defaultCurrency: "EUR",
        taxFilingMonths: [4], taxDayOfMonth: 30, taxFrequencyLabel: "Annual",
        businessTaxRate: 0.258, personalTaxRate: 0.37,
        taxName: "Inkomstenbelasting", salesTaxName: "BTW", salesTaxRate: 0.21,
        taxIdName: "KvK-nummer", eInvoicingMandatory: true, eInvoicingSystem: "Peppol",
        languages: ["nl"], defaultLanguage: "Nederlands", rtlRequired: false,
        numberLocale: "nl_NL", calendarType: .gregorian, complianceComplexity: .high
    ),

    // ── Middle East ────────────────────────────────────────────────────────────
    BXCountryInfo(
        name: "United Arab Emirates", code: "AE", defaultCurrency: "AED",
        taxFilingMonths: [6], taxDayOfMonth: 30, taxFrequencyLabel: "Annual",
        businessTaxRate: 0.09, personalTaxRate: 0.00,
        taxName: "Corporate Tax", salesTaxName: "VAT", salesTaxRate: 0.05,
        taxIdName: "TRN", eInvoicingMandatory: false, eInvoicingSystem: nil,
        languages: ["ar", "en"], defaultLanguage: "Arabic", rtlRequired: true,
        numberLocale: "ar_AE", calendarType: .islamicCivil, complianceComplexity: .medium
    ),
    BXCountryInfo(
        name: "Saudi Arabia", code: "SA", defaultCurrency: "SAR",
        taxFilingMonths: [3,6,9,12], taxDayOfMonth: 30, taxFrequencyLabel: "Quarterly",
        businessTaxRate: 0.20, personalTaxRate: 0.00,
        taxName: "Income Tax", salesTaxName: "VAT", salesTaxRate: 0.15,
        taxIdName: "CR Number", eInvoicingMandatory: true, eInvoicingSystem: "FATOORA",
        languages: ["ar"], defaultLanguage: "Arabic", rtlRequired: true,
        numberLocale: "ar_SA", calendarType: .islamicCivil, complianceComplexity: .high
    ),
    BXCountryInfo(
        name: "Qatar", code: "QA", defaultCurrency: "QAR",
        taxFilingMonths: [4], taxDayOfMonth: 30, taxFrequencyLabel: "Annual",
        businessTaxRate: 0.10, personalTaxRate: 0.00,
        taxName: "Income Tax", salesTaxName: "—", salesTaxRate: 0.00,
        taxIdName: "CR Number", eInvoicingMandatory: false, eInvoicingSystem: nil,
        languages: ["ar", "en"], defaultLanguage: "Arabic", rtlRequired: true,
        numberLocale: "ar_QA", calendarType: .gregorian, complianceComplexity: .low
    ),
    BXCountryInfo(
        name: "Kuwait", code: "KW", defaultCurrency: "KWD",
        taxFilingMonths: [4], taxDayOfMonth: 30, taxFrequencyLabel: "Annual",
        businessTaxRate: 0.15, personalTaxRate: 0.00,
        taxName: "Income Tax", salesTaxName: "—", salesTaxRate: 0.00,
        taxIdName: "Commercial License", eInvoicingMandatory: false, eInvoicingSystem: nil,
        languages: ["ar", "en"], defaultLanguage: "Arabic", rtlRequired: true,
        numberLocale: "ar_KW", calendarType: .gregorian, complianceComplexity: .low
    ),

    // ── Asia-Pacific ───────────────────────────────────────────────────────────
    BXCountryInfo(
        name: "Australia", code: "AU", defaultCurrency: "AUD",
        taxFilingMonths: [10], taxDayOfMonth: 31, taxFrequencyLabel: "Annual",
        businessTaxRate: 0.30, personalTaxRate: 0.32,
        taxName: "Income Tax", salesTaxName: "GST", salesTaxRate: 0.10,
        taxIdName: "ABN", eInvoicingMandatory: false, eInvoicingSystem: "Peppol",
        languages: ["en"], defaultLanguage: "English", rtlRequired: false,
        numberLocale: "en_AU", calendarType: .gregorian, complianceComplexity: .medium
    ),
    BXCountryInfo(
        name: "Japan", code: "JP", defaultCurrency: "JPY",
        taxFilingMonths: [3], taxDayOfMonth: 15, taxFrequencyLabel: "Annual",
        businessTaxRate: 0.235, personalTaxRate: 0.20,
        taxName: "Shotoku-zei", salesTaxName: "Shohi-zei", salesTaxRate: 0.10,
        taxIdName: "Corporate Number", eInvoicingMandatory: true, eInvoicingSystem: "Invoice System",
        languages: ["ja"], defaultLanguage: "Japanese", rtlRequired: false,
        numberLocale: "ja_JP", calendarType: .japanese, complianceComplexity: .high
    ),
    BXCountryInfo(
        name: "South Korea", code: "KR", defaultCurrency: "KRW",
        taxFilingMonths: [3,4], taxDayOfMonth: 31, taxFrequencyLabel: "Annual",
        businessTaxRate: 0.24, personalTaxRate: 0.24,
        taxName: "Corporate Tax", salesTaxName: "VAT", salesTaxRate: 0.10,
        taxIdName: "BRN", eInvoicingMandatory: true, eInvoicingSystem: "e-Tax Invoice",
        languages: ["ko"], defaultLanguage: "Korean", rtlRequired: false,
        numberLocale: "ko_KR", calendarType: .gregorian, complianceComplexity: .high
    ),
    BXCountryInfo(
        name: "Singapore", code: "SG", defaultCurrency: "SGD",
        taxFilingMonths: [11], taxDayOfMonth: 30, taxFrequencyLabel: "Annual",
        businessTaxRate: 0.17, personalTaxRate: 0.22,
        taxName: "Corporate Tax", salesTaxName: "GST", salesTaxRate: 0.09,
        taxIdName: "UEN", eInvoicingMandatory: false, eInvoicingSystem: "InvoiceNow",
        languages: ["en"], defaultLanguage: "English", rtlRequired: false,
        numberLocale: "en_SG", calendarType: .gregorian, complianceComplexity: .low
    ),

    // ── Fallback ───────────────────────────────────────────────────────────────
    BXCountryInfo(
        name: "Other", code: "XX", defaultCurrency: "USD",
        taxFilingMonths: [4], taxDayOfMonth: 15, taxFrequencyLabel: "Annual",
        businessTaxRate: 0.20, personalTaxRate: 0.15,
        taxName: "Income Tax", salesTaxName: "Sales Tax", salesTaxRate: 0.10,
        taxIdName: "Tax ID", eInvoicingMandatory: false, eInvoicingSystem: nil,
        languages: ["en"], defaultLanguage: "English", rtlRequired: false,
        numberLocale: "en_US", calendarType: .gregorian, complianceComplexity: .low
    ),
]

/// Supported world currencies with names in all supported app languages.
struct BXCurrencyInfo {
    let code: String
    let symbol: String
    let name: String      // English
    let nameEs: String    // Spanish
    let namePt: String    // Portuguese
    let nameFr: String    // French
    let nameAr: String    // Arabic
    let nameDe: String    // German
    let nameIt: String    // Italian
    let nameNl: String    // Dutch
    let nameJa: String    // Japanese
    let nameKo: String    // Korean
}

let BXSupportedCurrencies: [BXCurrencyInfo] = [
    // ── Americas ───────────────────────────────────────────────────────────────
    BXCurrencyInfo(code: "USD", symbol: "$",    name: "US Dollar",          nameEs: "Dólar estadounidense",  namePt: "Dólar americano",     nameFr: "Dollar américain",      nameAr: "دولار أمريكي",    nameDe: "US-Dollar",          nameIt: "Dollaro americano",   nameNl: "Amerikaanse dollar", nameJa: "米ドル",      nameKo: "미국 달러"),
    BXCurrencyInfo(code: "CAD", symbol: "CA$",  name: "Canadian Dollar",    nameEs: "Dólar canadiense",      namePt: "Dólar canadense",     nameFr: "Dollar canadien",       nameAr: "دولار كندي",      nameDe: "Kanadischer Dollar", nameIt: "Dollaro canadese",    nameNl: "Canadese dollar",    nameJa: "カナダドル", nameKo: "캐나다 달러"),
    BXCurrencyInfo(code: "MXN", symbol: "MX$",  name: "Mexican Peso",       nameEs: "Peso mexicano",         namePt: "Peso mexicano",       nameFr: "Peso mexicain",         nameAr: "بيزو مكسيكي",     nameDe: "Mexikanischer Peso", nameIt: "Peso messicano",      nameNl: "Mexicaanse peso",    nameJa: "メキシコペソ", nameKo: "멕시코 페소"),
    BXCurrencyInfo(code: "HNL", symbol: "L",    name: "Honduran Lempira",   nameEs: "Lempira hondureño",     namePt: "Lempira hondurenho",  nameFr: "Lempira hondurien",     nameAr: "ليمبيرا هندوراسي", nameDe: "Honduranischer Lempira", nameIt: "Lempira honduregno", nameNl: "Hondurese lempira",  nameJa: "ホンジュラスレンピラ", nameKo: "온두라스 렘피라"),
    BXCurrencyInfo(code: "GTQ", symbol: "Q",    name: "Guatemalan Quetzal", nameEs: "Quetzal guatemalteco",  namePt: "Quetzal guatemalteco",nameFr: "Quetzal guatémaltèque", nameAr: "كيتسال غواتيمالي", nameDe: "Guatemaltekischer Quetzal", nameIt: "Quetzal guatemalteco", nameNl: "Guatemalteekse quetzal", nameJa: "グアテマラケツァル", nameKo: "과테말라 케찰"),
    BXCurrencyInfo(code: "CRC", symbol: "₡",    name: "Costa Rican Colón",  nameEs: "Colón costarricense",   namePt: "Colón costa-riquenho",nameFr: "Colón costaricain",     nameAr: "كولون كوستاريكي",  nameDe: "Costa-ricanischer Colón", nameIt: "Colón costaricano", nameNl: "Costa Ricaanse colón", nameJa: "コスタリカコロン", nameKo: "코스타리카 콜론"),
    BXCurrencyInfo(code: "COP", symbol: "COL$", name: "Colombian Peso",     nameEs: "Peso colombiano",       namePt: "Peso colombiano",     nameFr: "Peso colombien",        nameAr: "بيزو كولومبي",    nameDe: "Kolumbianischer Peso", nameIt: "Peso colombiano",   nameNl: "Colombiaanse peso",  nameJa: "コロンビアペソ", nameKo: "콜롬비아 페소"),
    BXCurrencyInfo(code: "ARS", symbol: "AR$",  name: "Argentine Peso",     nameEs: "Peso argentino",        namePt: "Peso argentino",      nameFr: "Peso argentin",         nameAr: "بيزو أرجنتيني",   nameDe: "Argentinischer Peso",  nameIt: "Peso argentino",    nameNl: "Argentijnse peso",   nameJa: "アルゼンチンペソ", nameKo: "아르헨티나 페소"),
    BXCurrencyInfo(code: "CLP", symbol: "CL$",  name: "Chilean Peso",       nameEs: "Peso chileno",          namePt: "Peso chileno",        nameFr: "Peso chilien",          nameAr: "بيزو شيلي",       nameDe: "Chilenischer Peso",    nameIt: "Peso cileno",       nameNl: "Chileense peso",     nameJa: "チリペソ", nameKo: "칠레 페소"),
    BXCurrencyInfo(code: "PEN", symbol: "S/",   name: "Peruvian Sol",       nameEs: "Sol peruano",           namePt: "Sol peruano",         nameFr: "Sol péruvien",          nameAr: "سول بيروفي",      nameDe: "Peruanischer Sol",     nameIt: "Sol peruviano",     nameNl: "Peruaanse sol",      nameJa: "ペルーソル", nameKo: "페루 솔"),
    BXCurrencyInfo(code: "VED", symbol: "Bs.",  name: "Venezuelan Bolívar", nameEs: "Bolívar venezolano",    namePt: "Bolívar venezuelano", nameFr: "Bolívar vénézuélien",   nameAr: "بوليفار فنزويلي", nameDe: "Venezolanischer Bolívar", nameIt: "Bolívar venezuelano", nameNl: "Venezolaanse bolivar", nameJa: "ベネズエラボリバル", nameKo: "베네수엘라 볼리바르"),
    BXCurrencyInfo(code: "BOB", symbol: "Bs.",  name: "Bolivian Boliviano", nameEs: "Boliviano",             namePt: "Boliviano",           nameFr: "Boliviano",             nameAr: "بوليفيانو بوليفي", nameDe: "Bolivianischer Boliviano", nameIt: "Boliviano boliviano", nameNl: "Boliviaanse boliviano", nameJa: "ボリビアボリビアーノ", nameKo: "볼리비아 볼리비아노"),
    BXCurrencyInfo(code: "PYG", symbol: "₲",    name: "Paraguayan Guaraní", nameEs: "Guaraní paraguayo",     namePt: "Guarani paraguaio",   nameFr: "Guaraní paraguayen",    nameAr: "غواراني باراغوي", nameDe: "Paraguayischer Guaraní", nameIt: "Guaraní paraguaiano", nameNl: "Paraguayaanse guaraní", nameJa: "パラグアイグアラニー", nameKo: "파라과이 과라니"),
    BXCurrencyInfo(code: "UYU", symbol: "UY$",  name: "Uruguayan Peso",     nameEs: "Peso uruguayo",         namePt: "Peso uruguaio",       nameFr: "Peso uruguayen",        nameAr: "بيزو أوروغواي",   nameDe: "Uruguayischer Peso",   nameIt: "Peso uruguaiano",   nameNl: "Uruguayaanse peso",  nameJa: "ウルグアイペソ", nameKo: "우루과이 페소"),
    BXCurrencyInfo(code: "BRL", symbol: "R$",   name: "Brazilian Real",     nameEs: "Real brasileño",        namePt: "Real brasileiro",     nameFr: "Real brésilien",        nameAr: "ريال برازيلي",    nameDe: "Brasilianischer Real", nameIt: "Real brasiliano",   nameNl: "Braziliaanse real",  nameJa: "ブラジルレアル", nameKo: "브라질 헤알"),
    BXCurrencyInfo(code: "DOP", symbol: "RD$",  name: "Dominican Peso",     nameEs: "Peso dominicano",       namePt: "Peso dominicano",     nameFr: "Peso dominicain",       nameAr: "بيزو دومينيكي",   nameDe: "Dominikanischer Peso", nameIt: "Peso dominicano",   nameNl: "Dominicaanse peso",  nameJa: "ドミニカペソ", nameKo: "도미니카 페소"),
    BXCurrencyInfo(code: "NIO", symbol: "C$",   name: "Nicaraguan Córdoba", nameEs: "Córdoba nicaragüense",  namePt: "Córdoba nicaraguense",nameFr: "Córdoba nicaraguayen",  nameAr: "كوردوبا نيكاراغوا", nameDe: "Nicaraguanischer Córdoba", nameIt: "Córdoba nicaraguense", nameNl: "Nicaraguaanse córdoba", nameJa: "ニカラグアコルドバ", nameKo: "니카라과 코르도바"),
    BXCurrencyInfo(code: "CUP", symbol: "₱",    name: "Cuban Peso",         nameEs: "Peso cubano",           namePt: "Peso cubano",         nameFr: "Peso cubain",           nameAr: "بيزو كوبي",       nameDe: "Kubanischer Peso",     nameIt: "Peso cubano",       nameNl: "Cubaanse peso",      nameJa: "キューバペソ", nameKo: "쿠바 페소"),

    // ── Europe ─────────────────────────────────────────────────────────────────
    BXCurrencyInfo(code: "EUR", symbol: "€",    name: "Euro",               nameEs: "Euro",                  namePt: "Euro",                nameFr: "Euro",                  nameAr: "يورو",            nameDe: "Euro",                 nameIt: "Euro",              nameNl: "Euro",               nameJa: "ユーロ", nameKo: "유로"),
    BXCurrencyInfo(code: "GBP", symbol: "£",    name: "British Pound",      nameEs: "Libra esterlina",       namePt: "Libra esterlina",     nameFr: "Livre sterling",        nameAr: "جنيه إسترليني",   nameDe: "Britisches Pfund",     nameIt: "Sterlina britannica", nameNl: "Brits pond",         nameJa: "英国ポンド", nameKo: "영국 파운드"),

    // ── Middle East ────────────────────────────────────────────────────────────
    BXCurrencyInfo(code: "AED", symbol: "د.إ",  name: "UAE Dirham",         nameEs: "Dírham de EAU",         namePt: "Dírham dos EAU",      nameFr: "Dirham des EAU",        nameAr: "درهم إماراتي",    nameDe: "Dirham der VAE",       nameIt: "Dirham degli EAU",  nameNl: "VAE-dirham",         nameJa: "UAEディルハム", nameKo: "UAE 디르함"),
    BXCurrencyInfo(code: "SAR", symbol: "ر.س",  name: "Saudi Riyal",        nameEs: "Riyal saudí",           namePt: "Riyal saudita",       nameFr: "Riyal saoudien",        nameAr: "ريال سعودي",      nameDe: "Saudischer Riyal",     nameIt: "Riyal saudita",     nameNl: "Saudische riyal",    nameJa: "サウジアラビアリヤル", nameKo: "사우디 리얄"),
    BXCurrencyInfo(code: "QAR", symbol: "ر.ق",  name: "Qatari Riyal",       nameEs: "Riyal catarí",          namePt: "Riyal catariano",     nameFr: "Riyal qatari",          nameAr: "ريال قطري",       nameDe: "Katarischer Riyal",    nameIt: "Riyal del Qatar",   nameNl: "Qatarese riyal",     nameJa: "カタールリヤル", nameKo: "카타르 리얄"),
    BXCurrencyInfo(code: "KWD", symbol: "د.ك",  name: "Kuwaiti Dinar",      nameEs: "Dinar kuwaití",         namePt: "Dinar kuwaitiano",    nameFr: "Dinar koweïtien",       nameAr: "دينار كويتي",     nameDe: "Kuwaitischer Dinar",   nameIt: "Dinaro del Kuwait", nameNl: "Koeweitse dinar",    nameJa: "クウェートディナール", nameKo: "쿠웨이트 디나르"),

    // ── Asia-Pacific ───────────────────────────────────────────────────────────
    BXCurrencyInfo(code: "AUD", symbol: "A$",   name: "Australian Dollar",  nameEs: "Dólar australiano",     namePt: "Dólar australiano",   nameFr: "Dollar australien",     nameAr: "دولار أسترالي",   nameDe: "Australischer Dollar", nameIt: "Dollaro australiano",nameNl: "Australische dollar", nameJa: "オーストラリアドル", nameKo: "호주 달러"),
    BXCurrencyInfo(code: "JPY", symbol: "¥",    name: "Japanese Yen",       nameEs: "Yen japonés",           namePt: "Iene japonês",        nameFr: "Yen japonais",          nameAr: "ين ياباني",       nameDe: "Japanischer Yen",      nameIt: "Yen giapponese",    nameNl: "Japanse yen",        nameJa: "日本円", nameKo: "일본 엔"),
    BXCurrencyInfo(code: "KRW", symbol: "₩",    name: "South Korean Won",   nameEs: "Won surcoreano",        namePt: "Won sul-coreano",     nameFr: "Won sud-coréen",        nameAr: "وون كوري جنوبي",  nameDe: "Südkoreanischer Won",  nameIt: "Won sudcoreano",    nameNl: "Zuid-Koreaanse won", nameJa: "韓国ウォン", nameKo: "대한민국 원"),
    BXCurrencyInfo(code: "SGD", symbol: "S$",   name: "Singapore Dollar",   nameEs: "Dólar de Singapur",     namePt: "Dólar de Singapura",  nameFr: "Dollar de Singapour",   nameAr: "دولار سنغافوري",  nameDe: "Singapur-Dollar",      nameIt: "Dollaro di Singapore",nameNl: "Singaporese dollar",  nameJa: "シンガポールドル", nameKo: "싱가포르 달러"),
]

/// Supported languages in Balance X.
/// `code` is the internal key stored in OnboardingProfile.language.
struct BXLanguageInfo {
    let code: String        // Internal key (e.g. "English", "Espanol", "Arabic")
    let isoCode: String     // BCP 47 code (en, es, pt, fr, ar, de, it, nl, ja, ko)
    let displayName: String // English display name
    let localName: String   // Native language name
    let rtl: Bool           // Right-to-left script
    let priority: Int       // Display order (lower = higher priority)
}

let BXSupportedLanguages: [BXLanguageInfo] = [
    // P0 — Core markets
    BXLanguageInfo(code: "English",    isoCode: "en", displayName: "English",    localName: "English",    rtl: false, priority: 1),
    BXLanguageInfo(code: "Espanol",    isoCode: "es", displayName: "Spanish",    localName: "Español",    rtl: false, priority: 2),
    BXLanguageInfo(code: "Portugues",  isoCode: "pt", displayName: "Portuguese", localName: "Português",  rtl: false, priority: 3),
    BXLanguageInfo(code: "Francais",   isoCode: "fr", displayName: "French",     localName: "Français",   rtl: false, priority: 4),
    // P1 — Regional expansion
    BXLanguageInfo(code: "Arabic",     isoCode: "ar", displayName: "Arabic",     localName: "العربية",    rtl: true,  priority: 5),
    BXLanguageInfo(code: "Deutsch",    isoCode: "de", displayName: "German",     localName: "Deutsch",    rtl: false, priority: 6),
    BXLanguageInfo(code: "Italiano",   isoCode: "it", displayName: "Italian",    localName: "Italiano",   rtl: false, priority: 7),
    BXLanguageInfo(code: "Nederlands", isoCode: "nl", displayName: "Dutch",      localName: "Nederlands", rtl: false, priority: 8),
    BXLanguageInfo(code: "Japanese",   isoCode: "ja", displayName: "Japanese",   localName: "日本語",      rtl: false, priority: 9),
    // P2 — Future Asia
    BXLanguageInfo(code: "Korean",     isoCode: "ko", displayName: "Korean",     localName: "한국어",      rtl: false, priority: 10),
]

extension OnboardingProfile {
    var languageInfo: BXLanguageInfo? {
        BXSupportedLanguages.first {
            $0.code.caseInsensitiveCompare(language) == .orderedSame
                || $0.isoCode.caseInsensitiveCompare(language) == .orderedSame
                || $0.displayName.caseInsensitiveCompare(language) == .orderedSame
                || $0.localName.caseInsensitiveCompare(language) == .orderedSame
        }
    }

    // ── Language detectors ─────────────────────────────────────────────────────

    var isSpanish: Bool    { languageInfo?.isoCode == "es" }
    var isPortuguese: Bool { languageInfo?.isoCode == "pt" }
    var isFrench: Bool     { languageInfo?.isoCode == "fr" }
    var isArabic: Bool     { languageInfo?.isoCode == "ar" }
    var isGerman: Bool     { languageInfo?.isoCode == "de" }
    var isItalian: Bool    { languageInfo?.isoCode == "it" }
    var isDutch: Bool      { languageInfo?.isoCode == "nl" }
    var isJapanese: Bool   { languageInfo?.isoCode == "ja" }
    var isKorean: Bool     { languageInfo?.isoCode == "ko" }

    var isHonduras: Bool   { country == "Honduras" }

    /// True when the current language requires right-to-left layout.
    var isRTL: Bool { isArabic }

    /// BCP 47 locale identifier for the current app language + country.
    /// Use with NumberFormatter, DateFormatter, and Locale(identifier:).
    var localeIdentifier: String {
        countryInfo?.numberLocale ?? {
            if let isoCode = languageInfo?.isoCode {
                switch isoCode {
                case "es": return "es"
                case "pt": return "pt"
                case "fr": return "fr"
                case "ar": return "ar"
                case "de": return "de_DE"
                case "it": return "it_IT"
                case "nl": return "nl_NL"
                case "ja": return "ja_JP"
                case "ko": return "ko_KR"
                default: break
                }
            }
            if isSpanish    { return "es" }
            if isPortuguese { return "pt" }
            if isFrench     { return "fr" }
            if isArabic     { return "ar" }
            if isGerman     { return "de_DE" }
            if isItalian    { return "it_IT" }
            if isDutch      { return "nl_NL" }
            if isJapanese   { return "ja_JP" }
            if isKorean     { return "ko_KR" }
            return "en_US"
        }()
    }

    /// Returns the localized name of a currency from a BXCurrencyInfo record.
    func localizedCurrencyName(_ info: BXCurrencyInfo) -> String {
        if isArabic     { return info.nameAr }
        if isGerman     { return info.nameDe }
        if isItalian    { return info.nameIt }
        if isDutch      { return info.nameNl }
        if isJapanese   { return info.nameJa }
        if isKorean     { return info.nameKo }
        return text(en: info.name, es: info.nameEs, pt: info.namePt, fr: info.nameFr)
    }

    // ── Core localization function ──────────────────────────────────────────────

    /// Returns the string that matches the current app language.
    /// Falls back to English for any language not explicitly provided.
    func text(
        en: String,
        es: String,
        pt: String? = nil,
        fr: String? = nil,
        ar: String? = nil,
        de: String? = nil,
        it: String? = nil,
        nl: String? = nil,
        ja: String? = nil,
        ko: String? = nil
    ) -> String {
        if isArabic     { return ar ?? en }
        if isGerman     { return de ?? en }
        if isItalian    { return it ?? en }
        if isDutch      { return nl ?? en }
        if isJapanese   { return ja ?? en }
        if isKorean     { return ko ?? en }
        if isSpanish    { return es }
        if isPortuguese { return pt ?? en }
        if isFrench     { return fr ?? en }
        return en
    }

    /// Country info from the global registry
    var countryInfo: BXCountryInfo? {
        BXSupportedCountries.first { $0.name == country }
    }

    /// Estimated effective tax rate based on country and workspace type.
    func estimatedTaxRate(on profit: Decimal) -> Decimal {
        if let info = countryInfo {
            return workspaceType == .business ? info.businessTaxRate : info.personalTaxRate
        }
        // Fallback progressive estimate
        switch workspaceType {
        case .business: return Decimal(string: "0.21") ?? 0.21
        case .personal:
            if profit < 30_000 { return Decimal(string: "0.12") ?? 0.12 }
            if profit < 80_000 { return Decimal(string: "0.22") ?? 0.22 }
            return Decimal(string: "0.28") ?? 0.28
        }
    }

    /// Next months when a tax payment is due, based on country info
    var taxDeadlineMonths: [Int] {
        countryInfo?.taxFilingMonths ?? [4]
    }

    /// Day of month the tax payment is due
    var taxDayOfMonth: Int {
        countryInfo?.taxDayOfMonth ?? 15
    }

    /// Tax filing frequency label — localized to all 10 supported languages.
    var taxFrequencyLabel: String {
        let label = countryInfo?.taxFrequencyLabel ?? "Quarterly"
        return text(
            en: label,
            es: { switch label { case "Monthly": return "Mensual";   case "Quarterly": return "Trimestral"; case "Annual": return "Anual";      default: return label }}(),
            pt: { switch label { case "Monthly": return "Mensal";    case "Quarterly": return "Trimestral"; case "Annual": return "Anual";      default: return label }}(),
            fr: { switch label { case "Monthly": return "Mensuel";   case "Quarterly": return "Trimestriel";case "Annual": return "Annuel";    default: return label }}(),
            ar: { switch label { case "Monthly": return "شهري";      case "Quarterly": return "ربع سنوي";    case "Annual": return "سنوي";       default: return label }}(),
            de: { switch label { case "Monthly": return "Monatlich"; case "Quarterly": return "Vierteljährlich"; case "Annual": return "Jährlich"; default: return label }}(),
            it: { switch label { case "Monthly": return "Mensile";   case "Quarterly": return "Trimestrale";case "Annual": return "Annuale";   default: return label }}(),
            nl: { switch label { case "Monthly": return "Maandelijks"; case "Quarterly": return "Kwartaal"; case "Annual": return "Jaarlijks"; default: return label }}(),
            ja: { switch label { case "Monthly": return "毎月";       case "Quarterly": return "四半期";       case "Annual": return "年次";       default: return label }}(),
            ko: { switch label { case "Monthly": return "매월";       case "Quarterly": return "분기별";       case "Annual": return "연간";       default: return label }}()
        )
    }

    /// Income/profit tax acronym for this user's country (e.g. "ISR", "Income Tax", "IRPF")
    var incomeTaxName: String {
        countryInfo?.taxName ?? "Income Tax"
    }

    /// Consumption/sales tax acronym for this user's country (e.g. "IVA", "VAT", "GST")
    var salesTaxLabel: String {
        countryInfo?.salesTaxName ?? "Sales Tax"
    }

    /// Standard sales/VAT rate for the user's country
    var salesTaxRate: Decimal {
        countryInfo?.salesTaxRate ?? 0.10
    }

    var nextTaxReminderTitle: String {
        text(en: "Upcoming tax payment", es: "Próximo pago fiscal",
             pt: "Próximo pagamento fiscal", fr: "Prochain paiement fiscal",
             ar: "الدفعة الضريبية القادمة", de: "Nächste Steuerzahlung",
             it: "Prossima scadenza fiscale", nl: "Volgende belastingbetaling",
             ja: "次回納税期限", ko: "다음 납세일")
    }

    var defaultBusinessName: String {
        text(en: "My Business", es: "Mi negocio",
             pt: "Meu negócio", fr: "Mon entreprise",
             ar: "عملي", de: "Mein Unternehmen",
             it: "La mia attività", nl: "Mijn bedrijf",
             ja: "私のビジネス", ko: "내 비즈니스")
    }

    var uncategorizedLabel: String {
        text(en: "Uncategorized", es: "Sin categoría",
             pt: "Sem categoria", fr: "Sans catégorie",
             ar: "غير مصنف", de: "Ohne Kategorie",
             it: "Senza categoria", nl: "Zonder categorie",
             ja: "未分類", ko: "미분류")
    }

    func isUncategorizedCategory(_ value: String) -> Bool {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return true }

        let candidates = [
            "uncategorized", "sin categoría", "sin categoria", "sem categoria", "sans catégorie",
            "sans categorie", "ohne kategorie", "senza categoria", "zonder categorie", "未分類", "미분류", "غير مصنف"
        ]

        return candidates.contains(normalized)
    }

    var primaryName: String {
        let trimmedWorkspace = workspaceName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPerson = personName.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmedWorkspace.isEmpty { return trimmedWorkspace }
        if !trimmedPerson.isEmpty { return trimmedPerson }
        return workspaceType == .business ? defaultBusinessName : "Balance X"
    }

    var greetingName: String {
        let trimmedPerson = personName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPerson.isEmpty { return trimmedPerson }
        return primaryName
    }
}

// MARK: - Financial Health Score

struct FinancialHealthScore {
    let score: Int // 0-100
    let grade: String // A+, A, B, C, D, F
    let factors: [HealthFactor]

    struct HealthFactor {
        let title: String
        let detail: String
        let impact: Impact
        enum Impact { case positive, neutral, negative }
    }

    static var empty: FinancialHealthScore { FinancialHealthScore(score: 0, grade: "—", factors: []) }
}

// MARK: - Net Worth

enum NetWorthAccountType: String, Codable, CaseIterable, Identifiable {
    case asset
    case liability

    var id: String { rawValue }
}

enum NetWorthCategory: String, Codable, CaseIterable, Identifiable {
    // Assets
    case bankAccount   = "Bank Account"
    case investment    = "Investment"
    case realEstate    = "Real Estate"
    case vehicle       = "Vehicle"
    case otherAsset    = "Other Asset"
    // Liabilities
    case creditCard    = "Credit Card"
    case loan          = "Loan"
    case mortgage      = "Mortgage"
    case otherLiability = "Other Liability"

    var id: String { rawValue }

    var accountType: NetWorthAccountType {
        switch self {
        case .bankAccount, .investment, .realEstate, .vehicle, .otherAsset: return .asset
        case .creditCard, .loan, .mortgage, .otherLiability: return .liability
        }
    }

    var symbol: String {
        switch self {
        case .bankAccount: return "building.columns"
        case .investment: return "chart.line.uptrend.xyaxis"
        case .realEstate: return "house.fill"
        case .vehicle: return "car.fill"
        case .otherAsset: return "shippingbox.fill"
        case .creditCard: return "creditcard.fill"
        case .loan: return "banknote"
        case .mortgage: return "house.and.flag.fill"
        case .otherLiability: return "minus.circle.fill"
        }
    }
}

struct NetWorthAccount: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var category: NetWorthCategory
    var balance: Decimal
    let createdAt: Date
    var updatedAt: Date

    var type: NetWorthAccountType { category.accountType }
}

/// Pre-computed analytics snapshot. Recomputed on a background thread whenever
/// transactions, budgets, or savings goals change, then published to the main actor.
struct BXAnalyticsCache {
    var profit: Decimal = .zero
    var totalIncome: Decimal = .zero
    var totalExpenses: Decimal = .zero
    var estimatedTaxes: Decimal = .zero
    var predictedBalance: Decimal = .zero
    var healthScore: FinancialHealthScore = .empty
    var chartPoints: [DashboardPeriod: [Decimal]] = [:]
    var insights: [DashboardPeriod: [InsightCardModel]] = [:]
    var notifications: [AppNotificationItem] = []
}

extension Array where Element == AccountingTransaction {
    func financialHealthScore(budgets: [BudgetItem], savingsGoals: [SavingsGoal], profile: OnboardingProfile) -> FinancialHealthScore {
        var score = 50
        var factors: [FinancialHealthScore.HealthFactor] = []
        func loc(
            en: String,
            es: String,
            pt: String? = nil,
            fr: String? = nil,
            ar: String? = nil,
            de: String? = nil,
            it: String? = nil,
            nl: String? = nil,
            ja: String? = nil,
            ko: String? = nil
        ) -> String {
            profile.text(en: en, es: es, pt: pt, fr: fr, ar: ar, de: de, it: it, nl: nl, ja: ja, ko: ko)
        }

        let income = totalIncome
        let expenses = totalExpenses
        let net = profit

        // Profitability factor
        if income > .zero {
            let ratio = (expenses as NSDecimalNumber).doubleValue / (income as NSDecimalNumber).doubleValue
            if ratio < 0.5 {
                score += 20
                factors.append(.init(
                    title: loc(en: "Low expense ratio", es: "Baja proporción de gastos", pt: "Baixa proporção de gastos", fr: "Faible ratio de dépenses", ar: "نسبة مصروفات منخفضة", de: "Niedrige Ausgabenquote", it: "Basso rapporto di spesa", nl: "Lage uitgavenratio", ja: "低い支出比率", ko: "낮은 지출 비율"),
                    detail: loc(en: "You spend less than 50% of income", es: "Gastas menos del 50% de tus ingresos", pt: "Você gasta menos de 50% da renda", fr: "Vous dépensez moins de 50% de vos revenus", ar: "تنفق أقل من 50% من دخلك", de: "Du gibst weniger als 50% deiner Einnahmen aus", it: "Spendi meno del 50% delle entrate", nl: "Je geeft minder dan 50% van je inkomen uit", ja: "支出は収入の50%未満です", ko: "지출이 수입의 50% 미만입니다"),
                    impact: .positive
                ))
            } else if ratio < 0.8 {
                score += 10
                factors.append(.init(
                    title: loc(en: "Moderate spending", es: "Gasto moderado", pt: "Gasto moderado", fr: "Dépenses modérées", ar: "إنفاق معتدل", de: "Moderate Ausgaben", it: "Spesa moderata", nl: "Gematigde uitgaven", ja: "適度な支出", ko: "적정 지출"),
                    detail: loc(en: "Expense ratio is manageable", es: "La proporción de gastos es manejable", pt: "A proporção de gastos é administrável", fr: "Le ratio de dépenses reste gérable", ar: "نسبة المصروفات قابلة للإدارة", de: "Die Ausgabenquote ist beherrschbar", it: "Il rapporto di spesa è gestibile", nl: "De uitgavenratio is beheersbaar", ja: "支出比率は許容範囲です", ko: "지출 비율이 관리 가능한 수준입니다"),
                    impact: .neutral
                ))
            } else {
                score -= 10
                factors.append(.init(
                    title: loc(en: "High expenses", es: "Gastos altos", pt: "Despesas altas", fr: "Dépenses élevées", ar: "مصروفات مرتفعة", de: "Hohe Ausgaben", it: "Spese elevate", nl: "Hoge uitgaven", ja: "高い支出", ko: "높은 지출"),
                    detail: loc(en: "Spending exceeds 80% of income", es: "Tus gastos superan el 80% de tus ingresos", pt: "Os gastos superam 80% da renda", fr: "Les dépenses dépassent 80% des revenus", ar: "الإنفاق يتجاوز 80% من الدخل", de: "Die Ausgaben übersteigen 80% der Einnahmen", it: "Le spese superano l'80% delle entrate", nl: "Uitgaven zijn hoger dan 80% van het inkomen", ja: "支出が収入の80%を超えています", ko: "지출이 수입의 80%를 초과합니다"),
                    impact: .negative
                ))
            }
        }

        // Net positive
        if net > .zero {
            score += 10
            factors.append(.init(
                title: loc(en: "Positive balance", es: "Balance positivo", pt: "Saldo positivo", fr: "Solde positif", ar: "رصيد إيجابي", de: "Positiver Saldo", it: "Saldo positivo", nl: "Positief saldo", ja: "プラス残高", ko: "흑자 잔액"),
                detail: loc(en: "Income exceeds expenses", es: "Tus ingresos superan tus gastos", pt: "A receita supera as despesas", fr: "Les revenus dépassent les dépenses", ar: "الدخل يتجاوز المصروفات", de: "Einnahmen übersteigen Ausgaben", it: "Le entrate superano le spese", nl: "Inkomsten zijn hoger dan uitgaven", ja: "収入が支出を上回っています", ko: "수입이 지출을 초과합니다"),
                impact: .positive
            ))
        } else if net < .zero {
            score -= 15
            factors.append(.init(
                title: loc(en: "Negative balance", es: "Balance negativo", pt: "Saldo negativo", fr: "Solde négatif", ar: "رصيد سلبي", de: "Negativer Saldo", it: "Saldo negativo", nl: "Negatief saldo", ja: "マイナス残高", ko: "적자 잔액"),
                detail: loc(en: "Expenses exceed income", es: "Tus gastos superan tus ingresos", pt: "As despesas superam a receita", fr: "Les dépenses dépassent les revenus", ar: "المصروفات تتجاوز الدخل", de: "Ausgaben übersteigen Einnahmen", it: "Le spese superano le entrate", nl: "Uitgaven zijn hoger dan inkomsten", ja: "支出が収入を上回っています", ko: "지출이 수입을 초과합니다"),
                impact: .negative
            ))
        }

        // Budget adherence
        if !budgets.isEmpty {
            let calendar = Calendar.current
            let now = Date.now
            let monthExpenses = filter { $0.type == .expense && calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
            let monthKey = String(format: "%04d-%02d", calendar.component(.year, from: now), calendar.component(.month, from: now))
            let monthlyBudget = budgets.first { $0.category == "__monthly_budget__\(monthKey)" }
            let monthlySpent = monthExpenses.reduce(into: Decimal.zero) { $0 += $1.amount }
            let categoryTotals = Dictionary(grouping: monthExpenses, by: \.category).mapValues { $0.reduce(into: Decimal.zero) { $0 += $1.amount } }
            let categoryBudgets = budgets.filter { !$0.category.hasPrefix("__monthly_budget__") }
            let overBudgetCount = categoryBudgets.filter { budget in (categoryTotals[budget.category] ?? .zero) > budget.monthlyLimit }.count
            let isMonthlyOverBudget = monthlyBudget.map { monthlySpent > $0.monthlyLimit } ?? false
            if overBudgetCount == 0 {
                score += isMonthlyOverBudget ? 0 : 15
                factors.append(.init(
                    title: isMonthlyOverBudget ? loc(en: "Monthly budget exceeded", es: "Presupuesto mensual excedido", pt: "Orçamento mensal excedido", fr: "Budget mensuel dépassé", ar: "تم تجاوز الميزانية الشهرية", de: "Monatsbudget überschritten", it: "Budget mensile superato", nl: "Maandbudget overschreden", ja: "月間予算超過", ko: "월 예산 초과") : loc(en: "Within monthly budget", es: "Dentro del presupuesto mensual", pt: "Dentro do orçamento mensal", fr: "Dans le budget mensuel", ar: "ضمن الميزانية الشهرية", de: "Innerhalb des Monatsbudgets", it: "Dentro il budget mensile", nl: "Binnen maandbudget", ja: "月間予算内", ko: "월 예산 범위 내"),
                    detail: isMonthlyOverBudget ? loc(en: "Spending is above this month's limit", es: "El gasto supera el límite de este mes", pt: "Os gastos estão acima do limite deste mês", fr: "Les dépenses dépassent la limite de ce mois", ar: "الإنفاق أعلى من حد هذا الشهر", de: "Die Ausgaben liegen über dem Limit dieses Monats", it: "La spesa supera il limite di questo mese", nl: "Uitgaven zijn boven de limiet van deze maand", ja: "支出が今月の上限を超えています", ko: "지출이 이번 달 한도를 초과했습니다") : loc(en: "Spending is below this month's limit", es: "El gasto está por debajo del límite de este mes", pt: "Os gastos estão abaixo do limite deste mês", fr: "Les dépenses sont sous la limite de ce mois", ar: "الإنفاق أقل من حد هذا الشهر", de: "Die Ausgaben liegen unter dem Limit dieses Monats", it: "La spesa è sotto il limite di questo mese", nl: "Uitgaven zijn onder de limiet van deze maand", ja: "支出は今月の上限内です", ko: "지출이 이번 달 한도 이하입니다"),
                    impact: isMonthlyOverBudget ? .negative : .positive
                ))
            } else {
                score -= overBudgetCount * 5
                factors.append(.init(
                    title: loc(en: "\(overBudgetCount) over budget", es: "\(overBudgetCount) sobre presupuesto", pt: "\(overBudgetCount) acima do orçamento", fr: "\(overBudgetCount) hors budget", ar: "\(overBudgetCount) فوق الميزانية", de: "\(overBudgetCount) über Budget", it: "\(overBudgetCount) oltre budget", nl: "\(overBudgetCount) boven budget", ja: "\(overBudgetCount)件が予算超過", ko: "\(overBudgetCount)개 예산 초과"),
                    detail: loc(en: "Some categories exceeded limits", es: "Algunas categorías superaron sus límites", pt: "Algumas categorias ultrapassaram os limites", fr: "Certaines catégories ont dépassé les limites", ar: "بعض الفئات تجاوزت الحدود", de: "Einige Kategorien haben ihre Limits überschritten", it: "Alcune categorie hanno superato i limiti", nl: "Sommige categorieën hebben de limieten overschreden", ja: "一部のカテゴリが上限を超えました", ko: "일부 카테고리가 한도를 초과했습니다"),
                    impact: .negative
                ))
            }
        }

        // Savings goals progress
        if !savingsGoals.isEmpty {
            let avgProgress = savingsGoals.map { goal -> Double in
                guard goal.targetAmount > .zero else { return 1.0 }
                return Swift.min(1.0, (goal.savedAmount as NSDecimalNumber).doubleValue / (goal.targetAmount as NSDecimalNumber).doubleValue)
            }.reduce(0, +) / Double(savingsGoals.count)
            if avgProgress > 0.5 {
                score += 10
                factors.append(.init(
                    title: loc(en: "Savings on track", es: "Ahorro en buen camino", pt: "Poupança no caminho certo", fr: "Épargne en bonne voie", ar: "الادخار على المسار الصحيح", de: "Sparen im Plan", it: "Risparmio in linea", nl: "Sparen ligt op koers", ja: "貯蓄は順調です", ko: "저축 목표가 순조롭습니다"),
                    detail: loc(en: "Over 50% toward goals", es: "Más del 50% de avance hacia tus metas", pt: "Mais de 50% rumo às metas", fr: "Plus de 50% de progression vers les objectifs", ar: "أكثر من 50% نحو الأهداف", de: "Mehr als 50% Fortschritt zu den Zielen", it: "Oltre il 50% verso gli obiettivi", nl: "Meer dan 50% richting doelen", ja: "目標達成まで50%以上進んでいます", ko: "목표 달성률이 50%를 넘었습니다"),
                    impact: .positive
                ))
            }
        }

        // Diversity
        let categories = Set(filter { $0.type == .expense }.map(\.category))
        if categories.count >= 3 {
            score += 5
            factors.append(.init(
                title: loc(en: "Diversified tracking", es: "Seguimiento diversificado", pt: "Acompanhamento diversificado", fr: "Suivi diversifié", ar: "تتبع متنوع", de: "Vielfältiges Tracking", it: "Monitoraggio diversificato", nl: "Gediversifieerde tracking", ja: "多様な支出トラッキング", ko: "다양한 추적"),
                detail: loc(en: "\(categories.count) expense categories", es: "\(categories.count) categorías de gasto", pt: "\(categories.count) categorias de despesa", fr: "\(categories.count) catégories de dépense", ar: "\(categories.count) فئات مصروفات", de: "\(categories.count) Ausgabenkategorien", it: "\(categories.count) categorie di spesa", nl: "\(categories.count) uitgavencategorieën", ja: "\(categories.count) 個の支出カテゴリ", ko: "\(categories.count)개의 지출 카테고리"),
                impact: .positive
            ))
        }

        let clamped = Swift.max(0, Swift.min(100, score))
        let grade: String
        switch clamped {
        case 90...100: grade = "A+"
        case 80..<90: grade = "A"
        case 70..<80: grade = "B"
        case 60..<70: grade = "C"
        case 50..<60: grade = "D"
        default: grade = "F"
        }

        return FinancialHealthScore(score: clamped, grade: grade, factors: factors)
    }

    /// AI-style spending prediction: estimated end-of-month balance based on current pace.
    func predictedEndOfMonthBalance(currentBalance: Decimal) -> Decimal {
        let calendar = Calendar.current
        let now = Date.now
        let monthExpenses = filter { $0.type == .expense && calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
        let dayOfMonth = calendar.component(.day, from: now)
        guard dayOfMonth > 0 else { return currentBalance }
        let range = calendar.range(of: .day, in: .month, for: now) ?? 1..<31
        let daysInMonth = range.count
        let dailyRate = monthExpenses.reduce(into: Decimal.zero) { $0 += $1.amount } / Decimal(dayOfMonth)
        let remainingDays = Decimal(daysInMonth - dayOfMonth)
        return currentBalance - (dailyRate * remainingDays)
    }
}

enum BXCurrencyConverter {
    private static let usdToHnl = Decimal(string: "24.70") ?? 24.70

    static func convert(amount: Decimal, from sourceCode: String?, to targetCode: String) -> CurrencyConversionResult {
        guard let sourceCode, sourceCode != targetCode else {
            return CurrencyConversionResult(amount: amount, sourceCurrencyCode: sourceCode)
        }

        let converted: Decimal
        switch (sourceCode, targetCode) {
        case ("USD", "HNL"):
            converted = amount * usdToHnl
        case ("HNL", "USD"):
            converted = amount / usdToHnl
        default:
            converted = amount
        }

        return CurrencyConversionResult(amount: converted, sourceCurrencyCode: sourceCode)
    }
}
