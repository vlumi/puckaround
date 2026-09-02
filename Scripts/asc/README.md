# App Store Connect tooling

Manage the App Store listing from the repo instead of the ASC UI. Two syncs,
both dry-run by default:

- **Listing text** — [listing.json](listing.json) is the single source of
  truth for name, subtitle, description, keywords, promo text, and URLs. Edit
  it here, never in ASC.
- **Screenshots** — [screenshots.py](screenshots.py) uploads the captured
  `shots/` tree (see [SCREENSHOTS.md](SCREENSHOTS.md)) into the store sets, in
  store order, replacing what's there.

## Setup (none)

[run.sh](run.sh) self-manages a Python venv at `~/.venvs/puckaround-asc`
(deps in [requirements.txt](requirements.txt)) — the Makefile targets are the
whole interface. Credentials reuse the release lane's: `Scripts/.asc-config`
(Key ID + Issuer ID) with the `.p8` in `~/.appstoreconnect/private_keys/` —
nothing new to set up.

## Use

```sh
make asc-listing              # dry run: diff listing.json against ASC
make asc-listing-apply        # write

make shots PLATFORM=iphone    # guided capture → shots/iphone/en/…
make asc-screenshots          # dry run: what the shots/ tree would upload
make asc-screenshots-apply    # replace + upload
```

`whatsNew` is omitted automatically until the app has a released version —
Apple locks release notes on a first release.
