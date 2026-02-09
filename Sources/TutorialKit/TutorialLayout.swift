import SwiftUI

/// Specifies where an arrow connects to (or originates from) a target element's frame.
public enum ElementAnchor {
    case top, bottom, leading, trailing, center
    case topLeading, topTrailing
    case bottomLeading, bottomTrailing
    /// Percentage (0-1) along an edge: left-to-right for top/bottom, top-to-bottom for leading/trailing.
    case alongTop(CGFloat)
    case alongBottom(CGFloat)
    case alongLeading(CGFloat)
    case alongTrailing(CGFloat)

    /// Default arrow angle (compass degrees, 0 = north/up, clockwise).
    public var defaultAngle: CGFloat {
        switch self {
        case .top, .alongTop:           return 180
        case .bottom, .alongBottom:     return 0
        case .leading, .alongLeading:   return 90
        case .trailing, .alongTrailing: return 270
        case .center:                   return 180
        case .topLeading:               return 135
        case .topTrailing:              return 225
        case .bottomLeading:            return 45
        case .bottomTrailing:           return 315
        }
    }

    /// The anchor on the opposite side.
    public var opposite: ElementAnchor {
        switch self {
        case .top:                  return .bottom
        case .bottom:               return .top
        case .leading:              return .trailing
        case .trailing:             return .leading
        case .center:               return .center
        case .topLeading:           return .bottomTrailing
        case .topTrailing:          return .bottomLeading
        case .bottomLeading:        return .topTrailing
        case .bottomTrailing:       return .topLeading
        case .alongTop(let p):      return .alongBottom(p)
        case .alongBottom(let p):   return .alongTop(p)
        case .alongLeading(let p):  return .alongTrailing(p)
        case .alongTrailing(let p): return .alongLeading(p)
        }
    }

    /// Unit vector pointing outward from the element at this anchor.
    public var outwardDirection: CGPoint {
        switch self {
        case .top, .alongTop:           return CGPoint(x: 0, y: -1)
        case .bottom, .alongBottom:     return CGPoint(x: 0, y: 1)
        case .leading, .alongLeading:   return CGPoint(x: -1, y: 0)
        case .trailing, .alongTrailing: return CGPoint(x: 1, y: 0)
        case .center:                   return CGPoint(x: 0, y: -1)
        case .topLeading:               return CGPoint(x: -0.707, y: -0.707)
        case .topTrailing:              return CGPoint(x: 0.707, y: -0.707)
        case .bottomLeading:            return CGPoint(x: -0.707, y: 0.707)
        case .bottomTrailing:           return CGPoint(x: 0.707, y: 0.707)
        }
    }

    /// The anchor point on a given rect.
    public func point(in rect: CGRect) -> CGPoint {
        switch self {
        case .top:                  return CGPoint(x: rect.midX, y: rect.minY)
        case .bottom:               return CGPoint(x: rect.midX, y: rect.maxY)
        case .leading:              return CGPoint(x: rect.minX, y: rect.midY)
        case .trailing:             return CGPoint(x: rect.maxX, y: rect.midY)
        case .center:               return CGPoint(x: rect.midX, y: rect.midY)
        case .topLeading:           return CGPoint(x: rect.minX, y: rect.minY)
        case .topTrailing:          return CGPoint(x: rect.maxX, y: rect.minY)
        case .bottomLeading:        return CGPoint(x: rect.minX, y: rect.maxY)
        case .bottomTrailing:       return CGPoint(x: rect.maxX, y: rect.maxY)
        case .alongTop(let p):      return CGPoint(x: rect.minX + rect.width * p, y: rect.minY)
        case .alongBottom(let p):   return CGPoint(x: rect.minX + rect.width * p, y: rect.maxY)
        case .alongLeading(let p):  return CGPoint(x: rect.minX, y: rect.minY + rect.height * p)
        case .alongTrailing(let p): return CGPoint(x: rect.maxX, y: rect.minY + rect.height * p)
        }
    }
}

/// Holds separate values for portrait and landscape orientations.
public struct LayoutPair<T> {
    public let portrait: T
    public let landscape: T

    public init(_ value: T) {
        portrait = value
        landscape = value
    }

    public init(v portrait: T, h landscape: T) {
        self.portrait = portrait
        self.landscape = landscape
    }

    public func resolved(_ isLandscape: Bool) -> T {
        isLandscape ? landscape : portrait
    }
}
