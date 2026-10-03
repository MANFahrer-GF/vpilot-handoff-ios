# vPilot Remote 1.2.0

The VATSIM controller list, chat and radio panel on your iPad — next to your charts
in Split View. This is the iPad client for the
[Handoff plugin for vPilot](https://github.com/sushiat/vpilot-handoff) by sushi.at,
published with their permission.

## Install

**TestFlight** — the easiest way. Install Apple's TestFlight app, then open this link
on the iPad and tap *Accept*:

https://testflight.apple.com/join/BNjesezx

No sideloading, no 7-day expiry; updates arrive like any other app. An App Store
release is in review and will follow.

**Sideloading** — if you prefer SideStore or AltStore: the attached
`Handoff-1.2.0.ipa` is unsigned on purpose, so either tool can re-sign it with your
own free Apple ID. Add this source once and new versions show up as an update badge:

```
https://raw.githubusercontent.com/MANFahrer-GF/vpilot-handoff-ios/main/docs/source.json
```

With a free Apple ID the app expires after 7 days (both tools can refresh it
automatically) and you can have 3 sideloaded apps at a time — Apple's rules, not ours.

## What's new in 1.2.0

Keeps up with plugin **v0.6.0**, which now sends an ETA per controller instead of one
figure for the whole list ([upstream #127](https://github.com/sushiat/vpilot-handoff/issues/127)).
Without this update the ETA stops appearing once you update the plugin.

- **ETA sits on the controller row it belongs to**, next to NEXT / NEXT?. When two CTR
  sectors are tied, each shows its own estimate instead of borrowing the other's.
- **Older plugins still work.** If the plugin sends the list-level ETA (v0.5.0 and
  earlier), the header figure appears as before.
- **Under a minute reads "ETA <1′"**, not "ETA 0′".
- Demo mode carries a sample ETA, so the badge is visible without a plugin.

Nothing else changed. 118 tests, no warnings.

## Requirements

- iPad on iPadOS 17 or newer
- The Handoff plugin running in vPilot on a PC on the same network, with TCP 48765
  and UDP 48766 open
- No account, no server: the iPad talks to your PC and nothing else

## Try it without a plugin

Settings → **Try it without a plugin** fills the app with sample controllers, chat and
radio state, so you can see what it does before setting anything up on the PC.

---

Support for the iPad app is [here](https://github.com/MANFahrer-GF/vpilot-handoff-ios/issues),
not upstream — sushi.at has no Apple device to test against. Plugin and Android client
are their work; the app icon is their artwork, used with permission.
iPad app by Thomas Kant, Gifhorn. MIT licensed.
