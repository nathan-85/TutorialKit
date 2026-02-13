import SwiftUI

/// A type that provides the environment data needed by a tutorial step.
///
/// Both ``TutorialStep`` and your own custom step types can conform.
/// The ``TutorialOverlay`` modifier reads these properties to inject
/// blur targets, triggers, and supplemental arrows into the environment.
public protocol TutorialStepProviding {
    var blurTargets: TutorialBlurTargets { get }
    var triggers: [String] { get }
    var supplementalArrows: [TutorialArrow] { get }
}

extension TutorialStep: TutorialStepProviding {}

/// A view that renders a tutorial overlay.
///
/// Conform to this protocol and use the `.tutorial()` modifier to add a tutorial
/// to your view. The modifier handles environment injection, frame collection,
/// step index management, and overlay presentation automatically.
///
/// ```swift
/// struct MyTutorialOverlay: TutorialOverlay {
///     static var steps: [TutorialStep] { [
///         TutorialStep(title: "Welcome", body: "Let's take a tour."),
///     ] }
///
///     @Binding var stepIndex: Int
///     let frames: [TutorialElement: CGRect]
///     let dismiss: () -> Void
///
///     var body: some View { ... }
/// }
///
/// // Usage — one line:
/// ContentView()
///     .tutorial(MyTutorialOverlay.self, isPresented: $showTutorial)
/// ```
public protocol TutorialOverlay: View {
    associatedtype Step: TutorialStepProviding

    /// The tutorial steps. The modifier reads `blurTargets`, `triggers`, and
    /// `supplementalArrows` from the current step to inject into the environment.
    static var steps: [Step] { get }

    /// Creates the overlay.
    /// - Parameters:
    ///   - stepIndex: Binding to the current step index, managed by the modifier.
    ///   - frames: Captured frames of tutorial elements in global coordinates.
    ///   - dismiss: Call this to dismiss the tutorial overlay.
    init(stepIndex: Binding<Int>, frames: [TutorialElement: CGRect], dismiss: @escaping () -> Void)
}

// MARK: - View Modifier

extension View {
    /// Attaches a tutorial overlay to this view.
    ///
    /// The modifier manages all tutorial state automatically:
    /// - Injects `activeTutorialBlurTargets`, `activeTutorialTriggers`,
    ///   and `activeSupplementalArrows` into the environment
    /// - Collects element frames via `TutorialFramePreferenceKey`
    /// - Tracks the current step index (resets to 0 on each presentation)
    /// - Presents and dismisses the overlay
    ///
    /// ```swift
    /// ContentView()
    ///     .tutorial(MyOverlay.self, isPresented: $showTutorial) {
    ///         // Called when the tutorial is dismissed
    ///     }
    /// ```
    public func tutorial<Overlay: TutorialOverlay>(
        _ overlay: Overlay.Type,
        isPresented: Binding<Bool>,
        onComplete: (() -> Void)? = nil
    ) -> some View {
        modifier(TutorialHostModifier<Overlay>(isPresented: isPresented, onComplete: onComplete))
    }
}

private struct TutorialHostModifier<Overlay: TutorialOverlay>: ViewModifier {
    @Binding var isPresented: Bool
    let onComplete: (() -> Void)?

    @State private var stepIndex = 0
    @State private var resolvedSteps: [Overlay.Step] = Overlay.steps
    @State private var frames: [TutorialElement: CGRect] = [:]
    @State private var lastCapturedFrames: [TutorialElement: CGRect] = [:]
    @StateObject private var supplementalFrameStore = TutorialSupplementalFrameStore()
    @State private var overlayWindowController = TutorialOverlayWindowController()

    private var currentStep: Overlay.Step? {
        guard isPresented, stepIndex >= 0, stepIndex < resolvedSteps.count else { return nil }
        return resolvedSteps[stepIndex]
    }

    func body(content: Content) -> some View {
        content
            .environment(\.isTutorialActive, isPresented)
            .environment(\.activeTutorialBlurTargets, currentStep?.blurTargets ?? [])
            .environment(\.activeTutorialTriggers, currentStep.map { Set($0.triggers) } ?? [])
            .environment(\.activeSupplementalArrows, currentStep?.supplementalArrows ?? [])
            .environment(\.supplementalFrameStore, supplementalFrameStore)
            .environment(\.tutorialAdvanceAction, isPresented ? { advance() } : nil)
            .onPreferenceChange(TutorialFramePreferenceKey.self) { newValue in
                guard !tutorialFrameDictionariesApproximatelyEqual(lastCapturedFrames, newValue) else { return }
                lastCapturedFrames = newValue
                frames = newValue
            }
            .overlay {
                if isPresented {
                    Overlay(
                        stepIndex: $stepIndex,
                        frames: frames,
                        dismiss: { isPresented = false }
                    )
                }
            }
            .onChange(of: isPresented) { newValue in
                if newValue {
                    resolvedSteps = Overlay.steps
                    stepIndex = 0
                    supplementalFrameStore.isFrozen = false
                    supplementalFrameStore.frames = [:]
                    updateOverlayWindow()
                } else {
                    overlayWindowController.hide()
                    supplementalFrameStore.isFrozen = false
                    supplementalFrameStore.frames = [:]
                    onComplete?()
                }
            }
            .onChange(of: stepIndex) { _ in
                clampStepIndexIfNeeded()
                supplementalFrameStore.isFrozen = false
                supplementalFrameStore.frames = [:]
                updateOverlayWindow()
            }
            .onAppear {
                clampStepIndexIfNeeded()
                if isPresented {
                    updateOverlayWindow()
                }
            }
            .onDisappear {
                overlayWindowController.hide()
            }
    }

    private func advance() {
        guard !resolvedSteps.isEmpty else {
            isPresented = false
            return
        }
        if stepIndex < resolvedSteps.count - 1 {
            stepIndex += 1
        } else {
            isPresented = false
        }
    }

    private func updateOverlayWindow() {
        let arrows = currentStep?.supplementalArrows ?? []
        if arrows.isEmpty {
            overlayWindowController.hide()
        } else {
            overlayWindowController.update(arrows: arrows, frameStore: supplementalFrameStore)
        }
    }

    private func clampStepIndexIfNeeded() {
        guard !resolvedSteps.isEmpty else {
            stepIndex = 0
            return
        }
        if stepIndex < 0 {
            stepIndex = 0
        } else if stepIndex >= resolvedSteps.count {
            stepIndex = resolvedSteps.count - 1
        }
    }

}
