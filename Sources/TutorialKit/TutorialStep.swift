import SwiftUI

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

    public init(
        title: String,
        body: String,
        arrows: [TutorialArrow] = [],
        blurTargets: TutorialBlurTargets = [],
        supplementalArrows: [TutorialArrow] = [],
        triggers: [String] = []
    ) {
        self.title = title
        self.body = body
        self.arrows = arrows
        self.blurTargets = blurTargets
        self.supplementalArrows = supplementalArrows
        self.triggers = triggers
    }
}
