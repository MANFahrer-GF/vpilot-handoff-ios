# Handoff for iPad — v1.2.0

Keeps up with plugin **v0.6.0**, which moved the ETA onto each controller instead of
sending one value for the whole list ([issue #127](https://github.com/sushiat/vpilot-handoff/issues/127)).
Without this update the ETA simply stops appearing once you update the plugin.

## Changed

- **ETA is now a badge on the controller row it belongs to**, next to NEXT/NEXT?,
  instead of a single figure in the list header. When two CTR sectors are tied, each
  row now shows its own genuine estimate — previously one could borrow the other's.
- **Older plugins keep working.** If the plugin still sends the list-level ETA
  (v0.5.0 and earlier), the header figure appears exactly as before. Nothing about
  the connection is version-gated.
- **Under a minute reads as "ETA <1′"**, not "ETA 0′" — the plugin only sends an ETA
  for a sector still ahead of you, so a rounded-down zero would read like the bug
  upstream just fixed.
- Demo mode carries a sample ETA, so the badge is visible without a plugin.

No other behaviour changed. 118 tests, no warnings.

## Installing

The attached `Handoff-1.2.0.ipa` is **unsigned** on purpose — signing it here would
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
