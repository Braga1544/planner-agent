import Foundation
import Testing
@testable import Planer

struct APIClientTests {
    func client(
        accessId: String = "cf-id",
        onUnauthorized: @escaping () -> Void = {},
        handler: @escaping StubURLProtocol.Handler
    ) -> APIClient {
        let config = ServerConfig(
            baseURL: StubURLProtocol.register(handler),
            deviceToken: "geheim",
            accessClientId: accessId,
            accessClientSecret: accessId.isEmpty ? "" : "cf-secret"
        )
        return APIClient(config: config, session: StubURLProtocol.session(), onUnauthorized: onUnauthorized)
    }

    @Test func sendsAuthAndAccessHeaders() async throws {
        var seen: URLRequest?
        let api = client { request in
            seen = request
            return StubURLProtocol.response(request, status: 200, json: #"{"token_name":"iPhone"}"#)
        }
        let me: Me = try await api.get("/me")
        #expect(me.tokenName == "iPhone")
        #expect(seen?.url?.path == "/api/v1/me")
        #expect(seen?.value(forHTTPHeaderField: "Authorization") == "Bearer geheim")
        #expect(seen?.value(forHTTPHeaderField: "CF-Access-Client-Id") == "cf-id")
        #expect(seen?.value(forHTTPHeaderField: "CF-Access-Client-Secret") == "cf-secret")
    }

    @Test func trailingSlashInBaseURLIsIgnored() async throws {
        var seen: URLRequest?
        let base = StubURLProtocol.register { request in
            seen = request
            return StubURLProtocol.response(request, status: 200, json: #"{"token_name":"iPhone"}"#)
        }
        let config = ServerConfig(baseURL: URL(string: base.absoluteString + "/")!, deviceToken: "t", accessClientId: "", accessClientSecret: "")
        let _: Me = try await APIClient(config: config, session: StubURLProtocol.session()).get("/me")
        #expect(seen?.url?.path == "/api/v1/me")
    }

    @Test func postsJSONBody() async throws {
        var body: [String: Any]?
        var contentType: String?
        let api = client { request in
            body = try JSONSerialization.jsonObject(with: request.bodyData ?? Data()) as? [String: Any]
            contentType = request.value(forHTTPHeaderField: "Content-Type")
            return StubURLProtocol.response(request, status: 201, json: #"{"id":"p1","area":"hobby","name":"A","description":null,"status":"active","created_at":"x","updated_at":"x"}"#)
        }
        let project: Project = try await api.post("/projects", body: ProjectCreate(area: .hobby, name: "A"))
        #expect(project.id == "p1")
        #expect(body?["area"] as? String == "hobby")
        #expect(contentType == "application/json")
    }

    @Test func errorDetailString() async {
        let api = client { request in
            StubURLProtocol.response(request, status: 404, json: #"{"detail":"Projekt nicht gefunden"}"#)
        }
        await #expect(throws: APIError.http(status: 404, message: "Projekt nicht gefunden")) {
            let _: Project = try await api.get("/projects/x")
        }
    }

    @Test func errorDetailListIsJoined() {
        let data = Data(#"{"detail":[{"msg":"Field required"},{"msg":"Input should be a valid date"}]}"#.utf8)
        #expect(APIError.message(from: data, status: 422) == "Field required; Input should be a valid date")
        #expect(APIError.message(from: Data(), status: 500) == "Fehler 500")
    }

    @Test func unauthorizedCallsHandler() async {
        var called = false
        let api = client(onUnauthorized: { called = true }) { request in
            StubURLProtocol.response(request, status: 401, json: #"{"detail":"x"}"#)
        }
        await #expect(throws: APIError.unauthorized) {
            let _: Me = try await api.get("/me")
        }
        #expect(called)
    }

    @Test func htmlResponseMeansAccessDenied() async {
        let api = client { request in
            StubURLProtocol.response(request, status: 200, json: "<html>Cloudflare Access</html>", contentType: "text/html")
        }
        await #expect(throws: APIError.accessDenied) {
            let _: Me = try await api.get("/me")
        }
    }

    @Test func forbiddenMeansAccessDenied() async {
        let api = client { request in StubURLProtocol.response(request, status: 403, json: "{}") }
        await #expect(throws: APIError.accessDenied) {
            let _: Me = try await api.get("/me")
        }
    }

    @Test func networkFailure() async {
        let api = client { _ in throw URLError(.notConnectedToInternet) }
        await #expect(throws: APIError.network) {
            let _: Me = try await api.get("/me")
        }
    }

    @Test func cancelledRequestIsNoNetworkError() async {
        let api = client { _ in throw URLError(.cancelled) }
        await #expect(throws: CancellationError.self) {
            let _: Me = try await api.get("/me")
        }
    }

    @Test func queryEncodesPlus() {
        let query = Query.string([("from", "2026-10-12T00:00:00+02:00"), ("q", "C# Bot")])
        #expect(query == "?from=2026-10-12T00:00:00%2B02:00&q=C%23%20Bot")
        #expect(Query.string([]) == "")
    }

    @Test func emptyAccessFieldsOmitHeaders() async throws {
        var seen: URLRequest?
        let api = client(accessId: "") { request in
            seen = request
            return StubURLProtocol.response(request, status: 200, json: #"{"token_name":"Web"}"#)
        }
        let _: Me = try await api.get("/me")
        #expect(seen?.value(forHTTPHeaderField: "CF-Access-Client-Id") == nil)
        #expect(seen?.value(forHTTPHeaderField: "CF-Access-Client-Secret") == nil)
    }
}
