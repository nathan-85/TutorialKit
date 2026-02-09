# TutorialKit

A lightweight SwiftUI framework for building guided tutorials with animated arrows, blur effects, and popover triggers — all driven by the SwiftUI environment.

## Overview

TutorialKit provides five building blocks that work together through the SwiftUI environment:

| Tool | Purpose |
|------|---------|
| `.captureTutorialFrame(_:)` | Marks a view as a tutorial target |
| `.tutorialBlur(_:)` | Blurs a view when a tutorial step requires it |
| `.tutorialTriggered(_:isPresented:)` | Opens/closes a popover or sheet during a tutorial step |
| `.tutorialOverlay()` | Draws arrows inside presented views (popovers, sheets) |
| `TutorialArrowShape` | The arrow shape, for use in custom overlay views |

Your app defines what the elements, blur regions, and tutorial steps are. TutorialKit handles the rendering, layout, and coordination.

---

## Adding TutorialKit to Your Project

1. Copy the `TutorialKit/` directory into your project root.
2. In Xcode, choose **File > Add Package Dependencies**.
3. Click **Add Local**, then select the `TutorialKit` directory.
4. Add `TutorialKit` to your app target.

---

## Step 1 — Define Your Elements

A `TutorialElement` identifies a UI element that tutorial arrows can target. Define them as static properties:

```swift
import TutorialKit

extension TutorialElement {
    // Map controls
    static let mapView     = TutorialElement("Approach Plate")
    static let speedButton = TutorialElement("Adjustable Speed")
    static let windButton  = TutorialElement("Wind")

    // Instrument controls
    static let settingsButton = TutorialElement("Settings")
    static let courseLabel     = TutorialElement("Tap to adjust course.")

    // When the ID should differ from the display label:
    static let headingBug = TutorialElement(
        id: "headingBug",
        label: "Drag heading bug\nto make aircraft turn"
    )
}
```

## Step 2 — Define Your Blur Targets

`TutorialBlurTargets` is an `OptionSet` that identifies regions of your UI. Define the targets your app needs:

```swift
extension TutorialBlurTargets {
    static let map        = TutorialBlurTargets(rawValue: 1 << 0)
    static let instrument = TutorialBlurTargets(rawValue: 1 << 1)
    static let sidebar    = TutorialBlurTargets(rawValue: 1 << 2)
}
```

## Step 3 — Mark Views as Tutorial Targets

Use `.captureTutorialFrame(_:)` on any view you want arrows to point at:

```swift
Button("Settings") { showSettings = true }
    .captureTutorialFrame(.settingsButton)

Slider(value: $speed)
    .captureTutorialFrame(.speedSlider)
```

The modifier is invisible and has zero overhead when no tutorial is active. It is safe to leave on views permanently.

## Step 4 — Apply Blur and Trigger Modifiers

Use `.tutorialBlur(_:)` on views that should blur during certain tutorial steps:

```swift
MapView()
    .tutorialBlur(.map)

InstrumentPanel()
    .tutorialBlur(.instrument)
```

Use `.tutorialTriggered(_:isPresented:)` on views that should auto-present content during a tutorial step:

```swift
// The popover opens automatically when the "showSettings" trigger is active.
SomeView()
    .popover(isPresented: $showSettings) {
        SettingsView()
            .tutorialOverlay()   // draws supplemental arrows inside the popover
    }
    .tutorialTriggered("showSettings", isPresented: $showSettings)
```

## Step 5 — Define Tutorial Steps

Build your tutorial as an array of `TutorialStep` values:

```swift
let tutorialSteps: [TutorialStep] = [
    TutorialStep(
        title: "Welcome",
        body: "Let's take a quick tour.",
        blurTargets: [.map, .instrument]
    ),
    TutorialStep(
        title: "Map View",
        body: "Drag to pan, pinch to zoom.",
        arrows: [
            TutorialArrow(.mapView, anchor: .leading, fromAnchor: .trailing),
            TutorialArrow(.speedButton, anchor: .topTrailing),
            TutorialArrow(.windButton, anchor: .leading),
        ],
        blurTargets: [.instrument]
    ),
    TutorialStep(
        title: "Settings",
        body: "Configure your preferences.",
        arrows: [
            TutorialArrow(.settingsButton, anchor: .bottom, fromAnchor: .top),
        ],
        blurTargets: [.map],
        supplementalArrows: [
            TutorialArrow(.aircraftPicker, anchor: .top, length: 25),
        ],
        triggers: ["showSettings"]
    ),
]
```

### Arrow Parameters

