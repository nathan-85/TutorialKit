import SwiftUI

/// A type that provides the steps for a ``DefaultTutorialOverlay``.
///
/// Define your steps and use `DefaultTutorialOverlay<YourProvider>.self`
/// with the `.tutorial()` modifier:
/// ```swift
/// struct MyTutorialSteps: TutorialStepProvider {
///     static var steps: [TutorialStep] { [
///         TutorialStep(title: "Welcome", body: "Let's take a tour."),
///     ] }
/// }
///
/// ContentView()
///     .tutorial(DefaultTutorialOverlay<MyTutorialSteps>.self, isPresented: $show)
/// ```
@MainActor
public protocol TutorialStepProvider {
    static var steps: [TutorialStep] { get }
}

/// A ready-to-use tutorial overlay that renders arrows, labels, and a card.
///
/// For standard steps it shows title, body, and Skip/Next buttons.
/// Steps with ``TutorialStep/cardContent`` get fully custom rendering below the title.
public struct DefaultTutorialOverlay<Provider: TutorialStepProvider>: TutorialOverlay {
    public typealias Step = TutorialStep

    @Binding var stepIndex: Int
    let frames: [TutorialElement: CGRect]
    let dismiss: () -> Void
    @Environment(\.tutorialDimmingStyle) private var dimmingStyle

    @State private var cardSize = CGSize(width: 280, height: 140)
    @State private var lastRenderedStepIndex = 0
    @State private var previousStepIndex: Int?
    @State private var clearPreviousTask: Task<Void, Never>?
    @Namespace private var cardMorphNamespace

    public static var steps: [TutorialStep] { Provider.steps }

    public init(stepIndex: Binding<Int>, frames: [TutorialElement: CGRect], dismiss: @escaping () -> Void) {
        self._stepIndex = stepIndex
        self.frames = frames
        self.dismiss = dismiss
    }

