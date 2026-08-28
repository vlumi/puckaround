# Changelog

All notable changes to Puck Around are documented here. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Grouped by **marketing version** (a roadmap milestone), then by **build number** within it — the version stays steady while the build climbs each TestFlight upload (see [RELEASING.md](RELEASING.md)). The build heading is just `### build N — <date>`; the version comes from the `## vX.Y.Z` above it.

Each version's top section, **Unreleased (next build)**, collects entries merged to `main` but not yet in a TestFlight build; cutting a release renames it to that build's heading and opens a fresh empty one. Keep that heading immediately followed by its list items (no prose between), so the release script can promote it. A user-facing PR writes its own bullet here.

The `## vX.Y.Z` heading is written by the release lane too, whenever a release cuts a new marketing version — so nothing about a version's heading is hand-set.

**One bullet, one line — no hard wrapping.** Editors soft-wrap and rendered Markdown ignores the line breaks, while hard wraps make an edited entry re-flow into a diff nobody can read. **Order the unreleased list by what a player notices**, not by merge order, and fold entries that tell one story into one bullet.

## v0.1.0

### Unreleased (next build)

- **A front page.** The app opens to a title screen now — pick how many goals win (first to 3, 5, 7 or 11) and hit Play, rather than dropping straight onto the table.
- **A way out of a game.** A dim menu dot on the centre line pauses to Resume, Restart, or Quit to menu — so you can abandon or restart a game in progress. And when a game ends, alongside the restart ring there's a Menu button to head back to the front page.
- **Games start with a faceoff.** Instead of the puck landing in someone's half, it sits frozen in the middle behind a glowing force field, and each player's side shows "Ready?". Grab your mallet to ready up — the instant everyone has, the field drops and it's a scramble for the puck, hands already on. Nobody can nudge the puck early: your mallet can't cross into the force field. (After a goal it's still served to whoever conceded — the ceremony is just for the kickoff.)
- **The puck can't get stuck on a wall any more.** A puck pinned in a corner or against the boards used to be unrescuable — no hit could reach it. Now the table peels it off the wall the moment nothing's holding it there, so a stuck puck frees itself.
- **A neon-cabinet look.** The table glows now: a dark rink with a faint grid, a white-hot puck that trails when it's moving fast, and each player's colour — hot magenta, electric cyan — on their mallet, their goal and their score, so you can always tell whose is whose. The app icon is the same rink, shrunk. The glow eases off if you have Reduce Motion on.
- **The table has a voice.** Every hit, wall bounce and goal now makes a sound and a haptic tap, scaled to how hard it was — a click off the mallet, a duller knock off the boards, a two-note horn on a goal, and a flourish when the game is won. The device buzzes for everyone at the table at once. Sound honours the silent switch and mixes with your music.
- **A puck pinned against the wall squirts out along it** instead of passing through the mallet and shooting off backwards — the "mallet warps through the puck" seen when slamming it into the side.

### build 1 — 2026-08-27

- **Air hockey, one on one.** A puck on a walled table with a goal at each end and a mallet for each of the two players, dragged by the first finger down in their own half — the mallet follows the finger's movement, can touch the centre line but never cross it, and the puck bounces off it (a still mallet is a wall). Score by putting the puck through the other goal; the player scored on gets the puck; first to seven wins — each end of the table then reads WIN or LOSE the right way up for its own player, and a restart ring on the centre line starts over — the mallets stay live and where they are throughout, since they are the players' hands. Scores sit in the corner beside each goal, out of the mallet's way, each facing its player. The other seats (three and four players) wait on a decision about where their goals would go.
