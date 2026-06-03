import Intents
import PhotosUI
import SwiftUI
#if canImport(UIKit)
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit
#if canImport(VisionKit)
import VisionKit
#endif

private enum ReceiptCaptureSource: String {
    case scan
    case library

    var label: String { rawValue }
}

struct AddExpenseView: View {
    let initialTransaction: AccountingTransaction?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var supabase: SupabaseManager

    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var transactionType: TransactionType
    @State private var vendor: String
    @State private var amount: String
    @State private var category: String
    @State private var date: Date
    @State private var notes: String
    @State private var rawOCRText: String?
    @State private var ocrSummaryText: String?
    @State private var uploadedImageURL: URL?
    @State private var isScanning = false
    @State private var hasAttemptedOCR = false
    @State private var detectedSourceCurrencyCode: String?
    @State private var detectedDocumentType: OCRDocumentType = .unknown
    @State private var showImportOptions = false
    @State private var showingPhotoLibrary = false
    @State private var showingDocumentScanner = false
    @State private var captureSource: ReceiptCaptureSource?
    @State private var ocrVendorGuess: String?
    // Savings goal contribution (income only)
    @State private var saveToGoal = false
    @State private var selectedGoalID: UUID?
    @State private var goalContribution = ""
    // Budget over-limit alert
    @State private var budgetAlert: BudgetItem?
    // Category picker sheet
    @State private var showCategoryPicker = false

    init(initialTransaction: AccountingTransaction? = nil) {
        self.initialTransaction = initialTransaction
        _transactionType = State(initialValue: initialTransaction?.type ?? .expense)
        _vendor = State(initialValue: initialTransaction?.vendor ?? "")
        _amount = State(initialValue: initialTransaction.map { NSDecimalNumber(decimal: $0.amount).stringValue } ?? "")
        _category = State(initialValue: initialTransaction?.category ?? "")
        _date = State(initialValue: initialTransaction?.date ?? .now)
        _notes = State(initialValue: initialTransaction?.notes ?? "")
        _rawOCRText = State(initialValue: nil)
    }

    private var prof: OnboardingProfile { supabase.onboardingProfile }

    // Category definitions with icon and localized name
    private struct CategoryDef {
        let key: String
        let en: String
        let es: String
        let pt: String
        let fr: String
        let ar: String
        let de: String
        let it: String
        let nl: String
        let ja: String
        let ko: String
        let icon: String
    }

    private static let allCategories: [CategoryDef] = [
        // Food & Lifestyle
        CategoryDef(key: "food",          en: "Food",          es: "Comida",         pt: "Comida",        fr: "Nourriture",      ar: "طعام",          de: "Essen",           it: "Cibo",          nl: "Eten",           ja: "食費",          ko: "음식",          icon: "fork.knife"),
        CategoryDef(key: "groceries",     en: "Groceries",     es: "Supermercado",   pt: "Mercado",       fr: "Courses",         ar: "بقالة",         de: "Lebensmittel",   it: "Spesa",         nl: "Boodschappen",   ja: "食料品",        ko: "식료품",        icon: "cart.fill"),
        CategoryDef(key: "coffee",        en: "Coffee",        es: "Café",           pt: "Café",          fr: "Café",            ar: "قهوة",          de: "Kaffee",         it: "Caffè",         nl: "Koffie",         ja: "コーヒー",      ko: "커피",          icon: "cup.and.saucer.fill"),
        CategoryDef(key: "drinks",        en: "Drinks",        es: "Bebidas",        pt: "Bebidas",       fr: "Boissons",        ar: "مشروبات",       de: "Getränke",       it: "Bevande",       nl: "Dranken",        ja: "飲み物",        ko: "음료",          icon: "wineglass.fill"),
        // Transportation
        CategoryDef(key: "transport",     en: "Transport",     es: "Transporte",     pt: "Transporte",    fr: "Transport",       ar: "مواصلات",       de: "Transport",      it: "Trasporti",     nl: "Vervoer",        ja: "交通",          ko: "교통",          icon: "car.fill"),
        CategoryDef(key: "gas",           en: "Gas",           es: "Gasolina",       pt: "Combustível",   fr: "Carburant",       ar: "وقود",          de: "Kraftstoff",     it: "Carburante",    nl: "Brandstof",      ja: "燃料",          ko: "연료",          icon: "fuelpump.fill"),
        CategoryDef(key: "travel",        en: "Travel",        es: "Viajes",         pt: "Viagens",       fr: "Voyages",         ar: "سفر",           de: "Reisen",         it: "Viaggi",        nl: "Reizen",         ja: "旅行",          ko: "여행",          icon: "airplane"),
        CategoryDef(key: "parking",       en: "Parking",       es: "Estacionamiento",pt: "Estacionamento",fr: "Stationnement",   ar: "مواقف",         de: "Parken",         it: "Parcheggio",    nl: "Parkeren",       ja: "駐車場",        ko: "주차",          icon: "parkingsign.circle.fill"),
        // Home & Bills
        CategoryDef(key: "rent",          en: "Rent",          es: "Renta",          pt: "Aluguel",       fr: "Loyer",           ar: "إيجار",         de: "Miete",          it: "Affitto",       nl: "Huur",           ja: "家賃",          ko: "임대료",        icon: "house.fill"),
        CategoryDef(key: "utilities",     en: "Utilities",     es: "Servicios",      pt: "Serviços",      fr: "Services",        ar: "مرافق",         de: "Nebenkosten",    it: "Utenze",        nl: "Nutsvoorzieningen", ja: "公共料金",    ko: "공과금",        icon: "bolt.fill"),
        CategoryDef(key: "internet",      en: "Internet",      es: "Internet",       pt: "Internet",      fr: "Internet",        ar: "إنترنت",        de: "Internet",       it: "Internet",      nl: "Internet",       ja: "インターネット", ko: "인터넷",        icon: "wifi"),
        CategoryDef(key: "phone",         en: "Phone",         es: "Teléfono",       pt: "Telefone",      fr: "Téléphone",       ar: "هاتف",          de: "Telefon",        it: "Telefono",      nl: "Telefoon",       ja: "電話",          ko: "전화",          icon: "phone.fill"),
        // Health
        CategoryDef(key: "health",        en: "Health",        es: "Salud",          pt: "Saúde",         fr: "Santé",           ar: "صحة",           de: "Gesundheit",     it: "Salute",        nl: "Gezondheid",     ja: "健康",          ko: "건강",          icon: "cross.case.fill"),
        CategoryDef(key: "pharmacy",      en: "Pharmacy",      es: "Farmacia",       pt: "Farmácia",      fr: "Pharmacie",       ar: "صيدلية",        de: "Apotheke",       it: "Farmacia",      nl: "Apotheek",       ja: "薬局",          ko: "약국",          icon: "pills.fill"),
        CategoryDef(key: "gym",           en: "Gym",           es: "Gimnasio",       pt: "Academia",      fr: "Salle de sport",  ar: "نادي رياضي",     de: "Fitnessstudio",  it: "Palestra",      nl: "Sportschool",    ja: "ジム",          ko: "헬스장",        icon: "figure.strengthtraining.traditional"),
        // Education & Work
        CategoryDef(key: "education",     en: "Education",     es: "Educación",      pt: "Educação",      fr: "Éducation",       ar: "تعليم",         de: "Bildung",        it: "Istruzione",    nl: "Onderwijs",      ja: "教育",          ko: "교육",          icon: "book.fill"),
        CategoryDef(key: "subscriptions", en: "Subscriptions", es: "Suscripciones",  pt: "Assinaturas",    fr: "Abonnements",     ar: "اشتراكات",      de: "Abonnements",    it: "Abbonamenti",   nl: "Abonnementen",   ja: "サブスク",      ko: "구독",          icon: "repeat.circle.fill"),
        CategoryDef(key: "software",      en: "Software",      es: "Software",       pt: "Software",      fr: "Logiciels",       ar: "برامج",          de: "Software",       it: "Software",      nl: "Software",       ja: "ソフトウェア",  ko: "소프트웨어",    icon: "laptopcomputer"),
        // Shopping & Style
        CategoryDef(key: "clothing",      en: "Clothing",      es: "Ropa",           pt: "Roupas",        fr: "Vêtements",       ar: "ملابس",         de: "Kleidung",       it: "Abbigliamento", nl: "Kleding",        ja: "衣類",          ko: "의류",          icon: "tshirt.fill"),
        CategoryDef(key: "shopping",      en: "Shopping",      es: "Compras",        pt: "Compras",       fr: "Achats",          ar: "تسوق",          de: "Einkäufe",       it: "Shopping",      nl: "Winkelen",       ja: "買い物",        ko: "쇼핑",          icon: "bag.fill"),
        CategoryDef(key: "electronics",   en: "Electronics",   es: "Electrónicos",   pt: "Eletrônicos",   fr: "Électronique",    ar: "إلكترونيات",    de: "Elektronik",     it: "Elettronica",   nl: "Elektronica",    ja: "電子機器",      ko: "전자제품",      icon: "tv.fill"),
        // Entertainment
        CategoryDef(key: "entertainment", en: "Entertainment", es: "Entretenimiento",pt: "Entretenimento",fr: "Divertissement", ar: "ترفيه",         de: "Unterhaltung",   it: "Intrattenimento", nl: "Entertainment", ja: "娯楽",          ko: "엔터테인먼트",  icon: "play.circle.fill"),
        CategoryDef(key: "gaming",        en: "Gaming",        es: "Juegos",         pt: "Jogos",         fr: "Jeux",            ar: "ألعاب",         de: "Gaming",         it: "Giochi",        nl: "Games",          ja: "ゲーム",        ko: "게임",          icon: "gamecontroller.fill"),
        // Finance
        CategoryDef(key: "taxes",         en: "Taxes",         es: "Impuestos",      pt: "Impostos",      fr: "Impôts",          ar: "ضرائب",         de: "Steuern",        it: "Tasse",         nl: "Belastingen",    ja: "税金",          ko: "세금",          icon: "doc.text.fill"),
        CategoryDef(key: "insurance",     en: "Insurance",     es: "Seguro",         pt: "Seguro",        fr: "Assurance",       ar: "تأمين",         de: "Versicherung",   it: "Assicurazione", nl: "Verzekering",    ja: "保険",          ko: "보험",          icon: "shield.fill"),
        CategoryDef(key: "investment",    en: "Investment",    es: "Inversión",      pt: "Investimento",  fr: "Investissement",  ar: "استثمار",       de: "Investition",    it: "Investimento",  nl: "Investering",    ja: "投資",          ko: "투자",          icon: "chart.line.uptrend.xyaxis"),
        // Income-specific
        CategoryDef(key: "salary",        en: "Salary",        es: "Salario",        pt: "Salário",       fr: "Salaire",         ar: "راتب",          de: "Gehalt",         it: "Stipendio",     nl: "Salaris",        ja: "給与",          ko: "급여",          icon: "banknote.fill"),
        CategoryDef(key: "freelance",     en: "Freelance",     es: "Freelance",      pt: "Freelance",     fr: "Freelance",       ar: "عمل حر",        de: "Freelance",      it: "Freelance",     nl: "Freelance",      ja: "フリーランス",  ko: "프리랜스",      icon: "person.badge.plus"),
        CategoryDef(key: "sales",         en: "Sales",         es: "Ventas",         pt: "Vendas",        fr: "Ventes",          ar: "مبيعات",        de: "Verkäufe",       it: "Vendite",       nl: "Verkoop",        ja: "売上",          ko: "매출",          icon: "storefront.fill"),
        CategoryDef(key: "dividends",     en: "Dividends",     es: "Dividendos",     pt: "Dividendos",    fr: "Dividendes",      ar: "أرباح أسهم",     de: "Dividenden",     it: "Dividendi",     nl: "Dividenden",     ja: "配当",          ko: "배당금",        icon: "arrow.triangle.2.circlepath"),
        // Other
        CategoryDef(key: "other",         en: "Other",         es: "Otros",          pt: "Outro",         fr: "Autre",           ar: "أخرى",           de: "Sonstiges",      it: "Altro",         nl: "Overig",         ja: "その他",        ko: "기타",          icon: "square.grid.2x2.fill"),
    ]

