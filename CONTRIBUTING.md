# Contributing to Puck Around

Thanks for your interest! The full contributor guide — project layout, build &
test commands, code style, and conventions — lives in **[AGENTS.md](AGENTS.md)**,
which is the single canonical source for both humans and AI coding agents. This
file just points you there so it's easy to find.

Quick orientation:

- **Build & run / tests:** see [AGENTS.md](AGENTS.md). In short: Xcode 26 and
  XcodeGen; `make test` runs the logic tests, `make run-iphone` /
  `make run-ipad` build and launch in a simulator.
- **Architecture / why things are the way they are:**
  [ARCHITECTURE.md](ARCHITECTURE.md).
- **What's planned:** [ROADMAP.md](ROADMAP.md). **What's changed:**
  [CHANGELOG.md](CHANGELOG.md).

Pull requests:

- Branch off `main`; keep the change focused.
- Match the surrounding code style. CI must stay green — SwiftLint +
  swift-format, the logic tests (with coverage), and the iOS build all run on
  CI; run `make test` and `make lint` locally before pushing.
- **Changes to the simulation need tests.** The sim is deterministic on
  purpose, and `Packages/PuckaroundCore/Tests` is where that promise is held;
  add a case there for anything you change.
- If your change is user-facing, add a bullet to `CHANGELOG.md` under
  `### Unreleased (next build)` in the same PR.
- Describe what changed and why in the PR body.

Licensing:

- By contributing you agree your contributions are licensed under the
  repository's [MIT License](LICENSE), which includes distribution as part of
  the shipped app.
- You confirm the contribution is your own work and that you have the right to
  submit it under that license — not copied from code you don't have the right
  to relicense (an employer's, or an incompatibly-licensed project's).
- Ideas and suggestions in issues are welcome and, being ideas, aren't
  something anyone owns — feel free to open them; implementing them is fine.
