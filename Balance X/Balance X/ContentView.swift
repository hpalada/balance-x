import AuthenticationServices
import PhotosUI
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Content View

struct ContentView: View {
    @EnvironmentObject private var supabase: SupabaseManager
    @EnvironmentObject private var appSession: AppSession
    @AppStorage("bx.hasSeenWelcome") private var hasSeenWelcome = false
    @AppStorage("bx.hasSeenLaunchChoice") private var hasSeenLaunchChoice = false
    @State private var showSplash = true
    @State private var showThinkRicherStatement = false
    @State private var showIntroSlides = false
    @State private var isNewUser = false
    @State private var splashButtonsVisible = false

    var body: some View {
        ZStack {
            BXBackground()

            if showSplash {
                BXSplashView(
                    showButtons: splashButtonsVisible,
                    onNewUser: {
                        hasSeenLaunchChoice = true
                        withAnimation(.easeInOut(duration: 0.4)) {
                            isNewUser = true
                            showSplash = false
                            showThinkRicherStatement = true
                        }
                    },
                    onExistingUser: {
                        hasSeenLaunchChoice = true
                        withAnimation(.easeInOut(duration: 0.4)) {
                            isNewUser = false
                            showSplash = false
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else if showThinkRicherStatement {
                BXThinkRicherStatementView {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        showThinkRicherStatement = false
                        showIntroSlides = true
                    }
                }
                .transition(.opacity)
            } else if showIntroSlides {
                BXIntroSlidesView {
                    withAnimation(.easeInOut(duration: 0.4)) { showIntroSlides = false }
                }
                .environmentObject(supabase)
                .transition(.opacity)
            } else if supabase.authState == .signedOut {
                BXAuthView(isNewUser: isNewUser)
                    .environmentObject(supabase)
                    .transition(.opacity)
            } else {
                BXAppShell(showWelcome: Binding(
                    get: { !hasSeenWelcome && supabase.onboardingProfile.personName.trimmingCharacters(in: .whitespaces).isEmpty },
                    set: { showIt in if !showIt { hasSeenWelcome = true } }
                ))
                .environmentObject(supabase)
                .environmentObject(appSession)
                .transition(.opacity)
            }
        }
        .task {
            async let bootstrap: Void = supabase.bootstrap()
            async let minimumSplash: Void = waitForLaunchAnimation()
            _ = await (bootstrap, minimumSplash)
            configureLaunchFlowAfterBootstrap()
        }
        .alert(supabase.onboardingProfile.text(en: "Error", es: "Error", pt: "Erro", fr: "Erreur", ar: "خطأ", de: "Fehler", it: "Errore", nl: "Fout", ja: "エラー", ko: "오류"), isPresented: Binding(
            get: { supabase.errorMessage != nil },
            set: { newValue in if !newValue { supabase.errorMessage = nil } }
        )) {
            Button(supabase.onboardingProfile.text(en: "OK", es: "OK", pt: "OK", fr: "OK", ar: "حسنًا", de: "OK", it: "OK", nl: "OK", ja: "OK", ko: "확인"), role: .cancel) {}
        } message: {
            Text(supabase.errorMessage ?? "")
        }
    }

    private func runSplashSequence() {
        guard showSplash else { return }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.78)) {
            splashButtonsVisible = true
        }
    }

    private func waitForLaunchAnimation() async {
        try? await Task.sleep(for: .milliseconds(1600))
    }

    private func hideLaunchSplash() {
        withAnimation(.easeInOut(duration: 0.35)) {
            showSplash = false
            showThinkRicherStatement = false
            showIntroSlides = false
            splashButtonsVisible = false
        }
    }

    private func configureLaunchFlowAfterBootstrap() {
        if supabase.authState == .signedIn {
            hasSeenLaunchChoice = true
            hideLaunchSplash()
            return
        }

        if hasSeenLaunchChoice {
            hideLaunchSplash()
            return
        }

        runSplashSequence()
    }
}

// MARK: - Google Logo

/// Google "G" logo — matches the style of the official Sign in with Google button.
private struct BXGoogleLogo: View {
    var body: some View {
        ZStack {
            // Colored left arc (matches Google's logo arc)
            Circle()
                .trim(from: 0.55, to: 1.0)
                .stroke(Color(red: 0.26, green: 0.52, blue: 0.96), lineWidth: 3.5) // blue
                .rotationEffect(.degrees(-90))
            Circle()
                .trim(from: 0.0, to: 0.25)
                .stroke(Color(red: 0.92, green: 0.26, blue: 0.21), lineWidth: 3.5) // red
                .rotationEffect(.degrees(-90))
            Circle()
                .trim(from: 0.25, to: 0.42)
                .stroke(Color(red: 0.98, green: 0.74, blue: 0.02), lineWidth: 3.5) // yellow
                .rotationEffect(.degrees(-90))
            Circle()
                .trim(from: 0.42, to: 0.55)
                .stroke(Color(red: 0.20, green: 0.66, blue: 0.33), lineWidth: 3.5) // green
                .rotationEffect(.degrees(-90))

            // Crossbar — white rect covering right half center
            Rectangle()
                .fill(Color.white)
                .frame(width: 9, height: 6)
                .offset(x: 4.5)
        }
        .compositingGroup()
    }
}

// MARK: - Auth View

private struct BXAuthView: View {
    var isNewUser: Bool = false
    @EnvironmentObject private var supabase: SupabaseManager
    @State private var email = ""
    @State private var password = ""
    @State private var localIsNewUser: Bool = false
    @State private var resetPasswordSent = false

    private var p: OnboardingProfile { supabase.onboardingProfile }

    var body: some View {
        ZStack {
            BXBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 72)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(localIsNewUser
                             ? p.text(en: "Create account",        es: "Crea tu cuenta",      pt: "Criar conta",          fr: "Créer un compte", ar: "إنشاء حساب", de: "Konto erstellen", it: "Crea account", nl: "Account aanmaken", ja: "アカウント作成", ko: "계정 만들기")
                             : p.text(en: "Welcome back",          es: "Hola de nuevo",        pt: "Bem-vindo de volta",   fr: "Bon retour", ar: "مرحبًا بعودتك", de: "Willkommen zurück", it: "Bentornato", nl: "Welkom terug", ja: "おかえりなさい", ko: "다시 오신 것을 환영합니다"))
                            .font(BXFont.display(size: 40))
                            .foregroundStyle(.white)
                        Text(localIsNewUser
                             ? p.text(en: "Get started with Balance X", es: "Empieza con Balance X", pt: "Comece com Balance X", fr: "Démarrez avec Balance X", ar: "ابدأ مع Balance X", de: "Starte mit Balance X", it: "Inizia con Balance X", nl: "Begin met Balance X", ja: "Balance Xを始める", ko: "Balance X 시작하기")
                             : p.text(en: "Sign in to Balance X",       es: "Inicia sesión en Balance X", pt: "Entre no Balance X", fr: "Connectez-vous à Balance X", ar: "سجّل الدخول إلى Balance X", de: "Bei Balance X anmelden", it: "Accedi a Balance X", nl: "Inloggen bij Balance X", ja: "Balance Xにサインイン", ko: "Balance X에 로그인"))
                            .font(.subheadline)
                            .foregroundStyle(BXPalette.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 40)

                    // Auth stack
                    VStack(spacing: 12) {

                        // Apple
                        SignInWithAppleButton(localIsNewUser ? .signUp : .signIn) { request in
                            request.requestedScopes = [.email, .fullName]
                            request.nonce = supabase.prepareAppleNonce()
                        } onCompletion: { result in
                            Task { await supabase.handleAppleSignIn(result: result) }
                        }
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                        // Google
                        Button {
                            Task { await supabase.signInWithGoogle() }
                        } label: {
                            HStack(spacing: 10) {
                                BXGoogleLogo()
                                    .frame(width: 22, height: 22)
                                Text(p.text(en: "Continue with Google", es: "Continuar con Google", pt: "Continuar com Google", fr: "Continuer avec Google", ar: "المتابعة باستخدام Google", de: "Mit Google fortfahren", it: "Continua con Google", nl: "Doorgaan met Google", ja: "Googleで続ける", ko: "Google로 계속"))
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(Color(red: 0.13, green: 0.13, blue: 0.13))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }

                        // Divider
                        HStack(spacing: 12) {
                            Rectangle().fill(Color.white.opacity(0.10)).frame(height: 0.5)
                            Text(p.text(en: "or with email", es: "o con correo", pt: "ou com email", fr: "ou avec email", ar: "أو عبر البريد الإلكتروني", de: "oder mit E-Mail", it: "o con email", nl: "of met e-mail", ja: "またはメールで", ko: "또는 이메일로"))
                                .font(.caption.weight(.medium))
                                .foregroundStyle(BXPalette.textSecondary)
                                .fixedSize()
                            Rectangle().fill(Color.white.opacity(0.10)).frame(height: 0.5)
                        }

                        // Email field
                        VStack(alignment: .leading, spacing: 6) {
                            Text(p.text(en: "EMAIL", es: "CORREO", pt: "EMAIL", fr: "EMAIL", ar: "البريد الإلكتروني", de: "E-MAIL", it: "EMAIL", nl: "E-MAIL", ja: "メール", ko: "이메일"))
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(BXPalette.textSecondary)
                                .tracking(0.8)
                            TextField(p.text(en: "name@email.com", es: "nombre@correo.com", pt: "nome@email.com", fr: "nom@email.com", ar: "name@email.com", de: "name@email.com", it: "nome@email.com", nl: "naam@email.com", ja: "name@email.com", ko: "name@email.com"), text: $email)
                                .font(.subheadline)
                                .foregroundStyle(.white)
                                .autocapitalization(.none)
                                .keyboardType(.emailAddress)
                                .padding(14)
                                .background(BXPalette.fieldFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(BXPalette.panelStroke, lineWidth: 0.5)
                                )
                        }

                        // Password field
                        VStack(alignment: .leading, spacing: 6) {
                            Text(p.text(en: "PASSWORD", es: "CONTRASEÑA", pt: "SENHA", fr: "MOT DE PASSE", ar: "كلمة المرور", de: "PASSWORT", it: "PASSWORD", nl: "WACHTWOORD", ja: "パスワード", ko: "비밀번호"))
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(BXPalette.textSecondary)
                                .tracking(0.8)
                            SecureField("••••••••", text: $password)
                                .font(.subheadline)
                                .foregroundStyle(.white)
                                .padding(14)
                                .background(BXPalette.fieldFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(BXPalette.panelStroke, lineWidth: 0.5)
                                )
                        }

                        // Forgot password — sign in only
                        if !localIsNewUser {
                            VStack(alignment: .trailing, spacing: 4) {
                                HStack {
                                    Spacer()
                                    Button(p.text(en: "Forgot your password?", es: "¿Olvidaste tu contraseña?", pt: "Esqueceu a senha?", fr: "Mot de passe oublié?", ar: "هل نسيت كلمة المرور؟", de: "Passwort vergessen?", it: "Hai dimenticato la password?", nl: "Wachtwoord vergeten?", ja: "パスワードをお忘れですか？", ko: "비밀번호를 잊으셨나요?")) {
                                        guard !email.isEmpty else { return }
                                        resetPasswordSent = false
                                        Task {
                                            await supabase.resetPassword(email: email)
                                            if supabase.errorMessage == nil {
                                                resetPasswordSent = true
                                            }
                                        }
                                    }
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.white.opacity(0.65))
                                }
                                if resetPasswordSent {
                                    Text(p.text(en: "Recovery email sent. Check your inbox.", es: "Correo de recuperación enviado. Revisa tu bandeja.", pt: "E-mail de recuperação enviado. Verifique sua caixa.", fr: "E-mail de récupération envoyé. Vérifiez votre boîte.", ar: "تم إرسال بريد الاسترداد. تحقق من صندوق الوارد.", de: "Wiederherstellungs-E-Mail gesendet. Prüfe deinen Posteingang.", it: "Email di recupero inviata. Controlla la posta in arrivo.", nl: "Herstelmail verzonden. Controleer je inbox.", ja: "回復メールを送信しました。受信トレイを確認してください。", ko: "복구 이메일을 보냈습니다. 받은편지함을 확인하세요."))
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(Color(red: 0.29, green: 0.87, blue: 0.50))
                                        .multilineTextAlignment(.trailing)
                                        .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }
                            .animation(.easeOut(duration: 0.25), value: resetPasswordSent)
                        }

                        // Primary action button
                        Button {
                            Task {
                                if localIsNewUser {
                                    await supabase.signUp(email: email, password: password)
                                } else {
                                    await supabase.signIn(email: email, password: password)
                                }
                            }
                        } label: {
                            Text(localIsNewUser
                                 ? p.text(en: "Create Account", es: "Crear cuenta",    pt: "Criar Conta",     fr: "Créer un compte", ar: "إنشاء حساب", de: "Konto erstellen", it: "Crea account", nl: "Account maken", ja: "アカウント作成", ko: "계정 만들기")
                                 : p.text(en: "Sign In",        es: "Entrar",           pt: "Entrar",          fr: "Se connecter", ar: "تسجيل الدخول", de: "Anmelden", it: "Accedi", nl: "Inloggen", ja: "サインイン", ko: "로그인"))
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }

                        // Switch mode link
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                localIsNewUser.toggle()
                                email = ""
                                password = ""
                            }
                        } label: {
                            Text(localIsNewUser
                                 ? p.text(en: "Already have an account? Sign in", es: "¿Ya tienes cuenta? Inicia sesión", pt: "Já tem conta? Entre", fr: "Déjà un compte? Se connecter", ar: "هل لديك حساب بالفعل؟ سجّل الدخول", de: "Schon ein Konto? Anmelden", it: "Hai già un account? Accedi", nl: "Heb je al een account? Log in", ja: "すでにアカウントがありますか？ サインイン", ko: "이미 계정이 있나요? 로그인")
                                 : p.text(en: "Don't have an account? Sign up",   es: "¿No tienes cuenta? Regístrate",   pt: "Não tem conta? Cadastre-se", fr: "Pas de compte? S'inscrire", ar: "ليس لديك حساب؟ أنشئ حسابًا", de: "Noch kein Konto? Registrieren", it: "Non hai un account? Registrati", nl: "Nog geen account? Meld je aan", ja: "アカウントをお持ちでないですか？ 登録", ko: "계정이 없나요? 가입하기"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BXPalette.textSecondary)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 52)
                }
            }
        }
        .overlay {
            if supabase.isLoading {
                Color.black.opacity(0.35).ignoresSafeArea()
                ProgressView().tint(.white).scaleEffect(1.5)
            }
        }
        .onAppear { localIsNewUser = isNewUser }
    }
}

// MARK: - Splash View

private struct BXSplashView: View {
    let showButtons: Bool
    let onNewUser: () -> Void
    let onExistingUser: () -> Void

    @EnvironmentObject private var supabase: SupabaseManager
    @State private var billProgress: CGFloat = 0.0
    @State private var billFloat: CGFloat = 0.0
    @State private var letterOpacities: [Double] = Array(repeating: 0, count: 9)
    @State private var letterOffsets: [CGFloat] = Array(repeating: 20, count: 9)
    @State private var taglineOpacity: Double = 0.0
    @State private var glowOpacity: Double = 0.0

    private let letters: [String] = "Balance X".map { String($0) }
    private var p: OnboardingProfile { supabase.onboardingProfile }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Bill draws itself from nothing, stroke by stroke
            BXAnimatedBillLogo(progress: billProgress)
                .frame(width: 120, height: 120)
                .offset(y: billFloat)
                .padding(.bottom, 32)

            ZStack {
                // Subtle glow behind the wordmark
                Ellipse()
                    .fill(Color.white.opacity(0.055))
                    .frame(width: 270, height: 46)
                    .blur(radius: 24)
                    .opacity(glowOpacity)

                // "Balance X" — each letter rises and fades in one by one
                HStack(spacing: 0) {
                    ForEach(0..<letters.count, id: \.self) { i in
                        Text(letters[i])
                            .font(.system(size: 52, weight: .black))
                            .foregroundStyle(.white)
                            .opacity(letterOpacities[i])
                            .offset(y: letterOffsets[i])
                    }
                }
            }
            .padding(.bottom, 10)

            Text(p.text(
                en: "THINK RICHER",
                es: "PIENSA MÁS",
                pt: "PENSE MAIOR",
                fr: "PENSEZ PLUS",
                ar: "فكّر بثراء",
                de: "DENKE REICHER",
                it: "PENSA IN GRANDE",
                nl: "DENK GROTER",
                ja: "豊かに考える",
                ko: "더 풍요롭게"
            ))
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.white.opacity(0.34))
            .tracking(3.0)
            .opacity(taglineOpacity)

            Spacer()

            if showButtons {
                VStack(spacing: 12) {
                    Button(action: onNewUser) {
                        Text(p.text(en: "GET STARTED", es: "COMENZAR",
                                    pt: "COMEÇAR", fr: "COMMENCER",
                                    ar: "ابدأ الآن", de: "LOSLEGEN",
                                    it: "INIZIA", nl: "BEGINNEN",
                                    ja: "はじめる", ko: "시작하기"))
                            .font(.headline.weight(.black))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: .white.opacity(0.18), radius: 18, y: 4)
                    }
                    .buttonStyle(.plain)

                    Button(action: onExistingUser) {
                        Text(p.text(en: "I already have an account", es: "Ya tengo cuenta",
                                    pt: "Já tenho uma conta", fr: "J'ai déjà un compte",
                                    ar: "لدي حساب بالفعل", de: "Ich habe bereits ein Konto",
                                    it: "Ho già un account", nl: "Ik heb al een account",
                                    ja: "すでにアカウントがあります", ko: "이미 계정이 있습니다"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .bxLiquidControl(cornerRadius: 16)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 48)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                Spacer().frame(height: 128)
            }
        }
        .onAppear { startFormationAnimation() }
    }

    private func startFormationAnimation() {
        // Bill draws itself stroke by stroke
        withAnimation(.easeInOut(duration: 1.15)) {
            billProgress = 1.0
        }
        // Glow appears as the bill nears completion
        withAnimation(.easeOut(duration: 0.5).delay(0.45)) {
            glowOpacity = 1.0
        }
        // Each letter of "Balance X" rises and fades in while the bill finishes drawing
        for i in 0..<letters.count {
            let d = 0.50 + Double(i) * 0.07
            withAnimation(.spring(response: 0.44, dampingFraction: 0.70).delay(d)) {
                letterOpacities[i] = 1.0
                letterOffsets[i] = 0.0
            }
        }
        // Tagline fades in after all letters have landed
        withAnimation(.easeOut(duration: 0.5).delay(1.30)) {
            taglineOpacity = 1.0
        }
        // Gentle idle float loop
        Task {
            try? await Task.sleep(for: .milliseconds(1350))
            await MainActor.run {
                withAnimation(.easeInOut(duration: 1.9).repeatForever(autoreverses: true)) {
                    billFloat = -9
                }
            }
        }
    }
}

private struct BXThinkRicherStatementView: View {
    let onContinue: () -> Void

    @EnvironmentObject private var supabase: SupabaseManager
    @State private var textOpacity: Double = 0
    @State private var textOffset: CGFloat = 18
    @State private var promptOpacity: Double = 0

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            BXBackground()

            VStack {
                Spacer()
                Text(supabase.onboardingProfile.text(
                    en: "Think\nRicher",
                    es: "Piensa\nmás alto",
                    pt: "Pense\nmaior",
                    fr: "Pensez\nplus loin",
                    ar: "فكّر\nبثراء",
                    de: "Denke\nreicher",
                    it: "Pensa\nin grande",
                    nl: "Denk\ngroter",
                    ja: "豊かに\n考える",
                    ko: "더 풍요롭게\n생각해"
                ))
                    .font(.system(size: 76, weight: .black))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .opacity(textOpacity)
                    .offset(y: textOffset)
                    .padding(.horizontal, 28)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Text(supabase.onboardingProfile.text(en: "tap to continue", es: "toca para continuar", pt: "toque para continuar", fr: "touchez pour continuer", ar: "اضغط للمتابعة", de: "tippen zum Fortfahren", it: "tocca per continuare", nl: "tik om door te gaan", ja: "タップして続行", ko: "탭하여 계속"))
                .font(.caption.weight(.medium))
                .foregroundStyle(.white)
                .tracking(0.8)
                .padding(.trailing, 26)
                .padding(.bottom, 34)
                .opacity(promptOpacity)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onContinue)
        .onAppear {
            withAnimation(.easeOut(duration: 0.65)) {
                textOpacity = 1
                textOffset = 0
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.65)) {
                promptOpacity = 1
            }
        }
    }
}

// MARK: - Intro Slides

private struct BXIntroSlidesView: View {
    @EnvironmentObject private var supabase: SupabaseManager
    let onFinish: () -> Void
    @State private var page = 0

    private struct Slide {
        let symbol: String
        let title: (en: String, es: String, pt: String, fr: String, ar: String, de: String, it: String, nl: String, ja: String, ko: String)
        let body:  (en: String, es: String, pt: String, fr: String, ar: String, de: String, it: String, nl: String, ja: String, ko: String)
    }

    private let slides: [Slide] = [
        Slide(
            symbol: "chart.bar.fill",
            title: (
                en: "All your money,\nin one place.",
                es: "Todo tu dinero,\nen un lugar.",
                pt: "Todo o seu dinheiro,\nnum só lugar.",
                fr: "Tout votre argent,\nen un seul endroit.",
                ar: "كل أموالك،\nفي مكان واحد.",
                de: "Dein gesamtes Geld,\nan einem Ort.",
                it: "Tutti i tuoi soldi,\nin un posto solo.",
                nl: "Al je geld,\nop één plek.",
                ja: "すべてのお金を、\n一か所に。",
                ko: "모든 돈을,\n한 곳에."
            ),
            body: (
                en: "Balance X builds a complete picture of your financial health in real time.",
                es: "Balance X construye una imagen completa de tu salud financiera en tiempo real.",
                pt: "O Balance X constrói um quadro completo da sua saúde financeira em tempo real.",
                fr: "Balance X dresse un tableau complet de votre santé financière en temps réel.",
                ar: "يبني Balance X صورة كاملة عن صحتك المالية في الوقت الفعلي.",
                de: "Balance X erstellt ein vollständiges Bild deiner finanziellen Gesundheit in Echtzeit.",
                it: "Balance X costruisce un quadro completo della tua salute finanziaria in tempo reale.",
                nl: "Balance X bouwt een volledig beeld van je financiële gezondheid in realtime.",
                ja: "Balance Xはリアルタイムであなたの財務健全性の完全な画像を構築します。",
                ko: "Balance X는 실시간으로 재무 건강의 완전한 그림을 구축합니다."
            )
        ),
        Slide(
            symbol: "doc.text.viewfinder",
            title: (
                en: "Scan receipts\ninstantly.",
                es: "Escanea recibos\nal instante.",
                pt: "Digitalize recibos\ninstantaneamente.",
                fr: "Scannez vos reçus\ninstantanément.",
                ar: "امسح الإيصالات\nفورًا.",
                de: "Belege sofort\nscannen.",
                it: "Scansiona le ricevute\nall'istante.",
                nl: "Scan bonnetjes\nmeteen.",
                ja: "レシートを\n即座にスキャン。",
                ko: "영수증을\n즉시 스캔."
            ),
            body: (
                en: "AI extraction detects amount, merchant, and date from your receipts automatically.",
                es: "La IA detecta monto, comercio y fecha desde tus recibos automáticamente.",
                pt: "A IA detecta valor, comerciante e data dos seus recibos automaticamente.",
                fr: "L'IA détecte le montant, le commerçant et la date de vos reçus automatiquement.",
                ar: "يكشف الذكاء الاصطناعي تلقائيًا عن المبلغ والتاجر والتاريخ من إيصالاتك.",
                de: "Die KI erkennt automatisch Betrag, Händler und Datum aus deinen Belegen.",
                it: "L'IA rileva automaticamente importo, commerciante e data dalle tue ricevute.",
                nl: "AI detecteert automatisch bedrag, handelaar en datum van je bonnetjes.",
                ja: "AIがレシートから金額、店舗名、日付を自動的に検出します。",
                ko: "AI가 영수증에서 금액, 가맹점, 날짜를 자동으로 감지합니다."
            )
        ),
        Slide(
            symbol: "chart.bar.doc.horizontal",
            title: (
                en: "Reports &\ntax-ready exports.",
                es: "Reportes y\nexportaciones fiscales.",
                pt: "Relatórios e\nexportações fiscais.",
                fr: "Rapports et\nexports fiscaux.",
                ar: "تقارير و\nتصدير ضريبي.",
                de: "Berichte &\nsteuerfertige Exporte.",
                it: "Report ed\nesportazioni fiscali.",
                nl: "Rapporten &\nbelastingklare exports.",
                ja: "レポートと\n税務対応エクスポート。",
                ko: "보고서 및\n세금 준비 내보내기."
            ),
            body: (
                en: "Generate PDF or Excel exports, estimate taxes by country, and track budgets effortlessly.",
                es: "Genera exportaciones PDF/Excel, estima impuestos por país y controla presupuestos fácilmente.",
                pt: "Gere exportações PDF/Excel, estime impostos por país e acompanhe orçamentos facilmente.",
                fr: "Générez des exports PDF/Excel, estimez les impôts par pays et suivez vos budgets facilement.",
                ar: "أنشئ صادرات PDF/Excel، قدّر الضرائب حسب الدولة، وتتبع الميزانيات بسهولة.",
                de: "Erstelle PDF/Excel-Exporte, schätze Steuern nach Land und verfolge Budgets mühelos.",
                it: "Genera esportazioni PDF/Excel, stima le tasse per paese e monitora i budget facilmente.",
                nl: "Genereer PDF/Excel-exports, schat belastingen per land en volg budgetten moeiteloos.",
                ja: "PDF/Excelエクスポートを生成し、国別に税金を見積もり、予算を簡単に追跡できます。",
                ko: "PDF/Excel 내보내기를 생성하고, 국가별 세금을 추정하고, 예산을 쉽게 추적하세요."
            )
        )
    ]

    private var p: OnboardingProfile { supabase.onboardingProfile }

    var body: some View {
        ZStack {
            BXBackground()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(p.text(en: "Skip", es: "Saltar", pt: "Pular", fr: "Passer",
                                  ar: "تخطي", de: "Überspringen", it: "Salta", nl: "Overslaan",
                                  ja: "スキップ", ko: "건너뛰기")) { onFinish() }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(BXPalette.textSecondary)
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                }

                TabView(selection: $page) {
                    ForEach(Array(slides.enumerated()), id: \.offset) { index, slide in
                        VStack(alignment: .leading, spacing: 20) {
                            Spacer()
                            ZStack {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color.white.opacity(0.10))
                                    .frame(width: 68, height: 68)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .strokeBorder(Color.white.opacity(0.20), lineWidth: 1)
                                    )
                                Image(systemName: slide.symbol)
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            Text(p.text(en: slide.title.en, es: slide.title.es, pt: slide.title.pt, fr: slide.title.fr,
                                        ar: slide.title.ar, de: slide.title.de, it: slide.title.it, nl: slide.title.nl,
                                        ja: slide.title.ja, ko: slide.title.ko))
                                .font(.system(size: 44, weight: .black))
                                .foregroundStyle(.white)
                                .lineSpacing(2)
                            Text(p.text(en: slide.body.en, es: slide.body.es, pt: slide.body.pt, fr: slide.body.fr,
                                        ar: slide.body.ar, de: slide.body.de, it: slide.body.it, nl: slide.body.nl,
                                        ja: slide.body.ja, ko: slide.body.ko))
                                .font(.subheadline)
                                .foregroundStyle(BXPalette.textSecondary)
                                .lineSpacing(3)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 28)
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 6) {
                    ForEach(0..<slides.count, id: \.self) { i in
                        Circle()
                            .fill(i == page ? Color.white : Color.white.opacity(0.25))
                            .frame(width: i == page ? 8 : 5, height: i == page ? 8 : 5)
                            .animation(.spring(response: 0.3), value: page)
                    }
                }
                .padding(.bottom, 20)

                Button {
                    if page < slides.count - 1 {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { page += 1 }
                    } else {
                        onFinish()
                    }
                } label: {
                    Text(page < slides.count - 1
                         ? p.text(en: "NEXT", es: "SIGUIENTE", pt: "PRÓXIMO", fr: "SUIVANT",
                                  ar: "التالي", de: "WEITER", it: "AVANTI", nl: "VOLGENDE",
                                  ja: "次へ", ko: "다음")
                         : p.text(en: "GET STARTED", es: "COMENZAR", pt: "COMEÇAR", fr: "COMMENCER",
                                  ar: "ابدأ الآن", de: "LOSLEGEN", it: "INIZIA", nl: "BEGINNEN",
                                  ja: "はじめる", ko: "시작하기"))
                        .font(.headline.weight(.black))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: .white.opacity(0.18), radius: 12, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Tab

private enum BXTab: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case transactions = "Transactions"
    case reports = "Reports"
    case receipts = "Receipts"
    case settings = "Settings"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .dashboard:    return "house"
        case .transactions: return "arrow.left.arrow.right"
        case .reports:      return "chart.bar"
        case .receipts:     return "doc.text"
        case .settings:     return "gearshape"
        }
    }

