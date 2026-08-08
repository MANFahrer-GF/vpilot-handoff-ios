# Handoff for iPad — v1.1.0

**Demo mode.** Settings → *Try it without a plugin* fills the app with sample
controllers, messages and radio state, so you can see what it does before deciding
whether setting a plugin up is worth it. The sample data was already in the app,
but only reachable from a debug build with a launch argument — which helped nobody.

While it is on:

- the header and the status line both read **DEMO**,
- **nothing leaves the device** — every outbound command is refused,
- taps still answer, so it doesn't feel broken: tuning moves the frequency, a sent
  message appears in its conversation, pinning sticks. All of it local.

It is deliberately **not remembered across launches**. Leaving it on and relaunching
mid-flight would otherwise show invented controllers beside a real aircraft, so
every launch starts in the real mode. Returning to the foreground won't dial a
plugin out from under a demo session either, and connecting for real ends it and
clears the sample data.

## Under the hood

All 25 client commands now go through a single send path that refuses while demo
mode is on, rather than a check per method — a command added later can't reach a
real plugin by being forgotten. In a live session it forwards exactly as before.

## Also

- German translations for the new settings text, so the settings screen doesn't end
  up part-translated for German pilots. The cockpit stays English as always.
- A locally written demo message stamps its time with the same formatter the chat
  row parses with, instead of relying on two defaults happening to agree.

111 tests, no warnings.

## Installing

The attached `Handoff-1.1.0.ipa` is **unsigned** on purpose — signing it here would
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
