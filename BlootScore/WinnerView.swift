import SwiftUI

struct WinnerView: View {
    @EnvironmentObject var vm: GameViewModel
    @EnvironmentObject var voices: VoiceStore
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("🏆")
                .font(.system(size: 80))

            VStack(spacing: 8) {
                Text("الفائز")
                    .font(.title3)
                    .foregroundColor(.secondary)
                Text(vm.winnerName)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
            }

            HStack(spacing: 40) {
                finalScore(name: vm.team1Name, score: vm.team1Total, color: .blue)
                Divider().frame(height: 60)
                finalScore(name: vm.team2Name, score: vm.team2Total, color: .red)
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            .cornerRadius(16)

            Text("\(vm.rounds.count) جولة")
                .foregroundColor(.secondary)
                .font(.callout)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    vm.restartSameTeams()
                    dismiss()
                } label: {
                    Text("جولة جديدة — نفس الفرق")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                }

                Button {
                    vm.fullReset()
                    dismiss()
                } label: {
                    Text("تغيير الفرق")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGroupedBackground))
                        .foregroundColor(.primary)
                        .cornerRadius(14)
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .padding()
        .environment(\.layoutDirection, .rightToLeft)
        .onAppear {
            // تشغيل الصوت المناسب لحالة النتيجة (حلاق/فوز نهائي)
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
        VStack(spacing: 4) {
            Text(name)
                .font(.caption)
                .foregroundColor(.secondary)
            Text("\(score)")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
    }
}
