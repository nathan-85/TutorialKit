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

    @State private var cardSize = CGSize(width: 280, height: 140)

    public static var steps: [TutorialStep] { Provider.steps }

    public init(stepIndex: Binding<Int>, frames: [TutorialElement: CGRect], dismiss: @escaping () -> Void) {
        self._stepIndex = stepIndex
        self.frames = frames
        self.dismiss = dismiss
    }

    public var body: some View {
        GeometryReader { proxy in
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
            let step = currentStep
            let cardCenter = TutorialCardPlacement.position(
                for: step.arrows,
                in: localFrames,
                container: container
            )
            let cardRect = CGRect(
                x: cardCenter.x - cardSize.width / 2,
                y: cardCenter.y - cardSize.height / 2,
                width: cardSize.width,
                height: cardSize.height
            )

            ZStack {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()

                TutorialArrowLayer(
                    arrows: step.arrows,
                    frames: localFrames,
                    cardRect: cardRect,
                    isLandscape: container.width > container.height,
                    stepIndex: stepIndex
                )

                cardView(for: step)
                    .background(
                        GeometryReader { inner in
                            Color.clear.preference(key: TutorialCardSizeKey.self, value: inner.size)
                        }
                    )
                    .position(cardCenter)
                    .animation(.spring(response: 0.45, dampingFraction: 0.85), value: stepIndex)
            }
            .contentShape(Rectangle())
            .onTapGesture {}
            .onAppear {
                stepIndex = min(stepIndex, Self.steps.count - 1)
            }
            .onPreferenceChange(TutorialCardSizeKey.self) { newSize in
                if newSize != .zero {
                    cardSize = newSize
                }
            }
        }
        .transition(.opacity)
    }

    private var currentStep: TutorialStep {
        let steps = Self.steps
        if stepIndex >= 0 && stepIndex < steps.count {
            return steps[stepIndex]
        }
        return steps[0]
    }

    private func cardView(for step: TutorialStep) -> some View {
        let actions = TutorialActions(advance: advance, dismiss: finish)

        return TutorialCard(title: step.title, centered: step.centered) {
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
        }
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
}
