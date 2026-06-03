import Combine
import LocalAuthentication
import SwiftUI
import UserNotifications

@main
struct Balance_XApp: App {
    @UIApplicationDelegateAdaptor(BXAppDelegate.self) var appDelegate
    @StateObject private var supabaseManager = SupabaseManager()
    @StateObject private var appSession = AppSession()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(supabaseManager)
                .environmentObject(appSession)
                .onContinueUserActivity("com.bx.add-expense") { _ in
                    NotificationCenter.default.post(name: .bxOpenAddExpense, object: nil)
                }
                .onContinueUserActivity("com.bx.view-balance") { _ in
                    NotificationCenter.default.post(name: .bxOpenDashboard, object: nil)
                }
        }
    }
}

// MARK: - App Delegate

final class BXAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        NotificationCenter.default.post(name: .bxDeviceToken, object: tokenString)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[BX APNs] Registration failed: \(error.localizedDescription)")
    }

    // Show notifications even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let action = response.notification.request.content.userInfo["action"] as? String
        switch action {
        case "add_expense":
            NotificationCenter.default.post(name: .bxOpenAddExpense, object: nil)
        case "view_balance":
            NotificationCenter.default.post(name: .bxOpenDashboard, object: nil)
        default: break
        }
        completionHandler()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let bxDeviceToken  = Notification.Name("bxDeviceToken")
    static let bxOpenAddExpense = Notification.Name("bxOpenAddExpense")
    static let bxOpenDashboard  = Notification.Name("bxOpenDashboard")
}

@MainActor
final class AppSession: ObservableObject {
    @Published var isResetting = false

    func performRestart() {
        isResetting = true
        Task {
            try? await Task.sleep(for: .milliseconds(1800))
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.5)) {
                    isResetting = false
                }
            }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var supabase: SupabaseManager
    @EnvironmentObject private var appSession: AppSession
    @Environment(\.scenePhase) private var scenePhase
    @State private var isUnlocked = false
    @State private var authFailed = false
    @State private var deepLinkAddExpense = false

    var body: some View {
        ZStack {
            if appSession.isResetting {
                BXRestartSplash()
                    .transition(.opacity)
            } else if supabase.biometricLockEnabled && !isUnlocked {
                BXLockScreen(
                    authFailed: $authFailed,
                    onBiometric: { authenticate() }
                )
                .transition(.opacity)
            } else {
                ContentView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.45), value: appSession.isResetting)
        .animation(.easeInOut(duration: 0.3), value: isUnlocked)
        .animation(.easeInOut(duration: 0.25), value: authFailed)
        .onAppear {
            if supabase.biometricLockEnabled {
                authenticate()
            } else {
                isUnlocked = true
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                // Re-lock when app goes to background (if biometric is enabled)
                if supabase.biometricLockEnabled {
                    withAnimation { isUnlocked = false }
                    authFailed = false
                }
            case .active:
                // Trigger auth when returning to foreground while locked
                if supabase.biometricLockEnabled && !isUnlocked {
                    authenticate()
                } else if !supabase.biometricLockEnabled {
                    isUnlocked = true
                }
            default:
                break
            }
        }
        .onChange(of: supabase.biometricLockEnabled) { _, enabled in
            if !enabled {
                // Biometric turned off — unlock immediately
                isUnlocked = true
                authFailed = false
            }
            // When turned ON, the lock takes effect on next background→active cycle
            // so the user isn't immediately kicked out while using the app
        }
        .onReceive(NotificationCenter.default.publisher(for: .bxOpenAddExpense)) { _ in
            deepLinkAddExpense = true
        }
        .sheet(isPresented: $deepLinkAddExpense) {
            AddExpenseView()
        }
    }

    /// Uses .deviceOwnerAuthentication — Face ID first, passcode fallback (handled by iOS).
    private func authenticate() {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // Device has no passcode and no biometrics — allow entry
            isUnlocked = true
            return
        }
        context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: supabase.onboardingProfile.text(
                en: "Unlock Balance X to access your financial data",
                es: "Desbloquea Balance X para acceder a tus datos financieros",
                pt: "Desbloqueie o Balance X para acessar seus dados financeiros",
                fr: "Déverrouillez Balance X pour accéder à vos données financières",
                ar: "افتح Balance X للوصول إلى بياناتك المالية",
                de: "Entsperre Balance X, um auf deine Finanzdaten zuzugreifen",
                it: "Sblocca Balance X per accedere ai tuoi dati finanziari",
                nl: "Ontgrendel Balance X om toegang te krijgen tot je financiële gegevens",
                ja: "財務データにアクセスするには Balance X をロック解除してください",
                ko: "금융 데이터에 접근하려면 Balance X의 잠금을 해제하세요"
            )
        ) { success, _ in
            DispatchQueue.main.async {
                if success {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.isUnlocked = true
                    }
                    self.authFailed = false
                } else {
                    self.authFailed = true
                }
            }
        }
    }
}

