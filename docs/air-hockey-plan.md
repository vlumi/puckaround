# Air hockey first: the game, the mallet, and the parked four-seat question

Decided 2026-08-27. What the first game is, why it is that one, and what was
deliberately left open.

## The game is air hockey

Of the candidates the sandbox could have carried — air hockey, a four-goal
free-for-all, a shuffleboard-style scoring zone — air hockey is the one people
already know how to play. The rules need no screen to explain them: a goal at
each end, a mallet each, first to seven. **Plain 1v1 with the standard rules
first**; every other format waits behind it.

## The mallet, not the swipe

The sandbox shipped with swipe-to-strike: a finger sweeping across the puck
gave it the finger's velocity, and a resting finger did nothing. It made a
lively toy and a poor game — nothing to defend a goal with, and a puck that
passes under a still hand. Air hockey is *played* with the mallet, so the
mallet is the input: a disc each, confined to its own half, that the puck
bounces off; a still mallet is a wall, a moving one a strike.

**Dragged by movement, not placed under the finger.** The seat's input is how
far the hand moved this tick, and the sim adds it to the mallet and clamps to
the half. Two reasons: a finger landing anywhere in the half takes the mallet
without teleporting it into the puck, and the finger never has to cover the
mallet to use it — on a phone the mallet is under a thumb otherwise. Worth an
A/B against direct placement on device; it is one line in the sim.

**The first finger down in a half drives that mallet**; further fingers of
the same seat are ignored until it lifts. Together with the rule that a touch
belongs to the seat it began in, this keeps two hands on one screen
unambiguous without any handshake.

## Three and four seats — parked

`Lineup` models 2–4 seats and 2v2 teams, and the sim's seats-in-order rule
holds for any count. What does not exist is a table for them, and that is a
design question rather than a coding one:

- **Where are the goals?** One in every seat's wall makes a square table with
  four mouths — and an iPhone's screen is a long way from square, so two of
  the four seats get the short walls and a cramped half. Goals in the corners,
  or a shared goal per team, are the other readings.
- **Is it workable on a phone at all?** Four hands round a 6-inch screen may
  simply be an iPad-only format. Nothing decides that but trying it.

Until those are answered, `Rink` refuses anything but the duel, and the
roadmap holds the question under *Four players*.
