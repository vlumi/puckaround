# Roadmap

The implementation plan, as **named milestones in rough order** — and *only open work*. This file is *expected to churn*: milestones get reshaped as prototyping answers questions, and everything before 1.0 is beta by definition (TestFlight from the first cut). As work ships it leaves this file — brief summaries go to the [README version history](README.md#version-history), full detail to [CHANGELOG.md](CHANGELOG.md), and settled rules and design decisions to [ARCHITECTURE.md](ARCHITECTURE.md) or the plan under `docs/` that owns them. This file is only *when*, not *why*.

**No hard line wraps** — one paragraph or bullet, one line; editors soft-wrap and rendered Markdown ignores the breaks anyway.

**Milestones are not version numbers.** A version is assigned when a milestone is *cut*, not when it is planned — some of these will be reordered, split, or dropped outright, and renumbering the rest each time is the churn that stops a roadmap being updated at all.

Guiding order: **the flick is the game**, and **what comes early is whatever answers a question that changes the plan**.

## Open decisions — *settle these before building on them*

Each of these changes what gets built next, and none can be settled from a spec.

- [ ] **Which game first?** The sim is table-agnostic; the first *rules* are not. Candidates: **air hockey** (a goal in each of two facing walls; 1v1, and 2v2 with partners across from each other), a **four-goal free-for-all** (every seat defends its own edge), a **shuffleboard-style** scoring zone. Pick one to make the first playable thing, and let the others be modes later.
- [ ] **The strike model.** Swipe-through is built (a moving finger that crosses the puck gives it its velocity). The alternative is a **mallet** — a disc you drag that the puck bounces off, which also makes a still finger a wall. Needs an A/B on a device, ideally with the same table under both.
- [ ] **Team seating.** Partners currently sit across from each other (bottom + top vs. left + right). Adjacent partners is the other reading; the right one depends on which game ships first.

## One puck, one table — *find the fun*

The v0.1 sandbox is built and this milestone is about driving it on hardware: two hands on a phone, four on an iPad.

- [ ] **Tune the table on device.** Drag, wall restitution, the speed cap, the serve speed and the finger radius are constants in `Playfield`; turn them into on-device dials (a tuning panel, the sibling projects' pattern) so feel gets settled by play rather than by editing numbers.
- [ ] **iPad sizing.** A square table on a 13-inch screen may want margins, or may want to be as big as it can; and a portrait phone table held landscape needs a decision.
- [ ] **Multi-touch limits.** iPhones track about five simultaneous touches, iPads about eleven; four seats with two fingers each is over the phone's budget — measure what happens, and decide whether the phone is a two- or three-seat table.

## A game — *the first rules*

Gated on the open decisions above.

- [ ] Goals in the table's walls, a score per seat (or team), a serve after each goal toward the conceding side, a win at N.
- [ ] The lineup as a real setup step rather than a HUD button: player count, teams, and which game.
- [ ] Per-seat chrome facing its player — a score readout readable from where they sit.

## The couch — *who is playing*

- [ ] **The front door.** Who is at the table, then what to play; seat colors chosen by the players; side-by-side vs. face-to-face for two on an iPad.
- [ ] **Sound & haptics**, procedural. One haptic engine per device is a constraint worth designing around: the device buzzes for everyone.
- [ ] **A record of the session.** A running tally across games, so the last twenty minutes happened.

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
