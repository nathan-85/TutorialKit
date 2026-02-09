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

    public init(
        _ element: TutorialElement,
        anchor: ElementAnchor = .top,          anchorH: ElementAnchor? = nil,
        fromAnchor: ElementAnchor? = nil,      fromAnchorH: ElementAnchor? = nil,
        length: CGFloat = 50,                  lengthH: CGFloat? = nil,
        angle: CGFloat? = nil,                 angleH: CGFloat? = nil,
        textAlignment: TextAlignment = .center, textAlignmentH: TextAlignment? = nil,
        bend: ArrowBend = .auto,
        bendStrength: ArrowBendStrength = .medium
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
        let anchorOffset = fromAnchor.resolved(isLandscape).point(in: centeredRect)
        return CGPoint(
            x: start.x - anchorOffset.x,
            y: start.y - anchorOffset.y
        )
    }
}
