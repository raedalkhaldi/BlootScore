import Foundation
import SwiftUI

// MARK: - Game Type
enum GameType: String, CaseIterable {
    case sun  = "صن"
    case hokm = "حكم"

    var rawTotal: Int  { self == .sun ? 130 : 162 }
    var basePoints: Int { self == .sun ? 26  : 16  }
    var kabootBase: Int { self == .sun ? 44  : 25  }
}

// MARK: - Declarations
struct Declarations {
    var sara:        Int = 0   // سرا
    var fifty:       Int = 0   // خمسين
    var hundred:     Int = 0   // مية
    var fourHundred: Int = 0   // أربع مية (صن فقط)
    var bloot:       Int = 0   // بلوت   (حكم فقط)

    func total(for gt: GameType) -> Int {
        let s  = gt == .sun ? 4  : 2
        let f  = gt == .sun ? 10 : 5
        let h  = gt == .sun ? 20 : 10
        let fa = gt == .sun ? 40 : 0
        let b  = gt == .sun ? 0  : 2
        return sara*s + fifty*f + hundred*h + fourHundred*fa + bloot*b
    }

    mutating func reset() {
        sara = 0; fifty = 0; hundred = 0; fourHundred = 0; bloot = 0
    }
}

// MARK: - Round Result (preview)
struct RoundResult {
    var buyerCardPts: Int
    var otherCardPts: Int
    var buyerDecPts:  Int
    var otherDecPts:  Int
    var buyerWon:     Bool
    var buyerFinal:   Int
    var otherFinal:   Int
    var isKaboot:     Bool
    var isDobble:     Bool
}

// MARK: - Stored Round
struct Round: Identifiable {
    let id = UUID()
    var number:        Int
    var team1Score:    Int
    var team2Score:    Int
    var gameType:      GameType
    var buyerIsTeam1:  Bool
    var buyerWon:      Bool
    var isKaboot:      Bool
    var isDobble:      Bool
}

// MARK: - ViewModel
class GameViewModel: ObservableObject {
    @Published var team1Name = "نحن"
    @Published var team2Name = "هم"
    @Published var rounds:      [Round] = []
    @Published var isGameOver = false
    @Published var winnerIndex = 0          // 1 أو 2

    let winningScore = 152

    var team1Total:  Int    { rounds.reduce(0) { $0 + $1.team1Score } }
    var team2Total:  Int    { rounds.reduce(0) { $0 + $1.team2Score } }
    var winnerName:  String { winnerIndex == 1 ? team1Name : team2Name }

    // MARK: تحويل raw → بنطات
    func toPoints(raw: Int, gameType: GameType) -> Int {
        gameType == .sun ? rawToSun(raw) : rawToHokm(raw)
    }

    /// صن: تُضاعَف النقاط، والمناصف (×5) = وحدة كاملة (3.5 × 2 = 7)
    private func rawToSun(_ raw: Int) -> Int {
        let u = raw / 10, r = raw % 10
        if r < 5 { return u * 2 }
        if r > 5 { return (u + 1) * 2 }
        return u * 2 + 1          // r == 5 → 3.5 × 2 = 7
    }

    /// حكم: لا مضاعفة، المناصف يُكسَّر (4.5 → 4)
    private func rawToHokm(_ raw: Int) -> Int {
        let u = raw / 10, r = raw % 10
        return r <= 5 ? u : u + 1
    }

