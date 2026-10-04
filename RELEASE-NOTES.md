# vPilot Remote 1.2.1

The VATSIM controller list, chat and radio panel on your tablet — next to your charts
in Split View. This is the companion app for the
[Handoff plugin for vPilot](https://github.com/sushiat/vpilot-handoff) by sushi.at,
published with their permission.

## Install

**TestFlight** — the easiest way. Install Apple's TestFlight app, then open this link
on the tablet and tap *Accept*:

https://testflight.apple.com/join/BNjesezx

No sideloading, no 7-day expiry; updates arrive like any other app. An App Store
release is in review and will follow.

**Sideloading** — if you prefer SideStore or AltStore: the attached
`Handoff-1.2.1.ipa` is unsigned on purpose, so either tool can re-sign it with your
own free Apple ID. Add this source once and new versions show up as an update badge:

```
https://raw.githubusercontent.com/MANFahrer-GF/vpilot-handoff-ios/main/docs/source.json
```

With a free Apple ID the app expires after 7 days (both tools can refresh it
automatically) and you can have 3 sideloaded apps at a time — Apple's rules, not ours.

## What's new in 1.2.1

- **New name: vPilot Remote.** App Review does not allow "Handoff" in an app's name
  (it is the name of an Apple feature), so the app is now called vPilot Remote
  everywhere — home screen, header, TestFlight. The plugin keeps its name; nothing
  about the connection changed.
- **Auto-detect finds the PC again.** Discovery used a network broadcast that iOS
  silently drops on real devices. It now asks every address in your Wi-Fi subnet
  directly, which iOS allows, so the plugin shows up without typing its IP. Manual
  entry is still there as a fallback.
- The header no longer carries an "iPad · unofficial" tag, and the credits say what
  is true: an independent client, published with sushi.at's permission.

Sideloaders: the bundle identifier changed with the rename, so this version installs
next to the old one. Delete the old "Handoff" app and pair once more.

## Requirements

- iPad on iPadOS 17 or newer
- The Handoff plugin running in vPilot on a PC on the same network, with TCP 48765
  and UDP 48766 open
- No account, no server: the tablet talks to your PC and nothing else

## Try it without a plugin

Settings → **Try it without a plugin** fills the app with sample controllers, chat and
radio state, so you can see what it does before setting anything up on the PC.

---

Support for the app is [here](https://github.com/MANFahrer-GF/vpilot-handoff-ios/issues),
not upstream — sushi.at has no Apple device to test against. Plugin and Android client
are their work; the app icon is their artwork, used with permission.
App by Thomas Kant, Gifhorn. MIT licensed.
