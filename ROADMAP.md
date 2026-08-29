# Roadmap

The implementation plan, as **named milestones in rough order** — and *only open work*. This file is *expected to churn*: milestones get reshaped as prototyping answers questions, and everything before 1.0 is beta by definition (TestFlight from the first cut). As work ships it leaves this file — brief summaries go to the [README version history](README.md#version-history), full detail to [CHANGELOG.md](CHANGELOG.md), and settled rules and design decisions to [ARCHITECTURE.md](ARCHITECTURE.md) or the plan under `docs/` that owns them. This file is only *when*, not *why*.

**No hard line wraps** — one paragraph or bullet, one line; editors soft-wrap and rendered Markdown ignores the breaks anyway.

**Milestones are not version numbers.** A version is assigned when a milestone is *cut*, not when it is planned — some of these will be reordered, split, or dropped outright, and renumbering the rest each time is the churn that stops a roadmap being updated at all.

Guiding order: **the mallet is the game**, and **what comes early is whatever answers a question that changes the plan**.

Shipped so far (in TestFlight, detail in [CHANGELOG.md](CHANGELOG.md)): 1v1/1v2/2v2 air hockey with the faceoff/rematch flow, round/square/triangle pucks with spin (polygon and disc), wrap-wall tables, sound + haptics, and a front door. What's left is below.

## Tune & fit — *the table on real hardware*

- [ ] **Tune the table on device.** Drag, wall restitution, the speed cap, mallet and goal sizes are constants in `Playfield`; turn them into on-device dials (a tuning panel, the sibling projects' pattern) so feel gets settled by play rather than by editing numbers.
- [ ] **iPad sizing.** A portrait table on a 13-inch screen may want margins, or may want to be as big as it can; and a table held landscape needs a decision.
- [ ] **Pace levels.** A pick in setup for how fast the table plays — the puck's speed cap (and probably drag with it), a few presets from a gentle warm-up to a frantic one. `maxSpeed` is already a `Playfield` constant, so this is a value setup chooses, not a physics change. **Frame it as pace, not difficulty**: both sides share the same table, so a faster cap raises the intensity for everyone equally — it is not an easier/harder opponent. Real per-side difficulty only means something once there's an AI hand or a solo mode, and then it lives in *those*. Belongs to setup, never a mid-game control.

## The couch — *who is playing*

The front door sets each side's hand count and the table variant. What's missing is identity beyond a bare count.

- [ ] **Who's playing, remembered.** Names and colors that belong to a person, not just a side — so a result is *someone's*. Purely on-device. Gates the session tally and tournaments.
- [ ] **A record of the session.** A running tally across games, so the last twenty minutes happened.

## Puck & table variety — *what changes how it plays*

- [ ] **Shaped-puck follow-ons, if play asks for them.** Triangle-specific feel; **per-vertex goals** (today a goal needs the puck CENTER fully past the line, so a corner poked in early doesn't count — fine so far); more shapes only if they behave distinctly (a hexagon is basically a disc).
- [ ] **Grip-spin that rides the wall** — the coupling that makes a low, wall-hugging shot with forward spin accelerate toward the goal. Its real home is the **ellipse table** ([docs/table-and-modes-plan.md](docs/table-and-modes-plan.md)): a curved wall can carry the puck along it, which a flat wall can't. Builds on the shipped disc spin. A later spike.
- [ ] **More table variants.** Bumpers on the ice, two pucks, a moving goal — each a table variant beside solid/wrap, grouped under one picker (`SideWalls` is the seam for that grouping).

## Release & submission — *1.0 by definition*

The lane is in place (see [RELEASING.md](RELEASING.md)) and builds are shipping to TestFlight.

- [ ] The App Store Connect listing: text, screenshots, and the privacy/age answers.
- [ ] Final balancing pass with the dials, then bake the defaults.
- [ ] Submit, await review, release.

## Backlog (unversioned)

- [ ] An **AI hand** to fill an empty slot — a `ControlSource` like any other. Not the premise (this is a game for people in a room), so only if it costs little.
- [ ] Finnish/Japanese localization (String Catalog makes this translation-only).

## Ideas to evaluate — *not scheduled*

A parking lot for what could flesh the game out before 1.0. None of these is committed; each earns a milestone only if, tried on a device, it makes a game between people better. Ordered roughly by how much they lean on what already exists.

- [ ] **Pinball-style obstacles.** Bumpers on the ice — fixed discs (or pads) the puck bounces off, maybe with a kick. Cheap: the mallet collision is already a kinematic circle, so a bumper is a mallet that never moves and adds speed. The design question is placement — a few table layouts to choose from, not an editor. Once bumpers exist, more pinball furniture is the same idea: spinners, one-way gates, targets, a multiplier lane — each a fixed piece riding the one collision routine.
- [ ] **Multiple pucks.** Two or three pucks at once — chaos in a good way, and nearly free: the sim already steps one puck through walls and mallets, so this is an array plus puck–puck collision (the same circle–circle math the mallets use). Scoring needs a rule for who a goal counts for when several are live. A natural pairing with bumpers.
- [ ] **A single-player mode — a different game sharing the physics.** Ideas from pinball and breakout: a wall of bricks the puck chips away, a table of bumpers and targets to rack up a score, a survival mode where you keep the puck off your own goal. Honestly: this **changes what the app is** — the premise everywhere else is "the device is the table, people around one screen," and a solo score-attack is a genuinely different game that reuses the puck sim. So it earns a mode, never the front door, and only if the multiplayer game is proven first. The engine is ready (deterministic sim, event stream, kinematic-circle collisions); the question is whether it's a game worth being.
- [ ] **A curved table (the ellipse).** Slice goals and curved walls where the bounce angle depends on where you hit — and the payoff, a forward-spun puck rolling the wall toward the goal (needs grip-spin, above). A whole table's worth of physics, so a spike, not a variant; iPad-forgiving. Design in [docs/table-and-modes-plan.md](docs/table-and-modes-plan.md).
- [ ] **Tournaments.** A series of games across a session with standings — the thing that gives a two-minute game a reason to be played ten times. Skid's tournament model (fixed rounds, points table, persisted across quits) is the pattern to copy; wants remembered players under it first.
- [ ] **Nearby multiplayer.** Two devices, each its own table half, over the local network — no server, no accounts. The sim was built for it: inputs are data and the state is deterministic, so host-authoritative snapshots or lockstep over MultipeerConnectivity (as Skid does) is reachable without a rewrite. Changes the premise (one shared screen) enough that it needs its own decision before any code; listed so it isn't forgotten, not because it is planned.
- [ ] **Multi-device tournaments.** Several tables in the same room, each a device, feeding one bracket. Recorded because it follows from tournaments plus nearby play; judged *not important*: hard to see the game drawing crowds that need it, and it costs a network layer otherwise unneeded.

## Deliberately out of scope

Per [ARCHITECTURE.md](ARCHITECTURE.md): no ads, no IAP, no accounts, no server, no leaderboards, no third-party runtime dependencies. **No Mac, watch or TV target, ever** — the game is one handheld screen shared by the people around it. Networked play across devices is an idea to evaluate (above), not a plan.
