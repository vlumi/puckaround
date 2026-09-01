# Architecture

What Puck Around **is**, as built, with the *why* behind each choice woven in.
Process and conventions live in [AGENTS.md](AGENTS.md); *when* things happen is
[ROADMAP.md](ROADMAP.md). A big, still-undecided feature may get its own
`docs/*-plan.md` to think it through; once it ships, its decisions fold into
this file and the plan is retired.

Everything before "[Planned](#planned)" describes shipped code. That chapter is
fenced off deliberately: mixing the two is what lets architecture notes drift
into describing a model that was never built.

## The rule everything hangs on

**A control scheme is an input source, not a game mode.**

```swift
public protocol ControlSource {
    func input(for slot: MalletSlot, at tick: Tick) -> SeatInput
}
```

`SeatInput` is data about the table, not about the screen: it carries how far
the mallet wants moving this tick (and, on a fresh grab, an absolute point to
snap to), in world units. Fingers on glass (`MalletControlSource`), the practice
machine (`PatternControlSource`, a pure function of the tick sweeping its goal
mouth), a future AI hand — all just `ControlSource`s. The sim never knows
which, and decides for itself what the movement did (below).

## Two targets, one seam

| | `PuckaroundCore` | `PuckaroundKit` |
|---|---|---|
| holds | math, table geometry (`Playfield`/`Goal`, `Table`'s sides & slots), the air-hockey sim (puck, mallets, score), control sources, the session clock | SwiftUI rendering, UIKit touch capture, the app icon scene |
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

- `Rink.advance(inputs: [MalletSlot: SeatInput])` at a fixed timestep.
  `tickRate = 60`, `dt = 1/60`. `GameSession` drives it from render-loop time,
  stepping however many ticks a frame owes (capped, so a hitch drops time
  rather than spiralling; a `paused` latch freezes it for the menu).
- Physics is hand-written — position, velocity, drag, wall and mallet
  reflection. **Not** `SKPhysicsBody`: SpriteKit physics isn't guaranteed
  deterministic.
- Randomness is injected and seeded (`SeededRNG`, SplitMix64), never ambient.
  A seam for future randomness; the shipped sim has none (the faceoff opening
  replaced the old random serve).
- Mallets apply in `slots` (`Format.slots`) order, never dictionary order — the
  order hits land in is part of the state.

**The game is air hockey**, standard rules: a goal in each short wall, the side
scored on gets the puck, first to seven points (`Rules.pointsToWin`). A **match**
wraps games: first to `Rules.gamesToWin` games takes it (`gamesWon` per side,
tallied on the faceoff between games; a single game is `gamesToWin == 1`, and
the win events are `gameWon` mid-match vs. `matchOver`). Each side fields one or
two mallets — see [Sides & slots](#sides--slots) — so 1v1, 1v2 and 2v2 are one
game. It was chosen because everyone already knows how to play it: the
rules need no screen to explain them, so the sandbox could be a game on day one
rather than a toy that needs teaching. The mallet is the input, not a
swipe-across-the-puck strike — you defend with it, and a still one is a wall —
because that is what makes it *air hockey* rather than a lively toy.

**The table** (`Playfield`) is a walled rectangle in world units, a goal in each
short wall, plus the constants: puck and mallet radii, goal width, wall
restitution, surface drag, a speed cap (so no hit can carry the puck through a
wall in one tick), a rest speed below which the puck stops instead of creeping
on floating-point dust, the `puckShape` (below), and `sideWalls` (solid or
wrap). One side's goal geometry is a `Goal` value (built by `Playfield.goal`):
its line, its **opening** (the drawn gap between the posts), and the narrower
**scoring mouth** (the opening less a puck radius each side, since the whole
disc must clear the posts). A goal counts only once the **whole puck is past the
line and within the mouth** (soccer rules — it flies fully in before warping
back). A puck that enters the opening but clips a post bounces off the post's
inner face, staying in the goal; a puck wide of the opening bounces off the
short wall.

**Side walls can wrap.** With `sideWalls == .wrap` the long walls are portals —
a puck leaving one long side re-enters the opposite side at the same height,
keeping its speed (the goals stay solid). A table variant, orthogonal to shape
and format.

**Coordinates are y-down**, matching screen space. `Side.bottom` is the bottom
of the board.

**The board follows the phone.** One transform (`BoardPlacement`) owns the fit,
a turn from the *physical* device orientation (0 upright, ±90 landscape, 180
upside down), and the world ↔ screen mapping — the renderer draws through it and
the touch mapping inverts it, so a finger lands where it looks in any hold and
the bottom goal stays at the button end. Labels counter-turn to face the
players (side by side in landscape, head-to-head in either portrait — `Seat`);
the menus are plain SwiftUI and rotate with the interface. The system's rotation
animation briefly spins the board; suppressing it from the app was proven
impossible, and the accepted trade-off is recorded in the PR that shipped this.

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
no side, and each **side's** neon color on exactly the things that are theirs —
its mallet(s), its goal, its score — so table furniture never competes with side
identity. One color per side (both mallets of a doubles side share it): the
classic pair by default — magenta bottom, cyan top, max-contrast and
color-blind-safe (they separate on lightness and the red–green axis) — or the
players' own kits in named play (see the tournaments section; the pair is
clash-resolved, and every wardrobe hue is curated against ground, grid and
puck, since telling players apart is positional). Glow
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
puts it, clamped to its own zone (its side's half, and in doubles its left or
right lane — it may touch the center line, never cross it), and is infinitely
heavy as far as the puck is concerned: the puck is pushed clear along the
contact normal and, if they were closing, bounces with the mallet's velocity
added (`(1 + restitution)` of the closing speed) plus a little english. A fast
hand is swept along its path in steps no longer than the puck's radius, so it
cannot pass through the puck between two positions. A still mallet is a wall.
**Mallets are the players' hands, so they are never frozen or reset**: a
finished game parks only the puck, and a new game leaves the mallets where
they were.

## Sides & slots

The sim knows nothing of players or teams — that identity ends when you leave
the table. A **mallet is a `MalletSlot`** (a `Side` × a `Lane`); a **goal is a
`Side`** (bottom or top). Score is per side (`Rink.score(of:)`); own goals need
no special case — the puck crossing a side's own line is the other side's point,
whoever touched it.

`Format` is the shape of play: how many hands each side fields, `(bottom, top)`
each one or two, so 1v1, 1v2 and 2v2 all fall out of one model. `Format.slots`
lists the mallets in a fixed order (bottom's lanes, then top's) — the order the
sim iterates, so it stays deterministic. A side's goal **widens with its hand
count** (`Playfield.goalWidth(for:)`): a lone defender keeps a narrow goal, a
pair earns a wide one, so in 1v2 the harder goal to keep goes to the
better-staffed side. In doubles a side's half splits into left/right lanes, each
mallet confined to one, with a drawn divider down the middle.

**Tournaments sit on top, not inside.** Three shapes behind one handle
(`Evening`, in Core): winner-stays (`Tournament` — a line behind the table, the
loser to its back), a knockout `Bracket` (a seeded random draw on a
power-of-two sheet, byes for uneven counts, up to 32), and a `League` season
(circle-method round robin once or twice, standings by wins, ties by
head-to-head then sudden-death deciders, up to 10). All are pure, tested
scheduling that survives the app quitting. Names are labels the Kit pins on the
ends for the evening (`EndNames`, and a remembered tap-to-pick pool — no
profiles, no history); the sim still never learns who is playing. Each name
also wears a kit (`PlayerKit`, home + away slots into the Kit's eight-neon
wardrobe): in named play the table's side furniture — mallet, goal, score,
verdicts — takes the player's color (`EndColors`, clash-resolved so the home
side keeps its hue and the other switches to its away), while nameless play
keeps the classic magenta/cyan.

