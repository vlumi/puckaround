# Puckaround — command-line build/run/test, so you never have to open Xcode.
#
# The Scripts/*.sh do the actual work (one job each); this Makefile wires up the
# dependencies (e.g. the Xcode project is regenerated only when project.yml or
# an Info.plist changes) and gives short targets. Run `make` (or `make help`)
# to list them.

.DEFAULT_GOAL := help

.PHONY: help
help:  ## List the available commands
	@echo "Puckaround — available make targets:"
	@awk 'BEGIN {FS = ":.*## "} \
		/^##@ / {printf "\n\033[1m%s\033[0m\n", substr($$0, 5); next} \
		/^##~ / {printf "  \033[2m%s\033[0m\n", substr($$0, 5); next} \
		/^[a-zA-Z0-9_-]+:.*## / {printf "  \033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

##@ Dev — build, run, test

# Inputs xcodegen reads — regenerate the project when any of these change.
PROJECT_INPUTS := project.yml \
	$(wildcard Sources/*/Info.plist) \
	$(wildcard Sources/*/*.entitlements) \
	$(wildcard Sources/*/*.xcstrings)

# File target: the generated project depends on its inputs, so `make` skips the
# regen when nothing changed (and reruns it when project.yml etc. are edited).
Puckaround.xcodeproj: $(PROJECT_INPUTS)
	@Scripts/generate.sh

.PHONY: generate
generate: Puckaround.xcodeproj  ## Regenerate Puckaround.xcodeproj from project.yml (if stale)

.PHONY: run-iphone
run-iphone: Puckaround.xcodeproj  ## Build + launch on an iPhone simulator (DEVICE="SE" / "17 Pro" to pick)
	@Scripts/run-ios.sh iphone "$(DEVICE)"

.PHONY: run-ipad
run-ipad: Puckaround.xcodeproj  ## Build + launch on an iPad simulator (DEVICE="Air" / "13-inch" to pick)
	@Scripts/run-ios.sh ipad "$(DEVICE)"

.PHONY: build-ios
build-ios: Puckaround.xcodeproj  ## Build the iOS app (simulator, unsigned)
	@Scripts/build.sh ios

# Logic tests run straight from the Swift package — no Xcode project involved.
.PHONY: test
test:  ## Run the package logic tests (no Xcode project needed)
	@Scripts/test.sh

.PHONY: lint
lint:  ## SwiftLint + swift-format, both strict (as CI runs them)
	@swiftlint lint --strict
	@swift format lint --strict --recursive --configuration .swift-format \
		Packages/PuckaroundCore/Sources Packages/PuckaroundCore/Tests Sources

.PHONY: format
format:  ## Rewrite sources with swift-format
	@swift format --in-place --recursive --configuration .swift-format \
		Packages/PuckaroundCore/Sources Packages/PuckaroundCore/Tests Sources

.PHONY: icon
icon:  ## Regenerate the app icon from the game's own drawing code
	@swift run --package-path Packages/PuckaroundCore puckaround-icon \
		"$(CURDIR)/Sources/Shared/Assets.xcassets/AppIcon.appiconset/icon-1024.png"

.PHONY: clean
clean:  ## Remove the generated project + local build output
	@rm -rf Puckaround.xcodeproj .build-xcode Packages/PuckaroundCore/.build dist
	@echo "removed Puckaround.xcodeproj, .build-xcode, package .build, dist"

##@ App Store — screenshots & listing (asc-* talk to ASC; dry-run by default, -apply writes)
##~ Screenshots: make shots PLATFORM=iphone|ipad → stage + capture → commit shots/ → make asc-screenshots-apply
##~ Listing text: edit Scripts/asc/listing.json → make asc-listing → make asc-listing-apply

# See Scripts/asc/SCREENSHOTS.md. `make shots` is the whole capture flow: it
# launches the app on the right-sized simulator, prompts what to stage, and
# captures each shot itself, canonically named under shots/<platform>/<lang>/.
.PHONY: shots
shots:  ## Guided screenshot capture: PLATFORM=iphone|ipad [LANGS=en] [OUT=shots]
	@Scripts/shoot.sh

.PHONY: shots-organize
shots-organize:  ## Rename raw freehand screenshots by capture order: DIR=<folder> PLATFORM=iphone|ipad [LANGS=en]
	@Scripts/asc/run.sh organize $${PLATFORM:-iphone} $(DIR) $(if $(LANGS),--langs=$(LANGS),)

# The runner self-manages a venv (deps in Scripts/asc/requirements.txt);
# listing.json is the source of truth for the listing text.
.PHONY: asc-listing
asc-listing:  ## Show what differs between listing.json and the ASC listing (dry run)
	@Scripts/asc/run.sh listing $(ARGS)

.PHONY: asc-listing-apply
asc-listing-apply:  ## Push listing.json (description/keywords/etc.) to the ASC listing
	@Scripts/asc/run.sh listing --apply $(ARGS)

.PHONY: asc-screenshots
asc-screenshots:  ## Show what the shots/ tree would upload to the ASC listing (dry run)
	@Scripts/asc/run.sh screens $(ARGS)

.PHONY: asc-screenshots-apply
asc-screenshots-apply:  ## Replace + upload the shots/ tree to the ASC listing
	@Scripts/asc/run.sh screens --apply $(ARGS)

##@ Release lane
##~ Cut a build: make release — runs preflight → publish → tag → distribute

# The cut is split by concern, one script each, chained here in order:
#   preflight → publish → tag → distribute
# The pure ends (preflight, tag, distribute) re-derive their inputs from git +
# project.yml, so each runs standalone. The dirty middle (publish: version-bump
# prompts + auto-merging PR + CI-wait) is the one stateful script; state crosses
# to the later steps via the merged commit on main, not through Make.
#
# PLATFORM is ios — the only target there will be; the scripts' macos/all scope
# is inherited machinery. UPLOAD=0 stops after export (no ASC upload). The
# steps are a linear dependency chain so they stay ordered even under
# `make -j`. Run from a clean, up-to-date main.
PLATFORM ?= ios
UPLOAD ?= 1
DIST_FLAGS := $(if $(filter 0,$(UPLOAD)),--no-upload,)

.PHONY: release
release: release-distribute  ## Cut a release (UPLOAD=0 to skip the ASC upload)
	@echo "✓ release complete (PLATFORM=$(PLATFORM))."

.PHONY: release-build
release-build:  ## Like `release` but stop after export (no upload)
	@$(MAKE) release UPLOAD=0

.PHONY: release-preflight
release-preflight:  ## Release step 1: verify a clean, up-to-date base (main or release/X.Y.x)
	@Scripts/release-preflight.sh

.PHONY: release-publish
release-publish: release-preflight  ## Release step 2: bump, open auto-merging PR, wait for CI
	@Scripts/release-publish.sh $(PLATFORM)

.PHONY: release-tag
release-tag: release-publish  ## Release step 3: tag the merge commit + publish GitHub releases
	@Scripts/release-tag.sh $(PLATFORM)

.PHONY: release-distribute
release-distribute: release-tag  ## Release step 4: archive/export (+ upload unless UPLOAD=0)
	@Scripts/release-distribute.sh $(PLATFORM) $(DIST_FLAGS)

# Distribute is the likeliest step to fail (archive/export/ASC upload) and is
# safe to repeat. This standalone retry has NO prereqs — it re-distributes an
# already-tagged release without touching git/PR/tags, after verifying the tag
# for the current version+build exists.
.PHONY: release-distribute-retry
release-distribute-retry:  ## Re-distribute an already-tagged release (no PR/tag steps)
	@Scripts/release-distribute.sh $(PLATFORM) $(DIST_FLAGS) --require-tag

# Upload the package already in dist/ (from a prior `release-build`) without
# rebuilding — for when export succeeded but only the ASC upload failed.
.PHONY: release-upload
release-upload:  ## Upload the already-built dist/ package (no rebuild)
	@Scripts/release-distribute.sh $(PLATFORM) --upload-only
