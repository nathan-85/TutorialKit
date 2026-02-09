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

extension EnvironmentValues {
    /// String identifiers for triggers that are currently active.
    /// Set at the root of your view hierarchy; read by `.tutorialTriggered()`.
    public var activeTutorialTriggers: Set<String> {
        get { self[ActiveTutorialTriggersKey.self] }
        set { self[ActiveTutorialTriggersKey.self] = newValue }
    }
}

extension View {
    /// Sets `isPresented` to `true` (after a short delay) when the given trigger
    /// becomes active, and back to `false` when it is removed.
    public func tutorialTriggered(_ id: String, isPresented: Binding<Bool>) -> some View {
        modifier(TutorialTriggerModifier(id: id, isPresented: isPresented))
    }
}

private struct TutorialTriggerModifier: ViewModifier {
    let id: String
    @Binding var isPresented: Bool
    @Environment(\.activeTutorialTriggers) private var triggers

    func body(content: Content) -> some View {
        content.onChange(of: triggers.contains(id)) { isActive in
            if isActive {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isPresented = true
                }
            } else {
                isPresented = false
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

extension View {
    /// Draws tutorial-style arrows on top of this view when the tutorial system
    /// provides supplemental arrows via the environment.
    ///
    /// Pair with `.captureTutorialFrame(_:)` on child views so the overlay knows
    /// where each element is. Only arrows whose target frames are found will draw,
    /// so the modifier is safe to leave on any view permanently.
    public func tutorialOverlay() -> some View {
        modifier(SupplementalTutorialModifier())
    }
}

private struct SupplementalTutorialModifier: ViewModifier {
    @Environment(\.activeSupplementalArrows) private var arrows
    @State private var frames: [TutorialElement: CGRect] = [:]
    @State private var visibleArrows = 0
    @State private var arrowAnimationId = UUID()

    func body(content: Content) -> some View {
        content
            .onPreferenceChange(TutorialFramePreferenceKey.self) { newValue in
                frames.merge(newValue) { _, new in new }
            }
            .overlay {
                if !arrows.isEmpty {
                    arrowOverlay
                }
            }
    }

    private var arrowOverlay: some View {
        GeometryReader { proxy in
            let globalOrigin = proxy.frame(in: .global).origin
            let localFrames = frames.mapValues { rect in
                CGRect(
                    x: rect.minX - globalOrigin.x,
                    y: rect.minY - globalOrigin.y,
                    width: rect.width,
                    height: rect.height
                )
            }
            let isLandscape = proxy.size.width > proxy.size.height
            let labels = resolvedLabels(localFrames: localFrames, isLandscape: isLandscape)

            ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                let arrowStart = label.arrowStart(isLandscape: isLandscape)
                let visible = visibleArrows >= index + 1

                TutorialArrowShape(
                    start: arrowStart,
                    end: label.anchorPoint,
                    curvature: label.arrow.curvature(start: arrowStart, end: label.anchorPoint, isLandscape: isLandscape)
                )
                .trim(from: 0, to: visible ? 1 : 0)
                .stroke(
                    Color.white.opacity(0.85),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                )

                Text(label.arrow.element.label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(label.arrow.textAlignment.resolved(isLandscape))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .mask(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(.white)
                            .blur(radius: 5)
                    )
                    .scaleEffect(visible ? 1 : 0.3)
                    .opacity(visible ? 1 : 0)
                    .position(label.labelCenter)
            }
        }
        .allowsHitTesting(false)
        .onAppear { animateArrowsIn() }
    }

    private func resolvedLabels(localFrames: [TutorialElement: CGRect], isLandscape: Bool) -> [ResolvedLabel] {
        var labels: [ResolvedLabel] = []
        for arrow in arrows {
            guard let targetFrame = localFrames[arrow.element] else { continue }
            let anchorPoint = arrow.anchor.resolved(isLandscape).point(in: targetFrame)
            let labelSize = estimatedLabelSize(for: arrow.element.label)
            let labelCenter = arrow.labelCenter(anchorPoint: anchorPoint, labelSize: labelSize, isLandscape: isLandscape)
            labels.append(ResolvedLabel(arrow: arrow, anchorPoint: anchorPoint, labelSize: labelSize, labelCenter: labelCenter))
        }
        ResolvedLabel.resolveOverlaps(&labels)
        return labels
    }

    private func animateArrowsIn() {
        let id = UUID()
        arrowAnimationId = id
        for i in 0..<arrows.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 + Double(i) * 0.15) {
                guard arrowAnimationId == id else { return }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    visibleArrows = i + 1
                }
            }
        }
    }

    private func estimatedLabelSize(for text: String) -> CGSize {
        let font = UIFont.systemFont(ofSize: 13, weight: .medium)
        let size = (text as NSString).boundingRect(
            with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        ).size
        let hPad: CGFloat = 3 * 2
        let vPad: CGFloat = 2 * 2
        return CGSize(width: ceil(size.width) + hPad, height: ceil(size.height) + vPad)
    }
}
