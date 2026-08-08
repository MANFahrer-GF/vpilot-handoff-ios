# Handoff for iPad — v1.1.1

Maintenance release. Nothing to do with your setup — this just keeps the tagged
version in step with the source tree, which had moved on a little since v1.1.0.

## Changed

- Renamed a settings section header from "Appearance" to "Appearance Mode"
  ("Darstellungsmodus" in German). Purely cosmetic on iPad — the old wording never
  caused a problem there. It came up while trying the app as a native
  [Mac app](https://github.com/MANFahrer-GF/vpilot-handoff-ios#running-on-a-mac):
  Xcode's build tooling for that destination is stricter about generated symbol
  names than the iPad build path is, and flagged "Appearance" and "APPEARANCE" as
  colliding.
- Removed a stale, unused entry from the string catalog left over from an earlier
  edit.

No other behaviour changed. 111 tests, no warnings.

## Installing

The attached `Handoff-1.1.1.ipa` is **unsigned** on purpose — signing it here would
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
