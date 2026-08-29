# Tables & modes: singles/doubles first, an ellipse to explore

Decided 2026-08-29. How multiplayer beyond 1v1 works, why it is framed as
singles/doubles rather than a player count, and the curved-wall table parked
as its own exploration. Nothing here is built yet; this records the direction
so the couch work builds against it.

## The insight: mallets, not player count

On the oblong table, **2v2, 1v1-with-two-mallets-each, and 1v2 are the same
game** — the same two goals, the same walls, the same mallet physics. What
differs is only *how many mallets a side has* and *how many hands drive them*,
never the geometry. So the setup is not "2, 3 or 4 players"; it is two
independent choices:

- **Singles or Doubles** — one mallet per side, or two. This is a property of
  the *table*.
- **Who drives each mallet** — a person per mallet, or one person working both
  mallets of a side. This is the couch's "who is playing", and it is now
  cleanly separated from the geometry.

The tennis vocabulary is legible at a glance, maps to how people sit down
("singles or doubles?"), and dissolves the awkward cases: **1v2 is just doubles
with one side short a player** (allow it or not, a UI choice), and **soloing
both your mallets in doubles is a real, harder mode for free**. There is no
three-player problem because there is no "three players" — there are sides with
mallets.

This is the near-term direction because it needs **almost no new geometry**:
`Lineup` already models a teamed four. What is new is a mallet-count on a side
and the input routing (a hand may own two mallets), plus one table tweak below.

### The doubles goal is wider

Two defenders make a narrow goal trivial to hold, so **the goal widens in
doubles** toward (nearly) the whole end — restoring scoring against two
mallets. It is one number (`goalWidth`), and it means singles and doubles are
subtly different games, which is good: doubles is a wider, more frantic target.
Whether they share a width is a tuning call; the default is *no*, doubles is
wider.

### Where the two mallets sit

Each side's half splits **left/right**, one mallet's zone per quadrant, so two
defenders don't fight over the same space (the existing "a mallet stays in its
zone" rule, one level finer). A player driving both mallets of a side reaches
across both quadrants; two players each keep their own.

## Not the first answer: square, triangle, circle

Weighed and deferred, because each is a *different table* (new geometry) and
most fit a portrait phone poorly:

- **Square, a goal per edge** (true four-way, four goals). Wastes half a
  portrait screen (a centerd square), and four thumbs crowd the shrunk field.
  **Corner goals** map better to the long axis but change the game (you defend
  a diagonal; a puck along an edge is safe — likely too defensive). The
  strongest *free-for-all* four-way, but free-for-all needs four goals, which
  the oblong can't give — so it is a later, probably iPad, table.
- **Triangle** (three equal edges/goals) is the only *fair* three-player shape,
  but fits portrait worse than a square and is cramped for three around a
  phone. Since singles/doubles removes the need for a three-player mode, this
  is unlikely to be built.
- **Circle** (2–4, arc goals) is elegant and scales, but letterboxes badly in
  portrait AND is the most expensive: curved walls and pie-slice zones are a
  physics rewrite. See the ellipse below, which keeps the exciting half.

## The exploration: an ellipse with slice goals and rolling spin

Parked as its own spike (like shaped pucks were), to run any time — independent
of the couch flow, and forgiving on iPad. The point is not a novelty shape; it
is a mechanic the round game can't have.

**An ellipse wastes less portrait space than a circle** (stretch it to the
phone's aspect) and brings curved walls, where the bounce angle depends on
*where* on the wall you hit — a genuinely different feel that pairs with the
shaped-puck spin already built. **Goals are pie-slices** of the perimeter, not
gaps in a flat wall: a player defends an arc segment, and a puck curving toward
a slice is a new defensive problem.

**The mechanic that makes it worth building — spin that rolls the wall.**
Crucially this wants spin on the ROUND puck too, not just polygons. Spin is
invisible on a disc, so either it stays a hidden state that only shows through
behavior, or **a small symbol is drawn on the puck** to make its rotation
readable (open question — decide when it is built; a mark that reads at a
glance without cluttering the neon puck). The walls are **not sticky or
rubbery by default** — a plain bounce. But a **low, wall-hugging shot with
forward spin** should keep the puck close to the curve through each bounce and
carry it along, accelerating toward the goal — a skill shot the flat table
can't express. This is the same spin↔surface coupling deferred as "grip-spin
on a round puck" on the roadmap; the ellipse is where it earns its place.

**Cost, honestly.** A whole table's worth of physics: curved-wall reflection
(off the local tangent, not a fixed normal), elliptical-sector mallet zones,
a goal test over an angular range, and generalising `PolygonCollision` to an
arbitrary wall normal (it assumes axis-aligned today). Comparable to the
shaped-puck spike. So: **a spike, not a variant** — prove the rolling shot is
fun before committing, and keep it off the singles/doubles path.

## Order

1. **Singles/Doubles on the oblong** (near-term). Unlocks the couch work — who
   is playing, seat colors — on the table that exists, plus the doubles goal
   width and quadrant zones. This is what the couch is built against.
2. **The ellipse + slice goals + rolling spin** (a later spike, any time).
   Independent; the exciting exploration; iPad-forgiving.

## Settled at build time (2026-08-29)

Building it clarified the model further:

- **Formats are per-side hand counts: 1v1, 1v2, 2v2.** Not a single
  singles/doubles switch — each side independently fields one or two mallets,
  so 1v2 is first-class, not an awkward "doubles short a player". `Format` is
  `(bottom: Hands, top: Hands)`.
- **Goal width is per side, and follows that side's hand count.** A one-hand
  side keeps the narrow goal; a two-hand side gets the wide one. So in 1v2 the
  lone defender faces a tight goal and the pair a broad one — the harder goal
  to keep goes to the better-staffed side. Fairer than a table-wide width, and
  it falls out of the per-side model for free.
- **No player/team identity in the sim.** A mallet is only its slot (side +
  lane); a goal is only its side. The sim tracks score per side and knows
  nothing of who holds what — "who's playing" is a couch/UI matter that ends
  when you leave the table. Own goals are allowed and need no special case: the
  puck crossing a side's own line is the other side's point, whoever touched it.
- **One color per side.** Both mallets of a side and its goal and its score
  share one color (bottom magenta, top cyan) — a side reads as one team.
- **The "1.5"/asymmetric worry is gone** — per-side hand counts ARE the
  asymmetry, handled uniformly. A three-player table (one side singles, other
  doubles) is exactly 1v2.

## Open questions, still

- Is soloing both mallets of a side surfaced as its own harder mode, or only a
  side effect of who shows up at the couch?
- On the ellipse: hidden spin, or a drawn puck symbol to make rotation
  readable?
