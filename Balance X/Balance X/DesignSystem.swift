import SwiftUI

// MARK: - Typography

enum BXFont {
    static func display(size: CGFloat) -> Font {
        .custom("BebasNeue-Regular", size: size, relativeTo: .largeTitle)
    }

    static func thinCaption(size: CGFloat = 11) -> Font {
        .custom("Poppins-Thin", size: size, relativeTo: .caption2)
    }

    static func light(size: CGFloat = 14) -> Font {
        .custom("Poppins-Light", size: size, relativeTo: .subheadline)
    }
}

// MARK: - Palette

enum BXPalette {
    static let backgroundTop    = Color(red: 0.039, green: 0.039, blue: 0.059)
    static let backgroundBottom = Color.black

    static let accentStart = Color.white
    static let accentEnd   = Color(white: 0.88)

    static let income       = Color(red: 0.063, green: 0.918, blue: 0.533)  // #10EA88
    static let incomeLight  = Color(red: 0.063, green: 0.918, blue: 0.533).opacity(0.18)
    static let expense      = Color(red: 1.000, green: 0.286, blue: 0.392)  // #FF4964
    static let expenseLight = Color(red: 1.000, green: 0.286, blue: 0.392).opacity(0.18)
    static let warning      = Color(red: 1.000, green: 0.722, blue: 0.302)  // #FFB84D
    static let tax          = Color(red: 0.302, green: 0.722, blue: 1.000)  // #4DB8FF

    static let panelStroke         = Color.white.opacity(0.07)
    static let panelFill           = Color(red: 0.102, green: 0.102, blue: 0.141)  // #1A1A24
    static let panelFillElevated   = Color(red: 0.133, green: 0.133, blue: 0.184)  // #22222F

    static let textPrimary   = Color(red: 0.941, green: 0.941, blue: 1.000)  // #F0F0FF
    static let textSecondary = Color(red: 0.941, green: 0.941, blue: 1.000).opacity(0.55)
    static let textTertiary  = Color(red: 0.941, green: 0.941, blue: 1.000).opacity(0.30)

    static let fieldFill  = Color(red: 0.173, green: 0.173, blue: 0.243)  // #2C2C3E
    static let alertFill  = Color(red: 0.102, green: 0.102, blue: 0.141)
    static let tabInactive = Color(red: 0.941, green: 0.941, blue: 1.000).opacity(0.35)
    static let chromeShadow = Color.black.opacity(0.22)

    static let accentGradient = LinearGradient(
        colors: [accentStart, accentEnd],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

// MARK: - Background

struct BXBackground: View {
    var body: some View {
        LinearGradient(
            colors: [BXPalette.backgroundTop, BXPalette.backgroundBottom],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

// MARK: - Glass Card

struct BXGlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let fillOpacity: Double

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(
                    .regular.interactive(),
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(BXPalette.panelFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(BXPalette.panelStroke, lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)
        }
    }
}

extension View {
    func bxGlassCard(cornerRadius: CGFloat = 20, fillOpacity: Double = 1.0) -> some View {
        modifier(BXGlassCardModifier(cornerRadius: cornerRadius, fillOpacity: fillOpacity))
    }

    @ViewBuilder
    func bxLiquidControl(cornerRadius: CGFloat = 14) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(
                .regular,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        } else {
            self
                .background(BXPalette.fieldFill, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(BXPalette.panelStroke, lineWidth: 0.5)
                )
        }
    }

    /// Liquid glass with a tint color — used for accent elements.
    @ViewBuilder
    func bxLiquidTinted(_ color: Color, cornerRadius: CGFloat = 14) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(
                .regular.tint(color),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        } else {
            self
                .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(color.opacity(0.30), lineWidth: 0.5)
                )
        }
    }
}

// MARK: - Buttons

struct BXPrimaryButton: View {
    let title: String
    let systemImage: String?
    var isLoading = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView().tint(.white)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.subheadline.weight(.semibold))
                }
                Text(title)
                    .font(.headline.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 14)
            .padding(.vertical, 16)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
    }
}

struct BXSecondaryButton: View {
    let title: String
    let systemImage: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.subheadline.weight(.semibold))
                }
                Text(title)
                    .font(.headline.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(BXPalette.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 14)
            .padding(.vertical, 16)
            .bxLiquidControl(cornerRadius: 16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Section Title

struct BXSectionTitle: View {
    let eyebrow: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(eyebrow.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(BXPalette.textTertiary)
                .tracking(1.2)
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(BXPalette.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.88)
        }
    }
}

// MARK: - Metric Card

struct BXMetricCard: View {
    let title: String
    let value: Decimal
    let caption: String
    let color: Color
    let symbol: String
    var currencyCode: String = Locale.current.currency?.identifier ?? "USD"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color)
                    .frame(width: 28, height: 28)
                    .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                Spacer()
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(BXPalette.textSecondary)
                    .lineLimit(1)
                Text(value.currencyString(code: currencyCode))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(BXPalette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(caption)
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
    }
}

// MARK: - Empty State Card

struct BXEmptyStateCard: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(BXPalette.textTertiary)
                .frame(width: 48, height: 48)
                .background(BXPalette.fieldFill, in: Circle())
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(BXPalette.textPrimary)
            Text(message)
                .font(.caption)
                .foregroundStyle(BXPalette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .bxGlassCard()
    }
}

// MARK: - Status Pill

struct BXStatusPill: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.14), in: Capsule())
    }
}

// MARK: - Neuron Logo

struct BXNeuronLogo: View {
    var size: CGFloat = 82
    var animated = true
    var morphProgress: Double = 1.0

