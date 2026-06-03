import AuthenticationServices
import Combine
import CryptoKit
import Foundation
import SwiftUI
import UserNotifications
import WidgetKit
#if canImport(Supabase)
import Supabase
#endif

@MainActor
final class SupabaseManager: ObservableObject {
    private let developmentAdminEmail = "admin@gmail.com"
    private let developmentAdminPassword = "admin123"
    private let localCompanyID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private let localUserID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    private let localAccountsKey = "local_sandbox_accounts"
    private let currentLocalAccountEmailKey = "current_local_account_email"
    private let onboardingProfileKey = "bx_onboarding_profile"
    private let subscriptionsKey = "bx_subscriptions"
    private let budgetsKey = "bx_budgets"
    private let monthlyBudgetCategoryPrefix = "__monthly_budget__"
    private let savingsGoalsKey = "bx_savings_goals"
    private let customCategoriesKey = "bx_custom_categories_v2"
    private let teamInvitationsKey = "bx_team_invitations"
    private let reconciliationStatusesKey = "bx_reconciliation_statuses"
    private let transactionAuditKey = "bx_transaction_audit"
    private let recurringTransactionKeysKey = "bx_recurring_transaction_keys"
    private let isPremiumKey = "bx_is_premium"
    private let biometricLockKey = "bx_biometric_lock"
    private let localAdminCompanyNameKey = "bx_local_admin_company_name"
    private let selectedCompanyIDKey = "bx_selected_company_id"
    private let supabaseTransactionsCacheKey = "bx_supabase_txns_cache"
    private let supabaseReceiptsCacheKey = "bx_supabase_receipts_cache"
    private let supabaseCompaniesCacheKey = "bx_supabase_companies_cache"
    private let netWorthAccountsKey = "bx_net_worth_accounts"
    private let deviceTokenKey = "bx_apns_device_token"
    private let emailMonthlyReportKey = "bx_email_monthly_report"
    private let emailExpenseAlertKey = "bx_email_expense_alert"
    private let emailExpenseThresholdKey = "bx_email_expense_threshold"

    @Published private(set) var authState: AuthState = .loading
    @Published private(set) var currentCompany: Company?
    @Published private(set) var availableCompanies: [Company] = []
    @Published private(set) var transactions: [AccountingTransaction] = []
    @Published private(set) var receiptsByTransactionID: [UUID: Receipt] = [:]
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published private(set) var isUsingLocalAdminMode = false
    @Published private(set) var currentLocalAccountEmail: String?
    @Published var onboardingProfile = OnboardingProfile.default
    @Published private(set) var subscriptions: [SubscriptionItem] = []
    @Published private(set) var budgets: [BudgetItem] = []
    @Published private(set) var savingsGoals: [SavingsGoal] = []
    @Published private(set) var customCategories: [CustomCategory] = []
    @Published private(set) var teamInvitations: [TeamInvitation] = []
    @Published private(set) var reconciliationStatuses: [UUID: ReconciliationStatus] = [:]
    @Published private(set) var transactionAuditEntries: [TransactionAuditEntry] = []
    @Published var isPremium = false
    @Published var biometricLockEnabled = false
    @Published var notificationsEnabled = true
    @Published private(set) var isOffline = false
    @Published private(set) var analytics = BXAnalyticsCache()
    @Published private(set) var netWorthAccounts: [NetWorthAccount] = []
    @Published private(set) var deviceToken: String?
    @Published var emailMonthlyReportEnabled = false
    @Published var emailExpenseAlertEnabled = false
    @Published var emailExpenseAlertThreshold: Double = 1000.0

    private var cancellables = Set<AnyCancellable>()

    var configurationStatusMessage: String? {
        #if canImport(Supabase)
        if receiptService == nil {
            return "Supabase is linked. OCR backend is still not configured."
        }
        return nil
        #else
        return "The app target does not have supabase-swift linked yet. Add the package in Xcode to enable real auth, storage, and database access."
        #endif
    }

    #if canImport(Supabase)
    private let client: SupabaseClient
    #endif

