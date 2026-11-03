import SwiftUI

@main
struct AsideTweakApp: App {
    @State private var store = TweakStore()

    var body: some Scene {
        Window("Aside Tweak", id: "main") {
            ContentView(store: store)
                .frame(minWidth: 760, idealWidth: 860, minHeight: 560, idealHeight: 720)
        }
        .windowResizability(.contentMinSize)

        // Native tweaks need the app running, so it stays in the menu bar when the window is closed.
        MenuBarExtra("Aside Tweak", systemImage: "slider.horizontal.3") {
            MenuBarContent(store: store)
        }
    }
}
