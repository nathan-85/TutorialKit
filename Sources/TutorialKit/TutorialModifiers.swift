import SwiftUI
import UIKit

// MARK: - Frame Capture

/// Preference key that collects element frames in global coordinates.
public struct TutorialFramePreferenceKey: PreferenceKey {
    public static var defaultValue: [TutorialElement: CGRect] = [:]

    public static func reduce(value: inout [TutorialElement: CGRect], nextValue: () -> [TutorialElement: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

extension View {
    /// Captures this view's frame so the tutorial system can draw arrows to it.
    public func captureTutorialFrame(_ element: TutorialElement) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(key: TutorialFramePreferenceKey.self, value: [element: proxy.frame(in: .global)])
            }
        )
    }
}

// MARK: - Tutorial Blur

private struct ActiveTutorialBlurTargetsKey: EnvironmentKey {
    static let defaultValue: TutorialBlurTargets = []
}

extension EnvironmentValues {
    /// The blur targets that are currently active in the tutorial.
    /// Set at the root of your view hierarchy; read by `.tutorialBlur()`.
    public var activeTutorialBlurTargets: TutorialBlurTargets {
        get { self[ActiveTutorialBlurTargetsKey.self] }
        set { self[ActiveTutorialBlurTargetsKey.self] = newValue }
    }
}

extension View {
    /// Blurs this view when the tutorial system marks the given target as active.
    public func tutorialBlur(_ target: TutorialBlurTargets) -> some View {
        modifier(TutorialBlurModifier(target: target))
    }
}

private struct TutorialBlurModifier: ViewModifier {
    let target: TutorialBlurTargets
    @Environment(\.activeTutorialBlurTargets) private var activeTargets

    func body(content: Content) -> some View {
        content.blur(radius: activeTargets.contains(target) ? 20 : 0)
    }
}

// MARK: - Tutorial Triggers

private struct ActiveTutorialTriggersKey: EnvironmentKey {
    static let defaultValue: Set<String> = []
}

private struct TutorialAdvanceActionKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    /// String identifiers for triggers that are currently active.
    /// Set at the root of your view hierarchy; read by `.tutorialTriggered()`.
    public var activeTutorialTriggers: Set<String> {
        get { self[ActiveTutorialTriggersKey.self] }
        set { self[ActiveTutorialTriggersKey.self] = newValue }
    }

    /// Advances the tutorial to the next step. Injected by ``TutorialHostModifier``.
    var tutorialAdvanceAction: (() -> Void)? {
        get { self[TutorialAdvanceActionKey.self] }
        set { self[TutorialAdvanceActionKey.self] = newValue }
    }
}

extension View {
    /// Sets `isPresented` to `true` (after a short delay) when the given trigger
    /// becomes active, and back to `false` when it is removed.
    public func tutorialTriggered(_ id: String, isPresented: Binding<Bool>) -> some View {
        modifier(TutorialTriggerModifier(id: id, isPresented: isPresented))
    }

    /// Runs an action when a tutorial trigger becomes active or inactive.
    ///
    /// Use this for side effects during a tutorial step — starting or stopping
    /// animations, timers, or other app-state changes:
    /// ```swift
    /// InstrumentView()
    ///     .tutorialAction("animateHeadingBug") { isActive in
    ///         if isActive { startDemo() } else { stopDemo() }
    ///     }
    /// ```
    public func tutorialAction(_ id: String, perform action: @escaping (_ isActive: Bool) -> Void) -> some View {
        modifier(TutorialActionModifier(id: id, action: action))
    }
}

private struct TutorialActionModifier: ViewModifier {
    let id: String
    let action: (_ isActive: Bool) -> Void
    @Environment(\.activeTutorialTriggers) private var triggers

    func body(content: Content) -> some View {
        content.onChange(of: triggers.contains(id)) { isActive in
            action(isActive)
        }
    }
}

private struct TutorialTriggerModifier: ViewModifier {
    let id: String
    @Binding var isPresented: Bool
    @Environment(\.activeTutorialTriggers) private var triggers
    @Environment(\.tutorialAdvanceAction) private var advanceAction

