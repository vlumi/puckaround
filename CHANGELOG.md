# Changelog

All notable changes to Puck Around are documented here. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Grouped by **marketing version** (a roadmap milestone), then by **build number** within it — the version stays steady while the build climbs each TestFlight upload (see [RELEASING.md](RELEASING.md)). The build heading is just `### build N — <date>`; the version comes from the `## vX.Y.Z` above it.

Each version's top section, **Unreleased (next build)**, collects entries merged to `main` but not yet in a TestFlight build; cutting a release renames it to that build's heading and opens a fresh empty one. Keep that heading immediately followed by its list items (no prose between), so the release script can promote it. A user-facing PR writes its own bullet here.

The `## vX.Y.Z` heading is written by the release lane too, whenever a release cuts a new marketing version — so nothing about a version's heading is hand-set.

**One bullet, one line — no hard wrapping.** Editors soft-wrap and rendered Markdown ignores the line breaks, while hard wraps make an edited entry re-flow into a diff nobody can read. **Order the unreleased list by what a player notices**, not by merge order, and fold entries that tell one story into one bullet.

## v0.1.0

### Unreleased (next build)

- **Air hockey, one on one.** A puck on a walled table with a goal at each end and a mallet for each of the two players, dragged by the first finger down in their own half — the mallet follows the finger's movement, can touch the centre line but never cross it, and the puck bounces off it (a still mallet is a wall). Score by putting the puck through the other goal; the player scored on gets the puck; first to seven wins — each end of the table then reads WIN or LOSE the right way up for its own player, and a restart ring on the centre line starts over — the mallets stay live and where they are throughout, since they are the players' hands. Scores sit in the corner beside each goal, out of the mallet's way, each facing its player. The other seats (three and four players) wait on a decision about where their goals would go.
