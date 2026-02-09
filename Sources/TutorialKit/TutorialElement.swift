import Foundation

/// Identifies a UI element that tutorial arrows can target.
///
/// Define your app's elements as static properties:
/// ```swift
/// extension TutorialElement {
///     static let loginButton = TutorialElement("Tap to log in")
///     static let profileIcon = TutorialElement(id: "profile", label: "Your Profile")
/// }
/// ```
public struct TutorialElement: Hashable, Sendable {
    /// Unique identifier for this element. Used as the dictionary key for frame lookup.
    public let id: String

    /// Human-readable label displayed next to the tutorial arrow.
    public let label: String

    /// Creates an element where the label doubles as the identifier.
    public init(_ label: String) {
        self.id = label
        self.label = label
    }

    /// Creates an element with a distinct identifier and display label.
    public init(id: String, label: String) {
        self.id = id
        self.label = label
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}

/// Identifies which parts of the UI should blur during a tutorial step.
///
/// Define your app's blur regions as static properties:
/// ```swift
/// extension TutorialBlurTargets {
///     static let map        = TutorialBlurTargets(rawValue: 1 << 0)
///     static let instrument = TutorialBlurTargets(rawValue: 1 << 1)
/// }
/// ```
public struct TutorialBlurTargets: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
}