    private var categoryOptions: [CategoryDef] {
        if transactionType == .income {
            // Show income-specific categories first
            let incomeKeys = ["salary", "freelance", "sales", "dividends", "investment", "other"]
            let incomeFirst = Self.allCategories.filter { incomeKeys.contains($0.key) }
            let rest = Self.allCategories.filter { !incomeKeys.contains($0.key) }
            return incomeFirst + rest
        }
        return Self.allCategories
    }

    private func categoryLabel(_ def: CategoryDef) -> String {
        prof.text(en: def.en, es: def.es, pt: def.pt, fr: def.fr, ar: def.ar, de: def.de, it: def.it, nl: def.nl, ja: def.ja, ko: def.ko)
    }

    // Top 3 categories by usage frequency; falls back to first 3 in pool
    private var topCategories: [CategoryDef] {
        let pool = categoryOptions
        let usageCounts = supabase.transactions
            .filter { $0.type == transactionType }
            .reduce(into: [String: Int]()) { counts, tx in
                counts[tx.category.lowercased(), default: 0] += 1
            }

        var sorted: [CategoryDef]
        if usageCounts.isEmpty {
            sorted = pool
        } else {
            sorted = pool.sorted { a, b in
                let aKey = categoryLabel(a).lowercased()
                let bKey = categoryLabel(b).lowercased()
                let aC = usageCounts[aKey] ?? usageCounts[a.key] ?? 0
                let bC = usageCounts[bKey] ?? usageCounts[b.key] ?? 0
                return aC > bC
            }
        }

        var top = Array(sorted.prefix(3))
        // Always keep currently-selected category visible
        if !category.isEmpty,
           let currentDef = pool.first(where: { categoryLabel($0) == category || $0.key == category.lowercased() }),
           !top.contains(where: { $0.key == currentDef.key }) {
            top[2] = currentDef
        }
        return top
    }

    // Custom categories saved by user
    private static let customCategoriesKey = "bx_custom_categories"

