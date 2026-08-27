# Architecture

What Puck Around **is**, as built. Process and conventions live in
[AGENTS.md](AGENTS.md); *when* things happen is [ROADMAP.md](ROADMAP.md); *why*
a design was chosen is in the `docs/*-plan.md` files, linked from here.

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

`SeatInput` is data about the table, not about the screen: it carries how far
the seat wants its mallet moved this tick, in world units. Fingers on glass, a
future AI seat, anything else are all just `ControlSource`s. The sim never
knows which, and decides for itself what the movement did (below).

## Two targets, one seam

| | `PuckaroundCore` | `PuckaroundKit` |
|---|---|---|
| holds | math, lineup + seats, the air-hockey sim (table, puck, mallets, score), control sources, the session clock | SwiftUI rendering, UIKit touch capture, the app icon scene |
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
- Physics is hand-written — position, velocity, drag, wall and mallet
  reflection. **Not** `SKPhysicsBody`: SpriteKit physics isn't guaranteed
  deterministic.
- Randomness is injected and seeded (`SeededRNG`, SplitMix64), never ambient.
  The opening possession is the one random thing.
- Seats apply in `Lineup` order, never dictionary order — the order hits land
  in is part of the state.

**The game is 1v1 air hockey**, standard rules: a goal in each short wall, a
mallet each, the player scored on gets the puck, first to seven
(`Rules.pointsToWin`). Why this game and not another is in
[docs/air-hockey-plan.md](docs/air-hockey-plan.md).

**The table** (`Playfield`) is a walled rectangle in world units, a goal mouth
centred in each short wall, plus the constants: puck and mallet radii, goal
width, wall restitution, surface drag, a speed cap (so no hit can carry the
puck through a wall in one tick), and a rest speed below which the puck stops
instead of creeping on floating-point dust. A puck crossing a short wall
**clear of both posts** — its centre within `goalWidth/2 − puckRadius` of the
middle — is a goal; anywhere else the wall bounces it.

**Coordinates are y-down**, matching screen space: rendering is a pure scale
and nothing flips. `Seat.bottom` is the bottom of the screen.

**Mallets are kinematic.** A mallet goes exactly where the hand's movement
puts it, clamped to its own half (it may touch the centre line, never cross
it), and is infinitely heavy as far as the puck is concerned: the puck is
pushed clear along the contact normal and, if they were closing, bounces with
the mallet's velocity added (`(1 + restitution)` of the closing speed). A fast
hand is swept along its path in steps no longer than the puck's radius, so it
cannot pass through the puck between two positions. A still mallet is a wall.
**Mallets are the players' hands, so they are never frozen or reset**: a
finished game parks only the puck, and a new game leaves the mallets where
they were.

## Seats

`Lineup` is who is at the table: 2–4 players, seated in order at the bottom,
top, left and right edges — so two players face each other across the table.
With four, the lineup may be **teamed** (partners across: bottom + top vs.
left + right). **Only the duel is playable**: `Rink` refuses any other count,
because the table has nowhere to put more goals yet (see *Planned*).

`SeatZones` maps a world point to its seat by nearest seated wall, and gives
each seat a band along its edge to be drawn in.

**A touch belongs to the seat it began in for its whole life**, and **the
first finger down in a half drives that half's mallet** — further fingers of
the same seat are ignored until the driver lifts. Decided at touch-down, never
revisited, so a finger crossing the centre line never becomes the other
player's. `MalletControlSource` holds the ownership and turns the driving
finger's movement since the last tick into that seat's drag.

---

## Planned

Not built. Nothing below describes existing code.

**Three and four seats.** The lineup exists; the table doesn't. Where a third
and fourth goal go — one per wall on a square table, corners, a shared goal
per team — and whether four hands fit round a phone at all are open; see
[docs/air-hockey-plan.md](docs/air-hockey-plan.md).

**The couch.** A front door that asks who is playing, seat colors, per-seat
HUD facing its player, side-by-side vs. face-to-face seating on iPad.

**Sound & haptics.** Procedural, no assets.

## Deliberately out of scope

No ads, no IAP, no accounts, no server, no leaderboards, no third-party runtime
dependencies. **No Mac, watch or TV target — the premise is one handheld
screen shared by the people around it.** Networked play across devices is not
planned for the same reason.
