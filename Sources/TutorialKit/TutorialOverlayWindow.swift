import SwiftUI
import UIKit

// MARK: - Passthrough Window

/// A UIWindow that never becomes key and passes all touches through.
final class PassthroughWindow: UIWindow {
    override var canBecomeKey: Bool { false }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        nil
    }
}

// MARK: - Window Controller

/// Manages a transparent UIWindow that renders supplemental tutorial arrows
/// above all other content, including popovers.
final class TutorialOverlayWindowController {
    private var window: PassthroughWindow?

    func show(arrows: [TutorialArrow], frameStore: TutorialSupplementalFrameStore) {
        guard window == nil else { return }

        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
                ?? UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first
        else { return }

        let overlay = PassthroughWindow(windowScene: scene)
        overlay.windowLevel = .alert + 1
        overlay.backgroundColor = .clear
        overlay.isUserInteractionEnabled = false

        let hostingController = UIHostingController(
            rootView: SupplementalArrowOverlayView(
                arrows: arrows,
                frameStore: frameStore
            )
        )
        hostingController.view.backgroundColor = .clear
        overlay.rootViewController = hostingController
        overlay.isHidden = false

        self.window = overlay
    }

    func update(arrows: [TutorialArrow], frameStore: TutorialSupplementalFrameStore) {
        guard let window = window,
              let hc = window.rootViewController as? UIHostingController<SupplementalArrowOverlayView>
        else {
            // Window doesn't exist yet — show it instead
            show(arrows: arrows, frameStore: frameStore)
            return
        }
        hc.rootView = SupplementalArrowOverlayView(arrows: arrows, frameStore: frameStore)
    }

    func hide() {
        window?.isHidden = true
        window?.rootViewController = nil
        window = nil
    }

    var isVisible: Bool { window != nil && window?.isHidden == false }

    deinit {
        hide()
    }
}

// MARK: - Arrow Overlay View

/// SwiftUI view rendered inside the overlay window. Since the window is
/// full-screen, global coordinates from the frame store map directly.
struct SupplementalArrowOverlayView: View {
    let arrows: [TutorialArrow]
    @ObservedObject var frameStore: TutorialSupplementalFrameStore
    @State private var visibleArrows = 0
    @State private var arrowAnimationId = UUID()

    var body: some View {
        GeometryReader { proxy in
            let isLandscape = proxy.size.width > proxy.size.height
            let labels = resolvedLabels(isLandscape: isLandscape)

            ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                let visible = visibleArrows >= index + 1

                if let iconName = label.arrow.icon {
                    Image(systemName: iconName)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 2)
                        .scaleEffect(visible ? 1 : 0.3)
                        .opacity(visible ? 1 : 0)
                        .position(label.anchorPoint)

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
                } else {
                    let arrowStart = label.arrowStart(isLandscape: isLandscape)

                    TutorialArrowShape(
                        start: arrowStart,
                        end: label.anchorPoint,
                        curvature: label.arrow.curvature(
                            start: arrowStart,
                            end: label.anchorPoint,
                            isLandscape: isLandscape
                        )
                    )
                    .trim(from: 0, to: visible ? 1 : 0)
                    .stroke(
                        Color.white.opacity(label.arrow.arrowOpacity),
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
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear { animateArrowsIn() }
        .onChange(of: frameStore.frames.count) { _ in
            // Frames arrived after the view appeared — re-trigger animation
            if visibleArrows == 0 {
                animateArrowsIn()
            }
        }
    }

    private func resolvedLabels(isLandscape: Bool) -> [ResolvedLabel] {
        var labels: [ResolvedLabel] = []
        for arrow in arrows {
            guard let targetFrame = frameStore.frames[arrow.element] else { continue }
            let anchorPoint = arrow.resolvedAnchorPoint(in: targetFrame, isLandscape: isLandscape)
            let labelSize = estimatedLabelSize(for: arrow.element.label)
            let labelCenter = arrow.labelCenter(
                anchorPoint: anchorPoint,
                labelSize: labelSize,
                isLandscape: isLandscape
            )
            labels.append(ResolvedLabel(
                arrow: arrow,
                anchorPoint: anchorPoint,
                labelSize: labelSize,
                labelCenter: labelCenter
            ))
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
