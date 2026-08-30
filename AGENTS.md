# Puck Around — agent & contributor guide

Air hockey for iPhone and iPad: people around **one device**, a goal each end,
one or two mallets a side (1v1, 1v2, 2v2). Local multiplayer only — the device
*is* the table. This file is how to *work
on* the repo, for humans and AI agents alike.

**The repo is past first feel and building out the couch.** The core plays well
on glass (mallet, drag, bounce all proven on device), and singles/doubles/1v2,
shaped and spinning pucks, wrap-wall tables, and a front door have shipped. The
work now is the multiplayer table and the pickers around it — kept lean, feel
first. [ROADMAP.md](ROADMAP.md) has the order, and its *Settled* section records
what has been decided.

Separate project from its siblings [Skid Jam](https://github.com/vlumi/skid) (a
couch racer), [Donpa Squad](https://github.com/vlumi/donpa) (Minesweeper),
Lattice Five and Nitpitch. Donpa is the proving ground for the conventions
below; Skid is the closest relative (iOS-only, one device, 2–4 thumbs). Reuse
their *approach* by copying and adapting, never by sharing a package — the repo
is fully independent and self-contained, and every convention it carries is
repeated here in full, so nothing cross-repo is needed to act on it.

## Where things are documented

One place per concern — don't duplicate, link:

| | |
|---|---|
| **What the system is** | [ARCHITECTURE.md](ARCHITECTURE.md) — the sim, sides & slots, the touch rule, and a fenced *Planned* chapter |
| **How to work on it** | this file — conventions, toolchain, PR process |
| **What's next, and when** | [ROADMAP.md](ROADMAP.md) |
| **Why a design was chosen** | woven into [ARCHITECTURE.md](ARCHITECTURE.md); a big undecided feature may get a temporary `docs/*-plan.md`, retired once it ships |
| **How it ships** | [RELEASING.md](RELEASING.md) |
| **What shipped** | [CHANGELOG.md](CHANGELOG.md) |

When something ships, move it out of ARCHITECTURE.md's *Planned* chapter and
into the prose above it. The fence exists because architecture notes drift into
describing intent as fact otherwise.

## Project facts

- **Platforms:** iOS 16+ / iPadOS 16+ — iPhone and iPad. **The floor is iOS 16
  so an iPhone 8 still runs it**; anything newer goes behind a wrapper (see
  *iOS 16 compatibility*). **No Mac, no watch, no TV — ever**: the premise is
  people sharing one handheld screen. `PuckaroundKit` still *compiles* on
  macOS 14, because `swift test` runs on the Mac — UIKit-only code sits behind
  `#if os(iOS)`.
- **Toolchain:** Xcode 26 / Swift 6 toolchain (Swift 5 language mode),
  **XcodeGen** (`.xcodeproj` generated, gitignored, never committed). The team
  ID IS committed in `project.yml` (it's not a secret, and the release lane's
  headless automatic signing needs it); certs/profiles are fetched by
  `-allowProvisioningUpdates`.
- **Name:** the game ships as **Puck Around**; `Puckaround` is the short
  repo/target/module name. **Bundle id:** `fi.misaki.puckaround`, matching the
  App Store Connect record — **don't change it** (an ASC bundle id can't be
  edited or reused once the record exists). MIT, no monetization.
- **Localization:** English-only for now, but String Catalog + `Text(_,
  bundle:)` / `String(localized:)` from day one — never hardcoded literals.
- **No third-party runtime dependencies.** Everything ships with the OS
  (Foundation, SwiftUI, UIKit). Dev tools (SwiftLint, XcodeGen) don't count and
  aren't SPM deps.

## Architecture: one deterministic sim, inputs as data

The load-bearing decisions and their rationale live in
[ARCHITECTURE.md](ARCHITECTURE.md). The essentials:

- **A control scheme is an input source, not a game mode.** Every mallet's
  action reaches the sim as a `SeatInput` value (how far to move it this tick,
  or a point to grab it to). Fingers, a future AI hand, anything — all
  `ControlSource`s; the sim never knows which.
- **The sim is pure and deterministic** — hand-written physics at a fixed
  timestep, seeded RNG, no `SKPhysicsBody`, no ambient randomness. Same seed +
  same inputs → same state, bit-for-bit. Replays are seed + inputs.
- **Testable logic goes in `PuckaroundCore`.** The coverage gate covers Core;
  the SwiftUI/UIKit layer (`PuckaroundKit`) is ignored wholesale, so logic left
  there is logic left untested.

### Structure

