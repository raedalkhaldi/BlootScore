import SwiftUI

struct WinnerView: View {
    @EnvironmentObject var vm: GameViewModel
    @EnvironmentObject var voices: VoiceStore
    @Environment(\.dismiss) var dismiss

    private var winnerColor: Color {
        vm.winnerIndex == 2 ? Theme.Color.team2 : Theme.Color.team1
    }

    var body: some View {
        VStack(spacing: Theme.Space.xxl) {
            Spacer()

            Text("🏆")
                .font(.system(size: 80))

            VStack(spacing: Theme.Space.sm) {
                Text("الفائز")
                    .font(Theme.Font.title)
                    .foregroundColor(Theme.Color.muted)
                Text(vm.winnerName)
                    .font(Theme.Font.displayXL)
                    .foregroundColor(winnerColor)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }

            HStack(spacing: Theme.Space.xxl + Theme.Space.sm) {
                finalScore(name: vm.team1Name, score: vm.team1Total, color: Theme.Color.team1)
                Rectangle().fill(Theme.Color.border).frame(width: 1, height: 60)
                finalScore(name: vm.team2Name, score: vm.team2Total, color: Theme.Color.team2)
            }
            .padding(Theme.Space.lg)
            .background(Theme.Color.surface)
            .cornerRadius(Theme.Radius.lg)
            .themeHairline(cornerRadius: Theme.Radius.lg)

            Text("\(vm.rounds.count) جولة")
                .font(Theme.Font.body)
                .foregroundColor(Theme.Color.muted)

            Spacer()

            VStack(spacing: Theme.Space.md) {
                Button {
                    Theme.Haptic.medium()
                    vm.restartSameTeams()
                    dismiss()
                } label: {
                    Text("جولة جديدة — نفس الفرق")
                        .font(Theme.Font.title)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Space.md + 2)
                        .background(Theme.Color.accent)
                        .foregroundColor(Theme.Color.onAccent)
                        .cornerRadius(Theme.Radius.md)
                }

                Button {
                    Theme.Haptic.light()
                    vm.fullReset()
                    dismiss()
                } label: {
                    Text("تغيير الفرق")
                        .font(Theme.Font.title)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Space.md + 2)
                        .background(Theme.Color.surface)
                        .foregroundColor(Theme.Color.ink)
                        .cornerRadius(Theme.Radius.md)
                        .themeHairline(cornerRadius: Theme.Radius.md)
                }
            }
            .padding(.horizontal, Theme.Space.lg)
            .padding(.bottom, Theme.Space.lg)
        }
        .padding(Theme.Space.lg)
        .background(Theme.Color.canvas.ignoresSafeArea())
        .environment(\.layoutDirection, .rightToLeft)
        .onAppear {
            // تشغيل الصوت المناسب لحالة النتيجة (حلاق/فوز نهائي)
            Theme.Haptic.success()
            let t1 = vm.team1Total, t2 = vm.team2Total
            if t1 == 0 || t2 == 0 {
                voices.play(.barber)
            } else {
                voices.play(.finalWin)
            }
        }
    }

    @ViewBuilder
    private func finalScore(name: String, score: Int, color: Color) -> some View {
        VStack(spacing: Theme.Space.xs) {
            Text(name)
                .font(Theme.Font.caption)
                .foregroundColor(Theme.Color.muted)
            Text("\(score)")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
    }
}
