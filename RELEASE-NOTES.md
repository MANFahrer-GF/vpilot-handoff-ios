# vPilot Remote 1.2.2

The VATSIM controller list, chat and radio panel on your tablet — next to your charts
in Split View. This is the companion app for the
[Handoff plugin for vPilot](https://github.com/sushiat/vpilot-handoff) by sushi.at,
published with their permission.

## Install

**App Store** — free, updates like any other app:

https://apps.apple.com/app/vpilot-remote/id6817687242

**TestFlight** — for the beta of the next version. Install Apple's TestFlight app,
then open this link on the tablet and tap *Accept*:

https://testflight.apple.com/join/BNjesezx

## What's new in 1.2.2

- **Auto-detect fills in the address.** When one PC answers, its IP and port go
  straight into the connection field; before, the result was only listed below it
  and had to be tapped or typed.
- **Sideload builds have ended.** The App Store version is signed, updates itself
  and has no 7-day limit, so the unsigned `.ipa` for SideStore/AltStore is no
  longer produced. If you still run a sideloaded "Handoff", delete it and install
  from the App Store; pair once more.

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
