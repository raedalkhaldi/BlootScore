import Foundation
import AVFoundation
import Combine

// MARK: - Game States
enum VoiceState: String, CaseIterable, Identifiable {
    case kaboot
    case doubleWin
    case doubleLoss
    case buyerLost
    case buyerWon
    case tieBuyerLost
    case nearWin
    case finalWin
    case bigGap
    case declaration
    case gameStart
    case barber

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

// MARK: - Source of a clip
enum VoiceSource {
    case custom      // المستخدم سجّل نسخته المحلية
    case defaultAdmin // الافتراضي اللي رفعه الأدمن على Firestore
    case none         // ما فيه صوت
}

// MARK: - Default metadata from Firestore
struct DefaultClip {
    var enabled: Bool
    var hasAudio: Bool
}

// MARK: - VoiceStore
@MainActor
final class VoiceStore: ObservableObject {
    static let shared = VoiceStore()

    // Admin state (Firestore)
    @Published private(set) var adminUID: String?
    @Published private(set) var defaults: [String: DefaultClip] = [:]

    // User local overrides
    @Published private(set) var localFiles: [String: URL] = [:]   // state -> m4a file in Documents/voices/overrides
    @Published private(set) var localEnabled: [String: Bool] = [:] // state -> enabled override

    // UI state
    @Published private(set) var isLoading = false
    @Published var lastError: String?

    private let fb = FirebaseREST.shared
    private var player: AVAudioPlayer?
    private var defaultFileCache: [String: URL] = [:] // cached Firestore defaults on disk

    private init() {
        loadLocalOverrides()
    }

    // MARK: Paths
    private var adminPath: String { "bloot_config/admin" }
    private func voicePath(_ key: String) -> String { "bloot_voices/\(key)" }

    private var docsDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    private var overridesDir: URL {
        let u = docsDir.appendingPathComponent("voices/overrides", isDirectory: true)
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }
    private var defaultsCacheDir: URL {
        let u = docsDir.appendingPathComponent("voices/defaults_cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }

    // MARK: Admin check
    var isAdmin: Bool {
        guard let adminUID, let myUID = fb.uid, !adminUID.isEmpty else { return false }
        return adminUID == myUID
    }
    var adminNotClaimed: Bool { (adminUID ?? "").isEmpty }

    // MARK: Effective accessors
    func source(_ state: VoiceState) -> VoiceSource {
        if localFiles[state.key] != nil { return .custom }
        if defaults[state.key]?.hasAudio == true { return .defaultAdmin }
        return .none
    }

    func effectiveEnabled(_ state: VoiceState) -> Bool {
        localEnabled[state.key] ?? defaults[state.key]?.enabled ?? true
    }

    func hasAnyAudio(_ state: VoiceState) -> Bool {
        source(state) != .none
    }

    func hasLocalOverride(_ state: VoiceState) -> Bool {
        localFiles[state.key] != nil
    }

    // MARK: Loaders
    func loadAll() async {
        loadLocalOverrides()
        await loadDefaults()
    }

    private func loadLocalOverrides() {
        var files: [String: URL] = [:]
        for s in VoiceState.allCases {
            let url = overridesDir.appendingPathComponent("\(s.key).m4a")
            if FileManager.default.fileExists(atPath: url.path) {
                files[s.key] = url
            }
        }
        localFiles = files

        var enabled: [String: Bool] = [:]
        for s in VoiceState.allCases {
            let k = "voiceEnabled_\(s.key)"
            if let v = UserDefaults.standard.object(forKey: k) as? Bool {
                enabled[s.key] = v
            }
        }
        localEnabled = enabled
    }

    private func loadDefaults() async {
        isLoading = true
        defer { isLoading = false }
        await loadAdmin()
        var dict: [String: DefaultClip] = [:]
        for state in VoiceState.allCases {
            do {
                if let fields = try await fb.getDoc(voicePath(state.key)) {
                    let enabled  = fields["enabled"]?.boolValue ?? true
                    let hasAudio = (fields["audioBase64"]?.stringValue?.isEmpty == false)
                    dict[state.key] = DefaultClip(enabled: enabled, hasAudio: hasAudio)
                } else {
                    dict[state.key] = DefaultClip(enabled: true, hasAudio: false)
                }
            } catch {
                dict[state.key] = DefaultClip(enabled: true, hasAudio: false)
            }
        }
        defaults = dict
    }

    private func loadAdmin() async {
        do {
            let fields = try await fb.getDoc(adminPath)
            adminUID = fields?["adminUID"]?.stringValue ?? ""
        } catch {
            adminUID = ""
        }
    }

    // MARK: Local override mutations (all users)
    /// ينسخ/ينقل ملف التسجيل إلى مجلد الـ overrides ويسجّله كنسخة مخصّصة.
    func saveLocalOverride(_ state: VoiceState, from tempURL: URL) throws {
        let dest = overridesDir.appendingPathComponent("\(state.key).m4a")
        // Validate size first
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: tempURL.path),
              let size = (attrs[.size] as? NSNumber)?.intValue, size > 0 else {
            throw NSError(domain: "VoiceStore", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "الملف فارغ"])
        }
        guard size <= 2_000_000 else {
            throw NSError(domain: "VoiceStore", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "الملف أكبر من 2MB"])
        }
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.copyItem(at: tempURL, to: dest)
        localFiles[state.key] = dest
    }

