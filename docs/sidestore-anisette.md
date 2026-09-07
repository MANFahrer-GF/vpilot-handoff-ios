# Installing Handoff with SideStore, and using the fallback Anisette server

Two independent things, both covered here: getting Handoff onto your iPad in the
first place, and what to do if SideStore's automatic refresh ever stalls.

Deutsche Fassung weiter unten.

## English

### 1. Install SideStore (one-time, needs a computer)

SideStore's own install process changes with iOS versions, so this repo doesn't
duplicate it — follow the current official guide:
[docs.sidestore.io → Installation](https://docs.sidestore.io/docs/installation/install).
In short: you pair a free Apple ID with your iPad once from a computer, then
SideStore lives entirely on the iPad afterwards — no computer needed for
day-to-day use.

### 2. Add Handoff's source and install it

1. Open SideStore, go to the **Sources** tab.
2. Add this URL:
   ```
   https://raw.githubusercontent.com/MANFahrer-GF/vpilot-handoff-ios/main/docs/source.json
   ```
3. Find "Handoff for iPad" in the source and install it.
4. The first launch asks you to trust the developer profile: **Settings →
   General → VPN & Device Management → [your Apple ID] → Trust**.

From here on, new Handoff versions show up as an update badge in SideStore —
nothing to redo.

### 3. If SideStore's refresh stalls: add the fallback Anisette server

SideStore keeps the app alive by re-signing it automatically in the background,
which needs a working **Anisette server** — shared infrastructure every
SideStore install depends on. The default ones are free and community-run, and
can get slow when many people lean on them at once. If Handoff (or anything
else in SideStore) stops refreshing and the built-in servers aren't responding,
switch to this project's own:

1. In SideStore, go to **Settings → Anisette Servers**.
2. If your version shows a **list URL** field, set it to:
   ```
   https://raw.githubusercontent.com/MANFahrer-GF/vpilot-handoff-ios/main/docs/anisette-servers.json
   ```
   then tap **Refresh Servers** and pick **"Handoff (kant.ovh)"** from the list.
3. If your version instead takes a single server **address**, use:
   ```
   https://anisette.kant.ovh
   ```

This server has also been submitted to
[SideStore's own community list](https://github.com/SideStore/anisette-servers) —
once merged there, it'll show up among the built-in options with no extra setup.

---

## Deutsch

### 1. SideStore installieren (einmalig, braucht einen Rechner)

Der Installationsweg von SideStore selbst ändert sich mit iOS-Versionen, daher
steht er nicht doppelt hier — folge der aktuellen offiziellen Anleitung:
[docs.sidestore.io → Installation](https://docs.sidestore.io/docs/installation/install).
Kurz zusammengefasst: Du koppelst einmal von einem Rechner aus eine kostenlose
Apple-ID mit deinem iPad. Danach läuft SideStore komplett auf dem iPad weiter —
für den Alltag brauchst du keinen Rechner mehr.

### 2. Handoff-Quelle hinzufügen und installieren

1. SideStore öffnen, zum Tab **Sources** gehen.
2. Diese URL hinzufügen:
   ```
   https://raw.githubusercontent.com/MANFahrer-GF/vpilot-handoff-ios/main/docs/source.json
   ```
3. "Handoff for iPad" in der Quelle suchen und installieren.
4. Beim ersten Start muss das Entwicklerprofil bestätigt werden: **Einstellungen
   → Allgemein → VPN & Geräteverwaltung → [deine Apple-ID] → Vertrauen**.

Ab dann erscheinen neue Handoff-Versionen einfach als Update-Badge in
SideStore — nichts weiter zu tun.

### 3. Wenn die automatische Erneuerung bei SideStore stockt: Ausweich-Anisette-Server

SideStore hält die App am Leben, indem es sie automatisch im Hintergrund neu
signiert — dafür braucht es einen funktionierenden **Anisette-Server**, eine
gemeinsam genutzte Infrastruktur, auf die jede SideStore-Installation
angewiesen ist. Die eingebauten sind kostenlos und werden von der Community
betrieben, können aber langsam werden, wenn viele Leute gleichzeitig darauf
zugreifen. Wenn Handoff (oder irgendetwas anderes in SideStore) nicht mehr
erneuert wird und die eingebauten Server nicht antworten, auf den eigenen
Server dieses Projekts wechseln:

1. In SideStore zu **Settings → Anisette Servers** gehen.
2. Falls die Version ein Feld für eine **Listen-URL** zeigt, dort eintragen:
   ```
   https://raw.githubusercontent.com/MANFahrer-GF/vpilot-handoff-ios/main/docs/anisette-servers.json
   ```
   dann **Refresh Servers** antippen und **"Handoff (kant.ovh)"** aus der
   aktualisierten Liste auswählen.
3. Falls die Version stattdessen eine einzelne Server-**Adresse** verlangt,
   diese eintragen:
   ```
   https://anisette.kant.ovh
   ```

Dieser Server wurde außerdem bei
[SideStores eigener Community-Liste](https://github.com/SideStore/anisette-servers)
eingereicht — sobald er dort aufgenommen ist, taucht er ohne zusätzliche
Einrichtung direkt unter den eingebauten Optionen auf.