```text
puckaround/
├── project.yml                     XcodeGen spec (the iOS app target)
├── Makefile                        Short targets; run `make` to list them
├── Scripts/                        One job per script; the Makefile wires them
│     generate.sh                   Regenerates the .xcodeproj (refuses if THIS project is open in Xcode)
│     build.sh / test.sh / run-ios.sh
│     embed-commit-sha.sh           Stamps GitCommitSHA into the built Info.plist
│     release-*.sh, distribute.sh   The release lane (RELEASING.md)
├── Sources/iOS/                    Thin @main app shell (+ generated Info.plist, entitlements)
├── Sources/Shared/                 The asset catalog (AppIcon) + an empty app-level String Catalog
└── Packages/PuckaroundCore/        Swift package — all the code
    ├── Sources/PuckaroundCore/     Pure logic — tested, coverage-gated; grouped by domain:
    │   ├── Math/                   Vec2, Rect, SeededRNG, Tick
    │   ├── Sim/                    Rink (+Rink+Physics) the air-hockey sim, Puck, Mallet,
    │   │                           PolygonCollision (shaped pucks), GameSession, SideWalls
    │   ├── Table/                  Playfield + Goal geometry, Table (Side/Lane/MalletSlot/Format), PuckShape
    │   └── Input/                  SeatInput + ControlSource, SeatZones, MalletControlSource
    ├── Sources/PuckaroundKit/      SwiftUI + UIKit, depends on Core; coverage-ignored
    │   ├── App/                    AppRoot, MenuView + NewMatchSheet/SetupControls/Setup (the front door),
    │   │                           GameView + HockeyGame (one table), InterfaceTurn, NeonUI, Compat (iOS 16 wrappers)
    │   ├── Feedback/               Haptics + SoundEngine — procedural, off the sim's GameEvent stream
    │   ├── Input/                  MultiTouchSurface — every finger, id-tagged, to the control source
    │   ├── Render/                 RinkRenderer (+Puck/+Faceoff/+Score, Canvas), BoardPlacement, Seat, SeatPalette
    │   ├── Icon/                   AppIconScene — the icon is drawn by the game's own code
    │   └── Resources/              Localizable.xcstrings (the Kit's strings)
    ├── Sources/PuckaroundIcon/     Dev tool: `make icon` renders the icon PNG (macOS-only)
    └── Tests/PuckaroundCoreTests/  Grouped by domain (Math/, Seats/, Sim/, Input/, Session/, Render/; Support/ stages a rink)
```

Both targets and the tests group **by domain, not by type**.

### Art assets

