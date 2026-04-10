import Foundation
import AVFoundation

@MainActor
final class VoiceRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published private(set) var isRecording = false
    @Published private(set) var lastURL: URL?
    @Published private(set) var errorMessage: String?

    private var recorder: AVAudioRecorder?

    // m4a بجودة منخفضة عشان الحجم يبقى أقل من 300KB حتى عند 15 ثانية
    private let settings: [String: Any] = [
        AVFormatIDKey:             Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey:           22050.0,
        AVNumberOfChannelsKey:     1,
        AVEncoderBitRateKey:       24000,
        AVEncoderAudioQualityKey:  AVAudioQuality.medium.rawValue,
    ]

    func start() {
        errorMessage = nil
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)

            let tmp = FileManager.default.temporaryDirectory
                .appendingPathComponent("voice_\(UUID().uuidString).m4a")
            let r = try AVAudioRecorder(url: tmp, settings: settings)
            r.delegate = self
            r.prepareToRecord()
            r.record(forDuration: 20)   // حد أقصى 20 ثانية

            self.recorder = r
            self.lastURL = tmp
            self.isRecording = true
        } catch {
            errorMessage = "تعذّر بدء التسجيل: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func stop() -> URL? {
        recorder?.stop()
        isRecording = false
        let url = lastURL
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return url
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            self.isRecording = false
        }
    }

    /// يقرأ الملف ويرجعه base64 إذا الحجم أقل من الحد المسموح (~700KB)
    static func base64(url: URL, maxBytes: Int = 700_000) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard data.count <= maxBytes else { return nil }
        return data.base64EncodedString()
    }
}