    var symbolFilled: String {
        switch self {
        case .dashboard:    return "house.fill"
        case .transactions: return "arrow.left.arrow.right"
        case .reports:      return "chart.bar.fill"
        case .receipts:     return "doc.text.fill"
        case .settings:     return "gearshape.fill"
        }
    }
}

// MARK: - App Shell

private struct BXAppShell: View {
    @EnvironmentObject private var supabase: SupabaseManager
    @EnvironmentObject private var appSession: AppSession
    @Binding var showWelcome: Bool
    @State private var selectedTab: BXTab = .dashboard
    @State private var showingAddExpense = false
    @State private var showingNotifications = false
    @State private var period: DashboardPeriod = .weekly

    var body: some View {
        ZStack(alignment: .bottom) {
            if selectedTab == .settings {
                NavigationStack {
                    ZStack {
                        BXBackground()
                        BXSettingsView()
                            .environmentObject(supabase)
                            .environmentObject(appSession)
                    }
                    .navigationTitle(supabase.onboardingProfile.text(en: "Settings",     es: "Ajustes",
                                                                      pt: "Definições",  fr: "Réglages",
                                                                      ar: "الإعدادات",  de: "Einstellungen",
                                                                      it: "Impostazioni", nl: "Instellingen",
                                                                      ja: "設定",          ko: "설정"))
                    .navigationBarTitleDisplayMode(.large)
                }
                .padding(.bottom, 72)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        heroHeader

                        switch selectedTab {
                        case .dashboard:
                            BXDashboardView(period: $period, showingAddExpense: $showingAddExpense)
                                .environmentObject(supabase)
                        case .transactions:
                            BXTransactionsView()
                                .environmentObject(supabase)
                        case .reports:
                            BXReportsView(period: $period)
                                .environmentObject(supabase)
                        case .receipts:
                            BXReceiptsView()
                                .environmentObject(supabase)
                        case .settings:
                            EmptyView()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 120)
                }
            }

            // Tab bar + floating plus button (hidden on Settings tab)
            ZStack(alignment: .topTrailing) {
                BXFloatingTabBar(selectedTab: $selectedTab)
                    .padding(.horizontal, 20)

                if selectedTab != .settings {
                    Button {
                        showingAddExpense = true
                        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(width: 52, height: 52)
                            .background(Color.white, in: Circle())
                            .shadow(color: .white.opacity(0.20), radius: 14, y: 6)
                    }
                    .buttonStyle(.plain)
                    .offset(x: -28, y: -62)
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: selectedTab == .settings)
            .padding(.bottom, 12)
        }
        .sheet(isPresented: $showingAddExpense) {
            AddExpenseView()
                .environmentObject(supabase)
        }
        .sheet(isPresented: $showWelcome) {
            BXWelcomeView(showWelcome: $showWelcome)
                .environmentObject(supabase)
        }
        .sheet(isPresented: $showingNotifications) {
            BXNotificationsView()
                .environmentObject(supabase)
        }
    }

    // MARK: Hero Header

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(BXPalette.panelFillElevated)
                        .frame(width: 42, height: 42)
                    let initials = supabase.onboardingProfile.greetingName
                        .trimmingCharacters(in: .whitespaces)
                        .prefix(1)
                        .uppercased()
                    if initials.isEmpty {
                        Image(systemName: supabase.onboardingProfile.workspaceType == .business
                              ? "building.2.fill" : "person.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    } else {
                        Text(initials)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }

                // Name + Renovar badge
                HStack(spacing: 8) {
                    Text(supabase.onboardingProfile.greetingName.isEmpty
                         ? supabase.onboardingProfile.primaryName
                         : supabase.onboardingProfile.greetingName)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)


                }

                Spacer()

                // Bell
                Button {
                    showingNotifications = true
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell")
                        if !supabase.dailyNotifications.isEmpty {
                            Circle()
                                .fill(BXPalette.expense)
                                .frame(width: 7, height: 7)
                                .offset(x: 2, y: -1)
                        }
                    }
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .bxLiquidControl(cornerRadius: 12)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)

            if supabase.isOffline {
                HStack(spacing: 8) {
                    Image(systemName: "wifi.slash")
                        .font(.caption.weight(.semibold))
                    Text(supabase.onboardingProfile.text(
                        en: "Offline - showing cached data",
                        es: "Sin conexion - mostrando datos guardados",
                        pt: "Offline - exibindo dados em cache",
                        fr: "Hors ligne - donnees en cache",
                        ar: "غير متصل - عرض البيانات المحفوظة",
                        de: "Offline - zwischengespeicherte Daten",
                        it: "Offline - dati in cache",
                        nl: "Offline - gecachte gegevens",
                        ja: "オフライン - キャッシュデータを表示中",
                        ko: "오프라인 - 캐시된 데이터 표시 중"
                    ))
                    .font(.caption.weight(.medium))
                }
                .foregroundStyle(BXPalette.warning)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .bxGlassCard(cornerRadius: 14)
            }

            if let message = supabase.configurationStatusMessage {
                Text(message)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(BXPalette.warning)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .bxGlassCard(cornerRadius: 14)
            }
        }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let name = supabase.onboardingProfile.greetingName
        if hour < 12 { return "Good morning, \(name)" }
        if hour < 18 { return "Good afternoon, \(name)" }
        return "Good evening, \(name)"
    }
}

// MARK: - Dashboard View

private struct BXDashboardView: View {
    @EnvironmentObject private var supabase: SupabaseManager
    @Binding var period: DashboardPeriod
    @Binding var showingAddExpense: Bool
    @State private var filterSheet: BXTransactionFilter? = nil
    @State private var showNetWorthSheet = false

