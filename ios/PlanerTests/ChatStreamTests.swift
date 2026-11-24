import Foundation
import Testing
@testable import Planer

private func bytes(_ text: String) -> AsyncStream<UInt8> {
    AsyncStream { continuation in
        for byte in Array(text.utf8) { continuation.yield(byte) }
        continuation.finish()
    }
}

private func failingBytes(_ text: String) -> AsyncThrowingStream<UInt8, Error> {
    AsyncThrowingStream { continuation in
        for byte in Array(text.utf8) { continuation.yield(byte) }
        continuation.finish(throwing: URLError(.networkConnectionLost))
    }
}

@MainActor
struct ChatStreamTests {
    @Test func parserHandlesFieldsCommentsAndCRLF() {
        var parser = SSEParser()
        #expect(parser.feed(line: ": ping") == nil)
        #expect(parser.feed(line: "event: text\r") == nil)
        #expect(parser.feed(line: "data: {\"delta\":\"Hal\"}") == nil)
        #expect(parser.feed(line: "") == SSEEvent(event: "text", data: "{\"delta\":\"Hal\"}"))
        #expect(parser.feed(line: "") == nil)
    }

    @Test func sequenceYieldsEventsAndIgnoresPing() async throws {
        let raw = ": ping\n\nevent: text\ndata: {\"delta\":\"Hallo\"}\n\nevent: done\ndata: {\"message_id\":\"m1\"}\n\n"
        var events: [SSEEvent] = []
        for try await event in SSEEventSequence(base: bytes(raw)) { events.append(event) }
        #expect(events.map(\.event) == ["text", "done"])
    }

    @Test func multibyteCharactersSurvive() async {
        let raw = "event: text\ndata: {\"delta\":\"Grüße – 👋\"}\n\n"
        var received: [ChatStreamEvent] = []
        await ChatStream.consume(bytes(raw)) { received.append($0) }
        #expect(received.first == .text("Grüße – 👋"))
    }

    @Test func mapsAllEventTypes() async {
        let raw = "event: tool_start\ndata: {\"name\":\"get_agenda\",\"id\":\"t1\"}\n\n"
            + "event: tool_end\ndata: {\"name\":\"get_agenda\",\"id\":\"t1\",\"is_error\":true}\n\n"
            + "event: text\ndata: {\"delta\":\"Fertig\"}\n\n"
            + "event: done\ndata: {\"message_id\":\"m9\"}\n\n"
        var received: [ChatStreamEvent] = []
        await ChatStream.consume(bytes(raw)) { received.append($0) }
        #expect(received == [
            .toolStart(name: "get_agenda", id: "t1"),
            .toolEnd(name: "get_agenda", id: "t1", isError: true),
            .text("Fertig"),
            .done(messageId: "m9"),
        ])
    }

    @Test func streamWithoutDoneReportsInterruption() async {
        var received: [ChatStreamEvent] = []
        await ChatStream.consume(bytes("event: text\ndata: {\"delta\":\"Hal\"}\n\n")) { received.append($0) }
        #expect(received == [.text("Hal"), .error(ChatStream.interrupted)])

        received = []
        await ChatStream.consume(failingBytes("event: text\ndata: {\"delta\":\"Hal\"}\n\n")) { received.append($0) }
        #expect(received == [.text("Hal"), .error(ChatStream.interrupted)])
    }

    @Test func truncatedTrailingEventIsDropped() async {
        var received: [ChatStreamEvent] = []
        await ChatStream.consume(bytes("event: done\ndata: {\"message_i")) { received.append($0) }
        #expect(received == [.error(ChatStream.interrupted)])
    }

    @Test func serverErrorEventEndsTurn() async {
        var received: [ChatStreamEvent] = []
        await ChatStream.consume(bytes("event: error\ndata: {\"detail\":\"Fehler der Claude-API\"}\n\n")) { received.append($0) }
        #expect(received == [.error("Fehler der Claude-API")])
    }
}
