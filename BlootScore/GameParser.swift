import Foundation

// MARK: - Parsed Result
struct ParsedRound {
    var gameType:     GameType?
    var buyerIsTeam1: Bool?
    var buyerRaw:     Int?
    var isKaboot:     Bool         = false
    var isDobble:     Bool         = false
    var team1Dec:     Declarations = Declarations()
    var team2Dec:     Declarations = Declarations()
}

// MARK: - JSON Models
private struct DecJSON: Codable {
    var sara:        Int = 0
    var fifty:       Int = 0
    var hundred:     Int = 0
    var fourHundred: Int = 0
    var bloot:       Int = 0
}

private struct RoundJSON: Codable {
    var gameType:          String?
    var buyerIsTeam1:      Bool?
    var buyerRaw:          Int?
    var isKaboot:          Bool?
    var isDobble:          Bool?
    var team1Declarations: DecJSON?
    var team2Declarations: DecJSON?
}

// MARK: - Built-in API Key (obfuscated)
private let _k: [UInt8] = [0xd8, 0xc0, 0x86, 0xca, 0xc5, 0xdf, 0x86, 0xca, 0xdb, 0xc2, 0x9b, 0x98, 0x86, 0xfc, 0xc0, 0xfe, 0xc9, 0xd1, 0xdd, 0xd9, 0xe2, 0xea, 0xfe, 0xfd, 0xea, 0xfe, 0xf8, 0xc7, 0xfc, 0xe9, 0xed, 0x86, 0x93, 0xf8, 0xfb, 0xf1, 0xec, 0xc3, 0xdd, 0xef, 0xc4, 0x9e, 0x9b, 0xcc, 0xd1, 0xf3, 0xf2, 0xe2, 0xf1, 0xed, 0xe2, 0x9d, 0xf2, 0x92, 0xe5, 0x99, 0xe8, 0xec, 0x9b, 0xe7, 0xfc, 0x9b, 0xed, 0xe2, 0xd1, 0x86, 0xe3, 0xe2, 0xf4, 0xdf, 0xe0, 0xe0, 0xc5, 0xe3, 0xd3, 0x9e, 0xd3, 0x99, 0x9b, 0xc2, 0xcc, 0xd3, 0xe5, 0x98, 0xc8, 0x99, 0xc8, 0xf2, 0x9d, 0xc7, 0xcf, 0xfb, 0xf3, 0x86, 0xcd, 0xd9, 0xf9, 0xf9, 0xcc, 0x86, 0xc5, 0x9e, 0xd9, 0x9e, 0xe0, 0xdc, 0xea, 0xea]
let kBuiltInAPIKey: String = String(_k.map { Character(UnicodeScalar($0 ^ 0xAB)) })

// MARK: - Parser
enum GameParser {

    static func parse(
        text:      String,
        team1Name: String,
        team2Name: String,
        apiKey:    String
    ) async throws -> ParsedRound {

        let systemPrompt = """
        أنت مساعد لتسجيل نقاط لعبة البلوت الخليجية.
        استخرج معلومات الجولة من النص وأرجع JSON فقط بهذا الشكل:

        {
          "gameType": "sun" أو "hokm",
          "buyerIsTeam1": true إذا المشتري هو "\(team1Name)"، false إذا "\(team2Name)",
          "buyerRaw": نقاط أوراق الفريق المشتري (رقم فقط بدون مشاريع),
          "isKaboot": true أو false,
          "isDobble": true أو false,
          "team1Declarations": {"sara":0,"fifty":0,"hundred":0,"fourHundred":0,"bloot":0},
          "team2Declarations": {"sara":0,"fifty":0,"hundred":0,"fourHundred":0,"bloot":0}
        }

        قواعد:
        - sara = سرا أو سارة (عدد)
        - fifty = خمسين (عدد)
        - hundred = مية أو مئة (عدد)
        - fourHundred = أربع مية (صن فقط)
        - bloot = بلوت (حكم فقط)
        - كبوت/كنس/كنسوا = isKaboot:true (buyerRaw يصبح 0)
        - دبل = isDobble:true
        - الأرقام قد تكون عربية أو إنجليزية
        - أرجع JSON فقط بدون شرح
        """

        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 400,
            "system": systemPrompt,
            "messages": [["role": "user", "content": text]]
        ]

