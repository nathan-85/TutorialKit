import SwiftUI
import UIKit

/// Renders tutorial arrows with labels, handling staggered animation automatically.
///
/// The first arrow draws from the card to the first element. Remaining arrows
/// draw from collision-resolved labels to their target elements.
///
/// ```swift
/// TutorialArrowLayer(
///     arrows: step.arrows,
///     frames: localFrames,
///     cardRect: cardRect,
///     isLandscape: isLandscape,
///     stepIndex: stepIndex
/// )
/// ```
public struct TutorialArrowLayer: View {
    let arrows: [TutorialArrow]
    let frames: [TutorialElement: CGRect]
    let cardRect: CGRect
    let isLandscape: Bool
    let stepIndex: Int
    let primaryStrokeWidth: CGFloat
    let secondaryStrokeWidth: CGFloat

    @State private var visibleCount = 0
    @State private var animationTask: Task<Void, Never>?

    public init(
        arrows: [TutorialArrow],
        frames: [TutorialElement: CGRect],
        cardRect: CGRect,
        isLandscape: Bool,
        stepIndex: Int,
        primaryStrokeWidth: CGFloat = 2,
        secondaryStrokeWidth: CGFloat = 1.5
    ) {
        self.arrows = arrows
        self.frames = frames
        self.cardRect = cardRect
        self.isLandscape = isLandscape
        self.stepIndex = stepIndex
        self.primaryStrokeWidth = primaryStrokeWidth
        self.secondaryStrokeWidth = secondaryStrokeWidth
    }

    public var body: some View {
        let primaryResolved = {
            guard let firstArrow = arrows.first else { return false }
            return frames[firstArrow.element] != nil
        }()
        let secondaryLabels = resolvedSecondaryLabels()
        let secondaryStartIndex = primaryResolved ? 2 : 1
        let resolvedArrowCount = (primaryResolved ? 1 : 0) + secondaryLabels.count

        Group {
            // Primary arrow: card → first element
            if let firstArrow = arrows.first,
               let targetFrame = frames[firstArrow.element] {
                let anchorPoint = firstArrow.resolvedAnchorPoint(in: targetFrame, isLandscape: isLandscape)
                let start = firstArrow.fromAnchor.resolved(isLandscape).point(in: cardRect)

                TutorialArrowShape(
                    start: start,
                    end: anchorPoint,
                    curvature: firstArrow.curvature(start: start, end: anchorPoint, isLandscape: isLandscape)
                )
                .trim(from: 0, to: visibleCount >= 1 ? 1 : 0)
                .stroke(
                    Color.white.opacity(firstArrow.arrowOpacity),
                    style: StrokeStyle(lineWidth: primaryStrokeWidth, lineCap: .round, lineJoin: .round)
                )
            }

            // Secondary arrows: label + short arrow each (collision-resolved)
            ForEach(Array(secondaryLabels.enumerated()), id: \.offset) { index, label in
                let visible = visibleCount >= index + secondaryStartIndex

                if let iconName = label.arrow.icon {
                    // Icon at anchor point, label at its normal position
                    Image(systemName: iconName)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 2)
                        .scaleEffect(visible ? 1 : 0.3)
                        .opacity(visible ? 1 : 0)
                        .position(label.anchorPoint)

                    if !label.arrow.element.label.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text(label.arrow.element.label)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .multilineTextAlignment(label.arrow.textAlignment.resolved(isLandscape))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(label.arrow.labelBackgroundStyle)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color.white.opacity(0.9), lineWidth: 0.8)
                            )
                            .scaleEffect(visible ? 1 : 0.3)
                            .opacity(visible ? 1 : 0)
                            .position(label.labelCenter)
                    }
                } else {
                    let arrowStart = label.arrowStart(isLandscape: isLandscape)

                    TutorialArrowShape(
                        start: arrowStart,
                        end: label.anchorPoint,
                        curvature: label.arrow.curvature(start: arrowStart, end: label.anchorPoint, isLandscape: isLandscape)
                    )
                    .trim(from: 0, to: visible ? 1 : 0)
                    .stroke(
                        Color.white.opacity(label.arrow.arrowOpacity),
                        style: StrokeStyle(lineWidth: secondaryStrokeWidth, lineCap: .round, lineJoin: .round)
                    )

                    Text(label.arrow.element.label)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .multilineTextAlignment(label.arrow.textAlignment.resolved(isLandscape))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(label.arrow.labelBackgroundStyle)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.white.opacity(0.9), lineWidth: 0.8)
                        )
                        .scaleEffect(visible ? 1 : 0.3)
                        .opacity(visible ? 1 : 0)
                        .position(label.labelCenter)
                }
            }
        }
        .onAppear {
            restartArrowAnimation(after: 0.35, total: resolvedArrowCount)
        }
        .onChange(of: stepIndex) { _ in
            restartArrowAnimation(after: 0.2, total: resolvedArrowCount)
        }
        .onChange(of: resolvedArrowCount) { newCount in
            if newCount > visibleCount || (visibleCount == 0 && newCount > 0) {
                restartArrowAnimation(after: 0.05, total: newCount)
            } else if newCount == 0 {
                animationTask?.cancel()
                animationTask = nil
                visibleCount = 0
            }
        }
        .onDisappear {
            animationTask?.cancel()
            animationTask = nil
        }
    }

    private func restartArrowAnimation(after baseDelay: Double, total: Int) {
        animationTask?.cancel()
        visibleCount = 0

        guard total > 0 else { return }

        animationTask = Task { @MainActor in
            var previousDelay = 0.0
            for i in 0..<total {
                if Task.isCancelled { return }
                let nextDelay = baseDelay + Double(i) * 0.05
                let increment = max(nextDelay - previousDelay, 0)
                previousDelay = nextDelay
                let nanoseconds = UInt64(increment * 1_000_000_000)
                if nanoseconds > 0 {
                    do {
                        try await Task.sleep(nanoseconds: nanoseconds)
                    } catch {
                        return
                    }
                }
                if Task.isCancelled { return }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    visibleCount = i + 1
                }
            }
        }
    }

    private func resolvedSecondaryLabels() -> [ResolvedLabel] {
        var labels: [ResolvedLabel] = []
        for arrow in arrows.dropFirst() {
            guard let targetFrame = frames[arrow.element] else { continue }
            let anchorPoint = arrow.resolvedAnchorPoint(in: targetFrame, isLandscape: isLandscape)
            let labelSize = Self.estimatedLabelSize(for: arrow.element.label)
            let labelCenter = arrow.labelCenter(anchorPoint: anchorPoint, labelSize: labelSize, isLandscape: isLandscape)
            labels.append(ResolvedLabel(arrow: arrow, anchorPoint: anchorPoint, labelSize: labelSize, labelCenter: labelCenter))
        }
        ResolvedLabel.resolveOverlaps(&labels)
        return labels
    }

    /// Estimates the rendered size of a label string at the standard tutorial label font size.
    public static func estimatedLabelSize(for text: String) -> CGSize {
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