**All graphics procedural** — table, puck, mallets, and the app icon are drawn in
code; no image assets. The icon is the one PNG in the repo, and it is
*generated*: `make icon` renders `AppIconScene` (the game's own drawing code)
to `Sources/Shared/Assets.xcassets/AppIcon.appiconset/icon-1024.png`, flattened
to opaque because App Store Connect silently rejects a transparent icon. To
change the icon, change the scene and re-run — never hand-edit the PNG.

## Build, run, test

Everything is a `make` target so Xcode never has to be opened
(`make` / `make help` lists them):

```sh
make test              # package logic tests (swift test; no Xcode project needed)
make lint              # SwiftLint + swift-format, both --strict, as CI runs them
make format            # rewrite sources with swift-format
make build-ios         # generate the project if stale, build the app for the simulator (unsigned)
make run-iphone        # build + install + launch on an iPhone simulator (DEVICE="SE" to pick)
make run-ipad          # same, iPad (DEVICE="Air")
make icon              # regenerate the app icon PNG from AppIconScene
make generate          # regenerate Puckaround.xcodeproj from project.yml (only if stale)
make clean             # remove the generated project + build output
```

`swift test` runs on the Mac, headless — that's the inner loop. The
simulator/device is for feel, which can't be settled from a spec. `make release`
is the release lane, documented in [RELEASING.md](RELEASING.md).

### Lint & format

```sh
swiftlint lint --strict                 # style + light correctness (config: .swiftlint.yml)
swift format lint --strict --recursive --configuration .swift-format \
  Packages/PuckaroundCore/Sources Packages/PuckaroundCore/Tests Sources
swift format --in-place --recursive --configuration .swift-format <paths>   # auto-format
```

CI runs both with `--strict` (warnings fail). **swift-format is the authority
on whitespace/punctuation**; where SwiftLint conflicts (trailing commas, brace
placement) those SwiftLint rules are disabled rather than fought. Run the
formatter before committing.

**Run SwiftLint from the repo root.** Its `excluded:` paths (`.build`,
`Packages/PuckaroundCore/.build`) resolve relative to the invocation directory,
not the config file — run it elsewhere and it lints the build dirs, drowning
you in noise from generated sources.

**SwiftLint is pinned to a specific version** (`SWIFTLINT_VERSION` in
`.github/workflows/ci.yml`, currently **0.65.0**) so CI and local runs agree —
an unpinned `brew install` follows the rolling latest, so a new release can
turn CI red on untouched code. Match it locally where possible (a patch release
ahead is usually fine; a minor one isn't). Bump the CI version deliberately and
update this line. swift-format needs no pin — it ships with the Xcode toolchain,
which CI pins via `XCODE_VERSION`.

## Pull requests & CI

Branch off `main`, one focused change per PR (details in
[CONTRIBUTING.md](CONTRIBUTING.md)). Agent-specific mechanics on top of that:

- **Commit trailer:** end commit messages with a
  `Co-Authored-By: <model> <noreply@anthropic.com>` line.
- **A user-facing PR writes its own CHANGELOG bullet** under the newest
  version's `### Unreleased (next build)` heading — the release lane only
  stamps the build number, it never writes entries. See CHANGELOG.md's preamble.
- **Wait for Codecov before merging.** `codecov/patch` is reported but is NOT a
  required check, so `--auto` merge can land a PR *before* coverage posts —
  merge only once it's green (target 80% on new, non-ignored code).
- **The whole `PuckaroundKit` target is coverage-ignored** (the SwiftUI/UIKit
  layer), so pure logic goes in `PuckaroundCore` to be tracked. If a Kit file
  grows testable logic, move the logic, don't widen the ignore list.
- **BEHIND blocks merge** (branch protection). Merge `origin/main` into the
  branch to catch it up; auto-merge needs required checks, so a base without
  protection falls back to a direct merge after the CI wait.

## Conventions

- **Comments minimal:** explain only what isn't obvious from the code. No
  historical / roadmap ("lands later") narration in source — that goes in
  commit messages and the docs.
- **Determinism for tests:** all randomness through an injected `SeededRNG`
  (SplitMix64); production seeds from `SystemRandomNumberGenerator`. The sim
  iterates mallets in `Format.slots` order, never dictionary order.
- **World coordinates are y-down**, matching screen space, so rendering is one
  scale and nothing flips. `Side.bottom` is the bottom of the screen in
  portrait.
- **A touch belongs to the mallet it grabbed for its whole life**, and **a
  finger only grabs a mallet it comes down near** — the two rules that make
  several fingers on one screen unambiguous.
- Core geometry uses `Vec2`/`Rect` (no CoreGraphics in Core); the Kit bridges
  to `CGPoint`/`CGRect` at the edge.
- `.vscode/` is gitignored and must not be pushed.
- When you change rules or controls, update `README.md` too.

### iOS 16 compatibility

The floor is iOS 16 and the Kit also compiles for macOS 14 (tests). Two
patterns, both in `PuckaroundKit/App/Compat.swift`:

- **Newer-API wrappers** — `onChangeCompat(of:perform:)` picks the right
  `onChange` overload per OS (neither is clean on both). Add a sibling wrapper
  for any API newer than the floor rather than sprinkling `#available` through
  views.
- **Platform-only wrappers** — `statusBarHiddenIfAvailable()`,
  `defersEdgeSwipes(_:)` are no-ops off iOS, so views stay free of `#if`.
  UIKit-only *code* (touch capture) sits in an `#if os(iOS)` block with a
  fallback that keeps the macOS test build compiling.

### String catalogs (`.xcstrings`)

- **Xcode's serialized form is canonical** (spaced colons, 2-space indent).
  After any scripted/CLI edit, normalize before committing:
  `plutil -convert json -r -o FILE FILE` — then opening the project in Xcode
  produces no churn.
- **Renaming a key must update its explicit `en` unit too.** An entry with an
  `en` localization whose value overrides the key would leave English silently
  showing the old text. Audit: flag any entry whose explicit `en` value ≠ its
  key (positional-format entries like `%1$@…` are the legit exceptions).
- Localize the **concept**, not the word — each locale by a native ear.

## Gotchas

- SourceKit in-IDE diagnostics may report `No such module 'PuckaroundCore'`
  for files it hasn't indexed — these are **false**. The authoritative checks
  are `swift build` / `swift test` / `xcodebuild`.
- The Canvas renderer closure is **not MainActor**: step the sim and build the
  frame's plain-value `RinkScene` outside it (see `HockeyGame.frame(at:)`), and
  hand the closure copies. Nothing per-frame is `@Published` — the view redraws
  every frame via `TimelineView(.animation)` anyway, and publishing per-frame
  state would mutate observable state mid-view-update.
