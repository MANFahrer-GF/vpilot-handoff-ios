# Handoff for iPad — v1.0.0

First public build. An **unofficial** iPad client for the
[Handoff vPilot plugin](https://github.com/sushiat/vpilot-handoff) by sushi.at,
written against the plugin's public `docs/protocol.md`.

**Not affiliated with, endorsed by, or maintained by sushi.at, VATSIM or vPilot.**
Report problems with this app here, not upstream. The plugin itself, and the
Android client this interface follows, are sushi.at's work.

## What's in it

- **Controller list** — ranked by the plugin, colour-coded per facility, showing
  the station's VATSIM rating, with pin, chat and one-tap tuning to COM1, COM2 or
  standby. `CONTACT ME`, `NEXT`, `TUNED`, `STBY` and `SELCAL` states are marked.
- **Radio panel** — COM1/COM2 active and standby, transmit and receive selection,
  transponder, all mirrored live from SimConnect. Tuning from the iPad writes back
  to the sim.
- **Chat** — radio and private conversations as separate tabs, unread badges per
  conversation, and calls that name your own callsign highlighted as `TO YOU`.
  SELCAL alerts appear as a banner.
- **Flight-plan cross-check** — flags a missing VATSIM flight plan, a
  SimBrief/VATSIM divergence, or a filed origin that doesn't match where the
  aircraft is parked.
- **Colour themes** — the per-facility palette is fully editable, with
  colourblind-safe presets (deuteranopia, protanopia), contrast threshold and a
  separate dark-mode offset.
- **8.33 kHz and 25 kHz channel spacing**, with optional rejection of frequencies
  that aren't valid channels.
- **Adaptive layout** — the radio and chat panel sits beside the dashboard on a
  wide window and folds into an overlay on a narrow split, so it works in Split
  View next to your charts.

## Language

The cockpit is **English everywhere**, like the radio work it mirrors. Only the
settings screens follow the iPad's language, in English or German.

## Security

- The plugin's TLS certificate is **pinned on first pairing**. A different machine
  answering on that address is refused rather than trusted, and the app says so
  instead of silently reconnecting.
- The pairing token lives in the iPad **Keychain**, scoped per host *and* port.
- No account, no analytics, no server of ours. The iPad talks to your PC and
  nothing else. The only permission requested is local network access.

## Requirements

- iPad on **iPadOS 17** or newer
- The Handoff plugin running in vPilot on the PC
- Both on the same network, with **TCP 48765** (and **UDP 48766** for
  auto-discovery) allowed through the Windows firewall

## Installing

There is no App Store build. The attached `Handoff-1.0.0.ipa` is **unsigned** on
purpose — signing it here would tie it to one developer account and be useless to
anyone else. [SideStore](https://sidestore.io) or [AltStore](https://altstore.io)
re-sign it with *your own* free Apple ID.

With a free Apple ID, Apple expires the app after **7 days** (both tools can
refresh it automatically over your network) and allows **3** sideloaded apps at a
time. A paid Apple Developer account raises the 7 days to a year; it is not
required.

Building from source and running it on your own iPad from Xcode is the same deal,
and is described in the README.

## Known limits

- Tested against the protocol documentation and a local TLS stand-in, **not yet
  against a live plugin** on a real VATSIM session. First-flight reports are
  welcome.
- No moving map. The plugin's own map is not part of the protocol surface this
  client consumes.
- iPad only. There is no iPhone layout.

## Credits

- [Handoff vPilot plugin & Android client](https://github.com/sushiat/vpilot-handoff) — sushi.at (MIT)
- [VATSpy](https://github.com/vatsimnetwork/vatspy-data-project) — airport & FIR data (CC BY-SA 4.0)
- [VatGlasses](https://github.com/lennycolton/vatglasses-data) — sector boundaries (CC BY-NC-SA 4.0)
- [VATSIM Data Feed](https://vatsim.dev), [SimBrief](https://www.simbrief.com) by Navigraph,
  [vPilot](https://vpilot.rosscarlson.dev)

iPad app by **Thomas Kant**, Gifhorn — built with **Claude (Anthropic)**.
MIT licensed.