    private var customCategories: [String] {
        let legacy = UserDefaults.standard.stringArray(forKey: Self.customCategoriesKey) ?? []
        let managed = supabase.customCategories.filter { !$0.isHidden }.map(\.name)
        return Array(Set(legacy + managed)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func saveCustomCategoryIfNeeded() {
        let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // Only save if it's not already a built-in category
        let isBuiltIn = Self.allCategories.contains { categoryLabel($0) == trimmed || $0.key == trimmed.lowercased() }
        guard !isBuiltIn else { return }
        supabase.addCustomCategory(named: trimmed)
        var customs = UserDefaults.standard.stringArray(forKey: Self.customCategoriesKey) ?? []
        guard !customs.contains(trimmed) else { return }
        customs.insert(trimmed, at: 0)
        if customs.count > 20 { customs = Array(customs.prefix(20)) }
        UserDefaults.standard.set(customs, forKey: Self.customCategoriesKey)
    }

    private func iconForCategory(_ cat: String) -> String {
        let lower = cat.lowercased()
        return Self.allCategories.first(where: {
            lower.contains($0.key) || lower.contains($0.en.lowercased()) || lower.contains($0.es.lowercased())
        })?.icon ?? "square.grid.2x2.fill"
    }

    private func currencySymbol(for code: String) -> String {
        let locale = Locale.availableIdentifiers
            .map { Locale(identifier: $0) }
            .first { $0.currency?.identifier == code }
        return locale?.currencySymbol ?? code
    }

    private func handleKey(_ key: String) {
        switch key {
        case "⌫":
            if !amount.isEmpty { amount.removeLast() }
        case ".":
            if !amount.contains(".") { amount += "." }
        default:
            if amount == "0" { amount = key }
            else { amount += key }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BXBackground()

                VStack(spacing: 0) {

                    // ── Header ───────────────────────────────────────────
                    HStack(spacing: 12) {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(BXPalette.textSecondary)
                                .frame(width: 34, height: 34)
                                .background(BXPalette.fieldFill, in: Circle())
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Text(initialTransaction == nil
                             ? prof.text(en: "New Transaction",  es: "Nuevo Movimiento",
                                         pt: "Nova Transação",   fr: "Nouvelle opération",
                                         ar: "معاملة جديدة",    de: "Neue Transaktion",
                                         it: "Nuova Transazione", nl: "Nieuwe Transactie",
                                         ja: "新しい取引",         ko: "새 거래")
                             : prof.text(en: "Edit Transaction",  es: "Editar Movimiento",
                                         pt: "Editar Transação",  fr: "Modifier l'opération",
                                         ar: "تعديل المعاملة",   de: "Transaktion bearbeiten",
                                         it: "Modifica Transazione", nl: "Transactie bewerken",
                                         ja: "取引を編集",          ko: "거래 편집"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)

                        Spacer()

                        // Invisible spacer to balance the X button
                        Color.clear.frame(width: 34, height: 34)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                    // ── Gasto / Ingreso Toggle (full-width, prominent) ────
                    HStack(spacing: 0) {
                        ForEach([TransactionType.expense, .income], id: \.self) { type in
                            Button {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) { transactionType = type }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: type == .expense ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                                        .font(.system(size: 17, weight: .semibold))
                                    Text(type == .expense
                                         ? prof.text(en: "Expense",  es: "Gasto",    pt: "Despesa",
                                                     fr: "Dépense",  ar: "مصروف",    de: "Ausgabe",
                                                     it: "Spesa",    nl: "Uitgave",   ja: "支出",    ko: "지출")
                                         : prof.text(en: "Income",   es: "Ingreso",  pt: "Receita",
                                                     fr: "Revenu",   ar: "دخل",      de: "Einnahme",
                                                     it: "Entrata",  nl: "Inkomst",  ja: "収入",    ko: "수입"))
                                        .font(.system(size: 16, weight: .bold))
                                }
                                .foregroundStyle(transactionType == type
                                    ? (type == .expense ? BXPalette.expense : BXPalette.income)
                                    : BXPalette.textTertiary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    transactionType == type
                                        ? (type == .expense ? BXPalette.expense.opacity(0.15) : BXPalette.income.opacity(0.15))
                                        : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(4)
                    .background(BXPalette.fieldFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(BXPalette.panelStroke, lineWidth: 0.5))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 4)

                    // ── Amount Display ────────────────────────────────────
                    VStack(spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(currencySymbol(for: supabase.onboardingProfile.currencyCode))
                                .font(.system(size: 22, weight: .regular))
                                .foregroundStyle(BXPalette.textSecondary)
                            Text(amount.isEmpty ? "0" : amount)
                                .font(.system(size: 54, weight: .bold, design: .rounded))
                                .foregroundStyle(transactionType == .expense ? BXPalette.expense : BXPalette.income)
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.4)
                        }
                        .animation(.spring(response: 0.2), value: amount)

                        if isScanning {
                            HStack(spacing: 6) {
                                ProgressView().tint(BXPalette.accentStart).scaleEffect(0.75)
                                Text(prof.text(en: "Analyzing receipt...",  es: "Analizando recibo...",
                                               pt: "Analisando recibo...", fr: "Analyse du reçu...",
                                               ar: "جاري تحليل الإيصال...", de: "Beleg wird analysiert...",
                                               it: "Analisi ricevuta...",   nl: "Bon wordt geanalyseerd...",
                                               ja: "レシートを分析中...",    ko: "영수증 분석 중..."))
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(BXPalette.textSecondary)
                            }
                        } else if !vendor.isEmpty {
                            Text(vendor)
                                .font(.caption)
                                .foregroundStyle(BXPalette.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)

                    // ── Categories — top 3 pills + "Más" button ───────────
                    HStack(spacing: 8) {
                        ForEach(topCategories, id: \.key) { def in
                            let label = categoryLabel(def)
                            let isSelected = category == label || category == def.en || category == def.es
                            let activeColor = transactionType == .expense ? BXPalette.expense : BXPalette.income
                            Button {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) { category = label }
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: def.icon)
                                        .font(.caption.weight(.semibold))
                                    Text(label)
                                        .font(.caption.weight(.semibold))
                                        .lineLimit(1)
                                }
                                .foregroundStyle(isSelected ? activeColor : BXPalette.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(
                                    isSelected ? activeColor.opacity(0.15) : BXPalette.fieldFill,
                                    in: Capsule()
                                )
                                .overlay(
                                    Capsule()
                                        .strokeBorder(isSelected ? activeColor.opacity(0.4) : Color.clear, lineWidth: 0.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        Spacer()

                        Button { showCategoryPicker = true } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "square.grid.2x2")
                                    .font(.caption.weight(.semibold))
                                Text(prof.text(en: "More", es: "Más", pt: "Mais", fr: "Plus",
                                               ar: "المزيد", de: "Mehr", it: "Altro", nl: "Meer",
                                               ja: "もっと見る", ko: "더보기"))
                                    .font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(BXPalette.textTertiary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(BXPalette.fieldFill, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .sheet(isPresented: $showCategoryPicker) {
                            categoryPickerSheet
                        }
                    }
                    .padding(.horizontal, 20)

                    // ── Vendor + Notes + Date ─────────────────────────────
                    HStack(spacing: 10) {
                        Image(systemName: "textformat")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(BXPalette.textTertiary)
                        TextField(prof.text(en: "Add vendor / context...",    es: "Agrega contexto o nombre...",
                                            pt: "Fornecedor / contexto...",  fr: "Fournisseur / contexte...",
                                            ar: "أضف البائع / السياق...",   de: "Händler / Kontext...",
                                            it: "Fornitore / contesto...",   nl: "Leverancier / context...",
                                            ja: "販売店 / 詳細...",           ko: "상점 / 내용..."), text: $vendor)
                            .font(.subheadline)
                            .foregroundStyle(BXPalette.textPrimary)
                        Spacer()
                        DatePicker("", selection: $date, displayedComponents: .date)
                            .labelsHidden()
                            .colorScheme(.dark)
                            .scaleEffect(0.85, anchor: .trailing)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)

                    Divider().opacity(0.1).padding(.horizontal, 20)

                    // ── Savings goal (income only) ────────────────────────
                    if transactionType == .income && !supabase.savingsGoals.isEmpty {
                        incomeGoalCard
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                            .padding(.bottom, 12)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // ── Scan receipt button ───────────────────────────────
                    Button { showImportOptions = true } label: {
                        HStack(spacing: 10) {
                            ZStack {
                                if let selectedImageData, let img = UIImage(data: selectedImageData) {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 32, height: 32)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                } else {
                                    Image(systemName: "doc.text.viewfinder")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(BXPalette.accentStart)
                                }
                            }
                            Text(selectedImageData != nil
                                 ? prof.text(en: "Receipt attached",   es: "Comprobante adjunto",
                                             pt: "Comprovante anexado", fr: "Reçu joint",
                                             ar: "تم إرفاق الإيصال",   de: "Beleg angehängt",
                                             it: "Ricevuta allegata",  nl: "Bon bijgevoegd",
                                             ja: "レシートを添付済み",   ko: "영수증 첨부됨")
                                 : prof.text(en: "Upload receipt",      es: "Subir comprobante",
                                             pt: "Enviar comprovante",  fr: "Télécharger reçu",
                                             ar: "رفع الإيصال",         de: "Beleg hochladen",
                                             it: "Carica ricevuta",    nl: "Bon uploaden",
                                             ja: "レシートをアップロード", ko: "영수증 업로드"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(selectedImageData != nil ? BXPalette.income : .white)
                            Spacer()
                            Image(systemName: selectedImageData != nil ? "checkmark.circle.fill" : "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(selectedImageData != nil ? BXPalette.income : BXPalette.textTertiary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(BXPalette.fieldFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(selectedImageData != nil ? BXPalette.income.opacity(0.4) : BXPalette.panelStroke, lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)

                    Spacer(minLength: 8)

                    // ── Keypad ────────────────────────────────────────────
                    let keys = ["1","2","3","4","5","6","7","8","9",".","0","⌫"]
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(keys, id: \.self) { key in
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                handleKey(key)
                            } label: {
                                Group {
                                    if key == "⌫" {
                                        Image(systemName: "delete.left")
                                            .font(.system(size: 18, weight: .medium))
                                    } else {
                                        Text(key)
                                            .font(.system(size: 22, weight: .medium, design: .rounded))
                                    }
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(key == "⌫" ? BXPalette.panelFillElevated : BXPalette.fieldFill,
                                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)

                    // ── Save button ───────────────────────────────────────
                    Button {
                        Task { await saveTransaction() }
                    } label: {
                        HStack(spacing: 8) {
                            if supabase.isLoading {
                                ProgressView().tint(.black)
                            } else {
                                Image(systemName: "checkmark")
                                    .font(.subheadline.weight(.bold))
                                Text(initialTransaction == nil
                                     ? prof.text(en: "Save",   es: "Guardar", pt: "Salvar",    fr: "Enregistrer",
                                                 ar: "حفظ",    de: "Speichern", it: "Salva",  nl: "Opslaan",
                                                 ja: "保存",    ko: "저장")
                                     : prof.text(en: "Update", es: "Actualizar", pt: "Atualizar", fr: "Mettre à jour",
                                                 ar: "تحديث",  de: "Aktualisieren", it: "Aggiorna", nl: "Bijwerken",
                                                 ja: "更新",    ko: "업데이트"))
                                    .font(.headline.weight(.semibold))
                            }
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(canSave ? Color.white : Color.white.opacity(0.35),
                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSave || supabase.isLoading || isScanning)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 28)
                }
            }  // ZStack
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: canSave)
            .confirmationDialog(
                prof.text(en: "Upload Receipt",     es: "Subir comprobante",
                          pt: "Enviar comprovante", fr: "Télécharger reçu",
                          ar: "رفع الإيصال",        de: "Beleg hochladen",
                          it: "Carica ricevuta",   nl: "Bon uploaden",
                          ja: "レシートをアップロード", ko: "영수증 업로드"),
                isPresented: $showImportOptions,
                titleVisibility: .visible
            ) {
                #if canImport(VisionKit)
                Button(prof.text(en: "Scan document",    es: "Escanear documento",
                                 pt: "Escanear documento", fr: "Scanner un document",
                                 ar: "مسح المستند",      de: "Dokument scannen",
                                 it: "Scansiona documento", nl: "Document scannen",
                                 ja: "書類をスキャン",     ko: "문서 스캔")) {
                    showingDocumentScanner = true
                }
                #endif
                Button(prof.text(en: "Choose from library",  es: "Elegir de la galería",
                                 pt: "Escolher da galeria", fr: "Choisir de la galerie",
                                 ar: "اختر من المكتبة",    de: "Aus Bibliothek wählen",
                                 it: "Scegli dalla libreria", nl: "Kies uit bibliotheek",
                                 ja: "ライブラリから選択",   ko: "라이브러리에서 선택")) {
                    showingPhotoLibrary = true
                }
                Button(prof.text(en: "Cancel", es: "Cancelar", pt: "Cancelar", fr: "Annuler",
                                 ar: "إلغاء", de: "Abbrechen", it: "Annulla", nl: "Annuleren",
                                 ja: "キャンセル", ko: "취소"), role: .cancel) {}
            }
            .photosPicker(isPresented: $showingPhotoLibrary, selection: $selectedItem, matching: .images)
            .sheet(isPresented: $showingDocumentScanner) {
                BXDocumentScanner { data in
                    setSelectedImage(data, source: .scan)
                }
            }
            .onChange(of: selectedItem) { _, newValue in
                guard let newValue else { return }

                Task {
                    let data = try? await newValue.loadTransferable(type: Data.self)
                    setSelectedImage(data, source: .library)
                }
            }
            .alert(
                prof.text(en: "Budget exceeded",        es: "Presupuesto excedido",
                          pt: "Orçamento excedido",     fr: "Budget dépassé",
                          ar: "تجاوز الميزانية",        de: "Budget überschritten",
                          it: "Budget superato",        nl: "Budget overschreden",
                          ja: "予算超過",                ko: "예산 초과"),
                isPresented: Binding(
                    get: { budgetAlert != nil },
                    set: { if !$0 { budgetAlert = nil; dismiss() } }
                ),
                presenting: budgetAlert
            ) { budget in
                Button(prof.text(en: "Got it", es: "Entendido", pt: "Entendi", fr: "Compris",
                                 ar: "فهمت", de: "Verstanden", it: "Capito", nl: "Begrepen",
                                 ja: "了解", ko: "확인"), role: .cancel) {
                    budgetAlert = nil
                    dismiss()
                }
            } message: { budget in
                let spent = supabase.totalSpentThisMonth()
                let limit = budget.monthlyLimit
                let code = supabase.onboardingProfile.currencyCode
                Text(prof.text(
                    en: "You've spent \(spent.currencyString(code: code)) this month, over your monthly budget of \(limit.currencyString(code: code)).",
                    es: "Gastaste \(spent.currencyString(code: code)) este mes, superando tu presupuesto mensual de \(limit.currencyString(code: code)).",
                    pt: "Você gastou \(spent.currencyString(code: code)) este mês, acima do orçamento mensal de \(limit.currencyString(code: code)).",
                    fr: "Vous avez dépensé \(spent.currencyString(code: code)) ce mois-ci, au-dessus du budget mensuel de \(limit.currencyString(code: code)).",
                    ar: "لقد أنفقت \(spent.currencyString(code: code)) هذا الشهر، متجاوزًا الميزانية الشهرية \(limit.currencyString(code: code)).",
                    de: "Du hast diesen Monat \(spent.currencyString(code: code)) ausgegeben und damit dein Monatsbudget von \(limit.currencyString(code: code)) überschritten.",
                    it: "Hai speso \(spent.currencyString(code: code)) questo mese, superando il budget mensile di \(limit.currencyString(code: code)).",
                    nl: "Je hebt deze maand \(spent.currencyString(code: code)) uitgegeven, boven je maandbudget van \(limit.currencyString(code: code)).",
                    ja: "今月 \(spent.currencyString(code: code)) を使い、月間予算 \(limit.currencyString(code: code)) を超えています。",
                    ko: "이번 달 \(spent.currencyString(code: code))을 사용해 월 예산 \(limit.currencyString(code: code))을 초과했습니다."
                ))
            }
            .onAppear {
                if category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    category = prof.uncategorizedLabel
                }
            }
            .userActivity("com.bx.add-expense") { activity in
                activity.title = "Add expense in Balance X"
                activity.isEligibleForSearch = true
                activity.isEligibleForPrediction = true
                activity.suggestedInvocationPhrase = "Add expense"
            }
        }
    }

    private var transactionTypeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            BXSectionTitle(
                eyebrow: prof.text(en: "Flow", es: "Flujo", pt: "Fluxo", fr: "Flux", ar: "التدفق", de: "Ablauf", it: "Flusso", nl: "Stroom", ja: "フロー", ko: "흐름"),
                title: prof.text(en: "Select transaction type", es: "Selecciona tipo de movimiento", pt: "Selecione o tipo de transação", fr: "Sélectionnez le type d'opération", ar: "اختر نوع المعاملة", de: "Transaktionstyp auswählen", it: "Seleziona tipo di transazione", nl: "Selecteer transactietype", ja: "取引タイプを選択", ko: "거래 유형 선택")
            )

            Picker(prof.text(en: "Transaction Type", es: "Tipo de movimiento", pt: "Tipo de transação", fr: "Type d'opération", ar: "نوع المعاملة", de: "Transaktionstyp", it: "Tipo di transazione", nl: "Transactietype", ja: "取引タイプ", ko: "거래 유형"), selection: $transactionType) {
                Text(prof.text(en: "Expense", es: "Gasto", pt: "Despesa", fr: "Dépense", ar: "مصروف", de: "Ausgabe", it: "Spesa", nl: "Uitgave", ja: "支出", ko: "지출")).tag(TransactionType.expense)
                Text(prof.text(en: "Income", es: "Ingreso", pt: "Receita", fr: "Revenu", ar: "دخل", de: "Einnahme", it: "Entrata", nl: "Inkomst", ja: "収入", ko: "수입")).tag(TransactionType.income)
            }
            .pickerStyle(.segmented)

            Text(transactionType == .expense
                 ? prof.text(en: "Scan a receipt or import one from your library.", es: "Escanea un recibo o impórtalo desde tu galería.", pt: "Escaneie um recibo ou importe da galeria.", fr: "Scannez un reçu ou importez-le depuis votre galerie.", ar: "امسح إيصالًا أو استورده من مكتبتك.", de: "Scanne einen Beleg oder importiere ihn aus deiner Bibliothek.", it: "Scansiona una ricevuta o importala dalla libreria.", nl: "Scan een bon of importeer er een uit je bibliotheek.", ja: "レシートをスキャンするかライブラリから読み込みます。", ko: "영수증을 스캔하거나 보관함에서 가져오세요.")
                 : prof.text(en: "Register income with vendor, amount, and date.", es: "Registra ingresos con origen, monto y fecha.", pt: "Registre receitas com origem, valor e data.", fr: "Enregistrez un revenu avec source, montant et date.", ar: "سجّل الدخل مع المصدر والمبلغ والتاريخ.", de: "Erfasse Einnahmen mit Quelle, Betrag und Datum.", it: "Registra entrate con fonte, importo e data.", nl: "Registreer inkomsten met bron, bedrag en datum.", ja: "入金元、金額、日付を指定して収入を登録します。", ko: "출처, 금액, 날짜로 수입을 등록하세요."))
                .font(.subheadline)
                .foregroundStyle(BXPalette.textPrimary.opacity(0.65))
        }
        .padding(20)
        .bxGlassCard(cornerRadius: 24)
    }

    private var receiptHero: some View {
        VStack(alignment: .leading, spacing: 14) {
            BXSectionTitle(
                eyebrow: prof.text(en: "Receipt AI", es: "IA de Recibo", pt: "IA de Recibo",
                    fr: "IA Reçu", ar: "الذكاء الاصطناعي للإيصال", de: "Beleg-KI",
                    it: "IA Ricevuta", nl: "Bon-AI", ja: "レシートAI", ko: "영수증 AI"),
                title: transactionType == .expense
                    ? prof.text(en: "Scan and auto-fill", es: "Escanear y autocompletar",
                        pt: "Escanear e preencher", fr: "Scanner et remplir auto",
                        ar: "مسح وملء تلقائي", de: "Scannen und ausfüllen",
                        it: "Scansiona e compila", nl: "Scannen en invullen",
                        ja: "スキャンして自動入力", ko: "스캔 및 자동 입력")
                    : prof.text(en: "Receipt scan is optional for income", es: "El escaneo es opcional para ingresos",
                        pt: "Digitalização é opcional para receitas", fr: "Le scan est optionnel pour les revenus",
                        ar: "المسح الضوئي اختياري للدخل", de: "Scan ist optional für Einnahmen",
                        it: "La scansione è opzionale per le entrate", nl: "Scannen is optioneel voor inkomsten",
                        ja: "収入のスキャンはオプションです", ko: "수입에 대한 스캔은 선택 사항입니다")
            )

            if let selectedImageData, let image = UIImage(data: selectedImageData) {
                Button {
                    showImportOptions = true
                } label: {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 200)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(alignment: .topTrailing) {
                            if uploadedImageURL != nil {
                                Label(prof.text(en: "Uploaded", es: "Subido", pt: "Enviado", fr: "Téléchargé",
                                ar: "تم الرفع", de: "Hochgeladen", it: "Caricato", nl: "Geüpload",
                                ja: "アップロード済み", ko: "업로드됨"), systemImage: "checkmark.circle.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(BXPalette.textPrimary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(BXPalette.panelFillElevated, in: Capsule())
                                    .padding(10)
                            }
                        }
                        .overlay {
                            if isScanning {
                                BXScanningOverlay()
                            }
                        }
                }
                .buttonStyle(.plain)

                HStack(spacing: 10) {
                    Button {
                        showImportOptions = true
                    } label: {
                        Label(prof.text(en: "Replace", es: "Reemplazar", pt: "Substituir", fr: "Remplacer",
                            ar: "استبدال", de: "Ersetzen", it: "Sostituisci", nl: "Vervangen",
                            ja: "置き換え", ko: "교체"), systemImage: "arrow.triangle.2.circlepath")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(BXPalette.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(BXPalette.fieldFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                // Scan and import buttons directly below section title
                HStack(spacing: 10) {
                    Button {
                        showingDocumentScanner = true
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "doc.text.viewfinder")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(BXPalette.accentStart)
                            Text(prof.text(en: "Scan", es: "Escanear", pt: "Escanear", fr: "Scanner",
                                ar: "مسح", de: "Scannen", it: "Scansiona", nl: "Scannen",
                                ja: "スキャン", ko: "스캔"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BXPalette.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .background(BXPalette.fieldFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        showingPhotoLibrary = true
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(BXPalette.accentStart)
                            Text(prof.text(en: "Library", es: "Galería", pt: "Galeria", fr: "Galerie",
                                ar: "المكتبة", de: "Galerie", it: "Libreria", nl: "Bibliotheek",
                                ja: "ライブラリ", ko: "라이브러리"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BXPalette.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .background(BXPalette.fieldFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .disabled(isScanning || supabase.isLoading)
                .opacity(isScanning || supabase.isLoading ? 0.6 : 1)

                if isScanning {
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(BXPalette.accentStart)
                        Text(prof.text(en: "Analyzing receipt...", es: "Analizando recibo...", pt: "Analisando recibo...", fr: "Analyse du reçu...", ar: "جارٍ تحليل الإيصال...", de: "Beleg wird analysiert...", it: "Analisi ricevuta...", nl: "Bon wordt geanalyseerd...", ja: "レシートを分析中...", ko: "영수증 분석 중..."))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(BXPalette.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
            }
        }
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            BXSectionTitle(
                eyebrow: prof.text(en: "Details", es: "Detalles", pt: "Detalhes", fr: "Détails",
                    ar: "التفاصيل", de: "Details", it: "Dettagli", nl: "Details",
                    ja: "詳細", ko: "세부 정보"),
                title: prof.text(en: "Editable transaction fields", es: "Campos editables de la transacción",
                    pt: "Campos editáveis da transação", fr: "Champs de transaction modifiables",
                    ar: "حقول المعاملة القابلة للتعديل", de: "Bearbeitbare Transaktionsfelder",
                    it: "Campi transazione modificabili", nl: "Bewerkbare transactievelden",
                    ja: "編集可能なトランザクションフィールド", ko: "편집 가능한 거래 필드")
            )

            HStack {
                Text(statusMessage)
                    .font(.subheadline)
                    .foregroundStyle(BXPalette.textPrimary.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                if hasAttemptedOCR {
                    BXStatusPill(
                        title: uploadedImageURL == nil
                            ? prof.text(en: "Manual review", es: "Revisión manual", pt: "Revisão manual",
                                fr: "Révision manuelle", ar: "مراجعة يدوية", de: "Manuelle Prüfung",
                                it: "Revisione manuale", nl: "Handmatige controle",
                                ja: "手動レビュー", ko: "수동 검토")
                            : prof.text(en: "AI filled", es: "Completado por IA", pt: "Preenchido por IA",
                                fr: "Rempli par IA", ar: "مملوء بالذكاء الاصطناعي", de: "KI ausgefüllt",
                                it: "Compilato da IA", nl: "AI ingevuld",
                                ja: "AIが入力", ko: "AI 입력"),
                        color: uploadedImageURL == nil ? BXPalette.warning : BXPalette.income
                    )
                }
            }

            if let ocrSummaryText, !ocrSummaryText.isEmpty {
                Text(ocrSummaryText)
                    .font(.footnote)
                    .foregroundStyle(BXPalette.textSecondary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(BXPalette.fieldFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            BXField(
                title: transactionType == .income
                    ? prof.text(en: "Source", es: "Origen", pt: "Origem", fr: "Source", ar: "المصدر", de: "Quelle", it: "Fonte", nl: "Bron", ja: "入金元", ko: "출처")
                    : prof.text(en: "Vendor", es: "Comercio", pt: "Fornecedor", fr: "Fournisseur", ar: "البائع", de: "Anbieter", it: "Fornitore", nl: "Leverancier", ja: "店舗", ko: "판매처"),
                text: $vendor,
                keyboardType: .default
            )
            BXField(title: prof.text(en: "Amount", es: "Monto", pt: "Valor", fr: "Montant", ar: "المبلغ", de: "Betrag", it: "Importo", nl: "Bedrag", ja: "金額", ko: "금액"), text: $amount, keyboardType: .decimalPad)
            BXField(title: prof.text(en: "Category", es: "Categoría", pt: "Categoria", fr: "Catégorie", ar: "الفئة", de: "Kategorie", it: "Categoria", nl: "Categorie", ja: "カテゴリ", ko: "카테고리"), text: $category, keyboardType: .default)

            VStack(alignment: .leading, spacing: 6) {
                Text(prof.text(en: "Date", es: "Fecha", pt: "Data", fr: "Date", ar: "التاريخ", de: "Datum", it: "Data", nl: "Datum", ja: "日付", ko: "날짜"))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(BXPalette.textPrimary.opacity(0.70))
                DatePicker("", selection: $date, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.graphical)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(BXPalette.fieldFill)
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.08), lineWidth: 0.5))
                    )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(prof.text(en: "Notes", es: "Notas", pt: "Notas", fr: "Notes", ar: "ملاحظات", de: "Notizen", it: "Note", nl: "Notities", ja: "メモ", ko: "메모"))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(BXPalette.textPrimary.opacity(0.70))
                TextField(prof.text(en: "Optional context", es: "Contexto opcional", pt: "Contexto opcional", fr: "Contexte facultatif", ar: "سياق اختياري", de: "Optionaler Kontext", it: "Contesto facoltativo", nl: "Optionele context", ja: "任意の補足情報", ko: "선택적 메모"), text: $notes, axis: .vertical)
                    .lineLimit(3...5)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .foregroundStyle(BXPalette.textPrimary)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(BXPalette.fieldFill)
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.08), lineWidth: 0.5))
                    )
            }
        }
        .padding(20)
        .bxGlassCard(cornerRadius: 24)
    }

    private var canSave: Bool {
        !amount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Decimal(string: amount.replacingOccurrences(of: ",", with: ".")) != nil
    }

    private var saveButton: some View {
        Button {
            Task { await saveTransaction() }
        } label: {
            HStack(spacing: 10) {
                if supabase.isLoading {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.bold))
                    Text(initialTransaction == nil
                        ? prof.text(en: "Save Transaction", es: "Guardar movimiento", pt: "Salvar transação", fr: "Enregistrer l'opération", ar: "حفظ المعاملة", de: "Transaktion speichern", it: "Salva transazione", nl: "Transactie opslaan", ja: "取引を保存", ko: "거래 저장")
                        : prof.text(en: "Update Transaction", es: "Actualizar movimiento", pt: "Atualizar transação", fr: "Mettre à jour l'opération", ar: "تحديث المعاملة", de: "Transaktion aktualisieren", it: "Aggiorna transazione", nl: "Transactie bijwerken", ja: "取引を更新", ko: "거래 업데이트"))
                        .font(.headline.weight(.semibold))
                }
            }
            .foregroundStyle(canSave ? Color.black : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                canSave ? LinearGradient(colors: [.white, .white], startPoint: .leading, endPoint: .trailing) : LinearGradient(colors: [BXPalette.fieldFill, BXPalette.fieldFill], startPoint: .leading, endPoint: .trailing),
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .shadow(color: canSave ? Color.white.opacity(0.15) : .clear, radius: 10, y: 5)
        }
        .buttonStyle(.plain)
        .disabled(!canSave || supabase.isLoading || isScanning)
        .opacity(!canSave ? 0.45 : 1)
        .animation(.easeInOut(duration: 0.2), value: canSave)
    }

    private var incomeGoalCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "target")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BXPalette.income)
                Text(prof.text(en: "Apply to a goal", es: "Abonar a una meta", pt: "Aplicar a uma meta", fr: "Appliquer à un objectif", ar: "تطبيق على هدف", de: "Auf ein Ziel anwenden", it: "Applica a un obiettivo", nl: "Toepassen op een doel", ja: "目標に充当", ko: "목표에 반영"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BXPalette.textPrimary)
                Spacer()
                Toggle("", isOn: $saveToGoal)
                    .labelsHidden()
                    .tint(BXPalette.income)
            }

            if saveToGoal {
                VStack(alignment: .leading, spacing: 10) {
                    // Goal picker
                    Picker(prof.text(en: "Goal", es: "Meta", pt: "Meta", fr: "Objectif", ar: "الهدف", de: "Ziel", it: "Obiettivo", nl: "Doel", ja: "目標", ko: "목표"), selection: $selectedGoalID) {
                        Text(prof.text(en: "Select goal", es: "Seleccionar meta", pt: "Selecionar meta", fr: "Sélectionner un objectif", ar: "اختر هدفًا", de: "Ziel auswählen", it: "Seleziona obiettivo", nl: "Doel selecteren", ja: "目標を選択", ko: "목표 선택")).tag(UUID?.none)
                        ForEach(supabase.savingsGoals) { goal in
                            Text(goal.name).tag(Optional(goal.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(BXPalette.accentStart)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(BXPalette.fieldFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    // Show goal progress if selected
                    if let goalID = selectedGoalID,
                       let goal = supabase.savingsGoals.first(where: { $0.id == goalID }) {
                        let progress = goal.targetAmount > .zero
                            ? min(1.0, (goal.savedAmount as NSDecimalNumber).doubleValue / (goal.targetAmount as NSDecimalNumber).doubleValue)
                            : 0.0
                        HStack(spacing: 10) {
                            GeometryReader { proxy in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .fill(BXPalette.fieldFill).frame(height: 5)
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .fill(BXPalette.income)
                                        .frame(width: proxy.size.width * progress, height: 5)
                                }
                            }
                            .frame(height: 5)
                            Text("\(goal.savedAmount.smartCurrencyString(code: supabase.onboardingProfile.currencyCode)) / \(goal.targetAmount.smartCurrencyString(code: supabase.onboardingProfile.currencyCode))")
                                .font(.caption2)
                                .foregroundStyle(BXPalette.textSecondary)
                                .fixedSize()
                        }
                    }

                    // Contribution amount
                    BXField(title: prof.text(en: "Contribution amount", es: "Monto a abonar", pt: "Valor a contribuir", fr: "Montant à contribuer", ar: "مبلغ المساهمة", de: "Beitragsbetrag", it: "Importo del contributo", nl: "Bijdragebedrag", ja: "積立金額", ko: "기여 금액"), text: $goalContribution, keyboardType: .decimalPad)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(18)
        .background(BXPalette.panelFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(BXPalette.income.opacity(saveToGoal ? 0.35 : 0.15), lineWidth: 1)
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: saveToGoal)
        .onChange(of: transactionType) { _, type in
            if type != .income { saveToGoal = false }
        }
    }

    private var categoryPickerSheet: some View {
        NavigationStack {
            ZStack {
                BXBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {

                        // Custom / recently added categories
                        if !customCategories.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(prof.text(en: "Saved",    es: "Guardadas", pt: "Salvas",   fr: "Enregistrées",
                                       ar: "المحفوظة", de: "Gespeichert", it: "Salvate", nl: "Opgeslagen",
                                       ja: "保存済み",   ko: "저장됨"))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(BXPalette.textTertiary)
                                    .padding(.horizontal, 20)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(customCategories, id: \.self) { custom in
                                            Button {
                                                withAnimation { category = custom }
                                                showCategoryPicker = false
                                            } label: {
                                                Text(custom)
                                                    .font(.caption.weight(.semibold))
                                                    .foregroundStyle(category == custom ? (transactionType == .expense ? BXPalette.expense : BXPalette.income) : BXPalette.textPrimary)
                                                    .padding(.horizontal, 14)
                                                    .padding(.vertical, 8)
                                                    .background(
                                                        category == custom
                                                        ? (transactionType == .expense ? BXPalette.expense.opacity(0.15) : BXPalette.income.opacity(0.15))
                                                        : BXPalette.fieldFill,
                                                        in: Capsule()
                                                    )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                        }

                        // All built-in categories grid
                        Text(prof.text(en: "All categories",     es: "Todas las categorías",
                                       pt: "Todas as categorias", fr: "Toutes les catégories",
                                       ar: "جميع الفئات",         de: "Alle Kategorien",
                                       it: "Tutte le categorie",  nl: "Alle categorieën",
                                       ja: "すべてのカテゴリ",      ko: "모든 카테고리"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(BXPalette.textTertiary)
                            .padding(.horizontal, 20)

                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
                            spacing: 8
                        ) {
                            ForEach(categoryOptions, id: \.key) { def in
                                let label = categoryLabel(def)
                                let isSelected = category == label || category == def.en || category == def.es
                                let activeColor = transactionType == .expense ? BXPalette.expense : BXPalette.income
                                Button {
                                    withAnimation { category = label }
                                    showCategoryPicker = false
                                } label: {
                                    VStack(spacing: 5) {
                                        Image(systemName: def.icon)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(isSelected ? activeColor : BXPalette.textSecondary)
                                        Text(label)
                                            .font(.system(size: 9, weight: .semibold))
                                            .foregroundStyle(isSelected ? BXPalette.textPrimary : BXPalette.textTertiary)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.7)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        isSelected ? activeColor.opacity(0.15) : BXPalette.fieldFill,
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(isSelected ? activeColor.opacity(0.4) : Color.clear, lineWidth: 0.5)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle(prof.text(en: "Category",  es: "Categoría",
                                        pt: "Categoria", fr: "Catégorie",
                                        ar: "الفئة",     de: "Kategorie",
                                        it: "Categoria", nl: "Categorie",
                                        ja: "カテゴリ",   ko: "카테고리"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(prof.text(en: "Done",   es: "Listo",  pt: "Pronto", fr: "Terminé",
                                    ar: "تم",      de: "Fertig", it: "Fine",   nl: "Klaar",
                                    ja: "完了",     ko: "완료")) {
                        showCategoryPicker = false
                    }
                    .foregroundStyle(BXPalette.textPrimary)
                }
            }
        }
    }

    private var statusMessage: String {
        if transactionType == .income {
            return prof.text(
                en: "Income entries are saved directly and reflected in reports immediately.",
                es: "Los ingresos se guardan directamente y se reflejan en los reportes.",
                pt: "As receitas são salvas diretamente e refletidas nos relatórios imediatamente.",
                fr: "Les revenus sont enregistrés directement et reflétés dans les rapports immédiatement.",
                ar: "يتم حفظ إدخالات الدخل مباشرة وتظهر في التقارير فورًا.",
                de: "Einnahmen werden direkt gespeichert und sofort in Berichten angezeigt.",
                it: "Le voci di reddito vengono salvate direttamente e riflesse immediatamente nei report.",
                nl: "Inkomsten worden direct opgeslagen en onmiddellijk weergegeven in rapporten.",
                ja: "収入エントリはすぐに保存され、レポートに反映されます。",
                ko: "수입 항목은 직접 저장되어 즉시 보고서에 반영됩니다."
            )
        }
        if isScanning {
            return prof.text(
                en: "Uploading the receipt and extracting vendor, amount, and date automatically.",
                es: "Subiendo el recibo y extrayendo comercio, monto y fecha automáticamente.",
                pt: "Enviando o recibo e extraindo fornecedor, valor e data automaticamente.",
                fr: "Téléchargement du reçu et extraction du commerçant, montant et date automatiquement.",
                ar: "جارٍ رفع الإيصال واستخراج المورد والمبلغ والتاريخ تلقائيًا.",
                de: "Beleg wird hochgeladen und Händler, Betrag und Datum werden automatisch extrahiert.",
                it: "Caricamento della ricevuta ed estrazione automatica di fornitore, importo e data.",
                nl: "Ontvangstbewijs uploaden en automatisch leverancier, bedrag en datum extraheren.",
                ja: "レシートをアップロードし、店舗名、金額、日付を自動的に抽出しています。",
                ko: "영수증을 업로드하고 공급업체, 금액, 날짜를 자동으로 추출하고 있습니다."
            )
        }
        if hasAttemptedOCR {
            return prof.text(
                en: "The form was filled automatically. Review the result and save when it looks right.",
                es: "El formulario fue llenado automáticamente. Revisa el resultado y guarda cuando esté bien.",
                pt: "O formulário foi preenchido automaticamente. Revise o resultado e salve quando estiver correto.",
                fr: "Le formulaire a été rempli automatiquement. Vérifiez le résultat et enregistrez quand c'est bon.",
                ar: "تم ملء النموذج تلقائيًا. راجع النتيجة واحفظ عندما تبدو صحيحة.",
                de: "Das Formular wurde automatisch ausgefüllt. Überprüfe das Ergebnis und speichere, wenn es stimmt.",
                it: "Il modulo è stato compilato automaticamente. Rivedi il risultato e salva quando sembra corretto.",
                nl: "Het formulier is automatisch ingevuld. Controleer het resultaat en sla op als het er goed uitziet.",
                ja: "フォームが自動的に入力されました。結果を確認して、正しい場合は保存してください。",
                ko: "양식이 자동으로 채워졌습니다. 결과를 검토하고 올바르면 저장하세요."
            )
        }
        return prof.text(
            en: "Scan the receipt or import one from your library. Analysis starts automatically.",
            es: "Escanea el recibo o importa uno de tu galería. El análisis inicia automáticamente.",
            pt: "Escaneie o recibo ou importe um da sua galeria. A análise começa automaticamente.",
            fr: "Scannez le reçu ou importez-en un depuis votre galerie. L'analyse démarre automatiquement.",
            ar: "امسح الإيصال أو استورد واحدًا من مكتبتك. يبدأ التحليل تلقائيًا.",
            de: "Scanne den Beleg oder importiere einen aus deiner Galerie. Die Analyse startet automatisch.",
            it: "Scansiona la ricevuta o importane una dalla tua libreria. L'analisi inizia automaticamente.",
            nl: "Scan het bonnetje of importeer er een uit je bibliotheek. Analyse start automatisch.",
            ja: "レシートをスキャンするかライブラリからインポートしてください。分析が自動的に開始されます。",
            ko: "영수증을 스캔하거나 라이브러리에서 가져오세요. 분석이 자동으로 시작됩니다."
        )
    }

    private func uploadAndAnalyzeReceipt() async {
        guard let selectedImageData else { return }

        isScanning = true
        hasAttemptedOCR = true
        defer { isScanning = false }

        do {
            let preparedImageData = ReceiptImageProcessor.enhanceForOCR(imageData: selectedImageData) ?? selectedImageData
            let imageURL = try await supabase.uploadReceiptImageForOCR(imageData: preparedImageData, fileExtension: "jpg")
            uploadedImageURL = imageURL
            let localResult = try? await ReceiptVisionAnalyzer.analyzeDetailed(imageData: preparedImageData)

            do {
                let cloudResult = try await supabase.scanReceipt(imageURL: imageURL)
                let mergedResult = mergedOCRResult(cloudResult: cloudResult, localResult: localResult)
                await applyOCRResult(
                    mergedResult.response,
                    sourceLabel: "Cloud OCR",
                    sourceCurrencyCode: mergedResult.currencyCode,
                    rawTextOverride: mergedResult.rawText,
                    documentType: mergedResult.documentType,
                    suggestedCategory: mergedResult.suggestedCategory,
                    suggestedTransactionType: mergedResult.suggestedTransactionType
                )
            } catch {
                guard let fallbackResult = localResult else { throw error }
                await applyOCRResult(
                    fallbackResult.response,
                    sourceLabel: "On-device OCR",
                    sourceCurrencyCode: fallbackResult.currencyCode,
                    rawTextOverride: fallbackResult.rawText,
                    documentType: fallbackResult.documentType,
                    suggestedCategory: fallbackResult.suggestedCategory,
                    suggestedTransactionType: fallbackResult.suggestedTransactionType
                )
            }

            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } catch {
            supabase.errorMessage = error.localizedDescription
        }
    }

    private func applyOCRResult(
        _ result: OCRReceiptResponse,
        sourceLabel: String,
        sourceCurrencyCode: String?,
        rawTextOverride: String? = nil,
        documentType: OCRDocumentType = .unknown,
        suggestedCategory: String? = nil,
        suggestedTransactionType: TransactionType? = nil
    ) async {
        if !result.vendor.isEmpty {
            vendor = result.vendor
        }
        ocrVendorGuess = result.vendor
        if result.amount > 0, let decimalAmount = Decimal(string: String(result.amount)) {
            let normalized = await ExchangeRateService.shared.convert(
                amount: decimalAmount,
                from: sourceCurrencyCode,
                to: supabase.onboardingProfile.currencyCode
            )
            amount = NSDecimalNumber(decimal: normalized.amount).stringValue
            detectedSourceCurrencyCode = normalized.sourceCurrencyCode
        }
        detectedDocumentType = documentType
        if prof.isUncategorizedCategory(category), let suggestedCategory, !suggestedCategory.isEmpty {
            category = suggestedCategory
        }
        if let suggestedTransactionType {
            transactionType = suggestedTransactionType
        }
        if
            documentType == .transfer,
            let companyName = supabase.currentCompany?.name.lowercased(),
            let rawTextOverride,
            !companyName.isEmpty,
            rawTextOverride.lowercased().contains(companyName)
        {
            transactionType = .income
        }

        if let learned = ReceiptLearningStore.shared.learnedCorrection(rawText: rawTextOverride, vendorGuess: result.vendor) {
            vendor = learned.correctedVendor
            category = learned.correctedCategory
            transactionType = learned.correctedTransactionType
        }

        let sourceNote: String
        if let sourceCurrencyCode, sourceCurrencyCode != supabase.onboardingProfile.currencyCode {
            sourceNote = " • \(sourceCurrencyCode) -> \(supabase.onboardingProfile.currencyCode)"
        } else {
            sourceNote = ""
        }
        let documentNote = documentType == .unknown ? "" : " • \(documentType.rawValue.capitalized)"
        rawOCRText = rawTextOverride
        let captureNote = captureSource.map { " • \($0.label)" } ?? ""
        ocrSummaryText = "\(sourceLabel): \(result.vendor) • \(String(format: "%.2f", result.amount)) • \(result.date)\(sourceNote)\(documentNote)\(captureNote)"

        let formatter = ISO8601DateFormatter()
        if let parsedDate = formatter.date(from: result.date) {
            date = parsedDate
        } else if let shortDate = DateFormatter.receiptServiceDate.date(from: result.date) {
            date = shortDate
        }
    }

    private func mergedOCRResult(cloudResult: OCRReceiptResponse, localResult: OCRVisionScanResult?) -> OCRVisionScanResult {
        guard let localResult else {
            return OCRVisionScanResult(
                response: cloudResult,
                rawText: "Cloud OCR: \(cloudResult.vendor) • \(String(format: "%.2f", cloudResult.amount)) • \(cloudResult.date)",
                currencyCode: nil,
                documentType: .unknown,
                suggestedCategory: nil,
                suggestedTransactionType: nil
            )
        }

        let resolvedVendor = betterVendor(cloudResult.vendor, fallback: localResult.response.vendor)
        let resolvedAmount = betterAmount(cloudResult.amount, fallback: localResult.response.amount)
        let resolvedDate = cloudResult.date.isEmpty ? localResult.response.date : cloudResult.date

        return OCRVisionScanResult(
            response: OCRReceiptResponse(
                vendor: resolvedVendor,
                amount: resolvedAmount,
                date: resolvedDate
            ),
            rawText: localResult.rawText,
            currencyCode: localResult.currencyCode,
            documentType: localResult.documentType,
            suggestedCategory: localResult.suggestedCategory,
            suggestedTransactionType: localResult.suggestedTransactionType
        )
    }

    private func betterVendor(_ primary: String, fallback: String) -> String {
        let invalidValues = ["receipt", "recibo", "unknown", ""]
        let normalizedPrimary = primary.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if invalidValues.contains(normalizedPrimary) || primary.count < 3 {
            return fallback
        }
        if fallback.count > primary.count + 6 {
            return fallback
        }
        return primary
    }

    private func betterAmount(_ primary: Double, fallback: Double) -> Double {
        if primary <= 0 { return fallback }
        if fallback <= 0 { return primary }
        return max(primary, fallback)
    }

    private func resetScanStateAfterNewImage() {
        uploadedImageURL = nil
        hasAttemptedOCR = false
        rawOCRText = nil
        ocrSummaryText = nil
        ocrVendorGuess = nil
        detectedSourceCurrencyCode = nil
        detectedDocumentType = .unknown
    }

    private func setSelectedImage(_ data: Data?, source: ReceiptCaptureSource) {
        selectedImageData = data
        captureSource = data == nil ? nil : source
        resetScanStateAfterNewImage()

        guard data != nil, transactionType == .expense else { return }

        Task {
            await uploadAndAnalyzeReceipt()
        }
    }

    private func storedReceiptMetadata() -> String? {
        guard rawOCRText != nil || captureSource != nil else { return nil }

        let sourceValue = captureSource?.label ?? "unknown"
        let currencyValue = detectedSourceCurrencyCode ?? "unknown"
        let documentValue = detectedDocumentType.rawValue
        let body = rawOCRText ?? ""
        return "[capture_source:\(sourceValue)][currency:\(currencyValue)][document:\(documentValue)]\n\(body)"
    }

    private func saveTransaction() async {
        guard let decimalAmount = Decimal(string: amount.replacingOccurrences(of: ",", with: ".")) else {
            supabase.errorMessage = prof.text(en: "Enter a valid amount.",   es: "Ingresa un monto válido.",
                                               pt: "Insira um valor válido.", fr: "Entrez un montant valide.",
                                               ar: "أدخل مبلغاً صحيحاً.",    de: "Geben Sie einen gültigen Betrag ein.",
                                               it: "Inserisci un importo valido.", nl: "Voer een geldig bedrag in.",
                                               ja: "有効な金額を入力してください。", ko: "유효한 금액을 입력하세요.")
            return
        }
        // Auto-fill vendor from category when not provided
        if vendor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            vendor = category.isEmpty
                ? prof.text(en: "Unspecified", es: "Sin especificar", pt: "Não especificado",
                            fr: "Non spécifié", ar: "غير محدد",        de: "Nicht angegeben",
                            it: "Non specificato", nl: "Niet opgegeven", ja: "未指定", ko: "미지정")
                : category
        }

        let notesValue = notes.isEmpty ? nil : notes
        let success: Bool

        if let initialTransaction {
            var imageURL = uploadedImageURL

            if imageURL == nil, let selectedImageData {
                do {
                    imageURL = try await supabase.uploadReceiptImageForOCR(imageData: selectedImageData, fileExtension: "jpg")
                    uploadedImageURL = imageURL
                } catch {
                    supabase.errorMessage = error.localizedDescription
                    return
                }
            }

            success = await supabase.updateTransaction(
                initialTransaction,
                type: transactionType,
                vendor: vendor,
                amount: decimalAmount,
                category: category,
                date: date,
                notes: notesValue,
                imageURL: imageURL,
                rawText: storedReceiptMetadata()
            )
        } else {
            var imageURL = uploadedImageURL

            if transactionType == .expense, imageURL == nil, let selectedImageData {
                do {
                    imageURL = try await supabase.uploadReceiptImageForOCR(imageData: selectedImageData, fileExtension: "jpg")
                    uploadedImageURL = imageURL
                } catch {
                    supabase.errorMessage = error.localizedDescription
                    return
                }
            }

            success = await supabase.createTransaction(
                type: transactionType,
                vendor: vendor,
                amount: decimalAmount,
                category: category,
                date: date,
                notes: notesValue,
                imageURL: imageURL,
                rawText: storedReceiptMetadata()
            )
        }

        if success {
            // Persist custom category if the user typed one not in the built-in list
            saveCustomCategoryIfNeeded()

            if hasAttemptedOCR {
                ReceiptLearningStore.shared.saveCorrection(
                    rawText: rawOCRText,
                    vendorGuess: ocrVendorGuess,
                    correctedVendor: vendor,
                    correctedCategory: category,
                    correctedTransactionType: transactionType
                )
            }
            // Deposit to savings goal if user opted in
            if transactionType == .income,
               saveToGoal,
               let goalID = selectedGoalID,
               let goal = supabase.savingsGoals.first(where: { $0.id == goalID }),
               let contribution = Decimal(string: goalContribution.replacingOccurrences(of: ",", with: ".")),
               contribution > 0 {
                supabase.depositToSavingsGoal(goal, amount: contribution)
            }
            // Check if this expense pushed any budget over the limit
            if transactionType == .expense,
               let overBudget = supabase.overBudgetAlerts(for: category) {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                budgetAlert = overBudget
                return  // alert will call dismiss() when dismissed
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        }
    }
}

struct BXField: View {
    let title: String
    @Binding var text: String
    let keyboardType: UIKeyboardType

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(BXPalette.textPrimary.opacity(0.70))
            TextField(title, text: $text)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(.words)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .foregroundStyle(BXPalette.textPrimary)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(BXPalette.fieldFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(.white.opacity(text.isEmpty ? 0.06 : 0.14), lineWidth: 0.5)
                        )
                )
        }
    }
}

#if canImport(VisionKit)
private struct BXDocumentScanner: UIViewControllerRepresentable {
    let onScan: (Data?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onScan: (Data?) -> Void

        init(onScan: @escaping (Data?) -> Void) {
            self.onScan = onScan
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            controller.dismiss(animated: true)
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            let image = scan.imageOfPage(at: 0)
            onScan(image.jpegData(compressionQuality: 0.92))
            controller.dismiss(animated: true)
        }
    }
}
#endif

// BXScanningOverlay is defined in DesignSystem.swift

private enum ReceiptImageProcessor {
    static func enhanceForOCR(imageData: Data) -> Data? {
        guard let uiImage = UIImage(data: imageData),
              let inputImage = CIImage(data: imageData)
        else {
            return nil
        }

        let context = CIContext(options: nil)
        let controls = CIFilter.colorControls()
        controls.inputImage = inputImage
        controls.contrast = 1.25
        controls.brightness = 0.02
        controls.saturation = 0

        let sharpen = CIFilter.sharpenLuminance()
        sharpen.inputImage = controls.outputImage
        sharpen.sharpness = 0.45

        guard let outputImage = sharpen.outputImage,
              let cgImage = context.createCGImage(outputImage, from: outputImage.extent)
        else {
            return nil
        }

        return UIImage(cgImage: cgImage, scale: uiImage.scale, orientation: .up)
            .jpegData(compressionQuality: 0.92)
    }
}
#endif
