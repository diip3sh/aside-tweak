import Foundation

/// The controls in the app. `aside-tweak` turns the web ones into CSS, and `NativeBridge` applies the native ones.
struct TweakSettings: Codable, Equatable {
    static let defaultRoundness = 1.4

    var roundness = TweakSettings.defaultRoundness
    var textSize = 100.0
    var backgroundOpacity = 100.0
    var font = TweakFont.standard
    var animationMode = TweakAnimation.standard
    var sidebarAnimation = SidebarAnimation.standard
    var hideNewTabContent = false
    var nativeHidden: Set<String> = []

    init() {}

    /// Settings saved by an older version may be missing keys, which must not reset the rest.
    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        roundness = try values.decodeIfPresent(Double.self, forKey: .roundness) ?? TweakSettings.defaultRoundness
        textSize = try values.decodeIfPresent(Double.self, forKey: .textSize) ?? 100
        backgroundOpacity = try values.decodeIfPresent(Double.self, forKey: .backgroundOpacity) ?? 100
        font = try values.decodeIfPresent(TweakFont.self, forKey: .font) ?? .standard
        animationMode = try values.decodeIfPresent(TweakAnimation.self, forKey: .animationMode) ?? .standard
        sidebarAnimation = try values.decodeIfPresent(SidebarAnimation.self, forKey: .sidebarAnimation) ?? .standard
        hideNewTabContent = try values.decodeIfPresent(Bool.self, forKey: .hideNewTabContent) ?? false
        nativeHidden = try values.decodeIfPresent(Set<String>.self, forKey: .nativeHidden) ?? []
    }
}

enum TweakFont: String, Codable, CaseIterable, Identifiable {
    case standard = "default"
    case system
    case serif
    case mono

    var id: String { rawValue }

    var label: String {
        switch self {
        case .standard: "Aside default (Geist)"
        case .system: "System"
        case .serif: "Serif"
        case .mono: "Monospaced"
        }
    }
}

enum TweakAnimation: String, Codable, CaseIterable, Identifiable {
    case standard = "default"
    case fast
    case off

    var id: String { rawValue }

    var label: String {
        switch self {
        case .standard: "Aside default"
        case .fast: "Fast"
        case .off: "Off"
        }
    }
}

/// Chromium's Side Panel Flyover Animation flag: the sidebar slides over the page, which resizes once instead of on every frame.
/// No animation uses the animation-duration-scale switch instead.
enum SidebarAnimation: String, Codable, CaseIterable, Identifiable {
    case standard = "default"
    case smooth
    case ms250 = "250"
    case ms300 = "300"
    case ms350 = "350"
    case off = "none"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .standard: "Aside default"
        case .smooth: "Smooth"
        case .ms250: "Smooth, 250 ms"
        case .ms300: "Smooth, 300 ms"
        case .ms350: "Smooth, 350 ms"
        case .off: "No animation"
        }
    }

    /// The value saved in Aside's flag. With no animation the flag has nothing to time, so this just keeps it on.
    var flagChoice: SidebarAnimation {
        self == .off ? .smooth : self
    }

    /// Chromium has no switch for the sidebar alone, so this reaches all of Aside's native window animations.
    var launchArguments: [String] {
        self == .off ? ["--animation-duration-scale=0"] : []
    }
}