**The arcade sits on top the same way.** Solo minigames reuse the sim, never a
second engine: a solo table is just a `Format` with an empty end (`Hands.none`
— one ready starts play, and touches on the machine's half drive nothing),
bumpers are table furniture (`Bumper` on `Playfield`: a mallet that never
moves and kicks back, resolved in fixed index order like everything), and a
run is `ScoreAttack` folding the same `GameEvent` stream the feedback layers
feed on — the sim's own points target sits out of reach, so the cabinet, not
the rink, ends a run. `Hiscores` is the ten-line board, signed from the same
remembered pool. Each minigame has one canonical table spec (`ArcadeSpec`, in
the Kit), so its board's scores actually compare.

`SeatZones` maps a world point to the slot that owns it (its side's half, then
its lane). **A touch belongs to the slot it grabbed for its whole life** — one
finger per mallet, decided on the grab, never revisited. `MalletControlSource`
holds the ownership and turns the driving finger's movement into that mallet's
drag. A finger only **grabs** a mallet when it comes down (or slides) near it;
land far away and the mallet stays put until a finger reaches it — so re-grabbing
after a lift snaps the mallet under the thumb instead of driving it from an
offset.

---

## Planned

Not built. Nothing below describes existing code.

**The couch's tail.** The front door shipped (a bare title with three modes —
the New match modal, tournaments in all three shapes, and practice against the
machine; a rematch is the faceoff returning), and so did per-person kit colors
— cosmetic identity only; the sim stays side-based. What remains of the couch
is in ROADMAP.md's arcade section.

**A curved table (the ellipse).** Slice goals and curved walls, and the payoff
the flat table can't express: a forward-spun puck that rolls the wall toward the
goal. A whole table's worth of physics — a spike, not a variant; see
[ROADMAP.md](ROADMAP.md).

## Deliberately out of scope

No ads, no IAP, no accounts, no server, no leaderboards, no third-party runtime
dependencies. **No Mac, watch or TV target — the premise is one handheld
screen shared by the people around it.** Networked play across devices is an
idea on the roadmap's evaluation list, not a plan; the sim's determinism keeps
it reachable if it is ever wanted.
