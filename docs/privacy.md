---
title: Privacy
---

# Privacy policy

*Handoff for iPad — unofficial client for the [Handoff vPilot plugin](https://github.com/sushiat/vpilot-handoff).*
Last updated: 8 August 2026.

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

Controllers, chat messages, radio state and flight-plan data are held **in memory
only** while the app runs. They are never written to storage.

Deleting the app removes all of it.

## What is sent, and to whom

Only to the plugin on your own PC, over your local network:

- the pairing code you type, and afterwards the token above,
- the installation identifier,
- your SimBrief user ID/username, when you save them,
- the commands you trigger — tuning a frequency, setting a squawk, sending a
  message, pinning a station.

**One exception worth naming.** If you turn on *Debug mode* **and** leave
*Attach screenshot* enabled, a diagnostic snapshot includes a **picture of this
app's own window**, and that picture is sent to your plugin. It never leaves your
PC by this app's doing. Debug mode is off by default. iOS does not allow an app to
capture anything outside its own window, so nothing else on your iPad can appear in
it.

## What the app requests from iOS

**Local network access**, and nothing else. Without it the app cannot find or reach
your PC. No location, no contacts, no photos, no microphone, no notifications.

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

*Handoff für iPad — inoffizieller Client für das
[Handoff-vPilot-Plugin](https://github.com/sushiat/vpilot-handoff).*
Stand: 8. August 2026.

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

Lotsen, Chatnachrichten, Funkzustand und Flugplandaten liegen **nur im
Arbeitsspeicher**, solange die App läuft. Sie werden nie auf den Speicher
geschrieben.

Das Löschen der App entfernt alles davon.

## Was gesendet wird, und an wen

Ausschließlich an das Plugin auf deinem eigenen PC, über dein lokales Netz:

- der Kopplungscode, den du eingibst, und danach das oben genannte Token,
- die Installationskennung,
- deine SimBrief-Kennung und dein Benutzername, wenn du sie sicherst,
- die Befehle, die du auslöst — Frequenz stellen, Transpondercode setzen,
  Nachricht senden, Station anheften.

**Eine Ausnahme, die genannt gehört.** Wenn du den *Debug-Modus* einschaltest
**und** *Bildschirmfoto anhängen* aktiviert lässt, enthält ein Diagnose-Schnappschuss
ein **Bild des Fensters dieser App**, und dieses Bild geht an dein Plugin. Durch
diese App verlässt es deinen PC nicht. Der Debug-Modus ist standardmäßig aus. iOS
erlaubt einer App nicht, etwas außerhalb ihres eigenen Fensters aufzunehmen — es
kann also nichts anderes von deinem iPad darauf erscheinen.

## Was die App vom System verlangt

**Zugriff auf das lokale Netzwerk**, und sonst nichts. Ohne ihn findet und erreicht
die App deinen PC nicht. Kein Standort, keine Kontakte, keine Fotos, kein Mikrofon,
keine Mitteilungen.

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
