import Foundation
import Security

// نستخدم REST API مباشرة بدون Firebase SDK — أخف، أسرع بناء، صفر تبعيات
// المشروع مشترك مع FlickMatch، بس بيانات BlootScore تستخدم prefix "bloot_"

enum FirebaseConst {
    static let apiKey    = "AIzaSyAmH0x2ngMxVpLvrcB9F8DPdJMpdionv9M"
    static let projectId = "invlog-6088f"
}

enum FBError: Error, LocalizedError {
    case notAuthed
    case http(Int, String)
    case decode

    var errorDescription: String? {
        switch self {
        case .notAuthed:          return "لم يتم تسجيل الدخول"
        case .http(let c, let m): return "HTTP \(c): \(m)"
        case .decode:             return "فشل فك ترميز الاستجابة"
        }
    }
}

// MARK: - Firestore Value (REST wire format)
indirect enum FSValue: Codable {
    case string(String)
    case bool(Bool)
    case int(Int)
    case double(Double)
    case timestamp(Date)
    case null

    private enum K: String, CodingKey {
        case stringValue, booleanValue, integerValue, doubleValue, timestampValue, nullValue
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: K.self)
        switch self {
        case .string(let v):    try c.encode(v, forKey: .stringValue)
        case .bool(let v):      try c.encode(v, forKey: .booleanValue)
        case .int(let v):       try c.encode(String(v), forKey: .integerValue)
        case .double(let v):    try c.encode(v, forKey: .doubleValue)
        case .timestamp(let v):
            let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            try c.encode(f.string(from: v), forKey: .timestampValue)
        case .null:             try c.encodeNil(forKey: .nullValue)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: K.self)
        if let v = try? c.decode(String.self, forKey: .stringValue)  { self = .string(v); return }
        if let v = try? c.decode(Bool.self,   forKey: .booleanValue) { self = .bool(v);   return }
        if let v = try? c.decode(String.self, forKey: .integerValue), let n = Int(v) { self = .int(n); return }
        if let v = try? c.decode(Double.self, forKey: .doubleValue)  { self = .double(v); return }
        if let v = try? c.decode(String.self, forKey: .timestampValue) {
            let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            self = .timestamp(f.date(from: v) ?? Date()); return
        }
        self = .null
    }

    var stringValue: String? { if case .string(let v) = self { return v }; return nil }
    var boolValue:   Bool?   { if case .bool(let v)   = self { return v }; return nil }
    var intValue:    Int?    { if case .int(let v)    = self { return v }; return nil }
}

struct FSDocument: Codable {
    var fields: [String: FSValue]
}

// MARK: - FirebaseREST
@MainActor
final class FirebaseREST: ObservableObject {
    static let shared = FirebaseREST()

    @Published private(set) var uid: String?
    @Published private(set) var isReady = false
    @Published private(set) var lastError: String?

    private var idToken: String?
    private var tokenExpiry: Date = .distantPast
    private var refreshTokenStr: String?

    private let kcService = "com.bloot.BlootScore.firebase"
    private let kcAccount = "refreshToken"

    private init() {}

    // MARK: Bootstrap
    func start() async {
        if let stored = loadKeychain() {
            refreshTokenStr = stored
            do { try await refresh(); isReady = true; return }
            catch { /* fall through to new anon sign-up */ }
        }
        do {
            try await anonymousSignUp()
            isReady = true
        } catch {
            lastError = "\(error)"
            print("⚠️ Firebase sign-in failed: \(error)")
        }
    }

    // MARK: Auth REST
    private struct SignUpResp: Codable {
        let idToken: String
        let refreshToken: String
        let localId: String
        let expiresIn: String
    }

    private func anonymousSignUp() async throws {
        let url = URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=\(FirebaseConst.apiKey)")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = #"{"returnSecureToken":true}"#.data(using: .utf8)

        let (data, resp) = try await URLSession.shared.data(for: req)
        try check(resp, data)
        let r = try JSONDecoder().decode(SignUpResp.self, from: data)
        self.idToken = r.idToken
        self.refreshTokenStr = r.refreshToken
        self.uid = r.localId
        self.tokenExpiry = Date().addingTimeInterval(max(60, (Double(r.expiresIn) ?? 3600) - 60))
        saveKeychain(r.refreshToken)
    }

