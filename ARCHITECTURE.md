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
centerd in each short wall, plus the constants: puck and mallet radii, goal
width, wall restitution, surface drag, a speed cap (so no hit can carry the
puck through a wall in one tick), and a rest speed below which the puck stops
instead of creeping on floating-point dust, and the `puckShape` (below). The
short walls are **open across the mouth** (clear of both posts, `goalWidth/2 −
puckRadius`): a puck lined up with the goal passes through, and a goal counts
only once the **whole puck is past the line** (soccer rules — it flies fully in
before warping back). Elsewhere the wall bounces it; a post bounces it too.

**Coordinates are y-down**, matching screen space: rendering is a pure scale
and nothing flips. `Seat.bottom` is the bottom of the screen.

**The puck has a shape** (`PuckShape` on `Playfield` — `circle` by default, or
a `polygon`; square and triangle ship). A polygon puck carries an `angle` and
`angularVelocity`: it tumbles. Its wall collision (`PolygonCollision`,
deterministic — vertices in fixed index order, ties broken by that order) is
not a rigid impulse but a **feel model** chosen to play well, not to be exactly
physical: the linear bounce is disc-like (speed preserved, never a launch off
the wall), while the puck's **spin steers the outgoing direction off-axis** —
which way and how much set by the spin's sign and speed and how off-center the
corner hit is. A corner catch also *starts* a little spin from rest; a flat
face bounces clean. A glancing mallet hit puts english on it. Three dials tune
the feel: `PolygonCollision.steerPerSpin`, `spinFromCorner`, `spinSpent`.

**The round puck spins too, more gently.** A glancing mallet hit gives the disc
english (`Rink.discSpinBite`, below the polygon's `spinBite`), and its spin
skews the wall bounce (`discSteerPerSpin`) while the wall bleeds some of it
(`discSpinKeptOnBounce`) — a finesse effect, not the polygon's tumble, and a
flat wall deliberately can't *roll* the puck along it (that payoff waits on the
ellipse's curved walls). Spin is invisible on a circle, so the renderer draws a
small mark that turns with `angle`.

**The look is a neon cabinet, and single-theme by choice.** A dark violet-black
ground, a glowing neutral rink (ice, grid, center line, puck) that belongs to
no seat, and each player's neon color on exactly the three things that are
theirs — mallet, goal mouth, score — so table furniture never competes with
player identity. Magenta and cyan lead the 1v1 palette: the max-contrast pair,
and color-blind-safe (they separate on lightness and the red–green axis). Glow
is drawn as a blurred pass under a solid core, so a hard puck and a readable
score survive the bloom; decorative motion (the puck's speed-scaled trail, a CRT
scanline breath) backs off under `accessibilityReduceMotion`. All procedural, no
assets — the icon is the same recipe (`AppIconScene`), and it must keep matching
`RinkRenderer`. A cabinet is a dark object, so there is no light variant. See
`RinkRenderer` / `SeatPalette`.

**Feedback is a pure event stream.** Each tick fills `Rink.events` —
`malletHit` (with closing speed), `wallBounce`, `goal`, `gameOver` — cleared at
the top of the next `advance`, so it always describes only the latest step.
The sim raises them and knows nothing more; `PuckaroundKit`'s `Haptics`
(`UIFeedbackGenerator`) and `SoundEngine` (one `AVAudioSourceNode` synthesizing
short percussive envelopes, no assets) consume them off the render frame. Being
a pure function of the sim, the events are deterministic and a replay gets them
for free.

**Mallets are kinematic.** A mallet goes exactly where the hand's movement
puts it, clamped to its own half (it may touch the center line, never cross
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
revisited, so a finger crossing the center line never becomes the other
player's. `MalletControlSource` holds the ownership and turns the driving
finger's movement since the last tick into that seat's drag.

---

## Planned

Not built. Nothing below describes existing code.

**Three and four seats.** The lineup exists; the table doesn't. Where a third
and fourth goal go — one per wall on a square table, corners, a shared goal
per team — and whether four hands fit round a phone at all are open; see
[docs/air-hockey-plan.md](docs/air-hockey-plan.md).

**The couch's tail.** The front door shipped (title, first-to-N, puck pick,
Play; the center ring is the always-available menu; a rematch is the faceoff
returning). Still planned: who is playing, seat colors, per-seat HUD facing its
player, side-by-side vs. face-to-face seating on iPad — the parts that need
more seats and profiles.

## Deliberately out of scope

No ads, no IAP, no accounts, no server, no leaderboards, no third-party runtime
dependencies. **No Mac, watch or TV target — the premise is one handheld
screen shared by the people around it.** Networked play across devices is an
idea on the roadmap's evaluation list, not a plan; the sim's determinism keeps
it reachable if it is ever wanted.
