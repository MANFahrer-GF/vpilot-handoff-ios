# Handoff for iPad

An **unofficial** iPad client for the [Handoff vPilot plugin](https://github.com/sushiat/vpilot-handoff)
by sushi.at — the VATSIM controller list, chat and radio panel on a second screen,
next to your charts in iPadOS Split View.

> This project is **not affiliated with, endorsed by, or maintained by sushi.at**.
> It is an independent client written against the plugin's public
> [`docs/protocol.md`](https://github.com/sushiat/vpilot-handoff/blob/master/docs/protocol.md),
> in the same spirit as that document's note that it is "the source of truth if
> you're building an alternate client (e.g. iOS)". Please report issues with this
> app here, not to the upstream project. The plugin itself, and the Android client
> this UI follows, are sushi.at's work.

## What it does

Everything runs over the plugin's LAN WebSocket — the Windows PC keeps doing the
talking to VATSIM, the iPad is a second screen for it.

- **Controller list**, ranked by the plugin, colour-coded per facility, with the
  station's rating, pin and chat shortcuts, and one-tap tuning to COM1/COM2/standby.
- **Radio panel** — COM1/COM2 active and standby, transmit/receive selection,
  transponder, all reflected live from SimConnect.
- **Chat** — private and radio messages, SELCAL alerts, and a nearby-traffic
  picker for starting a private chat.
- **Flight-plan cross-check** — flags a missing VATSIM flight plan, a SimBrief/VATSIM
  divergence, or a filed origin that doesn't match where the aircraft is sitting.
- **Colour themes** — the per-facility palette is editable, with colourblind-safe
  presets and named themes.
- **Adaptive layout** — the RADIO panel sits beside the dashboard on a wide window
  and folds into an overlay on a narrow split.

## Requirements

- iPad on iPadOS 17 or newer
- The [Handoff vPilot plugin](https://github.com/sushiat/vpilot-handoff) running on
  the PC with vPilot
- Both on the same LAN, with TCP 48765 (and UDP 48766 for auto-discovery) allowed
  through the Windows firewall

## Building

The Xcode project is generated from `project.yml`, so it isn't in version control.

```sh
brew install xcodegen
cp .env.example .env      # then put your Apple Development Team ID in it
source .env
xcodegen generate
open Handoff.xcodeproj
```

A free personal Apple ID is enough to install on your own iPad; Apple then expires
the build after 7 days and it has to be reinstalled.

### Tests

```sh
xcodebuild -project Handoff.xcodeproj -scheme Handoff \
  -destination 'platform=iOS Simulator,name=iPad Air 11-inch (M4)' test
```

### Looking at the UI without a plugin

Launching with `-handoffDemoData` fills the app with sample state. The flag is
`#if DEBUG`-only and has to be passed explicitly, so it never shows up in normal use.

## Notes on the protocol

Two things in `docs/protocol.md` are easy to get wrong and worth repeating:

- **Decode defensively.** The plugin adds optional fields between versions and
  resends full state constantly. A model that throws on a missing field silently
  drops the whole message — that's how the chat panel here once ended up
  permanently empty.
- **The badge on a controller row is the VATSIM rating** (C1/S2/S3…), not a tuned
  indicator. `isCurrent`/`isStandbyTuned` are separate booleans.

## Credits

Data and upstream work this depends on:

- [Handoff vPilot plugin & Android client](https://github.com/sushiat/vpilot-handoff) — sushi.at (MIT)
- [VATSpy](https://github.com/vatsimnetwork/vatspy-data-project) — airport & FIR data (CC BY-SA 4.0)
- [VatGlasses](https://github.com/lennycolton/vatglasses-data) — sector boundaries (CC BY-NC-SA 4.0)
- [VATSIM Data Feed](https://vatsim.dev) — live network data
- [SimBrief](https://www.simbrief.com) by Navigraph — flight plan data
- [vPilot](https://vpilot.rosscarlson.dev) — the pilot client the plugin runs inside

## License

MIT — see [LICENSE](LICENSE).
