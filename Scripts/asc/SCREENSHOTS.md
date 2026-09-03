# App Store screenshots — capture guide

The carousel's job: make someone scrolling past their 500th arcade game stop
on *"wait — both of them play on the same phone?"* Lead with the premise (two
mallets, one screen), then breadth: the party formats, the arcade. Capture
runs in **demo mode** (`-puckaround-demo`, see `DemoMode`): an ephemeral
store seeded with the fixed cast — eight names each wearing a different neon,
a bracket tournament one match from the final, and full hiscore boards on all
three cabinets — so nothing needs typing, the shots are reproducible, and the
simulator's real data is never shown or touched. Only the live-play framing
(a rally mid-flight, a part-broken wall) is still yours to stage.

**Gameplay and functional UI only — no title menu.** Show the table, not the
packaging.

## Workflow — one command

```sh
make shots PLATFORM=iphone     # or ipad; LANGS=en by default
```

It builds, boots the right simulator (the device pick pins the pixel size ASC
wants), launches the app, and walks the shot list — *"stage this, press ⏎"* —
capturing each shot itself via `simctl`, straight to
`shots/<platform>/<lang>/<shot>-<platform>.png`. Retake with `r`, skip with
`s`. No ⌘S, no renaming: `shots/` is the handoff for `make
asc-screenshots-apply`, and the tree is **committed** — the store set is
versioned with the app.

Manual fallback (freehand capture, then rename by capture order):
`make demo-iphone` (or `demo-ipad`) launches the seeded demo without the
guide, then `make shots-organize DIR=<folder> PLATFORM=iphone`.

## Sizes

iPhone 6.9" (1320×2868) · iPad 13" (2064×2752) — portrait, the way the game
is held between two people. `screenshots.py` refuses any other size before an
upload (a wrong-sized tile breaks ASC processing and blocks submission).

## The shots

Capture order (what `make shots` walks):

1. **rally** — free play 1v1, mid-rally: puck in flight between the mallets,
   both scores lit. The premise in one frame — this is the shot that stops
   the scroll.
2. **doubles** — a 2v2 match: four mallets in the two team neons (a doubles
   side shares its color), a lane each. The party shot; proves "up to four
   hands" isn't a bullet point.
3. **tournament** — tap Tournament: the demo resumes its seeded bracket
   (quarterfinals played, a semifinal in the books), every name in its own
   neon. No staging.
4. **arcade-shelf** — the arcade shelf: three cabinet cards, icons left,
   hiscores right — the demo's boards come pre-filled. No staging.
5. **brick-wall** — Brick Wall mid-stage: part-broken wall, HUD showing
   stage · score · lives. The puck live, bricks chipped — not the faceoff.
6. **survival** — the feed running: three pucks live, mixed shapes, score
   climbing.

**Store order ≠ capture order.** The upload arranges the carousel by
persuasion — the first ~3 sell the app: **rally, doubles, brick-wall**, then
tournament, survival, arcade-shelf. (`STORE_ORDER` in `screenshots.py`.)

Every language gets this same set, in that language — the listing is en-US
only today; if fi/ja localization lands, `LANGS=en,fi,ja` and the locale
mapping are already wired.

Optional captions (add in ASC), one concrete idea each: "The device is the
table." · "Up to four hands." · "Winner stays on." · "An arcade in the
corner."

## After capturing

Commit the `shots/` tree, then `make asc-screenshots` (dry run) →
`make asc-screenshots-apply`.
