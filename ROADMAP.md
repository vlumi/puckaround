# Roadmap

The implementation plan, as **named milestones in rough order** — and *only open work*. This file is *expected to churn*: milestones get reshaped as prototyping answers questions, and everything before 1.0 is beta by definition (TestFlight from the first cut). As work ships it leaves this file — brief summaries go to the [README version history](README.md#version-history), full detail to [CHANGELOG.md](CHANGELOG.md), and settled rules and design decisions to [ARCHITECTURE.md](ARCHITECTURE.md) or the plan under `docs/` that owns them. This file is only *when*, not *why*.

**No hard line wraps** — one paragraph or bullet, one line; editors soft-wrap and rendered Markdown ignores the breaks anyway.

**Milestones are not version numbers.** A version is assigned when a milestone is *cut*, not when it is planned — some of these will be reordered, split, or dropped outright, and renumbering the rest each time is the churn that stops a roadmap being updated at all.

Guiding order: **the mallet is the game**, and **what comes early is whatever answers a question that changes the plan**.

## Settled — *2026-08-27*

**Air hockey, with mallets, plain 1v1 under the standard rules first.** The swipe-through strike model is gone; the reasons and the parked four-seat question are in [docs/air-hockey-plan.md](docs/air-hockey-plan.md). Still to test on a device: **movement-drag vs. direct placement** of the mallet (a one-line sim change), and team seating (partners across or adjacent), which only matters once four seats have a table.

## Air hockey 1v1 — *find the fun*

The game is built and this milestone is about driving it on hardware: two thumbs on a phone, two hands on an iPad.

- [ ] **Tune the table on device.** Drag, wall restitution, the speed cap, mallet and goal sizes are constants in `Playfield`; turn them into on-device dials (a tuning panel, the sibling projects' pattern) so feel gets settled by play rather than by editing numbers.
- [ ] **Mallet drag A/B.** Movement-drag (built) against direct placement under the finger, on the same table.
- [ ] **iPad sizing.** A portrait table on a 13-inch screen may want margins, or may want to be as big as it can; and a table held landscape needs a decision.
- [ ] **Per-seat chrome facing its player.** The score and the WIN/LOSE verdict already turn toward their seat, and the restart ring is symmetric; the mid-game New game corner button still faces the bottom seat only.

## The couch — *who is playing*

- [ ] **The front door.** Who is at the table, then what to play; seat colors chosen by the players; the HUD button becomes a real setup step (player count, first-to-N).
- [ ] **Sound & haptics**, procedural. One haptic engine per device is a constraint worth designing around: the device buzzes for everyone.
- [ ] **A record of the session.** A running tally across games, so the last twenty minutes happened.

## Four players — *parked on a design question*

`Lineup` already seats 3–4 and pairs 2v2; the sim's seats-in-order rule holds for any count. What is missing is a table with room for their goals, and that is a decision, not code:

- [ ] **Where do the goals go?** One per seat's wall on a square table; corners; or one shared goal per team. An iPhone is far from square, so two of four seats would get a cramped half.
- [ ] **Is four on a phone workable at all?** Four hands round a 6-inch screen may make this an iPad-only format. Nothing decides it but trying — and iPhones track about five simultaneous touches, so measure that too.

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

## Deliberately out of scope

Per [ARCHITECTURE.md](ARCHITECTURE.md): no ads, no IAP, no accounts, no server, no leaderboards, no third-party runtime dependencies. **No Mac, watch or TV target, ever** — the game is one handheld screen shared by the people around it — and for the same reason networked play across devices is not planned.
