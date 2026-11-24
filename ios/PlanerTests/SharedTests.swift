import Foundation
import Testing
@testable import Planer

@MainActor
struct SharedTests {
    @Test func markdownBulletsHeadingsAndInlineStyles() {
        let attributed = MarkdownText.attributed("# Ziele\n- **fett** und *kursiv*\n* zweiter Punkt")
        #expect(String(attributed.characters) == "Ziele\n• fett und kursiv\n• zweiter Punkt")
    }

    @Test func markdownFallsBackToPlainText() {
        #expect(String(MarkdownText.attributed("Kein [Link").characters).contains("Kein"))
    }

    @Test func errorMessageUsesGermanDescriptions() {
        #expect(errorMessage(APIError.accessDenied) == "Cloudflare Access hat die Anfrage abgelehnt – Service-Token prüfen.")
        #expect(errorMessage(APIError.http(status: 404, message: "Projekt nicht gefunden")) == "Projekt nicht gefunden")
    }
}