| Parameter | Description |
|-----------|-------------|
| `anchor` | Where the arrowhead connects to the target element's frame. |
| `fromAnchor` | Where the arrow tail originates from the label. Defaults to `anchor.opposite`. |
| `length` | Distance (in points) from the element anchor to the label. |
| `angle` | Compass direction (0 = up, 90 = right) from the label toward the element. |
| `bend` | `.auto`, `.left`, `.right`, or `.none`. |
| `bendStrength` | `.low`, `.medium`, or `.high`. |

Add an `H` suffix for landscape-specific overrides: `anchorH`, `fromAnchorH`, `lengthH`, `angleH`, `textAlignmentH`.

## Step 6 — Inject the Environment

At the root of your view hierarchy, compute the current step's values and inject them:

```swift
struct ContentView: View {
    @State private var stepIndex = 0
    @State private var showTutorial = false

    var body: some View {
        ZStack {
            MainContent()

            if showTutorial {
                TutorialOverlayView(
                    steps: tutorialSteps,
                    stepIndex: $stepIndex,
                    onComplete: { showTutorial = false }
                )
            }
        }
        .environment(\.activeTutorialBlurTargets, currentBlurTargets)
        .environment(\.activeTutorialTriggers, currentTriggers)
        .environment(\.activeSupplementalArrows, currentSupplementalArrows)
    }

    private var currentBlurTargets: TutorialBlurTargets {
        guard showTutorial, stepIndex < tutorialSteps.count else { return [] }
        return tutorialSteps[stepIndex].blurTargets
    }

    private var currentTriggers: Set<String> {
        guard showTutorial, stepIndex < tutorialSteps.count else { return [] }
        return Set(tutorialSteps[stepIndex].triggers)
    }

    private var currentSupplementalArrows: [TutorialArrow] {
        guard showTutorial, stepIndex < tutorialSteps.count else { return [] }
        return tutorialSteps[stepIndex].supplementalArrows
    }
}
```

When `showTutorial` is `false` or the step has no active targets, every modifier returns to its default (no blur, no triggers, no arrows). This makes the system fully self-regulating.

## Step 7 — Build Your Overlay View

TutorialKit provides the building blocks; you build the overlay that shows the tutorial card, buttons, and primary arrows. A minimal example:

```swift
import TutorialKit

struct TutorialOverlayView: View {
    let steps: [TutorialStep]
    @Binding var stepIndex: Int
    let onComplete: () -> Void

    // Collect element frames via preference key
    @State private var frames: [TutorialElement: CGRect] = [:]

    var body: some View {
        GeometryReader { proxy in
            let origin = proxy.frame(in: .global).origin
            let localFrames = frames.mapValues { rect in
                CGRect(
                    x: rect.minX - origin.x,
                    y: rect.minY - origin.y,
                    width: rect.width,
                    height: rect.height
                )
            }
            let step = steps[stepIndex]
            let isLandscape = proxy.size.width > proxy.size.height

            ZStack {
                // Dim background
                Color.black.opacity(0.35)
                    .ignoresSafeArea()

                // Draw arrows for the current step
                ForEach(Array(step.arrows.dropFirst().enumerated()), id: \.offset) { _, arrow in
                    if let targetFrame = localFrames[arrow.element] {
                        let anchorPt = arrow.anchor.resolved(isLandscape).point(in: targetFrame)
                        let labelSize = CGSize(width: 80, height: 24)
                        let labelCenter = arrow.labelCenter(
                            anchorPoint: anchorPt,
                            labelSize: labelSize,
                            isLandscape: isLandscape
                        )
                        let start = arrow.fromAnchor.resolved(isLandscape).point(
                            in: CGRect(
                                x: labelCenter.x - labelSize.width / 2,
                                y: labelCenter.y - labelSize.height / 2,
                                width: labelSize.width,
                                height: labelSize.height
                            ).insetBy(dx: 3, dy: 2)
                        )

                        TutorialArrowShape(
                            start: start,
                            end: anchorPt,
                            curvature: arrow.curvature(
                                start: start,
                                end: anchorPt,
                                isLandscape: isLandscape
                            )
                        )
                        .stroke(Color.white.opacity(0.85), lineWidth: 1.5)

                        Text(arrow.element.label)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .position(labelCenter)
                    }
                }

                // Tutorial card
                VStack(spacing: 12) {
                    Text(step.title).font(.headline).foregroundColor(.white)
                    Text(step.body).font(.subheadline).foregroundColor(.white.opacity(0.85))
                    HStack {
                        Button("Skip") { onComplete() }
                        Spacer()
                        Button("Next") {
                            if stepIndex < steps.count - 1 {
                                stepIndex += 1
                            } else {
                                onComplete()
                            }
                        }
                    }
                }
                .padding()
                .background(Color(white: 0.1))
                .cornerRadius(16)
                .frame(maxWidth: 280)
            }
        }
        .onPreferenceChange(TutorialFramePreferenceKey.self) { frames = $0 }
    }
}
```

