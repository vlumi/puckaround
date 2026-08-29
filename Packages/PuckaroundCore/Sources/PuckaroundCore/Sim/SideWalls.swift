/// How the table's LONG walls (left and right) behave. The short walls always
/// stay solid — they hold the goals. A variation axis, orthogonal to puck shape
/// and format.
public enum SideWalls: Equatable, Codable, Sendable {
    /// Classic air hockey: the side walls bounce the puck back.
    case solid
    /// The side walls are portals — a puck leaving one side re-enters the
    /// opposite side at the same height, keeping its velocity (Asteroids-style
    /// horizontal wrap). No bounce, so spin off the side walls never fires.
    case wrap
}
