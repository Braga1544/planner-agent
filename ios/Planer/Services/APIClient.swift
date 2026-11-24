import Foundation

struct ServerConfig: Equatable {
    var baseURL: URL
    var deviceToken: String
    var accessClientId: String
    var accessClientSecret: String
}

enum APIError: LocalizedError, Equatable {
    case http(status: Int, message: String)
    case unauthorized
    case accessDenied
    case network
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .http(_, let message): message
        case .unauthorized: "Token ungültig oder gesperrt."
        case .accessDenied: "Cloudflare Access hat die Anfrage abgelehnt – Service-Token prüfen."
        case .network: "Server nicht erreichbar."
        case .invalidResponse: "Unerwartete Antwort vom Server."
        }
    }

    // fastapi detail is a string or a list
    static func message(from data: Data, status: Int) -> String {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let detail = object["detail"] as? String { return detail }
            if let list = object["detail"] as? [[String: Any]] {
                let messages = list.compactMap { $0["msg"] as? String }
                if !messages.isEmpty { return messages.joined(separator: "; ") }
            }
        }
        return "Fehler \(status)"
    }
}

final class APIClient {
    let config: ServerConfig
    private let session: URLSession
    private let onUnauthorized: () -> Void
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(config: ServerConfig, session: URLSession = .shared, onUnauthorized: @escaping () -> Void = {}) {
        self.config = config
        self.session = session
        self.onUnauthorized = onUnauthorized
    }

    func get<T: Decodable>(_ path: String) async throws -> T {
        try decode(try await data(method: "GET", path: path, body: nil))
    }

    func post<T: Decodable>(_ path: String, body: some Encodable) async throws -> T {
        try decode(try await data(method: "POST", path: path, body: try encoder.encode(body)))
    }

    func post<T: Decodable>(_ path: String) async throws -> T {
        try decode(try await data(method: "POST", path: path, body: nil))
    }

    func patch<T: Decodable>(_ path: String, body: some Encodable) async throws -> T {
        try decode(try await data(method: "PATCH", path: path, body: try encoder.encode(body)))
    }

    func delete(_ path: String) async throws {
        _ = try await data(method: "DELETE", path: path, body: nil)
    }

    func stream(_ path: String, body: some Encodable) async throws -> URLSession.AsyncBytes {
        var request = try makeRequest(method: "POST", path: path, body: try encoder.encode(body))
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 300
        let bytes: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (bytes, response) = try await session.bytes(for: request)
        } catch {
            throw Self.transportError(error)
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        if !(200..<300).contains(http.statusCode) || http.mimeType == "text/html" {
            var collected = Data()
            for try await byte in bytes {
                collected.append(byte)
                if collected.count > 65_536 { break }
            }
            try check(http, data: collected)
        }
        return bytes
    }

    // MARK: internal

    private func makeRequest(method: String, path: String, body: Data?) throws -> URLRequest {
        var base = config.baseURL.absoluteString
        while base.hasSuffix("/") { base.removeLast() }
        guard let url = URL(string: base + "/api/v1" + path) else {
            throw APIError.http(status: 0, message: "Ungültige Server-Adresse.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(config.deviceToken)", forHTTPHeaderField: "Authorization")
        if !config.accessClientId.isEmpty {
            request.setValue(config.accessClientId, forHTTPHeaderField: "CF-Access-Client-Id")
            request.setValue(config.accessClientSecret, forHTTPHeaderField: "CF-Access-Client-Secret")
        }
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    private func data(method: String, path: String, body: Data?) async throws -> Data {
        let request = try makeRequest(method: method, path: path, body: body)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw Self.transportError(error)
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        try check(http, data: data)
        return data
    }

    // cancel stays cancel, not "server unreachable"
    private static func transportError(_ error: Error) -> Error {
        if error is CancellationError || (error as? URLError)?.code == .cancelled { return CancellationError() }
        return APIError.network
    }

    private func check(_ http: HTTPURLResponse, data: Data) throws {
        // cf access redirects to login html or returns 403
        if http.mimeType == "text/html" || http.url?.host?.hasSuffix("cloudflareaccess.com") == true || http.statusCode == 403 {
            throw APIError.accessDenied
        }
        if http.statusCode == 401 {
            onUnauthorized()
            throw APIError.unauthorized
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.http(status: http.statusCode, message: APIError.message(from: data, status: http.statusCode))
        }
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        if T.self == EmptyResponse.self, let empty = EmptyResponse() as? T { return empty }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.invalidResponse
        }
    }
}

struct EmptyResponse: Decodable {}