        guard let url      = URL(string: "https://api.anthropic.com/v1/messages"),
              let bodyData = try? JSONSerialization.data(withJSONObject: body)
        else { throw ParserError.invalidRequest }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json",    forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey,               forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01",         forHTTPHeaderField: "anthropic-version")
        req.httpBody = bodyData

        let (data, response) = try await URLSession.shared.data(for: req)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200
        else { throw ParserError.apiError }

        guard let outer   = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = (outer["content"] as? [[String: Any]])?.first,
              let text    = content["text"] as? String,
              let jsonStr = extractJSON(from: text),
              let jsonData = jsonStr.data(using: .utf8),
              let parsed  = try? JSONDecoder().decode(RoundJSON.self, from: jsonData)
        else { throw ParserError.parseFailed }

        return convert(parsed)
    }

    // MARK: - Simple mode (رقمين بس)
    static func parseSimple(
        text:   String,
        apiKey: String
    ) async throws -> (t1: Int, t2: Int) {

        let systemPrompt = """
        المستخدم يقول نتيجة جولة بلوت. استخرج رقمين فقط:
        - الرقم الأول = نقاط فريقه (نحن/لنا)
        - الرقم الثاني = نقاط الفريق الآخر (هم/لهم)
        أرجع JSON فقط: {"t1": الرقم_الأول, "t2": الرقم_الثاني}
        لو قال رقمين بدون تحديد، الأول لنا والثاني لهم.
        لو قال رقم واحد فقط، حطه t1 وخل t2 = 0.
        """

        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 50,
            "system": systemPrompt,
            "messages": [["role": "user", "content": text]]
        ]

        guard let url      = URL(string: "https://api.anthropic.com/v1/messages"),
              let bodyData = try? JSONSerialization.data(withJSONObject: body)
        else { throw ParserError.invalidRequest }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey,            forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01",      forHTTPHeaderField: "anthropic-version")
        req.httpBody = bodyData

        let (data, response) = try await URLSession.shared.data(for: req)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200
        else { throw ParserError.apiError }

        guard let outer   = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = (outer["content"] as? [[String: Any]])?.first,
              let text    = content["text"] as? String,
              let jsonStr = extractJSON(from: text),
              let jsonData = jsonStr.data(using: .utf8),
              let obj     = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
              let t1      = obj["t1"] as? Int,
              let t2      = obj["t2"] as? Int
        else { throw ParserError.parseFailed }

        return (t1, t2)
    }

    // MARK: - Helpers
    private static func extractJSON(from text: String) -> String? {
        // Claude might wrap JSON in ```json ... ```
        if let start = text.range(of: "{"),
           let end   = text.range(of: "}", options: .backwards) {
            return String(text[start.lowerBound...end.upperBound])
        }
        return nil
    }

    private static func convert(_ p: RoundJSON) -> ParsedRound {
        var r         = ParsedRound()
        r.gameType    = p.gameType == "sun" ? .sun : .hokm
        r.buyerIsTeam1 = p.buyerIsTeam1
        r.buyerRaw    = p.buyerRaw
        r.isKaboot    = p.isKaboot ?? false
        r.isDobble    = p.isDobble ?? false

        if let d = p.team1Declarations {
            r.team1Dec = Declarations(sara: d.sara, fifty: d.fifty,
                                      hundred: d.hundred, fourHundred: d.fourHundred, bloot: d.bloot)
        }
        if let d = p.team2Declarations {
            r.team2Dec = Declarations(sara: d.sara, fifty: d.fifty,
                                      hundred: d.hundred, fourHundred: d.fourHundred, bloot: d.bloot)
        }
        return r
    }

    enum ParserError: LocalizedError {
        case invalidRequest, apiError, parseFailed
        var errorDescription: String? {
            switch self {
            case .invalidRequest: return "طلب غير صحيح"
            case .apiError:       return "خطأ في الاتصال بالذكاء الاصطناعي"
            case .parseFailed:    return "تعذّر تحليل النص"
            }
        }
    }
}
