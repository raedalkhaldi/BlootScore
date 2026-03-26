import SwiftUI

@main
struct BlootApp: App {
    @StateObject private var vm = GameViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vm)
                .environment(\.layoutDirection, .rightToLeft)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var vm: GameViewModel

    var body: some View {
        MainView()
            .sheet(isPresented: $vm.isGameOver) {
                WinnerView()
                    .environmentObject(vm)
                    .environment(\.layoutDirection, .rightToLeft)
            }
    }
}