    @State private var breathScale: Double = 1.0
    @State private var glowPulse: Double = 0.45

    var body: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { i in
                let angle = Double(i) * 30.0
                Rectangle()
                    .fill(Color.white.opacity(0.55 * morphProgress))
                    .frame(width: size * 0.045, height: size * 0.36 * morphProgress)
                    .rotationEffect(.degrees(angle))
            }
            Circle()
                .fill(Color.white)
                .frame(width: size * 0.16, height: size * 0.16)
                .shadow(color: Color.white.opacity(0.5), radius: size * 0.08)
                .scaleEffect(breathScale)
        }
        .frame(width: size, height: size)
        .onAppear {
            guard animated else { return }
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                breathScale = 1.08
                glowPulse = 0.70
            }
        }
    }
}

// MARK: - Animated Brand

struct BXAnimatedBillLogo: View {
    let progress: CGFloat

    private func phase(_ start: CGFloat, _ end: CGFloat) -> CGFloat {
        guard progress > start else { return 0 }
        return min(1, (progress - start) / (end - start))
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .trim(from: 0, to: phase(0.0, 0.28))
                .stroke(Color.white, style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))
                .frame(width: 108, height: 66)

            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .trim(from: 0, to: phase(0.20, 0.48))
                .stroke(Color.white.opacity(0.42), style: StrokeStyle(lineWidth: 1.0, lineCap: .round, lineJoin: .round))
                .frame(width: 90, height: 50)

            Circle()
                .trim(from: 0, to: phase(0.38, 0.62))
                .stroke(Color.white, style: StrokeStyle(lineWidth: 1.9, lineCap: .round))
                .frame(width: 30, height: 30)
                .rotationEffect(.degrees(-90))

            Text("$")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(.white)
                .scaleEffect(0.5 + 0.5 * phase(0.56, 0.76))
                .opacity(Double(phase(0.56, 0.76)))

            VStack(spacing: 5) {
                Capsule().fill(Color.white.opacity(0.62)).frame(width: 10, height: 1.6)
                Capsule().fill(Color.white.opacity(0.62)).frame(width: 7, height: 1.6)
                Capsule().fill(Color.white.opacity(0.62)).frame(width: 5, height: 1.6)
            }
            .scaleEffect(x: phase(0.60, 0.82), y: 1, anchor: .leading)
            .opacity(Double(phase(0.60, 0.82)))
            .offset(x: -38)

            VStack(spacing: 5) {
                Capsule().fill(Color.white.opacity(0.62)).frame(width: 10, height: 1.6)
                Capsule().fill(Color.white.opacity(0.62)).frame(width: 7, height: 1.6)
                Capsule().fill(Color.white.opacity(0.62)).frame(width: 5, height: 1.6)
            }
            .scaleEffect(x: phase(0.68, 0.90), y: 1, anchor: .trailing)
            .opacity(Double(phase(0.68, 0.90)))
            .offset(x: 38)

            HStack(spacing: 3) {
                ForEach(0..<6, id: \.self) { _ in
                    Capsule()
                        .fill(Color.white.opacity(0.32))
                        .frame(width: 5.5, height: 2.8)
                }
            }
            .scaleEffect(x: phase(0.78, 1.0), y: 1, anchor: .leading)
            .opacity(Double(phase(0.78, 1.0)))
            .offset(x: -22, y: -19)

            HStack(spacing: 3) {
                ForEach(0..<6, id: \.self) { _ in
                    Capsule()
                        .fill(Color.white.opacity(0.32))
                        .frame(width: 5.5, height: 2.8)
                }
            }
            .scaleEffect(x: phase(0.78, 1.0), y: 1, anchor: .trailing)
            .opacity(Double(phase(0.78, 1.0)))
            .offset(x: 22, y: 19)
        }
        .shadow(color: .white.opacity(0.24 * Double(progress)), radius: 20, y: 6)
    }
}

struct BXFormingWordmark: View {
    var progress: CGFloat
    var fontSize: CGFloat = 60

    var body: some View {
        GeometryReader { proxy in
            let clamped = min(1, max(0, progress))
            let revealWidth = max(1, proxy.size.width * clamped)

            ZStack(alignment: .leading) {
                Text("Balance X")
                    .font(.system(size: fontSize, weight: .black))
                    .foregroundStyle(Color.white.opacity(0.10))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text("Balance X")
                    .font(.system(size: fontSize, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .mask(alignment: .leading) {
                        Rectangle()
                            .frame(width: revealWidth)
                    }

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.75), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 18)
                    .blur(radius: 2)
                    .opacity(clamped > 0 && clamped < 1 ? 1 : 0)
                    .offset(x: max(0, revealWidth - 9))
            }
        }
        .frame(height: fontSize * 1.05)
    }
}

// MARK: - Animated Progress Bar

struct BXProgressBar: View {
    let value: Double  // 0.0 - 1.0
    var color: Color = BXPalette.accentStart
    var height: CGFloat = 6
    @State private var animatedValue: Double = 0

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(height: height)
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(color)
                    .frame(width: proxy.size.width * animatedValue, height: height)
            }
        }
        .frame(height: height)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                animatedValue = min(1.0, max(0.0, value))
            }
        }
        .onChange(of: value) { _, newValue in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                animatedValue = min(1.0, max(0.0, newValue))
            }
        }
    }
}

// MARK: - Scanning Overlay

struct BXScanningOverlay: View {
    @State private var offset: CGFloat = -1

    var body: some View {
        GeometryReader { proxy in
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.3), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 60)
                .offset(y: offset * proxy.size.height)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                        offset = 1
                    }
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
