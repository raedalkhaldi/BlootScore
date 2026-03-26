import Foundation

struct SimpleRoundResult {
    var gameType:     GameType?
    var buyerIsTeam1: Bool?
    var t1Score:      Int?
    var t2Score:      Int?
    var isKaboot:     Bool = false
    var isDobble:     Bool = false
}

enum LocalVoiceParser {

    static func parse(text: String, team1Name: String = "نحن", team2Name: String = "هم") -> SimpleRoundResult {
        let t = normalize(text)
        print("🎙️ normalized: \(t)")
        var r = SimpleRoundResult()

        // نوع اللعبة
        if t.contains("صن") || t.contains("سن") { r.gameType = .sun }
        else if t.contains("حكم") { r.gameType = .hokm }

        // كبوت / دبل
        if t.contains("كبوت") || t.contains("كنس") { r.isKaboot = true }
        if t.contains("دبل") || t.contains("دوبل") { r.isDobble = true }

        // استخرج كل الأرقام الرقمية بالترتيب
        let nums = extractDigits(from: t)
        print("🎙️ digits: \(nums)")
        if nums.count >= 1 { r.t1Score = nums[0] }
        if nums.count >= 2 { r.t2Score = nums[1] }

        return r
    }

    // تحويل الأرقام العربية-الهندية إلى غربية
    private static func normalize(_ text: String) -> String {
        let map: [Character: Character] = [
            "\u{0660}": "0", "\u{0661}": "1", "\u{0662}": "2", "\u{0663}": "3",
            "\u{0664}": "4", "\u{0665}": "5", "\u{0666}": "6", "\u{0667}": "7",
            "\u{0668}": "8", "\u{0669}": "9"
        ]
        return String(text.map { map[$0] ?? $0 })
    }

    // استخرج كل مجموعات الأرقام بترتيبها في النص
    private static func extractDigits(from text: String) -> [Int] {
        guard let regex = try? NSRegularExpression(pattern: "\\d+") else { return [] }
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        return matches.compactMap { m in
            guard let range = Range(m.range, in: text) else { return nil }
            return Int(text[range])
        }
    }
}
