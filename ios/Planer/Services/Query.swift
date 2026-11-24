import Foundation

enum Query {
    // + as %2B, otherwise the backend turns it into a space
    static func string(_ items: [(String, String)]) -> String {
        guard !items.isEmpty else { return "" }
        var components = URLComponents()
        components.queryItems = items.map { URLQueryItem(name: $0.0, value: $0.1) }
        let encoded = (components.percentEncodedQuery ?? "").replacingOccurrences(of: "+", with: "%2B")
        return "?" + encoded
    }
}