    var body: some View {
        VStack(spacing: 20) {
            balanceHero
            metricsRow
            netWorthCard
            healthScoreCard
            pendingSubscriptionsBanner
            smartAlertsSection
            chartSection
            quickAction
            recentActivity
            insightsSection
        }
        .sheet(item: $filterSheet) { filter in
            NavigationStack {
                ScrollView(showsIndicators: false) {
                    BXTransactionsView(initialFilter: filter)
                        .environmentObject(supabase)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 40)
                }
                .background(BXBackground())
                .navigationTitle(filter == .income
                    ? supabase.onboardingProfile.text(en: "Income", es: "Ingresos", pt: "Receitas", fr: "Revenus", ar: "الدخل", de: "Einnahmen", it: "Entrate", nl: "Inkomsten", ja: "収入", ko: "수입")
                    : supabase.onboardingProfile.text(en: "Expenses", es: "Gastos", pt: "Despesas", fr: "Dépenses", ar: "المصروفات", de: "Ausgaben", it: "Spese", nl: "Uitgaven", ja: "支出", ko: "지출"))
                .navigationBarTitleDisplayMode(.large)
            }
        }
        .sheet(isPresented: $showNetWorthSheet) {
            BXNetWorthSheet()
                .environmentObject(supabase)
        }
    }

    @ViewBuilder
    private var pendingSubscriptionsBanner: some View {
        let pending = supabase.pendingSubscriptionsThisMonth
        let prof = supabase.onboardingProfile
        let cc = prof.currencyCode

        if !pending.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(BXPalette.warning)
                    Text(prof.text(en: "Pending payments", es: "Pagos pendientes", pt: "Pagamentos pendentes", fr: "Paiements en attente", ar: "مدفوعات معلقة", de: "Ausstehende Zahlungen", it: "Pagamenti in sospeso", nl: "Openstaande betalingen", ja: "保留中の支払い", ko: "보류 중인 결제"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BXPalette.textPrimary)
                    Spacer()
                    Text("\(pending.count)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.black)
                        .frame(minWidth: 20, minHeight: 20)
                        .background(BXPalette.warning, in: Capsule())
                }

                ForEach(pending) { subscription in
                    HStack(spacing: 10) {
                        Text(subscription.name)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(BXPalette.textPrimary)
                        Spacer()
                        Text(subscription.amount.currencyString(code: cc))
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(BXPalette.warning)
                        Button {
                            supabase.markSubscriptionPaid(subscription, paid: true)
                        } label: {
                            Text(prof.text(en: "Paid", es: "Pagado", pt: "Pago", fr: "Payé", ar: "مدفوع", de: "Bezahlt", it: "Pagato", nl: "Betaald", ja: "支払い済み", ko: "결제 완료"))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.white, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
            .background(BXPalette.warning.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(BXPalette.warning.opacity(0.35), lineWidth: 1)
            )
        }
    }

    private var balanceHero: some View {
        let cc  = supabase.onboardingProfile.currencyCode
        let net = supabase.analytics.profit
        return ZStack(alignment: .topTrailing) {
            // Glow orb
            RadialGradient(
                colors: [BXPalette.accentStart.opacity(0.32), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 150
            )
            .frame(width: 200, height: 200)
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center) {
                    Text(supabase.onboardingProfile.text(
                        en: "Net Balance · This Month",
                        es: "Balance Neto · Este mes",
                        pt: "Saldo Líquido · Este mês",
                        fr: "Solde Net · Ce mois",
                        ar: "الرصيد الصافي · هذا الشهر",
                        de: "Nettostand · Diesen Monat",
                        it: "Saldo Netto · Questo mese",
                        nl: "Nettosaldo · Deze maand",
                        ja: "純残高 · 今月",
                        ko: "순잔액 · 이번 달"
                    ).uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .tracking(0.8)
                    Spacer()
                }

                BXCountUpAmount(
                    value: net,
                    code: cc,
                    font: .system(size: 46, weight: .black),
                    positiveGradient: LinearGradient(
                        colors: [Color(red: 0.063, green: 0.918, blue: 0.533), Color(red: 0.28, green: 1.0, blue: 0.70)],
                        startPoint: .topLeading, endPoint: .bottomTrailing),
                    negativeGradient: LinearGradient(
                        colors: [Color(red: 1.0, green: 0.286, blue: 0.392), Color(red: 1.0, green: 0.50, blue: 0.30)],
                        startPoint: .topLeading, endPoint: .bottomTrailing)
                )

                HStack(spacing: 6) {
                    BXStatusPill(
                        title: supabase.onboardingProfile.text(en: "● Updated", es: "● Actualizado", pt: "● Atualizado", fr: "● Mis à jour", ar: "● محدث", de: "● Aktualisiert", it: "● Aggiornato", nl: "● Bijgewerkt", ja: "● 更新済", ko: "● 업데이트됨"),
                        color: BXPalette.income
                    )
                    BXStatusPill(
                        title: supabase.onboardingProfile.text(en: "Tax-ready", es: "Listo para taxes", pt: "Pronto p/ impostos", fr: "Prêt pour taxes", ar: "جاهز للضريبة", de: "Steuerfertig", it: "Pronto per tasse", nl: "Belastingklaar", ja: "税務対応", ko: "세금 준비됨"),
                        color: BXPalette.tax
                    )
                }

                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 0.5)

                HStack(spacing: 12) {
                    // Income pill — tappable → filtered sheet
                    Button { filterSheet = .income } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.left")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(BXPalette.income)
                                .frame(width: 22, height: 22)
                                .background(BXPalette.income.opacity(0.18), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(supabase.onboardingProfile.text(en: "Income", es: "Ingresos", pt: "Receitas", fr: "Revenus", ar: "الدخل", de: "Einnahmen", it: "Entrate", nl: "Inkomsten", ja: "収入", ko: "수입"))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.45))
                                BXCountUpAmount(
                                    value: supabase.analytics.totalIncome,
                                    code: cc,
                                    font: .system(size: 14, weight: .bold, design: .rounded),
                                    color: BXPalette.income
                                )
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.25))
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.white.opacity(0.09), lineWidth: 0.5))

                    // Expense pill — tappable → filtered sheet
                    Button { filterSheet = .expense } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(BXPalette.expense)
                                .frame(width: 22, height: 22)
                                .background(BXPalette.expense.opacity(0.18), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(supabase.onboardingProfile.text(en: "Expenses", es: "Gastos", pt: "Despesas", fr: "Dépenses", ar: "المصروفات", de: "Ausgaben", it: "Spese", nl: "Uitgaven", ja: "支出", ko: "지출"))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.45))
                                BXCountUpAmount(
                                    value: supabase.analytics.totalExpenses,
                                    code: cc,
                                    font: .system(size: 14, weight: .bold, design: .rounded),
                                    color: BXPalette.expense
                                )
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.25))
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.white.opacity(0.09), lineWidth: 0.5))
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(BXPalette.panelFill, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(BXPalette.panelStroke, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
    }

    private var netWorthCard: some View {
        let p = supabase.onboardingProfile
        let cc = p.currencyCode
        let nw = supabase.netWorth
        let hasAccounts = !supabase.netWorthAccounts.isEmpty
        let nwColor: Color = nw >= 0 ? BXPalette.income : BXPalette.expense

        return Button { showNetWorthSheet = true } label: {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(p.text(en: "Net Worth", es: "Patrimonio Neto", pt: "Patrimônio Líquido", fr: "Patrimoine Net", ar: "صافي الثروة", de: "Nettovermögen", it: "Patrimonio Netto", nl: "Nettovermogen", ja: "純資産", ko: "순자산"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BXPalette.textSecondary)
                        .tracking(0.5)

                    if hasAccounts {
                        Text(nw.currencyString(code: cc))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(nwColor)

                        HStack(spacing: 14) {
                            let assets = supabase.netWorthAccounts.filter { $0.type == .asset }
                                .reduce(Decimal.zero) { $0 + $1.balance }
                            let liabilities = supabase.netWorthAccounts.filter { $0.type == .liability }
                                .reduce(Decimal.zero) { $0 + $1.balance }
                            Label(assets.currencyString(code: cc), systemImage: "arrow.down.left")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(BXPalette.income)
                            Label(liabilities.currencyString(code: cc), systemImage: "arrow.up.right")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(BXPalette.expense)
                        }
                    } else {
                        Text(p.text(en: "Track assets & liabilities", es: "Registra activos y pasivos", pt: "Registre ativos e passivos", fr: "Suivez actifs et dettes", ar: "تتبع الأصول والخصوم", de: "Vermögen & Schulden verfolgen", it: "Traccia attivi e passivi", nl: "Volg activa en schulden", ja: "資産と負債を管理", ko: "자산과 부채 추적"))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(BXPalette.textTertiary)
                    }
                }
                Spacer()
                Image(systemName: hasAccounts ? "chart.bar.fill" : "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(hasAccounts ? nwColor : BXPalette.textSecondary)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .bxGlassCard()
            .shadow(color: .black.opacity(0.20), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
    }

    private var metricsRow: some View {
        let cc = supabase.onboardingProfile.currencyCode
        let p = supabase.onboardingProfile
        let income = supabase.analytics.totalIncome
        let expenses = supabase.analytics.totalExpenses

        // Savings rate — (income - expenses) / income * 100
        let savingsRate: Double? = income > 0
            ? ((income - expenses) as NSDecimalNumber).doubleValue
              / (income as NSDecimalNumber).doubleValue * 100
            : nil
        let rateColor = savingsRate.map { $0 >= 0 ? BXPalette.income : BXPalette.expense }
            ?? BXPalette.textSecondary

        // Top expense category this month
        let calendar = Calendar.current
        let now = Date()
        let monthExpenses = supabase.transactions.filter {
            $0.type == .expense && calendar.isDate($0.date, equalTo: now, toGranularity: .month)
        }
        let catTotals = Dictionary(grouping: monthExpenses, by: \.category)
            .mapValues { $0.reduce(Decimal.zero) { $0 + $1.amount } }
        let topCat = catTotals.max(by: { $0.value < $1.value })

        return HStack(spacing: 12) {
            // Savings rate card
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(rateColor)
                        .frame(width: 28, height: 28)
                        .background(rateColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    Spacer()
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(p.text(en: "Savings rate", es: "Tasa de ahorro", pt: "Taxa de poupança", fr: "Taux d'épargne", ar: "معدل الادخار", de: "Sparquote", it: "Tasso risparmio", nl: "Spaarquote", ja: "貯蓄率", ko: "저축률"))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(BXPalette.textSecondary)
                        .lineLimit(1)
                    if let rate = savingsRate {
                        Text(String(format: "%.0f%%", rate))
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(rate >= 0 ? BXPalette.income : BXPalette.expense)
                            .monospacedDigit()
                    } else {
                        Text("--")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(BXPalette.textTertiary)
                    }
                    Text(p.text(en: "of income saved", es: "de ingresos ahorrado", pt: "da renda guardada", fr: "du revenu épargné", ar: "من الدخل المدخر", de: "des Einkommens gespart", it: "del reddito risparmiato", nl: "van inkomen gespaard", ja: "収入の貯蓄分", ko: "수입 중 저축"))
                        .font(.caption2)
                        .foregroundStyle(BXPalette.textTertiary)
                        .lineLimit(1)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 110, alignment: .topLeading)
            .bxGlassCard()
            .shadow(color: .black.opacity(0.25), radius: 12, y: 6)

            // Top expense category card
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "tag.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(BXPalette.warning)
                        .frame(width: 28, height: 28)
                        .background(BXPalette.warning.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    Spacer()
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(p.text(en: "Top category", es: "Mayor gasto", pt: "Maior categoria", fr: "Top catégorie", ar: "أعلى فئة", de: "Top-Kategorie", it: "Cat. principale", nl: "Top categorie", ja: "最多カテゴリ", ko: "최대 지출"))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(BXPalette.textSecondary)
                        .lineLimit(1)
                    Text(topCat?.key ?? "--")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(BXPalette.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    if let top = topCat {
                        Text(top.value.currencyString(code: cc))
                            .font(.caption2)
                            .foregroundStyle(BXPalette.expense)
                            .lineLimit(1)
                    } else {
                        Text(p.text(en: "No expenses yet", es: "Sin gastos aún", pt: "Sem despesas ainda", fr: "Aucune dépense", ar: "لا مصروفات بعد", de: "Noch keine Ausgaben", it: "Nessuna spesa", nl: "Nog geen uitgaven", ja: "支出なし", ko: "지출 없음"))
                            .font(.caption2)
                            .foregroundStyle(BXPalette.textTertiary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 110, alignment: .topLeading)
            .bxGlassCard()
            .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
        }
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            BXSectionTitle(
                eyebrow: supabase.onboardingProfile.text(en: "Performance",  es: "Rendimiento",
                                                          pt: "Desempenho",  fr: "Performance",
                                                          ar: "الأداء",       de: "Leistung",
                                                          it: "Prestazioni", nl: "Prestaties",
                                                          ja: "パフォーマンス", ko: "성과"),
                title: supabase.onboardingProfile.text(en: "Cash flow",      es: "Flujo de caja",
                                                        pt: "Fluxo de caixa", fr: "Flux de trésorerie",
                                                        ar: "التدفق النقدي",  de: "Cashflow",
                                                        it: "Flusso di cassa", nl: "Kasstroom",
                                                        ja: "キャッシュフロー", ko: "현금 흐름")
            )

            Picker(
                supabase.onboardingProfile.text(
                    en: "Period",
                    es: "Periodo",
                    pt: "Período",
                    fr: "Période",
                    ar: "الفترة",
                    de: "Zeitraum",
                    it: "Periodo",
                    nl: "Periode",
                    ja: "期間",
                    ko: "기간"
                ),
                selection: $period
            ) {
                ForEach(DashboardPeriod.allCases) { option in
                    Text(localizedPeriod(option)).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: .infinity)
            .fixedSize(horizontal: false, vertical: true)

            BXLineChart(points: supabase.analytics.chartPoints[period] ?? [])
                .frame(height: 140)

            HStack {
                Label(supabase.onboardingProfile.text(en: "Income", es: "Ingresos", pt: "Receitas", fr: "Revenus", ar: "الدخل", de: "Einnahmen", it: "Entrate", nl: "Inkomsten", ja: "収入", ko: "수입"), systemImage: "circle.fill")
                    .foregroundStyle(BXPalette.textSecondary, BXPalette.income)
                Spacer()
                Label(supabase.onboardingProfile.text(en: "Expenses", es: "Gastos", pt: "Despesas", fr: "Dépenses", ar: "المصروفات", de: "Ausgaben", it: "Spese", nl: "Uitgaven", ja: "支出", ko: "지출"), systemImage: "circle.fill")
                    .foregroundStyle(BXPalette.textSecondary, BXPalette.expense)
            }
            .font(.caption2.weight(.medium))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bxGlassCard(cornerRadius: 24)
    }

    private var quickAction: some View {
        Button {
            showingAddExpense = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(supabase.onboardingProfile.text(en: "Add transaction",  es: "Agregar movimiento",
                                                          pt: "Adicionar",       fr: "Ajouter",
                                                          ar: "إضافة معاملة",    de: "Transaktion hinzufügen",
                                                          it: "Aggiungi",        nl: "Transactie toevoegen",
                                                          ja: "取引を追加",       ko: "거래 추가"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BXPalette.textPrimary)
                    Text(supabase.onboardingProfile.text(en: "Income or expense", es: "Ingreso o gasto",
                                                          pt: "Receita ou gasto", fr: "Revenu ou dépense",
                                                          ar: "دخل أو مصروف",    de: "Einnahme oder Ausgabe",
                                                          it: "Entrata o spesa", nl: "Inkomst of uitgave",
                                                          ja: "収入または支出",    ko: "수입 또는 지출"))
                        .font(.caption2)
                        .foregroundStyle(BXPalette.textSecondary)
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(BXPalette.textTertiary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .bxGlassCard(cornerRadius: 20)
    }

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 12) {
            BXSectionTitle(
                eyebrow: supabase.onboardingProfile.text(en: "Activity",    es: "Actividad",
                                                          pt: "Atividade",  fr: "Activité",
                                                          ar: "النشاط",     de: "Aktivität",
                                                          it: "Attività",   nl: "Activiteit",
                                                          ja: "アクティビティ", ko: "활동"),
                title: supabase.onboardingProfile.text(en: "Recent transactions",  es: "Movimientos recientes",
                                                        pt: "Transações recentes", fr: "Opérations récentes",
                                                        ar: "المعاملات الأخيرة",  de: "Letzte Transaktionen",
                                                        it: "Transazioni recenti", nl: "Recente transacties",
                                                        ja: "最近の取引",           ko: "최근 거래")
            )

            if supabase.transactions.isEmpty {
                BXEmptyStateCard(
                    title: supabase.onboardingProfile.text(en: "No activity yet", es: "Sin actividad",
                                                            pt: "Sem atividade",  fr: "Aucune activité",
                                                            ar: "لا يوجد نشاط",  de: "Keine Aktivität",
                                                            it: "Nessuna attività", nl: "Geen activiteit",
                                                            ja: "アクティビティなし", ko: "활동 없음"),
                    message: supabase.onboardingProfile.text(en: "Your latest expenses and income will appear here.",
                                                              es: "Tus movimientos aparecerán aquí.",
                                                              pt: "Suas transações aparecerão aqui.",
                                                              fr: "Vos opérations apparaîtront ici.",
                                                              ar: "ستظهر معاملاتك هنا.",
                                                              de: "Ihre Transaktionen erscheinen hier.",
                                                              it: "Le tue transazioni appariranno qui.",
                                                              nl: "Uw transacties verschijnen hier.",
                                                              ja: "取引がここに表示されます。",
                                                              ko: "거래 내역이 여기에 표시됩니다."),
                    systemImage: "tray"
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(supabase.transactions.prefix(3).enumerated()), id: \.element.id) { index, transaction in
                        BXTransactionRow(
                            transaction: transaction,
                            currencyCode: supabase.onboardingProfile.currencyCode,
                            profile: supabase.onboardingProfile,
                            showActions: false,
                            onOpen: {},
                            onEdit: {},
                            onDelete: {}
                        )
                        if index < min(supabase.transactions.count, 3) - 1 {
                            Divider()
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .bxGlassCard(cornerRadius: 20)
            }
        }
    }

    private var insightsSection: some View {
        let isBusiness = supabase.onboardingProfile.workspaceType == .business
        return VStack(alignment: .leading, spacing: 12) {
            BXSectionTitle(
                eyebrow: supabase.onboardingProfile.text(en: "Intelligence", es: "Inteligencia",
                    pt: "Inteligência", fr: "Intelligence", ar: "الذكاء", de: "Intelligenz",
                    it: "Intelligenza", nl: "Intelligentie", ja: "インサイト", ko: "인텔리전스"),
                title: supabase.onboardingProfile.text(
                    en: isBusiness ? "Business Insights" : "Financial Insights",
                    es: isBusiness ? "Analisis Empresarial" : "Analisis Financiero",
                    pt: isBusiness ? "Insights Empresariais" : "Insights Financeiros",
                    fr: isBusiness ? "Analyses Commerciales" : "Analyses Financières",
                    ar: isBusiness ? "رؤى الأعمال" : "رؤى مالية",
                    de: isBusiness ? "Geschäftsanalysen" : "Finanzanalysen",
                    it: isBusiness ? "Analisi Aziendali" : "Analisi Finanziarie",
                    nl: isBusiness ? "Zakelijke Inzichten" : "Financiële Inzichten",
                    ja: isBusiness ? "ビジネスインサイト" : "財務インサイト",
                    ko: isBusiness ? "비즈니스 인사이트" : "재무 인사이트"
                )
            )

            // Tax card — shown for both, but with different framing
            HStack(spacing: 14) {
                Image(systemName: isBusiness ? "building.columns" : "doc.text.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(BXPalette.expense.opacity(0.85), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(supabase.onboardingProfile.text(
                        en: isBusiness ? "Estimated Tax Liability" : "Estimated Taxes",
                        es: isBusiness ? "Obligacion Fiscal Estimada" : "Impuestos Estimados",
                        pt: isBusiness ? "Responsabilidade Fiscal Estimada" : "Impostos Estimados",
                        fr: isBusiness ? "Charge Fiscale Estimée" : "Impôts Estimés",
                        ar: isBusiness ? "الالتزام الضريبي المقدر" : "الضرائب المقدرة",
                        de: isBusiness ? "Geschätzte Steuerlast" : "Geschätzte Steuern",
                        it: isBusiness ? "Stima Onere Fiscale" : "Tasse Stimate",
                        nl: isBusiness ? "Geschatte Belastingplicht" : "Geschatte Belastingen",
                        ja: isBusiness ? "推定納税義務" : "推定税額",
                        ko: isBusiness ? "예상 세금 부채" : "예상 세금"
                    ))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BXPalette.textPrimary)
                    Text(supabase.estimatedTaxes.smartCurrencyString(code: supabase.onboardingProfile.currencyCode))
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(BXPalette.expense)
                }
                Spacer()
            }
            .padding(16)
            .bxGlassCard(cornerRadius: 20)

            // AI insights grid
            let insights = supabase.analytics.insights[period] ?? []
            ForEach(insights) { insight in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: insight.systemImage)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(insight.title)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(BXPalette.textPrimary)
                        Text(insight.message)
                            .font(.caption2)
                            .foregroundStyle(BXPalette.textSecondary)
                            .lineLimit(3)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .bxGlassCard(cornerRadius: 16)
            }
        }
    }

    private var healthScoreCard: some View {
        let health = supabase.analytics.healthScore
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(supabase.onboardingProfile.text(en: "Financial Health", es: "Salud Financiera",
                        pt: "Saúde Financeira", fr: "Santé Financière", ar: "الصحة المالية",
                        de: "Finanzielle Gesundheit", it: "Salute Finanziaria", nl: "Financiële Gezondheid",
                        ja: "財務健全性", ko: "재무 건강"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(BXPalette.textTertiary)
                        .tracking(1.0)
                        .textCase(.uppercase)
                    Text(supabase.onboardingProfile.text(en: "Score", es: "Puntaje",
                        pt: "Pontuação", fr: "Score", ar: "النتيجة", de: "Bewertung",
                        it: "Punteggio", nl: "Score", ja: "スコア", ko: "점수"))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(BXPalette.textPrimary)
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(BXPalette.fieldFill, lineWidth: 6)
                        .frame(width: 56, height: 56)
                    Circle()
                        .trim(from: 0, to: CGFloat(health.score) / 100.0)
                        .stroke(healthColor(health.score), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 56, height: 56)
                        .rotationEffect(.degrees(-90))
                    Text(health.grade)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(healthColor(health.score))
                }
            }

            if !health.factors.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(health.factors.prefix(3), id: \.title) { factor in
                        HStack(spacing: 8) {
                            Image(systemName: factor.impact == .positive ? "checkmark.circle.fill" : factor.impact == .negative ? "exclamationmark.circle.fill" : "minus.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(factor.impact == .positive ? BXPalette.income : factor.impact == .negative ? BXPalette.expense : BXPalette.textTertiary)
                            Text(factor.title)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(BXPalette.textSecondary)
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bxGlassCard(cornerRadius: 24)
    }

    private func healthColor(_ score: Int) -> Color {
        switch score {
        case 80...100: return BXPalette.income
        case 60..<80: return BXPalette.warning
        default: return BXPalette.expense
        }
    }

    private var smartAlertsSection: some View {
        let alerts = buildSmartAlerts()
        return Group {
            if !alerts.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(alerts, id: \.title) { alert in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: alert.icon)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 26, height: 26)
                                .background(alert.color, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(alert.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(BXPalette.textPrimary)
                                Text(alert.message)
                                    .font(.caption2)
                                    .foregroundStyle(BXPalette.textSecondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
                .padding(16)
                .bxGlassCard(cornerRadius: 20)
            }
        }
    }

    private struct SmartAlert {
        let title: String
        let message: String
        let icon: String
        let color: Color
    }

    private func buildSmartAlerts() -> [SmartAlert] {
        var alerts: [SmartAlert] = []
        let prof = supabase.onboardingProfile
        let cc = prof.currencyCode

        let recentExpenses = supabase.transactions.filter { $0.type == .expense }
        let calendar = Calendar.current
        let now = Date.now
        let thisWeek = recentExpenses.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .weekOfYear) }
        let lastWeekDate = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
        let lastWeek = recentExpenses.filter { calendar.isDate($0.date, equalTo: lastWeekDate, toGranularity: .weekOfYear) }
        let thisWeekTotal = thisWeek.reduce(into: Decimal.zero) { $0 += $1.amount }
        let lastWeekTotal = lastWeek.reduce(into: Decimal.zero) { $0 += $1.amount }

        if lastWeekTotal > .zero {
            let change = ((thisWeekTotal as NSDecimalNumber).doubleValue - (lastWeekTotal as NSDecimalNumber).doubleValue) / (lastWeekTotal as NSDecimalNumber).doubleValue
            if change > 0.2 {
                let pct = Int((change * 100).rounded())
                alerts.append(SmartAlert(
                    title: prof.text(en: "Spending increase", es: "Gasto en aumento", pt: "Aumento de gastos", fr: "Hausse des dépenses",
                        ar: "زيادة في الإنفاق", de: "Ausgaben gestiegen", it: "Aumento delle spese", nl: "Meer uitgaven",
                        ja: "支出増加", ko: "지출 증가"),
                    message: prof.text(
                        en: "You're spending \(pct)% more than last week.",
                        es: "Gastas \(pct)% más que la semana pasada.",
                        pt: "Você gasta \(pct)% a mais do que na semana passada.",
                        fr: "Vous dépensez \(pct)% de plus que la semaine dernière.",
                        ar: "أنت تنفق \(pct)٪ أكثر من الأسبوع الماضي.",
                        de: "Du gibst \(pct)% mehr aus als letzte Woche.",
                        it: "Stai spendendo il \(pct)% in più rispetto alla settimana scorsa.",
                        nl: "Je geeft \(pct)% meer uit dan vorige week.",
                        ja: "先週より\(pct)%多く支出しています。",
                        ko: "지난 주보다 \(pct)% 더 지출하고 있습니다."
                    ),
                    icon: "arrow.up.right",
                    color: BXPalette.expense
                ))
            }
        }

        let predicted = supabase.analytics.predictedBalance
        if predicted < .zero {
            alerts.append(SmartAlert(
                title: prof.text(en: "Balance prediction", es: "Predicción de balance", pt: "Previsão de saldo", fr: "Prévision de solde",
                    ar: "توقع الرصيد", de: "Saldo-Prognose", it: "Previsione saldo", nl: "Saldo voorspelling",
                    ja: "残高予測", ko: "잔액 예측"),
                message: prof.text(
                    en: "At current pace, your balance may be \(predicted.smartCurrencyString(code: cc)) by month end.",
                    es: "Al ritmo actual, tu balance podría ser \(predicted.smartCurrencyString(code: cc)) al fin de mes.",
                    pt: "No ritmo atual, seu saldo pode ser \(predicted.smartCurrencyString(code: cc)) ao fim do mês.",
                    fr: "Au rythme actuel, votre solde pourrait être \(predicted.smartCurrencyString(code: cc)) en fin de mois.",
                    ar: "بالوتيرة الحالية، قد يكون رصيدك \(predicted.smartCurrencyString(code: cc)) بنهاية الشهر.",
                    de: "Bei aktuellem Tempo könnte dein Saldo bis Monatsende \(predicted.smartCurrencyString(code: cc)) betragen.",
                    it: "Al ritmo attuale, il tuo saldo potrebbe essere \(predicted.smartCurrencyString(code: cc)) a fine mese.",
                    nl: "Bij huidig tempo kan je saldo \(predicted.smartCurrencyString(code: cc)) zijn aan het einde van de maand.",
                    ja: "現在のペースでは、月末の残高は\(predicted.smartCurrencyString(code: cc))になる可能性があります。",
                    ko: "현재 속도로는 월말 잔액이 \(predicted.smartCurrencyString(code: cc))이 될 수 있습니다."
                ),
                icon: "chart.line.downtrend.xyaxis",
                color: BXPalette.warning
            ))
        }

        if let budget = supabase.currentMonthlyBudget {
            let spent = supabase.totalSpentThisMonth()
            if spent > budget.monthlyLimit {
                alerts.append(SmartAlert(
                    title: prof.text(en: "Monthly budget exceeded", es: "Presupuesto mensual excedido",
                        pt: "Orçamento mensal excedido", fr: "Budget mensuel dépassé",
                        ar: "تم تجاوز الميزانية الشهرية", de: "Monatsbudget überschritten",
                        it: "Budget mensile superato", nl: "Maandbudget overschreden",
                        ja: "月間予算超過", ko: "월 예산 초과"),
                    message: prof.text(
                        en: "Spent \(spent.smartCurrencyString(code: cc)) of \(budget.monthlyLimit.smartCurrencyString(code: cc)) this month.",
                        es: "Gastaste \(spent.smartCurrencyString(code: cc)) de \(budget.monthlyLimit.smartCurrencyString(code: cc)) este mes.",
                        pt: "Gastou \(spent.smartCurrencyString(code: cc)) de \(budget.monthlyLimit.smartCurrencyString(code: cc)) este mês.",
                        fr: "Dépensé \(spent.smartCurrencyString(code: cc)) sur \(budget.monthlyLimit.smartCurrencyString(code: cc)) ce mois-ci.",
                        ar: "أُنفق \(spent.smartCurrencyString(code: cc)) من \(budget.monthlyLimit.smartCurrencyString(code: cc)) هذا الشهر.",
                        de: "\(spent.smartCurrencyString(code: cc)) von \(budget.monthlyLimit.smartCurrencyString(code: cc)) diesen Monat ausgegeben.",
                        it: "Speso \(spent.smartCurrencyString(code: cc)) su \(budget.monthlyLimit.smartCurrencyString(code: cc)) questo mese.",
                        nl: "\(spent.smartCurrencyString(code: cc)) van \(budget.monthlyLimit.smartCurrencyString(code: cc)) deze maand uitgegeven.",
                        ja: "今月 \(budget.monthlyLimit.smartCurrencyString(code: cc)) のうち \(spent.smartCurrencyString(code: cc)) を支出しました。",
                        ko: "이번 달 \(budget.monthlyLimit.smartCurrencyString(code: cc)) 중 \(spent.smartCurrencyString(code: cc))을 지출했습니다."
                    ),
                    icon: "exclamationmark.triangle.fill",
                    color: BXPalette.expense
                ))
            }
        }

        return alerts
    }

    private var cashFlowValue: Decimal {
        supabase.analytics.chartPoints[period]?.last ?? .zero
    }

    private func localizedPeriod(_ period: DashboardPeriod) -> String {
        let p = supabase.onboardingProfile
        switch period {
        case .daily:
            return p.text(en: "Daily",   es: "Diario",   pt: "Diário",      fr: "Quotidien",
                          ar: "يومي",    de: "Täglich",   it: "Giornaliero", nl: "Dagelijks",
                          ja: "日次",    ko: "일별")
        case .weekly:
            return p.text(en: "Weekly",  es: "Semanal",  pt: "Semanal",     fr: "Hebdomadaire",
                          ar: "أسبوعي", de: "Wöchentlich", it: "Settimanale", nl: "Wekelijks",
                          ja: "週次",    ko: "주별")
        case .monthly:
            return p.text(en: "Monthly", es: "Mensual",  pt: "Mensal",      fr: "Mensuel",
                          ar: "شهري",   de: "Monatlich", it: "Mensile",     nl: "Maandelijks",
                          ja: "月次",    ko: "월별")
        }
    }

}

// MARK: - Transactions View

private enum BXTransactionFilter: String, CaseIterable, Identifiable {
    case all, income, expense
    var id: String { rawValue }
    func label(_ profile: OnboardingProfile) -> String {
        switch self {
        case .all:
            return profile.text(en: "All",      es: "Todos",    pt: "Todos",    fr: "Tous",
                                ar: "الكل",     de: "Alle",     it: "Tutti",    nl: "Alle",
                                ja: "すべて",   ko: "전체")
        case .income:
            return profile.text(en: "Income",   es: "Ingresos", pt: "Receitas", fr: "Revenus",
                                ar: "الدخل",    de: "Einnahmen", it: "Entrate", nl: "Inkomsten",
                                ja: "収入",     ko: "수입")
        case .expense:
            return profile.text(en: "Expenses", es: "Gastos",   pt: "Despesas", fr: "Dépenses",
                                ar: "المصروفات", de: "Ausgaben", it: "Spese",   nl: "Uitgaven",
                                ja: "支出",     ko: "지출")
        }
    }
}

private enum BXReceiptFilter: String, CaseIterable, Identifiable {
    case any, withReceipt, withoutReceipt
    var id: String { rawValue }

    func label(_ profile: OnboardingProfile) -> String {
        switch self {
        case .any:
            return profile.text(en: "Any receipt", es: "Cualquier recibo", pt: "Qualquer recibo", fr: "Tout reçu", ar: "أي إيصال", de: "Jeder Beleg", it: "Qualsiasi ricevuta", nl: "Elke bon", ja: "任意のレシート", ko: "모든 영수증")
        case .withReceipt:
            return profile.text(en: "With receipt", es: "Con recibo", pt: "Com recibo", fr: "Avec reçu", ar: "مع إيصال", de: "Mit Beleg", it: "Con ricevuta", nl: "Met bon", ja: "レシートあり", ko: "영수증 있음")
        case .withoutReceipt:
            return profile.text(en: "Without receipt", es: "Sin recibo", pt: "Sem recibo", fr: "Sans reçu", ar: "بدون إيصال", de: "Ohne Beleg", it: "Senza ricevuta", nl: "Zonder bon", ja: "レシートなし", ko: "영수증 없음")
        }
    }
}

private struct BXMiniTextField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(BXPalette.textTertiary)
            TextField("0", text: $text)
                .keyboardType(.decimalPad)
                .padding(10)
                .background(BXPalette.fieldFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

private struct BXTransactionsView: View {
    @EnvironmentObject private var supabase: SupabaseManager
    private let startFilter: BXTransactionFilter
    @State private var selectedCategory = "All"
    @State private var selectedFilter: BXTransactionFilter
    @State private var editingTransaction: AccountingTransaction?
    @State private var selectedTransaction: AccountingTransaction?
    @State private var searchText = ""
    @State private var showAdvancedFilters = false
    @State private var useDateRange = false
    @State private var startDate = Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now
    @State private var endDate = Date.now
    @State private var minAmount = ""
    @State private var maxAmount = ""
    @State private var receiptFilter: BXReceiptFilter = .any
    @State private var reconciliationFilter: ReconciliationStatus?
    @State private var showCategoriesSheet = false
    @State private var newCategoryName = ""

    init(initialFilter: BXTransactionFilter = .all) {
        startFilter = initialFilter
        _selectedFilter = State(initialValue: initialFilter)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header row with income/expense summary
            HStack(alignment: .firstTextBaseline) {
                BXSectionTitle(
                    eyebrow: supabase.onboardingProfile.text(en: "Ledger",    es: "Registro",
                                                              pt: "Registro", fr: "Grand livre",
                                                              ar: "السجل",    de: "Buch",
                                                              it: "Registro", nl: "Grootboek",
                                                              ja: "台帳",      ko: "장부"),
                    title: supabase.onboardingProfile.text(en: "Transactions", es: "Movimientos",
                                                            pt: "Transações",  fr: "Opérations",
                                                            ar: "المعاملات",  de: "Transaktionen",
                                                            it: "Transazioni", nl: "Transacties",
                                                            ja: "取引",         ko: "거래")
                )
                Spacer()
                HStack(spacing: 12) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("+" + supabase.analytics.totalIncome.smartCurrencyString(code: supabase.onboardingProfile.currencyCode))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(BXPalette.income)
                        Text("-" + supabase.analytics.totalExpenses.smartCurrencyString(code: supabase.onboardingProfile.currencyCode))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(BXPalette.expense)
                    }
                    Button {
                        showCategoriesSheet = true
                    } label: {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(BXPalette.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(BXPalette.panelFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .sheet(isPresented: $showCategoriesSheet) {
                BXCategoriesSheet(newCategoryName: $newCategoryName)
                    .environmentObject(supabase)
            }

            typeFilter
            categoryFilter
            advancedSearchPanel

            if filteredTransactions.isEmpty {
                BXEmptyStateCard(
                    title: supabase.onboardingProfile.text(en: "No transactions yet", es: "Sin transacciones",
                                                            pt: "Sem transações",      fr: "Aucune opération",
                                                            ar: "لا توجد معاملات",    de: "Keine Transaktionen",
                                                            it: "Nessuna transazione", nl: "Geen transacties",
                                                            ja: "取引なし",             ko: "거래 없음"),
                    message: supabase.onboardingProfile.text(en: "Your expense feed will appear here.",
                                                              es: "Tus movimientos apareceran aqui.",
                                                              pt: "Suas transações aparecerão aqui.",
                                                              fr: "Vos opérations apparaîtront ici.",
                                                              ar: "ستظهر معاملاتك هنا.",
                                                              de: "Ihre Transaktionen erscheinen hier.",
                                                              it: "Le tue transazioni appariranno qui.",
                                                              nl: "Uw transacties verschijnen hier.",
                                                              ja: "取引がここに表示されます。",
                                                              ko: "거래 내역이 여기에 표시됩니다."),
                    systemImage: "tray"
                )
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(groupedTransactions.keys.sorted(by: >), id: \.self) { monthKey in
                        let transactions = groupedTransactions[monthKey] ?? []

                        // Month/Year header
                        HStack {
                            Text(monthKey)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(BXPalette.textTertiary)
                                .textCase(.uppercase)
                            VStack { Divider() }
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 8)

                        VStack(spacing: 0) {
                            ForEach(Array(transactions.enumerated()), id: \.element.id) { index, transaction in
                                BXTransactionRow(
                                    transaction: transaction,
                                    currencyCode: supabase.onboardingProfile.currencyCode,
                                    profile: supabase.onboardingProfile,
                                    onOpen: { selectedTransaction = transaction },
                                    onEdit: { editingTransaction = transaction },
                                    onDelete: {
                                        Task {
                                            _ = await supabase.deleteTransaction(transaction)
                                        }
                                    }
                                )
                                .contextMenu {
                                    Button(supabase.onboardingProfile.text(en: "Edit", es: "Editar", pt: "Editar", fr: "Modifier", ar: "تعديل", de: "Bearbeiten", it: "Modifica", nl: "Bewerken", ja: "編集", ko: "편집"), systemImage: "pencil") {
                                        editingTransaction = transaction
                                    }
                                    Button(supabase.onboardingProfile.text(en: "Delete", es: "Eliminar", pt: "Excluir", fr: "Supprimer", ar: "حذف", de: "Löschen", it: "Elimina", nl: "Verwijderen", ja: "削除", ko: "삭제"), systemImage: "trash", role: .destructive) {
                                        Task {
                                            _ = await supabase.deleteTransaction(transaction)
                                        }
                                    }
                                }

                                if index < transactions.count - 1 {
                                    Divider()
                                        .padding(.leading, 52)
                                }
                            }
                        }
                        .bxGlassCard(cornerRadius: 16)
                    }
                }
            }
        }
        .sheet(item: $editingTransaction) { transaction in
            AddExpenseView(initialTransaction: transaction)
                .environmentObject(supabase)
        }
        .sheet(item: $selectedTransaction) { transaction in
            BXTransactionDetailView(transaction: transaction)
                .environmentObject(supabase)
        }
    }

    private var typeFilter: some View {
        HStack(spacing: 8) {
            ForEach(BXTransactionFilter.allCases) { filter in
                let isSelected = selectedFilter == filter
                Button(filter.label(supabase.onboardingProfile)) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.80)) {
                        selectedFilter = filter
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? .black : BXPalette.textSecondary)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(isSelected ? Color.white : BXPalette.fieldFill, in: Capsule())
            }
            Spacer()
        }
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(categories, id: \.self) { category in
                    let isSelected = selectedCategory == category
                    Button(localizedCategory(category)) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            selectedCategory = category
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? .black : BXPalette.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isSelected ? Color.white : BXPalette.fieldFill, in: Capsule())
                }
            }
        }
    }

    private var advancedSearchPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(BXPalette.textTertiary)
                TextField(supabase.onboardingProfile.text(en: "Search vendor, notes, category", es: "Buscar comercio, notas, categoria", pt: "Buscar fornecedor, notas, categoria", fr: "Rechercher fournisseur, notes, categorie", ar: "ابحث عن البائع أو الملاحظات أو الفئة", de: "Anbieter, Notizen, Kategorie suchen", it: "Cerca fornitore, note, categoria", nl: "Zoek leverancier, notities, categorie", ja: "店舗、メモ、カテゴリを検索", ko: "판매처, 메모, 카테고리 검색"), text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showAdvancedFilters.toggle()
                    }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(showAdvancedFilters ? .black : BXPalette.textSecondary)
                        .frame(width: 34, height: 34)
                        .background(showAdvancedFilters ? Color.white : BXPalette.fieldFill, in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(BXPalette.fieldFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            if showAdvancedFilters {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(supabase.onboardingProfile.text(en: "Date range", es: "Rango de fechas", pt: "Intervalo de datas", fr: "Plage de dates", ar: "نطاق التاريخ", de: "Datumsbereich", it: "Intervallo date", nl: "Datumbereik", ja: "日付範囲", ko: "날짜 범위"), isOn: $useDateRange)
                        .tint(BXPalette.accentStart)
                    if useDateRange {
                        DatePicker(supabase.onboardingProfile.text(en: "From", es: "Desde", pt: "De", fr: "De", ar: "من", de: "Von", it: "Da", nl: "Van", ja: "開始", ko: "시작"), selection: $startDate, displayedComponents: .date)
                        DatePicker(supabase.onboardingProfile.text(en: "To", es: "Hasta", pt: "Ate", fr: "A", ar: "إلى", de: "Bis", it: "A", nl: "Tot", ja: "終了", ko: "종료"), selection: $endDate, displayedComponents: .date)
                    }
                    HStack(spacing: 10) {
                        BXMiniTextField(title: supabase.onboardingProfile.text(en: "Min", es: "Min", pt: "Min", fr: "Min", ar: "الحد الأدنى", de: "Min", it: "Min", nl: "Min", ja: "最小", ko: "최소"), text: $minAmount)
                        BXMiniTextField(title: supabase.onboardingProfile.text(en: "Max", es: "Max", pt: "Max", fr: "Max", ar: "الحد الأقصى", de: "Max", it: "Max", nl: "Max", ja: "最大", ko: "최대"), text: $maxAmount)
                    }
                    Picker(supabase.onboardingProfile.text(en: "Receipt", es: "Recibo", pt: "Recibo", fr: "Recu", ar: "إيصال", de: "Beleg", it: "Ricevuta", nl: "Bon", ja: "レシート", ko: "영수증"), selection: $receiptFilter) {
                        ForEach(BXReceiptFilter.allCases) { filter in
                            Text(filter.label(supabase.onboardingProfile)).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    Picker(supabase.onboardingProfile.text(en: "Reconciliation", es: "Conciliacion", pt: "Conciliacao", fr: "Rapprochement", ar: "مطابقة", de: "Abgleich", it: "Riconciliazione", nl: "Afstemming", ja: "照合", ko: "조정"), selection: $reconciliationFilter) {
                        Text(supabase.onboardingProfile.text(en: "Any", es: "Cualquiera", pt: "Qualquer", fr: "Tous", ar: "أي", de: "Alle", it: "Qualsiasi", nl: "Elke", ja: "任意", ko: "모두")).tag(nil as ReconciliationStatus?)
                        ForEach(ReconciliationStatus.allCases) { status in
                            Text(statusLabel(status)).tag(Optional(status))
                        }
                    }
                }
                .font(.caption)
                .padding(14)
                .background(BXPalette.panelFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    private var categories: [String] {
        let hidden = Set(supabase.customCategories.filter(\.isHidden).map { normalized($0.name) })
        let custom = supabase.customCategories.filter { !$0.isHidden }.map(\.name)
        let transactionCategories = supabase.transactions.map(\.category).filter { !hidden.contains(normalized($0)) }
        return ["All"] + Array(Set(transactionCategories + custom)).sorted()
    }

    private var filteredTransactions: [AccountingTransaction] {
        let ordered = supabase.transactions.sorted {
            if Calendar.current.isDate($0.date, inSameDayAs: $1.date) {
                return $0.createdAt > $1.createdAt
            }
            return $0.date > $1.date
        }

        let typeFiltered: [AccountingTransaction]
        switch selectedFilter {
        case .all:     typeFiltered = ordered
        case .income:  typeFiltered = ordered.filter { $0.type == .income }
        case .expense: typeFiltered = ordered.filter { $0.type == .expense }
        }

        let categoryFiltered = selectedCategory == "All"
            ? typeFiltered
            : typeFiltered.filter { $0.category == selectedCategory }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let minValue = Decimal(string: minAmount.replacingOccurrences(of: ",", with: "."))
        let maxValue = Decimal(string: maxAmount.replacingOccurrences(of: ",", with: "."))
        let endOfSelectedDay = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: endDate)) ?? endDate

        return categoryFiltered.filter { transaction in
            if !query.isEmpty {
                let haystack = [transaction.vendor, transaction.category, transaction.notes ?? ""].joined(separator: " ")
                guard haystack.localizedCaseInsensitiveContains(query) else { return false }
            }
            if useDateRange, !(transaction.date >= Calendar.current.startOfDay(for: startDate) && transaction.date < endOfSelectedDay) {
                return false
            }
            if let minValue, transaction.amount < minValue { return false }
            if let maxValue, transaction.amount > maxValue { return false }
            switch receiptFilter {
            case .any:
                break
            case .withReceipt:
                guard supabase.receipt(for: transaction.id) != nil else { return false }
            case .withoutReceipt:
                guard supabase.receipt(for: transaction.id) == nil else { return false }
            }
            if let reconciliationFilter, supabase.reconciliationStatus(for: transaction) != reconciliationFilter {
                return false
            }
            return true
        }
    }

    private var groupedTransactions: [String: [AccountingTransaction]] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return Dictionary(grouping: filteredTransactions) { transaction in
            formatter.string(from: transaction.date)
        }
    }

    private func localizedCategory(_ category: String) -> String {
        if category == "All" {
            return supabase.onboardingProfile.text(en: "All",  es: "Todas",
                                                    pt: "Todas", fr: "Toutes",
                                                    ar: "الكل",  de: "Alle",
                                                    it: "Tutte", nl: "Alle",
                                                    ja: "すべて", ko: "전체")
        }
        return category
    }

    private func statusLabel(_ status: ReconciliationStatus) -> String {
        switch status {
        case .pending:
            return supabase.onboardingProfile.text(en: "Pending", es: "Pendiente", pt: "Pendente", fr: "En attente", ar: "معلق", de: "Ausstehend", it: "In sospeso", nl: "In behandeling", ja: "保留中", ko: "보류")
        case .reviewed:
            return supabase.onboardingProfile.text(en: "Reviewed", es: "Revisado", pt: "Revisado", fr: "Verifie", ar: "تمت المراجعة", de: "Geprueft", it: "Revisionato", nl: "Beoordeeld", ja: "確認済み", ko: "검토됨")
        case .reconciled:
            return supabase.onboardingProfile.text(en: "Reconciled", es: "Conciliado", pt: "Conciliado", fr: "Rapproche", ar: "تمت المطابقة", de: "Abgeglichen", it: "Riconciliato", nl: "Afgestemd", ja: "照合済み", ko: "조정됨")
        }
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}

// MARK: - Reports View

private struct BXReportsView: View {
    @EnvironmentObject private var supabase: SupabaseManager
    @Binding var period: DashboardPeriod
    @State private var exportDocument: ExportDocument?
    @State private var showingSubscriptionForm = false
    @State private var depositGoal: SavingsGoal?
    @State private var showingGenerator = false
    @State private var showingBudgetForm = false
    @State private var showingSavingsGoalForm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with Export button
            HStack {
                BXSectionTitle(
                    eyebrow: supabase.onboardingProfile.text(en: "Analysis",   es: "Análisis",
                                                              pt: "Análise",    fr: "Analyse",
                                                              ar: "التحليل",    de: "Analyse",
                                                              it: "Analisi",    nl: "Analyse",
                                                              ja: "分析",        ko: "분석"),
                    title: supabase.onboardingProfile.text(en: "Reports",   es: "Reportes",
                                                            pt: "Relatórios", fr: "Rapports",
                                                            ar: "التقارير",   de: "Berichte",
                                                            it: "Rapporti",   nl: "Rapporten",
                                                            ja: "レポート",    ko: "보고서")
                )
                Spacer()
                Button {
                    showingGenerator = true
                } label: {
                    Label(supabase.onboardingProfile.text(en: "Export",   es: "Exportar",
                                                          pt: "Exportar", fr: "Exporter",
                                                          ar: "تصدير",    de: "Exportieren",
                                                          it: "Esporta",  nl: "Exporteren",
                                                          ja: "エクスポート", ko: "내보내기"),
                          systemImage: "arrow.up.doc")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.white, in: Capsule())
                }
                .buttonStyle(.plain)
            }

            // Period tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DashboardPeriod.allCases) { p in
                        let isSelected = period == p
                        Button(periodLabel(p)) {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.80)) {
                                period = p
                            }
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? .black : BXPalette.textSecondary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(isSelected ? Color.white : BXPalette.fieldFill, in: Capsule())
                        .buttonStyle(.plain)
                    }
                }
            }

            if supabase.transactions.isEmpty {
                BXEmptyStateCard(
                    title: supabase.onboardingProfile.text(en: "Reports unlock after first entries", es: "Reportes se activan con movimientos", pt: "Relatórios são liberados após os primeiros lançamentos", fr: "Les rapports se débloquent après les premières entrées", ar: "يتم فتح التقارير بعد أولى الإدخالات", de: "Berichte werden nach den ersten Einträgen freigeschaltet", it: "I report si sbloccano dopo le prime registrazioni", nl: "Rapporten worden ontgrendeld na de eerste invoer", ja: "レポートは最初の記録後に有効になります", ko: "보고서는 첫 기록 후 활성화됩니다"),
                    message: supabase.onboardingProfile.text(en: "Start by scanning or adding an expense.", es: "Empieza agregando un gasto.", pt: "Comece escaneando ou adicionando uma despesa.", fr: "Commencez par scanner ou ajouter une dépense.", ar: "ابدأ بمسح مصروف أو إضافته.", de: "Beginne mit dem Scannen oder Hinzufügen einer Ausgabe.", it: "Inizia scansionando o aggiungendo una spesa.", nl: "Begin met het scannen of toevoegen van een uitgave.", ja: "まずは支出をスキャンまたは追加してください。", ko: "지출을 스캔하거나 추가하는 것부터 시작하세요."),
                    systemImage: "chart.bar.doc.horizontal"
                )
            } else {
                summaryRow

                VStack(alignment: .leading, spacing: 14) {
                    Text(supabase.onboardingProfile.text(en: "Period comparison", es: "Comparación", pt: "Comparação por período", fr: "Comparaison par période", ar: "مقارنة الفترات", de: "Zeitraumvergleich", it: "Confronto periodo", nl: "Periodevergelijking", ja: "期間比較", ko: "기간 비교"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BXPalette.textPrimary)
                    BXLineChart(points: supabase.analytics.chartPoints[period] ?? [])
                        .frame(height: 160)
                }
                .padding(20)
                .bxGlassCard(cornerRadius: 20)

                // Category breakdown
                categoryBreakdownSection

                // Tax summary
                VStack(alignment: .leading, spacing: 12) {
                    Text(supabase.onboardingProfile.text(en: "Tax-ready summary", es: "Resumen fiscal", pt: "Resumo fiscal", fr: "Résumé fiscal", ar: "ملخص ضريبي", de: "Steuerübersicht", it: "Riepilogo fiscale", nl: "Fiscaal overzicht", ja: "税務サマリー", ko: "세무 요약"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BXPalette.textPrimary)
                    reportRow(title: supabase.onboardingProfile.text(en: "Gross revenue", es: "Ingresos brutos", pt: "Receita bruta", fr: "Revenus bruts", ar: "الإيرادات الإجمالية", de: "Bruttoumsatz", it: "Ricavi lordi", nl: "Bruto-omzet", ja: "総売上", ko: "총매출"), value: supabase.analytics.totalIncome)
                    reportRow(title: supabase.onboardingProfile.text(en: "Deductible expenses", es: "Gastos deducibles", pt: "Despesas dedutíveis", fr: "Dépenses déductibles", ar: "المصروفات القابلة للخصم", de: "Absetzbare Ausgaben", it: "Spese deducibili", nl: "Aftrekbare kosten", ja: "控除対象経費", ko: "공제 가능 비용"), value: supabase.analytics.totalExpenses)
                    reportRow(title: supabase.onboardingProfile.text(en: "Estimated profit", es: "Ganancia estimada", pt: "Lucro estimado", fr: "Bénéfice estimé", ar: "الربح التقديري", de: "Geschätzter Gewinn", it: "Profitto stimato", nl: "Geschatte winst", ja: "推定利益", ko: "예상 이익"), value: supabase.analytics.profit)
                    reportRow(title: supabase.onboardingProfile.text(en: "Estimated taxes", es: "Impuestos estimados", pt: "Impostos estimados", fr: "Impôts estimés", ar: "الضرائب التقديرية", de: "Geschätzte Steuern", it: "Tasse stimate", nl: "Geschatte belastingen", ja: "推定税額", ko: "예상 세금"), value: supabase.estimatedTaxes)
                }
                .padding(20)
                .bxGlassCard(cornerRadius: 20)

                budgetSection
                savingsGoalsSection
                subscriptionSection
            }
        }
        .sheet(item: $exportDocument) { document in
            BXShareSheet(items: [document.fileURL])
        }
        .sheet(isPresented: $showingGenerator) {
            BXReportGeneratorView { format, includedCategories in
                generateExport(format: format, categories: includedCategories)
            }
            .environmentObject(supabase)
        }
        .sheet(isPresented: $showingSubscriptionForm) {
            BXSubscriptionFormView()
                .environmentObject(supabase)
        }
        .sheet(isPresented: $showingBudgetForm) {
            BXBudgetFormView()
                .environmentObject(supabase)
        }
        .sheet(isPresented: $showingSavingsGoalForm) {
            BXSavingsGoalFormView()
                .environmentObject(supabase)
        }
        .sheet(item: $depositGoal) { goal in
            BXDepositToGoalView(goal: goal)
                .environmentObject(supabase)
        }
        .onAppear {
            if supabase.shouldAskForMonthlyBudget() {
                showingBudgetForm = true
            }
        }
    }

    private func periodLabel(_ period: DashboardPeriod) -> String {
        let p = supabase.onboardingProfile
        switch period {
        case .daily:
            return p.text(en: "Week",  es: "Semana", pt: "Semana", fr: "Semaine",
                          ar: "أسبوع", de: "Woche",  it: "Settimana", nl: "Week",
                          ja: "週",    ko: "주")
        case .weekly:
            return p.text(en: "Month", es: "Mes",    pt: "Mês",    fr: "Mois",
                          ar: "شهر",  de: "Monat",   it: "Mese",   nl: "Maand",
                          ja: "月",    ko: "월")
        case .monthly:
            return p.text(en: "Year",  es: "Año",    pt: "Ano",    fr: "Année",
                          ar: "سنة",  de: "Jahr",    it: "Anno",   nl: "Jaar",
                          ja: "年",    ko: "년")
        }
    }

    private var categoryBreakdownSection: some View {
        let cc = supabase.onboardingProfile.currencyCode
        let expenses = supabase.transactions.filter { $0.type == .expense }
        let total = expenses.reduce(into: Decimal.zero) { $0 += $1.amount }
        let byCategory = Dictionary(grouping: expenses, by: \.category)
            .mapValues { $0.reduce(into: Decimal.zero) { $0 += $1.amount } }
            .sorted { $0.value > $1.value }
            .prefix(6)

        return VStack(alignment: .leading, spacing: 12) {
            Text(supabase.onboardingProfile.text(en: "EXPENSES BY CATEGORY", es: "GASTOS POR CATEGORÍA", pt: "DESPESAS POR CATEGORIA", fr: "DÉPENSES PAR CATÉGORIE", ar: "المصروفات حسب الفئة", de: "AUSGABEN NACH KATEGORIE", it: "SPESE PER CATEGORIA", nl: "UITGAVEN PER CATEGORIE", ja: "カテゴリ別支出", ko: "카테고리별 지출"))
                .font(.caption2.weight(.bold))
                .foregroundStyle(BXPalette.textTertiary)
                .tracking(1.0)

            if byCategory.isEmpty {
                Text(supabase.onboardingProfile.text(en: "No expenses recorded.", es: "Sin gastos registrados.", pt: "Nenhuma despesa registrada.", fr: "Aucune dépense enregistrée.", ar: "لا توجد مصروفات مسجلة.", de: "Keine Ausgaben erfasst.", it: "Nessuna spesa registrata.", nl: "Geen uitgaven geregistreerd.", ja: "支出はまだ記録されていません。", ko: "기록된 지출이 없습니다."))
                    .font(.caption)
                    .foregroundStyle(BXPalette.textSecondary)
            } else {
                ForEach(byCategory, id: \.key) { cat, amount in
                    let pctDouble = total > 0
                        ? (amount as NSDecimalNumber).doubleValue / (total as NSDecimalNumber).doubleValue
                        : 0.0
                    let pct = Int((pctDouble * 100).rounded())
                    VStack(spacing: 6) {
                        HStack {
                            Text(cat)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(BXPalette.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            Text("\(pct)%")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(BXPalette.textSecondary)
                                .monospacedDigit()
                                .frame(width: 36, alignment: .trailing)
                            Text(amount.smartCurrencyString(code: cc))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BXPalette.expense)
                                .monospacedDigit()
                                .frame(width: 80, alignment: .trailing)
                        }
                        // Progress bar
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(BXPalette.fieldFill)
                                    .frame(height: 4)
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(BXPalette.expense.opacity(0.75))
                                    .frame(width: proxy.size.width * pctDouble, height: 4)
                            }
                        }
                        .frame(height: 4)
                    }
                    .padding(.vertical, 4)
                    if cat != byCategory.last?.key {
                        Divider().opacity(0.15)
                    }
                }
            }
        }
        .padding(20)
        .bxGlassCard(cornerRadius: 20)
    }

    private var reportGeneratorHero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(supabase.onboardingProfile.text(en: "Generate", es: "Generar", pt: "Gerar", fr: "Générer", ar: "إنشاء", de: "Erstellen", it: "Genera", nl: "Genereren", ja: "生成", ko: "생성"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BXPalette.textPrimary)
                    Text(supabase.onboardingProfile.text(
                        en: "Choose categories and export format.",
                        es: "Elige categorías y formato.",
                        pt: "Escolha categorias e formato.",
                        fr: "Choisissez les catégories et le format.",
                        ar: "اختر الفئات وتنسيق التصدير.",
                        de: "Wähle Kategorien und Exportformat.",
                        it: "Scegli categorie e formato.",
                        nl: "Kies categorieën en exportformaat.",
                        ja: "カテゴリと出力形式を選択してください。",
                        ko: "카테고리와 내보내기 형식을 선택하세요."
                    ))
                    .font(.caption)
                    .foregroundStyle(BXPalette.textSecondary)
                }
                Spacer()
                Image(systemName: "document.badge.gearshape")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(BXPalette.accentStart)
                    .frame(width: 42, height: 42)
                    .background(BXPalette.fieldFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            BXPrimaryButton(
                title: supabase.onboardingProfile.text(en: "Generate Report", es: "Generar reporte", pt: "Gerar relatório", fr: "Générer le rapport", ar: "إنشاء تقرير", de: "Bericht erstellen", it: "Genera report", nl: "Rapport genereren", ja: "レポートを生成", ko: "보고서 생성"),
                systemImage: "arrow.up.doc"
            ) {
                showingGenerator = true
            }
        }
        .padding(20)
        .bxGlassCard(cornerRadius: 24)
    }

    private var summaryRow: some View {
        let cc = supabase.onboardingProfile.currencyCode
        let income = supabase.analytics.totalIncome
        let expenses = supabase.analytics.totalExpenses
        let balance = income - expenses
        return VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Income card
                VStack(alignment: .leading, spacing: 6) {
                    Text(supabase.onboardingProfile.text(en: "INCOME", es: "INGRESOS", pt: "RECEITAS", fr: "REVENUS", ar: "الدخل", de: "EINNAHMEN", it: "ENTRATE", nl: "INKOMSTEN", ja: "収入", ko: "수입"))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(BXPalette.income.opacity(0.8))
                        .tracking(0.8)
                    Text("+\(income.smartCurrencyString(code: cc))")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(BXPalette.income)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .bxGlassCard()

                // Expenses card
                VStack(alignment: .leading, spacing: 6) {
                    Text(supabase.onboardingProfile.text(en: "EXPENSES", es: "GASTOS", pt: "DESPESAS", fr: "DÉPENSES", ar: "المصروفات", de: "AUSGABEN", it: "SPESE", nl: "UITGAVEN", ja: "支出", ko: "지출"))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(BXPalette.expense.opacity(0.8))
                        .tracking(0.8)
                    Text("-\(expenses.smartCurrencyString(code: cc))")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(BXPalette.expense)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .bxGlassCard()
            }

            // Balance row
            HStack {
                Text(supabase.onboardingProfile.text(en: "Balance", es: "Balance", pt: "Saldo", fr: "Solde", ar: "الرصيد", de: "Saldo", it: "Saldo", nl: "Saldo", ja: "残高", ko: "잔액"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BXPalette.textSecondary)
                Spacer()
                Text(balance >= 0 ? "+\(balance.smartCurrencyString(code: cc))" : balance.smartCurrencyString(code: cc))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(balance >= 0 ? BXPalette.income : BXPalette.expense)
                    .monospacedDigit()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .bxGlassCard()
        }
    }

    private func reportRow(title: String, value: Decimal) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(BXPalette.textSecondary)
            Spacer()
            Text(value.currencyString(code: supabase.onboardingProfile.currencyCode))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(BXPalette.textPrimary)
        }
    }

    private func generateExport(format: BXReportExportFormat, categories: Set<String>) {
        let filteredTransactions: [AccountingTransaction]
        if categories.isEmpty {
            filteredTransactions = supabase.transactions
        } else {
            filteredTransactions = supabase.transactions.filter { categories.contains($0.category) }
        }

        do {
            switch format {
            case .pdf:
                exportDocument = try ExportService.makePDF(
                    transactions: filteredTransactions,
                    companyName: supabase.onboardingProfile.primaryName,
                    currencyCode: supabase.onboardingProfile.currencyCode,
                    profile: supabase.onboardingProfile
                )
            case .excel:
                exportDocument = try ExportService.makeCSV(
                    transactions: filteredTransactions,
                    companyName: supabase.onboardingProfile.primaryName,
                    currencyCode: supabase.onboardingProfile.currencyCode,
                    profile: supabase.onboardingProfile
                )
            }
        } catch {
            supabase.errorMessage = error.localizedDescription
        }
    }

    private var budgetSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            let budget = supabase.currentMonthlyBudget
            let spent = supabase.totalSpentThisMonth()
            let monthlyLimit = budget?.monthlyLimit ?? .zero
            let progress = monthlyLimit > 0 ? min(Double(truncating: (spent / monthlyLimit) as NSDecimalNumber), 1.0) : 0
            let isOverBudget = monthlyLimit > 0 && spent > monthlyLimit

            HStack {
                Text(supabase.onboardingProfile.text(en: "Monthly Budget", es: "Presupuesto del mes", pt: "Orçamento mensal", fr: "Budget mensuel", ar: "الميزانية الشهرية", de: "Monatsbudget", it: "Budget mensile", nl: "Maandbudget", ja: "月間予算", ko: "월 예산"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BXPalette.textPrimary)
                Spacer()
                Button {
                    showingBudgetForm = true
                } label: {
                    Image(systemName: budget == nil ? "plus" : "pencil")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.14), in: Circle())
                }
                .buttonStyle(.plain)
            }

            if budget == nil {
                Text(supabase.onboardingProfile.text(
                    en: "Set this month's budget to track how much has been spent.",
                    es: "Define el presupuesto de este mes para ver cuánto se ha gastado.",
                    pt: "Defina o orçamento deste mês para acompanhar quanto foi gasto.",
                    fr: "Définissez le budget de ce mois pour suivre les dépenses.",
                    ar: "حدد ميزانية هذا الشهر لتتبع مقدار الإنفاق.",
                    de: "Lege das Monatsbudget fest, um die Ausgaben zu verfolgen.",
                    it: "Imposta il budget di questo mese per monitorare le spese.",
                    nl: "Stel het maandbudget in om uitgaven bij te houden.",
                    ja: "今月の予算を設定して支出を追跡しましょう。",
                    ko: "이번 달 예산을 설정해 지출을 추적하세요."
                ))
                .font(.caption)
                .foregroundStyle(BXPalette.textSecondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(supabase.onboardingProfile.text(en: "Spent this month", es: "Gastado este mes", pt: "Gasto este mês", fr: "Dépensé ce mois-ci", ar: "المصروف هذا الشهر", de: "Diesen Monat ausgegeben", it: "Speso questo mese", nl: "Deze maand uitgegeven", ja: "今月の支出", ko: "이번 달 지출"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(BXPalette.textPrimary)
                        Spacer()
                        Text("\(spent.currencyString(code: supabase.onboardingProfile.currencyCode)) / \(monthlyLimit.currencyString(code: supabase.onboardingProfile.currencyCode))")
                            .font(.caption.weight(.medium))
                            .monospacedDigit()
                            .foregroundStyle(isOverBudget ? BXPalette.expense : BXPalette.textSecondary)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(BXPalette.fieldFill)
                                .frame(height: 6)
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(isOverBudget ? BXPalette.expense : BXPalette.accentStart)
                                .frame(width: geo.size.width * progress, height: 6)
                        }
                    }
                    .frame(height: 6)
                }
                .padding(.vertical, 4)
                .contextMenu {
                    Button(role: .destructive) {
                        supabase.deleteCurrentMonthlyBudget()
                    } label: {
                        Label(supabase.onboardingProfile.text(en: "Delete", es: "Eliminar", pt: "Excluir", fr: "Supprimer", ar: "حذف", de: "Löschen", it: "Elimina", nl: "Verwijderen", ja: "削除", ko: "삭제"), systemImage: "trash")
                    }
                }
            }
        }
        .padding(20)
        .bxGlassCard(cornerRadius: 24)
    }

    private var savingsGoalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(supabase.onboardingProfile.text(en: "Savings Goals", es: "Metas de ahorro", pt: "Metas de poupança", fr: "Objectifs d'épargne", ar: "أهداف الادخار", de: "Sparziele", it: "Obiettivi di risparmio", nl: "Spaardoelen", ja: "貯蓄目標", ko: "저축 목표"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BXPalette.textPrimary)
                Spacer()
                Button {
                    showingSavingsGoalForm = true
                } label: {
                    Image(systemName: "plus")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.14), in: Circle())
                }
                .buttonStyle(.plain)
            }

            if supabase.savingsGoals.isEmpty {
                Text(supabase.onboardingProfile.text(en: "Set savings goals to track progress.", es: "Establece metas de ahorro para seguir tu progreso.", pt: "Defina metas de poupança para acompanhar o progresso.", fr: "Définissez des objectifs d'épargne pour suivre vos progrès.", ar: "حدّد أهداف ادخار لمتابعة تقدمك.", de: "Lege Sparziele fest, um deinen Fortschritt zu verfolgen.", it: "Imposta obiettivi di risparmio per monitorare i progressi.", nl: "Stel spaardoelen in om je voortgang te volgen.", ja: "進捗を追跡するために貯蓄目標を設定しましょう。", ko: "진행 상황을 추적할 저축 목표를 설정하세요."))
                    .font(.caption)
                    .foregroundStyle(BXPalette.textSecondary)
            } else {
                ForEach(supabase.savingsGoals) { goal in
                    VStack(alignment: .leading, spacing: 8) {
                        // Name + deadline
                        HStack(alignment: .firstTextBaseline) {
                            Text(goal.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(BXPalette.textPrimary)
                            Spacer()
                            if let targetDate = goal.targetDate {
                                let daysLeft = Calendar.current.dateComponents([.day], from: Date.now.startOfDay, to: targetDate.startOfDay).day ?? 0
                                Text(daysLeft > 0
                                     ? supabase.onboardingProfile.text(en: "\(daysLeft) days left", es: "\(daysLeft) días restantes", pt: "Faltam \(daysLeft) dias", fr: "Il reste \(daysLeft) jours", ar: "يتبقى \(daysLeft) يومًا", de: "Noch \(daysLeft) Tage", it: "Restano \(daysLeft) giorni", nl: "Nog \(daysLeft) dagen", ja: "残り\(daysLeft)日", ko: "\(daysLeft)일 남음")
                                     : supabase.onboardingProfile.text(en: "Deadline reached", es: "Plazo cumplido", pt: "Prazo atingido", fr: "Échéance atteinte", ar: "تم الوصول إلى الموعد", de: "Frist erreicht", it: "Scadenza raggiunta", nl: "Deadline bereikt", ja: "期限到達", ko: "마감 도달"))
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(daysLeft <= 7 ? BXPalette.expense : BXPalette.textTertiary)
                            }
                        }

                        // Progress bar + percentage
                        let progress = goal.targetAmount > .zero
                            ? min(1.0, (goal.savedAmount as NSDecimalNumber).doubleValue / (goal.targetAmount as NSDecimalNumber).doubleValue)
                            : 0.0
                        VStack(alignment: .leading, spacing: 4) {
                            GeometryReader { proxy in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(BXPalette.fieldFill)
                                        .frame(height: 7)
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(BXPalette.income)
                                        .frame(width: proxy.size.width * progress, height: 7)
                                }
                            }
                            .frame(height: 7)

                            HStack {
                                Text("\(goal.savedAmount.smartCurrencyString(code: supabase.onboardingProfile.currencyCode)) / \(goal.targetAmount.smartCurrencyString(code: supabase.onboardingProfile.currencyCode))")
                                    .font(.caption2.weight(.medium))
                                    .monospacedDigit()
                                    .foregroundStyle(BXPalette.textSecondary)
                                Spacer()
                                Text("\(Int(progress * 100))%")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(BXPalette.income)
                            }
                        }

                        // Full-width deposit button
                        Button {
                            depositGoal = goal
                        } label: {
                            Label(supabase.onboardingProfile.text(en: "Deposit", es: "Abonar", pt: "Depositar", fr: "Déposer", ar: "إيداع", de: "Einzahlen", it: "Deposita", nl: "Storten", ja: "入金", ko: "입금"), systemImage: "plus.circle.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(BXPalette.income, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 6)
                    .contextMenu {
                        Button {
                            depositGoal = goal
                        } label: {
                            Label(supabase.onboardingProfile.text(en: "Deposit", es: "Abonar", pt: "Depositar", fr: "Déposer", ar: "إيداع", de: "Einzahlen", it: "Deposita", nl: "Storten", ja: "入金", ko: "입금"), systemImage: "plus.circle")
                        }
                        Button(role: .destructive) {
                            supabase.deleteSavingsGoal(goal)
                        } label: {
                            Label(supabase.onboardingProfile.text(en: "Delete", es: "Eliminar", pt: "Excluir", fr: "Supprimer", ar: "حذف", de: "Löschen", it: "Elimina", nl: "Verwijderen", ja: "削除", ko: "삭제"), systemImage: "trash")
                        }
                    }
                }
            }
        }
        .padding(20)
        .bxGlassCard(cornerRadius: 24)
    }

    private var subscriptionSection: some View {
        let prof = supabase.onboardingProfile
        let currencyCode = prof.currencyCode
        let pendingCount = supabase.pendingSubscriptionsThisMonth.count

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(prof.text(en: "Monthly Payments", es: "Pagos mensuales", pt: "Pagamentos mensais", fr: "Paiements mensuels", ar: "الدفعات الشهرية", de: "Monatliche Zahlungen", it: "Pagamenti mensili", nl: "Maandelijkse betalingen", ja: "月次支払い", ko: "월간 결제"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BXPalette.textPrimary)
                if pendingCount > 0 {
                    Text("\(pendingCount)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(BXPalette.expense, in: Capsule())
                }
                Spacer()
                Button {
                    showingSubscriptionForm = true
                } label: {
                    Image(systemName: "plus")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.14), in: Circle())
                }
                .buttonStyle(.plain)
            }

            if supabase.subscriptions.isEmpty {
                Text(prof.text(
                    en: "Add rent, installments, and bills to receive reminders.",
                    es: "Agrega renta, cuotas y servicios para recibir recordatorios.",
                    pt: "Adicione aluguel, prestações e contas para receber lembretes.",
                    fr: "Ajoutez loyer, versements et factures pour recevoir des rappels.",
                    ar: "أضف الإيجار والأقساط والفواتير لتلقي التذكيرات.",
                    de: "Füge Miete, Raten und Rechnungen hinzu, um Erinnerungen zu erhalten.",
                    it: "Aggiungi affitto, rate e bollette per ricevere promemoria.",
                    nl: "Voeg huur, termijnen en rekeningen toe om herinneringen te ontvangen.",
                    ja: "家賃、分割払い、請求書を追加してリマインダーを受け取りましょう。",
                    ko: "알림을 받으려면 월세, 할부금, 청구서를 추가하세요."
                ))
                .font(.caption)
                .foregroundStyle(BXPalette.textSecondary)
            } else {
                ForEach(supabase.subscriptions) { subscription in
                    HStack(spacing: 10) {
                        Image(systemName: subscription.category.systemImage)
                            .font(.subheadline)
                            .foregroundStyle(subscription.isDueOrOverdue ? BXPalette.expense : BXPalette.accentStart)
                            .frame(width: 26, height: 26)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(subscription.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(BXPalette.textPrimary)
                            Text("\(subscription.category.label(prof)) · \(prof.text(en: "Day", es: "Día", pt: "Dia", fr: "Jour", ar: "اليوم", de: "Tag", it: "Giorno", nl: "Dag", ja: "日", ko: "일")) \(subscription.dueDay)")
                                .font(.caption2)
                                .foregroundStyle(BXPalette.textSecondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text(subscription.amount.currencyString(code: currencyCode))
                                .font(.subheadline.weight(.bold))
                                .monospacedDigit()
                                .foregroundStyle(BXPalette.textPrimary)

                            if subscription.isPaidThisMonth {
                                HStack(spacing: 3) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption2)
                                    Text(prof.text(en: "Paid", es: "Pagado", pt: "Pago", fr: "Payé", ar: "مدفوع", de: "Bezahlt", it: "Pagato", nl: "Betaald", ja: "支払い済み", ko: "결제 완료"))
                                        .font(.caption2.weight(.medium))
                                }
                                .foregroundStyle(BXPalette.income)
                            } else if subscription.isDueOrOverdue {
                                Button {
                                    supabase.markSubscriptionPaid(subscription, paid: true)
                                } label: {
                                    Text(prof.text(en: "Mark paid", es: "Marcar pagado", pt: "Marcar como pago", fr: "Marquer comme payé", ar: "وضع علامة مدفوع", de: "Als bezahlt markieren", it: "Segna come pagato", nl: "Markeer als betaald", ja: "支払い済みにする", ko: "결제 완료로 표시"))
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.black)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.white, in: Capsule())
                                }
                                .buttonStyle(.plain)
                            } else {
                                Text(prof.text(en: "Upcoming", es: "Próximo", pt: "A vencer", fr: "À venir", ar: "قادم", de: "Bevorstehend", it: "In arrivo", nl: "Aankomend", ja: "近日予定", ko: "예정"))
                                    .font(.caption2)
                                    .foregroundStyle(BXPalette.textTertiary)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                    .contextMenu {
                        if subscription.isPaidThisMonth {
                            Button {
                                supabase.markSubscriptionPaid(subscription, paid: false)
                            } label: {
                                Label(prof.text(en: "Mark as unpaid", es: "Marcar como no pagado", pt: "Marcar como não pago", fr: "Marquer comme impayé", ar: "وضع علامة غير مدفوع", de: "Als unbezahlt markieren", it: "Segna come non pagato", nl: "Markeer als onbetaald", ja: "未払いに戻す", ko: "미납으로 표시"), systemImage: "arrow.uturn.backward")
                            }
                        }
                        Button(role: .destructive) {
                            supabase.deleteSubscription(subscription)
                        } label: {
                            Label(prof.text(en: "Delete", es: "Eliminar", pt: "Excluir", fr: "Supprimer", ar: "حذف", de: "Löschen", it: "Elimina", nl: "Verwijderen", ja: "削除", ko: "삭제"), systemImage: "trash")
                        }
                    }
                }
            }
        }
        .padding(20)
        .bxGlassCard(cornerRadius: 24)
    }
}

