import Foundation
#if canImport(UIKit)
import UIKit
import ImageIO
#endif
import Vision

enum ReceiptVisionAnalyzer {
    private struct MerchantProfile {
        let name: String
        let aliases: [String]
        let category: String
        let documentType: OCRDocumentType?
        let preferredTransactionType: TransactionType?
        let countryCodes: [String]
    }

    private static let merchantProfiles: [MerchantProfile] = [
        MerchantProfile(name: "BAC", aliases: ["BAC", "BANCO BAC", "BANCO DE AMERICA CENTRAL"], category: "Transfer", documentType: .transfer, preferredTransactionType: .income, countryCodes: ["HN", "US"]),
        MerchantProfile(name: "Ficohsa", aliases: ["FICOHSA", "BANCO FICOHSA"], category: "Transfer", documentType: .transfer, preferredTransactionType: .income, countryCodes: ["HN"]),
        MerchantProfile(name: "Banco Atlántida", aliases: ["ATLANTIDA", "ATLÁNTIDA", "BANCO ATLANTIDA"], category: "Transfer", documentType: .transfer, preferredTransactionType: .income, countryCodes: ["HN"]),
        MerchantProfile(name: "La Colonia", aliases: ["LA COLONIA", "SUPERMERCADOS LA COLONIA"], category: "Groceries", documentType: .receipt, preferredTransactionType: .expense, countryCodes: ["HN"]),
        MerchantProfile(name: "Walmart", aliases: ["WALMART"], category: "Groceries", documentType: .receipt, preferredTransactionType: .expense, countryCodes: ["HN", "US"]),
        MerchantProfile(name: "Pricesmart", aliases: ["PRICESMART", "PRICE SMART"], category: "Groceries", documentType: .receipt, preferredTransactionType: .expense, countryCodes: ["HN", "US"]),
        MerchantProfile(name: "Shell", aliases: ["SHELL"], category: "Fuel", documentType: .receipt, preferredTransactionType: .expense, countryCodes: ["US"]),
        MerchantProfile(name: "Chevron", aliases: ["CHEVRON"], category: "Fuel", documentType: .receipt, preferredTransactionType: .expense, countryCodes: ["US"]),
        MerchantProfile(name: "Texaco", aliases: ["TEXACO"], category: "Fuel", documentType: .receipt, preferredTransactionType: .expense, countryCodes: ["HN", "US"]),
        MerchantProfile(name: "Exxon", aliases: ["EXXON"], category: "Fuel", documentType: .receipt, preferredTransactionType: .expense, countryCodes: ["US"]),
        MerchantProfile(name: "Mobil", aliases: ["MOBIL"], category: "Fuel", documentType: .receipt, preferredTransactionType: .expense, countryCodes: ["US"]),
        MerchantProfile(name: "Speedway", aliases: ["SPEEDWAY"], category: "Fuel", documentType: .receipt, preferredTransactionType: .expense, countryCodes: ["US"]),
        MerchantProfile(name: "Circle K", aliases: ["CIRCLE K"], category: "Fuel", documentType: .receipt, preferredTransactionType: .expense, countryCodes: ["US"]),
        MerchantProfile(name: "Murphy USA", aliases: ["MURPHY USA", "MURPHY"], category: "Fuel", documentType: .receipt, preferredTransactionType: .expense, countryCodes: ["US"]),
        MerchantProfile(name: "Costco Gas", aliases: ["COSTCO GAS", "COSTCO WHOLESALE"], category: "Fuel", documentType: .receipt, preferredTransactionType: .expense, countryCodes: ["US"]),
        MerchantProfile(name: "7-Eleven", aliases: ["7-ELEVEN", "7 ELEVEN"], category: "Fuel", documentType: .receipt, preferredTransactionType: .expense, countryCodes: ["US"]),
        MerchantProfile(name: "Farmacia Kielsa", aliases: ["KIELSA", "FARMACIA KIELSA"], category: "Pharmacy", documentType: .receipt, preferredTransactionType: .expense, countryCodes: ["HN"]),
        MerchantProfile(name: "Farmacias del Ahorro", aliases: ["FARMACIAS DEL AHORRO", "DEL AHORRO"], category: "Pharmacy", documentType: .receipt, preferredTransactionType: .expense, countryCodes: ["HN"]),
        MerchantProfile(name: "CVS Pharmacy", aliases: ["CVS", "CVS PHARMACY"], category: "Pharmacy", documentType: .receipt, preferredTransactionType: .expense, countryCodes: ["US"]),
        MerchantProfile(name: "Walgreens", aliases: ["WALGREENS"], category: "Pharmacy", documentType: .receipt, preferredTransactionType: .expense, countryCodes: ["US"]),
        MerchantProfile(name: "McDonald's", aliases: ["MCDONALD", "MCDONALDS"], category: "Restaurant", documentType: .receipt, preferredTransactionType: .expense, countryCodes: ["HN", "US"]),
        MerchantProfile(name: "Starbucks", aliases: ["STARBUCKS"], category: "Restaurant", documentType: .receipt, preferredTransactionType: .expense, countryCodes: ["US"]),
        MerchantProfile(name: "Espresso Americano", aliases: ["ESPRESSO AMERICANO", "AMERICANO"], category: "Restaurant", documentType: .receipt, preferredTransactionType: .expense, countryCodes: ["HN"])
    ]

