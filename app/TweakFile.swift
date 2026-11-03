import Foundation

/// A stylesheet in `tweaks/`. A file ending in `.off` is disabled.
struct TweakFile: Identifiable, Hashable {
    let url: URL

    var id: URL { url }
    var isEnabled: Bool { url.pathExtension == "css" }

    var name: String {
        let base = isEnabled ? url : url.deletingPathExtension()
        return base.deletingPathExtension().lastPathComponent
    }
}