    private let receiptService: ReceiptService?
    private let defaults = UserDefaults.standard
    private var webAuthSession: ASWebAuthenticationSession?
    private let webAuthContext = BXWebAuthContext()
    private var pendingAppleNonce: String = ""
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    init() {
        if
            let data = defaults.data(forKey: onboardingProfileKey),
            let profile = try? decoder.decode(OnboardingProfile.self, from: data)
        {
            self.onboardingProfile = profile
        }
        if
            let data = defaults.data(forKey: subscriptionsKey),
            let subscriptions = try? decoder.decode([SubscriptionItem].self, from: data)
        {
            self.subscriptions = subscriptions
        }
        if
            let data = defaults.data(forKey: budgetsKey),
            let budgets = try? decoder.decode([BudgetItem].self, from: data)
        {
            self.budgets = budgets
        }
        if
            let data = defaults.data(forKey: savingsGoalsKey),
            let goals = try? decoder.decode([SavingsGoal].self, from: data)
        {
            self.savingsGoals = goals
        }
        if
            let data = defaults.data(forKey: customCategoriesKey),
            let categories = try? decoder.decode([CustomCategory].self, from: data)
        {
            self.customCategories = categories
        }
        if
            let data = defaults.data(forKey: teamInvitationsKey),
            let invitations = try? decoder.decode([TeamInvitation].self, from: data)
        {
            self.teamInvitations = invitations
        }
        if
            let data = defaults.data(forKey: reconciliationStatusesKey),
            let statuses = try? decoder.decode([UUID: ReconciliationStatus].self, from: data)
        {
            self.reconciliationStatuses = statuses
        }
        if
            let data = defaults.data(forKey: transactionAuditKey),
            let entries = try? decoder.decode([TransactionAuditEntry].self, from: data)
        {
            self.transactionAuditEntries = entries
        }
        if let data = defaults.data(forKey: netWorthAccountsKey),
           let accounts = try? decoder.decode([NetWorthAccount].self, from: data) {
            self.netWorthAccounts = accounts
        }
        self.deviceToken = defaults.string(forKey: deviceTokenKey)
        self.emailMonthlyReportEnabled = defaults.bool(forKey: emailMonthlyReportKey)
        self.emailExpenseAlertEnabled = defaults.bool(forKey: emailExpenseAlertKey)
        let savedThreshold = defaults.double(forKey: emailExpenseThresholdKey)
        self.emailExpenseAlertThreshold = savedThreshold > 0 ? savedThreshold : 1000.0
        self.isPremium = defaults.bool(forKey: isPremiumKey)
        self.biometricLockEnabled = defaults.bool(forKey: biometricLockKey)
        if defaults.object(forKey: "bx_notifications_enabled") != nil {
            self.notificationsEnabled = defaults.bool(forKey: "bx_notifications_enabled")
        }
        self.receiptService = ReceiptService.makeIfConfigured()
        #if canImport(Supabase)
        let configuration = SupabaseConfiguration.load()
        self.client = SupabaseClient(
            supabaseURL: configuration.url,
            supabaseKey: configuration.publishableKey
        )
        #endif
        // All stored properties initialized — now safe to call methods
        self.syncFromiCloud()
        // Schedule notifications after all members are initialized
        Task { @MainActor [weak self] in self?.scheduleLocalNotifications() }
        Task { @MainActor [weak self] in self?.registerForPushNotifications() }

        // Recompute expensive analytics on a background thread whenever data changes.
        // Debounce so rapid transaction edits don't spawn redundant tasks.
        Publishers.CombineLatest($transactions, $budgets)
            .combineLatest($savingsGoals)
            .combineLatest($onboardingProfile)
            .combineLatest($notificationsEnabled)
            .debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.recomputeAnalytics()
            }
            .store(in: &cancellables)
    }

    func bootstrap() async {
        #if canImport(Supabase)
        isLoading = true
        defer { isLoading = false }

        do {
            let session = try await client.auth.session
            authState = .signedIn
            try await ensureDefaultCompanyExists(for: session.user.id)
            await refreshDashboard()
        } catch {
            if defaults.bool(forKey: "local_admin_enabled") {
                loadLocalAdminSession()
            } else if let email = defaults.string(forKey: currentLocalAccountEmailKey),
                      let account = localSandboxAccounts()[email] {
                loadLocalSandboxAccount(account)
            } else {
                authState = .signedOut
            }
        }
        #else
        if defaults.bool(forKey: "local_admin_enabled") {
            loadLocalAdminSession()
        } else if let email = defaults.string(forKey: currentLocalAccountEmailKey),
                  let account = localSandboxAccounts()[email] {
            loadLocalSandboxAccount(account)
        } else {
            authState = .signedOut
        }
        #endif
    }

    func signUp(email: String, password: String) async {
        if email == developmentAdminEmail, password == developmentAdminPassword {
            enableLocalAdminMode()
            return
        }

        #if canImport(Supabase)
        await runLoadingTask {
            let response = try await client.auth.signUp(email: email, password: password)
            isUsingLocalAdminMode = false
            currentLocalAccountEmail = nil
            defaults.removeObject(forKey: currentLocalAccountEmailKey)
            authState = .signedIn
            try? await ensureDefaultCompanyExists(for: response.user.id)
            await refreshDashboard()
            await triggerEmail(type: "welcome", to: email, name: onboardingProfile.personName)
        }
        #else
        let account = createOrLoadLocalSandboxAccount(email: email, password: password)
        loadLocalSandboxAccount(account)
        errorMessage = onboardingProfile.text(
            en: "Account created in local sandbox mode. You can use the app immediately on this device.",
            es: "Cuenta creada en modo local sandbox. Podrás usar la app inmediatamente en este dispositivo.",
            pt: "Conta criada no modo sandbox local. Você pode usar o app imediatamente neste dispositivo.",
            fr: "Compte créé en mode sandbox local. Vous pouvez utiliser l’app immédiatement sur cet appareil.",
            ar: "تم إنشاء الحساب في وضع الحماية المحلي. يمكنك استخدام التطبيق فورًا على هذا الجهاز.",
            de: "Konto im lokalen Sandbox-Modus erstellt. Du kannst die App sofort auf diesem Gerät verwenden.",
            it: "Account creato in modalità sandbox locale. Puoi usare l’app subito su questo dispositivo.",
            nl: "Account aangemaakt in lokale sandboxmodus. Je kunt de app direct op dit apparaat gebruiken.",
            ja: "ローカルサンドボックスモードでアカウントを作成しました。このデバイスですぐにアプリを使えます。",
            ko: "로컬 샌드박스 모드에서 계정이 생성되었습니다. 이 기기에서 바로 앱을 사용할 수 있습니다."
        )
        #endif
    }

    func resetPassword(email: String) async {
        #if canImport(Supabase)
        await runLoadingTask {
            try await client.auth.resetPasswordForEmail(email)
        }
        #else
        errorMessage = onboardingProfile.text(
            en: "Password recovery is only available with a live Supabase connection.",
            es: "La recuperación de contraseña solo está disponible con una conexión activa a Supabase.",
            pt: "A recuperação de senha só está disponível com uma conexão ativa ao Supabase.",
            fr: "La récupération du mot de passe n’est disponible qu’avec une connexion Supabase active.",
            ar: "استعادة كلمة المرور متاحة فقط مع اتصال Supabase نشط.",
            de: "Die Passwortwiederherstellung ist nur mit einer aktiven Supabase-Verbindung verfügbar.",
            it: "Il recupero della password è disponibile solo con una connessione Supabase attiva.",
            nl: "Wachtwoordherstel is alleen beschikbaar met een actieve Supabase-verbinding.",
            ja: "パスワード回復は、有効なSupabase接続がある場合のみ利用可能です。",
            ko: "비밀번호 복구는 활성 Supabase 연결이 있을 때만 사용할 수 있습니다."
        )
        #endif
    }

    func signIn(email: String, password: String) async {
        if email == developmentAdminEmail, password == developmentAdminPassword {
            enableLocalAdminMode()
            return
        }

        if let account = localSandboxAccounts()[email], account.password == password {
            loadLocalSandboxAccount(account)
            return
        }

        #if canImport(Supabase)
        await runLoadingTask {
            let response = try await client.auth.signIn(email: email, password: password)

            try await ensureDefaultCompanyExists(for: response.user.id)
            isUsingLocalAdminMode = false
            currentLocalAccountEmail = nil
            defaults.removeObject(forKey: currentLocalAccountEmailKey)
            authState = .signedIn
            await refreshDashboard()
        }
        #else
        errorMessage = onboardingProfile.text(en: "Supabase SDK is not linked.", es: "El SDK de Supabase no está vinculado.", pt: "O SDK do Supabase não está vinculado.", fr: "Le SDK Supabase n'est pas lié.", ar: "حزمة Supabase SDK غير مرتبطة.", de: "Das Supabase-SDK ist nicht verknüpft.", it: "L'SDK di Supabase non è collegato.", nl: "De Supabase SDK is niet gekoppeld.", ja: "Supabase SDK がリンクされていません。", ko: "Supabase SDK가 연결되어 있지 않습니다.")
        #endif
    }

    func signOut() async {
        if isUsingLocalAdminMode {
            defaults.set(false, forKey: "local_admin_enabled")
            defaults.removeObject(forKey: currentLocalAccountEmailKey)
            currentCompany = nil
            transactions = []
            authState = .signedOut
            isUsingLocalAdminMode = false
            currentLocalAccountEmail = nil
            return
        }

        #if canImport(Supabase)
        await runLoadingTask {
            try await client.auth.signOut()
            clearSupabaseCache()
            currentCompany = nil
            transactions = []
            authState = .signedOut
            isUsingLocalAdminMode = false
            currentLocalAccountEmail = nil
            isOffline = false
        }
        #else
        authState = .signedOut
        #endif
    }

    func refreshDashboard() async {
        if isUsingLocalAdminMode || currentLocalAccountEmail != nil {
            loadLocalTransactions()
            loadLocalReceipts()
            await autoCreateDueRecurringTransactions()
            return
        }

        #if canImport(Supabase)
        guard authState == .signedIn else { return }

        await runLoadingTask {
            // Try to get valid session, refresh token if needed
            let session: Session
            do {
                session = try await client.auth.session
            } catch {
                // Token may have expired — try refreshing before giving up
                do {
                    session = try await client.auth.refreshSession()
                } catch {
                    authState = .signedOut
                    throw error
                }
            }
            let companies: [Company] = try await client
                .from("companies")
                .select()
                .eq("owner_id", value: session.user.id.uuidString)
                .order("created_at", ascending: true)
                .execute()
                .value

            availableCompanies = companies
            let selectedCompanyID = defaults.string(forKey: selectedCompanyIDKey).flatMap(UUID.init(uuidString:))
            currentCompany = companies.first(where: { $0.id == selectedCompanyID }) ?? companies.first

            guard let companyID = currentCompany?.id else {
                transactions = []
                return
            }

            defaults.set(companyID.uuidString, forKey: selectedCompanyIDKey)

            transactions = try await client
                .from("transactions")
                .select()
                .eq("company_id", value: companyID.uuidString)
                .order("date", ascending: false)
                .execute()
                .value

            let receipts: [Receipt] = try await client
                .from("receipts")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value

            let currentTransactionIDs = Set(transactions.map(\.id))
            receiptsByTransactionID = Dictionary(uniqueKeysWithValues: receipts.filter { currentTransactionIDs.contains($0.transactionID) }.map { ($0.transactionID, $0) })
            saveToSupabaseCache()
            isOffline = false
            await autoCreateDueRecurringTransactions()
        }
        #endif
    }

    func uploadReceiptImageForOCR(imageData: Data, fileExtension: String) async throws -> URL {
        if isUsingLocalAdminMode || currentLocalAccountEmail != nil {
            let directoryURL = try localReceiptImagesDirectory()
            let fileURL = directoryURL.appendingPathComponent("\(UUID().uuidString).\(fileExtension)")
            try imageData.write(to: fileURL, options: .atomic)
            return fileURL
        }

        #if canImport(Supabase)
        return try await uploadReceiptImage(imageData: imageData, fileExtension: fileExtension)
        #else
        throw URLError(.badURL)
        #endif
    }

    func createExpenseWithUploadedReceipt(
        imageURL: URL,
        vendor: String,
        amount: Decimal,
        category: String,
        date: Date,
        notes: String?,
        rawText: String?
    ) async -> Bool {
        await createTransaction(
            type: .expense,
            vendor: vendor,
            amount: amount,
            category: category,
            date: date,
            notes: notes,
            imageURL: imageURL,
            rawText: rawText
        )
    }

    func createTransaction(
        type: TransactionType,
        vendor: String,
        amount: Decimal,
        category: String,
        date: Date,
        notes: String?,
        imageURL: URL? = nil,
        rawText: String? = nil
    ) async -> Bool {
        if isUsingLocalAdminMode || currentLocalAccountEmail != nil {
            let transaction = AccountingTransaction(
                id: UUID(),
                companyID: currentCompany?.id ?? localCompanyID,
                type: type,
                amount: amount,
                vendor: vendor,
                category: category,
                date: date,
                notes: notes,
                createdAt: .now
            )
            transactions.insert(transaction, at: 0)
            if let imageURL {
                let receipt = Receipt(
                    id: UUID(),
                    transactionID: transaction.id,
                    imageURL: imageURL.absoluteString,
                    vendor: vendor,
                    amount: amount,
                    date: date,
                    rawText: rawText,
                    createdAt: .now
                )
                receiptsByTransactionID[transaction.id] = receipt
                saveLocalReceipts()
            }
            saveLocalTransactions()
            saveCustomCategoryIfNeeded(category)
            appendAudit(transactionID: transaction.id, action: "created", detail: vendor)
            return true
        }

        #if canImport(Supabase)
        guard let currentCompany else {
            errorMessage = onboardingProfile.text(en: "No company available for this user.", es: "No hay ninguna empresa disponible para este usuario.", pt: "Nenhuma empresa disponível para este usuário.", fr: "Aucune entreprise disponible pour cet utilisateur.", ar: "لا توجد شركة متاحة لهذا المستخدم.", de: "Für diesen Benutzer ist kein Unternehmen verfügbar.", it: "Nessuna azienda disponibile per questo utente.", nl: "Er is geen bedrijf beschikbaar voor deze gebruiker.", ja: "このユーザーに利用可能な会社がありません。", ko: "이 사용자에게 사용할 수 있는 회사가 없습니다.")
            return false
        }

        return await runLoadingTaskReturningBool {
            let transactionPayload = NewTransactionPayload(
                companyID: currentCompany.id,
                type: type,
                amount: amount,
                vendor: vendor,
                category: category,
                date: date,
                notes: notes
            )

            let transaction: AccountingTransaction = try await client
                .from("transactions")
                .insert(transactionPayload)
                .select()
                .single()
                .execute()
                .value

            if let imageURL {
                let receiptPayload = NewReceiptPayload(
                    transactionID: transaction.id,
                    imageURL: imageURL.absoluteString,
                    vendor: vendor,
                    amount: amount,
                    date: date,
                    rawText: rawText
                )

                _ = try await client
                    .from("receipts")
                    .insert(receiptPayload)
                    .execute()
            }

            await refreshDashboard()
            saveCustomCategoryIfNeeded(category)
            appendAudit(transactionID: transaction.id, action: "created", detail: vendor)
        }
        #else
        errorMessage = onboardingProfile.text(en: "Supabase SDK is not linked.", es: "El SDK de Supabase no está vinculado.", pt: "O SDK do Supabase não está vinculado.", fr: "Le SDK Supabase n'est pas lié.", ar: "حزمة Supabase SDK غير مرتبطة.", de: "Das Supabase-SDK ist nicht verknüpft.", it: "L'SDK di Supabase non è collegato.", nl: "De Supabase SDK is niet gekoppeld.", ja: "Supabase SDK がリンクされていません。", ko: "Supabase SDK가 연결되어 있지 않습니다.")
        return false
        #endif
    }

    func updateTransaction(
        _ transaction: AccountingTransaction,
        type: TransactionType,
        vendor: String,
        amount: Decimal,
        category: String,
        date: Date,
        notes: String?,
        imageURL: URL? = nil,
        rawText: String? = nil
    ) async -> Bool {
        let updatedTransaction = AccountingTransaction(
            id: transaction.id,
            companyID: transaction.companyID,
            type: type,
            amount: amount,
            vendor: vendor,
            category: category,
            date: date,
            notes: notes,
            createdAt: transaction.createdAt
        )

        if isUsingLocalAdminMode || currentLocalAccountEmail != nil {
            guard let index = transactions.firstIndex(where: { $0.id == transaction.id }) else { return false }
            transactions[index] = updatedTransaction
            if let existingReceipt = receiptsByTransactionID[transaction.id] {
                receiptsByTransactionID[transaction.id] = Receipt(
                    id: existingReceipt.id,
                    transactionID: existingReceipt.transactionID,
                    imageURL: imageURL?.absoluteString ?? existingReceipt.imageURL,
                    vendor: vendor,
                    amount: amount,
                    date: date,
                    rawText: rawText ?? existingReceipt.rawText,
                    createdAt: existingReceipt.createdAt
                )
                saveLocalReceipts()
            } else if let imageURL {
                receiptsByTransactionID[transaction.id] = Receipt(
                    id: UUID(),
                    transactionID: transaction.id,
                    imageURL: imageURL.absoluteString,
                    vendor: vendor,
                    amount: amount,
                    date: date,
                    rawText: rawText,
                    createdAt: .now
                )
                saveLocalReceipts()
            }
            transactions.sort { $0.date > $1.date }
            saveLocalTransactions()
            appendAudit(transactionID: transaction.id, action: "updated", detail: vendor)
            return true
        }

        #if canImport(Supabase)
        return await runLoadingTaskReturningBool {
            _ = try await client
                .from("transactions")
                .update(NewTransactionPayload(
                    companyID: updatedTransaction.companyID,
                    type: type,
                    amount: amount,
                    vendor: vendor,
                    category: category,
                    date: date,
                    notes: notes
                ))
                .eq("id", value: transaction.id.uuidString)
                .execute()

            struct ReceiptUpdate: Codable {
                let vendor: String
                let amount: Decimal
                let date: Date
            }

            _ = try? await client
                .from("receipts")
                .update(ReceiptUpdate(vendor: vendor, amount: amount, date: date))
                .eq("transaction_id", value: transaction.id.uuidString)
                .execute()

            if let imageURL {
                let receiptPayload = NewReceiptPayload(
                    transactionID: transaction.id,
                    imageURL: imageURL.absoluteString,
                    vendor: vendor,
                    amount: amount,
                    date: date,
                    rawText: rawText
                )

                _ = try? await client
                    .from("receipts")
                    .insert(receiptPayload)
                    .execute()
            }

            await refreshDashboard()
            appendAudit(transactionID: transaction.id, action: "updated", detail: vendor)
        }
        #else
        errorMessage = onboardingProfile.text(en: "Supabase SDK is not linked.", es: "El SDK de Supabase no está vinculado.", pt: "O SDK do Supabase não está vinculado.", fr: "Le SDK Supabase n'est pas lié.", ar: "حزمة Supabase SDK غير مرتبطة.", de: "Das Supabase-SDK ist nicht verknüpft.", it: "L'SDK di Supabase non è collegato.", nl: "De Supabase SDK is niet gekoppeld.", ja: "Supabase SDK がリンクされていません。", ko: "Supabase SDK가 연결되어 있지 않습니다.")
        return false
        #endif
    }

    func deleteTransaction(_ transaction: AccountingTransaction) async -> Bool {
        if isUsingLocalAdminMode || currentLocalAccountEmail != nil {
            transactions.removeAll { $0.id == transaction.id }
            receiptsByTransactionID.removeValue(forKey: transaction.id)
            saveLocalTransactions()
            saveLocalReceipts()
            appendAudit(transactionID: transaction.id, action: "deleted", detail: transaction.vendor)
            return true
        }

        #if canImport(Supabase)
        return await runLoadingTaskReturningBool {
            _ = try await client
                .from("transactions")
                .delete()
                .eq("id", value: transaction.id.uuidString)
                .execute()

            await refreshDashboard()
            appendAudit(transactionID: transaction.id, action: "deleted", detail: transaction.vendor)
        }
        #else
        errorMessage = onboardingProfile.text(en: "Supabase SDK is not linked.", es: "El SDK de Supabase no está vinculado.", pt: "O SDK do Supabase não está vinculado.", fr: "Le SDK Supabase n'est pas lié.", ar: "حزمة Supabase SDK غير مرتبطة.", de: "Das Supabase-SDK ist nicht verknüpft.", it: "L'SDK di Supabase non è collegato.", nl: "De Supabase SDK is niet gekoppeld.", ja: "Supabase SDK がリンクされていません。", ko: "Supabase SDK가 연결되어 있지 않습니다.")
        return false
        #endif
    }

    func saveOnboardingProfile(
        country: String,
        language: String,
        currencyCode: String,
        workspaceType: WorkspaceType,
        personName: String,
        workspaceName: String
    ) {
        let normalizedPersonName = personName.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedWorkspaceName = workspaceName.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedWorkspaceName: String

        if workspaceType == .personal {
            resolvedWorkspaceName = normalizedWorkspaceName.isEmpty ? normalizedPersonName : normalizedWorkspaceName
        } else {
            resolvedWorkspaceName = normalizedWorkspaceName.isEmpty ? onboardingProfile.defaultBusinessName : normalizedWorkspaceName
        }

        onboardingProfile = OnboardingProfile(
            country: country,
            language: language,
            currencyCode: currencyCode,
            workspaceType: workspaceType,
            personName: normalizedPersonName,
            workspaceName: resolvedWorkspaceName
        )

        guard let data = try? encoder.encode(onboardingProfile) else { return }
        defaults.set(data, forKey: onboardingProfileKey)
        syncToiCloud()
    }

    func updateSettings(
        country: String,
        language: String,
        currencyCode: String,
        workspaceType: WorkspaceType,
        personName: String,
        workspaceName: String,
        companyName: String,
        notificationsEnabled: Bool
    ) async -> Bool {
        saveOnboardingProfile(
            country: country,
            language: language,
            currencyCode: currencyCode,
            workspaceType: workspaceType,
            personName: personName,
            workspaceName: workspaceName
        )
        self.notificationsEnabled = notificationsEnabled
        defaults.set(notificationsEnabled, forKey: "bx_notifications_enabled")
        scheduleLocalNotifications()
        let cleanedCompanyName = companyName.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedCompanyName = cleanedCompanyName.isEmpty ? onboardingProfile.primaryName : cleanedCompanyName

        guard let currentCompany else {
            errorMessage = nil
            return true
        }

        let updatedCompany = Company(
            id: currentCompany.id,
            ownerID: currentCompany.ownerID,
            name: resolvedCompanyName,
            logoURL: currentCompany.logoURL,
            createdAt: currentCompany.createdAt
        )

        if isUsingLocalAdminMode || currentLocalAccountEmail != nil {
            self.currentCompany = updatedCompany
            if isUsingLocalAdminMode {
                defaults.set(companyName, forKey: localAdminCompanyNameKey)
            } else if let currentLocalAccountEmail {
                var accounts = localSandboxAccounts()
                if let account = accounts[currentLocalAccountEmail] {
                    accounts[currentLocalAccountEmail] = LocalSandboxAccount(
                        id: account.id,
                        email: account.email,
                        password: account.password,
                        company: updatedCompany,
                        createdAt: account.createdAt
                    )
                    saveLocalSandboxAccounts(accounts)
                }
            }
            errorMessage = nil
            return true
        }

        #if canImport(Supabase)
        return await runLoadingTaskReturningBool {
            struct CompanyUpdate: Codable {
                let name: String
            }

            _ = try await client
                .from("companies")
                    .update(CompanyUpdate(name: updatedCompany.name))
                .eq("id", value: currentCompany.id.uuidString)
                .execute()

            self.currentCompany = updatedCompany
        }
        #else
        return true
        #endif
    }

    func addSubscription(name: String, amount: Decimal, dueDay: Int, category: MonthlyPaymentCategory = .subscription, notes: String?) {
        let item = SubscriptionItem(
            id: UUID(),
            name: name,
            amount: amount,
            dueDay: dueDay,
            category: category,
            notes: notes,
            createdAt: .now
        )
        subscriptions.append(item)
        subscriptions.sort { $0.dueDay < $1.dueDay }
        saveSubscriptions()
        scheduleLocalNotifications()
    }

    func deleteSubscription(_ subscription: SubscriptionItem) {
        subscriptions.removeAll { $0.id == subscription.id }
        saveSubscriptions()
        scheduleLocalNotifications()
    }

    func markSubscriptionPaid(_ subscription: SubscriptionItem, paid: Bool) {
        guard let index = subscriptions.firstIndex(where: { $0.id == subscription.id }) else { return }
        let key = SubscriptionItem.monthKey(for: .now)
        if paid {
            if !subscriptions[index].paidMonths.contains(key) {
                subscriptions[index].paidMonths.append(key)
                // Auto-create expense transaction so it shows in reports + deducts from income
                Task {
                    _ = await createTransaction(
                        type: .expense,
                        vendor: subscription.name,
                        amount: subscription.amount,
                        category: subscription.category.rawValue,
                        date: .now,
                        notes: nil
                    )
                }
            }
        } else {
            subscriptions[index].paidMonths.removeAll { $0 == key }
        }
        saveSubscriptions()
        scheduleLocalNotifications()
    }

    /// Returns subscriptions due this month that haven't been marked paid
    var pendingSubscriptionsThisMonth: [SubscriptionItem] {
        let today = Calendar.current.component(.day, from: .now)
        return subscriptions.filter { $0.dueDay <= today && !$0.isPaidThisMonth }
    }

    /// Checks if any budget is over limit after a new transaction is added
    func overBudgetAlerts(for category: String) -> BudgetItem? {
        guard let budget = currentMonthlyBudget else { return nil }
        let spent = totalSpentThisMonth()
        return spent > budget.monthlyLimit ? budget : nil
    }

    var currentMonthlyBudget: BudgetItem? {
        budget(for: monthlyBudgetCategory(for: .now))
    }

    func shouldAskForMonthlyBudget() -> Bool {
        currentMonthlyBudget == nil
    }

    func setCurrentMonthlyBudget(_ monthlyLimit: Decimal) {
        let category = monthlyBudgetCategory(for: .now)
        budgets.removeAll { normalizedCategory($0.category) == normalizedCategory(category) }
        budgets.append(BudgetItem(id: UUID(), category: category, monthlyLimit: monthlyLimit, createdAt: .now))
        budgets.sort { $0.createdAt > $1.createdAt }
        saveBudgets()
    }

    func deleteCurrentMonthlyBudget() {
        let category = monthlyBudgetCategory(for: .now)
        budgets.removeAll { normalizedCategory($0.category) == normalizedCategory(category) }
        saveBudgets()
    }

    func addBudget(category: String, monthlyLimit: Decimal) {
        let cleanedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        budgets.removeAll { normalizedCategory($0.category) == normalizedCategory(cleanedCategory) }
        let item = BudgetItem(id: UUID(), category: cleanedCategory, monthlyLimit: monthlyLimit, createdAt: .now)
        budgets.append(item)
        budgets.sort { $0.category < $1.category }
        saveBudgets()
    }

    func deleteBudget(_ budget: BudgetItem) {
        budgets.removeAll { $0.id == budget.id }
        saveBudgets()
    }

    func addCustomCategory(named name: String) {
        saveCustomCategoryIfNeeded(name)
    }

    func renameCustomCategory(_ category: CustomCategory, to name: String) {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedName.isEmpty,
              let index = customCategories.firstIndex(where: { $0.id == category.id }) else { return }
        customCategories[index].name = cleanedName
        customCategories.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        saveCustomCategories()
    }

    func setCustomCategory(_ category: CustomCategory, hidden: Bool) {
        guard let index = customCategories.firstIndex(where: { $0.id == category.id }) else { return }
        customCategories[index].isHidden = hidden
        saveCustomCategories()
    }

    func deleteCustomCategory(_ category: CustomCategory) {
        customCategories.removeAll { $0.id == category.id }
        saveCustomCategories()
    }

    func inviteTeamMember(email: String, role: MemberRole) {
        let cleanedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanedEmail.isEmpty else { return }
        let companyID = currentCompany?.id ?? localCompanyID
        teamInvitations.removeAll {
            $0.companyID == companyID &&
            $0.email.caseInsensitiveCompare(cleanedEmail) == .orderedSame &&
            $0.status == .pending
        }
        teamInvitations.insert(
            TeamInvitation(
                id: UUID(),
                companyID: companyID,
                email: cleanedEmail,
                role: role,
                status: .pending,
                createdAt: .now,
                respondedAt: nil
            ),
            at: 0
        )
        saveTeamInvitations()

        let companyName = currentCompany?.name ?? onboardingProfile.workspaceName
        let senderName = onboardingProfile.personName
        Task {
            await triggerEmail(
                type: "invite",
                to: cleanedEmail,
                name: "",
                extraData: [
                    "companyName": companyName,
                    "senderName": senderName,
                    "role": role.rawValue
                ]
            )
        }
    }

    func updateInvitationRole(_ invitation: TeamInvitation, role: MemberRole) {
        guard let index = teamInvitations.firstIndex(where: { $0.id == invitation.id }) else { return }
        teamInvitations[index].role = role
        saveTeamInvitations()
    }

    func acceptInvitation(_ invitation: TeamInvitation) {
        setInvitation(invitation, status: .accepted)
    }

    func revokeInvitation(_ invitation: TeamInvitation) {
        setInvitation(invitation, status: .revoked)
    }

    func reconciliationStatus(for transaction: AccountingTransaction) -> ReconciliationStatus {
        reconciliationStatuses[transaction.id] ?? .pending
    }

    func setReconciliationStatus(_ status: ReconciliationStatus, for transaction: AccountingTransaction) {
        reconciliationStatuses[transaction.id] = status
        saveReconciliationStatuses()
        appendAudit(transactionID: transaction.id, action: status.rawValue, detail: transaction.vendor)
    }

    func auditEntries(for transaction: AccountingTransaction) -> [TransactionAuditEntry] {
        transactionAuditEntries
            .filter { $0.transactionID == transaction.id }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func addSavingsGoal(name: String, targetAmount: Decimal, targetDate: Date? = nil) {
        let goal = SavingsGoal(id: UUID(), name: name, targetAmount: targetAmount, savedAmount: .zero, targetDate: targetDate, createdAt: .now)
        savingsGoals.append(goal)
        saveSavingsGoals()
    }

    func updateSavingsGoalAmount(_ goal: SavingsGoal, savedAmount: Decimal) {
        guard let index = savingsGoals.firstIndex(where: { $0.id == goal.id }) else { return }
        savingsGoals[index].savedAmount = savedAmount
        saveSavingsGoals()
    }

    func depositToSavingsGoal(_ goal: SavingsGoal, amount: Decimal) {
        guard let index = savingsGoals.firstIndex(where: { $0.id == goal.id }) else { return }
        savingsGoals[index].savedAmount += amount
        saveSavingsGoals()
    }

    func deleteSavingsGoal(_ goal: SavingsGoal) {
        savingsGoals.removeAll { $0.id == goal.id }
        saveSavingsGoals()
    }

    func setPremium(_ value: Bool) {
        isPremium = value
        defaults.set(value, forKey: isPremiumKey)
    }

    func setBiometricLock(_ value: Bool) {
        biometricLockEnabled = value
        defaults.set(value, forKey: biometricLockKey)
    }

    func spentThisMonth(for category: String) -> Decimal {
        let calendar = Calendar.current
        let now = Date.now
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) ?? now
        let normalizedTarget = normalizedCategory(category)
        return transactions
            .filter {
                $0.type == .expense &&
                normalizedCategory($0.category) == normalizedTarget &&
                $0.date >= startOfMonth &&
                $0.date < endOfMonth
            }
            .reduce(into: Decimal.zero) { $0 += $1.amount }
    }

    func totalSpentThisMonth() -> Decimal {
        let calendar = Calendar.current
        let now = Date.now
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) ?? now
        return transactions
            .filter { $0.type == .expense && $0.date >= startOfMonth && $0.date < endOfMonth }
            .reduce(into: Decimal.zero) { $0 += $1.amount }
    }

    func budget(for category: String) -> BudgetItem? {
        let normalizedTarget = normalizedCategory(category)
        return budgets.first { normalizedCategory($0.category) == normalizedTarget }
    }

    func monthlyBudgetCategories() -> [String] {
        let calendar = Calendar.current
        let now = Date.now
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) ?? now
        var categoriesByKey: [String: String] = [:]

        for budget in budgets {
            let cleanedCategory = budget.category.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanedCategory.isEmpty else { continue }
            categoriesByKey[normalizedCategory(cleanedCategory)] = cleanedCategory
        }

        for transaction in transactions where transaction.type == .expense && transaction.date >= startOfMonth && transaction.date < endOfMonth {
            let cleanedCategory = transaction.category.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanedCategory.isEmpty else { continue }
            categoriesByKey[normalizedCategory(cleanedCategory), default: cleanedCategory] = cleanedCategory
        }

        return categoriesByKey.values.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func normalizedCategory(_ category: String) -> String {
        category.trimmingCharacters(in: .whitespacesAndNewlines).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private func monthlyBudgetCategory(for date: Date) -> String {
        "\(monthlyBudgetCategoryPrefix)\(monthKey(for: date))"
    }

    private func monthKey(for date: Date) -> String {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        return String(format: "%04d-%02d", year, month)
    }

    // MARK: - Cached analytics pass-throughs

    var estimatedTaxes: Decimal { analytics.estimatedTaxes }
    var dailyNotifications: [AppNotificationItem] { analytics.notifications }

    // MARK: - Background analytics computation

    /// Recomputes all expensive analytics on a background thread and publishes the result.
    func recomputeAnalytics() {
        // Capture all main-actor state before entering the background task.
        let txns = transactions
        let bdgs = budgets
        let goals = savingsGoals
        let profile = onboardingProfile
        let notificationsOn = notificationsEnabled
        let subs = subscriptions
        let currencyCode = profile.currencyCode

        // Pre-compute ALL analytics on the main actor to avoid strict-concurrency warnings
        // about @MainActor-inferred methods being called from Task.detached.
        let preProfit   = txns.profit
        let preIncome   = txns.totalIncome
        let preExpenses = txns.totalExpenses
        let preTaxes: Decimal = preProfit > .zero ? preProfit * profile.estimatedTaxRate(on: preProfit) : .zero
        let prePredictedBalance = txns.predictedEndOfMonthBalance(currentBalance: preProfit)
        let preHealthScore = txns.financialHealthScore(budgets: bdgs, savingsGoals: goals, profile: profile)
        var preChartPoints: [DashboardPeriod: [Decimal]] = [:]
        var preInsights: [DashboardPeriod: [InsightCardModel]] = [:]
        for period in DashboardPeriod.allCases {
            preChartPoints[period] = txns.chartPoints(for: period)
            preInsights[period] = txns.topInsights(period: period, profile: profile, currencyCode: currencyCode)
        }

        // Pre-build the analytics cache struct on the main actor.
        var preCache = BXAnalyticsCache()
        preCache.profit           = preProfit
        preCache.totalIncome      = preIncome
        preCache.totalExpenses    = preExpenses
        preCache.estimatedTaxes   = preTaxes
        preCache.predictedBalance = prePredictedBalance
        preCache.healthScore      = preHealthScore
        preCache.chartPoints      = preChartPoints
        preCache.insights         = preInsights

        // Pre-compute notification-related values (currency strings, booleans, dates).
        let today = Date.now
        let todayStart = today.startOfDay
        let taxDate = nextTaxDueDate(from: today)
        let taxDateStart = taxDate.startOfDay
        let preTaxEstimate = preTaxes.currencyString(code: currencyCode)
        let hasTodayActivity = txns.contains(where: { Calendar.current.isDate($0.date, inSameDayAs: today) })
        let subDates: [(sub: SubscriptionItem, dueDate: Date, dueDateStart: Date, amountStr: String)] = subs.map {
            let due = nextDueDate(for: $0, from: today)
            return ($0, due, due.startOfDay, $0.amount.currencyString(code: currencyCode))
        }
        var preNotificationItems: [AppNotificationItem] = []
        if notificationsOn {
            let calendar = Calendar.current

            if !hasTodayActivity {
                preNotificationItems.append(AppNotificationItem(
                    id: UUID(),
                    title: profile.text(
                        en: "No activity logged today",
                        es: "Aún no registras movimientos",
                        pt: "Nenhuma atividade registrada hoje",
                        fr: "Aucune activité enregistrée aujourd'hui",
                        ar: "لم يتم تسجيل أي نشاط اليوم",
                        de: "Heute wurde noch keine Aktivität erfasst",
                        it: "Nessuna attività registrata oggi",
                        nl: "Vandaag is nog geen activiteit geregistreerd",
                        ja: "今日はまだ取引が記録されていません",
                        ko: "오늘은 아직 활동이 기록되지 않았습니다"
                    ),
                    message: profile.text(
                        en: "You have not logged income or expenses today. Keep your books current.",
                        es: "Hoy no has registrado ingresos ni gastos. Mantén tu contabilidad al día.",
                        pt: "Você ainda não registrou receitas ou despesas hoje. Mantenha sua contabilidade em dia.",
                        fr: "Vous n'avez encore enregistré ni revenus ni dépenses aujourd'hui. Gardez votre comptabilité à jour.",
                        ar: "لم تسجل أي دخل أو مصروفات اليوم. حافظ على دفاترك محدثة.",
                        de: "Du hast heute noch keine Einnahmen oder Ausgaben erfasst. Halte deine Buchhaltung aktuell.",
                        it: "Oggi non hai ancora registrato entrate o spese. Mantieni aggiornata la contabilità.",
                        nl: "Je hebt vandaag nog geen inkomsten of uitgaven geregistreerd. Houd je administratie up-to-date.",
                        ja: "今日はまだ収入や支出が記録されていません。会計を最新の状態に保ちましょう。",
                        ko: "오늘은 아직 수입이나 지출을 기록하지 않았습니다. 장부를 최신 상태로 유지하세요."
                    ),
                    date: today,
                    kind: .reminder
                ))
            }

            let daysUntilTax = calendar.dateComponents([.day], from: todayStart, to: taxDateStart).day ?? 0
            if daysUntilTax <= 10 {
                preNotificationItems.append(AppNotificationItem(
                    id: UUID(),
                    title: profile.nextTaxReminderTitle,
                    message: profile.text(
                        en: "Your estimated payment is \(preTaxEstimate) and is due in \(daysUntilTax) days.",
                        es: "Tu pago estimado es \(preTaxEstimate) y vence en \(daysUntilTax) días.",
                        pt: "Seu pagamento estimado é \(preTaxEstimate) e vence em \(daysUntilTax) dias.",
                        fr: "Votre paiement estimé est de \(preTaxEstimate) et arrive à échéance dans \(daysUntilTax) jours.",
                        ar: "دفعتك التقديرية هي \(preTaxEstimate) وتستحق خلال \(daysUntilTax) أيام.",
                        de: "Deine geschätzte Zahlung beträgt \(preTaxEstimate) und ist in \(daysUntilTax) Tagen fällig.",
                        it: "Il tuo pagamento stimato è \(preTaxEstimate) e scade tra \(daysUntilTax) giorni.",
                        nl: "Je geschatte betaling is \(preTaxEstimate) en vervalt over \(daysUntilTax) dagen.",
                        ja: "推定支払額は\(preTaxEstimate)で、あと\(daysUntilTax)日で期限です。",
                        ko: "예상 납부액은 \(preTaxEstimate)이며 \(daysUntilTax)일 후 마감됩니다."
                    ),
                    date: taxDate,
                    kind: .tax
                ))
            }

            for (subscription, dueDate, dueDateStart, amountStr) in subDates {
                let daysUntil = calendar.dateComponents([.day], from: todayStart, to: dueDateStart).day ?? 0
                if daysUntil <= 5 {
                    preNotificationItems.append(AppNotificationItem(
                        id: UUID(),
                        title: profile.text(
                            en: "Payment due soon",
                            es: "Pago próximo",
                            pt: "Pagamento próximo",
                            fr: "Paiement à venir",
                            ar: "دفعة مستحقة قريبًا",
                            de: "Zahlung bald fällig",
                            it: "Pagamento in arrivo",
                            nl: "Betaling binnenkort verschuldigd",
                            ja: "まもなく支払い期限",
                            ko: "곧 결제 예정"
                        ),
                        message: profile.text(
                            en: "\(subscription.name) is due in \(daysUntil) days for \(amountStr).",
                            es: "\(subscription.name) vence en \(daysUntil) días por \(amountStr).",
                            pt: "\(subscription.name) vence em \(daysUntil) dias no valor de \(amountStr).",
                            fr: "\(subscription.name) arrive à échéance dans \(daysUntil) jours pour \(amountStr).",
                            ar: "يستحق \(subscription.name) خلال \(daysUntil) أيام بمبلغ \(amountStr).",
                            de: "\(subscription.name) ist in \(daysUntil) Tagen über \(amountStr) fällig.",
                            it: "\(subscription.name) scade tra \(daysUntil) giorni per \(amountStr).",
                            nl: "\(subscription.name) vervalt over \(daysUntil) dagen voor \(amountStr).",
                            ja: "\(subscription.name) はあと\(daysUntil)日で \(amountStr) の支払い期限です。",
                            ko: "\(subscription.name)의 \(amountStr) 결제가 \(daysUntil)일 후 마감됩니다."
                        ),
                        date: dueDate,
                        kind: .subscription
                    ))
                }
            }
        }

        Task.detached(priority: .utility) {
            // All heavy computation is already done — Task.detached only assembles notifications.
            var cache = preCache

            if notificationsOn {
                var items = preNotificationItems
                if let firstInsight = cache.insights[.monthly]?.first {
                    items.append(AppNotificationItem(
                        id: UUID(),
                        title: firstInsight.title,
                        message: firstInsight.message,
                        date: today,
                        kind: .insight
                    ))
                }

                cache.notifications = items.sorted { $0.date < $1.date }
            }

            let finalCache = cache
            await MainActor.run { [weak self] in
                self?.analytics = finalCache
                if let group = UserDefaults(suiteName: "group.TheClassified.Balance-X") {
                    group.set((finalCache.totalIncome as NSDecimalNumber).doubleValue, forKey: "bx_widget_income")
                    group.set((finalCache.totalExpenses as NSDecimalNumber).doubleValue, forKey: "bx_widget_expenses")
                    group.set(self?.onboardingProfile.currencyCode ?? "USD", forKey: "bx_widget_currency")
                }
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }

    /// True when the device's preferred language is Spanish, regardless of in-app language setting.
    private var deviceIsSpanish: Bool {
        Locale.preferredLanguages.first?.hasPrefix("es") == true
    }

    func scanReceipt(imageURL: URL) async throws -> OCRReceiptResponse {
        guard let receiptService else {
            throw ReceiptServiceError.notConfigured
        }

        return try await receiptService.scanReceipt(imageURL: imageURL)
    }

    func receipt(for transactionID: UUID) -> Receipt? {
        receiptsByTransactionID[transactionID]
    }

    func switchCompany(to company: Company) async {
        currentCompany = company
        defaults.set(company.id.uuidString, forKey: selectedCompanyIDKey)
        // Use a lightweight reload that doesn't re-validate auth session
        // (avoids spurious sign-out when the token auto-refreshes in the background)
        await reloadTransactions(for: company)
    }

    /// Reloads only transactions + receipts for a specific company.
    /// Does NOT touch authState — safe to call during company switches.
    private func reloadTransactions(for company: Company) async {
        if isUsingLocalAdminMode {
            loadLocalTransactions()
            loadLocalReceipts()
            return
        }
        #if canImport(Supabase)
        guard authState == .signedIn else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            transactions = try await client
                .from("transactions")
                .select()
                .eq("company_id", value: company.id.uuidString)
                .order("date", ascending: false)
                .execute()
                .value

            let receipts: [Receipt] = try await client
                .from("receipts")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value

            let txIDs = Set(transactions.map(\.id))
            receiptsByTransactionID = Dictionary(
                uniqueKeysWithValues: receipts
                    .filter { txIDs.contains($0.transactionID) }
                    .map { ($0.transactionID, $0) }
            )
            saveToSupabaseCache()
            isOffline = false
        } catch {
            // Fall back to cached data if available; only show error when cache is empty
            let loaded = loadFromSupabaseCache()
            if !loaded {
                errorMessage = onboardingProfile.text(
                    en: "Couldn’t load company data. Check your connection.",
                    es: "No se pudo cargar la empresa. Verifica tu conexión.",
                    pt: "Não foi possível carregar os dados da empresa. Verifique sua conexão.",
                    fr: "Impossible de charger les données de l’entreprise. Vérifiez votre connexion.",
                    ar: "تعذر تحميل بيانات الشركة. تحقق من اتصالك.",
                    de: "Unternehmensdaten konnten nicht geladen werden. Prüfe deine Verbindung.",
                    it: "Impossibile caricare i dati dell’azienda. Controlla la connessione.",
                    nl: "Kon de bedrijfsgegevens niet laden. Controleer je verbinding.",
                    ja: "会社データを読み込めませんでした。接続を確認してください。",
                    ko: "회사 데이터를 불러올 수 없습니다. 연결을 확인하세요."
                )
            }
        }
        #endif
    }

    func createAdditionalCompany(named name: String) async -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = onboardingProfile.text(en: "Enter a valid company name.", es: "Ingresa un nombre de empresa válido.", pt: "Informe um nome de empresa válido.", fr: "Saisissez un nom d’entreprise valide.", ar: "أدخل اسم شركة صالحًا.", de: "Gib einen gültigen Firmennamen ein.", it: "Inserisci un nome aziendale valido.", nl: "Voer een geldige bedrijfsnaam in.", ja: "有効な会社名を入力してください。", ko: "유효한 회사 이름을 입력하세요.")
            return false
        }

        if isUsingLocalAdminMode || currentLocalAccountEmail != nil {
            let company = Company(
                id: UUID(),
                ownerID: currentCompany?.ownerID ?? localUserID,
                name: trimmedName,
                logoURL: nil,
                createdAt: .now
            )
            availableCompanies.append(company)
            availableCompanies.sort { $0.createdAt < $1.createdAt }
            currentCompany = company
            defaults.set(company.id.uuidString, forKey: selectedCompanyIDKey)
            errorMessage = nil
            return true
        }

        #if canImport(Supabase)
        return await runLoadingTaskReturningBool {
            let session = try await client.auth.session

            struct NewCompany: Codable {
                let ownerID: UUID
                let name: String
                let logoURL: String?

                enum CodingKeys: String, CodingKey {
                    case ownerID = "owner_id"
                    case name
                    case logoURL = "logo_url"
                }
            }

            struct NewMember: Codable {
                let userID: UUID
                let companyID: UUID
                let role: MemberRole

                enum CodingKeys: String, CodingKey {
                    case userID = "user_id"
                    case companyID = "company_id"
                    case role
                }
            }

            let company: Company = try await client
                .from("companies")
                .insert(NewCompany(ownerID: session.user.id, name: trimmedName, logoURL: nil))
                .select()
                .single()
                .execute()
                .value

            _ = try await client
                .from("members")
                .insert(NewMember(userID: session.user.id, companyID: company.id, role: .owner))
                .execute()

            defaults.set(company.id.uuidString, forKey: selectedCompanyIDKey)
            await refreshDashboard()
        }
        #else
        return false
        #endif
    }

    #if canImport(Supabase)
    private func ensureDefaultCompanyExists(for userID: UUID) async throws {
        let existingCompanies: [Company] = try await client
            .from("companies")
            .select()
            .eq("owner_id", value: userID.uuidString)
            .limit(1)
            .execute()
            .value

        guard existingCompanies.isEmpty else { return }

        struct NewCompany: Codable {
            let ownerID: UUID
            let name: String
            let logoURL: String?

            enum CodingKeys: String, CodingKey {
                case ownerID = "owner_id"
                case name
                case logoURL = "logo_url"
            }
        }

        let company: Company = try await client
            .from("companies")
            .insert(NewCompany(ownerID: userID, name: onboardingProfile.primaryName, logoURL: nil))
            .select()
            .single()
            .execute()
            .value

        struct NewMember: Codable {
            let userID: UUID
            let companyID: UUID
            let role: MemberRole

            enum CodingKeys: String, CodingKey {
                case userID = "user_id"
                case companyID = "company_id"
                case role
            }
        }

        _ = try await client
            .from("members")
            .insert(NewMember(userID: userID, companyID: company.id, role: .owner))
            .execute()
    }

    private func uploadReceiptImage(imageData: Data, fileExtension: String) async throws -> URL {
        let path = "\(UUID().uuidString).\(fileExtension)"

        try await client.storage
            .from("receipts")
            .upload(
                path,
                data: imageData,
                options: FileOptions(contentType: mimeType(for: fileExtension))
            )

        return try client.storage
            .from("receipts")
            .getPublicURL(path: path)
    }
    #endif

    private func mimeType(for fileExtension: String) -> String {
        switch fileExtension.lowercased() {
        case "png":
            "image/png"
        case "heic":
            "image/heic"
        default:
            "image/jpeg"
        }
    }

    #if canImport(Supabase)
    #endif

    private func enableLocalAdminMode() {
        defaults.set(true, forKey: "local_admin_enabled")
        defaults.removeObject(forKey: currentLocalAccountEmailKey)
        loadLocalAdminSession()
    }

    private func loadLocalAdminSession() {
        isUsingLocalAdminMode = true
        currentLocalAccountEmail = nil
        authState = .signedIn
        currentCompany = Company(
            id: localCompanyID,
            ownerID: localUserID,
            name: defaults.string(forKey: localAdminCompanyNameKey) ?? onboardingProfile.primaryName,
            logoURL: nil,
            createdAt: .now
        )
        if let currentCompany {
            availableCompanies = [currentCompany]
        }
        loadLocalTransactions()
        loadLocalReceipts()
        Task { await autoCreateDueRecurringTransactions() }
    }

    private func createOrLoadLocalSandboxAccount(email: String, password: String) -> LocalSandboxAccount {
        var accounts = localSandboxAccounts()

        if let existing = accounts[email] {
            return existing
        }

        let company = Company(
            id: UUID(),
            ownerID: UUID(),
            name: onboardingProfile.primaryName,
            logoURL: nil,
            createdAt: .now
        )

        let account = LocalSandboxAccount(
            id: UUID(),
            email: email,
            password: password,
            company: company,
            createdAt: .now
        )
        accounts[email] = account
        saveLocalSandboxAccounts(accounts)
        return account
    }

    private func loadLocalSandboxAccount(_ account: LocalSandboxAccount) {
        isUsingLocalAdminMode = false
        currentLocalAccountEmail = account.email
        defaults.set(account.email, forKey: currentLocalAccountEmailKey)
        defaults.set(false, forKey: "local_admin_enabled")
        authState = .signedIn
        currentCompany = account.company
        availableCompanies = [account.company]
        loadLocalTransactions()
        loadLocalReceipts()
        Task { await autoCreateDueRecurringTransactions() }
    }

    private func localSandboxAccounts() -> [String: LocalSandboxAccount] {
        guard let data = defaults.data(forKey: localAccountsKey) else { return [:] }
        return (try? decoder.decode([String: LocalSandboxAccount].self, from: data)) ?? [:]
    }

    private func saveLocalSandboxAccounts(_ accounts: [String: LocalSandboxAccount]) {
        guard let data = try? encoder.encode(accounts) else { return }
        defaults.set(data, forKey: localAccountsKey)
    }

    private func loadLocalTransactions() {
        let key = localTransactionsKey()
        guard let data = defaults.data(forKey: key) else {
            transactions = []
            return
        }

        do {
            transactions = try decoder.decode([AccountingTransaction].self, from: data)
        } catch {
            transactions = []
        }
    }

    private func loadLocalReceipts() {
        let key = localReceiptsKey()
        guard let data = defaults.data(forKey: key) else {
            receiptsByTransactionID = [:]
            return
        }

        do {
            let receipts = try decoder.decode([Receipt].self, from: data)
            receiptsByTransactionID = Dictionary(uniqueKeysWithValues: receipts.map { ($0.transactionID, $0) })
        } catch {
            receiptsByTransactionID = [:]
        }
    }

    private func saveLocalTransactions() {
        do {
            let data = try encoder.encode(transactions)
            defaults.set(data, forKey: localTransactionsKey())
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveLocalReceipts() {
        do {
            let data = try encoder.encode(Array(receiptsByTransactionID.values))
            defaults.set(data, forKey: localReceiptsKey())
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func scheduleLocalNotifications() {
        guard notificationsEnabled else {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            return
        }

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
            guard granted, let self else { return }
            Task { @MainActor in
                await self.doScheduleNotifications()
            }
        }
    }

    private func doScheduleNotifications() async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        let calendar = Calendar.current
        let today = Date.now
        // Use the user's selected app language for notifications
        // Daily insight at 9:00 AM
        let insightContent = UNMutableNotificationContent()
        insightContent.title = onboardingProfile.text(
            en: "Balance X — Daily Insight",
            es: "Balance X — Consejo del día",
            pt: "Balance X — Insight diário",
            fr: "Balance X — Insight du jour",
            ar: "Balance X — نصيحة اليوم",
            de: "Balance X — Täglicher Hinweis",
            it: "Balance X — Insight del giorno",
            nl: "Balance X — Inzicht van de dag",
            ja: "Balance X — 今日のインサイト",
            ko: "Balance X — 오늘의 인사이트"
        )
        if let insight = transactions.topInsights(period: .monthly, profile: onboardingProfile, currencyCode: onboardingProfile.currencyCode).first {
            insightContent.body = insight.message
        } else {
            insightContent.body = onboardingProfile.text(
                en: "Log income and expenses to receive personalized suggestions.",
                es: "Registra ingresos y gastos para obtener sugerencias personalizadas.",
                pt: "Registre receitas e despesas para receber sugestões personalizadas.",
                fr: "Enregistrez revenus et dépenses pour recevoir des suggestions personnalisées.",
                ar: "سجّل الدخل والمصروفات للحصول على اقتراحات مخصصة.",
                de: "Erfasse Einnahmen und Ausgaben, um personalisierte Vorschläge zu erhalten.",
                it: "Registra entrate e spese per ricevere suggerimenti personalizzati.",
                nl: "Log inkomsten en uitgaven om persoonlijke suggesties te ontvangen.",
                ja: "収入と支出を記録すると、パーソナライズされた提案を受け取れます。",
                ko: "수입과 지출을 기록하면 맞춤 제안을 받을 수 있습니다."
            )
        }
        insightContent.sound = .default
        var dailyComponents = DateComponents()
        dailyComponents.hour = 9
        dailyComponents.minute = 0
        let insightTrigger = UNCalendarNotificationTrigger(dateMatching: dailyComponents, repeats: true)
        let insightRequest = UNNotificationRequest(identifier: "bx.daily.insight", content: insightContent, trigger: insightTrigger)
        try? await center.add(insightRequest)

        // Upcoming payment reminders (3 days before dueDay)
        for subscription in subscriptions {
            let dueDate = nextDueDate(for: subscription, from: today)
            guard let reminderDate = calendar.date(byAdding: .day, value: -3, to: dueDate),
                  reminderDate >= today else { continue }
            let content = UNMutableNotificationContent()
            content.title = onboardingProfile.text(
                en: "Upcoming payment: \(subscription.name)",
                es: "Pago próximo: \(subscription.name)",
                pt: "Próximo pagamento: \(subscription.name)",
                fr: "Paiement à venir : \(subscription.name)",
                ar: "دفعة قادمة: \(subscription.name)",
                de: "Bevorstehende Zahlung: \(subscription.name)",
                it: "Pagamento in arrivo: \(subscription.name)",
                nl: "Aankomende betaling: \(subscription.name)",
                ja: "支払い予定: \(subscription.name)",
                ko: "예정된 결제: \(subscription.name)"
            )
            content.body = onboardingProfile.text(
                en: "\(subscription.name) is due on day \(subscription.dueDay) for \(subscription.amount.currencyString(code: onboardingProfile.currencyCode)).",
                es: "\(subscription.name) vence el día \(subscription.dueDay) por \(subscription.amount.currencyString(code: onboardingProfile.currencyCode)).",
                pt: "\(subscription.name) vence no dia \(subscription.dueDay) no valor de \(subscription.amount.currencyString(code: onboardingProfile.currencyCode)).",
                fr: "\(subscription.name) arrive à échéance le jour \(subscription.dueDay) pour \(subscription.amount.currencyString(code: onboardingProfile.currencyCode)).",
                ar: "يستحق \(subscription.name) في اليوم \(subscription.dueDay) بمبلغ \(subscription.amount.currencyString(code: onboardingProfile.currencyCode)).",
                de: "\(subscription.name) ist am Tag \(subscription.dueDay) über \(subscription.amount.currencyString(code: onboardingProfile.currencyCode)) fällig.",
                it: "\(subscription.name) scade il giorno \(subscription.dueDay) per \(subscription.amount.currencyString(code: onboardingProfile.currencyCode)).",
                nl: "\(subscription.name) vervalt op dag \(subscription.dueDay) voor \(subscription.amount.currencyString(code: onboardingProfile.currencyCode)).",
                ja: "\(subscription.name) は\(subscription.dueDay)日に \(subscription.amount.currencyString(code: onboardingProfile.currencyCode)) の支払い期限です。",
                ko: "\(subscription.name)은 \(subscription.dueDay)일에 \(subscription.amount.currencyString(code: onboardingProfile.currencyCode)) 결제 마감입니다."
            )
            content.sound = .default
            let triggerComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
            let request = UNNotificationRequest(identifier: "bx.payment.\(subscription.id.uuidString)", content: content, trigger: trigger)
            try? await center.add(request)
        }

        // Tax deadline reminder (10 days before)
        let taxDate = nextTaxDueDate(from: today)
        if let taxReminderDate = calendar.date(byAdding: .day, value: -10, to: taxDate), taxReminderDate >= today {
            let taxContent = UNMutableNotificationContent()
            taxContent.title = onboardingProfile.nextTaxReminderTitle
            let estimate = estimatedTaxes.currencyString(code: onboardingProfile.currencyCode)
            taxContent.body = onboardingProfile.text(
                en: "Your estimated tax payment is \(estimate). Due in 10 days.",
                es: "Tu pago estimado es \(estimate). Vence en 10 días.",
                pt: "Seu pagamento estimado de imposto é \(estimate). Vence em 10 dias.",
                fr: "Votre paiement fiscal estimé est de \(estimate). Échéance dans 10 jours.",
                ar: "دفعتك الضريبية التقديرية هي \(estimate). تستحق خلال 10 أيام.",
                de: "Deine geschätzte Steuerzahlung beträgt \(estimate). Fällig in 10 Tagen.",
                it: "Il tuo pagamento fiscale stimato è \(estimate). Scade tra 10 giorni.",
                nl: "Je geschatte belastingbetaling is \(estimate). Vervalt over 10 dagen.",
                ja: "推定納税額は\(estimate)です。期限まで10日です。",
                ko: "예상 세금 납부액은 \(estimate)이며 10일 후 마감됩니다."
            )
            taxContent.sound = .default
            let taxComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: taxReminderDate)
            let taxTrigger = UNCalendarNotificationTrigger(dateMatching: taxComponents, repeats: false)
            let taxRequest = UNNotificationRequest(identifier: "bx.tax.reminder", content: taxContent, trigger: taxTrigger)
            try? await center.add(taxRequest)
        }
    }

    private func saveCustomCategoryIfNeeded(_ name: String) {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedName.isEmpty else { return }
        guard !customCategories.contains(where: { $0.name.caseInsensitiveCompare(cleanedName) == .orderedSame }) else { return }
        customCategories.append(CustomCategory(id: UUID(), name: cleanedName, isHidden: false, createdAt: .now))
        customCategories.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        saveCustomCategories()
    }

    private func setInvitation(_ invitation: TeamInvitation, status: TeamInvitationStatus) {
        guard let index = teamInvitations.firstIndex(where: { $0.id == invitation.id }) else { return }
        teamInvitations[index].status = status
        teamInvitations[index].respondedAt = .now
        saveTeamInvitations()
    }

    private func appendAudit(transactionID: UUID, action: String, detail: String) {
        transactionAuditEntries.insert(
            TransactionAuditEntry(
                id: UUID(),
                transactionID: transactionID,
                action: action,
                detail: detail,
                createdAt: .now
            ),
            at: 0
        )
        if transactionAuditEntries.count > 500 {
            transactionAuditEntries = Array(transactionAuditEntries.prefix(500))
        }
        saveTransactionAudit()
    }

    private func autoCreateDueRecurringTransactions() async {
        let calendar = Calendar.current
        let today = Date.now
        let currentMonth = monthKey(for: today)
        var generatedKeys = Set(defaults.stringArray(forKey: recurringTransactionKeysKey) ?? [])

        for subscription in subscriptions where subscription.dueDay <= calendar.component(.day, from: today) {
            let key = "\(subscription.id.uuidString)-\(currentMonth)"
            guard !generatedKeys.contains(key), !subscription.paidMonths.contains(currentMonth) else { continue }
            generatedKeys.insert(key)
            defaults.set(Array(generatedKeys), forKey: recurringTransactionKeysKey)
            let success = await createTransaction(
                type: .expense,
                vendor: subscription.name,
                amount: subscription.amount,
                category: subscription.category.rawValue,
                date: today,
                notes: subscription.notes
            )
            if !success {
                generatedKeys.remove(key)
            }
        }

        defaults.set(Array(generatedKeys), forKey: recurringTransactionKeysKey)
    }

    private func saveToSupabaseCache() {
        if let data = try? encoder.encode(transactions) {
            defaults.set(data, forKey: supabaseTransactionsCacheKey)
        }
        if let data = try? encoder.encode(Array(receiptsByTransactionID.values)) {
            defaults.set(data, forKey: supabaseReceiptsCacheKey)
        }
        if let data = try? encoder.encode(availableCompanies) {
            defaults.set(data, forKey: supabaseCompaniesCacheKey)
        }
    }

    @discardableResult
    private func loadFromSupabaseCache() -> Bool {
        guard
            let txData = defaults.data(forKey: supabaseTransactionsCacheKey),
            let txns = try? decoder.decode([AccountingTransaction].self, from: txData),
            !txns.isEmpty
        else { return false }

        transactions = txns

        if let rcData = defaults.data(forKey: supabaseReceiptsCacheKey),
           let receipts = try? decoder.decode([Receipt].self, from: rcData) {
            receiptsByTransactionID = Dictionary(
                uniqueKeysWithValues: receipts.map { ($0.transactionID, $0) }
            )
        }

        if let coData = defaults.data(forKey: supabaseCompaniesCacheKey),
           let companies = try? decoder.decode([Company].self, from: coData) {
            availableCompanies = companies
            let selectedID = defaults.string(forKey: selectedCompanyIDKey).flatMap(UUID.init(uuidString:))
            currentCompany = companies.first(where: { $0.id == selectedID }) ?? companies.first
        }

        isOffline = true
        return true
    }

    private func clearSupabaseCache() {
        defaults.removeObject(forKey: supabaseTransactionsCacheKey)
        defaults.removeObject(forKey: supabaseReceiptsCacheKey)
        defaults.removeObject(forKey: supabaseCompaniesCacheKey)
    }

    private func saveSubscriptions() {
        guard let data = try? encoder.encode(subscriptions) else { return }
        defaults.set(data, forKey: subscriptionsKey)
    }

    private func saveBudgets() {
        guard let data = try? encoder.encode(budgets) else { return }
        defaults.set(data, forKey: budgetsKey)
    }

    private func saveSavingsGoals() {
        guard let data = try? encoder.encode(savingsGoals) else { return }
        defaults.set(data, forKey: savingsGoalsKey)
    }

    private func saveCustomCategories() {
        guard let data = try? encoder.encode(customCategories) else { return }
        defaults.set(data, forKey: customCategoriesKey)
    }

    private func saveTeamInvitations() {
        guard let data = try? encoder.encode(teamInvitations) else { return }
        defaults.set(data, forKey: teamInvitationsKey)
    }

    private func saveReconciliationStatuses() {
        guard let data = try? encoder.encode(reconciliationStatuses) else { return }
        defaults.set(data, forKey: reconciliationStatusesKey)
    }

    private func saveTransactionAudit() {
        guard let data = try? encoder.encode(transactionAuditEntries) else { return }
        defaults.set(data, forKey: transactionAuditKey)
    }

    private func nextTaxDueDate(from date: Date) -> Date {
        let calendar = Calendar.current
        let profile = onboardingProfile
        let dueDay = profile.taxDayOfMonth
        let deadlineMonths = profile.taxDeadlineMonths
        let currentYear = calendar.component(.year, from: date)

        // Find the next upcoming deadline month at or after today
        for month in deadlineMonths.sorted() {
            var components = DateComponents()
            components.year = currentYear
            components.month = month
            components.day = dueDay
            if let candidate = calendar.date(from: components), candidate >= date.startOfDay {
                return candidate
            }
        }
        // All deadlines this year have passed — take the first deadline of next year
        let firstMonth = deadlineMonths.sorted().first ?? 4
        var nextComponents = DateComponents()
        nextComponents.year = currentYear + 1
        nextComponents.month = firstMonth
        nextComponents.day = dueDay
        return calendar.date(from: nextComponents) ?? date.addingTimeInterval(86400 * 90)
    }

    private func nextDueDate(for subscription: SubscriptionItem, from date: Date) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month], from: date)
        components.day = min(max(subscription.dueDay, 1), 28)
        let candidate = calendar.date(from: components) ?? date
        if candidate >= date.startOfDay {
            return candidate
        }
        return calendar.date(byAdding: .month, value: 1, to: candidate) ?? candidate
    }

    private func localTransactionsKey() -> String {
        if isUsingLocalAdminMode {
            return "local_admin_transactions"
        }

        return "local_transactions_\(currentLocalAccountEmail ?? "default")"
    }

    private func localReceiptImagesDirectory() throws -> URL {
        let baseDirectory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let folderName: String
        if isUsingLocalAdminMode {
            folderName = "LocalAdminReceipts"
        } else {
            folderName = "LocalReceipts-\(currentLocalAccountEmail ?? "default")"
        }

        let directoryURL = baseDirectory
            .appendingPathComponent("BalanceX", isDirectory: true)
            .appendingPathComponent(folderName, isDirectory: true)

        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }

    private func localReceiptsKey() -> String {
        if isUsingLocalAdminMode {
            return "local_admin_receipts"
        }

        return "local_receipts_\(currentLocalAccountEmail ?? "default")"
    }

    private func runLoadingTask(_ operation: () async throws -> Void) async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await operation()
        } catch {
            errorMessage = userFriendlyMessage(for: error)
        }
    }

    private func runLoadingTaskReturningBool(_ operation: () async throws -> Void) async -> Bool {
        isLoading = true
        defer { isLoading = false }

        do {
            try await operation()
            return true
        } catch {
            errorMessage = userFriendlyMessage(for: error)
            return false
        }
    }

    // MARK: - Social Auth

    func signInWithGoogle() async {
        let googleClientID = "168568714050-qd4gda22otbpl2m0tepo66ht11cta9mj.apps.googleusercontent.com"
        let redirectScheme = "com.googleusercontent.apps.168568714050-qd4gda22otbpl2m0tepo66ht11cta9mj"
        let redirectURI = "\(redirectScheme):/oauth2callback"

        let verifier = pkceVerifier()
        let challenge = pkceChallenge(from: verifier)

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: googleClientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
        ]

        guard let authURL = components.url else { return }
        isLoading = true

        let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: redirectScheme) { [weak self] callbackURL, error in
            Task { @MainActor [weak self] in
                await self?.handleGoogleCallback(
                    callbackURL: callbackURL,
                    error: error,
                    verifier: verifier,
                    redirectURI: redirectURI,
                    clientID: googleClientID
                )
            }
        }
        session.presentationContextProvider = webAuthContext
        session.prefersEphemeralWebBrowserSession = false
        webAuthSession = session
        session.start()
    }

    private func handleGoogleCallback(callbackURL: URL?, error: Error?, verifier: String, redirectURI: String, clientID: String) async {
        defer { isLoading = false }

        if let error {
            if (error as? ASWebAuthenticationSessionError)?.code != .canceledLogin {
                errorMessage = error.localizedDescription
            }
            return
        }

        guard let callbackURL,
              let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                  .queryItems?.first(where: { $0.name == "code" })?.value
        else { return }

        do {
            let tokens = try await exchangeGoogleCode(code, verifier: verifier, redirectURI: redirectURI, clientID: clientID)
            let payload = jwtPayload(from: tokens.idToken)
            let email = payload["email"] as? String ?? "user@google.com"
            let name = payload["name"] as? String ?? ""

            #if canImport(Supabase)
            await runLoadingTask {
                let session = try await client.auth.signInWithIdToken(
                    credentials: OpenIDConnectCredentials(provider: .google, idToken: tokens.idToken)
                )
                isUsingLocalAdminMode = false
                currentLocalAccountEmail = nil
                defaults.removeObject(forKey: currentLocalAccountEmailKey)
                authState = .signedIn
                try? await ensureDefaultCompanyExists(for: session.user.id)
                await refreshDashboard()
            }
            #else
            finishSocialSignIn(email: email, name: name)
            #endif
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Call this from onRequest to configure the ASAuthorizationAppleIDRequest nonce.
    /// Returns the hashed nonce to pass to Apple; the raw nonce is stored internally.
    func prepareAppleNonce() -> String {
        pendingAppleNonce = randomNonce()
        return sha256(of: pendingAppleNonce)
    }

    func handleAppleSignIn(result: Result<ASAuthorization, Error>) async {
        switch result {
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code != .canceled {
                errorMessage = error.localizedDescription
            }
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else { return }
            // Apple only provides email on the very first authentication; use the stable user ID as fallback key
            let email = credential.email ?? "\(credential.user)@privaterelay.appleid.com"
            let givenName = credential.fullName?.givenName ?? ""
            let familyName = credential.fullName?.familyName ?? ""
            let fullName = [givenName, familyName].filter { !$0.isEmpty }.joined(separator: " ")

            guard let identityTokenData = credential.identityToken,
                  let idToken = String(data: identityTokenData, encoding: .utf8) else {
                errorMessage = "Apple no devolvió un token de identidad válido."
                return
            }

            let rawNonce = pendingAppleNonce

            #if canImport(Supabase)
            await runLoadingTask {
                let session = try await client.auth.signInWithIdToken(
                    credentials: OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: rawNonce)
                )
                isUsingLocalAdminMode = false
                currentLocalAccountEmail = nil
                defaults.removeObject(forKey: currentLocalAccountEmailKey)
                authState = .signedIn
                try? await ensureDefaultCompanyExists(for: session.user.id)
                await refreshDashboard()
                // Apple only provides email + fullName on first authentication (new user)
                if credential.email != nil {
                    await triggerEmail(type: "welcome", to: email, name: fullName)
                }
            }
            #else
            finishSocialSignIn(email: email, name: fullName)
            #endif
        }
    }

    private func finishSocialSignIn(email: String, name: String) {
        let account = createOrLoadLocalSandboxAccount(email: email, password: UUID().uuidString)
        loadLocalSandboxAccount(account)
    }

    // MARK: - PKCE + JWT Helpers

    private func pkceVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func pkceChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    func randomNonce() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    func sha256(of string: String) -> String {
        let data = Data(string.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    private struct GoogleTokens {
        let idToken: String
        let accessToken: String
    }

    private func exchangeGoogleCode(_ code: String, verifier: String, redirectURI: String, clientID: String) async throws -> GoogleTokens {
        let bodyParams: [String: String] = [
            "code": code,
            "client_id": clientID,
            "redirect_uri": redirectURI,
            "grant_type": "authorization_code",
            "code_verifier": verifier,
        ]
        let bodyString = bodyParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")

        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyString.data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]

        guard let idToken = json["id_token"] as? String,
              let accessToken = json["access_token"] as? String else {
            throw URLError(.badServerResponse)
        }
        return GoogleTokens(idToken: idToken, accessToken: accessToken)
    }

    private func jwtPayload(from token: String) -> [String: Any] {
        let parts = token.split(separator: ".").map(String.init)
        guard parts.count >= 2 else { return [:] }
        var base64 = parts[1]
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64 += "=" }
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }
        return json
    }

    // MARK: - Net Worth

    func addNetWorthAccount(name: String, category: NetWorthCategory, balance: Decimal) {
        let account = NetWorthAccount(id: UUID(), name: name, category: category, balance: balance, createdAt: .now, updatedAt: .now)
        netWorthAccounts.append(account)
        netWorthAccounts.sort { $0.category.accountType.rawValue < $1.category.accountType.rawValue }
        saveNetWorthAccounts()
    }

    func updateNetWorthAccount(_ account: NetWorthAccount, name: String, category: NetWorthCategory, balance: Decimal) {
        guard let index = netWorthAccounts.firstIndex(where: { $0.id == account.id }) else { return }
        netWorthAccounts[index].name = name
        netWorthAccounts[index].category = category
        netWorthAccounts[index].balance = balance
        netWorthAccounts[index].updatedAt = .now
        saveNetWorthAccounts()
    }

    func deleteNetWorthAccount(_ account: NetWorthAccount) {
        netWorthAccounts.removeAll { $0.id == account.id }
        saveNetWorthAccounts()
    }

    var netWorth: Decimal {
        let assets = netWorthAccounts.filter { $0.type == .asset }.reduce(Decimal.zero) { $0 + $1.balance }
        let liabilities = netWorthAccounts.filter { $0.type == .liability }.reduce(Decimal.zero) { $0 + $1.balance }
        return assets - liabilities
    }

    private func saveNetWorthAccounts() {
        guard let data = try? encoder.encode(netWorthAccounts) else { return }
        defaults.set(data, forKey: netWorthAccountsKey)
    }

    // MARK: - Demo Data

    func loadDemoData() {
        let calendar = Calendar.current
        let now = Date()
        func date(_ daysAgo: Int) -> Date { calendar.date(byAdding: .day, value: -daysAgo, to: now) ?? now }
        let cc = onboardingProfile.currencyCode
        _ = cc

        let samples: [(TransactionType, String, Decimal, String, Date)] = [
            (.income,  "Salary",          3500.00, "Income",      date(1)),
            (.income,  "Freelance",        750.00, "Income",      date(5)),
            (.expense, "Rent",            1200.00, "Housing",     date(2)),
            (.expense, "Groceries",        185.40, "Food",        date(3)),
            (.expense, "Netflix",           15.99, "Subscriptions", date(4)),
            (.expense, "Electricity",       82.00, "Utilities",   date(6)),
            (.expense, "Gym",               45.00, "Health",      date(7)),
            (.expense, "Restaurant",        67.50, "Food",        date(8)),
            (.expense, "Gas",               55.00, "Transport",   date(9)),
            (.expense, "Pharmacy",          32.00, "Health",      date(10)),
            (.expense, "Coffee",            18.00, "Food",        date(12)),
            (.expense, "Clothes",          120.00, "Shopping",    date(14)),
            (.income,  "Transfer",         200.00, "Income",      date(15)),
            (.expense, "Internet",          49.99, "Utilities",   date(16)),
            (.expense, "Spotify",            9.99, "Subscriptions", date(17)),
        ]

        for (type, vendor, amount, category, txDate) in samples {
            let tx = AccountingTransaction(
                id: UUID(),
                companyID: currentCompany?.id ?? localCompanyID,
                type: type,
                amount: amount,
                vendor: vendor,
                category: category,
                date: txDate,
                notes: nil,
                createdAt: .now
            )
            transactions.append(tx)
        }
        transactions.sort { $0.date > $1.date }
        saveLocalTransactions()
    }

    // MARK: - iCloud Key-Value Sync

    private func syncToiCloud() {
        guard let data = try? encoder.encode(onboardingProfile) else { return }
        NSUbiquitousKeyValueStore.default.set(data, forKey: onboardingProfileKey)
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    private func syncFromiCloud() {
        // Only restore if local profile is the default (empty names)
        guard onboardingProfile.personName.isEmpty,
              let data = NSUbiquitousKeyValueStore.default.data(forKey: onboardingProfileKey),
              let profile = try? decoder.decode(OnboardingProfile.self, from: data)
        else { return }
        onboardingProfile = profile
        if let encoded = try? encoder.encode(profile) {
            defaults.set(encoded, forKey: onboardingProfileKey)
        }
    }

    // MARK: - Push Notifications (APNs)

    func registerForPushNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }

        NotificationCenter.default.addObserver(forName: .bxDeviceToken, object: nil, queue: nil) { [weak self] note in
            guard let token = note.object as? String else { return }
            Task { @MainActor [weak self] in
                self?.deviceToken = token
                self?.defaults.set(token, forKey: self?.deviceTokenKey ?? "bx_apns_device_token")
            }
        }
    }

    func sendPushNotification(title: String, body: String, data: [String: Any] = [:]) async {
        guard let token = deviceToken, !token.isEmpty,
              let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              !urlString.isEmpty,
              let supabaseURL = URL(string: urlString),
              let publishableKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String,
              !publishableKey.isEmpty
        else { return }
        let payload: [String: Any] = ["token": token, "title": title, "body": body, "data": data]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: payload) else { return }
        let url = supabaseURL.appendingPathComponent("functions/v1/send-push")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(publishableKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData
        _ = try? await URLSession.shared.data(for: request)
    }

    // MARK: - Email

    @discardableResult
    private func triggerEmail(type: String, to: String, name: String, extraData: [String: Any] = [:]) async -> String? {
        guard
            let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            !urlString.isEmpty,
            let supabaseURL = URL(string: urlString),
            let publishableKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String,
            !publishableKey.isEmpty
        else {
            print("[BX Email] Missing SUPABASE_URL or SUPABASE_PUBLISHABLE_KEY in Info.plist")
            return "Config missing: SUPABASE_URL or SUPABASE_PUBLISHABLE_KEY not set in Info.plist"
        }

        let langMap: [String: String] = [
            "English": "en", "Spanish": "es", "Portuguese": "pt", "French": "fr",
            "Arabic": "ar", "German": "de", "Italian": "it", "Dutch": "nl",
            "Japanese": "ja", "Korean": "ko"
        ]
        let lang = langMap[onboardingProfile.language] ?? "en"

        var body: [String: Any] = ["type": type, "to": to, "name": name, "lang": lang]
        if !extraData.isEmpty { body["data"] = extraData }

        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            return "Failed to serialize request body"
        }

        let url = supabaseURL.appendingPathComponent("functions/v1/send-email")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(publishableKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            if status >= 200 && status < 300 {
                print("[BX Email] Sent '\(type)' to \(to) — HTTP \(status)")
                return nil
            } else {
                print("[BX Email] Error HTTP \(status): \(responseBody)")
                return "HTTP \(status): \(responseBody)"
            }
        } catch {
            print("[BX Email] Network error: \(error.localizedDescription)")
            return "Network error: \(error.localizedDescription)"
        }
    }

    func sendPerformanceEmail() async -> String? {
        var recipientEmail = currentLocalAccountEmail ?? ""
        #if canImport(Supabase)
        if let sessionEmail = try? await client.auth.session.user.email {
            recipientEmail = sessionEmail
        }
        #endif
        guard !recipientEmail.isEmpty else {
            return "No email address — sign in or set an account email first"
        }

        let data: [String: Any] = [
            "income": (analytics.totalIncome as NSDecimalNumber).doubleValue,
            "expenses": (analytics.totalExpenses as NSDecimalNumber).doubleValue,
            "balance": ((analytics.totalIncome - analytics.totalExpenses) as NSDecimalNumber).doubleValue,
            "currency": onboardingProfile.currencyCode
        ]
        return await triggerEmail(type: "performance", to: recipientEmail, name: onboardingProfile.personName, extraData: data)
    }

    func sendTestEmail(to address: String) async -> String? {
        return await triggerEmail(type: "welcome", to: address, name: "Homer")
    }

    func setEmailMonthlyReport(_ enabled: Bool) {
        emailMonthlyReportEnabled = enabled
        defaults.set(enabled, forKey: emailMonthlyReportKey)
    }

    func setEmailExpenseAlert(enabled: Bool, threshold: Double) {
        emailExpenseAlertEnabled = enabled
        emailExpenseAlertThreshold = threshold
        defaults.set(enabled, forKey: emailExpenseAlertKey)
        defaults.set(threshold, forKey: emailExpenseThresholdKey)
    }

    func checkExpenseAlertIfNeeded() {
        guard emailExpenseAlertEnabled else { return }
        let monthlyExpenses = (analytics.totalExpenses as NSDecimalNumber).doubleValue
        guard monthlyExpenses >= emailExpenseAlertThreshold else { return }
        Task {
            var recipientEmail = currentLocalAccountEmail ?? ""
            #if canImport(Supabase)
            if let sessionEmail = try? await client.auth.session.user.email {
                recipientEmail = sessionEmail
            }
            #endif
            guard !recipientEmail.isEmpty else { return }
            await triggerEmail(
                type: "performance",
                to: recipientEmail,
                name: onboardingProfile.personName,
                extraData: [
                    "income": (analytics.totalIncome as NSDecimalNumber).doubleValue,
                    "expenses": monthlyExpenses,
                    "balance": ((analytics.totalIncome - analytics.totalExpenses) as NSDecimalNumber).doubleValue,
                    "currency": onboardingProfile.currencyCode,
                    "alertType": "expense_limit"
                ]
            )
        }
    }

    private func userFriendlyMessage(for error: Error) -> String {
        let message = error.localizedDescription
        let lowercase = message.lowercased()
        if lowercase.contains("missing session")
            || lowercase.contains("no session found")
            || lowercase.contains("no current session")
            || lowercase.contains("auth session missing") {
            // Session expired — update auth state so UI shows login screen
            authState = .signedOut
            return onboardingProfile.text(en: "Your session has expired. Please sign in again.", es: "Tu sesión ha expirado. Por favor inicia sesión nuevamente.", pt: "Sua sessão expirou. Faça login novamente.", fr: "Votre session a expiré. Veuillez vous reconnecter.", ar: "انتهت جلستك. يرجى تسجيل الدخول مرة أخرى.", de: "Deine Sitzung ist abgelaufen. Bitte melde dich erneut an.", it: "La tua sessione è scaduta. Accedi di nuovo.", nl: "Je sessie is verlopen. Log opnieuw in.", ja: "セッションの有効期限が切れました。もう一度サインインしてください。", ko: "세션이 만료되었습니다. 다시 로그인하세요.")
        }

        if lowercase.contains("security purposes")
            || lowercase.contains("rate limit")
            || lowercase.contains("email rate limit")
            || lowercase.contains("over_email_send_rate_limit")
            || lowercase.contains("too many requests") {
            return onboardingProfile.text(en: "Too many attempts. Please wait a moment and try again.", es: "Demasiados intentos. Espera un momento e intenta de nuevo.", pt: "Muitas tentativas. Aguarde um momento e tente novamente.", fr: "Trop de tentatives. Attendez un instant puis réessayez.", ar: "محاولات كثيرة جدًا. انتظر قليلًا ثم حاول مرة أخرى.", de: "Zu viele Versuche. Bitte warte kurz und versuche es erneut.", it: "Troppi tentativi. Attendi un momento e riprova.", nl: "Te veel pogingen. Wacht even en probeer opnieuw.", ja: "試行回数が多すぎます。少し待ってから再試行してください。", ko: "시도가 너무 많습니다. 잠시 후 다시 시도하세요.")
        }

        if lowercase.contains("email not confirmed") {
            return onboardingProfile.text(en: "Your email is not yet confirmed. Check your inbox.", es: "Tu correo aún no está confirmado. Revisa tu bandeja de entrada.", pt: "Seu e-mail ainda não foi confirmado. Verifique sua caixa de entrada.", fr: "Votre e-mail n'est pas encore confirmé. Vérifiez votre boîte de réception.", ar: "بريدك الإلكتروني غير مؤكد بعد. تحقق من صندوق الوارد.", de: "Deine E-Mail ist noch nicht bestätigt. Prüfe deinen Posteingang.", it: "La tua email non è ancora stata confermata. Controlla la posta in arrivo.", nl: "Je e-mail is nog niet bevestigd. Controleer je inbox.", ja: "メールアドレスはまだ確認されていません。受信トレイを確認してください。", ko: "이메일이 아직 확인되지 않았습니다. 받은편지함을 확인하세요.")
        }

        if lowercase.contains("invalid login credentials") {
            return onboardingProfile.text(en: "Invalid login credentials.", es: "Credenciales inválidas.", pt: "Credenciais de login inválidas.", fr: "Identifiants de connexion invalides.", ar: "بيانات تسجيل الدخول غير صالحة.", de: "Ungültige Anmeldedaten.", it: "Credenziali di accesso non valide.", nl: "Ongeldige inloggegevens.", ja: "ログイン情報が無効です。", ko: "로그인 자격 증명이 올바르지 않습니다.")
        }

        if lowercase.contains("network") || lowercase.contains("internet") || lowercase.contains("offline") {
            return onboardingProfile.text(en: "No internet connection. Check your network.", es: "Sin conexión a internet. Revisa tu red.", pt: "Sem conexão com a internet. Verifique sua rede.", fr: "Pas de connexion Internet. Vérifiez votre réseau.", ar: "لا يوجد اتصال بالإنترنت. تحقق من الشبكة.", de: "Keine Internetverbindung. Prüfe dein Netzwerk.", it: "Nessuna connessione a Internet. Controlla la rete.", nl: "Geen internetverbinding. Controleer je netwerk.", ja: "インターネット接続がありません。ネットワークを確認してください。", ko: "인터넷 연결이 없습니다. 네트워크를 확인하세요.")
        }

        return message
    }

}

// MARK: - Web Auth Presentation Context

final class BXWebAuthContext: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let allWindows = scenes.flatMap { $0.windows }
        if let keyWindow = allWindows.first(where: { $0.isKeyWindow }) { return keyWindow }
        if let anyWindow = allWindows.first { return anyWindow }
        // Always has at least one scene while the app is running
        return UIWindow(windowScene: scenes[0])
    }
}

// MARK: - Supabase Configuration

struct SupabaseConfiguration {
    let url: URL
    let publishableKey: String

    static func load() -> SupabaseConfiguration {
        guard
            let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            !urlString.isEmpty,
            let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String,
            !key.isEmpty
        else {
            fatalError("SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY must be set in Info.plist")
        }

        guard let url = URL(string: urlString) else {
            fatalError("Invalid SUPABASE_URL configuration")
        }

        return SupabaseConfiguration(url: url, publishableKey: key)
    }
}
