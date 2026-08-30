# Changelog

All notable changes to Puck Around are documented here. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Grouped by **marketing version** (a roadmap milestone), then by **build number** within it — the version stays steady while the build climbs each TestFlight upload (see [RELEASING.md](RELEASING.md)). The build heading is just `### build N — <date>`; the version comes from the `## vX.Y.Z` above it.

Each version's top section, **Unreleased (next build)**, collects entries merged to `main` but not yet in a TestFlight build; cutting a release renames it to that build's heading and opens a fresh empty one. Keep that heading immediately followed by its list items (no prose between), so the release script can promote it. A user-facing PR writes its own bullet here.

The `## vX.Y.Z` heading is written by the release lane too, whenever a release cuts a new marketing version — so nothing about a version's heading is hand-set.

**One bullet, one line — no hard wrapping.** Editors soft-wrap and rendered Markdown ignores the line breaks, while hard wraps make an edited entry re-flow into a diff nobody can read. **Order the unreleased list by what a player notices**, not by merge order, and fold entries that tell one story into one bullet.

## v0.1.0

### Unreleased (next build)

- **Change the setup without leaving the table.** Tap the center ring and there's a new Settings button — players, first-to, match length, puck and walls, the same choices as the front page. Change anything and the game restarts with it; leave it untouched and play resumes where it was. No more quitting to the title just to switch the puck.
- **A "?" for a random puck or table.** Both the Puck and Walls pickers now offer a "?" — pick it and the shape (or solid-vs-wrap) is rolled fresh at the start of each game, so you don't know what you're getting until it drops. The two roll independently.
- **Play a match, not just a game.** Pick "Best of 3" or "Best of 5" under Match and a win takes a game, not the whole thing — first to two (or three) games takes the match. Between games it's a fresh faceoff with the points reset, and a row of pips by each score tracks who's ahead. The result names what just ended — GAME won/lost between games, MATCH when it's decided — so it's never unclear whether the match is over. "Single" is the old one-game behavior.

### build 6 — 2026-08-29

- **Wrap-around walls, a new table variation.** Pick "Wrap" under Walls and the long side walls become portals — a shot that would glance off the side slides off one edge and reappears on the other at the same height, keeping its speed, so you can bank the puck right around the table. The goals stay solid. Works with any puck and any number of players.
- **Shots into the goal corner count.** A shot that clips a goal post now deflects off the post and carries in, instead of pinging back onto the table — and the goal is drawn at its true scoring width, so what looks in is in. A steep shot into the corner is a goal, not a mystery bounce.
- **The edge-swipe guard actually works now.** Build 5's attempt to make a bottom-edge swipe take a deliberate second try didn't take effect — the first swipe still dropped you to the app switcher. It's wired up correctly now, and only while a game is on the table, not on the menu. (iOS still never lets an app fully block the swipe.)

### build 5 — 2026-08-29

- **The round puck takes spin now.** Clip it with a moving mallet and it picks up english — a little dot on the puck shows which way it's turning — and a spinning puck skews off the walls instead of bouncing straight. It's a gentler effect than the square or triangle (a disc has no corners to catch), a finesse tool rather than a big swing.
- **Grabbing your mallet is more forgiving.** Put your finger on or near the mallet and it snaps under your thumb; land far from it and nothing happens until you swipe over to it — so coming back to the table after lifting your hand no longer drives the mallet from an awkward offset.
- **A stray edge swipe won't yank you out mid-rally.** Fingers skating along the bottom of the screen during play no longer trip the app-switch gesture on the first brush — it now takes a deliberate second swipe to leave. (iOS never lets an app fully block that swipe; this makes it much harder to hit by accident.)
- **The score no longer touches the wall.** It sits clear of the boards now, including in doubles where the wider goal used to crowd it into the corner.

### build 4 — 2026-08-29