    /// يحذف نسخة المستخدم المحلية فيرجع السلوك للصوت الافتراضي (الأدمن).
    func restoreDefault(_ state: VoiceState) {
        if let url = localFiles[state.key] {
            try? FileManager.default.removeItem(at: url)
        }
        localFiles[state.key] = nil
        // ونشيل tweak التفعيل المحلي عشان يتبع إعداد الأدمن
        localEnabled[state.key] = nil
        UserDefaults.standard.removeObject(forKey: "voiceEnabled_\(state.key)")
    }

    /// يعدّل حالة التفعيل (محلياً فقط).
    func setLocalEnabled(_ state: VoiceState, _ enabled: Bool) {
        localEnabled[state.key] = enabled
        UserDefaults.standard.set(enabled, forKey: "voiceEnabled_\(state.key)")
    }

    // MARK: Admin claim
    func claimAdmin() async throws {
        guard let myUID = fb.uid else { throw FBError.notAuthed }
        try await fb.setDoc(adminPath, fields: ["adminUID": .string(myUID)])
        adminUID = myUID
    }

    // MARK: Admin-only: upload a voice as the global default
    func uploadAsDefault(_ state: VoiceState, fileURL: URL) async throws {
        guard let b64 = VoiceRecorder.base64(url: fileURL) else {
            throw NSError(domain: "VoiceStore", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "الملف أكبر من 700KB — سجّل مقطع أقصر."])
        }
        try await fb.setDoc(voicePath(state.key), fields: [
            "enabled":     .bool(defaults[state.key]?.enabled ?? true),
            "audioBase64": .string(b64),
            "format":      .string("m4a"),
            "updatedAt":   .timestamp(Date()),
        ])
        // حدّث النسخة في الذاكرة
        var d = defaults[state.key] ?? DefaultClip(enabled: true, hasAudio: true)
        d.hasAudio = true
        defaults[state.key] = d
        // أبطل الكاش عشان يتحمل الجديد عند التشغيل
        defaultFileCache[state.key] = nil
        let cached = defaultsCacheDir.appendingPathComponent("\(state.key).m4a")
        try? FileManager.default.removeItem(at: cached)
    }

    /// Admin-only: ضبط التفعيل الافتراضي
    func setDefaultEnabled(_ state: VoiceState, _ enabled: Bool) async throws {
        try await fb.setDoc(voicePath(state.key), fields: ["enabled": .bool(enabled)])
        var d = defaults[state.key] ?? DefaultClip(enabled: enabled, hasAudio: false)
        d.enabled = enabled
        defaults[state.key] = d
    }

    // MARK: Playback
    func play(_ state: VoiceState) {
        guard effectiveEnabled(state) else { return }
        Task { await playAsync(state) }
    }

    private func playAsync(_ state: VoiceState) async {
        var fileURL: URL? = nil
        if let local = localFiles[state.key] {
            fileURL = local
        } else if defaults[state.key]?.hasAudio == true {
            // نحاول من الكاش، وإلا نحمّله من Firestore
            if let cached = defaultFileCache[state.key],
               FileManager.default.fileExists(atPath: cached.path) {
                fileURL = cached
            } else {
                fileURL = try? await fetchDefaultAudio(state)
            }
        }
        guard let url = fileURL else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            player?.play()
        } catch {
            print("⚠️ play failed for \(state.key): \(error)")
        }
    }

    private func fetchDefaultAudio(_ state: VoiceState) async throws -> URL? {
        guard let fields = try await fb.getDoc(voicePath(state.key)),
              let b64 = fields["audioBase64"]?.stringValue,
              !b64.isEmpty,
              let data = Data(base64Encoded: b64) else { return nil }
        let dest = defaultsCacheDir.appendingPathComponent("\(state.key).m4a")
        try data.write(to: dest, options: .atomic)
        defaultFileCache[state.key] = dest
        return dest
    }

    /// معاينة من ملف أيّ URL (محلي مؤقت قبل الحفظ)
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
    static func detect(round: Round, team1Total: Int, team2Total: Int, winningScore: Int) -> VoiceState? {
        if team1Total >= winningScore || team2Total >= winningScore {
            if team1Total == 0 || team2Total == 0 { return .barber }
            return .finalWin
        }
        if round.isKaboot { return .kaboot }
        if round.isDobble {
            if round.buyerWon { return .doubleWin }
            return .doubleLoss
        }
        if team1Total >= 140 || team2Total >= 140 { return .nearWin }
        if abs(team1Total - team2Total) >= 50 { return .bigGap }
        return round.buyerWon ? .buyerWon : .buyerLost
    }
}
