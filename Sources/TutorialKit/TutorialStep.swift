import SwiftUI

/// Advance and dismiss actions passed to custom card content.
///
/// When a step provides ``TutorialStep/cardContent``, it receives this
/// so buttons can navigate the tutorial:
/// ```swift
/// TutorialStep(
///     title: "Done!",
///     body: "",
///     centered: true,
///     cardContent: { actions in
///         AnyView(Button("Finish") { actions.dismiss() })
///     }
/// )
/// ```
public struct TutorialActions {
    /// Advance to the next step (or dismiss if on the last step).
    public let advance: () -> Void
    /// Dismiss the tutorial immediately.
    public let dismiss: () -> Void

    public init(advance: @escaping () -> Void, dismiss: @escaping () -> Void) {
        self.advance = advance
        self.dismiss = dismiss
    }
}

/// A single step in a tutorial sequence.
///
/// Each step describes what to show (title, body), which arrows to draw,
/// which regions to blur, and which triggers to activate.
///
/// ```swift
/// let steps: [TutorialStep] = [
///     TutorialStep(
///         title: "Welcome",
///         body: "Let's take a quick tour.",
///         arrows: [],
///         blurTargets: [.map, .instrument]
///     ),
///     TutorialStep(
///         title: "Settings",
///         body: "Adjust your preferences here.",
///         arrows: [TutorialArrow(.settingsButton, anchor: .bottom)],
///         blurTargets: [.map],
///         triggers: ["showSettings"]
///     ),
/// ]
/// ```
public struct TutorialStep {
    public let title: String
    public let body: String
    public let arrows: [TutorialArrow]
    public let blurTargets: TutorialBlurTargets
    /// Arrows drawn by `.tutorialOverlay()` inside presented views (popovers, sheets, etc.).
    public var supplementalArrows: [TutorialArrow]
    /// String identifiers that activate `.tutorialTriggered()` modifiers on matching views.
    public var triggers: [String]
    /// Freeform tags for app-specific metadata (e.g. "proTier", "final").
    public var tags: Set<String>
    /// When `true`, the card uses centered layout (larger title, centered text, wider frame).
    public var centered: Bool
    /// When set, replaces the default body text and navigation buttons in the card.
    /// The closure receives advance/dismiss actions so custom content can navigate the tutorial.
    public var cardContent: ((TutorialActions) -> AnyView)?

    public init(
        title: String,
        body: String,
        arrows: [TutorialArrow] = [],
        blurTargets: TutorialBlurTargets = [],
        supplementalArrows: [TutorialArrow] = [],
        triggers: [String] = [],
        tags: Set<String> = [],
        centered: Bool = false,
        cardContent: ((TutorialActions) -> AnyView)? = nil
    ) {
        self.title = title
        self.body = body
        self.arrows = arrows
        self.blurTargets = blurTargets
        self.supplementalArrows = supplementalArrows
        self.triggers = triggers
        self.tags = tags
        self.centered = centered
        self.cardContent = cardContent
    }
}
