# TutorialKit

A lightweight SwiftUI framework for building guided tutorials with animated arrows, blur effects, and popover triggers — all driven by the SwiftUI environment.

## Overview

Define your tutorial steps, then attach them with a single modifier:

```swift
struct MySteps: TutorialStepProvider {
    static var steps: [TutorialStep] { [
        TutorialStep(title: "Welcome", body: "Let's take a tour."),
    ] }
}

ContentView()
    .tutorial(DefaultTutorialOverlay<MySteps>.self, isPresented: $showTutorial)
```

The modifier handles environment injection, frame collection, step management, and overlay presentation. Your app defines the elements, blur regions, and tutorial steps; TutorialKit handles the wiring and rendering.

Under the hood, these building blocks work together through the SwiftUI environment:

| Tool | Purpose |
|------|---------|
| `.tutorial(_:isPresented:onComplete:)` | Attaches a tutorial overlay with full automatic wiring |
| `.captureTutorialFrame(_:)` | Marks a view as a tutorial target |
| `.tutorialBlur(_:)` | Blurs a view when a tutorial step requires it |
| `.tutorialTriggered(_:isPresented:)` | Opens/closes a popover or sheet during a tutorial step |
| `.tutorialAction(_:perform:)` | Runs a callback when a trigger activates/deactivates |
| `.tutorialOverlay()` | Draws arrows inside presented views (popovers, sheets) |

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

Use `.tutorialAction(_:perform:)` for side effects — starting/stopping animations, timers, or other app-state changes during a step:

```swift
InstrumentView()
    .tutorialAction("animateHeadingBug") { isActive in
        if isActive {
            startHeadingBugDemo()   // e.g. start a timer that rotates the bug
        } else {
            stopHeadingBugDemo()
        }
    }
```

The action fires once when the trigger activates and once when it deactivates (step change or tutorial end).

## Step 5 — Define Tutorial Steps

Build your tutorial as a `TutorialStepProvider`:

```swift
struct MyTutorialSteps: TutorialStepProvider {
    static var steps: [TutorialStep] { [
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
    ] }
}
```

### Custom Card Content

For steps that need custom buttons or layout (e.g. an upsell or a final "done" step), use `centered` and `cardContent`. The closure receives a `TutorialActions` value with `advance` and `dismiss` methods:

```swift
TutorialStep(
    title: "You're All Set!",
    body: "Ready to go.",
    blurTargets: [.map, .instrument],
    centered: true,
    cardContent: { actions in
        AnyView(
            VStack(spacing: 12) {
                Text("Enjoy the app!")
                    .foregroundColor(.white.opacity(0.85))

                Button("Let's Go") { actions.dismiss() }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.green)
                    .clipShape(Capsule())
            }
        )
    }
)
```

When `cardContent` is `nil` (the default), `DefaultTutorialOverlay` renders the body text with Skip/Next buttons automatically.

### Tags

Use `tags` for app-specific metadata that doesn't affect TutorialKit's rendering:

```swift
TutorialStep(
    title: "Unlock Pro",
    body: "...",
    tags: ["upsell"],
    // ...
)
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

## Step 6 — Attach the Tutorial

One modifier does everything:

```swift
struct ContentView: View {
    @State private var showTutorial = false

    var body: some View {
        MainContent()
            .tutorial(DefaultTutorialOverlay<MyTutorialSteps>.self, isPresented: $showTutorial) {
                print("Tutorial complete!")
            }
    }
}
```

`DefaultTutorialOverlay` renders the overlay background, animated arrows with collision-resolved labels, and a card with your step content. For standard steps it provides Skip/Next navigation automatically.

The `.tutorial()` modifier:
- Injects `activeTutorialBlurTargets`, `activeTutorialTriggers`, and `activeSupplementalArrows` into the environment
- Collects element frames via `TutorialFramePreferenceKey`
- Manages the step index (resets to 0 on each presentation)
- Presents and dismisses the overlay
- Calls `onComplete` when the tutorial ends

When `isPresented` is `false`, all environment values return to their defaults and every modifier deactivates automatically.

---

## Advanced: Custom Overlay View

If `DefaultTutorialOverlay` doesn't fit your needs, you can build a fully custom overlay by conforming to `TutorialOverlay` directly. You still get all the environment wiring from the `.tutorial()` modifier — you just control the rendering yourself.

TutorialKit provides reusable building blocks you can compose in your custom overlay:

| Component | Purpose |
|-----------|---------|
| `TutorialArrowLayer` | Renders arrows with labels, staggered animation, and collision resolution. |
| `TutorialCard` | Dark card chrome with title, rounded corners, and a content slot. |
| `TutorialCardPlacement` | Computes card position opposite the centroid of arrow targets. |
| `TutorialCardSizeKey` | Preference key for measuring rendered card size. |
| `TutorialArrowShape` | The raw arrow `Shape`, for fully custom drawing. |
| `ResolvedLabel` | Label with computed position. Use `resolveOverlaps` to prevent collisions. |

```swift
struct MyCustomOverlay: TutorialOverlay {
    @Binding var stepIndex: Int
    let frames: [TutorialElement: CGRect]
    let dismiss: () -> Void

    static var steps: [TutorialStep] { MyTutorialSteps.steps }

