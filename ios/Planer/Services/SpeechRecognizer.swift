import AVFoundation
import Observation
import Speech

@MainActor
@Observable
final class SpeechRecognizer {
    static let maxDuration: TimeInterval = 60
    private static let serverNoticeKey = "speech.serverNoticeShown"

    private(set) var isRecording = false
    var message: String?
    private(set) var needsSettings = false

    @ObservationIgnored private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "de-DE"))
    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?
    @ObservationIgnored private var timeout: Task<Void, Never>?
    @ObservationIgnored private var base = ""
    @ObservationIgnored private var onText: ((String) -> Void)?
    // ignore stale recognitions
    @ObservationIgnored private var sessionNumber = 0

    static func merge(base: String, transcript: String) -> String {
        let trimmedBase = base.trimmingCharacters(in: .whitespaces)
        if trimmedBase.isEmpty { return transcript }
        if transcript.isEmpty { return base }
        return trimmedBase + " " + transcript
    }

    func start(base: String, onText: @escaping (String) -> Void) async {
        guard !isRecording else { return }
        message = nil
        needsSettings = false
        guard await Self.requestPermissions() else {
            message = "Mikrofon oder Spracherkennung ist nicht erlaubt. Du kannst das in den iOS-Einstellungen ändern."
            needsSettings = true
            return
        }
        guard let recognizer, recognizer.isAvailable else {
            message = "Die Spracherkennung ist gerade nicht verfügbar."
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        } else if !UserDefaults.standard.bool(forKey: Self.serverNoticeKey) {
            UserDefaults.standard.set(true, forKey: Self.serverNoticeKey)
            message = "Hinweis: Auf diesem iPhone läuft die Spracherkennung über Apple-Server."
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            try Self.installTap(on: engine.inputNode, request: request)
            engine.prepare()
            try engine.start()
        } catch {
            engine.inputNode.removeTap(onBus: 0)
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            message = "Die Aufnahme konnte nicht starten."
            return
        }

        self.base = base
        self.onText = onText
        self.request = request
        isRecording = true
        sessionNumber += 1
        let current = sessionNumber
        task?.cancel() // old recognition might still be running
        task = Self.startTask(recognizer: recognizer, request: request) { [weak self] text, ended in
            Task { @MainActor in self?.handle(text: text, ended: ended, session: current) }
        }
        timeout = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.maxDuration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.stop()
        }
    }

    func stop() {
        guard isRecording else { return }
        isRecording = false
        timeout?.cancel()
        timeout = nil
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio() // final result still arrives via handle
        request = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func cancel() {
        stop()
        task?.cancel()
        task = nil
        onText = nil
    }

    private func handle(text: String?, ended: Bool, session: Int) {
        guard session == sessionNumber else { return }
        if let text { onText?(Self.merge(base: base, transcript: text)) }
        if ended {
            stop()
            task = nil
            onText = nil
        }
    }

    // nonisolated on purpose, audio tap + recognizer call back on their own threads
    nonisolated private static func installTap(on input: AVAudioInputNode, request: SFSpeechAudioBufferRecognitionRequest) throws {
        let format = input.outputFormat(forBus: 0)
        // no input (phone call) means empty format, installTap crashes then
        guard format.sampleRate > 0, format.channelCount > 0 else { throw URLError(.cannotOpenFile) }
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
    }

    nonisolated private static func startTask(
        recognizer: SFSpeechRecognizer,
        request: SFSpeechAudioBufferRecognitionRequest,
        handler: @escaping @Sendable (String?, Bool) -> Void
    ) -> SFSpeechRecognitionTask {
        recognizer.recognitionTask(with: request) { result, error in
            handler(result?.bestTranscription.formattedString, error != nil || (result?.isFinal ?? false))
        }
    }

    nonisolated private static func requestPermissions() async -> Bool {
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
        }
        guard speech else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }
}
