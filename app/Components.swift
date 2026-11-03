import AppKit
import SwiftUI

/// A white symbol on a colored rounded square, as in System Settings.
struct IconTile: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 22

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.52, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: size * 0.26, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// An icon, a title and an optional description, used as the label of every setting row.
struct RowLabel: View {
    let title: String
    var subtitle: String?
    var symbol: String?
    var color: Color = .accentColor

    var body: some View {
        HStack(spacing: 10) {
            if let symbol {
                IconTile(symbol: symbol, color: color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

/// The screenshot at the top of each page, with the page's icon, title and description below it.
struct PageHero: View {
    let page: TweakPage
    let highlight: String?

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                ScreenshotPreview(page: page, highlight: highlight)
                    .overlay(alignment: .bottom) { caption.padding(10) }
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(.separator, lineWidth: 0.5)
                    }
                HStack(spacing: 12) {
                    IconTile(symbol: page.symbol, color: page.color, size: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(page.title).font(.headline)
                        Text(page.summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var caption: some View {
        let text: String = if let highlight, let title = Feature.title(highlight) {
            PreviewImages.pair(for: highlight) == nil ? "No screenshot for \(title)" : "\(title) in Aside"
        } else {
            "Point at a setting to see it in Aside"
        }
        return Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.regularMaterial, in: Capsule())
            .contentTransition(.opacity)
            .animation(.easeOut(duration: 0.15), value: text)
    }
}

/// Screenshots of Aside, taken in a separate test profile and bundled with the app.
@MainActor
enum PreviewImages {
    private static var cache: [String: NSImage] = [:]

    static func image(_ name: String) -> NSImage? {
        if let cached = cache[name] { return cached }
        guard let url = Bundle.main.url(forResource: name, withExtension: "jpg", subdirectory: "previews"),
              let image = NSImage(contentsOf: url) else { return nil }
        cache[name] = image
        return image
    }

    /// The setting off and on, if both were captured.
    static func pair(for id: String) -> (off: NSImage, on: NSImage)? {
        guard let off = image("\(id)-off"), let on = image("\(id)-on") else { return nil }
        return (off, on)
    }
}

/// Shows the page's screenshot, or, for the setting under the pointer, Aside with it off and then on.
struct ScreenshotPreview: View {
    let page: TweakPage
    let highlight: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private static let interval = 1.6

    var body: some View {
        Group {
            if let highlight, let pair = PreviewImages.pair(for: highlight) {
                TimelineView(.periodic(from: .now, by: Self.interval)) { context in
                    let isOn = Int(context.date.timeIntervalSinceReferenceDate / Self.interval) % 2 == 0
                    ZStack(alignment: .topLeading) {
                        screenshot(pair.off)
                        screenshot(pair.on).opacity(isOn ? 1 : 0)
                        Text(isOn ? "On" : "Off")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(isOn ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.regularMaterial), in: Capsule())
                            .foregroundStyle(isOn ? .white : .primary)
                            .padding(10)
                    }
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: isOn)
                }
                .accessibilityLabel("Aside with \(Feature.title(highlight) ?? "this setting") off and on")
            } else {
                screenshot(PreviewImages.image(page.overview))
                    .accessibilityLabel("Screenshot of Aside")
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(2, contentMode: .fit)
        .background(.quaternary)
        .clipped()
    }

    @ViewBuilder
    private func screenshot(_ image: NSImage?) -> some View {
        // A clear view takes the frame's size, so the image fills it exactly instead of setting it.
        Color.clear.overlay {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            }
        }
        .clipped()
    }
}

/// A notice at the top of a page, with an optional action.
struct NoticeRow: View {
    let title: String
    let subtitle: String
    var symbol = "exclamationmark.triangle.fill"
    var color: Color = .orange
    var actionTitle: String?
    var action: () -> Void = {}

    var body: some View {
        HStack(spacing: 10) {
            RowLabel(title: title, subtitle: subtitle, symbol: symbol, color: color)
            Spacer(minLength: 8)
            if let actionTitle {
                Button(actionTitle, action: action)
            }
        }
    }
}

extension View {
    /// Shows this setting in the page's preview while the pointer is over it.
    func previews(_ id: String, in highlight: Binding<String?>) -> some View {
        contentShape(Rectangle())
            .onHover { isHovering in
                if isHovering {
                    highlight.wrappedValue = id
                } else if highlight.wrappedValue == id {
                    highlight.wrappedValue = nil
                }
            }
    }
}
