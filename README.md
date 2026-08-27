# Puck Around

[![CI](https://github.com/vlumi/puckaround/actions/workflows/ci.yml/badge.svg)](https://github.com/vlumi/puckaround/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/vlumi/puckaround/branch/main/graph/badge.svg)](https://codecov.io/gh/vlumi/puckaround)

A tabletop puck game for iPhone and iPad — two to four people around **one
device**, batting a puck about with their fingers.

> **Status: prototype.** "Puckaround" is the short repo/target name; the game
> ships as **Puck Around**. How it's built: [ARCHITECTURE.md](ARCHITECTURE.md).
> How to work on it: [AGENTS.md](AGENTS.md). What's next: [ROADMAP.md](ROADMAP.md).

## The idea

Put the phone (better: the iPad) flat on the table. Everyone takes an edge. A
puck slides on the screen between you, and a finger swept across it sends it
off at the finger's own speed — that's the whole input. Two players face each
other across the table; three or four take the remaining edges, and four can
pair up into two teams.

The device is the table. There is no network, no account, no server — the
people playing are all within arm's reach of the same screen.

Planned arc:

- **Find the fun first.** One puck, one table, 2–4 seats. Prove that flicking a
  puck around glass feels good — the strike model, the drag, the bounce — before
  anything is built on top.
- **Then a game.** Goals and scoring; which puck game comes first is open.
- **Then the couch.** Who is playing, seat colors, chrome that faces each
  player, sound and haptics.

## Principles

- **All graphics procedural** — table, puck, seats and the app icon are drawn in
  code; no image assets.
- **The same input feeds every seat** — a finger, a future AI, anything: all
  produce one input value per seat per tick, into one deterministic simulation.
- **iPhone and iPad only, iOS 16 up** — an iPhone 8 still counts as a table.
- **English-only for now**, built on a String Catalog from day one so more
  languages are drop-in later.
- No server, no accounts, no tracking.

## Version history

Nothing has shipped yet. See [CHANGELOG.md](CHANGELOG.md) for what's landed on
`main` and [ROADMAP.md](ROADMAP.md) for what's next.

## License

MIT. See [LICENSE](LICENSE).
