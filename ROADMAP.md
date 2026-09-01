# Roadmap

The implementation plan, as **named milestones in rough order** — and *only open work*. This file is *expected to churn*: milestones get reshaped as prototyping answers questions, and everything before 1.0 is beta by definition (TestFlight from the first cut). As work ships it leaves this file — brief summaries go to the [README version history](README.md#version-history), full detail to [CHANGELOG.md](CHANGELOG.md), and settled rules and design decisions to [ARCHITECTURE.md](ARCHITECTURE.md). This file is only *when*, not *why*.

**No hard line wraps** — one paragraph or bullet, one line; editors soft-wrap and rendered Markdown ignores the breaks anyway.

**Milestones are not version numbers.** A version is assigned when a milestone is *cut*, not when it is planned — some of these will be reordered, split, or dropped outright, and renumbering the rest each time is the churn that stops a roadmap being updated at all.

Guiding order: **the mallet is the game**, and **what comes early is whatever answers a question that changes the plan**.

Shipped so far (in TestFlight, detail in [CHANGELOG.md](CHANGELOG.md)): 1v1/1v2/2v2 air hockey with the faceoff/rematch flow, best-of matches, round/square/triangle pucks with spin (polygon and disc) and up to three at once, wrap-wall tables, "?" randoms, tournaments in three shapes (winner stays, brackets, league seasons) with remembered names, practice against the machine, landscape play, sound + haptics, and a front door with the New match modal. What's left is below.

## Tune & fit — *the table on real hardware*

- [ ] **Tune the table on device.** Drag, wall restitution, the speed cap, mallet and goal sizes are constants in `Playfield`; turn them into on-device dials (a tuning panel, the sibling projects' pattern) so feel gets settled by play rather than by editing numbers.
- [ ] **iPad sizing.** A portrait table on a 13-inch screen may want margins, or may want to be as big as it can. (Landscape is settled: the board follows the phone and fills the screen.)
- [ ] **Pace levels.** A pick in setup for how fast the table plays — the puck's speed cap (and probably drag with it), a few presets from a gentle warm-up to a frantic one. `maxSpeed` is already a `Playfield` constant, so this is a value setup chooses, not a physics change. **Frame it as pace, not difficulty**: both sides share the same table, so a faster cap raises the intensity for everyone equally — it is not an easier/harder opponent. Real per-side difficulty only means something once there's an AI hand or a solo mode, and then it lives in *those*. Belongs to setup, never a mid-game control.

## The couch — *who is playing*

Tournaments shipped in all three shapes — winner stays, knockout brackets, and league seasons — on remembered names (a tap-to-pick pool, no profiles). Left here:

- [x] **A color of one's own.** Shipped for tournaments (the arcade's boards inherit it when they land); the captain rule below stays dormant. As decided 2026-09-01: each pool name carries two kits — home and away — from a small traditional-neon palette (~8 hues; auto-assigned on first add so the zero-tap flow survives, picking is optional editing; the name stays the only identity). Named play wears the color on the table itself — mallet, goal, score and verdicts (the `SeatPalette` seam; the sim stays side-based, and nameless free play keeps classic magenta/cyan). A clash switches exactly one side to its away kit: the home side is the winner-stays incumbent (their turf), otherwise the bottom end — and a player's away is by definition distinct from their own home, so one step always resolves it. Palette curation gates on surroundings, not opponents: every hue must read against the dark ground, grid and white puck; distinguishing players is positional (your end is under your own hands), so pair-contrast is a nice-to-have. Dormant until names meet teams: in doubles the first-seated player is the captain (a marked chip) and the team wears their kit.

## Puck & table variety — *what changes how it plays*

- [ ] **Shaped-puck follow-ons, if play asks for them.** Triangle-specific feel; **per-vertex goals** (today a goal needs the puck CENTER fully past the line, so a corner poked in early doesn't count — fine so far); more shapes only if they behave distinctly (a hexagon is basically a disc).
- [ ] **Grip-spin that rides the wall** — the coupling that makes a low, wall-hugging shot with forward spin accelerate toward the goal. Its real home is the **ellipse table** (below): a curved wall can carry the puck along it, which a flat wall can't. Builds on the shipped disc spin. A later spike.
- [ ] **More table variants.** Bumpers on the ice, two pucks, a moving goal — each a table variant beside solid/wrap, grouped under one picker (`SideWalls` is the seam for that grouping).

## The arcade — *solo minigames on the same physics*

Decided 2026-09-01: solo content lives behind one Arcade shelf so the front door stays "people around one screen", and minigames reuse the sim rather than growing a second engine. Doesn't gate 1.0.

- [ ] **The seams first.** Static obstacles — a bumper is a mallet that never moves and adds speed (the same piece the multiplayer table variants want); a brick is a static rect that vanishes on hit — plus a score-attack loop (score, lives, game over) and the hiscore table.
- [ ] **Hiscores, arcade-rendered.** Top 10 per minigame — rank, name, score in neon uppercase. Entry goes through the same remembered-name pool as tournaments (extract RosterSheet's picker; the 12-char IME-safe cap already fits beside a score), so a regular signs a record in one tap and the board says who actually holds it — no three-letter truncation collisions. Each minigame has one canonical config so scores stay comparable; no "?" randoms on the board.
- [ ] **Bumper field (pinball-lite).** Your mallet is the flipper: keep the puck off your own goal while bumpers pay points. The cheapest new physics, and it proves the obstacle seam for everything else.
- [ ] **Breakout, fused with the goal.** A brick wall defends the top goal mouth — chip through and score into it; draining into your own goal costs a life. Static-rect collision is the genuinely new piece (`PolygonCollision` is close).
- [ ] **Survival.** The machine feeds pucks and the pace ramps; the score is how long your goal stays clean. Nearly free — multi-puck, the machine mallet and serving all exist.
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

- [ ] **Pinball-style obstacles.** Bumpers on the ice — fixed discs (or pads) the puck bounces off, maybe with a kick. Cheap: the mallet collision is already a kinematic circle, so a bumper is a mallet that never moves and adds speed. The design question is placement — a few table layouts to choose from, not an editor. Once bumpers exist, more pinball furniture is the same idea: spinners, one-way gates, targets, a multiplier lane — each a fixed piece riding the one collision routine.
- [ ] **A curved table (the ellipse).** An ellipse wastes less portrait space than a circle and brings **curved walls**, where the bounce angle depends on *where* on the wall you hit — reflection off the local tangent, not a fixed normal. **Goals are pie-slices** of the perimeter (defend an arc, not a gap in a flat wall). The payoff — the reason it's worth building — is the **rolling shot**: a low, wall-hugging shot with forward spin that hugs the curve through each bounce and accelerates toward the goal, a skill the flat table can't express (needs grip-spin, above; disc spin is invisible, so decide then whether a drawn puck symbol shows rotation). Cost is a whole table's worth of physics — elliptical-sector mallet zones, an angular goal test, and generalizing `PolygonCollision` off its axis-aligned assumption to an arbitrary wall normal. Comparable to the shaped-puck spike, so a spike not a variant; iPad-forgiving, and off the singles/doubles path.
- [ ] **Nearby multiplayer.** Two devices, each its own table half, over the local network — no server, no accounts. The sim was built for it: inputs are data and the state is deterministic, so host-authoritative snapshots or lockstep over MultipeerConnectivity (as Skid does) is reachable without a rewrite. Changes the premise (one shared screen) enough that it needs its own decision before any code; listed so it isn't forgotten, not because it is planned.
- [ ] **Multi-device tournaments.** Several tables in the same room, each a device, feeding one bracket. Recorded because it follows from tournaments plus nearby play; judged *not important*: hard to see the game drawing crowds that need it, and it costs a network layer otherwise unneeded.

## Deliberately out of scope

Per [ARCHITECTURE.md](ARCHITECTURE.md): no ads, no IAP, no accounts, no server, no leaderboards, no third-party runtime dependencies. **No Mac, watch or TV target, ever** — the game is one handheld screen shared by the people around it. Networked play across devices is an idea to evaluate (above), not a plan.
