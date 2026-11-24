import SwiftUI

struct MarkdownText: View {
    let text: String

    var body: some View {
        Text(Self.attributed(text))
            .textSelection(.enabled)
    }

    static func attributed(_ text: String) -> AttributedString {
        let prepared = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> String in
                let trimmed = line.drop(while: { $0 == " " })
                if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                    return "• " + trimmed.dropFirst(2)
                }
                if trimmed.hasPrefix("#") {
                    let heading = trimmed.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
                    return heading.isEmpty ? String(line) : "**\(heading)**"
                }
                return String(line)
            }
            .joined(separator: "\n")
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: prepared, options: options)) ?? AttributedString(text)
    }
}
