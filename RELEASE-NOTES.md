# vPilot Remote 1.4.0

> **📲 Download: [vPilot Remote on the App Store](https://apps.apple.com/app/vpilot-remote/id6817687242)** — free.
> There is no file attached to this release on purpose: the App Store is the download, and it keeps the app updated for you.

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

## What's new in 1.4.0

- **Connect to VATSIM from the tablet.** With Handoff 0.8.0 or newer, the antenna icon in
  the status bar and the *Network* row in the expanded footer connect and disconnect vPilot
  without reaching the sim PC. The form is prefilled from your SimBrief plan (callsign,
  aircraft type, SELCAL), offers *Connect as observer*, and shows vPilot's answer in place.
  Disconnecting always asks first. A refresh button next to the VATSIM row polls the network
  data right away. Against older plugins the controls stay hidden.
- **The departure slot now reads like the VDGS site.** The chip follows the start-up window
  the site's banner shows — anchored on the TSAT, else the CTOT minus the taxi-out time, else
  the accepted T/OBT, from 5 minutes before to 6 after: yellow *STUP T-8m* before it, green
  *STUP 4m left* inside it, red *MISS +3m* once it has passed, grey while nothing is accepted
  yet. Expanded, it lists EOBT, T/OBT, TSAT, EXOT, CTOT, reason and ATFCM status in the site's
  own terms. The taxi-out time is your flight's own, which is what the backend works with.
- **The slot tile at more airports.** Any airport the CDM backend knows now gets the tile, not
  only those already flagged for CDM — a T/OBT set there is kept for when CDM goes live.
- **New stations blink.** A controller who comes online at your departure airport flashes for a
  few seconds (Handoff 0.8.0 or newer); tapping the row stops it.
- **A one-time note on VATSIM's rules.** On first start the app reminds you that a VATSIM
  connection must not be left unattended, with a link to the Code of Conduct.

Everything works with older plugins too; the network controls and the blink need 0.8.0.

## What's new in 1.3.0

- **Departure slot on the status bar.** With a flight plan filed from a CDM airport, the
  footer shows your TOBT, TSAT or CTOT with a countdown and a traffic-light dot that
  follows the start-up window; expanded, it adds the assigned runway and SID and the
  reason for any delay. Tapping it opens the VDGS site, where the TOBT is set — the one
  step that still needs the website and your own VATSIM login.
- **Unread chat now matches your other devices.** Newer plugins keep the read mark
  themselves, so what you have read stays read after an app restart and across every
  paired tablet or phone. Against older plugins nothing changes.
- **A controller's "contact me" is readable on their row.** Newer plugins deliver the
  wording with the controller instead of as a chat message; without this it would have
  disappeared from view entirely.

Both chat changes need the next plugin release; everything keeps working with the
current one.

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
