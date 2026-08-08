# Handoff for iPad — v1.0.2

**New app icon.** The iPad app now carries the same handoff mark as the plugin and
the Android client, so it no longer looks like a stranger to the thing it talks to.

The mark is **sushi.at's artwork, reused with their permission**. It is traced from
`plugin/Assets/handoff.svg` upstream rather than redrawn by eye — same four paths,
same 45° rotation about the same centre, same stroke width and colours. Measured
against the shipped `handoff.ico` to be sure: principal axis −68.5° upstream,
−68.4° here.

Two differences, both forced by iOS: no baked-in corner radius, because iOS masks
icons itself and a baked one leaves a dark seam outside the mask; and no alpha
channel, because app icons must be opaque. The renderer is in
[`tools/make-icon.py`](https://github.com/MANFahrer-GF/vpilot-handoff-ios/blob/main/tools/make-icon.py)
if you want to see exactly what was done.

Credit for the artwork now appears in the app's own credits screen and in the
README.

Nothing else changed. No protocol, pairing or radio behaviour is affected, so there
is no reason to re-pair.

## Installing

The attached `Handoff-1.0.2.ipa` is **unsigned** on purpose — signing it here would
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