    public var body: some View {
        GeometryReader { proxy in
            let allSteps = Self.steps
            let globalOrigin = proxy.frame(in: .global).origin
            let container = CGRect(origin: .zero, size: proxy.size)
            let localFrames = frames.mapValues { rect in
                CGRect(
                    x: rect.minX - globalOrigin.x,
                    y: rect.minY - globalOrigin.y,
                    width: rect.width,
                    height: rect.height
                )
            }
            if allSteps.isEmpty {
                Color.clear
                    .ignoresSafeArea()
                    .onAppear { finish() }
            } else {
                let clampedStepIndex = clampIndex(stepIndex, in: allSteps)
                let step = allSteps[clampedStepIndex]
                let previousStep = previousStepIndex.flatMap { index -> TutorialStep? in
                    guard index >= 0 && index < allSteps.count else { return nil }
                    return allSteps[index]
                }
                let isLandscape = container.width > container.height
                let cardCenter = resolvedCardCenter(
                    for: step,
                    isLandscape: isLandscape,
                    container: container,
                    localFrames: localFrames
                )
                let cardRect = CGRect(
                    x: cardCenter.x - cardSize.width / 2,
                    y: cardCenter.y - cardSize.height / 2,
                    width: cardSize.width,
                    height: cardSize.height
                )

                ZStack {
                    // Touch-blocking layer — absorbs all touches except over passthrough element frames
                    let cutouts = step.passthroughElements.compactMap { localFrames[$0] }
                    Color.clear
                        .contentShape(
                            RectWithCutouts(cutouts: cutouts),
                            eoFill: true
                        )
                        .onTapGesture {}

                    dimmingStyle.color
                        .opacity(dimmingStyle.opacity)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)

                    TutorialArrowLayer(
                        arrows: step.arrows,
                        frames: localFrames,
                        cardRect: cardRect,
                        isLandscape: isLandscape,
                        stepIndex: clampedStepIndex
                    )
                    .allowsHitTesting(false)

                    ZStack {
                        if let previousStep {
                            let previousCenter = resolvedCardCenter(
                                for: previousStep,
                                isLandscape: isLandscape,
                                container: container,
                                localFrames: localFrames
                            )
                            cardView(for: previousStep)
                                .position(previousCenter)
                                .matchedGeometryEffect(id: "tutorial-card", in: cardMorphNamespace, isSource: true)
                                .opacity(0.001)
                                .allowsHitTesting(false)
                        }

                        cardView(for: step)
                            .background(
                                GeometryReader { inner in
                                    Color.clear.preference(key: TutorialCardSizeKey.self, value: inner.size)
                                }
                            )
                            .position(cardCenter)
                            .matchedGeometryEffect(id: "tutorial-card", in: cardMorphNamespace, isSource: false)
                            .transition(.opacity)
                    }
                    .animation(.spring(response: 0.45, dampingFraction: 0.85), value: clampedStepIndex)
                }
                .onAppear {
                    let clamped = min(stepIndex, allSteps.count - 1)
                    stepIndex = clamped
                    lastRenderedStepIndex = clamped
                }
                .onChange(of: stepIndex) { newValue in
                    let clamped = clampIndex(newValue, in: allSteps)
                    guard clamped != lastRenderedStepIndex else { return }
                    previousStepIndex = lastRenderedStepIndex
                    lastRenderedStepIndex = clamped
                    schedulePreviousCardCleanup()
                }
                .onPreferenceChange(TutorialCardSizeKey.self) { newSize in
                    if newSize != .zero && !sizesApproximatelyEqual(cardSize, newSize) {
                        cardSize = newSize
                    }
                }
                .onDisappear {
                    clearPreviousTask?.cancel()
                    clearPreviousTask = nil
                }
            }
        }
        .transition(.opacity)
    }

    private func currentStep(in steps: [TutorialStep]) -> TutorialStep {
        if stepIndex >= 0 && stepIndex < steps.count {
            return steps[stepIndex]
        }
        return steps[0]
    }

    private func cardView(for step: TutorialStep) -> AnyView {
        let actions = TutorialActions(advance: advance, dismiss: finish)

        let card = AnyView(TutorialCard(title: step.title, centered: step.centered) {
            if let customContent = step.cardContent {
                customContent(actions)
            } else {
                Text(step.body)
                    .font(.system(size: 14))
                    .foregroundColor(Color.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(step.centered ? .center : .leading)

                HStack {
                    Button("Skip") {
                        finish()
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.7))

                    Spacer()

                    Button("Next") {
                        advance()
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .clipShape(Capsule())
                    .accessibilityIdentifier("TutorialNextButton")
                }
            }
        })
        return card
    }

    private func advance() {
        if stepIndex < Self.steps.count - 1 {
            stepIndex += 1
        } else {
            finish()
        }
    }

    private func finish() {
        withAnimation(.easeInOut(duration: 0.3)) {
            dismiss()
        }
    }

    private func schedulePreviousCardCleanup() {
        clearPreviousTask?.cancel()
        clearPreviousTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 300_000_000)
            } catch {
                return
            }
            previousStepIndex = nil
        }
    }

    private func clampIndex(_ index: Int, in steps: [TutorialStep]) -> Int {
        guard !steps.isEmpty else { return 0 }
        return min(max(index, 0), steps.count - 1)
    }

    private func resolvedCardCenter(
        for step: TutorialStep,
        isLandscape: Bool,
        container: CGRect,
        localFrames: [TutorialElement: CGRect]
    ) -> CGPoint {
        let resolvedPosition = isLandscape ? (step.landscapePosition ?? step.position) : step.position
        let rawCenter: CGPoint = if let pos = resolvedPosition {
            CGPoint(x: container.width * pos.width, y: container.height * pos.height)
        } else {
            TutorialCardPlacement.position(
                for: step.arrows,
                in: localFrames,
                container: container
            )
        }
        return clampedCardCenter(rawCenter, in: container)
    }

    private func clampedCardCenter(_ center: CGPoint, in container: CGRect) -> CGPoint {
        let insetX = max(cardSize.width / 2 + 8, 8)
        let insetY = max(cardSize.height / 2 + 8, 8)
        let minX = container.minX + insetX
        let maxX = container.maxX - insetX
        let minY = container.minY + insetY
        let maxY = container.maxY - insetY
        return CGPoint(
            x: min(max(center.x, minX), maxX),
            y: min(max(center.y, minY), maxY)
        )
    }

    private func sizesApproximatelyEqual(_ lhs: CGSize, _ rhs: CGSize, tolerance: CGFloat = 0.5) -> Bool {
        abs(lhs.width - rhs.width) <= tolerance &&
        abs(lhs.height - rhs.height) <= tolerance
    }
}

/// A shape that fills its bounds with rectangular cutouts removed (using even-odd fill).
private struct RectWithCutouts: Shape {
    let cutouts: [CGRect]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        for cutout in cutouts {
            path.addRect(cutout)
        }
        return path
    }
}