    func body(content: Content) -> some View {
        content
            .onChange(of: triggers.contains(id)) { isActive in
                if isActive {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isPresented = true
                    }
                } else {
                    isPresented = false
                }
            }
            .onChange(of: isPresented) { presented in
                // When the user dismisses a triggered popover/sheet directly
                // (e.g. tapping outside), the trigger is still active but
                // isPresented becomes false. Auto-advance so the user doesn't
                // need to tap "Next" a second time.
                if !presented && triggers.contains(id) {
                    advanceAction?()
                }
            }
    }
}

// MARK: - Supplemental Tutorial Overlay

private struct ActiveSupplementalArrowsKey: EnvironmentKey {
    static let defaultValue: [TutorialArrow] = []
}

extension EnvironmentValues {
    /// Tutorial arrows that supplemental overlays should display.
    /// Set at the root of your view hierarchy; read by `.tutorialOverlay()`.
    public var activeSupplementalArrows: [TutorialArrow] {
        get { self[ActiveSupplementalArrowsKey.self] }
        set { self[ActiveSupplementalArrowsKey.self] = newValue }
    }
}

// MARK: - Supplemental Frame Store

/// Shared store that collects element frames (in global coordinates) from
/// views inside popovers/sheets, so the overlay window can draw arrows to them.
public final class TutorialSupplementalFrameStore: ObservableObject {
    @Published public var frames: [TutorialElement: CGRect] = [:]

    /// When `true`, frame updates from `onPreferenceChange` are ignored.
    /// Set at the start of a popover/sheet dismiss animation to prevent
    /// intermediate positions from being published. Reset on next appearance.
    var isFrozen = false
}

private struct SupplementalFrameStoreKey: EnvironmentKey {
    static let defaultValue: TutorialSupplementalFrameStore? = nil
}

extension EnvironmentValues {
    /// The shared frame store for supplemental tutorial arrows.
    /// Injected by the `.tutorial()` modifier; read by `.tutorialOverlay()`.
    var supplementalFrameStore: TutorialSupplementalFrameStore? {
        get { self[SupplementalFrameStoreKey.self] }
        set { self[SupplementalFrameStoreKey.self] = newValue }
    }
}

extension View {
    /// Captures element frames from this view and publishes them to the
    /// supplemental frame store so the tutorial overlay window can draw
    /// arrows that extend beyond popover/sheet boundaries.
    ///
    /// Pair with `.captureTutorialFrame(_:)` on child views so the store knows
    /// where each element is. Safe to leave on any view permanently.
    public func tutorialOverlay() -> some View {
        modifier(SupplementalTutorialModifier())
    }
}

/// Captures element frames from inside popovers/sheets and publishes them
/// to the shared ``TutorialSupplementalFrameStore``. Arrow rendering is
/// handled by the overlay window managed by ``TutorialHostModifier``.
private struct SupplementalTutorialModifier: ViewModifier {
    @Environment(\.activeSupplementalArrows) private var arrows
    @Environment(\.supplementalFrameStore) private var frameStore

    func body(content: Content) -> some View {
        content
            .onPreferenceChange(TutorialFramePreferenceKey.self) { newValue in
                guard let store = frameStore, !store.isFrozen, !arrows.isEmpty else { return }
                let targetElements = Set(arrows.map(\.element))
                let relevant = newValue.filter { targetElements.contains($0.key) }
                store.frames.merge(relevant) { _, new in new }
            }
            .onAppear {
                frameStore?.isFrozen = false
            }
            .background(
                // UIKit's viewWillDisappear fires at the START of the dismiss
                // animation. We freeze the store so onPreferenceChange can't
                // re-populate frames with intermediate positions, then clear.
                WillDisappearView {
                    frameStore?.isFrozen = true
                    frameStore?.frames = [:]
                }
            )
    }
}

/// Bridges UIKit's `viewWillDisappear` into SwiftUI so we can react at the
/// *start* of a popover/sheet dismiss animation rather than after it finishes.
private struct WillDisappearView: UIViewControllerRepresentable {
    let action: () -> Void

    func makeUIViewController(context: Context) -> WillDisappearController {
        WillDisappearController(action: action)
    }

    func updateUIViewController(_ controller: WillDisappearController, context: Context) {
        controller.action = action
    }

    final class WillDisappearController: UIViewController {
        var action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError() }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            action()
        }
    }
}
