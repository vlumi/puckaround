# Roadmap

The implementation plan, as **named milestones in rough order** — and *only open work*. This file is *expected to churn*: milestones get reshaped as prototyping answers questions, and everything before 1.0 is beta by definition (TestFlight from the first cut). As work ships it leaves this file — brief summaries go to the [README version history](README.md#version-history), full detail to [CHANGELOG.md](CHANGELOG.md), and settled rules and design decisions to [ARCHITECTURE.md](ARCHITECTURE.md) or the plan under `docs/` that owns them. This file is only *when*, not *why*.

**No hard line wraps** — one paragraph or bullet, one line; editors soft-wrap and rendered Markdown ignores the breaks anyway.

**Milestones are not version numbers.** A version is assigned when a milestone is *cut*, not when it is planned — some of these will be reordered, split, or dropped outright, and renumbering the rest each time is the churn that stops a roadmap being updated at all.

Guiding order: **the mallet is the game**, and **what comes early is whatever answers a question that changes the plan**.

## Settled — *2026-08-27*

**Air hockey, with mallets, plain 1v1 under the standard rules first.** The swipe-through strike model is gone; the reasons and the parked four-seat question are in [docs/air-hockey-plan.md](docs/air-hockey-plan.md).

**The mallet follows the finger's movement and never leaves the ice** (settled after the first build, on device). Direct placement under the finger was the alternative; it means lifting the mallet off the deck and putting it back, and putting it back can land it on top of the puck. Movement-drag has no such moment. Still open: team seating (partners across or adjacent), which only matters once four seats have a table.

## Air hockey 1v1 — *find the fun*

The game is built and this milestone is about driving it on hardware: two thumbs on a phone, two hands on an iPad.

- [ ] **Tune the table on device.** Drag, wall restitution, the speed cap, mallet and goal sizes are constants in `Playfield`; turn them into on-device dials (a tuning panel, the sibling projects' pattern) so feel gets settled by play rather than by editing numbers.
- [ ] **iPad sizing.** A portrait table on a 13-inch screen may want margins, or may want to be as big as it can; and a table held landscape needs a decision.
- [ ] **A way out mid-game.** Nothing on screen faces one player only now — the score (in the corner by each goal, out of the mallet's way) and the WIN/LOSE verdict turn toward their seat, and the restart ring is symmetric — but a game in progress can only be finished by playing it. The idea: a dim button near the middle of the board that opens a menu (quit, settings), readable from both ends.

## The couch — *who is playing*

Built against [singles & doubles](#singles--doubles--multiplayer-on-the-oblong): the setup asks singles or doubles, then who takes each mallet.

- [x] **A front door (first cut).** A title screen with a first-to-N pick and Play; a rematch that IS the faceoff (ready up again, score resets on start); and the centre ring as an always-available menu (resume / quit). Deliberately minimal for a 1v1-only game — **still to come as more seats and modes land**: who is at the table, player count, seat colours chosen by the players, and mode selection.
- [ ] **A record of the session.** A running tally across games, so the last twenty minutes happened.

## Feel — *sound & haptics*

Not polish to leave for last: haptics are part of how a hit reads, so this comes right after the first build. Procedural, no assets, in the sibling projects' pattern — a deterministic event stream out of the sim, one synthesizer node for the sound, `UIFeedbackGenerator` for the taps.

- [ ] **Events out of the sim** — mallet hit (with closing speed), wall bounce, goal, game over — as data the feedback layers consume; replays get them for free.
- [ ] **Haptics**: a tap per hit scaled by speed, a softer one per wall bounce, a flourish on a goal. One engine per device is a constraint worth designing around: the device buzzes for everyone.
- [ ] **Sound**: a click per hit, a duller one per wall, a horn on a goal. Ambient audio session, so the silent switch is honoured and the players' music keeps playing.
- [ ] **Pace levels.** A pick in setup for how fast the table plays — the puck's speed cap (and probably drag with it), a few presets from a gentle warm-up to a frantic one. `maxSpeed` is already a `Playfield` constant, so this is a value setup chooses, not a physics change. **Frame it as pace, not difficulty**: in a two-player game both players share the same table, so a faster cap raises the intensity for both equally — it is not an easier/harder opponent (the opponent is the other person). Real per-side difficulty only means something once there's an AI seat or a solo mode, and then it lives in *those*, not here. Belongs to the setup step (see *The couch*), never a mid-game control.

## Puck variety — *shaped pucks*

The one addition that changes how the game plays rather than what is around it. A square or triangular puck skitters unpredictably off walls and mallets.

- [x] **The physics (spiked, shipped).** A polygon puck that rotates and tumbles, with a deterministic wall collision (`PolygonCollision`) tuned for feel over exact realism: a disc-like linear bounce (never a launch) while the spin steers the outgoing direction off-axis. Proven fun on a device — that was the whole question. Round / square / triangle are pickable on the front page. See [ARCHITECTURE.md](ARCHITECTURE.md).
- [ ] **Follow-ons, if play asks for them.** Triangle-specific feel; **per-vertex goals** (today a goal needs the puck CENTRE fully past the line, so a corner poked in early doesn't count — fine so far); tuning the three feel dials on more play; more shapes only if they behave distinctly (a hexagon is basically a disc).
- [ ] **Grip-spin on a ROUND puck** — english coupling back into linear motion. Its real home is the **ellipse table** ([docs/table-and-modes-plan.md](docs/table-and-modes-plan.md)): a low, wall-hugging shot with forward spin rides the curved wall and accelerates toward the goal — a skill shot the flat table can't express, and the reason the ellipse is worth building. Spin on a disc is invisible, so it either stays hidden state or gets a small drawn puck symbol (open). A later spike, independent of singles/doubles.

## Singles & doubles — *multiplayer on the oblong*

The near-term multiplayer answer, decided in [docs/table-and-modes-plan.md](docs/table-and-modes-plan.md): not a player count but **how many mallets a side has** (singles = one, doubles = two) and **how many hands drive them** — so 2v2, 1v1-with-two-mallets, 1v2 and soloing-both are one game, not four, and there is no awkward three-player case. Same oblong, near-zero new geometry.

- [ ] **A side can have two mallets** (doubles), each in its own left/right quadrant of the half; a hand may own one mallet or both.
- [ ] **The doubles goal is wider** (toward the whole end) — two defenders make a narrow goal trivial. One number.
- [ ] **The couch flow drives it** (see below): singles/doubles, then who takes each mallet. This is what unblocks who-is-playing and seat colours.

Deferred, non-rectangle tables (square/corners/triangle/circle) and their trade-offs are recorded in the plan; the exciting one is the ellipse spike below.

## Release lane & TestFlight

The lane is in place (see [RELEASING.md](RELEASING.md)); what's missing is the first cut.

- [ ] First TestFlight build once the sandbox is fun on a device.
- [ ] Icon polish pass (the base icon ships with every build already).
- [ ] The App Store Connect record is created; listing text, screenshots, and the privacy/age answers still are not.

## Polish & submission — *this one is 1.0 by definition*

- [ ] Final balancing pass with the dials, then bake the defaults.
- [ ] Submit, await review, release.

## Backlog (unversioned)

- [ ] An **AI seat** to fill an empty edge — a `ControlSource` like any other. Not the premise (this is a game for people in a room), so only if it costs little.
- [ ] Variants: bumpers on the table, two pucks, a moving goal.
- [ ] Finnish/Japanese localization (String Catalog makes this translation-only).

## Ideas to evaluate — *not scheduled*

A parking lot for what could flesh the game out before 1.0. None of these is committed; each earns a milestone only if, tried on a device, it makes a game between two people better. Ordered roughly by how much they lean on what already exists.

- [ ] **Pinball-style obstacles.** Bumpers on the ice — fixed discs (or pads) the puck bounces off, maybe with a kick. Cheapest of the lot: the mallet collision is already a kinematic circle, so a bumper is a mallet that never moves and adds speed. The design question is placement — a few table layouts to choose from, not an editor. Once bumpers exist, more pinball furniture is the same idea: spinners, one-way gates, targets that light up, a multiplier lane — each a fixed piece the puck interacts with, all riding the one collision routine.
- [ ] **Multiple pucks.** Two or three pucks on the table at once — chaos in a good way, and nearly free: the sim already steps one puck through walls and mallets, so this is an array instead of a single value, plus puck–puck collision (the same circle–circle math the mallets use). Scoring needs a rule for who a goal counts for when several are live. A natural pairing with bumpers, and with a "multiball" beat if any solo mode lands.
- [ ] **A single-player mode — a different game sharing the physics.** Ideas from pinball and breakout: a wall of bricks the puck chips away, a table dressed with bumpers and targets to rack up a score, a survival mode where you keep the puck off your own goal. Worth flagging honestly: this **changes what the app is** — the premise everywhere else is "the device is the table, two-plus people around one screen," and a solo score-attack is a genuinely different game that happens to reuse the puck sim. So it earns a mode, never the front door, and only if the two-player game is proven first. The engine is ready for it (deterministic sim, event stream, kinematic-circle collisions already carry bumpers and a paddle); the question is whether it's a game worth being, not whether it's buildable.
- [ ] **A curved table (the ellipse).** Slice goals and curved walls where the bounce angle depends on where you hit — and the payoff mechanic, a forward-spun puck rolling the wall toward the goal (needs round-puck spin, above). A whole table's worth of physics, so a spike, not a variant; iPad-forgiving. Design in [docs/table-and-modes-plan.md](docs/table-and-modes-plan.md).
- [ ] **Tournaments.** A series of games across a session with standings — the thing that gives a two-minute game a reason to be played ten times. Skid's tournament model (fixed number of rounds, points table, persisted across quits) is the pattern to copy and adapt; it wants player cards under it first.
- [ ] **Player cards.** Local profiles — a name and a colour, wins and losses, maybe a best streak — so results belong to a person rather than to a seat. Purely on-device (no accounts); Skid's profiles are the reference. The gate for tournaments and for anything that remembers who you are.
- [ ] **Nearby multiplayer.** Two devices, each its own table half, over the local network — no server, no accounts. The sim was built for it: inputs are data and the state is deterministic, so either host-authoritative snapshots or lockstep over MultipeerConnectivity (as Skid does) is reachable without a rewrite. Changes the premise (one shared screen) enough that it needs its own decision before any code; listed here so it isn't forgotten, not because it is planned.
- [ ] **Multi-device tournaments.** Several tables in the same room, each a device, feeding one bracket — so a bigger group plays more than one game at a time. Recorded because it follows naturally from tournaments plus nearby play; judged *not important*: it is hard to see the game drawing crowds large enough to need it, and it costs a network layer the game otherwise doesn't have.

## Deliberately out of scope

Per [ARCHITECTURE.md](ARCHITECTURE.md): no ads, no IAP, no accounts, no server, no leaderboards, no third-party runtime dependencies. **No Mac, watch or TV target, ever** — the game is one handheld screen shared by the people around it. Networked play across devices is an idea to evaluate (above), not a plan.