    // MARK: حساب جولة
    func calculateRound(
        gameType:  GameType,
        buyerRaw:  Int,
        isKaboot:  Bool,
        isDobble:  Bool,
        buyerDec:  Declarations,
        otherDec:  Declarations
    ) -> RoundResult {

        let buyerDecPts = buyerDec.total(for: gameType)
        let otherDecPts = otherDec.total(for: gameType)
        let multiplier  = isDobble ? 2 : 1

        // ── كبوت ─────────────────────────────────────────────
        if isKaboot {
            let base = gameType.kabootBase + buyerDecPts
            return RoundResult(
                buyerCardPts: gameType.kabootBase,
                otherCardPts: 0,
                buyerDecPts:  buyerDecPts,
                otherDecPts:  otherDecPts,
                buyerWon:     true,
                buyerFinal:   base * multiplier,
                otherFinal:   0,
                isKaboot:     true,
                isDobble:     isDobble
            )
        }

        // ── عادي ─────────────────────────────────────────────
        let otherRaw  = max(0, gameType.rawTotal - buyerRaw)
        let buyerCard = toPoints(raw: buyerRaw,  gameType: gameType)
        let otherCard = toPoints(raw: otherRaw,  gameType: gameType)

        let buyerTotal = buyerCard + buyerDecPts
        let otherTotal = otherCard + otherDecPts

        // في الدبل: التعادل = خسارة للفريق المشتري
        // في العادي: التعادل = فوز للفريق المشتري
        let buyerWon = isDobble ? (buyerTotal > otherTotal)
                                : (buyerTotal >= otherTotal)

        let buyerFinal: Int
        let otherFinal: Int

        if buyerWon {
            buyerFinal = buyerTotal * multiplier
            otherFinal = otherTotal * multiplier
        } else {
            // الفريق المشتري خسر: الكل يذهب للفريق الآخر
            buyerFinal = 0
            otherFinal = (gameType.basePoints + buyerDecPts + otherDecPts) * multiplier
        }

        return RoundResult(
            buyerCardPts: buyerCard,
            otherCardPts: otherCard,
            buyerDecPts:  buyerDecPts,
            otherDecPts:  otherDecPts,
            buyerWon:     buyerWon,
            buyerFinal:   buyerFinal,
            otherFinal:   otherFinal,
            isKaboot:     false,
            isDobble:     isDobble
        )
    }

    // MARK: إضافة جولة
    func addRound(
        gameType:     GameType,
        buyerIsTeam1: Bool,
        buyerRaw:     Int,
        isKaboot:     Bool,
        isDobble:     Bool,
        buyerDec:     Declarations,
        otherDec:     Declarations
    ) {
        let r  = calculateRound(gameType: gameType, buyerRaw: buyerRaw,
                                isKaboot: isKaboot, isDobble: isDobble,
                                buyerDec: buyerDec, otherDec: otherDec)
        let t1 = buyerIsTeam1 ? r.buyerFinal : r.otherFinal
        let t2 = buyerIsTeam1 ? r.otherFinal : r.buyerFinal

        rounds.append(Round(
            number:       rounds.count + 1,
            team1Score:   t1,
            team2Score:   t2,
            gameType:     gameType,
            buyerIsTeam1: buyerIsTeam1,
            buyerWon:     r.buyerWon,
            isKaboot:     isKaboot,
            isDobble:     isDobble
        ))
        checkWinner()
    }

    // MARK: إضافة جولة مباشرة (الوضع المبسط)
    func addRoundDirect(t1: Int, t2: Int, gameType: GameType = .hokm, buyerIsTeam1: Bool = true) {
        rounds.append(Round(
            number:       rounds.count + 1,
            team1Score:   t1,
            team2Score:   t2,
            gameType:     gameType,
            buyerIsTeam1: buyerIsTeam1,
            buyerWon:     buyerIsTeam1 ? (t1 >= t2) : (t2 >= t1),
            isKaboot:     false,
            isDobble:     false
        ))
        checkWinner()
    }

    // MARK: إدارة اللعبة
    func undoLastRound() {
        guard !rounds.isEmpty else { return }
        rounds.removeLast()
        isGameOver = false
        winnerIndex = 0
    }

    func restartSameTeams() {
        rounds.removeAll(); isGameOver = false; winnerIndex = 0
    }

    func fullReset() {
        rounds.removeAll(); isGameOver = false; winnerIndex = 0
        team1Name = "نحن"; team2Name = "هم"
    }

    private func checkWinner() {
        let t1 = team1Total, t2 = team2Total
        guard t1 >= winningScore || t2 >= winningScore else { return }
        isGameOver  = true
        winnerIndex = t1 >= t2 ? 1 : 2
    }
}
