import Foundation
import AVFoundation
import Combine

// MARK: - Game States
enum VoiceState: String, CaseIterable, Identifiable {
    case kaboot          // كبوت
    case doubleWin       // دبل فوز          -> double_win
    case doubleLoss      // دبل خسارة        -> double_loss
    case buyerLost       // المشتري خسر
    case buyerWon        // المشتري كسب
    case tieBuyerLost    // تعادل في الدبل   -> tie_buyer_lost
    case nearWin         // اقتراب من الفوز  -> near_win
    case finalWin        // فوز نهائي        -> final_win
    case bigGap          // فرق كبير         -> big_gap
    case declaration     // إعلان
    case gameStart       // بداية لعبة       -> game_start
    case barber          // الحلاق (0 مقابل 152)

    var id: String { key }

    var key: String {
        switch self {
        case .kaboot:       return "kaboot"
        case .doubleWin:    return "double_win"
        case .doubleLoss:   return "double_loss"
        case .buyerLost:    return "buyer_lost"
        case .buyerWon:     return "buyer_won"
        case .tieBuyerLost: return "tie_buyer_lost"
        case .nearWin:      return "near_win"
        case .finalWin:     return "final_win"
        case .bigGap:       return "big_gap"
        case .declaration:  return "declaration"
        case .gameStart:    return "game_start"
        case .barber:       return "barber"
        }
    }

    var title: String {
        switch self {
        case .kaboot:       return "كبوت"
        case .doubleWin:    return "دبل — فوز"
        case .doubleLoss:   return "دبل — خسارة"
        case .buyerLost:    return "المشتري خسر"
        case .buyerWon:     return "المشتري كسب"
        case .tieBuyerLost: return "تعادل في الدبل"
        case .nearWin:      return "اقتراب من الفوز (140+)"
        case .finalWin:     return "فوز نهائي"
        case .bigGap:       return "فرق كبير (50+)"
        case .declaration:  return "إعلان (بلوت/سرا/مية)"
        case .gameStart:    return "بداية لعبة جديدة"
        case .barber:       return "الحلاق (0 مقابل 152)"
        }
    }
}

// MARK: - Voice Clip Model
struct VoiceClip {
    var enabled: Bool
    var hasAudio: Bool
    var updatedAt: Date?
}

// MARK: - VoiceStore
@MainActor
final class VoiceStore: ObservableObject {
    static let shared = VoiceStore()

    // config/admin
    @Published private(set) var adminUID: String?
    // metadata (بدون base64 الصوت — يتحمّل عند الحاجة)
    @Published private(set) var clips: [String: VoiceClip] = [:]
    @Published private(set) var isLoading = false
    @Published var lastError: String?

    private let fb = FirebaseREST.shared
    private var player: AVAudioPlayer?
    private var cache: [String: Data] = [:] // key -> decoded m4a

    private init() {}

    // MARK: Paths
    private var adminPath: String { "bloot_config/admin" }
    private func voicePath(_ key: String) -> String { "bloot_voices/\(key)" }

    var isAdmin: Bool {
        guard let adminUID, let myUID = fb.uid else { return false }
        return adminUID == myUID && !adminUID.isEmpty
    }

    var adminNotClaimed: Bool { (adminUID ?? "").isEmpty }

    // MARK: Load all
    func loadAll() async {
        isLoading = true
        defer { isLoading = false }
        await loadAdmin()
        await loadClipsMetadata()
    }

    private func loadAdmin() async {
        do {
            let fields = try await fb.getDoc(adminPath)
            adminUID = fields?["adminUID"]?.stringValue ?? ""
        } catch {
            lastError = "تعذّر جلب إعدادات الأدمن: \(error.localizedDescription)"
        }
    }

    private func loadClipsMetadata() async {
        var dict: [String: VoiceClip] = [:]
        for state in VoiceState.allCases {
            do {
                if let fields = try await fb.getDoc(voicePath(state.key)) {
                    let enabled  = fields["enabled"]?.boolValue ?? true
                    let hasAudio = (fields["audioBase64"]?.stringValue?.isEmpty == false)
                    var updated: Date? = nil
                    if case .timestamp(let d) = fields["updatedAt"] ?? .null { updated = d }
                    dict[state.key] = VoiceClip(enabled: enabled, hasAudio: hasAudio, updatedAt: updated)
                } else {
                    dict[state.key] = VoiceClip(enabled: true, hasAudio: false, updatedAt: nil)
                }
            } catch {
                dict[state.key] = VoiceClip(enabled: true, hasAudio: false, updatedAt: nil)
            }
        }
        clips = dict
    }