    var body: some View {
        GeometryReader { proxy in
            let origin = proxy.frame(in: .global).origin
            let container = CGRect(origin: .zero, size: proxy.size)
            let localFrames = frames.mapValues { rect in
                CGRect(
                    x: rect.minX - origin.x, y: rect.minY - origin.y,
                    width: rect.width, height: rect.height
                )
            }
            let step = Self.steps[stepIndex]

            ZStack {
                Color.black.opacity(0.35).ignoresSafeArea()

                // Use the built-in arrow layer...
                TutorialArrowLayer(
                    arrows: step.arrows,
                    frames: localFrames,
                    cardRect: /* your card rect */,
                    isLandscape: container.width > container.height,
                    stepIndex: stepIndex
                )

                // ...or draw arrows manually with TutorialArrowShape
                // ...with your own card design
            }
        }
    }
}
```

### Custom Step Types

If `TutorialStep` doesn't have enough fields for your custom overlay, define a type conforming to `TutorialStepProviding`:

```swift
struct MyCustomStep: TutorialStepProviding {
    let title: String
    let body: String
    let arrows: [TutorialArrow]
    let blurTargets: TutorialBlurTargets
    var supplementalArrows: [TutorialArrow] = []
    var triggers: [String] = []

    // Your extra fields:
    var showConfetti: Bool = false
}

struct MyOverlay: TutorialOverlay {
    @Binding var stepIndex: Int
    let frames: [TutorialElement: CGRect]
    let dismiss: () -> Void

    // Associated type inferred as MyCustomStep
    static var steps: [MyCustomStep] { /* ... */ }

    var body: some View { /* ... */ }
}
```

### Manual Environment Injection

If you need more control than the `.tutorial()` modifier provides, you can inject the environment values yourself:

```swift
struct ContentView: View {
    @State private var stepIndex = 0
    @State private var showTutorial = false

    var body: some View {
        ZStack {
            MainContent()

            if showTutorial {
                MyOverlayView(
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

---

## Architecture

```
┌───────────────────────────────────────────────────┐
│  Root View                                         │
│  .tutorial(DefaultTutorialOverlay<S>.self, ...)    │
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
│  │ DefaultTutorialOverlay (or custom overlay)  │  │
│  │ ├─ TutorialArrowLayer (arrows + labels)     │  │
│  │ ├─ TutorialCard (title + content)           │  │
│  │ └─ TutorialCardPlacement (positioning)      │  │
│  └─────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────┘
```

### Data Flow

1. **Frame capture**: `.captureTutorialFrame()` reports each element's global frame via a `PreferenceKey`. The overlay view receives these frames from the modifier.

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

### Protocols

| Protocol | Description |
|----------|-------------|
| `TutorialStepProviding` | Exposes `blurTargets`, `triggers`, and `supplementalArrows` for environment injection. |
| `TutorialStepProvider` | Provides `static var steps: [TutorialStep]` for use with `DefaultTutorialOverlay`. |
| `TutorialOverlay` | A `View` with `static var steps` and a standard init. Enables the `.tutorial()` modifier. |

### Types

| Type | Description |
|------|-------------|
| `TutorialElement` | Identifies a targetable UI element (id + label). |
| `TutorialBlurTargets` | `OptionSet` identifying blurrable UI regions. |
| `TutorialArrow` | Describes an arrow: target element, anchors, length, angle, bend. |
| `TutorialArrowShape` | A SwiftUI `Shape` that draws a curved arrow with arrowhead. |
| `TutorialStep` | A tutorial step: title, body, arrows, blur targets, triggers, tags, centered, cardContent. Conforms to `TutorialStepProviding`. |
| `TutorialActions` | Advance and dismiss closures passed to custom `cardContent`. |
| `DefaultTutorialOverlay` | Ready-to-use overlay with arrows, card, and Skip/Next navigation. Generic over a `TutorialStepProvider`. |
| `TutorialArrowLayer` | Renders arrows with labels, staggered animation, and collision resolution. |
| `TutorialCard` | Dark card chrome with title and a `@ViewBuilder` content slot. |
| `TutorialCardPlacement` | Computes card position opposite the centroid of arrow targets. |
| `TutorialCardSizeKey` | Preference key for measuring rendered card size. |
| `ResolvedLabel` | A label with computed position. Use `resolveOverlaps` to prevent collisions. |
| `LayoutPair<T>` | Holds portrait and landscape variants of a value. |
| `ElementAnchor` | Edge/corner positions on a rect (`.top`, `.bottomLeading`, `.alongTop(0.3)`, etc.). |

### View Modifiers

| Modifier | Description |
|----------|-------------|
| `.tutorial(_:isPresented:onComplete:)` | Attaches a `TutorialOverlay` with full automatic wiring. |
| `.captureTutorialFrame(_:)` | Reports the view's frame for arrow targeting. |
| `.tutorialBlur(_:)` | Applies blur when the target is in the active set. |
| `.tutorialTriggered(_:isPresented:)` | Binds a presentation to a tutorial trigger string. |
| `.tutorialAction(_:perform:)` | Runs a callback when a trigger activates or deactivates. |
| `.tutorialOverlay()` | Draws supplemental arrows inside the modified view. |

### Environment Values

| Key Path | Type | Description |
|----------|------|-------------|
| `\.activeTutorialBlurTargets` | `TutorialBlurTargets` | Which regions should blur. |
| `\.activeTutorialTriggers` | `Set<String>` | Which triggers are active. |
| `\.activeSupplementalArrows` | `[TutorialArrow]` | Arrows for supplemental overlays. |
