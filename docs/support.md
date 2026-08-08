---
title: Support
---

# Support

*Handoff for iPad — unofficial client for the
[Handoff vPilot plugin](https://github.com/sushiat/vpilot-handoff).*

**Deutsche Fassung weiter unten.**

## Where to ask

**[Open an issue](https://github.com/MANFahrer-GF/vpilot-handoff-ios/issues)** —
that is the whole support channel, and it is a real one.

Please **don't** take iPad problems to the upstream project. sushi.at writes the
plugin and the Android client and has no Apple device to test against; this app is
mine to support.

The other way round applies too: if the plugin itself misbehaves — wrong controller
ranking, a station missing, sector data odd — that belongs
[upstream](https://github.com/sushiat/vpilot-handoff/issues), and I'll say so if
it turns out that way.

### What to include

Without these I'll only be able to guess:

- the app version (top right of the header, e.g. `v1.1.0`),
- your iPadOS version and iPad model,
- the plugin version (Settings → Plugin → Version),
- what you did, what you expected, what happened instead,
- a screenshot if anything looked wrong.

## Before you file: the usual suspects

**"It can't find my PC."** Auto-detect uses a UDP broadcast, which some networks
and most guest/VPN setups drop. Enter the address by hand under
*Settings → Manual IP*. If that fails too, the Windows firewall is the next
suspect: the plugin needs **TCP 48765** inbound, and **UDP 48766** for discovery.
Both devices must be on the same network — a phone hotspot on one side and the
house Wi-Fi on the other won't do.

**"It says the PC's identity changed."** The plugin's certificate is pinned when
you first pair. This appears when it no longer matches — normally after
reinstalling or resetting the plugin, in which case entering the new code is fine.
If you didn't do either, don't enter the code: something else is answering on that
address.

**"The app expired after a week."** That is Apple's rule for a free Apple ID, not
this app. AltStore and SideStore can refresh it automatically while your iPad is on
the same network as the computer you set them up with. A paid Apple Developer
account stretches it to a year.

**"I want to look at it without setting up a plugin."**
*Settings → Try it without a plugin → Demo mode.* Sample data, clearly marked, and
nothing is sent anywhere. It is not remembered across restarts — deliberately, so
invented controllers can't turn up beside a real flight.

**"Everything is in the wrong language."** The cockpit is English on purpose, the
way the radio is. Only the settings screens follow the iPad's language, in English
or German.

**"A frequency change didn't arrive."** Check the status line at the bottom. If a
command couldn't be handed to the connection, it says so there rather than pretending
it worked.

## What this app can't do

- Talk to VATSIM by itself. Everything goes through the plugin on your PC.
- Show a moving map — the plugin's map is not part of the protocol this client uses.
- Run on iPhone. iPad only.
- Transmit voice. It is the radio *panel*, not the radio.

---

# Hilfe

*Handoff für iPad — inoffizieller Client für das
[Handoff-vPilot-Plugin](https://github.com/sushiat/vpilot-handoff).*

## Wohin mit Fragen

**[Ein Issue eröffnen](https://github.com/MANFahrer-GF/vpilot-handoff-ios/issues)** —
das ist der gesamte Support-Weg, und er ist ernst gemeint.

Bitte **keine** iPad-Probleme im Ursprungsprojekt melden. sushi.at schreibt das
Plugin und die Android-App und hat kein Apple-Gerät zum Testen; diese App zu
betreuen ist meine Sache.

Umgekehrt gilt dasselbe: wenn sich das Plugin selbst falsch verhält — falsche
Reihenfolge der Lotsen, fehlende Station, seltsame Sektordaten — gehört das
[dorthin](https://github.com/sushiat/vpilot-handoff/issues), und ich sage es dir,
wenn sich das herausstellt.

### Was hineingehört

Ohne das kann ich nur raten:

- die App-Version (oben rechts in der Kopfzeile, z. B. `v1.1.0`),
- deine iPadOS-Version und das iPad-Modell,
- die Plugin-Version (Einstellungen → Plugin → Version),
- was du getan hast, was du erwartet hast, was stattdessen passiert ist,
- ein Bildschirmfoto, falls etwas falsch aussah.

## Vorher: die üblichen Verdächtigen

**„Es findet meinen PC nicht."** Die automatische Suche nutzt einen
UDP-Rundruf, den manche Netze und die meisten Gast- oder VPN-Aufbauten verwerfen.
Trag die Adresse von Hand unter *Einstellungen → Manuelle IP* ein. Klappt auch das
nicht, ist als Nächstes die Windows-Firewall dran: das Plugin braucht **TCP 48765**
eingehend und **UDP 48766** für die Suche. Beide Geräte müssen im selben Netz sein —
Handy-Hotspot auf der einen und WLAN auf der anderen Seite geht nicht.

**„Es meldet, die Identität des PCs habe sich geändert."** Das Zertifikat des
Plugins wird beim ersten Koppeln angeheftet. Diese Meldung erscheint, wenn es nicht
mehr passt — normalerweise nach einer Neuinstallation oder einem Zurücksetzen des
Plugins; dann ist die Eingabe des neuen Codes in Ordnung. Wenn du weder das eine
noch das andere getan hast: **gib den Code nicht ein.** Dann antwortet etwas
anderes unter dieser Adresse.

**„Die App ist nach einer Woche abgelaufen."** Das ist Apples Regel für eine
kostenlose Apple-ID, nicht diese App. AltStore und SideStore können automatisch
erneuern, solange dein iPad im selben Netz ist wie der Rechner, mit dem du sie
eingerichtet hast. Ein kostenpflichtiges Entwicklerkonto dehnt es auf ein Jahr.

**„Ich will es ansehen, ohne ein Plugin einzurichten."**
*Einstellungen → Ausprobieren ohne Plugin → Demo-Modus.* Beispieldaten, deutlich
gekennzeichnet, und es wird nichts gesendet. Über Neustarts wird das bewusst nicht
gemerkt, damit erfundene Lotsen nicht neben einem echten Flug auftauchen.

**„Alles ist in der falschen Sprache."** Das Cockpit ist absichtlich englisch, so
wie der Funk. Nur die Einstellungen folgen der Sprache des iPads, auf Englisch oder
Deutsch.

**„Eine Frequenzumschaltung kam nicht an."** Schau auf die Statuszeile unten.
Wenn ein Befehl nicht an die Verbindung übergeben werden konnte, steht das dort —
statt so zu tun, als hätte es geklappt.

## Was diese App nicht kann

- Selbst mit VATSIM sprechen. Alles läuft über das Plugin auf deinem PC.
- Eine bewegte Karte zeigen — die Karte des Plugins gehört nicht zu dem Protokoll,
  das dieser Client nutzt.
- Auf dem iPhone laufen. Nur iPad.
- Sprechfunk übertragen. Es ist das Funk*gerät*, nicht der Funk.
