# Handoff for iPad — v1.0.1

A small fix and a much better set of screenshots. Nothing about the protocol,
pairing or radio handling changed, so there is no reason to re-pair.

## Fixed

- **The MSG tile showed a badge with `0`** once every conversation had been read.
  A counter that renders zero reads as a count rather than as the absence of one;
  the badge now disappears instead.

## Also in this release

- A proper **[gallery](https://github.com/MANFahrer-GF/vpilot-handoff-ios/blob/main/docs/gallery.md)**
  — dashboard in light and dark, the narrow Split View layout, the expanded status
  line, both keypads, chat, settings, the colour-theme editor, and the pairing and
  identity screens, with an explanation of what each state means.
- The sample data behind `-handoffDemoData` now carries 23 stations instead of 11,
  so the layout can be judged against something resembling a European evening.
  Debug builds only; it can never appear in normal use.

Everything else since v1.0.0 was documentation and build plumbing.

## Installing

The attached `Handoff-1.0.1.ipa` is **unsigned** on purpose — signing it here would
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
sushi.at was asked before this was published and gave their blessing for the name
and for following the Android client's interface. Report problems with this app
here, not upstream. iPad app by **Thomas Kant**, Gifhorn, built with **Claude
(Anthropic)**. MIT licensed.
