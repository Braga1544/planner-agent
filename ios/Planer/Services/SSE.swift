import Foundation

struct SSEEvent: Equatable {
    var event: String
    var data: String
}

struct SSEParser {
    private var event = "message"
    private var dataLines: [String] = []

    mutating func feed(line rawLine: String) -> SSEEvent? {
        let line = rawLine.hasSuffix("\r") ? String(rawLine.dropLast()) : rawLine
        if line.isEmpty { return flush() }
        if line.hasPrefix(":") { return nil }
        let field: Substring
        var value: Substring
        if let colon = line.firstIndex(of: ":") {
            field = line[..<colon]
            value = line[line.index(after: colon)...]
            if value.hasPrefix(" ") { value = value.dropFirst() }
        } else {
            field = Substring(line)
            value = ""
        }
        switch field {
        case "event": event = String(value)
        case "data": dataLines.append(String(value))
        default: break
        }
        return nil
    }

    // drop a truncated event at the end
    mutating func flush(requireValidJSON: Bool = false) -> SSEEvent? {
        defer {
            event = "message"
            dataLines = []
        }
        guard !dataLines.isEmpty else { return nil }
        let data = dataLines.joined(separator: "\n")
        if requireValidJSON, (try? JSONSerialization.jsonObject(with: Data(data.utf8), options: [.fragmentsAllowed])) == nil {
            return nil
        }
        return SSEEvent(event: event, data: data)
    }
}

// not bytes.lines, it swallows empty lines
struct SSEEventSequence<Base: AsyncSequence>: AsyncSequence where Base.Element == UInt8 {
    typealias Element = SSEEvent
    let base: Base

    struct AsyncIterator: AsyncIteratorProtocol {
        var bytes: Base.AsyncIterator
        var parser = SSEParser()
        var line: [UInt8] = []
        var ended = false

        mutating func next() async throws -> SSEEvent? {
            while !ended {
                guard let byte = try await bytes.next() else {
                    ended = true
                    if !line.isEmpty {
                        _ = parser.feed(line: String(decoding: line, as: UTF8.self))
                        line.removeAll()
                    }
                    return parser.flush(requireValidJSON: true)
                }
                if byte == 0x0A {
                    let text = String(decoding: line, as: UTF8.self)
                    line.removeAll(keepingCapacity: true)
                    if let event = parser.feed(line: text) { return event }
                } else {
                    line.append(byte)
                }
            }
            return nil
        }
    }

    func makeAsyncIterator() -> AsyncIterator { AsyncIterator(bytes: base.makeAsyncIterator()) }
}
