---
title: Privacy
---

# Privacy policy

*vPilot Remote — iPad client for the [Handoff vPilot plugin](https://github.com/sushiat/vpilot-handoff).*
Last updated: 24 October 2026.

**Deutsche Fassung weiter unten.**

## The short version

This app has no server. It talks to the Handoff plugin on **your own PC**, over
your own network, and to nothing else. There is no account, no analytics, no crash
reporting, no advertising and no tracking of any kind. Nobody — including the
author — receives any data from your use of the app.

## What is stored on your iPad

All of it stays on the device. Nothing here is uploaded anywhere.

| Stored | Where | Why |
| --- | --- | --- |
| Your SimBrief user ID and username | iPad preferences | So you don't retype them; sent to your plugin when you press *Save & refresh* |
| The plugin's address and port | iPad preferences | To reconnect without asking again |
| The plugin's TLS certificate fingerprint | iPad preferences | Pinned at first pairing, so a different machine answering on that address is refused |
| A random identifier for this installation | iPad preferences | Sent to your plugin so it can recognise this iPad between sessions. A fresh UUID, not tied to you or your hardware |
| The pairing token issued by your plugin | iPad **Keychain** | It grants control of your radio, so it is kept in the Keychain rather than ordinary preferences |
| Display preferences: appearance, colour themes, channel spacing, keypad rules | iPad preferences | Your settings |
| That you have read the note on VATSIM's rules | iPad preferences | So it is shown once, not on every start |

Controllers, chat messages, radio state and flight-plan data are held **in memory
only** while the app runs. They are never written to storage.

Deleting the app removes all of it.

## What is sent, and to whom

### To the plugin on your own PC, over your local network

- the pairing code you type, and afterwards the token above,
- the installation identifier,
- your SimBrief user ID/username, when you save them,
- the commands you trigger — tuning a frequency, setting a squawk, sending a
  message, pinning a station,
- when you connect to VATSIM from the app: the callsign, aircraft type and SELCAL you
  entered. It is vPilot on your PC that then connects to the network with them, exactly as
  if you had used its own window; the app itself never talks to VATSIM.

**One exception worth naming.** If you turn on *Debug mode* **and** leave
*Attach screenshot* enabled, a diagnostic snapshot includes a **picture of this
app's own window**, and that picture is sent to your plugin. It never leaves your
PC by this app's doing. Debug mode is off by default. iOS does not allow an app to
capture anything outside its own window, so nothing else on your iPad can appear in
it.

### To the A-CDM service, over the internet

The departure-slot tile (TOBT/TSAT/CTOT) reads `api.viffsys.com`, the same A-CDM
backend the Android client and the EuroScope CDM plugin use. It runs **only** while a
flight plan filed with VATSIM gives a departure airport, and then roughly once a minute until
the flight takes off or the session ends. The first request asks which airports the service
knows at all; if yours is not among them, nothing further is sent.

Each request asks that airport for its list of tracked flights, so what leaves your
iPad is **the departure airport** (in the request) and your iPad's IP address, as with
any web request. Your callsign is matched against the answer **on the device**; it is
not sent. No account and no key is involved, nothing is written, and the app sends
nothing else there. The service is operated by a third party under its own terms.

Tapping the tile opens the **VDGS website** (`vdgs.vatsimspain.es`) inside the app,
which is where a TOBT is actually set. That is the real website: you log in with your
own VATSIM account, and your session cookie stays in this app so the login is not asked
for again every time. The app does not read, store or forward what you type there, and
the embedded window may only *open pages* on that site, VATSIM's login, and the bot check in
front of them — a link anywhere else is refused. Parts a page loads for itself (scripts, styles,
the bot check's own frame) are not restricted, because the page could not work otherwise.

## What the app requests from iOS

**Local network access**, and nothing else. Without it the app cannot find or reach
your PC. No location, no contacts, no photos, no microphone, no notifications. The
A-CDM request described above goes over your ordinary internet connection, for which
iOS asks no permission.

## Your PC is a separate matter

The plugin on your PC talks to VATSIM and SimBrief on its own account. That is the
plugin's business, not this app's, and it is governed by
[sushi.at's project](https://github.com/sushiat/vpilot-handoff) and by the terms of
those services.

## Legal basis and your rights

Because no personal data is collected, transmitted to, or processed by the author,
there is nothing held about you to access, correct, export or erase. Data stored on
your own device is under your control and is removed with the app.

## Contact

Questions about this app, including this policy, are best raised as an issue:
[github.com/MANFahrer-GF/vpilot-handoff-ios/issues](https://github.com/MANFahrer-GF/vpilot-handoff-ios/issues)

The app is free, open source (MIT) and not a commercial offering.

---

# Datenschutzerklärung

*vPilot Remote — iPad-Client für das
[Handoff-vPilot-Plugin](https://github.com/sushiat/vpilot-handoff).*
Stand: 24. Oktober 2026.

## Kurz gesagt

Diese App hat keinen Server. Sie spricht mit dem Handoff-Plugin auf **deinem
eigenen PC**, über dein eigenes Netz, und mit sonst nichts. Es gibt kein Konto,
keine Analysedienste, keine Absturzberichte, keine Werbung und kein Tracking.
Niemand — auch der Autor nicht — erhält Daten aus deiner Nutzung.

## Was auf deinem iPad gespeichert wird

Alles davon bleibt auf dem Gerät. Nichts wird irgendwohin übertragen.

| Gespeichert | Wo | Wozu |
| --- | --- | --- |
| SimBrief-Benutzerkennung und -Benutzername | iPad-Einstellungen | Damit du sie nicht neu eintippst; gehen an dein Plugin, wenn du *Sichern & aktualisieren* drückst |
| Adresse und Port des Plugins | iPad-Einstellungen | Um ohne Nachfrage wieder zu verbinden |
| Fingerabdruck des TLS-Zertifikats des Plugins | iPad-Einstellungen | Beim ersten Koppeln angeheftet, damit ein anderer Rechner unter derselben Adresse abgewiesen wird |
| Eine Zufallskennung dieser Installation | iPad-Einstellungen | Geht an dein Plugin, damit es dieses iPad wiedererkennt. Eine frisch erzeugte UUID, nicht mit dir oder deiner Hardware verknüpft |
| Das Kopplungs-Token deines Plugins | iPad-**Schlüsselbund** | Es erlaubt die Steuerung deines Funkgeräts und liegt deshalb im Schlüsselbund statt in gewöhnlichen Einstellungen |
| Anzeigeeinstellungen: Erscheinungsbild, Farbschemata, Kanalraster, Tastenfeldregeln | iPad-Einstellungen | Deine Einstellungen |
| Dass du den Hinweis auf die VATSIM-Regeln gelesen hast | iPad-Einstellungen | Damit er einmal erscheint, nicht bei jedem Start |

Lotsen, Chatnachrichten, Funkzustand und Flugplandaten liegen **nur im
Arbeitsspeicher**, solange die App läuft. Sie werden nie auf den Speicher
geschrieben.

Das Löschen der App entfernt alles davon.

## Was gesendet wird, und an wen

### An das Plugin auf deinem eigenen PC, über dein lokales Netz

- der Kopplungscode, den du eingibst, und danach das oben genannte Token,
- die Installationskennung,
- deine SimBrief-Kennung und dein Benutzername, wenn du sie sicherst,
- die Befehle, die du auslöst — Frequenz stellen, Transpondercode setzen,
  Nachricht senden, Station anheften,
- wenn du dich aus der App mit VATSIM verbindest: das eingegebene Rufzeichen, den
  Flugzeugtyp und den SELCAL-Code. Mit ihnen verbindet sich dann vPilot auf deinem PC mit
  dem Netz, genau wie über sein eigenes Fenster; die App selbst spricht nie mit VATSIM.

**Eine Ausnahme, die genannt gehört.** Wenn du den *Debug-Modus* einschaltest
**und** *Bildschirmfoto anhängen* aktiviert lässt, enthält ein Diagnose-Schnappschuss
ein **Bild des Fensters dieser App**, und dieses Bild geht an dein Plugin. Durch
diese App verlässt es deinen PC nicht. Der Debug-Modus ist standardmäßig aus. iOS
erlaubt einer App nicht, etwas außerhalb ihres eigenen Fensters aufzunehmen — es
kann also nichts anderes von deinem iPad darauf erscheinen.

### An den A-CDM-Dienst, über das Internet

Die Kachel mit der Abflugzeit (TOBT/TSAT/CTOT) liest `api.viffsys.com`, denselben
A-CDM-Dienst, den auch die Android-App und das EuroScope-CDM-Plugin nutzen. Sie läuft
**nur**, wenn ein bei VATSIM eingereichter Flugplan einen Abflughafen nennt, und dann etwa
einmal pro Minute, bis der Flug gestartet oder die Sitzung beendet ist. Die erste Anfrage holt,
welche Flughäfen der Dienst überhaupt kennt; ist deiner nicht dabei, wird nichts weiter
gesendet.

Jede Anfrage holt die Liste der verfolgten Flüge dieses Flughafens. Dein iPad gibt
dabei **den Abflughafen** preis (in der Anfrage) und, wie bei jedem Webzugriff, seine
IP-Adresse. Dein Rufzeichen wird **auf dem Gerät** mit der Antwort abgeglichen und
nicht übertragen. Es ist kein Konto und kein Schlüssel beteiligt, es wird nichts
geschrieben, und die App sendet sonst nichts dorthin. Der Dienst wird von Dritten
betrieben, zu deren eigenen Bedingungen.

Ein Tipp auf die Kachel öffnet die **VDGS-Webseite** (`vdgs.vatsimspain.es`) innerhalb
der App — dort wird eine TOBT tatsächlich gesetzt. Das ist die echte Webseite: Du
meldest dich mit deinem eigenen VATSIM-Konto an, und dein Sitzungs-Cookie bleibt in
dieser App, damit die Anmeldung nicht jedes Mal neu nötig ist. Die App liest, speichert
und leitet nicht weiter, was du dort eingibst, und das eingebettete Fenster darf nur
*Seiten* dieser Seite, der VATSIM-Anmeldung und der davor liegenden Bot-Prüfung öffnen — ein Link
woandershin wird abgewiesen. Was eine Seite für sich selbst nachlädt (Skripte, Gestaltung, der
Rahmen der Bot-Prüfung), ist nicht eingeschränkt, weil die Seite sonst nicht funktionieren würde.

## Was die App vom System verlangt

**Zugriff auf das lokale Netzwerk**, und sonst nichts. Ohne ihn findet und erreicht
die App deinen PC nicht. Kein Standort, keine Kontakte, keine Fotos, kein Mikrofon,
keine Mitteilungen. Die oben beschriebene A-CDM-Anfrage läuft über deine gewöhnliche
Internetverbindung, für die iOS keine Erlaubnis abfragt.

## Dein PC ist eine eigene Angelegenheit

Das Plugin auf deinem PC spricht auf eigene Rechnung mit VATSIM und SimBrief. Das
ist Sache des Plugins, nicht dieser App, und richtet sich nach
[sushi.ats Projekt](https://github.com/sushiat/vpilot-handoff) und den Bedingungen
dieser Dienste.

## Rechtsgrundlage und deine Rechte

Da keine personenbezogenen Daten erhoben, an den Autor übertragen oder von ihm
verarbeitet werden, liegt nichts über dich vor, worauf sich Auskunft, Berichtigung,
Übertragung oder Löschung beziehen könnte. Die auf deinem eigenen Gerät
gespeicherten Daten unterliegen deiner Kontrolle und werden mit der App entfernt.

## Kontakt

Fragen zur App, auch zu dieser Erklärung, am besten als Issue:
[github.com/MANFahrer-GF/vpilot-handoff-ios/issues](https://github.com/MANFahrer-GF/vpilot-handoff-ios/issues)

Die App ist kostenlos, quelloffen (MIT) und kein gewerbliches Angebot.
