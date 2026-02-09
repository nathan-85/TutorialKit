import SwiftUI

/// A `Shape` that draws a curved arrow with an arrowhead at the end point.
public struct TutorialArrowShape: Shape {
    public var start: CGPoint
    public var end: CGPoint
    public var curvature: CGFloat

    public init(start: CGPoint, end: CGPoint, curvature: CGFloat = 0.25) {
        self.start = start
        self.end = end
        self.curvature = curvature
    }

    public func path(in rect: CGRect) -> Path {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let distance = max(1.0, hypot(dx, dy))
        let perpX = -dy / distance
        let perpY = dx / distance

        let curveOffset = curvature * min(distance, 240)
        let control = CGPoint(
            x: (start.x + end.x) / 2 + perpX * curveOffset,
            y: (start.y + end.y) / 2 + perpY * curveOffset
        )

        var path = Path()

        // Curved line
        path.move(to: start)
        path.addQuadCurve(to: end, control: control)

        // Arrowhead — tangent at t=1 of the quad bezier is (end - control)
        let tangentX = end.x - control.x
        let tangentY = end.y - control.y
        let angle = atan2(tangentY, tangentX)

        let headLength: CGFloat = max(10, min(16, distance * 0.12))
        let headAngle: CGFloat = .pi / 5

        let left = CGPoint(
            x: end.x + cos(angle + .pi - headAngle) * headLength,
            y: end.y + sin(angle + .pi - headAngle) * headLength
        )
        let right = CGPoint(
            x: end.x + cos(angle + .pi + headAngle) * headLength,
            y: end.y + sin(angle + .pi + headAngle) * headLength
        )

        path.move(to: left)
        path.addLine(to: end)
        path.addLine(to: right)

        return path
    }
}
