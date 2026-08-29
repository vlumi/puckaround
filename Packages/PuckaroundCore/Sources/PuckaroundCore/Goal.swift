/// One side's goal, as geometry the physics can query directly: where its line
/// is, how wide the opening and the (narrower, whole-puck) scoring mouth are,
/// and where its posts stand. Built by `Playfield.goal(_:)`.
struct Goal {
    /// The y a puck center must reach for the WHOLE puck to be past the line
    /// (soccer rules — it warps back only once fully in).
    let line: Double
    /// +1 for the top goal (line above the field), -1 for the bottom.
    let facing: Double
    let centerX: Double
    let openingHalfWidth: Double
    let mouthHalfWidth: Double

    /// The whole puck is past the goal line.
    func isPast(_ y: Double) -> Bool { facing > 0 ? y <= line : y >= line }
    /// x is within the drawn opening (between the posts).
    func admitsOpening(_ x: Double) -> Bool { abs(x - centerX) <= openingHalfWidth }
    /// x is within the scoring mouth (the whole puck clears both posts).
    func admitsMouth(_ x: Double) -> Bool { abs(x - centerX) <= mouthHalfWidth }

    /// The inner faces of the two posts — the x a puck bounces off inside the
    /// opening. Their span is the scoring mouth.
    var postLeft: Double { centerX - mouthHalfWidth }
    var postRight: Double { centerX + mouthHalfWidth }
}

extension Playfield {
    func goal(_ side: Side) -> Goal {
        Goal(
            line: side == .top ? topGoalLine : bottomGoalLine,
            facing: side == .top ? 1 : -1,
            centerX: center.x,
            openingHalfWidth: goalWidth(for: side) / 2,
            mouthHalfWidth: goalMouthWidth(for: side) / 2)
    }
}
