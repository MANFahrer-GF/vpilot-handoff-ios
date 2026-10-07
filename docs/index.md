---
title: vPilot Remote
---

# vPilot Remote

An iPad client for the
[Handoff vPilot plugin](https://github.com/sushiat/vpilot-handoff) by sushi.at,
published with their permission — the VATSIM controller list, chat and radio panel
on a second screen, next to your charts in iPadOS Split View.

An independent client, developed separately from the plugin: sushi.at was asked
before this was published and explicitly permitted the name, the artwork, and
following the Android client's interface. Support for the iPad app is here, not
upstream.

- **[Gallery](gallery.md)** — what it looks like, and what each state means
- **[Support](support.md)** — where to ask, and the usual suspects first
- **[Privacy](privacy.md)** — no server, no account, no tracking; the details
- **[Source and downloads](https://github.com/MANFahrer-GF/vpilot-handoff-ios)** on GitHub

## Installing

**App Store (recommended):** [vPilot Remote on the App Store](https://apps.apple.com/app/vpilot-remote/id6817687242) — free,
updates like any other app.

**TestFlight (beta builds):** install Apple's TestFlight app, then open
[https://testflight.apple.com/join/BNjesezx](https://testflight.apple.com/join/BNjesezx) on the iPad.

**SideStore / AltStore:** each [release](https://github.com/MANFahrer-GF/vpilot-handoff-ios/releases/latest)
also carries an unsigned `.ipa` that [SideStore](https://sidestore.io) or
[AltStore](https://altstore.io) re-sign with your own free Apple ID.

Adding this source once means updates arrive as a badge instead of a manual
download:

```
https://raw.githubusercontent.com/MANFahrer-GF/vpilot-handoff-ios/main/docs/source.json
```

## Requirements

iPad on iPadOS 17 or newer, and the Handoff plugin running in vPilot on a PC on the
same network, with TCP 48765 and UDP 48766 open.

---

iPad app by **Thomas Kant**, Gifhorn — built with **Claude (Anthropic)**.
MIT licensed. The app icon is sushi.at's handoff mark, reused with permission.
