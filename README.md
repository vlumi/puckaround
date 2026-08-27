# Puck Around

[![CI](https://github.com/vlumi/puckaround/actions/workflows/ci.yml/badge.svg)](https://github.com/vlumi/puckaround/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/vlumi/puckaround/branch/main/graph/badge.svg)](https://codecov.io/gh/vlumi/puckaround)

Air hockey for iPhone and iPad — two people around **one device**, a mallet
each, a goal each.

> **Status: prototype.** "Puckaround" is the short repo/target name; the game
> ships as **Puck Around**. How it's built: [ARCHITECTURE.md](ARCHITECTURE.md).
> How to work on it: [AGENTS.md](AGENTS.md). What's next: [ROADMAP.md](ROADMAP.md).

## The idea

Put the phone (better: the iPad) flat on the table. Each of you takes an end.
A puck slides on the ice between you; your finger drags your mallet, your
mallet hits the puck, and the puck goes in the other goal or doesn't. The
player scored on gets the puck back; first to seven wins. That's the whole
game, and it's the one everybody already knows how to play.

Three and four players — a seat on every edge, two-a-side — are designed for
in the model but not on the table yet: where their goals would go, and
whether four hands fit round a phone at all, is an open question.

The device is the table. There is no network, no account, no server — the
people playing are all within arm's reach of the same screen.

Planned arc:

- **Find the fun first.** 1v1 air hockey is built; prove it feels good on a
  device — the mallet, the drag, the bounce — before anything is built on top.
- **Then the couch.** Who is playing, seat colors, chrome that faces each
  player, sound and haptics.
- **Then more seats**, once the four-goal table has a shape.

## Principles

- **All graphics procedural** — table, puck, seats and the app icon are drawn in
  code; no image assets.
- **The same input feeds every seat** — a finger, a future AI, anything: all
  produce one mallet movement per seat per tick, into one deterministic
  simulation.
- **iPhone and iPad only, iOS 16 up** — an iPhone 8 still counts as a table.
- **English-only for now**, built on a String Catalog from day one so more
  languages are drop-in later.
- No server, no accounts, no tracking.

## Version history

Nothing has shipped yet. See [CHANGELOG.md](CHANGELOG.md) for what's landed on
`main` and [ROADMAP.md](ROADMAP.md) for what's next.

## License

MIT. See [LICENSE](LICENSE).
