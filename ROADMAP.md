# Roadmap

The implementation plan, as **named milestones in rough order** — and *only open work*. This file is *expected to churn*: milestones get reshaped as prototyping answers questions, and everything before 1.0 is beta by definition (TestFlight from the first cut). As work ships it leaves this file — brief summaries go to the [README version history](README.md#version-history), full detail to [CHANGELOG.md](CHANGELOG.md), and settled rules and design decisions to [ARCHITECTURE.md](ARCHITECTURE.md). This file is only *when*, not *why*.

**No hard line wraps** — one paragraph or bullet, one line; editors soft-wrap and rendered Markdown ignores the breaks anyway.

**Milestones are not version numbers.** A version is assigned when a milestone is *cut*, not when it is planned — some of these will be reordered, split, or dropped outright, and renumbering the rest each time is the churn that stops a roadmap being updated at all.

Guiding order: **the mallet is the game**, and **what comes early is whatever answers a question that changes the plan**.

Shipped so far (in TestFlight, detail in [CHANGELOG.md](CHANGELOG.md)): 1v1/1v2/2v2 air hockey with the faceoff/rematch flow, best-of matches, round/square/triangle pucks with spin and up to three at once, wrap-wall tables, "?" randoms, tournaments in three shapes on remembered names wearing per-person kit colors, practice against the machine, the arcade's three staged score-attack cabinets with hiscore boards, landscape play, sound + haptics, and the app chrome (New match modal, Settings, About). What's left is below.

## Tune & fit — *the table on real hardware*

- [ ] **Tune the table on device.** Drag, wall restitution, the speed cap, mallet and goal sizes are constants in `Playfield`; turn them into on-device dials (a tuning panel, the sibling projects' pattern) so feel gets settled by play rather than by editing numbers.
- [ ] **iPad sizing.** A portrait table on a 13-inch screen may want margins, or may want to be as big as it can. (Landscape is settled: the board follows the phone and fills the screen.)
- [ ] **Pace levels.** A pick in setup for how fast the table plays — the puck's speed cap (and probably drag with it), a few presets from a gentle warm-up to a frantic one. `maxSpeed` is already a `Playfield` constant, so this is a value setup chooses, not a physics change. **Frame it as pace, not difficulty**: both sides share the same table, so a faster cap raises the intensity for everyone equally — it is not an easier/harder opponent. Real per-side difficulty only means something once there's an AI hand or a solo mode, and then it lives in *those*. Belongs to setup, never a mid-game control.

## Puck & table variety — *what changes how it plays*

- [ ] **Shaped-puck follow-ons, if play asks for them.** Triangle-specific feel; **per-vertex goals** (today a goal needs the puck CENTER fully past the line, so a corner poked in early doesn't count — fine so far); more shapes only if they behave distinctly (a hexagon is basically a disc).
- [ ] **Grip-spin that rides the wall** — the coupling that makes a low, wall-hugging shot with forward spin accelerate toward the goal. Its real home is the **ellipse table** (below): a curved wall can carry the puck along it, which a flat wall can't. Builds on the shipped disc spin. A later spike.
- [ ] **More couch-table variants.** The arcade's furniture, multiplayer: bumpers on the couch table, a moving goal — each a variant beside solid/wrap, grouped under one picker (`Bumper` and the collision already exist; this is a setup seam).

## The arcade — *solo minigames on the same physics*

The launch trio shipped — Bumper Field, Brick Wall, Survival: staged score-attack cabinets behind one shelf, with per-machine hiscore boards signed from the shared name pool (detail in CHANGELOG, seams in ARCHITECTURE). Solo never takes the front door. Still open:

- [ ] **Stage furniture, further.** Moving bumpers (a fixed deterministic pattern, like the practice machine's sweep), per-stage warp walls (needs `sideWalls` to become rink state the way bumpers and bricks are), bumpers set into the boards. The stage seam (`TableStage`) is ready to carry them.
- Unscheduled sub-idea: a daily seeded challenge — the deterministic sim hands everyone the same table that day for free.

## Release & submission — *1.0 by definition*

The lane is in place (see [RELEASING.md](RELEASING.md)) and builds are shipping to TestFlight.

- [ ] The App Store Connect listing: text, screenshots, and the privacy/age answers.
- [ ] Final balancing pass with the dials, then bake the defaults.
- [ ] Submit, await review, release.

## Backlog (unversioned)

- [ ] An **AI hand** to fill an empty slot — a `ControlSource` like any other. Not the premise (this is a game for people in a room), so only if it costs little. The seam is proven: Practice's `PatternControlSource` already drives a slot; this bullet is the version that *aims*.
- [ ] Finnish/Japanese localization (String Catalog makes this translation-only).

## Ideas to evaluate — *not scheduled*

A parking lot for what could flesh the game out before 1.0. None of these is committed; each earns a milestone only if, tried on a device, it makes a game between people better. Ordered roughly by how much they lean on what already exists.

- [ ] **More pinball furniture.** Bumpers and bricks shipped with the arcade; the same idea extends to spinners, one-way gates, targets, a multiplier lane — each a fixed piece riding the one collision routine, placeable per stage (`TableStage`) or, later, on couch-table variants.
- [ ] **A curved table (the ellipse).** An ellipse wastes less portrait space than a circle and brings **curved walls**, where the bounce angle depends on *where* on the wall you hit — reflection off the local tangent, not a fixed normal. **Goals are pie-slices** of the perimeter (defend an arc, not a gap in a flat wall). The payoff — the reason it's worth building — is the **rolling shot**: a low, wall-hugging shot with forward spin that hugs the curve through each bounce and accelerates toward the goal, a skill the flat table can't express (needs grip-spin, above; disc spin is invisible, so decide then whether a drawn puck symbol shows rotation). Cost is a whole table's worth of physics — elliptical-sector mallet zones, an angular goal test, and generalizing `PolygonCollision` off its axis-aligned assumption to an arbitrary wall normal. Comparable to the shaped-puck spike, so a spike not a variant; iPad-forgiving, and off the singles/doubles path.
- [ ] **Nearby multiplayer.** Two devices, each its own table half, over the local network — no server, no accounts. The sim was built for it: inputs are data and the state is deterministic, so host-authoritative snapshots or lockstep over MultipeerConnectivity (as Skid does) is reachable without a rewrite. Changes the premise (one shared screen) enough that it needs its own decision before any code; listed so it isn't forgotten, not because it is planned.
- [ ] **Multi-device tournaments.** Several tables in the same room, each a device, feeding one bracket. Recorded because it follows from tournaments plus nearby play; judged *not important*: hard to see the game drawing crowds that need it, and it costs a network layer otherwise unneeded.

## Deliberately out of scope

Per [ARCHITECTURE.md](ARCHITECTURE.md): no ads, no IAP, no accounts, no server, no leaderboards, no third-party runtime dependencies. **No Mac, watch or TV target, ever** — the game is one handheld screen shared by the people around it. Networked play across devices is an idea to evaluate (above), not a plan.