    private struct RefreshResp: Codable {
        let id_token: String
        let refresh_token: String
        let user_id: String
        let expires_in: String
    }

    private func refresh() async throws {
        guard let rt = refreshTokenStr else { throw FBError.notAuthed }
        let url = URL(string: "https://securetoken.googleapis.com/v1/token?key=\(FirebaseConst.apiKey)")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = "grant_type=refresh_token&refresh_token=\(rt)".data(using: .utf8)

        let (data, resp) = try await URLSession.shared.data(for: req)
        try check(resp, data)
        let r = try JSONDecoder().decode(RefreshResp.self, from: data)
        self.idToken = r.id_token
        self.refreshTokenStr = r.refresh_token
        self.uid = r.user_id
        self.tokenExpiry = Date().addingTimeInterval(max(60, (Double(r.expires_in) ?? 3600) - 60))
        saveKeychain(r.refresh_token)
    }

    private func ensureToken() async throws -> String {
        if let t = idToken, Date() < tokenExpiry { return t }
        try await refresh()
        guard let t = idToken else { throw FBError.notAuthed }
        return t
    }

    // MARK: Firestore REST
    private func docURL(_ path: String) -> URL {
        URL(string: "https://firestore.googleapis.com/v1/projects/\(FirebaseConst.projectId)/databases/(default)/documents/\(path)")!
    }

    /// Get a document. Returns nil if 404.
    func getDoc(_ path: String) async throws -> [String: FSValue]? {
        let token = try await ensureToken()
        var req = URLRequest(url: docURL(path))
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode == 404 { return nil }
        try check(resp, data)
        let doc = try JSONDecoder().decode(FSDocument.self, from: data)
        return doc.fields
    }

    /// Upsert a document (only the provided fields).
    func setDoc(_ path: String, fields: [String: FSValue]) async throws {
        let token = try await ensureToken()
        var comps = URLComponents(url: docURL(path), resolvingAgainstBaseURL: false)!
        comps.queryItems = fields.keys.map { URLQueryItem(name: "updateMask.fieldPaths", value: $0) }

        var req = URLRequest(url: comps.url!)
        req.httpMethod = "PATCH"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = FSDocument(fields: fields)
        req.httpBody = try JSONEncoder().encode(body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        try check(resp, data)
    }

    func deleteDoc(_ path: String) async throws {
        let token = try await ensureToken()
        var req = URLRequest(url: docURL(path))
        req.httpMethod = "DELETE"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await URLSession.shared.data(for: req)
        try check(resp, data)
    }

    private func check(_ resp: URLResponse, _ data: Data) throws {
        guard let http = resp as? HTTPURLResponse else { return }
        guard !(200..<300).contains(http.statusCode) else { return }
        let msg = String(data: data, encoding: .utf8) ?? ""
        throw FBError.http(http.statusCode, msg)
    }

    // MARK: Keychain (iCloud-synced so reinstall keeps the same UID)
    private func saveKeychain(_ token: String) {
        let data = token.data(using: .utf8)!
        let q: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrService as String:      kcService,
            kSecAttrAccount as String:      kcAccount,
            kSecAttrSynchronizable as String: kCFBooleanTrue!,
        ]
        SecItemDelete(q as CFDictionary)
        var add = q
        add[kSecValueData as String] = data
        SecItemAdd(add as CFDictionary, nil)
    }

    private func loadKeychain() -> String? {
        let q: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrService as String:      kcService,
            kSecAttrAccount as String:      kcAccount,
            kSecAttrSynchronizable as String: kCFBooleanTrue!,
            kSecReturnData as String:       true,
            kSecMatchLimit as String:       kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let s = String(data: data, encoding: .utf8) else { return nil }
        return s
    }
}
