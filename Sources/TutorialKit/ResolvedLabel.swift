import SwiftUI

/// A fully resolved label position for a tutorial arrow.
///
/// After resolving, use ``resolveOverlaps(_:padding:)`` to push overlapping labels apart.
public struct ResolvedLabel {
    public let arrow: TutorialArrow
    public let anchorPoint: CGPoint
    public let labelSize: CGSize
    public var labelCenter: CGPoint

    public init(arrow: TutorialArrow, anchorPoint: CGPoint, labelSize: CGSize, labelCenter: CGPoint) {
        self.arrow = arrow
        self.anchorPoint = anchorPoint
        self.labelSize = labelSize
        self.labelCenter = labelCenter
    }

    public var labelRect: CGRect {
        CGRect(
            x: labelCenter.x - labelSize.width / 2,
            y: labelCenter.y - labelSize.height / 2,
            width: labelSize.width,
            height: labelSize.height
        )
    }

    /// The point where the arrow tail meets the label edge, inset slightly for padding.
    public func arrowStart(isLandscape: Bool) -> CGPoint {
        let inset = labelRect.insetBy(dx: 3, dy: 2)
        return arrow.fromAnchor.resolved(isLandscape).point(in: inset)
    }

    /// Iteratively pushes overlapping labels apart along the axis of least overlap.
    public static func resolveOverlaps(_ labels: inout [ResolvedLabel], padding: CGFloat = 4) {
        guard labels.count > 1 else { return }
        for _ in 0..<8 {
            var anyOverlap = false
            for i in 0..<labels.count {
                for j in (i + 1)..<labels.count {
                    let ri = labels[i].labelRect.insetBy(dx: -padding / 2, dy: -padding / 2)
                    let rj = labels[j].labelRect.insetBy(dx: -padding / 2, dy: -padding / 2)
                    let overlap = ri.intersection(rj)
                    guard !overlap.isNull && overlap.width > 0 && overlap.height > 0 else { continue }
                    anyOverlap = true
                    if overlap.width < overlap.height {
                        let push = overlap.width / 2 + 0.5
                        if labels[i].labelCenter.x <= labels[j].labelCenter.x {
                            labels[i].labelCenter.x -= push
                            labels[j].labelCenter.x += push
                        } else {
                            labels[i].labelCenter.x += push
                            labels[j].labelCenter.x -= push
                        }
                    } else {
                        let push = overlap.height / 2 + 0.5
                        if labels[i].labelCenter.y <= labels[j].labelCenter.y {
                            labels[i].labelCenter.y -= push
                            labels[j].labelCenter.y += push
                        } else {
                            labels[i].labelCenter.y += push
                            labels[j].labelCenter.y -= push
                        }
                    }
                }
            }
            if !anyOverlap { break }
        }
    }
}