Use `ResolvedLabel` and `ResolvedLabel.resolveOverlaps(_:)` for production-quality label placement that avoids overlapping labels. See the HSI app's `FirstFlightOverlayView` for a full reference implementation.

---

## Architecture

```
┌───────────────────────────────────────────────────┐
│  Root View                                         │
│  .environment(\.activeTutorialBlurTargets, ...)    │
│  .environment(\.activeTutorialTriggers, ...)       │
│  .environment(\.activeSupplementalArrows, ...)     │
│                                                    │
│  ┌─────────────┐   ┌───────────────────────────┐  │
│  │ Panel A     │   │ Panel B                    │  │
│  │ .tutorialBlur│   │ .tutorialBlur              │  │
│  │             │   │                            │  │
│  │  ┌────────┐ │   │  ┌────────────────────┐   │  │
│  │  │ Button │ │   │  │ View               │   │  │
│  │  │.capture│ │   │  │.capture            │   │  │
│  │  │.trigger│ │   │  │  .popover {        │   │  │
│  │  └────────┘ │   │  │    Content()       │   │  │
│  └─────────────┘   │  │      .tutorialOverlay│  │  │
│                    │  │  }                  │   │  │
│                    │  └────────────────────┘   │  │
│                    └───────────────────────────┘  │
│                                                    │
│  ┌─────────────────────────────────────────────┐  │
│  │ TutorialOverlayView (your custom view)      │  │
│  │ Reads frames via TutorialFramePreferenceKey  │  │
│  │ Draws primary arrows + card + buttons        │  │
│  └─────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────┘
```

### Data Flow

1. **Frame capture**: `.captureTutorialFrame()` reports each element's global frame via a `PreferenceKey`. The overlay view collects these to know where to draw arrows.

2. **Blur**: `.tutorialBlur(.map)` reads `activeTutorialBlurTargets` from the environment. When `.map` is in the active set, the view blurs. When removed, it clears instantly.

3. **Triggers**: `.tutorialTriggered("showSettings", isPresented: $showSettings)` watches `activeTutorialTriggers`. When `"showSettings"` appears, it sets the binding to `true` after a 0.5s delay. When removed, it sets it to `false`.

4. **Supplemental arrows**: `.tutorialOverlay()` reads `activeSupplementalArrows` from the environment and draws arrows for any elements whose frames have been captured within that view's subtree. This is how arrows appear *inside* popovers and sheets (which have their own presentation context).

### Why Environment?

- **No parameter threading.** Views don't pass tutorial state down through initializers.
- **Popovers inherit the environment.** Presented views automatically receive the tutorial state.
- **Self-regulating.** When the tutorial ends, all environment values return to their defaults and every modifier deactivates.
- **Composable.** Any view in any part of the hierarchy can opt in with a single modifier.

---

## API Reference

### Types

| Type | Description |
|------|-------------|
| `TutorialElement` | Identifies a targetable UI element (id + label). |
| `TutorialBlurTargets` | `OptionSet` identifying blurrable UI regions. |
| `TutorialArrow` | Describes an arrow: target element, anchors, length, angle, bend. |
| `TutorialArrowShape` | A SwiftUI `Shape` that draws a curved arrow with arrowhead. |
| `TutorialStep` | A tutorial step: title, body, arrows, blur targets, triggers. |
| `ResolvedLabel` | A label with computed position. Use `resolveOverlaps` to prevent collisions. |
| `LayoutPair<T>` | Holds portrait and landscape variants of a value. |
| `ElementAnchor` | Edge/corner positions on a rect (`.top`, `.bottomLeading`, `.alongTop(0.3)`, etc.). |

### View Modifiers

| Modifier | Description |
|----------|-------------|
| `.captureTutorialFrame(_:)` | Reports the view's frame for arrow targeting. |
| `.tutorialBlur(_:)` | Applies blur when the target is in the active set. |
| `.tutorialTriggered(_:isPresented:)` | Binds a presentation to a tutorial trigger string. |
| `.tutorialOverlay()` | Draws supplemental arrows inside the modified view. |

### Environment Values

| Key Path | Type | Description |
|----------|------|-------------|
| `\.activeTutorialBlurTargets` | `TutorialBlurTargets` | Which regions should blur. |
| `\.activeTutorialTriggers` | `Set<String>` | Which triggers are active. |
| `\.activeSupplementalArrows` | `[TutorialArrow]` | Arrows for supplemental overlays. |
