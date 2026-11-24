import Testing
@testable import Planer

@MainActor
struct SpeechRecognizerTests {
    @Test func mergeAppendsTranscriptToExistingText() {
        #expect(SpeechRecognizer.merge(base: "", transcript: "Morgen Zahnarzt") == "Morgen Zahnarzt")
        #expect(SpeechRecognizer.merge(base: "Notiz:", transcript: "Rasen mähen") == "Notiz: Rasen mähen")
        #expect(SpeechRecognizer.merge(base: "Notiz: ", transcript: "") == "Notiz: ")
    }

    @Test func limitsAndIdleStop() {
        #expect(SpeechRecognizer.maxDuration == 60)
        let recognizer = SpeechRecognizer()
        recognizer.stop() // no-op without recording
        recognizer.cancel()
        #expect(!recognizer.isRecording)
    }
}
