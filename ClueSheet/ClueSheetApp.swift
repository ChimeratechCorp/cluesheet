import SwiftUI

@main
struct ClueSheetApp: App {
    @State private var store = GameStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}

struct ContentView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        if store.game == nil {
            NavigationStack { SetupView() }
        } else {
            NavigationStack { SheetView() }
        }
    }
}