private struct BXLockScreen: View {
    @EnvironmentObject private var supabase: SupabaseManager
    @Binding var authFailed: Bool
    let onBiometric: () -> Void

    private var biometricType: String {
        let ctx = LAContext(); var e: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &e) else { return "Passcode" }
        return ctx.biometryType == .faceID ? "Face ID" : "Touch ID"
    }

    private var biometricIcon: String {
        let ctx = LAContext(); var e: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &e) else { return "lock.shield" }
        return ctx.biometryType == .faceID ? "faceid" : "touchid"
    }

    var body: some View {
        ZStack {
            BXBackground()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    BXNeuronLogo(size: 80)

                    VStack(spacing: 6) {
                        Text("Balance X")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(BXPalette.textPrimary)
                        Text(supabase.onboardingProfile.text(en: "Workspace locked", es: "Espacio bloqueado", pt: "Espaço bloqueado", fr: "Espace verrouillé", ar: "مساحة العمل مقفلة", de: "Arbeitsbereich gesperrt", it: "Spazio bloccato", nl: "Werkruimte vergrendeld", ja: "ワークスペースはロックされています", ko: "작업 공간이 잠겨 있습니다"))
                            .font(.subheadline)
                            .foregroundStyle(BXPalette.textSecondary)
                    }

                    Image(systemName: biometricIcon)
                        .font(.system(size: 56))
                        .foregroundStyle(BXPalette.accentStart)
                        .symbolEffect(.pulse)
                        .padding(.top, 4)
                }

                Spacer()

                VStack(spacing: 14) {
                    if authFailed {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle")
                                .font(.caption.weight(.semibold))
                            Text(supabase.onboardingProfile.text(en: "Authentication failed. Try again.", es: "Autenticación fallida. Inténtalo de nuevo.", pt: "Falha na autenticação. Tente novamente.", fr: "Échec de l'authentification. Réessayez.", ar: "فشلت المصادقة. حاول مرة أخرى.", de: "Authentifizierung fehlgeschlagen. Versuche es erneut.", it: "Autenticazione non riuscita. Riprova.", nl: "Authenticatie mislukt. Probeer het opnieuw.", ja: "認証に失敗しました。もう一度お試しください。", ko: "인증에 실패했습니다. 다시 시도하세요."))
                                .font(.caption.weight(.medium))
                        }
                        .foregroundStyle(BXPalette.expense)
                        .multilineTextAlignment(.center)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // One button — iOS presents Face ID/Touch ID first, then passcode automatically
                    Button(action: onBiometric) {
                        HStack(spacing: 10) {
                            Image(systemName: biometricIcon)
                                .font(.subheadline.weight(.semibold))
                            Text(supabase.onboardingProfile.text(en: "Unlock with \(biometricType)", es: "Desbloquear con \(biometricType)", pt: "Desbloquear com \(biometricType)", fr: "Déverrouiller avec \(biometricType)", ar: "إلغاء القفل باستخدام \(biometricType)", de: "Mit \(biometricType) entsperren", it: "Sblocca con \(biometricType)", nl: "Ontgrendel met \(biometricType)", ja: "\(biometricType)でロック解除", ko: "\(biometricType)(으)로 잠금 해제"))
                                .font(.headline.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(BXPalette.accentGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: BXPalette.accentStart.opacity(0.30), radius: 10, y: 5)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 52)
            }
        }
    }
}

private struct BXRestartSplash: View {
    @EnvironmentObject private var supabase: SupabaseManager
    @State private var billProgress: CGFloat = 0
    @State private var wordmarkProgress: CGFloat = 0
    @State private var opacity = 0.0

    var body: some View {
        ZStack {
            BXBackground()

            VStack(spacing: 20) {
                BXAnimatedBillLogo(progress: billProgress)
                    .frame(width: 120, height: 120)

                BXFormingWordmark(progress: wordmarkProgress, fontSize: 42)
                    .frame(width: 240)

                ProgressView()
                    .tint(BXPalette.accentStart)
                    .scaleEffect(1.1)
                    .padding(.top, 8)

                Text(supabase.onboardingProfile.text(en: "Applying changes...", es: "Aplicando cambios...", pt: "Aplicando alterações...", fr: "Application des modifications...", ar: "جارٍ تطبيق التغييرات...", de: "Änderungen werden angewendet...", it: "Applicazione delle modifiche...", nl: "Wijzigingen toepassen...", ja: "変更を適用しています...", ko: "변경 사항을 적용하는 중..."))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(BXPalette.textSecondary)
            }
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.25)) {
                opacity = 1.0
            }
            withAnimation(.easeInOut(duration: 1.05)) {
                billProgress = 1.0
            }
            withAnimation(.easeInOut(duration: 0.9).delay(0.45)) {
                wordmarkProgress = 1.0
            }
        }
    }
}
