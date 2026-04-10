import Foundation
import AVFoundation

@MainActor
final class VoiceRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published private(set) var isRecording = false
    @Published private(set) var lastURL: URL?
    @Published var errorMessage: String?

    private var recorder: AVAudioRecorder?

    private let settings: [String: Any] = [
        AVFormatIDKey:            Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey:          22050.0,
        AVNumberOfChannelsKey:    1,
        AVEncoderBitRateKey:      32000,
        AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
    ]

    // MARK: Start
    func start() {
        errorMessage = nil
        guard !isRecording else { return }

        Task { @MainActor in
            let ok = await Self.requestMicPermission()
            guard ok else {
                errorMessage = "الميكروفون غير مسموح. فعّله من إعدادات الآيفون → BlootScore."
                return
            }
            doStart()
        }
    }

    private static func requestMicPermission() async -> Bool {
        let s = AVAudioSession.sharedInstance()
        switch s.recordPermission {
        case .granted:      return true
        case .denied:       return false
        case .undetermined:
            return await withCheckedContinuation { cont in
                s.requestRecordPermission { cont.resume(returning: $0) }
            }
        @unknown default:   return false
        }
    }

    private func doStart() {
        do {
            let s = AVAudioSession.sharedInstance()
            try s.setCategory(.playAndRecord,
                              mode: .default,
                              options: [.defaultToSpeaker, .allowBluetooth])
            try s.setActive(true, options: .notifyOthersOnDeactivation)

            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("voice_\(Int(Date().timeIntervalSince1970 * 1000)).m4a")
            // احذف لو فيه ملف قديم بنفس الاسم
            try? FileManager.default.removeItem(at: url)

            let r = try AVAudioRecorder(url: url, settings: settings)
            r.delegate = self
            guard r.prepareToRecord() else {
                errorMessage = "تعذّر تجهيز الميكروفون."
                return
            }
            guard r.record() else {
                errorMessage = "تعذّر بدء التسجيل."
                return
            }

            self.recorder    = r
            self.lastURL     = url
            self.isRecording = true
        } catch {
            errorMessage = "تعذّر بدء التسجيل: \(error.localizedDescription)"
        }
    }

    // MARK: Stop
    @discardableResult
    func stop() -> URL? {
        guard let r = recorder else { return nil }
        r.stop()                    // يفرغ الملف على القرص فوراً
        isRecording = false
        let url = lastURL
        self.recorder = nil

        // نتحقق أن الملف موجود وحجمه > 0
        guard let url,
              let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = (attrs[.size] as? NSNumber)?.intValue,
              size > 0 else {
            errorMessage = "الملف فارغ — تأكد من الميكروفون."
            return nil
        }
        print("🎤 recorded \(size) bytes → \(url.lastPathComponent)")
        return url
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            self.isRecording = false
            if !flag { self.errorMessage = "التسجيل فشل" }
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            self.errorMessage = "خطأ في الترميز: \(error?.localizedDescription ?? "?")"
            self.isRecording = false
        }
    }

    // MARK: Helpers
    static func base64(url: URL, maxBytes: Int = 700_000) -> String? {
        guard let data = try? Data(contentsOf: url), data.count > 0 else { return nil }
        guard data.count <= maxBytes else { return nil }
        return data.base64EncodedString()
    }
}
