import PuckaroundCore

/// The puck shapes the front door offers, as a stable `@AppStorage` string.
/// (`PuckShape` itself carries vertex data, so it isn't a tidy stored key.)
enum PuckShapeKey: String, CaseIterable {
    case circle
    case square
    case triangle

    var shape: PuckShape {
        switch self {
        case .circle: return .circle
        case .square: return .square
        case .triangle: return .triangle
        }
    }

    var label: String {
        switch self {
        case .circle: return "Round"
        case .square: return "Square"
        case .triangle: return "Triangle"
        }
    }
}
