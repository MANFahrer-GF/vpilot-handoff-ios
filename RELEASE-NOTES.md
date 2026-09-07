# Handoff for iPad — v1.1.2

Bugfix release.

## Changed

- A private message whose text the plugin couldn't deliver (missing or JSON
  `null` `text` field) used to render as a completely blank chat bubble,
  indistinguishable from a message that was genuinely empty. It now shows
  "⚠️ Message received without content" instead, so a delivery problem is
  visible rather than silent. Filed upstream as
  [sushiat/vpilot-handoff#131](https://github.com/sushiat/vpilot-handoff/issues/131)
  to track down why the plugin would send that field empty in the first place.

No other behaviour changed. 114 tests, no warnings.

## Installing

The attached `Handoff-1.1.2.ipa` is **unsigned** on purpose — signing it here would
tie it to one developer account and be useless to anyone else.
[SideStore](https://sidestore.io) or [AltStore](https://altstore.io) re-sign it with
*your own* free Apple ID.

**If you added the source, this update is already waiting for you.** If not, adding
it once means future versions arrive as an update badge instead of a manual
download:

```
https://raw.githubusercontent.com/MANFahrer-GF/vpilot-handoff-ios/main/docs/source.json
```

With a free Apple ID, Apple expires the app after **7 days** (both tools can
refresh it automatically over your network) and allows **3** sideloaded apps at a
time. A paid Apple Developer account raises the 7 days to a year; it is not
required.

## Requirements

- iPad on **iPadOS 17** or newer
- The [Handoff plugin](https://github.com/sushiat/vpilot-handoff) running in vPilot
  on a PC on the same network, with **TCP 48765** and **UDP 48766** open

---

Unofficial client, **not affiliated with sushi.at, VATSIM or vPilot** — though
sushi.at was asked before this was published and gave their blessing for the name,
the artwork, and for following the Android client's interface. Report problems with
this app here, not upstream. iPad app by **Thomas Kant**, Gifhorn, built with
**Claude (Anthropic)**. MIT licensed.