private enum BXReportExportFormat: String, CaseIterable, Identifiable {
    case pdf
    case excel

    var id: String { rawValue }
}

// MARK: - Report Generator

private struct BXReportGeneratorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var supabase: SupabaseManager
    @State private var selectedFormat: BXReportExportFormat = .pdf
    @State private var selectedCategories: Set<String> = []

    let onGenerate: (BXReportExportFormat, Set<String>) -> Void

    private var categories: [String] {
        Array(Set(supabase.transactions.map(\.category))).sorted()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BXBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(supabase.onboardingProfile.text(en: "Generate report", es: "Generar reporte", pt: "Gerar relatório", fr: "Générer le rapport", ar: "إنشاء تقرير", de: "Bericht erstellen", it: "Genera report", nl: "Rapport genereren", ja: "レポートを生成", ko: "보고서 생성"))
                                .font(.title2.weight(.bold))
                                .foregroundStyle(BXPalette.textPrimary)
                            Text(supabase.onboardingProfile.text(
                                en: "Choose format and categories.",
                                es: "Elige formato y categorías.",
                                pt: "Escolha formato e categorias.",
                                fr: "Choisissez le format et les catégories.",
                                ar: "اختر التنسيق والفئات.",
                                de: "Wähle Format und Kategorien.",
                                it: "Scegli formato e categorie.",
                                nl: "Kies formaat en categorieën.",
                                ja: "形式とカテゴリを選択してください。",
                                ko: "형식과 카테고리를 선택하세요."
                            ))
                            .font(.caption)
                            .foregroundStyle(BXPalette.textSecondary)
                        }
                        .padding(20)
                        .bxGlassCard(cornerRadius: 24)

                        VStack(alignment: .leading, spacing: 12) {
                            Text(supabase.onboardingProfile.text(en: "Format", es: "Formato", pt: "Formato", fr: "Format", ar: "التنسيق", de: "Format", it: "Formato", nl: "Formaat", ja: "形式", ko: "형식"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(BXPalette.textPrimary)

                            Picker("", selection: $selectedFormat) {
                                Text("PDF").tag(BXReportExportFormat.pdf)
                                Text("Excel").tag(BXReportExportFormat.excel)
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(20)
                        .bxGlassCard(cornerRadius: 24)

                        if !categories.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(supabase.onboardingProfile.text(en: "Categories", es: "Categorías", pt: "Categorias", fr: "Catégories", ar: "الفئات", de: "Kategorien", it: "Categorie", nl: "Categorieën", ja: "カテゴリ", ko: "카테고리"))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(BXPalette.textPrimary)

                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                    ForEach(categories, id: \.self) { category in
                                        Button {
                                            if selectedCategories.contains(category) {
                                                selectedCategories.remove(category)
                                            } else {
                                                selectedCategories.insert(category)
                                            }
                                        } label: {
                                            HStack {
                                                Text(category)
                                                    .lineLimit(1)
                                                    .minimumScaleFactor(0.8)
                                                Spacer()
                                                if selectedCategories.contains(category) {
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(selectedCategories.contains(category) ? BXPalette.accentStart : BXPalette.textPrimary)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 12)
                                            .background(
                                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                    .fill(selectedCategories.contains(category) ? BXPalette.accentStart.opacity(0.10) : BXPalette.fieldFill)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }

                                Text(supabase.onboardingProfile.text(
                                    en: "Leave unselected to export all.",
                                    es: "Deja sin seleccionar para exportar todo.",
                                    pt: "Deixe sem selecionar para exportar tudo.",
                                    fr: "Ne sélectionnez rien pour tout exporter.",
                                    ar: "اتركه بدون تحديد لتصدير الكل.",
                                    de: "Nichts auswählen, um alles zu exportieren.",
                                    it: "Lascia non selezionato per esportare tutto.",
                                    nl: "Laat leeg om alles te exporteren.",
                                    ja: "未選択のままにするとすべてエクスポートされます。",
                                    ko: "전체를 내보내려면 선택하지 마세요."
                                ))
                                .font(.caption2)
                                .foregroundStyle(BXPalette.textSecondary)
                            }
                            .padding(20)
                            .bxGlassCard(cornerRadius: 24)
                        }

                        BXPrimaryButton(
                            title: supabase.onboardingProfile.text(en: "Generate", es: "Generar", pt: "Gerar", fr: "Générer", ar: "إنشاء", de: "Erstellen", it: "Genera", nl: "Genereren", ja: "生成", ko: "생성"),
                            systemImage: "arrow.up.doc"
                        ) {
                            onGenerate(selectedFormat, selectedCategories)
                            dismiss()
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 30)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(supabase.onboardingProfile.text(en: "Close", es: "Cerrar", pt: "Fechar", fr: "Fermer", ar: "إغلاق", de: "Schließen", it: "Chiudi", nl: "Sluiten", ja: "閉じる", ko: "닫기")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Receipts View

private struct BXReceiptsView: View {
    @EnvironmentObject private var supabase: SupabaseManager
    @State private var selectedReceipt: Receipt?

    private var allReceipts: [Receipt] {
        supabase.receiptsByTransactionID.values.sorted { $0.date > $1.date }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with Nueva button
            HStack {
                BXSectionTitle(
                    eyebrow: supabase.onboardingProfile.text(en: "Documents", es: "Documentos", pt: "Documentos", fr: "Documents", ar: "المستندات", de: "Dokumente", it: "Documenti", nl: "Documenten", ja: "書類", ko: "문서"),
                    title: supabase.onboardingProfile.text(en: "Receipts", es: "Recibos", pt: "Recibos", fr: "Reçus", ar: "الإيصالات", de: "Belege", it: "Ricevute", nl: "Bonnen", ja: "レシート", ko: "영수증")
                )
                Spacer()
                if !allReceipts.isEmpty {
                    Text("\(allReceipts.count) \(supabase.onboardingProfile.text(en: "saved", es: "guardados", pt: "salvos", fr: "enregistrés", ar: "محفوظة", de: "gespeichert", it: "salvati", nl: "opgeslagen", ja: "保存済み", ko: "저장됨"))")
                        .font(.caption)
                        .foregroundStyle(BXPalette.textSecondary)
                }
            }

            if allReceipts.isEmpty {
                BXEmptyStateCard(
                    title: supabase.onboardingProfile.text(en: "No receipts yet", es: "Sin recibos", pt: "Sem recibos ainda", fr: "Aucun reçu pour le moment", ar: "لا توجد إيصالات بعد", de: "Noch keine Belege", it: "Nessuna ricevuta ancora", nl: "Nog geen bonnen", ja: "レシートはまだありません", ko: "아직 영수증이 없습니다"),
                    message: supabase.onboardingProfile.text(
                        en: "Scan or upload receipts when adding transactions.",
                        es: "Escanea o sube recibos al agregar movimientos.",
                        pt: "Escaneie ou envie recibos ao adicionar transações.",
                        fr: "Scannez ou importez des reçus lors de l'ajout d'opérations.",
                        ar: "امسح الإيصالات أو ارفعها عند إضافة المعاملات.",
                        de: "Scanne oder lade Belege hoch, wenn du Transaktionen hinzufügst.",
                        it: "Scansiona o carica ricevute quando aggiungi transazioni.",
                        nl: "Scan of upload bonnen wanneer je transacties toevoegt.",
                        ja: "取引を追加する際にレシートをスキャンまたはアップロードしてください。",
                        ko: "거래를 추가할 때 영수증을 스캔하거나 업로드하세요."
                    ),
                    systemImage: "doc.text.viewfinder"
                )
            } else {
                receiptStats

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(allReceipts) { receipt in
                        Button {
                            selectedReceipt = receipt
                        } label: {
                            receiptThumbnail(receipt)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .sheet(item: $selectedReceipt) { receipt in
            BXReceiptDetailView(receipt: receipt)
                .environmentObject(supabase)
        }
    }

    private var receiptStats: some View {
        HStack(spacing: 12) {
            statCard(
                title: supabase.onboardingProfile.text(en: "Total", es: "Total", pt: "Total", fr: "Total", ar: "الإجمالي", de: "Gesamt", it: "Totale", nl: "Totaal", ja: "合計", ko: "총합"),
                value: "\(allReceipts.count)",
                symbol: "doc.on.doc",
                color: BXPalette.accentStart
            )
            statCard(
                title: supabase.onboardingProfile.text(en: "This Month", es: "Este mes", pt: "Este mês", fr: "Ce mois-ci", ar: "هذا الشهر", de: "Diesen Monat", it: "Questo mese", nl: "Deze maand", ja: "今月", ko: "이번 달"),
                value: "\(receiptsThisMonth)",
                symbol: "calendar",
                color: BXPalette.income
            )
            statCard(
                title: supabase.onboardingProfile.text(en: "Amount", es: "Monto", pt: "Valor", fr: "Montant", ar: "المبلغ", de: "Betrag", it: "Importo", nl: "Bedrag", ja: "金額", ko: "금액"),
                value: totalReceiptAmount.smartCurrencyString(code: supabase.onboardingProfile.currencyCode),
                symbol: "dollarsign.circle",
                color: BXPalette.warning
            )
        }
        .padding(16)
        .bxGlassCard(cornerRadius: 20)
    }

    private func statCard(title: String, value: String, symbol: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(value)
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(BXPalette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption2)
                .foregroundStyle(BXPalette.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func receiptThumbnail(_ receipt: Receipt) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(BXPalette.panelFillElevated)
                    .frame(height: 100)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(BXPalette.panelStroke, lineWidth: 0.5)
                    )

                if let image = loadReceiptImage(receipt) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 22, weight: .regular))
                            .foregroundStyle(BXPalette.textTertiary)
                        Text(supabase.onboardingProfile.text(en: "Receipt", es: "Recibo", pt: "Recibo", fr: "Reçu", ar: "إيصال", de: "Beleg", it: "Ricevuta", nl: "Bon", ja: "レシート", ko: "영수증"))
                            .font(.caption2)
                            .foregroundStyle(BXPalette.textTertiary)
                    }
                }
            }
            .frame(height: 100)
            .clipped()

            Text(receipt.vendor)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(BXPalette.textPrimary)
                .lineLimit(1)
            Text(receipt.amount.currencyString(code: supabase.onboardingProfile.currencyCode))
                .font(.caption2)
                .foregroundStyle(BXPalette.textSecondary)
                .lineLimit(1)
        }
    }

    private func loadReceiptImage(_ receipt: Receipt) -> UIImage? {
        guard let url = URL(string: receipt.imageURL), url.isFileURL else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    private var receiptsThisMonth: Int {
        let calendar = Calendar.current
        let now = Date.now
        return allReceipts.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }.count
    }

    private var totalReceiptAmount: Decimal {
        allReceipts.reduce(into: Decimal.zero) { $0 += $1.amount }
    }
}

// MARK: - Receipt Detail View

private struct BXReceiptDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var supabase: SupabaseManager
    let receipt: Receipt

    var body: some View {
        NavigationStack {
            ZStack {
                BXBackground()

                ScrollView {
                    VStack(spacing: 16) {
                        if let image = loadImage() {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            detailRow(
                                title: supabase.onboardingProfile.text(en: "Vendor", es: "Comercio", pt: "Fornecedor", fr: "Fournisseur", ar: "البائع", de: "Anbieter", it: "Fornitore", nl: "Leverancier", ja: "店舗", ko: "판매처"),
                                value: receipt.vendor
                            )
                            detailRow(
                                title: supabase.onboardingProfile.text(en: "Amount", es: "Monto", pt: "Valor", fr: "Montant", ar: "المبلغ", de: "Betrag", it: "Importo", nl: "Bedrag", ja: "金額", ko: "금액"),
                                value: receipt.amount.currencyString(code: supabase.onboardingProfile.currencyCode)
                            )
                            detailRow(
                                title: supabase.onboardingProfile.text(en: "Date", es: "Fecha", pt: "Data", fr: "Date", ar: "التاريخ", de: "Datum", it: "Data", nl: "Datum", ja: "日付", ko: "날짜"),
                                value: receipt.date.formatted(date: .abbreviated, time: .omitted)
                            )
                        }
                        .padding(20)
                        .bxGlassCard(cornerRadius: 20)
                    }
                    .padding(20)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(supabase.onboardingProfile.text(en: "Close", es: "Cerrar", pt: "Fechar", fr: "Fermer", ar: "إغلاق", de: "Schließen", it: "Chiudi", nl: "Sluiten", ja: "閉じる", ko: "닫기")) {
                        dismiss()
                    }
                }
            }
            .navigationTitle(supabase.onboardingProfile.text(en: "Receipt", es: "Recibo", pt: "Recibo", fr: "Reçu", ar: "إيصال", de: "Beleg", it: "Ricevuta", nl: "Bon", ja: "レシート", ko: "영수증"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(BXPalette.textSecondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BXPalette.textPrimary)
        }
    }

    private func loadImage() -> UIImage? {
        guard let url = URL(string: receipt.imageURL), url.isFileURL else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}

private enum EmailButtonState: Equatable {
    case idle, sending, success, failure(String)
}

// MARK: - Settings View (with restart system)

private struct BXSettingsView: View {
    @EnvironmentObject private var supabase: SupabaseManager
    @EnvironmentObject private var appSession: AppSession
    @State private var personName = ""
    @State private var companyName = ""
    @State private var workspaceName = ""
    @State private var country = "United States"
    @State private var language = "English"
    @State private var currencyCode = "USD"
    @State private var workspaceType: WorkspaceType = .business
    @State private var notificationsEnabled = true
    @State private var isSaving = false
    @State private var saveConfirmation: String?
    @State private var showRestartConfirmation = false
    @State private var summaryEmailState: EmailButtonState = .idle
    @State private var testEmailState: EmailButtonState = .idle
    @State private var expenseThresholdString = ""

    @State private var originalLanguage = ""
    @State private var originalCurrency = ""
    @State private var originalCountry = ""

    private var availableCountries: [String] { BXSupportedCountries.map(\.name) }
    private var availableLanguages: [BXLanguageInfo] { BXSupportedLanguages }
    private var availableCurrencies: [BXCurrencyInfo] { BXSupportedCurrencies }

    var body: some View {
        Form {
            // Profile Section
            Section {
                // Avatar + name preview
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(BXPalette.panelFillElevated)
                            .frame(width: 64, height: 64)
                        if personName.trimmingCharacters(in: .whitespaces).isEmpty {
                            Image(systemName: workspaceType == .business ? "building.2.fill" : "person.fill")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.white)
                        } else {
                            Text(personName.trimmingCharacters(in: .whitespaces).prefix(1).uppercased())
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(personName.isEmpty
                             ? supabase.onboardingProfile.text(en: "Your Name", es: "Tu nombre", pt: "Seu nome", fr: "Votre nom", ar: "اسمك", de: "Dein Name", it: "Il tuo nome", nl: "Je naam", ja: "あなたの名前", ko: "이름")
                             : personName)
                            .font(.headline.weight(.semibold))
                        HStack(spacing: 5) {
                            Image(systemName: workspaceType == .business ? "building.2" : "person")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(workspaceType == .business
                                 ? (workspaceName.isEmpty
                                    ? supabase.onboardingProfile.text(en: "Business", es: "Empresa", pt: "Empresa", fr: "Entreprise", ar: "شركة", de: "Unternehmen", it: "Azienda", nl: "Bedrijf", ja: "ビジネス", ko: "비즈니스")
                                    : workspaceName)
                                 : supabase.onboardingProfile.text(en: "Personal Account", es: "Cuenta personal", pt: "Conta pessoal", fr: "Compte personnel", ar: "حساب شخصي", de: "Privatkonto", it: "Account personale", nl: "Persoonlijke rekening", ja: "個人アカウント", ko: "개인 계정"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 6)
                .listRowBackground(Color.clear)

                // Your name (always shown)
                TextField(supabase.onboardingProfile.text(en: "Your name", es: "Tu nombre", pt: "Seu nome", fr: "Votre nom", ar: "اسمك", de: "Dein Name", it: "Il tuo nome", nl: "Je naam", ja: "あなたの名前", ko: "이름"), text: $personName)
                    .textContentType(.name)

                // Business name (only for business)
                if workspaceType == .business {
                    TextField(
                        supabase.onboardingProfile.text(en: "Business name", es: "Nombre de empresa", pt: "Nome da empresa", fr: "Nom de l'entreprise", ar: "اسم الشركة", de: "Firmenname", it: "Nome azienda", nl: "Bedrijfsnaam", ja: "事業名", ko: "회사명"),
                        text: $workspaceName
                    )
                    .textContentType(.organizationName)
                }

                // Workspace type: locked once set to business
                if supabase.onboardingProfile.workspaceType == .business {
                    HStack {
                        Label(supabase.onboardingProfile.text(en: "Workspace", es: "Espacio de trabajo", pt: "Espaço de trabalho", fr: "Espace de travail", ar: "مساحة العمل", de: "Arbeitsbereich", it: "Spazio di lavoro", nl: "Werkruimte", ja: "ワークスペース", ko: "작업 공간"), systemImage: "building.2")
                        Spacer()
                        Text(supabase.onboardingProfile.text(en: "Business", es: "Empresa", pt: "Empresa", fr: "Entreprise", ar: "شركة", de: "Unternehmen", it: "Azienda", nl: "Bedrijf", ja: "ビジネス", ko: "비즈니스"))
                            .foregroundStyle(.secondary)
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(BXPalette.textTertiary)
                    }
                } else {
                    // Personal accounts can upgrade to Business (one-way)
                    Picker(supabase.onboardingProfile.text(en: "Workspace", es: "Espacio de trabajo", pt: "Espaço de trabalho", fr: "Espace de travail", ar: "مساحة العمل", de: "Arbeitsbereich", it: "Spazio di lavoro", nl: "Werkruimte", ja: "ワークスペース", ko: "작업 공간"), selection: $workspaceType) {
                        Label(supabase.onboardingProfile.text(en: "Personal", es: "Personal", pt: "Pessoal", fr: "Personnel", ar: "شخصي", de: "Persönlich", it: "Personale", nl: "Persoonlijk", ja: "個人", ko: "개인"), systemImage: "person")
                            .tag(WorkspaceType.personal)
                        Label(supabase.onboardingProfile.text(en: "Business", es: "Empresa", pt: "Empresa", fr: "Entreprise", ar: "شركة", de: "Unternehmen", it: "Azienda", nl: "Bedrijf", ja: "ビジネス", ko: "비즈니스"), systemImage: "building.2")
                            .tag(WorkspaceType.business)
                    }
                }
            } header: {
                Label(supabase.onboardingProfile.text(en: "Profile",  es: "Perfil",
                                                       pt: "Perfil",  fr: "Profil",
                                                       ar: "الملف",   de: "Profil",
                                                       it: "Profilo", nl: "Profiel",
                                                       ja: "プロフィール", ko: "프로필"),
                      systemImage: "person.crop.circle")
            }

            // Region & Language Section
            Section {
                Picker(supabase.onboardingProfile.text(en: "Country",  es: "Pais",
                                                        pt: "País",    fr: "Pays",
                                                        ar: "الدولة",  de: "Land",
                                                        it: "Paese",   nl: "Land",
                                                        ja: "国",       ko: "국가"), selection: $country) {
                    ForEach(availableCountries, id: \.self) { c in
                        Label(c, systemImage: "mappin.and.ellipse").tag(c)
                    }
                }

                Picker(supabase.onboardingProfile.text(en: "Language",  es: "Idioma",
                                                        pt: "Idioma",   fr: "Langue",
                                                        ar: "اللغة",    de: "Sprache",
                                                        it: "Lingua",   nl: "Taal",
                                                        ja: "言語",      ko: "언어"), selection: $language) {
                    ForEach(availableLanguages, id: \.code) { lang in
                        Text("\(lang.localName) — \(lang.displayName)").tag(lang.code)
                    }
                }

                Picker(supabase.onboardingProfile.text(en: "Currency",  es: "Moneda",
                                                        pt: "Moeda",    fr: "Devise",
                                                        ar: "العملة",   de: "Währung",
                                                        it: "Valuta",   nl: "Valuta",
                                                        ja: "通貨",      ko: "통화"), selection: $currencyCode) {
                    ForEach(availableCurrencies, id: \.code) { cur in
                        HStack {
                            Text(cur.symbol)
                                .font(.body.weight(.semibold))
                                .frame(width: 28, alignment: .leading)
                            Text("\(cur.code) — \(supabase.onboardingProfile.localizedCurrencyName(cur))")
                        }
                        .tag(cur.code)
                    }
                }

                // Currency note: always independent of language
                Text(supabase.onboardingProfile.text(
                    en: "Currency is independent from language. Spanish speakers in the US can use USD.",
                    es: "La moneda es independiente del idioma. Usuarios en EE.UU. pueden usar USD aunque hablen español.",
                    pt: "A moeda é independente do idioma.",
                    fr: "La devise est indépendante de la langue.",
                    ar: "العملة مستقلة عن اللغة.",
                    de: "Währung ist unabhängig von der Sprache.",
                    it: "La valuta è indipendente dalla lingua.",
                    nl: "Valuta is onafhankelijk van de taal.",
                    ja: "通貨は言語とは独立しています。",
                    ko: "통화는 언어와 독립적입니다."
                ))
                .font(.footnote)
                .foregroundStyle(.secondary)

                if requiresRestart {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(supabase.onboardingProfile.text(
                            en: "These changes require an app restart.",
                            es: "Estos cambios requieren reiniciar la app.",
                            pt: "Essas alterações exigem reiniciar o app.",
                            fr: "Ces modifications nécessitent de redémarrer l'app.",
                            ar: "تتطلب هذه التغييرات إعادة تشغيل التطبيق.",
                            de: "Diese Änderungen erfordern einen Neustart der App.",
                            it: "Queste modifiche richiedono il riavvio dell'app.",
                            nl: "Voor deze wijzigingen moet de app opnieuw worden gestart.",
                            ja: "これらの変更を適用するにはアプリの再起動が必要です。",
                            ko: "이 변경 사항을 적용하려면 앱을 다시 시작해야 합니다."
                        ))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Label(supabase.onboardingProfile.text(en: "Region & Language",  es: "Region e Idioma",
                                                       pt: "Região e Idioma",   fr: "Région et langue",
                                                       ar: "المنطقة واللغة",   de: "Region & Sprache",
                                                       it: "Regione e lingua",  nl: "Regio & taal",
                                                       ja: "地域と言語",          ko: "지역 및 언어"),
                      systemImage: "globe")
            }

            // Notifications Section
            Section {
                Toggle(isOn: $notificationsEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(supabase.onboardingProfile.text(en: "Reminders & Alerts",          es: "Recordatorios y Alertas",
                                                              pt: "Lembretes e Alertas",         fr: "Rappels et alertes",
                                                              ar: "تذكيرات وتنبيهات",           de: "Erinnerungen & Benachrichtigungen",
                                                              it: "Promemoria e avvisi",         nl: "Herinneringen & Meldingen",
                                                              ja: "リマインダーとアラート",        ko: "알림 및 경고"))
                        Text(supabase.onboardingProfile.text(en: "Tax dates, subscriptions, activity.",
                                                              es: "Fechas fiscales, suscripciones, actividad.",
                                                              pt: "Datas fiscais, assinaturas.",
                                                              fr: "Dates fiscales, abonnements.",
                                                              ar: "تواريخ ضريبية، اشتراكات.",
                                                              de: "Steuerdaten, Abos, Aktivität.",
                                                              it: "Scadenze fiscali, abbonamenti.",
                                                              nl: "Belastingdata, abonnementen.",
                                                              ja: "納税日、サブスク、活動。",
                                                              ko: "세금 날짜, 구독, 활동."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(BXPalette.accentStart)
            } header: {
                Label(supabase.onboardingProfile.text(en: "Notifications",  es: "Notificaciones",
                                                       pt: "Notificações",  fr: "Notifications",
                                                       ar: "الإشعارات",     de: "Benachrichtigungen",
                                                       it: "Notifiche",     nl: "Meldingen",
                                                       ja: "通知",           ko: "알림"),
                      systemImage: "bell")
            }

            // Security Section
            Section {
                Toggle(isOn: Binding(
                    get: { supabase.biometricLockEnabled },
                    set: { supabase.setBiometricLock($0) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(supabase.onboardingProfile.text(en: "Face ID / Touch ID", es: "Face ID / Touch ID", pt: "Face ID / Touch ID", fr: "Face ID / Touch ID", ar: "Face ID / Touch ID", de: "Face ID / Touch ID", it: "Face ID / Touch ID", nl: "Face ID / Touch ID", ja: "Face ID / Touch ID", ko: "Face ID / Touch ID"))
                        Text(supabase.onboardingProfile.text(en: "Require biometric to open app.", es: "Requiere biometría para abrir la app.", pt: "Exige biometria para abrir o app.", fr: "Exige la biométrie pour ouvrir l'app.", ar: "يتطلب التحقق الحيوي لفتح التطبيق.", de: "Biometrie zum Öffnen der App erforderlich.", it: "Richiede la biometria per aprire l'app.", nl: "Biometrie vereist om de app te openen.", ja: "アプリを開くには生体認証が必要です。", ko: "앱을 열려면 생체 인증이 필요합니다."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(BXPalette.accentStart)
            } header: {
                Label(supabase.onboardingProfile.text(en: "Security",    es: "Seguridad",
                                                       pt: "Segurança",  fr: "Sécurité",
                                                       ar: "الأمان",     de: "Sicherheit",
                                                       it: "Sicurezza",  nl: "Beveiliging",
                                                       ja: "セキュリティ", ko: "보안"),
                      systemImage: "lock.shield")
            }

            // Email Alerts Section
            Section {
                Toggle(isOn: Binding(
                    get: { supabase.emailMonthlyReportEnabled },
                    set: { supabase.setEmailMonthlyReport($0) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(supabase.onboardingProfile.text(en: "Monthly balance report", es: "Reporte mensual de balance", pt: "Relatorio mensal de saldo", fr: "Rapport mensuel", de: "Monatlicher Bericht", it: "Report mensile", nl: "Maandelijks rapport", ja: "Monthly report", ko: "Monthly report"))
                        Text(supabase.onboardingProfile.text(en: "Receive a summary at the end of each month.", es: "Recibe un resumen al final de cada mes.", pt: "Receba um resumo no fim de cada mes.", fr: "Recevez un resume en fin de mois.", de: "Erhalte eine Zusammenfassung am Monatsende.", it: "Ricevi un riepilogo a fine mese.", nl: "Ontvang een overzicht aan het einde van elke maand.", ja: "Summary monthly", ko: "Monthly summary"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(BXPalette.accentStart)

                Toggle(isOn: Binding(
                    get: { supabase.emailExpenseAlertEnabled },
                    set: { supabase.setEmailExpenseAlert(enabled: $0, threshold: supabase.emailExpenseAlertThreshold) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(supabase.onboardingProfile.text(en: "Expense limit alert", es: "Alerta de limite de gastos", pt: "Alerta de limite de despesas", fr: "Alerte limite depenses", de: "Ausgabenlimit-Alarm", it: "Avviso limite spese", nl: "Bestedingslimiet", ja: "Expense alert", ko: "Expense alert"))
                        Text(supabase.onboardingProfile.text(en: "Get an email when monthly expenses exceed the limit.", es: "Recibe un correo cuando los gastos del mes superen el limite.", pt: "Receba um e-mail quando as despesas mensais superarem o limite.", fr: "Recevez un e-mail quand les depenses depassent la limite.", de: "E-Mail wenn Ausgaben das Limit ueberschreiten.", it: "Email quando le spese superano il limite.", nl: "E-mail als uitgaven het limiet overschrijden.", ja: "Email when expenses exceed limit", ko: "Email when expenses exceed limit"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(BXPalette.accentStart)

                if supabase.emailExpenseAlertEnabled {
                    HStack {
                        Text(supabase.onboardingProfile.text(en: "Limit", es: "Limite", pt: "Limite", fr: "Limite", de: "Limit", it: "Limite", nl: "Limiet", ja: "Limit", ko: "Limit"))
                        Spacer()
                        TextField("1000", text: $expenseThresholdString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .onAppear {
                                expenseThresholdString = String(format: "%.0f", supabase.emailExpenseAlertThreshold)
                            }
                            .onChange(of: expenseThresholdString) { _, val in
                                if let d = Double(val), d > 0 {
                                    supabase.setEmailExpenseAlert(enabled: true, threshold: d)
                                }
                            }
                        Text(supabase.onboardingProfile.currencyCode)
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    summaryEmailState = .sending
                    Task {
                        let error = await supabase.sendPerformanceEmail()
                        await MainActor.run {
                            summaryEmailState = error == nil ? .success : .failure(error!)
                        }
                        try? await Task.sleep(for: .seconds(4))
                        await MainActor.run { summaryEmailState = .idle }
                    }
                } label: {
                    switch summaryEmailState {
                    case .idle:
                        Label(supabase.onboardingProfile.text(en: "Send summary now", es: "Enviar resumen ahora", pt: "Enviar resumo agora", fr: "Envoyer le resume maintenant", de: "Zusammenfassung jetzt senden", it: "Invia riepilogo adesso", nl: "Stuur samenvatting nu", ja: "Send summary now", ko: "Send summary now"), systemImage: "envelope")
                    case .sending:
                        Label(supabase.onboardingProfile.text(en: "Sending...", es: "Enviando...", pt: "Enviando...", fr: "Envoi...", de: "Senden...", it: "Invio...", nl: "Verzenden...", ja: "Sending...", ko: "Sending..."), systemImage: "paperplane")
                            .foregroundStyle(.secondary)
                    case .success:
                        Label(supabase.onboardingProfile.text(en: "Report sent!", es: "Reporte enviado!", pt: "Relatorio enviado!", fr: "Rapport envoye!", de: "Bericht gesendet!", it: "Report inviato!", nl: "Rapport verstuurd!", ja: "Report sent!", ko: "Report sent!"), systemImage: "checkmark.circle.fill")
                            .foregroundStyle(BXPalette.income)
                    case .failure(let msg):
                        VStack(alignment: .leading, spacing: 2) {
                            Label(supabase.onboardingProfile.text(en: "Failed to send", es: "Error al enviar", pt: "Erro ao enviar", fr: "Echec envoi", de: "Fehler beim Senden", it: "Invio fallito", nl: "Verzenden mislukt", ja: "Send failed", ko: "Send failed"), systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(BXPalette.expense)
                            Text(msg)
                                .font(.caption)
                                .foregroundStyle(BXPalette.expense)
                                .lineLimit(3)
                        }
                    }
                }
                .disabled(summaryEmailState == .sending || summaryEmailState == .success)
            } header: {
                Label(supabase.onboardingProfile.text(en: "Email Alerts", es: "Alertas de correo", pt: "Alertas de e-mail", fr: "Alertes e-mail", de: "E-Mail-Benachrichtigungen", it: "Avvisi e-mail", nl: "E-mailmeldingen", ja: "Email Alerts", ko: "Email Alerts"), systemImage: "envelope.badge")
            }


            // Subscription Section
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(supabase.isPremium
                             ? supabase.onboardingProfile.text(en: "Premium Active",   es: "Premium Activo",
                                                                pt: "Premium Ativo",   fr: "Premium Actif",
                                                                ar: "بريميوم مفعّل",   de: "Premium Aktiv",
                                                                it: "Premium Attivo",  nl: "Premium Actief",
                                                                ja: "プレミアム有効",    ko: "프리미엄 활성")
                             : supabase.onboardingProfile.text(en: "Free Plan",        es: "Plan Gratuito",
                                                                pt: "Plano Gratuito",  fr: "Plan Gratuit",
                                                                ar: "خطة مجانية",     de: "Kostenloser Plan",
                                                                it: "Piano Gratuito",  nl: "Gratis Plan",
                                                                ja: "無料プラン",       ko: "무료 플랜"))
                            .font(.headline)
                        Text(supabase.isPremium
                             ? supabase.onboardingProfile.text(en: "All features unlocked.", es: "Todas las funciones activas.", pt: "Todos os recursos desbloqueados.", fr: "Toutes les fonctionnalités sont débloquées.", ar: "تم فتح جميع الميزات.", de: "Alle Funktionen freigeschaltet.", it: "Tutte le funzioni sono sbloccate.", nl: "Alle functies zijn ontgrendeld.", ja: "すべての機能が利用可能です。", ko: "모든 기능이 잠금 해제되었습니다.")
                             : supabase.onboardingProfile.text(en: "Upgrade for AI insights, unlimited budgets, and more.", es: "Mejora para IA, presupuestos ilimitados y más.", pt: "Faça upgrade para insights com IA, orçamentos ilimitados e mais.", fr: "Passez à la version supérieure pour des analyses IA, des budgets illimités et plus encore.", ar: "قم بالترقية للحصول على رؤى الذكاء الاصطناعي وميزانيات غير محدودة والمزيد.", de: "Upgrade für KI-Einblicke, unbegrenzte Budgets und mehr.", it: "Passa alla versione premium per insight IA, budget illimitati e altro.", nl: "Upgrade voor AI-inzichten, onbeperkte budgetten en meer.", ja: "AIインサイト、無制限の予算、その他の機能を使うにはアップグレードしてください。", ko: "AI 인사이트, 무제한 예산 등 더 많은 기능을 사용하려면 업그레이드하세요."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !supabase.isPremium {
                        Button {
                            supabase.setPremium(true)
                        } label: {
                            Text(supabase.onboardingProfile.text(en: "Upgrade", es: "Mejorar", pt: "Fazer upgrade", fr: "Mettre à niveau", ar: "ترقية", de: "Upgrade", it: "Aggiorna", nl: "Upgraden", ja: "アップグレード", ko: "업그레이드"))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.white, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    } else {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(BXPalette.accentStart)
                            .font(.title3)
                    }
                }
            } header: {
                Label(supabase.onboardingProfile.text(en: "Subscription",  es: "Suscripcion",
                                                       pt: "Assinatura",   fr: "Abonnement",
                                                       ar: "الاشتراك",     de: "Abonnement",
                                                       it: "Abbonamento",  nl: "Abonnement",
                                                       ja: "サブスクリプション", ko: "구독"),
                      systemImage: "crown")
            }

            // About Section
            Section {
                Button {
                    testEmailState = .sending
                    Task {
                        let error = await supabase.sendTestEmail(to: "homerjaredme@gmail.com")
                        await MainActor.run {
                            testEmailState = error == nil ? .success : .failure(error!)
                        }
                        try? await Task.sleep(for: .seconds(5))
                        await MainActor.run { testEmailState = .idle }
                    }
                } label: {
                    switch testEmailState {
                    case .idle:
                        Label("Enviar correo de prueba a homerjaredme@gmail.com", systemImage: "envelope.badge")
                    case .sending:
                        Label("Enviando...", systemImage: "paperplane")
                            .foregroundStyle(.secondary)
                    case .success:
                        Label("Enviado! Revisa homerjaredme@gmail.com", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(BXPalette.income)
                    case .failure(let msg):
                        VStack(alignment: .leading, spacing: 2) {
                            Label("Error al enviar", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(BXPalette.expense)
                            Text(msg)
                                .font(.caption)
                                .foregroundStyle(BXPalette.expense)
                                .lineLimit(4)
                        }
                    }
                }
                .disabled(testEmailState == .sending || testEmailState == .success)

                HStack {
                    Text(supabase.onboardingProfile.text(en: "Version", es: "Version",
                                                          pt: "Versão", fr: "Version",
                                                          ar: "الإصدار", de: "Version",
                                                          it: "Versione", nl: "Versie",
                                                          ja: "バージョン", ko: "버전"))
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text(supabase.onboardingProfile.text(en: "Build", es: "Build",
                                                          pt: "Build", fr: "Build",
                                                          ar: "البنية", de: "Build",
                                                          it: "Build",  nl: "Build",
                                                          ja: "ビルド",  ko: "빌드"))
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Label(supabase.onboardingProfile.text(en: "About",      es: "Acerca de",
                                                       pt: "Sobre",     fr: "À propos",
                                                       ar: "حول",       de: "Über",
                                                       it: "Informazioni", nl: "Over",
                                                       ja: "情報",       ko: "정보"),
                      systemImage: "info.circle")
            }

            // Account / Sign Out Section
            Section {
                Button(role: .destructive) {
                    Task { await supabase.signOut() }
                } label: {
                    HStack {
                        Image(systemName: "arrow.backward.circle.fill")
                            .foregroundStyle(BXPalette.expense)
                            .frame(width: 28)
                        Text(supabase.onboardingProfile.text(en: "Sign Out",        es: "Cerrar Sesion",
                                                              pt: "Sair",            fr: "Se déconnecter",
                                                              ar: "تسجيل الخروج",   de: "Abmelden",
                                                              it: "Esci",            nl: "Uitloggen",
                                                              ja: "サインアウト",     ko: "로그아웃"))
                            .foregroundStyle(BXPalette.expense)
                    }
                }
            } header: {
                Label(supabase.onboardingProfile.text(en: "Account",  es: "Cuenta",
                                                       pt: "Conta",   fr: "Compte",
                                                       ar: "الحساب",  de: "Konto",
                                                       it: "Account", nl: "Account",
                                                       ja: "アカウント", ko: "계정"),
                      systemImage: "person.badge.shield.checkmark")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                // Only show checkmark when there are actual changes
                if isSaving {
                    ProgressView()
                        .scaleEffect(0.85)
                } else if isDirty && canSaveSettings {
                    Button {
                        if requiresRestart {
                            showRestartConfirmation = true
                        } else {
                            Task { await saveSettings() }
                        }
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(BXPalette.accentStart)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isDirty)
        .overlay(alignment: .top) {
            if let saveConfirmation {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text(saveConfirmation)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(BXPalette.income, in: Capsule())
                .shadow(color: BXPalette.income.opacity(0.3), radius: 8, y: 4)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onAppear {
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        await MainActor.run {
                            withAnimation(.easeOut(duration: 0.3)) { self.saveConfirmation = nil }
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: saveConfirmation)
        .onAppear {
            let profile = supabase.onboardingProfile
            personName = profile.personName
            workspaceName = profile.workspaceName
            companyName = supabase.currentCompany?.name ?? profile.primaryName
            country = profile.country
            language = profile.language
            currencyCode = profile.currencyCode
            workspaceType = profile.workspaceType
            notificationsEnabled = supabase.notificationsEnabled
            originalLanguage = profile.language
            originalCurrency = profile.currencyCode
            originalCountry = profile.country
        }
        .onChange(of: personName) { _, newValue in
            if workspaceType == .personal { workspaceName = newValue }
        }
        .alert(
            supabase.onboardingProfile.text(en: "Restart Required", es: "Reinicio requerido", pt: "Reinício necessário", fr: "Redémarrage requis", ar: "إعادة التشغيل مطلوبة", de: "Neustart erforderlich", it: "Riavvio richiesto", nl: "Opnieuw starten vereist", ja: "再起動が必要です", ko: "재시작이 필요합니다"),
            isPresented: $showRestartConfirmation
        ) {
            Button(supabase.onboardingProfile.text(en: "Cancel", es: "Cancelar", pt: "Cancelar", fr: "Annuler", ar: "إلغاء", de: "Abbrechen", it: "Annulla", nl: "Annuleren", ja: "キャンセル", ko: "취소"), role: .cancel) {}
            Button(supabase.onboardingProfile.text(en: "Apply & Restart", es: "Aplicar y reiniciar", pt: "Aplicar e reiniciar", fr: "Appliquer et redémarrer", ar: "تطبيق وإعادة التشغيل", de: "Anwenden und neu starten", it: "Applica e riavvia", nl: "Toepassen en herstarten", ja: "適用して再起動", ko: "적용 후 재시작")) {
                Task {
                    await saveSettings()
                    appSession.performRestart()
                }
            }
        } message: {
            Text(supabase.onboardingProfile.text(
                en: "Changes to language, currency, or region require restarting the app to apply properly.",
                es: "Los cambios de idioma, moneda o región requieren reiniciar la app para aplicarse correctamente.",
                pt: "Alterações de idioma, moeda ou região exigem reiniciar o app para serem aplicadas corretamente.",
                fr: "Les modifications de langue, devise ou région nécessitent de redémarrer l'app pour être appliquées correctement.",
                ar: "تتطلب تغييرات اللغة أو العملة أو المنطقة إعادة تشغيل التطبيق ليتم تطبيقها بشكل صحيح.",
                de: "Änderungen an Sprache, Währung oder Region erfordern einen Neustart der App, damit sie korrekt angewendet werden.",
                it: "Le modifiche a lingua, valuta o area geografica richiedono il riavvio dell'app per essere applicate correttamente.",
                nl: "Wijzigingen aan taal, valuta of regio vereisen een herstart van de app om correct te worden toegepast.",
                ja: "言語、通貨、地域の変更を正しく反映するには、アプリの再起動が必要です。",
                ko: "언어, 통화 또는 지역 변경을 올바르게 적용하려면 앱을 다시 시작해야 합니다."
            ))
        }
    }

    private var requiresRestart: Bool {
        language != originalLanguage ||
        currencyCode != originalCurrency ||
        country != originalCountry
    }

    /// True only when something has actually changed from the saved state
    private var isDirty: Bool {
        let profile = supabase.onboardingProfile
        return personName != profile.personName ||
               workspaceName != profile.workspaceName ||
               country != profile.country ||
               language != profile.language ||
               currencyCode != profile.currencyCode ||
               workspaceType != profile.workspaceType ||
               notificationsEnabled != supabase.notificationsEnabled
    }

    private var canSaveSettings: Bool {
        let trimmedPersonName = personName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedWorkspaceName = workspaceName.trimmingCharacters(in: .whitespacesAndNewlines)
        if workspaceType == .personal { return !trimmedPersonName.isEmpty }
        return !trimmedPersonName.isEmpty && !trimmedWorkspaceName.isEmpty
    }

    private func saveSettings() async {
        isSaving = true
        let success = await supabase.updateSettings(
            country: country,
            language: language,
            currencyCode: currencyCode,
            workspaceType: workspaceType,
            personName: personName,
            workspaceName: workspaceType == .personal ? personName : workspaceName,
            companyName: workspaceType == .personal
                ? (personName.isEmpty ? supabase.onboardingProfile.primaryName : personName)
                : (workspaceName.isEmpty ? (supabase.currentCompany?.name ?? supabase.onboardingProfile.primaryName) : workspaceName),
            notificationsEnabled: notificationsEnabled
        )
        isSaving = false
        if success {
            originalLanguage = language
            originalCurrency = currencyCode
            originalCountry = country
            saveConfirmation = supabase.onboardingProfile.text(
                en: "Settings saved successfully.",
                es: "Ajustes guardados correctamente.",
                pt: "Configurações salvas com sucesso.",
                fr: "Réglages enregistrés avec succès.",
                ar: "تم حفظ الإعدادات بنجاح.",
                de: "Einstellungen erfolgreich gespeichert.",
                it: "Impostazioni salvate correttamente.",
                nl: "Instellingen succesvol opgeslagen.",
                ja: "設定が正常に保存されました。",
                ko: "설정이 성공적으로 저장되었습니다."
            )
        }
    }

    private func currencySymbol(_ code: String) -> String {
        BXSupportedCurrencies.first { $0.code == code }?.symbol ?? code
    }

    private func currencyName(_ code: String) -> String {
        let cur = BXSupportedCurrencies.first { $0.code == code }
        guard let cur else { return code }
        return supabase.onboardingProfile.localizedCurrencyName(cur)
    }
}

// MARK: - Floating Tab Bar

private struct BXFloatingTabBar: View {
    @Binding var selectedTab: BXTab
    @EnvironmentObject private var supabase: SupabaseManager
    @Namespace private var tabNamespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(BXTab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.78)) {
                        selectedTab = tab
                    }
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: selectedTab == tab ? tab.symbolFilled : tab.symbol)
                            .font(.system(size: 18, weight: selectedTab == tab ? .bold : .regular))
                            .scaleEffect(selectedTab == tab ? 1.18 : 1.0)
                            .animation(.spring(response: 0.28, dampingFraction: 0.62), value: selectedTab)
                        Text(localizedTab(tab))
                            .font(.system(size: 9, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.70)
                    }
                    .foregroundStyle(selectedTab == tab ? BXPalette.accentStart : BXPalette.tabInactive)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 52)
                    .padding(.vertical, 4)
                    .background {
                        if selectedTab == tab {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(BXPalette.accentStart.opacity(0.16))
                                .matchedGeometryEffect(id: "bxTab", in: tabNamespace)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(BXPalette.accentStart.opacity(0.30), lineWidth: 0.5)
                                )
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(BXPalette.panelFillElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
                )
                .shadow(color: BXPalette.accentStart.opacity(0.08), radius: 20, y: 4)
        )
    }

    private func localizedTab(_ tab: BXTab) -> String {
        let p = supabase.onboardingProfile
        switch tab {
        case .dashboard:
            return p.text(en: "Home",         es: "Inicio",       pt: "Início",      fr: "Accueil",
                          ar: "الرئيسية",      de: "Übersicht",    it: "Home",        nl: "Home",
                          ja: "ホーム",         ko: "홈")
        case .transactions:
            return p.text(en: "Transactions", es: "Movimientos",  pt: "Transações",  fr: "Opérations",
                          ar: "المعاملات",    de: "Transaktionen", it: "Transazioni", nl: "Transacties",
                          ja: "取引",           ko: "거래")
        case .reports:
            return p.text(en: "Reports",      es: "Reportes",     pt: "Relatórios",  fr: "Rapports",
                          ar: "التقارير",      de: "Berichte",     it: "Rapporti",    nl: "Rapporten",
                          ja: "レポート",       ko: "보고서")
        case .receipts:
            return p.text(en: "Receipts",     es: "Recibos",      pt: "Recibos",     fr: "Reçus",
                          ar: "الإيصالات",    de: "Belege",        it: "Ricevute",    nl: "Bonnen",
                          ja: "領収書",         ko: "영수증")
        case .settings:
            return p.text(en: "Settings",     es: "Ajustes",      pt: "Definições",  fr: "Réglages",
                          ar: "الإعدادات",    de: "Einstellungen", it: "Impostazioni", nl: "Instellingen",
                          ja: "設定",           ko: "설정")
        }
    }
}

// MARK: - Transaction Row

private struct BXTransactionRow: View {
    let transaction: AccountingTransaction
    let currencyCode: String
    let profile: OnboardingProfile
    var showActions: Bool = true
    let onOpen: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var categoryIcon: String {
        switch transaction.category.lowercased() {
        case let c where c.contains("food") || c.contains("comida") || c.contains("restaurant") || c.contains("restaurante"):
            return "fork.knife"
        case let c where c.contains("transport") || c.contains("gas") || c.contains("gasolina"):
            return "car.fill"
        case let c where c.contains("health") || c.contains("salud") || c.contains("farmacia"):
            return "cross.fill"
        case let c where c.contains("entertain") || c.contains("entrete") || c.contains("netflix") || c.contains("spotify"):
            return "play.circle.fill"
        case let c where c.contains("shop") || c.contains("compra") || c.contains("supermercado"):
            return "cart.fill"
        case let c where c.contains("salary") || c.contains("salario") || c.contains("sueldo") || c.contains("income") || c.contains("ingreso") || c.contains("freelance"):
            return "banknote.fill"
        case let c where c.contains("rent") || c.contains("renta"):
            return "house.fill"
        case let c where c.contains("service") || c.contains("servicio") || c.contains("internet"):
            return "bolt.fill"
        default:
            return transaction.type == .income ? "arrow.down.left" : "arrow.up.right"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                Image(systemName: categoryIcon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(
                        transaction.type == .income
                            ? BXPalette.income.opacity(0.85)
                            : BXPalette.expense.opacity(0.85),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(transaction.vendor)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BXPalette.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text(transaction.category)
                            .lineLimit(1)
                        Text("·")
                        Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                    }
                    .font(.caption2)
                    .foregroundStyle(BXPalette.textSecondary)
                }

                Spacer()

                Text((transaction.type == .income ? "+" : "-") + transaction.amount.currencyString(code: currencyCode))
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(transaction.type == .income ? BXPalette.income : BXPalette.expense)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            if showActions {
                HStack(spacing: 6) {
                    Button(action: onOpen) {
                        Label(profile.text(en: "View", es: "Ver", pt: "Ver", fr: "Voir", ar: "عرض", de: "Anzeigen", it: "Visualizza", nl: "Bekijken", ja: "表示", ko: "보기"), systemImage: "doc.text.magnifyingglass")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(BXPalette.accentStart)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(BXPalette.accentStart.opacity(0.10), in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button(action: onEdit) {
                        Label(profile.text(en: "Edit", es: "Editar", pt: "Editar", fr: "Modifier", ar: "تعديل", de: "Bearbeiten", it: "Modifica", nl: "Bewerken", ja: "編集", ko: "편집"), systemImage: "pencil")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(BXPalette.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(BXPalette.fieldFill, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button(action: onDelete) {
                        Label(profile.text(en: "Delete", es: "Borrar", pt: "Excluir", fr: "Supprimer", ar: "حذف", de: "Löschen", it: "Elimina", nl: "Verwijderen", ja: "削除", ko: "삭제"), systemImage: "trash")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(BXPalette.expense)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(BXPalette.expense.opacity(0.10), in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            onOpen()
        }
    }
}

// MARK: - Line Chart

private struct BXLineChart: View {
    let points: [Decimal]
    @State private var animationProgress = 0.0

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let values = points.map { ($0 as NSDecimalNumber).doubleValue }
            let minValue = min(values.min() ?? 0, 0)
            let maxValue = max(values.max() ?? 0, 1)
            let range = max(maxValue - minValue, 1)
            let stepX = size.width / CGFloat(max(values.count - 1, 1))

            ZStack {
                VStack(spacing: size.height / 3) {
                    ForEach(0..<4, id: \.self) { _ in
                        Rectangle()
                            .fill(BXPalette.panelStroke)
                            .frame(height: 0.5)
                    }
                }

                Path { path in
                    for index in values.indices {
                        let x = CGFloat(index) * stepX
                        let normalized = (values[index] - minValue) / range
                        let y = size.height - (CGFloat(normalized) * size.height)

                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .trim(from: 0, to: animationProgress)
                .stroke(BXPalette.accentGradient, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                Path { path in
                    path.move(to: CGPoint(x: 0, y: size.height))
                    for index in values.indices {
                        let x = CGFloat(index) * stepX
                        let normalized = (values[index] - minValue) / range
                        let y = size.height - (CGFloat(normalized) * size.height)
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                    path.addLine(to: CGPoint(x: size.width, y: size.height))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [BXPalette.accentStart.opacity(0.25), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .mask(
                    Rectangle()
                        .scaleEffect(x: animationProgress, y: 1, anchor: .leading)
                )
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) {
                animationProgress = 1
            }
        }
        .onChange(of: points) { _, _ in
            animationProgress = 0
            withAnimation(.easeOut(duration: 0.9)) {
                animationProgress = 1
            }
        }
    }
}

// MARK: - Welcome View

private struct BXWelcomeView: View {
    @EnvironmentObject private var supabase: SupabaseManager
    @Binding var showWelcome: Bool
    @State private var page = 0
    @State private var selectedCountry = OnboardingProfile.default.country
    @State private var selectedLanguage = OnboardingProfile.default.language
    @State private var selectedCurrency = OnboardingProfile.default.currencyCode
    @State private var workspaceType = OnboardingProfile.default.workspaceType
    @State private var personName = ""
    @State private var workspaceName = ""
    // Once the user picks Business, they cannot revert during onboarding
    @State private var businessLocked = false

    private struct OnboardingSlide {
        let symbol: String
        let title: (en: String, es: String, pt: String, fr: String, ar: String, de: String, it: String, nl: String, ja: String, ko: String)
        let body:  (en: String, es: String, pt: String, fr: String, ar: String, de: String, it: String, nl: String, ja: String, ko: String)
    }

    private let pages: [OnboardingSlide] = [
        OnboardingSlide(symbol: "sparkles.rectangle.stack",
            title: (en: "Welcome to Balance X", es: "Bienvenido a Balance X", pt: "Bem-vindo ao Balance X", fr: "Bienvenue sur Balance X",
                    ar: "مرحبًا بك في Balance X", de: "Willkommen bei Balance X", it: "Benvenuto in Balance X",
                    nl: "Welkom bij Balance X", ja: "Balance Xへようこそ", ko: "Balance X에 오신 것을 환영합니다"),
            body:  (en: "Your intelligent financial workspace for personal tracking or business bookkeeping.",
                    es: "Tu espacio financiero inteligente para control personal o contabilidad empresarial.",
                    pt: "O seu espaço financeiro inteligente para controlo pessoal ou contabilidade empresarial.",
                    fr: "Votre espace financier intelligent pour le suivi personnel ou la comptabilité d'entreprise.",
                    ar: "مساحة عملك المالية الذكية للتتبع الشخصي أو المحاسبة التجارية.",
                    de: "Dein intelligenter Finanzarbeitsbereich für persönliche Verfolgung oder Geschäftsbuchhaltung.",
                    it: "Il tuo spazio finanziario intelligente per il monitoraggio personale o la contabilità aziendale.",
                    nl: "Jouw intelligente financiële werkruimte voor persoonlijk bijhouden of zakelijke boekhouding.",
                    ja: "個人追跡またはビジネス簿記のためのあなたのインテリジェントな財務ワークスペース。",
                    ko: "개인 추적 또는 비즈니스 부기를 위한 지능형 금융 작업 공간입니다.")),
        OnboardingSlide(symbol: "doc.text.viewfinder",
            title: (en: "Scan & Auto-Fill", es: "Escanea y Auto-Completa", pt: "Escanear e Preencher Auto", fr: "Scanner et Remplir Auto",
                    ar: "مسح وملء تلقائي", de: "Scannen & Auto-Ausfüllen", it: "Scansiona e Compila Auto",
                    nl: "Scannen & Auto-Invullen", ja: "スキャンと自動入力", ko: "스캔 및 자동 입력"),
            body:  (en: "AI or on-device extraction detects amount, merchant, and date from your receipts instantly.",
                    es: "IA o análisis local detecta monto, comercio y fecha desde tus recibos al instante.",
                    pt: "A IA deteta valor, comerciante e data dos seus recibos instantaneamente.",
                    fr: "L'IA détecte le montant, le commerçant et la date de vos reçus instantanément.",
                    ar: "يكشف الذكاء الاصطناعي أو الاستخراج على الجهاز عن المبلغ والتاجر والتاريخ من إيصالاتك فورًا.",
                    de: "KI oder geräteseitige Extraktion erkennt Betrag, Händler und Datum aus deinen Belegen sofort.",
                    it: "L'IA o l'estrazione sul dispositivo rileva importo, commerciante e data dalle tue ricevute istantaneamente.",
                    nl: "AI of on-device extractie detecteert bedrag, handelaar en datum van je bonnetjes direct.",
                    ja: "AIまたはデバイス上の抽出がレシートから金額、店舗名、日付を即座に検出します。",
                    ko: "AI 또는 기기 내 추출이 영수증에서 금액, 가맹점, 날짜를 즉시 감지합니다.")),
        OnboardingSlide(symbol: "chart.bar.doc.horizontal",
            title: (en: "Reports & Taxes", es: "Reportes e Impuestos", pt: "Relatórios e Impostos", fr: "Rapports et Impôts",
                    ar: "التقارير والضرائب", de: "Berichte & Steuern", it: "Report e Imposte",
                    nl: "Rapporten & Belastingen", ja: "レポートと税金", ko: "보고서 및 세금"),
            body:  (en: "Generate PDF/Excel exports, estimate taxes by country, and track monthly budgets effortlessly.",
                    es: "Genera exportaciones PDF/Excel, estima impuestos por país y controla presupuestos mensuales.",
                    pt: "Gere exportações PDF/Excel, estime impostos por país e acompanhe orçamentos mensais.",
                    fr: "Générez des exports PDF/Excel, estimez les impôts par pays et suivez vos budgets mensuels.",
                    ar: "أنشئ صادرات PDF/Excel، قدّر الضرائب حسب الدولة، وتتبع الميزانيات الشهرية بسهولة.",
                    de: "Erstelle PDF/Excel-Exporte, schätze Steuern nach Land und verfolge monatliche Budgets mühelos.",
                    it: "Genera esportazioni PDF/Excel, stima le tasse per paese e monitora i budget mensili facilmente.",
                    nl: "Genereer PDF/Excel-exports, schat belastingen per land en volg maandbudgetten moeiteloos.",
                    ja: "PDF/Excelエクスポートを生成し、国別に税金を見積もり、月次予算を簡単に追跡できます。",
                    ko: "PDF/Excel 내보내기를 생성하고, 국가별 세금을 추정하고, 월별 예산을 쉽게 추적하세요.")),
        OnboardingSlide(symbol: "gearshape.2",
            title: (en: "Set Up Your Workspace", es: "Configura tu Espacio", pt: "Configure o Seu Espaço", fr: "Configurez Votre Espace",
                    ar: "إعداد مساحة عملك", de: "Deinen Arbeitsbereich einrichten", it: "Configura il Tuo Spazio",
                    nl: "Stel Uw Werkruimte In", ja: "ワークスペースを設定する", ko: "작업 공간 설정"),
            body:  (en: "Choose your language, currency, and workspace type to get started.",
                    es: "Elige tu idioma, moneda y tipo de espacio de trabajo para comenzar.",
                    pt: "Escolha o seu idioma, moeda e tipo de espaço de trabalho para começar.",
                    fr: "Choisissez votre langue, devise et type d'espace de travail pour commencer.",
                    ar: "اختر لغتك وعملتك ونوع مساحة العمل للبدء.",
                    de: "Wähle deine Sprache, Währung und den Arbeitsbereichstyp, um loszulegen.",
                    it: "Scegli la tua lingua, valuta e tipo di spazio di lavoro per iniziare.",
                    nl: "Kies uw taal, valuta en type werkruimte om te beginnen.",
                    ja: "言語、通貨、ワークスペースタイプを選択して開始してください。",
                    ko: "시작하려면 언어, 통화, 작업 공간 유형을 선택하세요."))
    ]

    private func loc(en: String, es: String, pt: String, fr: String,
                     ar: String = "", de: String = "", it: String = "",
                     nl: String = "", ja: String = "", ko: String = "") -> String {
        let tempProfile = OnboardingProfile(
            country: selectedCountry,
            language: selectedLanguage,
            currencyCode: selectedCurrency,
            workspaceType: workspaceType,
            personName: personName,
            workspaceName: workspaceName
        )
        return tempProfile.text(en: en, es: es, pt: pt, fr: fr, ar: ar.isEmpty ? nil : ar, de: de.isEmpty ? nil : de, it: it.isEmpty ? nil : it, nl: nl.isEmpty ? nil : nl, ja: ja.isEmpty ? nil : ja, ko: ko.isEmpty ? nil : ko)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BXBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        TabView(selection: $page) {
                            ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                                VStack(spacing: 24) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(BXPalette.fieldFill)
                                            .frame(width: 64, height: 64)
                                        Image(systemName: item.symbol)
                                            .font(.system(size: 28, weight: .semibold))
                                            .foregroundStyle(.white)
                                    }
                                    .padding(.top, 8)
                                    Text(loc(en: item.title.en, es: item.title.es, pt: item.title.pt, fr: item.title.fr,
                                             ar: item.title.ar, de: item.title.de, it: item.title.it, nl: item.title.nl,
                                             ja: item.title.ja, ko: item.title.ko))
                                        .font(.system(size: 34, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(loc(en: item.body.en, es: item.body.es, pt: item.body.pt, fr: item.body.fr,
                                             ar: item.body.ar, de: item.body.de, it: item.body.it, nl: item.body.nl,
                                             ja: item.body.ja, ko: item.body.ko))
                                        .font(.subheadline)
                                        .foregroundStyle(BXPalette.textSecondary)
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.horizontal, 4)
                                .frame(maxWidth: .infinity)
                                .tag(index)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .always))
                        .frame(height: 300)

                        if page >= pages.count - 1 {
                            onboardingSetupCard
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }

                        Button {
                            if page == pages.count - 1 {
                                let finalWorkspaceName = workspaceType == .personal ? personName : workspaceName
                                supabase.saveOnboardingProfile(
                                    country: selectedCountry,
                                    language: selectedLanguage,
                                    currencyCode: selectedCurrency,
                                    workspaceType: workspaceType,
                                    personName: personName,
                                    workspaceName: finalWorkspaceName
                                )
                                showWelcome = false
                            } else {
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                                    page += 1
                                }
                            }
                        } label: {
                            Text(page == pages.count - 1
                                 ? loc(en: "Enter Balance X", es: "Entrar a Balance X", pt: "Entrar no Balance X", fr: "Entrer dans Balance X",
                                       ar: "ادخل Balance X", de: "Balance X betreten", it: "Entra in Balance X",
                                       nl: "Balance X betreden", ja: "Balance Xへ", ko: "Balance X 입장")
                                 : loc(en: "CONTINUE", es: "SIGUIENTE", pt: "CONTINUAR", fr: "CONTINUER",
                                       ar: "متابعة", de: "WEITER", it: "CONTINUA", nl: "DOORGAAN",
                                       ja: "続ける", ko: "계속"))
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 17)
                                .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(page == pages.count - 1 && !canFinishSetup)
                        .opacity(page == pages.count - 1 && !canFinishSetup ? 0.45 : 1)

                        // Demo data option on last slide
                        if page == pages.count - 1 {
                            Button {
                                let finalWorkspaceName = workspaceType == .personal ? personName : workspaceName
                                supabase.saveOnboardingProfile(
                                    country: selectedCountry,
                                    language: selectedLanguage,
                                    currencyCode: selectedCurrency,
                                    workspaceType: workspaceType,
                                    personName: personName,
                                    workspaceName: finalWorkspaceName
                                )
                                supabase.loadDemoData()
                                showWelcome = false
                            } label: {
                                Text(loc(en: "Start with sample data", es: "Comenzar con datos de ejemplo",
                                         pt: "Começar com dados de exemplo", fr: "Démarrer avec des exemples",
                                         ar: "البدء ببيانات تجريبية", de: "Mit Beispieldaten starten",
                                         it: "Inizia con dati di esempio", nl: "Begin met voorbeelddata",
                                         ja: "サンプルデータで始める", ko: "샘플 데이터로 시작"))
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(BXPalette.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 13)
                                    .background(BXPalette.panelFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(BXPalette.panelStroke, lineWidth: 0.5))
                            }
                            .buttonStyle(.plain)
                            .disabled(!canFinishSetup)
                            .opacity(!canFinishSetup ? 0.45 : 1)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                    .padding(24)
                }
            }
            .interactiveDismissDisabled()
            .onAppear {
                let profile = supabase.onboardingProfile
                // Only treat as a blank first-time setup when profile is the default
                let isFirstSetup = profile.personName.isEmpty && profile.workspaceName.isEmpty

                if isFirstSetup {
                    // Auto-detect device language
                    let deviceLang = Locale.preferredLanguages.first ?? ""
                    let normalizedCode = String(deviceLang.prefix(2)).lowercased()
                    selectedLanguage = BXSupportedLanguages.first(where: { $0.isoCode == normalizedCode })?.code ?? "English"
                    // Auto-detect device region → suggest country + currency
                    let regionCode = Locale.current.region?.identifier ?? ""
                    if let detected = BXSupportedCountries.first(where: { $0.code == regionCode }) {
                        selectedCountry = detected.name
                        selectedCurrency = detected.defaultCurrency
                    } else {
                        selectedCountry = profile.country
                        selectedCurrency = profile.currencyCode
                    }
                    workspaceType = profile.workspaceType
                    personName = ""
                    workspaceName = ""
                } else {
                    selectedCountry = profile.country
                    selectedLanguage = profile.language
                    selectedCurrency = profile.currencyCode
                    workspaceType = profile.workspaceType
                    personName = profile.personName
                    workspaceName = profile.workspaceName
                    if profile.workspaceType == .business {
                        businessLocked = true
                    }
                }
            }
        }
    }

    private var onboardingSetupCard: some View {
        return VStack(alignment: .leading, spacing: 16) {

            // Language
            setupRow(
                label: loc(en: "Language", es: "Idioma", pt: "Idioma", fr: "Langue"),
                symbol: "character.bubble"
            ) {
                Picker("", selection: $selectedLanguage) {
                    ForEach(BXSupportedLanguages, id: \.code) { lang in
                        Text(lang.localName).tag(lang.code)
                    }
                }
                .pickerStyle(.menu)
            }

            // Workspace type
            setupRow(
                label: loc(en: "Account type", es: "Tipo de cuenta", pt: "Tipo de conta", fr: "Type de compte"),
                symbol: "person.badge.clock"
            ) {
                if businessLocked {
                    HStack(spacing: 6) {
                        Image(systemName: "building.2.fill")
                            .font(.caption)
                            .foregroundStyle(BXPalette.accentStart)
                        Text(loc(en: "Business (locked)", es: "Empresa (bloqueado)", pt: "Empresa (bloqueado)", fr: "Entreprise (verrouillé)"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(BXPalette.textPrimary)
                        Spacer()
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(BXPalette.textTertiary)
                    }
                } else {
                    Picker("", selection: $workspaceType) {
                        Label(loc(en: "Personal",  es: "Personal", pt: "Pessoal",  fr: "Personnel"),  systemImage: "person").tag(WorkspaceType.personal)
                        Label(loc(en: "Business",  es: "Empresa",  pt: "Empresa",  fr: "Entreprise"), systemImage: "building.2").tag(WorkspaceType.business)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: workspaceType) { _, newType in
                        if newType == .business { businessLocked = true }
                    }
                }
            }

            // Country
            setupRow(
                label: loc(en: "Country", es: "País", pt: "País", fr: "Pays"),
                symbol: "globe.americas.fill"
            ) {
                Picker("", selection: $selectedCountry) {
                    ForEach(BXSupportedCountries, id: \.name) { c in
                        Text(c.name).tag(c.name)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedCountry) { _, newCountry in
                    // Auto-suggest currency when country changes (non-destructive)
                    if let info = BXSupportedCountries.first(where: { $0.name == newCountry }) {
                        selectedCurrency = info.defaultCurrency
                    }
                }
            }

            // Currency
            setupRow(
                label: loc(en: "Currency", es: "Moneda", pt: "Moeda", fr: "Devise"),
                symbol: "dollarsign.circle.fill"
            ) {
                Picker("", selection: $selectedCurrency) {
                    ForEach(BXSupportedCurrencies, id: \.code) { cur in
                        let curName: String = {
                            switch selectedLanguage {
                            case "Espanol":   return cur.nameEs
                            case "Portugues": return cur.namePt
                            case "Francais":  return cur.nameFr
                            default:          return cur.name
                            }
                        }()
                        Text("\(cur.symbol) \(cur.code) — \(curName)").tag(cur.code)
                    }
                }
                .pickerStyle(.menu)
            }

            Divider().opacity(0.3)

            // Name fields
            VStack(spacing: 10) {
                BXField(
                    title: loc(en: "Your name", es: "Tu nombre", pt: "O seu nome", fr: "Votre nom"),
                    text: $personName,
                    keyboardType: .default
                )
                if workspaceType == .business || businessLocked {
                    BXField(
                        title: loc(en: "Business name", es: "Nombre de empresa", pt: "Nome da empresa", fr: "Nom de l'entreprise"),
                        text: $workspaceName,
                        keyboardType: .default
                    )
                }
            }
        }
        .padding(18)
        .bxGlassCard(cornerRadius: 20)
    }

    @ViewBuilder
    private func setupRow<Content: View>(label: String, symbol: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BXPalette.accentStart)
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BXPalette.textTertiary)
                    .textCase(.uppercase)
            }
            content()
        }
    }

    private var canFinishSetup: Bool {
        let trimmedPersonName = personName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedWorkspaceName = workspaceName.trimmingCharacters(in: .whitespacesAndNewlines)
        if workspaceType == .personal {
            return !trimmedPersonName.isEmpty
        }
        return !trimmedPersonName.isEmpty && !trimmedWorkspaceName.isEmpty
    }

}

// MARK: - Net Worth Sheet

private struct BXNetWorthSheet: View {
    @EnvironmentObject private var supabase: SupabaseManager
    @Environment(\.dismiss) private var dismiss
    @State private var showAddAccount = false
    @State private var editingAccount: NetWorthAccount? = nil

    private var p: OnboardingProfile { supabase.onboardingProfile }
    private var cc: String { p.currencyCode }

    var body: some View {
        NavigationStack {
            ZStack {
                BXBackground()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Summary hero
                        VStack(spacing: 6) {
                            Text(p.text(en: "Net Worth", es: "Patrimonio Neto", pt: "Patrimônio Líquido", fr: "Patrimoine Net", ar: "صافي الثروة", de: "Nettovermögen", it: "Patrimonio Netto", nl: "Nettovermogen", ja: "純資産", ko: "순자산"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BXPalette.textSecondary)
                                .tracking(0.6)
                            Text(supabase.netWorth.currencyString(code: cc))
                                .font(.system(size: 40, weight: .black, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(supabase.netWorth >= 0 ? BXPalette.income : BXPalette.expense)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .bxGlassCard()

                        // Assets
                        accountSection(type: .asset)
                        // Liabilities
                        accountSection(type: .liability)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(p.text(en: "Net Worth", es: "Patrimonio Neto", pt: "Patrimônio Líquido", fr: "Patrimoine Net", ar: "صافي الثروة", de: "Nettovermögen", it: "Patrimonio Netto", nl: "Nettovermogen", ja: "純資産", ko: "순자산"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        editingAccount = nil
                        showAddAccount = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(BXPalette.textPrimary)
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(p.text(en: "Done", es: "Listo", pt: "Feito", fr: "Terminé", ar: "تم", de: "Fertig", it: "Fatto", nl: "Klaar", ja: "完了", ko: "완료")) { dismiss() }
                        .font(.body.weight(.semibold))
                        .foregroundStyle(BXPalette.textPrimary)
                }
            }
            .sheet(isPresented: $showAddAccount) {
                BXNetWorthAccountForm(editing: editingAccount)
                    .environmentObject(supabase)
            }
        }
    }

    @ViewBuilder
    private func accountSection(type: NetWorthAccountType) -> some View {
        let accounts = supabase.netWorthAccounts.filter { $0.type == type }
        let total = accounts.reduce(Decimal.zero) { $0 + $1.balance }
        let sectionTitle = type == .asset
            ? p.text(en: "Assets", es: "Activos", pt: "Ativos", fr: "Actifs", ar: "الأصول", de: "Vermögen", it: "Attivi", nl: "Activa", ja: "資産", ko: "자산")
            : p.text(en: "Liabilities", es: "Pasivos", pt: "Passivos", fr: "Passifs", ar: "الخصوم", de: "Schulden", it: "Passivi", nl: "Passiva", ja: "負債", ko: "부채")

        if !accounts.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(sectionTitle)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(BXPalette.textPrimary)
                    Spacer()
                    Text(total.currencyString(code: cc))
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(type == .asset ? BXPalette.income : BXPalette.expense)
                }
                .padding(.horizontal, 4)

                ForEach(accounts) { account in
                    Button {
                        editingAccount = account
                        showAddAccount = true
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: account.category.symbol)
                                .font(.subheadline)
                                .foregroundStyle(type == .asset ? BXPalette.income : BXPalette.expense)
                                .frame(width: 34, height: 34)
                                .background((type == .asset ? BXPalette.income : BXPalette.expense).opacity(0.13), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(account.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(BXPalette.textPrimary)
                                Text(account.category.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(BXPalette.textSecondary)
                            }
                            Spacer()
                            Text(account.balance.currencyString(code: cc))
                                .font(.subheadline.weight(.bold))
                                .monospacedDigit()
                                .foregroundStyle(BXPalette.textPrimary)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BXPalette.textTertiary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .bxGlassCard(cornerRadius: 14)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct BXNetWorthAccountForm: View {
    @EnvironmentObject private var supabase: SupabaseManager
    @Environment(\.dismiss) private var dismiss
    var editing: NetWorthAccount?

    @State private var name = ""
    @State private var category: NetWorthCategory = .bankAccount
    @State private var balanceText = ""
    @State private var showDeleteConfirm = false

    private var p: OnboardingProfile { supabase.onboardingProfile }
    private var isEditing: Bool { editing != nil }
    private var balance: Decimal { Decimal(string: balanceText.replacingOccurrences(of: ",", with: ".")) ?? .zero }

    var body: some View {
        NavigationStack {
            ZStack {
                BXBackground()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text(p.text(en: "Account name", es: "Nombre de cuenta", pt: "Nome da conta", fr: "Nom du compte", ar: "اسم الحساب", de: "Kontoname", it: "Nome conto", nl: "Rekeningnaam", ja: "口座名", ko: "계좌명"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BXPalette.textSecondary)
                            TextField(p.text(en: "e.g. Chase Checking", es: "Ej. Cuenta corriente", pt: "Ex. Conta corrente", fr: "Ex. Compte courant", ar: "مثال: حساب جاري", de: "z.B. Girokonto", it: "Es. Conto corrente", nl: "Bijv. Betaalrekening", ja: "例: 普通預金", ko: "예: 당좌예금"), text: $name)
                                .font(.body)
                                .foregroundStyle(BXPalette.textPrimary)
                                .padding(14)
                                .background(BXPalette.panelFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(BXPalette.panelStroke, lineWidth: 0.5))
                        }

                        // Category
                        VStack(alignment: .leading, spacing: 8) {
                            Text(p.text(en: "Category", es: "Categoría", pt: "Categoria", fr: "Catégorie", ar: "الفئة", de: "Kategorie", it: "Categoria", nl: "Categorie", ja: "カテゴリ", ko: "카테고리"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BXPalette.textSecondary)
                            Picker("", selection: $category) {
                                ForEach(NetWorthCategory.allCases) { cat in
                                    Label(cat.rawValue, systemImage: cat.symbol).tag(cat)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(BXPalette.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(BXPalette.panelFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(BXPalette.panelStroke, lineWidth: 0.5))
                        }

                        // Balance
                        VStack(alignment: .leading, spacing: 8) {
                            Text(p.text(en: "Balance", es: "Saldo", pt: "Saldo", fr: "Solde", ar: "الرصيد", de: "Saldo", it: "Saldo", nl: "Saldo", ja: "残高", ko: "잔액"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BXPalette.textSecondary)
                            TextField("0.00", text: $balanceText)
                                .keyboardType(.decimalPad)
                                .font(.body)
                                .foregroundStyle(BXPalette.textPrimary)
                                .padding(14)
                                .background(BXPalette.panelFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(BXPalette.panelStroke, lineWidth: 0.5))
                        }

                        if isEditing {
                            Button(role: .destructive) {
                                showDeleteConfirm = true
                            } label: {
                                Text(p.text(en: "Delete account", es: "Eliminar cuenta", pt: "Excluir conta", fr: "Supprimer le compte", ar: "حذف الحساب", de: "Konto löschen", it: "Elimina conto", nl: "Account verwijderen", ja: "口座を削除", ko: "계좌 삭제"))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(BXPalette.expense)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(BXPalette.expense.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(isEditing
                ? p.text(en: "Edit Account", es: "Editar Cuenta", pt: "Editar Conta", fr: "Modifier Compte", ar: "تعديل الحساب", de: "Konto bearbeiten", it: "Modifica Conto", nl: "Account bewerken", ja: "口座を編集", ko: "계좌 편집")
                : p.text(en: "Add Account", es: "Agregar Cuenta", pt: "Adicionar Conta", fr: "Ajouter Compte", ar: "إضافة حساب", de: "Konto hinzufügen", it: "Aggiungi Conto", nl: "Account toevoegen", ja: "口座を追加", ko: "계좌 추가"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(p.text(en: "Cancel", es: "Cancelar", pt: "Cancelar", fr: "Annuler", ar: "إلغاء", de: "Abbrechen", it: "Annulla", nl: "Annuleren", ja: "キャンセル", ko: "취소")) { dismiss() }
                        .foregroundStyle(BXPalette.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(p.text(en: "Save", es: "Guardar", pt: "Salvar", fr: "Enregistrer", ar: "حفظ", de: "Speichern", it: "Salva", nl: "Opslaan", ja: "保存", ko: "저장")) {
                        if let acc = editing {
                            supabase.updateNetWorthAccount(acc, name: name, category: category, balance: balance)
                        } else {
                            supabase.addNetWorthAccount(name: name, category: category, balance: balance)
                        }
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(name.isEmpty ? BXPalette.textTertiary : BXPalette.textPrimary)
                    .disabled(name.isEmpty)
                }
            }
            .confirmationDialog(p.text(en: "Delete this account?", es: "¿Eliminar esta cuenta?", pt: "Excluir esta conta?", fr: "Supprimer ce compte?", ar: "حذف هذا الحساب؟", de: "Konto löschen?", it: "Eliminare questo conto?", nl: "Dit account verwijderen?", ja: "この口座を削除しますか？", ko: "이 계좌를 삭제하시겠어요?"), isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button(p.text(en: "Delete", es: "Eliminar", pt: "Excluir", fr: "Supprimer", ar: "حذف", de: "Löschen", it: "Elimina", nl: "Verwijderen", ja: "削除", ko: "삭제"), role: .destructive) {
                    if let acc = editing { supabase.deleteNetWorthAccount(acc) }
                    dismiss()
                }
            }
            .onAppear {
                if let acc = editing {
                    name = acc.name
                    category = acc.category
                    balanceText = "\(acc.balance)"
                }
            }
        }
    }
}

// MARK: - Share Sheet

#if canImport(UIKit)
private struct BXShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

// MARK: - Notifications View

private struct BXNotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var supabase: SupabaseManager

    var body: some View {
        NavigationStack {
            ZStack {
                BXBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if supabase.dailyNotifications.isEmpty {
                            BXEmptyStateCard(
                                title: supabase.onboardingProfile.text(en: "No notifications", es: "Sin notificaciones",
                                    pt: "Sem notificações", fr: "Aucune notification", ar: "لا توجد إشعارات",
                                    de: "Keine Benachrichtigungen", it: "Nessuna notifica", nl: "Geen meldingen",
                                    ja: "通知はありません", ko: "알림 없음"),
                                message: supabase.onboardingProfile.text(en: "Reminders and alerts will appear here.", es: "Recordatorios y alertas apareceran aqui.",
                                    pt: "Lembretes e alertas aparecerão aqui.", fr: "Les rappels et alertes apparaîtront ici.",
                                    ar: "ستظهر التذكيرات والتنبيهات هنا.", de: "Erinnerungen und Benachrichtigungen erscheinen hier.",
                                    it: "I promemoria e gli avvisi appariranno qui.", nl: "Herinneringen en meldingen verschijnen hier.",
                                    ja: "リマインダーとアラートがここに表示されます。", ko: "알림 및 경고가 여기에 표시됩니다."),
                                systemImage: "bell.slash"
                            )
                        } else {
                            ForEach(supabase.dailyNotifications) { item in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(item.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(BXPalette.textPrimary)
                                    Text(item.message)
                                        .font(.caption)
                                        .foregroundStyle(BXPalette.textSecondary)
                                    Spacer(minLength: 0)
                                    Text(item.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption2)
                                        .foregroundStyle(BXPalette.textTertiary)
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
                                .bxGlassCard(cornerRadius: 20)
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(supabase.onboardingProfile.text(en: "Notifications", es: "Notificaciones",
                pt: "Notificações", fr: "Notifications", ar: "الإشعارات", de: "Benachrichtigungen",
                it: "Notifiche", nl: "Meldingen", ja: "通知", ko: "알림"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(supabase.onboardingProfile.text(en: "Done", es: "Listo",
                        pt: "Concluído", fr: "Terminé", ar: "تم", de: "Fertig",
                        it: "Fine", nl: "Klaar", ja: "完了", ko: "완료")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Subscription Form

private struct BXSubscriptionFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var supabase: SupabaseManager
    @State private var name = ""
    @State private var amount = ""
    @State private var dueDay = 1
    @State private var category: MonthlyPaymentCategory = .subscription
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            ZStack {
                BXBackground()
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        BXField(title: supabase.onboardingProfile.text(en: "Name", es: "Nombre", pt: "Nome", fr: "Nom", ar: "الاسم", de: "Name", it: "Nome", nl: "Naam", ja: "名前", ko: "이름"), text: $name, keyboardType: .default)
                        BXField(title: supabase.onboardingProfile.text(en: "Amount", es: "Monto", pt: "Valor", fr: "Montant", ar: "المبلغ", de: "Betrag", it: "Importo", nl: "Bedrag", ja: "金額", ko: "금액"), text: $amount, keyboardType: .decimalPad)

                        // Category picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text(supabase.onboardingProfile.text(en: "Category", es: "Categoría", pt: "Categoria", fr: "Catégorie", ar: "الفئة", de: "Kategorie", it: "Categoria", nl: "Categorie", ja: "カテゴリ", ko: "카테고리"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BXPalette.textPrimary.opacity(0.70))
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(MonthlyPaymentCategory.allCases) { cat in
                                        Button {
                                            category = cat
                                        } label: {
                                            Label(cat.label(supabase.onboardingProfile), systemImage: cat.systemImage)
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(category == cat ? Color.black : BXPalette.textSecondary)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(category == cat ? Color.white : BXPalette.fieldFill, in: Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        Stepper("\(supabase.onboardingProfile.text(en: "Due day", es: "Día de pago", pt: "Dia de vencimento", fr: "Jour d'échéance", ar: "يوم الاستحقاق", de: "Fälligkeitstag", it: "Giorno di scadenza", nl: "Vervaldag", ja: "支払日", ko: "납부일")): \(dueDay)", value: $dueDay, in: 1...28)
                            .foregroundStyle(BXPalette.textPrimary)
                            .padding(14)
                            .background(BXPalette.fieldFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                        BXField(title: supabase.onboardingProfile.text(en: "Notes (optional)", es: "Notas (opcional)", pt: "Notas (opcional)", fr: "Notes (facultatif)", ar: "ملاحظات (اختياري)", de: "Notizen (optional)", it: "Note (facoltative)", nl: "Notities (optioneel)", ja: "メモ（任意）", ko: "메모(선택)"), text: $notes, keyboardType: .default)

                        BXPrimaryButton(
                            title: supabase.onboardingProfile.text(en: "Save", es: "Guardar", pt: "Salvar", fr: "Enregistrer", ar: "حفظ", de: "Speichern", it: "Salva", nl: "Opslaan", ja: "保存", ko: "저장"),
                            systemImage: "checkmark"
                        ) {
                            guard let decimalAmount = Decimal(string: amount.replacingOccurrences(of: ",", with: ".")) else { return }
                            supabase.addSubscription(name: name, amount: decimalAmount, dueDay: dueDay, category: category, notes: notes.isEmpty ? nil : notes)
                            dismiss()
                        }
                        .disabled(name.isEmpty || amount.isEmpty)
                        .opacity(name.isEmpty || amount.isEmpty ? 0.5 : 1)

                        Spacer()
                    }
                    .padding(20)
                }
            }
            .navigationTitle(supabase.onboardingProfile.text(en: "New Monthly Payment", es: "Nueva cuota mensual", pt: "Novo pagamento mensal", fr: "Nouveau paiement mensuel", ar: "دفعة شهرية جديدة", de: "Neue monatliche Zahlung", it: "Nuovo pagamento mensile", nl: "Nieuwe maandelijkse betaling", ja: "新しい月額支払い", ko: "새 월간 결제"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(supabase.onboardingProfile.text(en: "Close", es: "Cerrar", pt: "Fechar", fr: "Fermer", ar: "إغلاق", de: "Schließen", it: "Chiudi", nl: "Sluiten", ja: "閉じる", ko: "닫기")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Budget Form

private struct BXBudgetFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var supabase: SupabaseManager
    @State private var amount = ""

    var body: some View {
        NavigationStack {
            ZStack {
                BXBackground()
                VStack(alignment: .leading, spacing: 14) {
                    Text(supabase.onboardingProfile.text(
                        en: "How much can you spend this month?",
                        es: "¿Cuánto puedes gastar este mes?",
                        pt: "Quanto você pode gastar este mês?",
                        fr: "Combien pouvez-vous dépenser ce mois-ci?",
                        ar: "كم يمكنك أن تنفق هذا الشهر؟",
                        de: "Wie viel kannst du diesen Monat ausgeben?",
                        it: "Quanto puoi spendere questo mese?",
                        nl: "Hoeveel kun je deze maand uitgeven?",
                        ja: "今月いくら使えますか？",
                        ko: "이번 달에 얼마를 쓸 수 있나요?"
                    ))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(BXPalette.textPrimary)

                    BXField(title: supabase.onboardingProfile.text(en: "Monthly Budget", es: "Presupuesto mensual", pt: "Orçamento mensal", fr: "Budget mensuel", ar: "الميزانية الشهرية", de: "Monatsbudget", it: "Budget mensile", nl: "Maandbudget", ja: "月間予算", ko: "월 예산"), text: $amount, keyboardType: .decimalPad)

                    BXPrimaryButton(
                        title: supabase.onboardingProfile.text(en: "Save Budget", es: "Guardar presupuesto", pt: "Salvar orçamento", fr: "Enregistrer le budget", ar: "حفظ الميزانية", de: "Budget speichern", it: "Salva budget", nl: "Budget opslaan", ja: "予算を保存", ko: "예산 저장"),
                        systemImage: "checkmark"
                    ) {
                        guard let decimalAmount = Decimal(string: amount.replacingOccurrences(of: ",", with: ".")) else { return }
                        supabase.setCurrentMonthlyBudget(decimalAmount)
                        dismiss()
                    }
                    .disabled(amount.isEmpty)
                    .opacity(amount.isEmpty ? 0.5 : 1)

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle(supabase.onboardingProfile.text(en: "Monthly Budget", es: "Presupuesto del mes", pt: "Orçamento mensal", fr: "Budget mensuel", ar: "الميزانية الشهرية", de: "Monatsbudget", it: "Budget mensile", nl: "Maandbudget", ja: "月間予算", ko: "월 예산"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(supabase.onboardingProfile.text(en: "Close", es: "Cerrar", pt: "Fechar", fr: "Fermer", ar: "إغلاق", de: "Schließen", it: "Chiudi", nl: "Sluiten", ja: "閉じる", ko: "닫기")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Savings Goal Form

private struct BXSavingsGoalFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var supabase: SupabaseManager
    @State private var goalName = ""
    @State private var targetAmount = ""

    var body: some View {
        NavigationStack {
            ZStack {
                BXBackground()
                VStack(alignment: .leading, spacing: 14) {
                    BXField(
                        title: supabase.onboardingProfile.text(en: "Goal Name", es: "Nombre de meta", pt: "Nome da meta", fr: "Nom de l'objectif", ar: "اسم الهدف", de: "Name des Ziels", it: "Nome obiettivo", nl: "Doelnaam", ja: "目標名", ko: "목표 이름"),
                        text: $goalName,
                        keyboardType: .default
                    )

                    BXField(
                        title: supabase.onboardingProfile.text(en: "Target Amount", es: "Monto objetivo", pt: "Valor da meta", fr: "Montant cible", ar: "المبلغ المستهدف", de: "Zielbetrag", it: "Importo obiettivo", nl: "Doelbedrag", ja: "目標金額", ko: "목표 금액"),
                        text: $targetAmount,
                        keyboardType: .decimalPad
                    )

                    BXPrimaryButton(
                        title: supabase.onboardingProfile.text(en: "Create Goal", es: "Crear meta", pt: "Criar meta", fr: "Créer l'objectif", ar: "إنشاء هدف", de: "Ziel erstellen", it: "Crea obiettivo", nl: "Doel maken", ja: "目標を作成", ko: "목표 생성"),
                        systemImage: "target"
                    ) {
                        guard let amount = Decimal(string: targetAmount.replacingOccurrences(of: ",", with: ".")) else { return }
                        supabase.addSavingsGoal(name: goalName, targetAmount: amount)
                        dismiss()
                    }
                    .disabled(goalName.isEmpty || targetAmount.isEmpty)
                    .opacity(goalName.isEmpty || targetAmount.isEmpty ? 0.5 : 1)

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle(supabase.onboardingProfile.text(en: "New Savings Goal", es: "Nueva meta de ahorro", pt: "Nova meta de poupança", fr: "Nouvel objectif d'épargne", ar: "هدف ادخار جديد", de: "Neues Sparziel", it: "Nuovo obiettivo di risparmio", nl: "Nieuw spaardoel", ja: "新しい貯蓄目標", ko: "새 저축 목표"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(supabase.onboardingProfile.text(en: "Close", es: "Cerrar", pt: "Fechar", fr: "Fermer", ar: "إغلاق", de: "Schließen", it: "Chiudi", nl: "Sluiten", ja: "閉じる", ko: "닫기")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Transaction Detail

private struct BXTransactionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var supabase: SupabaseManager
    let transaction: AccountingTransaction
    @State private var editingTransaction: AccountingTransaction?
    @State private var sharePayload: SharePayload?
    @State private var zoomPayload: SharePayload?
    @State private var selectedReceiptItem: PhotosPickerItem?
    @State private var showingReceiptPicker = false
    @State private var isAttachingReceipt = false

    var body: some View {
        NavigationStack {
            ZStack {
                BXBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        headerCard
                        receiptCard
                        reconciliationCard
                        auditCard
                        actionRow
                    }
                    .padding(20)
                }
            }
            .navigationTitle(supabase.onboardingProfile.text(en: "Transaction", es: "Transacción", pt: "Transação", fr: "Transaction", ar: "معاملة", de: "Transaktion", it: "Transazione", nl: "Transactie", ja: "取引", ko: "거래"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(supabase.onboardingProfile.text(en: "Close", es: "Cerrar", pt: "Fechar", fr: "Fermer", ar: "إغلاق", de: "Schließen", it: "Chiudi", nl: "Sluiten", ja: "閉じる", ko: "닫기")) {
                        dismiss()
                    }
                }
            }
            .sheet(item: $editingTransaction) { transaction in
                AddExpenseView(initialTransaction: transaction)
                    .environmentObject(supabase)
            }
            .sheet(item: $sharePayload) { payload in
                BXShareSheet(items: [payload.url])
            }
            .sheet(item: $zoomPayload) { payload in
                BXReceiptZoomView(imageURL: payload.url)
            }
            .photosPicker(isPresented: $showingReceiptPicker, selection: $selectedReceiptItem, matching: .images)
            .onChange(of: selectedReceiptItem) { _, newValue in
                guard let newValue else { return }
                attachReceipt(from: newValue)
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(transaction.vendor)
                .font(.title3.weight(.bold))
                .foregroundStyle(BXPalette.textPrimary)
            Text(transaction.amount.currencyString(code: supabase.onboardingProfile.currencyCode))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(transaction.type == .income ? BXPalette.income : BXPalette.expense)

            VStack(alignment: .leading, spacing: 6) {
                detailRow(
                    title: supabase.onboardingProfile.text(en: "Category", es: "Categoría", pt: "Categoria", fr: "Catégorie", ar: "الفئة", de: "Kategorie", it: "Categoria", nl: "Categorie", ja: "カテゴリ", ko: "카테고리"),
                    value: transaction.category
                )
                detailRow(
                    title: supabase.onboardingProfile.text(en: "Date", es: "Fecha", pt: "Data", fr: "Date", ar: "التاريخ", de: "Datum", it: "Data", nl: "Datum", ja: "日付", ko: "날짜"),
                    value: transaction.date.formatted(date: .complete, time: .omitted)
                )
                if let notes = transaction.notes, !notes.isEmpty {
                    detailRow(
                        title: supabase.onboardingProfile.text(en: "Notes", es: "Notas", pt: "Notas", fr: "Notes", ar: "ملاحظات", de: "Notizen", it: "Note", nl: "Notities", ja: "メモ", ko: "메모"),
                        value: notes
                    )
                }
            }
        }
        .padding(20)
        .bxGlassCard(cornerRadius: 24)
    }

    private var receiptCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(supabase.onboardingProfile.text(en: "Receipt", es: "Recibo", pt: "Recibo", fr: "Reçu", ar: "إيصال", de: "Beleg", it: "Ricevuta", nl: "Bon", ja: "レシート", ko: "영수증"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BXPalette.textPrimary)

            if let receipt = supabase.receipt(for: transaction.id), let url = URL(string: receipt.imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        Button {
                            zoomPayload = SharePayload(url: url)
                        } label: {
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    case .failure(_):
                        receiptPlaceholder
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 160)
                    @unknown default:
                        receiptPlaceholder
                    }
                }
            } else {
                receiptPlaceholder
            }
        }
        .padding(20)
        .bxGlassCard(cornerRadius: 24)
    }

    private var receiptPlaceholder: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.text.image")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(BXPalette.textTertiary)
            Text(supabase.onboardingProfile.text(en: "No receipt attached.", es: "Sin recibo adjunto.", pt: "Nenhum recibo anexado.", fr: "Aucun reçu joint.", ar: "لا يوجد إيصال مرفق.", de: "Kein Beleg angehängt.", it: "Nessuna ricevuta allegata.", nl: "Geen bon toegevoegd.", ja: "添付されたレシートはありません。", ko: "첨부된 영수증이 없습니다."))
                .font(.caption)
                .foregroundStyle(BXPalette.textSecondary)
            Button {
                showingReceiptPicker = true
            } label: {
                Label(supabase.onboardingProfile.text(en: "Attach receipt", es: "Adjuntar recibo", pt: "Anexar recibo", fr: "Joindre un reçu", ar: "إرفاق إيصال", de: "Beleg anhängen", it: "Allega ricevuta", nl: "Bon toevoegen", ja: "レシートを添付", ko: "영수증 첨부"), systemImage: "paperclip")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isAttachingReceipt)
        }
        .frame(maxWidth: .infinity, minHeight: 140)
        .background(BXPalette.fieldFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var reconciliationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(supabase.onboardingProfile.text(en: "Reconciliation", es: "Conciliacion", pt: "Conciliacao", fr: "Rapprochement", ar: "مطابقة", de: "Abgleich", it: "Riconciliazione", nl: "Afstemming", ja: "照合", ko: "조정"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BXPalette.textPrimary)
            Picker("", selection: Binding(
                get: { supabase.reconciliationStatus(for: transaction) },
                set: { supabase.setReconciliationStatus($0, for: transaction) }
            )) {
                ForEach(ReconciliationStatus.allCases) { status in
                    Text(statusLabel(status)).tag(status)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(20)
        .bxGlassCard(cornerRadius: 24)
    }

    private var auditCard: some View {
        let entries = supabase.auditEntries(for: transaction)
        return VStack(alignment: .leading, spacing: 12) {
            Text(supabase.onboardingProfile.text(en: "Change history", es: "Historial de cambios", pt: "Historico de alteracoes", fr: "Historique des modifications", ar: "سجل التغييرات", de: "Aenderungsverlauf", it: "Cronologia modifiche", nl: "Wijzigingsgeschiedenis", ja: "変更履歴", ko: "변경 기록"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BXPalette.textPrimary)
            if entries.isEmpty {
                Text(supabase.onboardingProfile.text(en: "No changes recorded yet.", es: "Aun no hay cambios registrados.", pt: "Ainda nao ha alteracoes registradas.", fr: "Aucun changement enregistre.", ar: "لم يتم تسجيل تغييرات بعد.", de: "Noch keine Aenderungen erfasst.", it: "Nessuna modifica registrata.", nl: "Nog geen wijzigingen vastgelegd.", ja: "記録された変更はまだありません。", ko: "아직 기록된 변경 사항이 없습니다."))
                    .font(.caption)
                    .foregroundStyle(BXPalette.textSecondary)
            } else {
                ForEach(entries.prefix(5)) { entry in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundStyle(BXPalette.accentStart)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(auditLabel(entry.action))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BXPalette.textPrimary)
                            Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(BXPalette.textTertiary)
                        }
                    }
                }
            }
        }
        .padding(20)
        .bxGlassCard(cornerRadius: 24)
    }

    private var actionRow: some View {
        VStack(spacing: 10) {
            if let receipt = supabase.receipt(for: transaction.id), let url = URL(string: receipt.imageURL) {
                Button {
                    sharePayload = SharePayload(url: url)
                } label: {
                    Label(supabase.onboardingProfile.text(en: "Share receipt", es: "Compartir recibo", pt: "Compartilhar recibo", fr: "Partager le reçu", ar: "مشاركة الإيصال", de: "Beleg teilen", it: "Condividi ricevuta", nl: "Bon delen", ja: "レシートを共有", ko: "영수증 공유"), systemImage: "square.and.arrow.up")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                Button {
                    editingTransaction = transaction
                } label: {
                    Label(supabase.onboardingProfile.text(en: "Edit", es: "Editar", pt: "Editar", fr: "Modifier", ar: "تعديل", de: "Bearbeiten", it: "Modifica", nl: "Bewerken", ja: "編集", ko: "편집"), systemImage: "pencil")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BXPalette.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(BXPalette.fieldFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    Task {
                        let deleted = await supabase.deleteTransaction(transaction)
                        if deleted {
                            dismiss()
                        }
                    }
                } label: {
                    Label(supabase.onboardingProfile.text(en: "Delete", es: "Eliminar", pt: "Excluir", fr: "Supprimer", ar: "حذف", de: "Löschen", it: "Elimina", nl: "Verwijderen", ja: "削除", ko: "삭제"), systemImage: "trash")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(BXPalette.expense)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(BXPalette.expense.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func detailRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(BXPalette.textTertiary)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(BXPalette.textPrimary)
        }
    }

    private func attachReceipt(from item: PhotosPickerItem) {
        isAttachingReceipt = true
        Task {
            defer { Task { @MainActor in isAttachingReceipt = false } }
            guard let data = try? await item.loadTransferable(type: Data.self) else { return }
            do {
                let url = try await supabase.uploadReceiptImageForOCR(imageData: data, fileExtension: "jpg")
                _ = await supabase.updateTransaction(
                    transaction,
                    type: transaction.type,
                    vendor: transaction.vendor,
                    amount: transaction.amount,
                    category: transaction.category,
                    date: transaction.date,
                    notes: transaction.notes,
                    imageURL: url,
                    rawText: nil
                )
            } catch {
                await MainActor.run { supabase.errorMessage = error.localizedDescription }
            }
        }
    }

    private func statusLabel(_ status: ReconciliationStatus) -> String {
        switch status {
        case .pending:
            return supabase.onboardingProfile.text(en: "Pending", es: "Pendiente", pt: "Pendente", fr: "En attente", ar: "معلق", de: "Ausstehend", it: "In sospeso", nl: "In behandeling", ja: "保留中", ko: "보류")
        case .reviewed:
            return supabase.onboardingProfile.text(en: "Reviewed", es: "Revisado", pt: "Revisado", fr: "Verifie", ar: "تمت المراجعة", de: "Geprueft", it: "Revisionato", nl: "Beoordeeld", ja: "確認済み", ko: "검토됨")
        case .reconciled:
            return supabase.onboardingProfile.text(en: "Reconciled", es: "Conciliado", pt: "Conciliado", fr: "Rapproche", ar: "تمت المطابقة", de: "Abgeglichen", it: "Riconciliato", nl: "Afgestemd", ja: "照合済み", ko: "조정됨")
        }
    }

    private func auditLabel(_ action: String) -> String {
        switch action {
        case "created":
            return supabase.onboardingProfile.text(en: "Created", es: "Creado", pt: "Criado", fr: "Cree", ar: "تم الإنشاء", de: "Erstellt", it: "Creato", nl: "Gemaakt", ja: "作成済み", ko: "생성됨")
        case "updated":
            return supabase.onboardingProfile.text(en: "Updated", es: "Actualizado", pt: "Atualizado", fr: "Mis a jour", ar: "تم التحديث", de: "Aktualisiert", it: "Aggiornato", nl: "Bijgewerkt", ja: "更新済み", ko: "업데이트됨")
        case "deleted":
            return supabase.onboardingProfile.text(en: "Deleted", es: "Eliminado", pt: "Excluido", fr: "Supprime", ar: "تم الحذف", de: "Geloescht", it: "Eliminato", nl: "Verwijderd", ja: "削除済み", ko: "삭제됨")
        default:
            return statusLabel(ReconciliationStatus(rawValue: action) ?? .pending)
        }
    }
}

private struct SharePayload: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Receipt Zoom

private struct BXReceiptZoomView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var supabase: SupabaseManager
    let imageURL: URL
    @State private var scale = 1.0
    @State private var lastScale = 1.0

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(scale)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        scale = max(1, min(lastScale * value, 5))
                                    }
                                    .onEnded { _ in
                                        lastScale = scale
                                    }
                            )
                            .onTapGesture(count: 2) {
                                if scale > 1.1 {
                                    scale = 1
                                    lastScale = 1
                                } else {
                                    scale = 2
                                    lastScale = 2
                                }
                            }
                            .padding()
                    case .failure(_):
                        Text(supabase.onboardingProfile.text(
                            en: "Unable to load image",
                            es: "No se pudo cargar la imagen",
                            pt: "Não foi possível carregar a imagem",
                            fr: "Impossible de charger l'image",
                            ar: "تعذر تحميل الصورة",
                            de: "Bild konnte nicht geladen werden",
                            it: "Impossibile caricare l'immagine",
                            nl: "Kan afbeelding niet laden",
                            ja: "画像を読み込めませんでした",
                            ko: "이미지를 불러올 수 없습니다"
                        ))
                            .foregroundStyle(.white)
                    case .empty:
                        ProgressView()
                            .tint(.white)
                    @unknown default:
                        EmptyView()
                    }
                }
            }
            .navigationTitle(supabase.onboardingProfile.text(
                en: "Receipt",
                es: "Recibo",
                pt: "Recibo",
                fr: "Reçu",
                ar: "إيصال",
                de: "Beleg",
                it: "Ricevuta",
                nl: "Bon",
                ja: "レシート",
                ko: "영수증"
            ))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(supabase.onboardingProfile.text(
                        en: "Done",
                        es: "Listo",
                        pt: "Concluir",
                        fr: "Terminé",
                        ar: "تم",
                        de: "Fertig",
                        it: "Fine",
                        nl: "Gereed",
                        ja: "完了",
                        ko: "완료"
                    )) {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
    }
}


// MARK: - Deposit to Savings Goal

private struct BXDepositToGoalView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var supabase: SupabaseManager
    let goal: SavingsGoal
    @State private var amountText = ""

    private var prof: OnboardingProfile { supabase.onboardingProfile }
    private var parsedAmount: Decimal? {
        Decimal(string: amountText.replacingOccurrences(of: ",", with: "."))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BXBackground()
                VStack(alignment: .leading, spacing: 16) {
                    // Goal summary
                    VStack(alignment: .leading, spacing: 6) {
                        Text(goal.name)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(BXPalette.textPrimary)

                        let progress = goal.targetAmount > .zero
                            ? min(1.0, (goal.savedAmount as NSDecimalNumber).doubleValue / (goal.targetAmount as NSDecimalNumber).doubleValue)
                            : 0.0

                        HStack {
                            GeometryReader { proxy in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(BXPalette.fieldFill)
                                        .frame(height: 6)
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(BXPalette.income)
                                        .frame(width: proxy.size.width * progress, height: 6)
                                }
                            }
                            .frame(height: 6)

                            Text("\(Int(progress * 100))%")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(BXPalette.income)
                        }

                        Text("\(goal.savedAmount.currencyString(code: supabase.onboardingProfile.currencyCode)) / \(goal.targetAmount.currencyString(code: supabase.onboardingProfile.currencyCode))")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(BXPalette.textSecondary)
                    }
                    .padding(18)
                    .bxGlassCard(cornerRadius: 20)

                    BXField(
                        title: prof.text(en: "Amount to deposit", es: "Monto a abonar", pt: "Valor a depositar", fr: "Montant à déposer", ar: "مبلغ الإيداع", de: "Einzahlungsbetrag", it: "Importo da versare", nl: "Te storten bedrag", ja: "入金額", ko: "입금 금액"),
                        text: $amountText,
                        keyboardType: .decimalPad
                    )

                    BXPrimaryButton(
                        title: prof.text(en: "Deposit", es: "Abonar", pt: "Depositar", fr: "Déposer", ar: "إيداع", de: "Einzahlen", it: "Deposita", nl: "Storten", ja: "入金", ko: "입금"),
                        systemImage: "plus.circle.fill"
                    ) {
                        guard let amount = parsedAmount, amount > 0 else { return }
                        supabase.depositToSavingsGoal(goal, amount: amount)
                        dismiss()
                    }
                    .disabled(parsedAmount == nil || (parsedAmount ?? 0) <= 0)
                    .opacity(parsedAmount == nil || (parsedAmount ?? 0) <= 0 ? 0.5 : 1)

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle(prof.text(en: "Deposit to Goal", es: "Abonar a meta", pt: "Depositar na meta", fr: "Déposer dans l'objectif", ar: "إيداع في الهدف", de: "In Ziel einzahlen", it: "Deposita nell'obiettivo", nl: "Storten naar doel", ja: "目標へ入金", ko: "목표에 입금"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(prof.text(en: "Close", es: "Cerrar", pt: "Fechar", fr: "Fermer", ar: "إغلاق", de: "Schließen", it: "Chiudi", nl: "Sluiten", ja: "閉じる", ko: "닫기")) { dismiss() }
                }
            }
        }
    }
}

// MARK: - Count-up Amount Helper

/// Animates a currency value from 0 to target on appear, rolling digits like a counter.
private struct BXCountUpAmount: View {
    let value: Decimal
    let code: String
    let font: Font
    var color: Color? = nil
    var positiveGradient: LinearGradient? = nil
    var negativeGradient: LinearGradient? = nil

    @State private var displayed: Double = 0

    private var isPositive: Bool { value >= .zero }
    private var displayDecimal: Decimal { NSDecimalNumber(value: displayed).decimalValue }

    var body: some View {
        let text = Text(displayDecimal.smartCurrencyString(code: code))
            .font(font)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.65)
            .contentTransition(.numericText())

        Group {
            if let c = color {
                text.foregroundStyle(c)
            } else if isPositive, let g = positiveGradient {
                text.foregroundStyle(g)
            } else if !isPositive, let g = negativeGradient {
                text.foregroundStyle(g)
            } else {
                text.foregroundStyle(Color.white)
            }
        }
        .onAppear {
            let target = NSDecimalNumber(decimal: value).doubleValue
            withAnimation(.easeOut(duration: 1.3).delay(0.2)) {
                displayed = target
            }
        }
        .onChange(of: value) { _, v in
            withAnimation(.easeOut(duration: 0.55)) {
                displayed = NSDecimalNumber(decimal: v).doubleValue
            }
        }
    }
}

// MARK: - Categories Sheet

private struct BXCategoriesSheet: View {
    @EnvironmentObject private var supabase: SupabaseManager
    @Environment(\.dismiss) private var dismiss
    @Binding var newCategoryName: String

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField(
                            supabase.onboardingProfile.text(en: "New category", es: "Nueva categoria", pt: "Nova categoria", fr: "Nouvelle categorie", de: "Neue Kategorie", it: "Nuova categoria", nl: "Nieuwe categorie", ja: "New category", ko: "New category"),
                            text: $newCategoryName
                        )
                        Button(supabase.onboardingProfile.text(en: "Add", es: "Agregar", pt: "Adicionar", fr: "Ajouter", de: "Hinzufuegen", it: "Aggiungi", nl: "Toevoegen", ja: "Add", ko: "Add")) {
                            supabase.addCustomCategory(named: newCategoryName)
                            newCategoryName = ""
                        }
                        .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                Section {
                    if supabase.customCategories.isEmpty {
                        Text(supabase.onboardingProfile.text(en: "No custom categories yet.", es: "Sin categorias personalizadas.", pt: "Sem categorias personalizadas.", fr: "Aucune categorie personnalisee.", de: "Keine benutzerdefinierten Kategorien.", it: "Nessuna categoria personalizzata.", nl: "Nog geen aangepaste categorieen.", ja: "No custom categories yet.", ko: "No custom categories yet."))
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(supabase.customCategories) { category in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(category.name)
                                    Text(category.isHidden
                                         ? supabase.onboardingProfile.text(en: "Hidden", es: "Oculta", pt: "Oculta", fr: "Masquee", de: "Ausgeblendet", it: "Nascosta", nl: "Verborgen", ja: "Hidden", ko: "Hidden")
                                         : supabase.onboardingProfile.text(en: "Visible", es: "Visible", pt: "Visivel", fr: "Visible", de: "Sichtbar", it: "Visibile", nl: "Zichtbaar", ja: "Visible", ko: "Visible"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button {
                                    supabase.setCustomCategory(category, hidden: !category.isHidden)
                                } label: {
                                    Image(systemName: category.isHidden ? "eye.slash" : "eye")
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.secondary)
                                Button(role: .destructive) {
                                    supabase.deleteCustomCategory(category)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(BXPalette.expense)
                            }
                        }
                    }
                } header: {
                    Text(supabase.onboardingProfile.text(en: "Custom Categories", es: "Categorias personalizadas", pt: "Categorias personalizadas", fr: "Categories personnalisees", de: "Benutzerdefinierte Kategorien", it: "Categorie personalizzate", nl: "Aangepaste categorieen", ja: "Custom categories", ko: "Custom categories"))
                }
            }
            .navigationTitle(supabase.onboardingProfile.text(en: "Categories", es: "Categorias", pt: "Categorias", fr: "Categories", de: "Kategorien", it: "Categorie", nl: "Categorieen", ja: "Categories", ko: "Categories"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(supabase.onboardingProfile.text(en: "Done", es: "Listo", pt: "Pronto", fr: "Termine", de: "Fertig", it: "Fatto", nl: "Klaar", ja: "Done", ko: "Done")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(SupabaseManager())
        .environmentObject(AppSession())
}
