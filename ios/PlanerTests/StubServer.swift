import Foundation
@testable import Planer

struct LoggedRequest {
    let method: String
    let path: String
    let query: [String: String]
    let body: Data?

    var json: [String: Any] {
        (body.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]) ?? [:]
    }
}

// fake server, responses keyed by "METHOD /path", logs all requests
final class StubServer {
    private struct Route {
        var status: Int
        var body: String
        var contentType: String
    }

    private let lock = NSLock()
    private var routes: [String: Route] = [:]
    private var log: [LoggedRequest] = []
    private(set) var baseURL: URL!

    init() {
        baseURL = StubURLProtocol.register { [weak self] request in
            guard let self else { throw URLError(.cancelled) }
            return self.handle(request)
        }
    }

    func on(_ method: String, _ path: String, status: Int = 200, json: String) {
        lock.withLock { routes["\(method) /api/v1\(path)"] = Route(status: status, body: json, contentType: "application/json") }
    }

    func onSSE(_ method: String, _ path: String, _ body: String) {
        lock.withLock { routes["\(method) /api/v1\(path)"] = Route(status: 200, body: body, contentType: "text/event-stream") }
    }

    func requests(_ method: String, _ path: String) -> [LoggedRequest] {
        lock.withLock { log.filter { $0.method == method && $0.path == "/api/v1\(path)" } }
    }

    func client(onUnauthorized: @escaping () -> Void = {}) -> APIClient {
        APIClient(
            config: ServerConfig(baseURL: baseURL, deviceToken: "test", accessClientId: "", accessClientSecret: ""),
            session: StubURLProtocol.session(),
            onUnauthorized: onUnauthorized
        )
    }

    private func handle(_ request: URLRequest) -> (HTTPURLResponse, Data) {
        let url = request.url!
        var query: [String: String] = [:]
        for item in URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? [] {
            query[item.name] = item.value ?? ""
        }
        let method = request.httpMethod ?? "GET"
        let entry = LoggedRequest(method: method, path: url.path, query: query, body: request.bodyData)
        let route: Route? = lock.withLock {
            log.append(entry)
            return routes["\(method) \(url.path)"]
        }
        guard let route else {
            return StubURLProtocol.response(request, status: 404, json: #"{"detail":"Kein Stub für \#(method) \#(url.path)"}"#)
        }
        return StubURLProtocol.response(request, status: route.status, json: route.body, contentType: route.contentType)
    }
}
