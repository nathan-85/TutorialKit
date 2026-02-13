import SwiftUI

/// Controls which direction the arrow curves between its start and end points.
public enum ArrowBend {
    /// Computed from the anchor's outward direction.
    case auto
    /// Curve left of the start-to-end direction.
    case left
    /// Curve right of the start-to-end direction.
    case right
    /// Straight line (no curve).
    case none
}

/// Controls how much the arrow curves.
public enum ArrowBendStrength {
    case low, medium, high

    public var magnitude: CGFloat {
        switch self {
        case .low:    return 0.1
        case .medium: return 0.4
        case .high:   return 0.85
        }
    }
}

/// Describes a single tutorial arrow: which element it targets, where it anchors,
/// how long the stem is, and how the label is positioned.
public struct TutorialArrow {
    public let element: TutorialElement
    public let anchor: LayoutPair<ElementAnchor>
    public let fromAnchor: LayoutPair<ElementAnchor>
    public let length: LayoutPair<CGFloat>
    public let angle: LayoutPair<CGFloat>
    public let textAlignment: LayoutPair<TextAlignment>
    public let bend: ArrowBend
    public let bendStrength: ArrowBendStrength
    /// Opacity of the arrow stroke (0–1). Does not affect the text label.
    public let arrowOpacity: CGFloat
    /// Optional SF Symbol name. When set, renders the icon at the anchor point
    /// instead of the arrow line and text label.
    public let icon: String?
    /// Background style used for the arrow label pill.
    public let labelBackgroundStyle: AnyShapeStyle
    /// Point offset applied to the resolved anchor position.
    public let anchorOffset: LayoutPair<CGPoint>

    public init(
        _ element: TutorialElement,
        anchor: ElementAnchor = .top,          anchorH: ElementAnchor? = nil,
        fromAnchor: ElementAnchor? = nil,      fromAnchorH: ElementAnchor? = nil,
        length: CGFloat = 50,                  lengthH: CGFloat? = nil,
        angle: CGFloat? = nil,                 angleH: CGFloat? = nil,
        textAlignment: TextAlignment = .center, textAlignmentH: TextAlignment? = nil,
        bend: ArrowBend = .auto,
        bendStrength: ArrowBendStrength = .medium,
        arrowOpacity: CGFloat = 1.0,
        icon: String? = nil,
        labelBackgroundStyle: AnyShapeStyle = AnyShapeStyle(.ultraThinMaterial),
        anchorOffset: CGPoint = .zero,         anchorOffsetH: CGPoint? = nil
    ) {
        self.element = element

        let hAnchor = anchorH ?? anchor
        self.anchor = LayoutPair(v: anchor, h: hAnchor)

        self.fromAnchor = LayoutPair(
            v: fromAnchor ?? anchor.opposite,
            h: fromAnchorH ?? fromAnchor ?? hAnchor.opposite
        )

        self.length = LayoutPair(v: length, h: lengthH ?? length)

        self.angle = LayoutPair(
            v: angle ?? anchor.defaultAngle,
            h: angleH ?? angle ?? hAnchor.defaultAngle
        )

        self.textAlignment = LayoutPair(v: textAlignment, h: textAlignmentH ?? textAlignment)
        self.bend = bend
        self.bendStrength = bendStrength
        self.arrowOpacity = arrowOpacity
        self.icon = icon
        self.labelBackgroundStyle = labelBackgroundStyle
        self.anchorOffset = LayoutPair(v: anchorOffset, h: anchorOffsetH ?? anchorOffset)
    }

    /// Convenience initializer that accepts any concrete `ShapeStyle` without requiring
    /// callers to wrap it in `AnyShapeStyle`.
    public init<S: ShapeStyle>(
        _ element: TutorialElement,
        anchor: ElementAnchor = .top,          anchorH: ElementAnchor? = nil,
        fromAnchor: ElementAnchor? = nil,      fromAnchorH: ElementAnchor? = nil,
        length: CGFloat = 50,                  lengthH: CGFloat? = nil,
        angle: CGFloat? = nil,                 angleH: CGFloat? = nil,
        textAlignment: TextAlignment = .center, textAlignmentH: TextAlignment? = nil,
        bend: ArrowBend = .auto,
        bendStrength: ArrowBendStrength = .medium,
        arrowOpacity: CGFloat = 1.0,
        icon: String? = nil,
        labelBackgroundStyle: S,
        anchorOffset: CGPoint = .zero,         anchorOffsetH: CGPoint? = nil
    ) {
        self.init(
            element,
            anchor: anchor, anchorH: anchorH,
            fromAnchor: fromAnchor, fromAnchorH: fromAnchorH,
            length: length, lengthH: lengthH,
            angle: angle, angleH: angleH,
            textAlignment: textAlignment, textAlignmentH: textAlignmentH,
            bend: bend,
            bendStrength: bendStrength,
            arrowOpacity: arrowOpacity,
            icon: icon,
            labelBackgroundStyle: AnyShapeStyle(labelBackgroundStyle),
            anchorOffset: anchorOffset, anchorOffsetH: anchorOffsetH
        )
    }

    /// Resolves the anchor point in the given frame, applying ``anchorOffset``.
    public func resolvedAnchorPoint(in frame: CGRect, isLandscape: Bool) -> CGPoint {
        let base = anchor.resolved(isLandscape).point(in: frame)
        let off = anchorOffset.resolved(isLandscape)
        return CGPoint(x: base.x + off.x, y: base.y + off.y)
    }

    /// The point where the arrow tail meets the label — exactly ``length`` from the element anchor.
    public func arrowStart(anchorPoint: CGPoint, isLandscape: Bool) -> CGPoint {
        let radians = angle.resolved(isLandscape) * .pi / 180
        return CGPoint(
            x: anchorPoint.x - sin(radians) * length.resolved(isLandscape),
            y: anchorPoint.y + cos(radians) * length.resolved(isLandscape)
        )
    }

    /// Signed curvature that bows the curve away from the element body.
    public func curvature(start: CGPoint, end: CGPoint, isLandscape: Bool) -> CGFloat {
        let mag = bendStrength.magnitude
        switch bend {
        case .none:  return 0
        case .left:  return mag
        case .right: return -mag
        case .auto:
            let dx = end.x - start.x
            let dy = end.y - start.y
            let distance = max(1, hypot(dx, dy))
            let perpX = -dy / distance
            let perpY = dx / distance
            let outward = anchor.resolved(isLandscape).outwardDirection
            let dot = perpX * outward.x + perpY * outward.y
            return dot >= 0 ? mag : -mag
        }
    }

    /// Label center, positioned so that its ``fromAnchor`` edge sits at ``arrowStart``.
    public func labelCenter(anchorPoint: CGPoint, labelSize: CGSize, isLandscape: Bool) -> CGPoint {
        let start = arrowStart(anchorPoint: anchorPoint, isLandscape: isLandscape)
        let centeredRect = CGRect(x: -labelSize.width / 2, y: -labelSize.height / 2, width: labelSize.width, height: labelSize.height)
        let fromPoint = fromAnchor.resolved(isLandscape).point(in: centeredRect)
        return CGPoint(
            x: start.x - fromPoint.x,
            y: start.y - fromPoint.y
        )
    }
}
