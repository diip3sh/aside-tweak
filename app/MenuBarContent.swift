import AppKit
import SwiftUI

struct MenuBarContent: View {
    let store: TweakStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(store.bridge.isConnected ? "Native tweaks connected" : "Native tweaks not connected")
        Button("Open Aside Tweak") {
            openWindow(id: "main")
            NSApp.activate()
        }
        Button("Relaunch Aside with Tweaks") {
            Task { await store.relaunchAside() }
        }
        .disabled(store.bridge.isRelaunching)
        Divider()
        Button("Quit Aside Tweak") {
            NSApp.terminate(nil)
        }
    }
}
