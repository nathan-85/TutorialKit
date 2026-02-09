import SwiftUI

/// A styled card for displaying tutorial step content.
///
/// Provides the standard dark background, rounded corners, and title styling.
/// Pass your content (body text, buttons, etc.) via the trailing closure.
///
/// ```swift
/// TutorialCard(title: "Welcome") {
///     Text("Let's take a quick tour.")
///         .font(.system(size: 14))
///         .foregroundColor(.white.opacity(0.85))
///
///     HStack {
///         Button("Skip") { ... }
///         Spacer()
///         Button("Next") { ... }
///     }
/// }
/// ```
public struct TutorialCard<Content: View>: View {
    let title: String
    let centered: Bool
    @ViewBuilder let content: Content

    public init(title: String, centered: Bool = false, @ViewBuilder content: () -> Content) {
        self.title = title
        self.centered = centered
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: centered ? .center : .leading, spacing: 12) {
            Text(title)
                .font(.system(size: centered ? 22 : 18, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(centered ? .center : .leading)

            content
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: centered ? 320 : 280, alignment: centered ? .center : .leading)
        .background(Color(red: 0.1, green: 0.11, blue: 0.14))
        .mask(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white)
                .blur(radius: 4)
        )
        .accessibilityIdentifier("TutorialCard")
    }
}

/// Preference key for measuring the rendered size of a tutorial card.
public struct TutorialCardSizeKey: PreferenceKey {
    public static var defaultValue: CGSize = .zero

    public static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next != .zero {
            value = next
        }
    }
}

/// Utility for computing tutorial card placement relative to arrow targets.
public enum TutorialCardPlacement {
    /// Computes a card position opposite the centroid of arrow targets.
    ///
    /// When no arrows are present, the card centers in the container.
    /// In landscape, the card goes to the opposite horizontal half.
    /// In portrait, the card goes to the opposite vertical half.
    public static func position(
        for arrows: [TutorialArrow],
        in frames: [TutorialElement: CGRect],
        container: CGRect
    ) -> CGPoint {
        guard !arrows.isEmpty else {
            return CGPoint(x: container.midX, y: container.midY)
        }

        let targetRects = arrows.compactMap { frames[$0.element] }
        guard !targetRects.isEmpty else {
            return CGPoint(x: container.midX, y: container.midY)
        }

        let count = CGFloat(targetRects.count)
        let centroidX = targetRects.map(\.midX).reduce(0, +) / count
        let centroidY = targetRects.map(\.midY).reduce(0, +) / count
        let isLandscape = container.width > container.height

        if isLandscape {
            let x = centroidX > container.midX ? container.width * 0.25 : container.width * 0.75
            return CGPoint(x: x, y: container.midY)
        } else {
            let y = centroidY > container.midY ? container.height * 0.25 : container.height * 0.75
            return CGPoint(x: container.midX, y: y)
        }
    }
}
