import CoreGraphics

func tutorialRectsApproximatelyEqual(_ lhs: CGRect, _ rhs: CGRect, tolerance: CGFloat = 0.5) -> Bool {
    abs(lhs.minX - rhs.minX) <= tolerance &&
    abs(lhs.minY - rhs.minY) <= tolerance &&
    abs(lhs.width - rhs.width) <= tolerance &&
    abs(lhs.height - rhs.height) <= tolerance
}

func tutorialFrameDictionariesApproximatelyEqual<K: Hashable>(
    _ lhs: [K: CGRect],
    _ rhs: [K: CGRect],
    tolerance: CGFloat = 0.5
) -> Bool {
    guard lhs.count == rhs.count else { return false }
    for (key, leftRect) in lhs {
        guard let rightRect = rhs[key], tutorialRectsApproximatelyEqual(leftRect, rightRect, tolerance: tolerance) else {
            return false
        }
    }
    return true
}
