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

/// Standard Skip / Next button row for use inside ``TutorialStep/cardContent``.
///
/// Matches the default button styling from ``DefaultTutorialOverlay`` with a
/// fade-in entrance animation.
///
/// ```swift
/// TutorialStep(
///     title: "My Step",
///     body: "",
///     cardContent: { actions in
///         AnyView(TutorialNextSkipButtons(actions: actions))
///     }
/// )
/// ```
public struct TutorialNextSkipButtons: View {
    public let actions: TutorialActions
    @State private var isVisible = false

    public init(actions: TutorialActions) {
        self.actions = actions
    }

    public var body: some View {
        HStack(spacing: 16) {
            Button("Skip") {
                actions.dismiss()
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(Color.white.opacity(0.7))

            Button("Next") {
                actions.advance()
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.black)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.white)
            .clipShape(Capsule())
            .accessibilityIdentifier("TutorialNextButton")
        }
        .offset(y: isVisible ? 0 : 8)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                isVisible = true
            }
        }
        .onDisappear {
            withAnimation(.easeInOut(duration: 0.2)) {
                isVisible = false
            }
        }
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
    /// When set, overrides automatic card placement with a fixed center expressed as a
    /// fraction of the container size (e.g. `CGSize(width: 0.5, height: 0.25)` places the
    /// card at 50% x, 25% y).
    public var position: CGSize?
    /// Optional landscape-specific override for ``position``. When the container is wider
    /// than it is tall and this value is set, it is used instead of ``position``.
    public var landscapePosition: CGSize?

    public init(
        title: String,
        body: String,
        arrows: [TutorialArrow] = [],
        blurTargets: TutorialBlurTargets = [],
        supplementalArrows: [TutorialArrow] = [],
        triggers: [String] = [],
        tags: Set<String> = [],
        centered: Bool = false,
        cardContent: ((TutorialActions) -> AnyView)? = nil,
        position: CGSize? = nil,
        landscapePosition: CGSize? = nil,
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
        self.position = position
        self.landscapePosition = landscapePosition
    }

    /// Convenience `cardContent` value that shows only the standard Next and Skip buttons.
    ///
    /// ```swift
    /// TutorialStep(
    ///     title: "My Step",
    ///     body: "",
    ///     cardContent: TutorialStep.nextSkipContent
    /// )
    /// ```
    public static let nextSkipContent: (TutorialActions) -> AnyView = { actions in
        AnyView(TutorialNextSkipButtons(actions: actions))
    }
}