- **Play doubles, or one against two.** The front page now sets each side's players separately — one or two per end, facing off across a "VS." — so you can play 1v1, 2v2, or an uneven 1v2. In doubles a side fields two mallets, one keeping each half of its end, with a line down the middle marking the two players' territory; the goal is wider to match the extra defender, and both mallets of a side share its color as one team.
- **Everyone gets their own "Ready?".** During the faceoff each player is prompted in their own patch of the table and readies up by grabbing their mallet, so in doubles it's clear which partner the game is still waiting on. The result of a finished game is still shown once per side, WIN or LOSE.
- **The faceoff goes off with a bang.** When everyone's readied and play begins, the force field bursts — a ring flares out from the center, with a whistle-crack sound and a haptic pop — instead of just quietly vanishing. You can feel the GO.
- **Opening the menu pauses the game.** Tapping the center ring now freezes the puck while the menu is up, and picks up exactly where it left off — no more play carrying on behind your back.
- **The front page fits every screen.** The menu now sits centered on iPad and scrolls on a small iPhone, instead of crowding into a corner or pushing Play off the bottom.

### build 3 — 2026-08-28

- **Pick your puck.** The front page now offers a round, square or triangular puck. The shaped ones tumble — a corner catching the boards starts them spinning, and a spinning puck skews off the wall at an angle that depends on how it's turning, so a rally with a square or triangle is a scramble. The round puck plays exactly as before. A first taste of puck variety.
- **A goal counts when the whole puck is over the line.** The puck now flies all the way into the goal before it warps back to center, instead of vanishing the instant it touched the line — the same for every shape.
- **A mallet can move through the center again.** The center-ring menu no longer swallows the touch that grabs or drives a mallet across the middle — a drag through the ring is play, only a tap opens the menu.

### build 2 — 2026-08-28

- **A front page.** The app opens to a title screen now — pick how many goals win (first to 3, 5, 7 or 11) and hit Play, rather than dropping straight onto the table.
- **Play again is just another faceoff.** When a game ends, the result stays up and the faceoff comes straight back — both players ready up to rematch, and the score resets the moment it starts. No button to hunt for.
- **The center ring is the menu.** Tap the middle of the table any time — mid-game or between games — for Resume, Restart (a clean new game, nobody readied), or Quit to menu. One neutral control that belongs to neither player, so leaving never means going through a restart.
- **Games start with a faceoff.** Instead of the puck landing in someone's half, it sits frozen in the middle behind a glowing force field, and each player's side shows "Ready?". Grab your mallet to ready up — the instant everyone has, the field drops and it's a scramble for the puck, hands already on. Nobody can nudge the puck early: your mallet can't cross into the force field. (After a goal it's still served to whoever conceded — the ceremony is just for the kickoff.)
- **The puck can't get stuck on a wall any more.** A puck pinned in a corner or against the boards used to be unrescuable — no hit could reach it. Now the table peels it off the wall the moment nothing's holding it there, so a stuck puck frees itself.
- **A neon-cabinet look.** The table glows now: a dark rink with a faint grid, a white-hot puck that trails when it's moving fast, and each player's color — hot magenta, electric cyan — on their mallet, their goal and their score, so you can always tell whose is whose. The app icon is the same rink, shrunk. The glow eases off if you have Reduce Motion on.
- **The table has a voice.** Every hit, wall bounce and goal now makes a sound and a haptic tap, scaled to how hard it was — a click off the mallet, a duller knock off the boards, a two-note horn on a goal, and a flourish when the game is won. The device buzzes for everyone at the table at once. Sound honors the silent switch and mixes with your music.
- **A puck pinned against the wall squirts out along it** instead of passing through the mallet and shooting off backwards — the "mallet warps through the puck" seen when slamming it into the side.

### build 1 — 2026-08-27

- **Air hockey, one on one.** A puck on a walled table with a goal at each end and a mallet for each of the two players, dragged by the first finger down in their own half — the mallet follows the finger's movement, can touch the center line but never cross it, and the puck bounces off it (a still mallet is a wall). Score by putting the puck through the other goal; the player scored on gets the puck; first to seven wins — each end of the table then reads WIN or LOSE the right way up for its own player, and a restart ring on the center line starts over — the mallets stay live and where they are throughout, since they are the players' hands. Scores sit in the corner beside each goal, out of the mallet's way, each facing its player. The other seats (three and four players) wait on a decision about where their goals would go.
