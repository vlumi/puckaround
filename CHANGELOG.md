# Changelog

All notable changes to Puck Around are documented here. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Grouped by **marketing version** (a roadmap milestone), then by **build number** within it — the version stays steady while the build climbs each TestFlight upload (see [RELEASING.md](RELEASING.md)). The build heading is just `### build N — <date>`; the version comes from the `## vX.Y.Z` above it.

Each version's top section, **Unreleased (next build)**, collects entries merged to `main` but not yet in a TestFlight build; cutting a release renames it to that build's heading and opens a fresh empty one. Keep that heading immediately followed by its list items (no prose between), so the release script can promote it. A user-facing PR writes its own bullet here.

The `## vX.Y.Z` heading is written by the release lane too, whenever a release cuts a new marketing version — so nothing about a version's heading is hand-set.

**One bullet, one line — no hard wrapping.** Editors soft-wrap and rendered Markdown ignores the line breaks, while hard wraps make an edited entry re-flow into a diff nobody can read. **Order the unreleased list by what a player notices**, not by merge order, and fold entries that tell one story into one bullet.

## v0.1.0

### Unreleased (next build)

- **One puck, one table.** The prototyping sandbox: a puck slides on a walled table and any finger that sweeps across it sends it off at the finger's own speed. Two, three or four seats sit around the device, one per edge, each finger belonging to the seat it came down in; four seats can pair up into two teams. Serve puts the puck back at centre. Not a game yet — the table for finding one.