    static func analyze(imageData: Data) async throws -> OCRReceiptResponse {
        try await analyzeDetailed(imageData: imageData).response
    }

    static func analyzeDetailed(imageData: Data) async throws -> OCRVisionScanResult {
        // Try OpenAI GPT-4o Vision first; fall back to local Vision framework
        if let openAIKey = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String,
           !openAIKey.isEmpty {
            if let result = try? await analyzeWithOpenAI(imageData: imageData, apiKey: openAIKey) {
                return result
            }
        }
        return try await analyzeWithLocalVision(imageData: imageData)
    }

    // MARK: - OpenAI GPT-4o Vision

    private static func analyzeWithOpenAI(imageData: Data, apiKey: String) async throws -> OCRVisionScanResult {
        // Resize image to max 1024px to reduce token cost while keeping quality
        let optimizedData = resizedImageData(imageData, maxDimension: 1024) ?? imageData
        let base64Image = optimizedData.base64EncodedString()

        let prompt = """
        You are an expert receipt and financial document analyzer. Analyze this image carefully.

        Return ONLY a valid JSON object with exactly these fields:
        {
          "vendor": "Business/store name (empty string if not found)",
          "amount": 0.00,
          "date": "YYYY-MM-DD",
          "currency_code": "USD",
          "category": "one of: Food, Groceries, Coffee, Transport, Gas, Travel, Rent, Utilities, Internet, Phone, Health, Pharmacy, Gym, Education, Subscriptions, Software, Clothing, Shopping, Electronics, Entertainment, Salary, Freelance, Sales, Taxes, Insurance, Other",
          "transaction_type": "expense or income",
          "document_type": "receipt, invoice, transfer, or unknown",
          "confidence": 0.95
        }

        Rules:
        - amount: total amount paid (number only, no currency symbols)
        - date: today's date if not visible
        - currency_code: detect from symbols ($=USD, L=HNL, €=EUR, etc.)
        - transaction_type: expense for purchases/receipts/invoices; income for deposits/transfers received
        - Return ONLY JSON, no markdown, no explanation
        """

        struct OpenAIRequest: Encodable {
            let model: String
            let messages: [Message]
            let maxTokens: Int
            let responseFormat: ResponseFormat

            enum CodingKeys: String, CodingKey {
                case model, messages
                case maxTokens = "max_tokens"
                case responseFormat = "response_format"
            }

            struct Message: Encodable {
                let role: String
                let content: [Content]

                struct Content: Encodable {
                    let type: String
                    let text: String?
                    let imageUrl: ImageURL?

                    enum CodingKeys: String, CodingKey {
                        case type, text
                        case imageUrl = "image_url"
                    }

                    struct ImageURL: Encodable {
                        let url: String
                        let detail: String
                    }
                }
            }

            struct ResponseFormat: Encodable {
                let type: String
            }
        }

        let requestBody = OpenAIRequest(
            model: "gpt-4o",
            messages: [
                OpenAIRequest.Message(role: "user", content: [
                    OpenAIRequest.Message.Content(
                        type: "text",
                        text: prompt,
                        imageUrl: nil
                    ),
                    OpenAIRequest.Message.Content(
                        type: "image_url",
                        text: nil,
                        imageUrl: .init(url: "data:image/jpeg;base64,\(base64Image)", detail: "high")
                    )
                ])
            ],
            maxTokens: 512,
            responseFormat: OpenAIRequest.ResponseFormat(type: "json_object")
        )

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw ReceiptServiceError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        // Parse OpenAI wrapper to get content
        struct OpenAIResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let content: String }
                let message: Message
            }
            let choices: [Choice]
        }

        let aiResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        guard let content = aiResponse.choices.first?.message.content,
              let jsonData = content.data(using: .utf8) else {
            throw ReceiptServiceError.notConfigured
        }

        // Parse the structured JSON from GPT
        struct ParsedReceipt: Decodable {
            let vendor: String?
            let amount: Double?
            let date: String?
            let currencyCode: String?
            let category: String?
            let transactionType: String?
            let documentType: String?

            enum CodingKeys: String, CodingKey {
                case vendor, amount, date, category
                case currencyCode = "currency_code"
                case transactionType = "transaction_type"
                case documentType = "document_type"
            }
        }

        let parsed = try JSONDecoder().decode(ParsedReceipt.self, from: jsonData)
        let today = DateFormatter.receiptServiceDate.string(from: .now)

        let docType: OCRDocumentType
        switch parsed.documentType?.lowercased() {
        case "receipt":  docType = .receipt
        case "invoice":  docType = .invoice
        case "transfer": docType = .transfer
        default:         docType = .unknown
        }

        let txType: TransactionType? = parsed.transactionType?.lowercased() == "income" ? .income : .expense

        let ocrResponse = OCRReceiptResponse(
            vendor: parsed.vendor ?? "",
            amount: parsed.amount ?? 0,
            date: parsed.date ?? today
        )

        return OCRVisionScanResult(
            response: ocrResponse,
            rawText: content,
            currencyCode: parsed.currencyCode,
            documentType: docType,
            suggestedCategory: parsed.category,
            suggestedTransactionType: txType
        )
    }

    // MARK: - Local Apple Vision (fallback)

    static func analyzeWithLocalVision(imageData: Data) async throws -> OCRVisionScanResult {
        #if canImport(UIKit)
        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
        else {
            throw ReceiptServiceError.imageMissing
        }

        let image = UIImage(data: imageData)
        let orientations = candidateOrientations(for: image)
        let results = try orientations.map { orientation in
            try recognizeReceipt(in: cgImage, orientation: orientation)
        }

        guard let best = results.max(by: { $0.score < $1.score }) else {
            throw ReceiptServiceError.notConfigured
        }

        return best.result
        #else
        throw ReceiptServiceError.notConfigured
        #endif
    }

    // MARK: - Image resize helper

    private static func resizedImageData(_ data: Data, maxDimension: CGFloat) -> Data? {
        #if canImport(UIKit)
        guard let image = UIImage(data: data) else { return nil }
        let size = image.size
        guard size.width > maxDimension || size.height > maxDimension else { return data }
        let scale = maxDimension / max(size.width, size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
        return resized.jpegData(compressionQuality: 0.85)
        #else
        return data
        #endif
    }

    #if canImport(UIKit)
    private static func recognizeReceipt(in cgImage: CGImage, orientation: CGImagePropertyOrientation) throws -> ScoredScanResult {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["es-HN", "es-419", "en-US"]
        request.minimumTextHeight = 0.012

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
        try handler.perform([request])

        let observations = request.results ?? []
        let lines = observations
            .compactMap { $0.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let text = lines.joined(separator: "\n")
        let profile = matchedProfile(from: text)
        let documentType = profile?.documentType ?? detectDocumentType(from: text)
        let currencyCode = extractCurrencyCode(from: text)
        let amount = extractAmount(from: lines, currencyCode: currencyCode)
        let vendor = profile?.name ?? extractVendor(from: lines, documentType: documentType)
        let category = profile?.category ?? suggestedCategory(from: text, documentType: documentType)
        let transactionType = profile?.preferredTransactionType ?? suggestedTransactionType(from: text, documentType: documentType)

        let response = OCRReceiptResponse(
            vendor: vendor,
            amount: amount,
            date: extractDate(from: text)
        )

        let result = OCRVisionScanResult(
            response: response,
            rawText: text,
            currencyCode: currencyCode,
            documentType: documentType,
            suggestedCategory: category,
            suggestedTransactionType: transactionType
        )

        return ScoredScanResult(
            result: result,
            score: score(result: result, lines: lines, orientation: orientation)
        )
    }

    private static func candidateOrientations(for image: UIImage?) -> [CGImagePropertyOrientation] {
        var candidates: [CGImagePropertyOrientation] = []
        if let image {
            candidates.append(image.imageOrientation.cgImagePropertyOrientation)
        }
        candidates.append(contentsOf: [.right, .left, .up, .down])

        var unique: [CGImagePropertyOrientation] = []
        for candidate in candidates where !unique.contains(candidate) {
            unique.append(candidate)
        }
        return unique
    }

    private static func score(
        result: OCRVisionScanResult,
        lines: [String],
        orientation: CGImagePropertyOrientation
    ) -> Int {
        var score = 0

        if !result.response.vendor.isEmpty, result.response.vendor.lowercased() != "receipt" {
            score += 12
        }

        if result.response.amount > 0 {
            score += 16
        }

        if result.currencyCode != nil {
            score += 5
        }

        if result.documentType != .unknown {
            score += 4
        }

        let topLines = Array(lines.prefix(10)).joined(separator: " ").uppercased()
        if topLines.contains(result.response.vendor.uppercased()) {
            score += 8
        }

        if lines.contains(where: { containsStrongTotalKeyword($0) }) {
            score += 10
        }

        if orientation == .right || orientation == .left {
            score += 3
        }

        return score
    }
    #endif

    private static func extractVendor(from lines: [String], documentType: OCRDocumentType) -> String {
        let bankKeywords = [
            "BAC", "FICOHSA", "ATLANTIDA", "BANPAIS", "BANRURAL", "BANCO",
            "CHASE", "BANK OF AMERICA", "WELLS FARGO", "CITI", "CAPITAL ONE"
        ]
        let ignoredKeywords = [
            "FACTURA", "INVOICE", "RECIBO", "RECEIPT", "TOTAL", "SUBTOTAL",
            "AUTORIZACION", "AUTORIZACIÓN", "TERMINAL", "LOTE", "REFERENCIA",
            "ISV", "IVA", "IMPUESTO", "CAI", "RTN", "FECHA", "DATE", "HORA",
            "CAJERO", "CUSTOMER", "CLIENTE", "PAGO", "PAYMENT", "MONTO", "AMOUNT"
        ]

        let headerLines = Array(lines.prefix(12))

        if documentType == .transfer,
           let bankLine = headerLines.first(where: { line in
               let uppercased = line.uppercased()
               return bankKeywords.contains(where: uppercased.contains)
           }) {
            return cleanedLabel(bankLine)
        }

        let candidates = headerLines.compactMap { line -> (String, Int)? in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let uppercased = trimmed.uppercased()

            guard trimmed.count >= 3 else { return nil }
            guard !ignoredKeywords.contains(where: uppercased.contains) else { return nil }
            guard digitRatio(in: trimmed) < 0.18 else { return nil }

            var score = 0
            if uppercased == trimmed { score += 3 }
            if line == headerLines.first { score += 6 }
            if trimmed.count <= 30 { score += 2 }
            if bankKeywords.contains(where: uppercased.contains) { score += 6 }
            if uppercased.contains("SUPER") || uppercased.contains("MARKET") || uppercased.contains("STORE") || uppercased.contains("SHOP") || uppercased.contains("RESTAURANT") {
                score += 2
            }
            if uppercased.contains("STATION") || uppercased.contains("TRAVEL") || uppercased.contains("MART") || uppercased.contains("FOOD") {
                score += 2
            }

            return (cleanedLabel(trimmed), score)
        }

        if let best = candidates.max(by: { $0.1 < $1.1 })?.0 {
            return best
        }

        if looksLikeFuelReceipt(text: lines.joined(separator: "\n")) {
            return "Fuel Station"
        }

        return "Receipt"
    }

    private static func matchedProfile(from text: String) -> MerchantProfile? {
        let normalized = text.uppercased()
        return merchantProfiles.first { profile in
            profile.aliases.contains { normalized.contains($0) }
        }
    }

    private static func extractAmount(from lines: [String], currencyCode: String?) -> Double {
        var candidates: [(Double, Int)] = []

        for line in lines {
            let uppercased = line.uppercased()
            let amountTokens = amountStrings(in: line)

            for token in amountTokens {
                guard let value = parseAmount(token), value > 0 else { continue }

                var score = 0
                if containsStrongTotalKeyword(line) { score += 18 }
                if containsFuelTotalKeyword(line) { score += 15 }
                if uppercased.contains("SUBTOTAL") { score -= 10 }
                if uppercased.contains("ISV") || uppercased.contains("IVA") || uppercased.contains("TAX") || uppercased.contains("IMPUESTO") { score -= 8 }
                if uppercased.contains("CAMBIO") || uppercased.contains("CHANGE") || uppercased.contains("PROPINA") || uppercased.contains("TIP") { score -= 7 }
                if uppercased.contains("GALLONS") || uppercased.contains("GALONES") || uppercased.contains("PRICE/G") || uppercased.contains("PRICE PER GALLON") || uppercased.contains("UNIT PRICE") {
                    score -= 10
                }
                if uppercased.contains("TOTAL A PAGAR") || uppercased.contains("IMPORTE A PAGAR") || uppercased.contains("TOTAL PAYMENT") { score += 12 }
                if uppercased.contains("FUEL SALE") || uppercased.contains("PAYMENT AMOUNT") || uppercased.contains("DEBIT") || uppercased.contains("CREDIT") || uppercased.contains("SALE AMOUNT") {
                    score += 10
                }
                if uppercased.contains("MONTO") || uppercased.contains("AMOUNT") || uppercased.contains("VALOR") { score += 4 }
                if currencyCode == "HNL", uppercased.contains("L.") { score += 2 }
                if currencyCode == "USD", uppercased.contains("$") { score += 2 }
                if value >= 1 { score += 1 }

                candidates.append((value, score))
            }
        }

        if let best = candidates.sorted(by: {
            if $0.1 == $1.1 { return $0.0 > $1.0 }
            return $0.1 > $1.1
        }).first {
            return best.0
        }

        return 0
    }

    private static func extractDate(from text: String) -> String {
        let patterns = [
            #"\b(\d{4}-\d{2}-\d{2})\b"#,
            #"\b(\d{2}/\d{2}/\d{4})\b"#,
            #"\b(\d{2}-\d{2}-\d{4})\b"#,
            #"\b(\d{2}/\d{2}/\d{2})\b"#,
            #"\b(\d{2}-\d{2}-\d{2})\b"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                let candidate = String(text[range])
                return normalizeDate(candidate) ?? DateFormatter.receiptServiceDate.string(from: .now)
            }
        }

        return DateFormatter.receiptServiceDate.string(from: .now)
    }

    private static func normalizeDate(_ value: String) -> String? {
        if value.contains("-"), value.prefix(4).allSatisfy(\.isNumber) {
            return value
        }

        let formats = [
            "MM/dd/yyyy", "dd/MM/yyyy", "MM-dd-yyyy", "dd-MM-yyyy",
            "MM/dd/yy", "dd/MM/yy", "MM-dd-yy", "dd-MM-yy"
        ]

        for format in formats {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            if let date = formatter.date(from: value) {
                return DateFormatter.receiptServiceDate.string(from: date)
            }
        }

        return nil
    }

    private static func extractCurrencyCode(from text: String) -> String? {
        let normalized = text.uppercased()
        if normalized.contains("HNL") || normalized.contains("LPS") || normalized.contains("LEMPIRA") || normalized.contains("L.") {
            return "HNL"
        }
        if normalized.contains("USD") || normalized.contains("US$") || normalized.contains("DOLAR") || normalized.contains("DÓLAR") {
            return "USD"
        }
        if normalized.contains("$") {
            return "USD"
        }
        return nil
    }

    private static func detectDocumentType(from text: String) -> OCRDocumentType {
        let normalized = text.uppercased()
        if normalized.contains("TRANSFERENCIA")
            || normalized.contains("ACH")
            || normalized.contains("WIRE")
            || normalized.contains("DEPOSITO")
            || normalized.contains("DEPÓSITO")
            || normalized.contains("ENVIADO")
            || normalized.contains("RECIBIDO") {
            return .transfer
        }
        if normalized.contains("FACTURA") || normalized.contains("INVOICE") {
            return .invoice
        }
        if normalized.contains("RECIBO") || normalized.contains("RECEIPT") || normalized.contains("TOTAL") {
            return .receipt
        }
        return .unknown
    }

    private static func suggestedCategory(for documentType: OCRDocumentType) -> String? {
        switch documentType {
        case .transfer:
            return "Transfer"
        case .invoice:
            return "Invoice"
        case .receipt, .unknown:
            return nil
        }
    }

    private static func suggestedCategory(from text: String, documentType: OCRDocumentType) -> String? {
        if looksLikeFuelReceipt(text: text) {
            return "Fuel"
        }
        return suggestedCategory(for: documentType)
    }

    private static func suggestedTransactionType(from text: String, documentType: OCRDocumentType) -> TransactionType? {
        let normalized = text.uppercased()

        if looksLikeFuelReceipt(text: normalized) {
            return .expense
        }

        switch documentType {
        case .receipt, .invoice:
            return .expense
        case .transfer:
            let incomingHints = ["RECIBIDO", "RECEIVED", "ABONO", "CRÉDITO", "CREDITO", "DEPOSITO", "DEPÓSITO", "INCOMING"]
            let outgoingHints = ["ENVIADO", "SENT", "PAGO", "PAYMENT", "DÉBITO", "DEBIT", "OUTGOING"]

            if incomingHints.contains(where: normalized.contains) { return .income }
            if outgoingHints.contains(where: normalized.contains) { return .expense }
            return .income
        case .unknown:
            return nil
        }
    }

    private static func amountStrings(in text: String) -> [String] {
        let pattern = #"(?:US\$|\$|L\.\s*|HNL\s*|USD\s*)?([0-9]{1,3}(?:[.,][0-9]{3})*(?:[.,][0-9]{2})|[0-9]+(?:[.,][0-9]{2}))"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsRange = NSRange(text.startIndex..., in: text)

        return regex.matches(in: text, range: nsRange).compactMap { match in
            guard let range = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[range])
        }
    }

    private static func parseAmount(_ text: String) -> Double? {
        let sanitized = text.replacingOccurrences(of: " ", with: "")
        let commaCount = sanitized.filter { $0 == "," }.count
        let dotCount = sanitized.filter { $0 == "." }.count

        if commaCount > 0 && dotCount > 0 {
            if let lastSeparator = sanitized.lastIndex(where: { $0 == "," || $0 == "." }) {
                let decimalSeparator = sanitized[lastSeparator]
                let thousandsSeparator: Character = decimalSeparator == "." ? "," : "."
                let normalized = sanitized
                    .replacingOccurrences(of: String(thousandsSeparator), with: "")
                    .replacingOccurrences(of: String(decimalSeparator), with: ".")
                return Double(normalized)
            }
        }

        if commaCount > 0 {
            let parts = sanitized.split(separator: ",")
            if parts.count == 2, parts[1].count == 2 {
                return Double(sanitized.replacingOccurrences(of: ",", with: "."))
            }
            return Double(sanitized.replacingOccurrences(of: ",", with: ""))
        }

        return Double(sanitized)
    }

    private static func containsStrongTotalKeyword(_ line: String) -> Bool {
        let normalized = line.uppercased()
        let keywords = [
            "TOTAL", "TOTAL A PAGAR", "TOTAL PAGADO", "IMPORTE TOTAL",
            "VALOR TOTAL", "MONTO TOTAL", "AMOUNT DUE", "BALANCE DUE",
            "NET TOTAL", "GRAND TOTAL"
        ]
        return keywords.contains(where: normalized.contains)
    }

    private static func containsFuelTotalKeyword(_ line: String) -> Bool {
        let normalized = line.uppercased()
        let keywords = [
            "FUEL SALE", "DEBIT", "PAYMENT AMOUNT", "SALE AMOUNT",
            "TOTAL DUE", "AMOUNT PAID", "CARD AMOUNT"
        ]
        return keywords.contains(where: normalized.contains)
    }

    private static func looksLikeFuelReceipt(text: String) -> Bool {
        let normalized = text.uppercased()
        let fuelSignals = [
            "PUMP", "SERVICE LEVEL", "REGULAR", "UNLEADED", "DIESEL",
            "PRICE/G", "GALLONS", "FUEL SALE", "OCTANE", "SELF", "GAS"
        ]
        let matches = fuelSignals.filter { normalized.contains($0) }
        return matches.count >= 2
    }

    private static func cleanedLabel(_ value: String) -> String {
        value
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func digitRatio(in text: String) -> Double {
        guard !text.isEmpty else { return 1 }
        let digits = text.filter(\.isNumber).count
        return Double(digits) / Double(text.count)
    }
}

#if canImport(UIKit)
private struct ScoredScanResult {
    let result: OCRVisionScanResult
    let score: Int
}

private extension UIImage.Orientation {
    var cgImagePropertyOrientation: CGImagePropertyOrientation {
        switch self {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
#endif
