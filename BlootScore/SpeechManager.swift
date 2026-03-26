import Speech
import AVFoundation

class SpeechManager: NSObject, ObservableObject {

    @Published var isListening  = false
    @Published var transcript   = ""
    @Published var authOK       = false

    /// يتفعّل لما المستخدم يسكت ويوقف التسجيل تلقائي — يحمل النص النهائي
    @Published var autoStoppedText: String?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ar-SA"))
    private var request:   SFSpeechAudioBufferRecognitionRequest?
    private var task:      SFSpeechRecognitionTask?
    private let engine     = AVAudioEngine()
    private var silenceTimer: Timer?
    private let silenceDelay: TimeInterval = 2.0  // ثانيتين سكوت = وقف تلقائي

    override init() {
        super.init()
        requestPermissions()
    }

    // MARK: - Permissions
    private func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                guard status == .authorized else { return }
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    DispatchQueue.main.async { self?.authOK = granted }
                }
            }
        }
    }

    // MARK: - Start
    func start() {
        guard authOK, !(recognizer?.isAvailable == false) else { return }
        transcript = ""
        autoStoppedText = nil

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            request = SFSpeechAudioBufferRecognitionRequest()
            request?.shouldReportPartialResults = true

            let node = engine.inputNode
            let fmt  = node.outputFormat(forBus: 0)
            node.installTap(onBus: 0, bufferSize: 1024, format: fmt) { [weak self] buf, _ in
                self?.request?.append(buf)
            }

            engine.prepare()
            try engine.start()

            task = recognizer?.recognitionTask(with: request!) { [weak self] result, _ in
                guard let self = self else { return }
                if let r = result {
                    DispatchQueue.main.async {
                        self.transcript = r.bestTranscription.formattedString
                        self.resetSilenceTimer()
                    }
                }
            }

            DispatchQueue.main.async { self.isListening = true }
        } catch {
            print("SpeechManager start error: \(error)")
        }
    }

    // MARK: - Silence Detection
    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        guard isListening, !transcript.isEmpty else { return }
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceDelay, repeats: false) { [weak self] _ in
            guard let self = self, self.isListening else { return }
            let finalText = self.stop()
            DispatchQueue.main.async {
                self.autoStoppedText = finalText
            }
        }
    }

    // MARK: - Stop → returns final transcript
    func stop() -> String {
        silenceTimer?.invalidate()
        silenceTimer = nil

        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task    = nil

        let result = transcript
        DispatchQueue.main.async {
            self.isListening = false
            self.transcript  = ""
        }
        return result
    }
}
