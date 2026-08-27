# Architecture

What Puck Around **is**, as built. Process and conventions live in
[AGENTS.md](AGENTS.md); *when* things happen is [ROADMAP.md](ROADMAP.md); *why*
a design was chosen will live in `docs/*-plan.md` files, linked from here.

Everything before "[Planned](#planned)" describes shipped code. That chapter is
fenced off deliberately: mixing the two is what lets architecture notes drift
into describing a model that was never built.

## The rule everything hangs on

**A control scheme is an input source, not a game mode.**

```swift
public protocol ControlSource {
    func input(for player: PlayerID, at tick: Tick) -> SeatInput
}
```

`SeatInput` is data about the table, not about the screen: today it carries an
optional `Swipe` — the world-space segment a finger swept this tick and the
velocity it swept at. Fingers on glass, a future AI seat, anything else are all
just `ControlSource`s. The sim never knows which, and decides for itself what a
swipe did (below).

## Two targets, one seam

| | `PuckaroundCore` | `PuckaroundKit` |
|---|---|---|
| holds | math, lineup + seats, table + puck sim, control sources, the session clock | SwiftUI rendering, UIKit touch capture, the app icon scene |
| imports | Foundation | SwiftUI, UIKit (iOS only), PuckaroundCore |
| tested | headless, coverage-gated | coverage-ignored |

The rule: **testable logic goes in PuckaroundCore.** The Kit compiles on macOS
too — not for a Mac app (there will be none) but because `swift test` runs on
the Mac; UIKit-only code sits behind `#if os(iOS)` with a fallback.

Both targets and the tests group **by domain, not by type** — `Kit/Input/`,
`Kit/Render/`, `Tests/Sim/`.

## The simulation

Deterministic by construction: same seed + same inputs → same state,
bit-for-bit. Replays are seed + per-tick inputs, and any future lockstep would
stand on the same promise.

- `Rink.advance(inputs: [PlayerID: SeatInput])` at a fixed timestep.
  `tickRate = 60`, `dt = 1/60`. `GameSession` drives it from render-loop time,
  stepping however many ticks a frame owes (capped, so a hitch drops time
  rather than spiralling).
- Physics is hand-written — position, velocity, drag, wall reflection. **Not**
  `SKPhysicsBody`: SpriteKit physics isn't guaranteed deterministic.
- Randomness is injected and seeded (`SeededRNG`, SplitMix64), never ambient.
  The serve direction is the one random thing so far.
- Seats apply in `Lineup` order, never dictionary order — the order strikes
  land in is part of the state.

**The table** (`Playfield`) is a walled rectangle in world units plus the puck's
constants: radius, wall restitution, surface drag, a speed cap (so no strike
can carry the puck through a wall in one tick), and a rest speed below which
the puck stops instead of creeping on floating-point dust. Two players get a
portrait table; three or four get a square one.

**Coordinates are y-down**, matching screen space: rendering is a pure scale
and nothing flips. `Edge.bottom` is the bottom of the screen.

**A swipe strikes the puck** when the segment it swept passes within
`puckRadius + fingerRadius` of the puck's centre; the puck then takes the
finger's velocity. A finger that is not moving does nothing — the puck passes
under it. This is the *first* strike model, chosen because it is the simplest
thing a finger can do to a puck; the roadmap's first question is whether it is
the right one.

## Seats

`Lineup` is who is at the table: 2–4 players, seated in order at the bottom,
top, left and right edges — so two players face each other across the table.
With four, the lineup may be **teamed**: partners sit across from each other
(bottom + top vs. left + right).

`SeatZones` maps a world point to its seat by nearest seated edge, and gives
each seat a band along its edge to be drawn in.

**A touch belongs to the seat it began in for its whole life.** `Edge`
ownership is decided at touch-down and never revisited, so a finger crossing
the table never becomes somebody else's — the one rule that makes several
fingers on one screen unambiguous. `SwipeControlSource` holds the ownership and
turns each finger's movement since the last tick into that seat's `Swipe`.

---

## Planned

Not built. Nothing below describes existing code.

**A game.** Goals, scoring, a serve after each goal, a win condition. Which
puck game comes first is the roadmap's open question (air hockey 1v1/2v2, a
four-goal free-for-all, …); the sim above is meant to carry any of them.

**Mallets.** A disc each player drags, which the puck collides with — the
alternative strike model to swipe-through, to be A/B'd on device.

**The couch.** A front door that asks who is playing, seat colors, per-seat
HUD facing its player, side-by-side vs. face-to-face seating on iPad.

**Sound & haptics.** Procedural, no assets.

## Deliberately out of scope

No ads, no IAP, no accounts, no server, no leaderboards, no third-party runtime
dependencies. **No Mac, watch or TV target — the premise is one handheld
screen shared by the people around it.** Networked play across devices is not
planned for the same reason.
