import SwiftUI

@main
struct BlootApp: App {
    @StateObject private var vm = GameViewModel()
    @StateObject private var fb = FirebaseREST.shared
    @StateObject private var voices = VoiceStore.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vm)
                .environmentObject(voices)
                .environment(\.layoutDirection, .rightToLeft)
                .task {
                    await fb.start()
                    await voices.loadAll()
                }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var vm: GameViewModel
    @EnvironmentObject var voices: VoiceStore

    var body: some View {
        MainView()
            .sheet(isPresented: $vm.isGameOver) {
                WinnerView()
                    .environmentObject(vm)
                    .environmentObject(voices)
                    .environment(\.layoutDirection, .rightToLeft)
            }
    }
}
