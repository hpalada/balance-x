import Foundation

enum AppServiceError: LocalizedError {
    case configurationMissing(String)
    case invalidLocalData
    case unsupportedOperation(String)

    var errorDescription: String? {
        switch self {
        case .configurationMissing(let key):
            "Missing configuration value for \(key)."
        case .invalidLocalData:
            "Stored local data is invalid."
        case .unsupportedOperation(let message):
            message
        }
    }
}

extension DateFormatter {
    static let receiptServiceDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}

extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
}

actor ExchangeRateService {
    static let shared = ExchangeRateService()

    private let session: URLSession
    private var cache: [String: Decimal] = [:]

    init(session: URLSession = .shared) {
        self.session = session
    }

    func convert(amount: Decimal, from sourceCode: String?, to targetCode: String) async -> CurrencyConversionResult {
        guard let sourceCode, sourceCode != targetCode else {
            return CurrencyConversionResult(amount: amount, sourceCurrencyCode: sourceCode)
        }

        let cacheKey = "\(sourceCode)-\(targetCode)"
        if let rate = cache[cacheKey] {
            return CurrencyConversionResult(amount: amount * rate, sourceCurrencyCode: sourceCode)
        }

        guard
            let encodedSource = sourceCode.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
            let encodedTarget = targetCode.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
            let url = URL(string: "https://api.frankfurter.dev/v2/rate/\(encodedSource)/\(encodedTarget)")
        else {
            return CurrencyConversionResult(amount: amount, sourceCurrencyCode: sourceCode)
        }

        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
                return CurrencyConversionResult(amount: amount, sourceCurrencyCode: sourceCode)
            }

            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let rateValue = object?["rate"] as? Double else {
                return CurrencyConversionResult(amount: amount, sourceCurrencyCode: sourceCode)
            }
            let rate = Decimal(rateValue)
            cache[cacheKey] = rate
            return CurrencyConversionResult(amount: amount * rate, sourceCurrencyCode: sourceCode)
        } catch {
            return CurrencyConversionResult(amount: amount, sourceCurrencyCode: sourceCode)
        }
    }
}

final class ReceiptLearningStore {
    static let shared = ReceiptLearningStore()

    private let defaults = UserDefaults.standard
    private let key = "bx_receipt_learning_store"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func learnedCorrection(rawText: String?, vendorGuess: String?) -> LearnedReceiptCorrection? {
        let corrections = loadCorrections()
        for signature in signatures(rawText: rawText, vendorGuess: vendorGuess) {
            if let match = corrections[signature] {
                return match
            }
        }
        return nil
    }

    func saveCorrection(
        rawText: String?,
        vendorGuess: String?,
        correctedVendor: String,
        correctedCategory: String,
        correctedTransactionType: TransactionType
    ) {
        let candidateSignatures = signatures(rawText: rawText, vendorGuess: vendorGuess)
        guard !candidateSignatures.isEmpty else { return }

        var corrections = loadCorrections()
        for signature in candidateSignatures {
            corrections[signature] = LearnedReceiptCorrection(
                id: corrections[signature]?.id ?? UUID(),
                signature: signature,
                correctedVendor: correctedVendor,
                correctedCategory: correctedCategory,
                correctedTransactionType: correctedTransactionType,
                updatedAt: .now
            )
        }

        if let data = try? encoder.encode(corrections) {
            defaults.set(data, forKey: key)
        }
    }

    private func loadCorrections() -> [String: LearnedReceiptCorrection] {
        guard let data = defaults.data(forKey: key),
              let value = try? decoder.decode([String: LearnedReceiptCorrection].self, from: data)
        else {
            return [:]
        }
        return value
    }

    private func signatures(rawText: String?, vendorGuess: String?) -> [String] {
        var values: [String] = []
        if let rawText {
            let signature = signature(for: rawText)
            if !signature.isEmpty { values.append(signature) }
        }
        if let vendorGuess {
            let signature = signature(for: vendorGuess)
            if !signature.isEmpty { values.append(signature) }
        }
        return Array(Set(values))
    }

    private func signature(for input: String) -> String {
        let normalized = input
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()

        let separators = CharacterSet.alphanumerics.inverted
        let tokens = normalized
            .components(separatedBy: separators)
            .filter { $0.count >= 3 && !stopwords.contains($0) }

        return Array(tokens.prefix(8)).joined(separator: "-")
    }

    private let stopwords: Set<String> = [
        "total", "receipt", "recibo", "invoice", "factura", "date", "fecha",
        "amount", "monto", "payment", "pago", "tax", "isv", "iva", "usd", "hnl"
    ]
}