    // MARK: Admin claim (first run)
    func claimAdmin() async throws {
        guard let myUID = fb.uid else { throw FBError.notAuthed }
        try await fb.setDoc(adminPath, fields: ["adminUID": .string(myUID)])
        adminUID = myUID
    }

    // MARK: Mutations (admin only by rules)
    func setEnabled(_ state: VoiceState, _ enabled: Bool) async throws {
        try await fb.setDoc(voicePath(state.key), fields: ["enabled": .bool(enabled)])
        var c = clips[state.key] ?? VoiceClip(enabled: enabled, hasAudio: false, updatedAt: nil)
        c.enabled = enabled
        clips[state.key] = c
    }

    func uploadVoice(_ state: VoiceState, fileURL: URL) async throws {
        guard let b64 = VoiceRecorder.base64(url: fileURL) else {
            throw NSError(domain: "VoiceStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "الملف أكبر من 700KB — سجّل مقطع أقصر."])
        }
        try await fb.setDoc(voicePath(state.key), fields: [
            "enabled":     .bool(clips[state.key]?.enabled ?? true),
            "audioBase64": .string(b64),
            "format":      .string("m4a"),
            "updatedAt":   .timestamp(Date()),
        ])
        if let data = Data(base64Encoded: b64) { cache[state.key] = data }
        var c = clips[state.key] ?? VoiceClip(enabled: true, hasAudio: true, updatedAt: Date())
        c.hasAudio = true
        c.updatedAt = Date()
        clips[state.key] = c
    }

    func deleteVoice(_ state: VoiceState) async throws {
        // نحتفظ بالتوثيق (enabled) ونحذف الصوت فقط بإفراغه
        try await fb.setDoc(voicePath(state.key), fields: [
            "audioBase64": .string(""),
            "updatedAt":   .timestamp(Date()),
        ])
        cache[state.key] = nil
        var c = clips[state.key] ?? VoiceClip(enabled: true, hasAudio: false, updatedAt: Date())
        c.hasAudio = false
        c.updatedAt = Date()
        clips[state.key] = c
    }

    // MARK: Playback
    /// يشغّل الصوت إذا كانت الحالة مفعّلة وفيه ملف.
    func play(_ state: VoiceState) {
        guard clips[state.key]?.enabled == true else { return }
        Task { await playAsync(state) }
    }

    private func playAsync(_ state: VoiceState) async {
        do {
            if cache[state.key] == nil {
                guard let fields = try await fb.getDoc(voicePath(state.key)),
                      let b64 = fields["audioBase64"]?.stringValue,
                      !b64.isEmpty,
                      let data = Data(base64Encoded: b64) else { return }
                cache[state.key] = data
            }
            guard let data = cache[state.key] else { return }
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(data: data)
            player?.prepareToPlay()
            player?.play()
        } catch {
            print("⚠️ play failed for \(state.key): \(error)")
        }
    }

    /// تشغيل معاينة من ملف محلي (قبل الرفع)
    func previewLocal(url: URL) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            player?.play()
        } catch {
            lastError = "فشل تشغيل المعاينة: \(error.localizedDescription)"
        }
    }
}

// MARK: - Game state detection helper
extension VoiceStore {
    /// يرجّع أعلى حالة مناسبة لنتيجة الجولة الأخيرة + المجاميع الحالية
    static func detect(round: Round, team1Total: Int, team2Total: Int, winningScore: Int) -> VoiceState? {
        // 1) فوز نهائي — حلاق إذا الخصم صفر
        if team1Total >= winningScore || team2Total >= winningScore {
            if team1Total == 0 || team2Total == 0 { return .barber }
            return .finalWin
        }
        // 2) كبوت
        if round.isKaboot { return .kaboot }
        // 3) دبل
        if round.isDobble {
            if round.buyerWon { return .doubleWin }
            // تعادل أم خسارة صريحة؟ عندنا مجرد buyerWon=false، فنعتبرها خسارة دبل
            return .doubleLoss
        }
        // 4) اقتراب من الفوز
        if team1Total >= 140 || team2Total >= 140 { return .nearWin }
        // 5) فرق كبير
        if abs(team1Total - team2Total) >= 50 { return .bigGap }
        // 6) فوز/خسارة المشتري العاديّة
        return round.buyerWon ? .buyerWon : .buyerLost
    }
}
