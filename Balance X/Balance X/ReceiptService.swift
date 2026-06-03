import Foundation

struct ReceiptService {
    private let session: URLSession
    private let baseURL: URL
    private let publishableKey: String?

    static func makeIfConfigured(session: URLSession = .shared) -> ReceiptService? {
        guard
            let supabaseURLString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let supabaseURL = URL(string: supabaseURLString),
            !supabaseURLString.isEmpty
        else {
            return nil
        }

        let functionURL = supabaseURL.appendingPathComponent("functions/v1/scan-receipt")
        let publishableKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String
        return ReceiptService(session: session, baseURL: functionURL, publishableKey: publishableKey)
    }

    init(session: URLSession = .shared) {
        self.session = session

        guard
            let supabaseURLString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let supabaseURL = URL(string: supabaseURLString),
            !supabaseURLString.isEmpty
        else {
            fatalError("Missing SUPABASE_URL configuration for ReceiptService.")
        }

        let functionURL = supabaseURL.appendingPathComponent("functions/v1/scan-receipt")
        self.baseURL = functionURL
        self.publishableKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String
    }

    private init(session: URLSession, baseURL: URL, publishableKey: String?) {
        self.session = session
        self.baseURL = baseURL
        self.publishableKey = publishableKey
    }

    func scanReceipt(imageURL: URL) async throws -> OCRReceiptResponse {
        struct RequestBody: Codable {
            let imageUrl: String
        }

        var request = URLRequest(url: baseURL.appendingPathComponent("scan-receipt"))
        if baseURL.absoluteString.contains("/functions/v1/scan-receipt") {
            request = URLRequest(url: baseURL)
        }
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let publishableKey, !publishableKey.isEmpty {
            request.setValue(publishableKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(publishableKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(RequestBody(imageUrl: imageURL.absoluteString))

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw ReceiptServiceError.serverError(httpResponse.statusCode)
        }

        return try JSONDecoder().decode(OCRReceiptResponse.self, from: data)
    }
}

enum ReceiptServiceError: LocalizedError {
    case serverError(Int)
    case imageMissing
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .serverError(let code):
            "OCR service returned status code \(code)."
        case .imageMissing:
            "Please select an image before continuing."
        case .notConfigured:
            "Receipt OCR backend is not configured yet."
        }
    }
}
