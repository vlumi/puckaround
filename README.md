# Puck Around

[![CI](https://github.com/vlumi/puckaround/actions/workflows/ci.yml/badge.svg)](https://github.com/vlumi/puckaround/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/vlumi/puckaround/branch/main/graph/badge.svg)](https://codecov.io/gh/vlumi/puckaround)

Air hockey for iPhone and iPad — people around **one device**, a goal each end,
one or two mallets a side (1v1, 1v2, 2v2).

> **Status: in TestFlight, pre-1.0.** "Puckaround" is the short repo/target
> name; the game ships as **Puck Around**. How it's built:
> [ARCHITECTURE.md](ARCHITECTURE.md). How to work on it: [AGENTS.md](AGENTS.md).
> What's next: [ROADMAP.md](ROADMAP.md).

## The idea

Put the phone (better: the iPad) flat on the table. Each of you takes an end.
A puck slides on the ice between you; your finger drags your mallet, your
mallet hits the puck, and the puck goes in the other goal or doesn't. The
player scored on gets the puck back; first to seven wins. That's the whole
game, and it's the one everybody already knows how to play.

Each side fields one or two mallets, so a two-player duel, an uneven 1v2, or
2v2 partners are all the same game — a pair of "one hand or two?" choices, not
a player count. In doubles a side's goal widens (two defenders make a narrow
one trivial) and its half splits into left/right lanes.

The device is the table. There is no network, no account, no server — the
people playing are all within arm's reach of the same screen.

Planned arc:

- **Find the fun first** — done: the core plays well on a device (the mallet,
  the drag, the bounce), so building on it is fair game now.
- **The couch** — singles/doubles, shaped and spinning pucks, wrap-wall tables,
  tournaments on remembered names in their own colors, practice against the
  machine, a three-cabinet solo arcade, and a front door have all shipped;
  what's left is polish on the way to 1.0.
- **A curved table** — an ellipse with slice goals, where a spun puck can ride
  the wall toward the goal. A later spike.

## Principles

- **All graphics procedural** — table, puck, mallets and the app icon are drawn
  in code; no image assets.
- **The same input feeds every mallet** — a finger, a future AI, anything: all
  produce one movement per mallet per tick, into one deterministic simulation.
- **iPhone and iPad only, iOS 16 up** — an iPhone 8 still counts as a table.
- **English-only for now**, built on a String Catalog from day one so more
  languages are drop-in later.
- No server, no accounts, no tracking.

## Version history

Pre-1.0, iterating in TestFlight. See [CHANGELOG.md](CHANGELOG.md) for what's
landed on `main` and [ROADMAP.md](ROADMAP.md) for what's next.

## License

MIT. See [LICENSE](LICENSE).
