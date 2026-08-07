# Entwurf: Nachricht an sushi.at

**Nicht versendet.** Das machst du selbst — ich verschicke keine Nachrichten in deinem Namen.

Kanäle, in dieser Reihenfolge sinnvoll:
1. **GitHub Issue oder Discussion** im Repo `sushiat/vpilot-handoff` — öffentlich, dokumentiert,
   und der Autor hat in `CONTRIBUTING.md` selbst dazu eingeladen. Für genau diese Frage der
   naheliegendste Weg.
2. **Flightsim.to**-Profilnachricht (`sushiat`) — dort ist er ebenfalls aktiv.
3. E-Mail nur, wenn du eine Adresse hast; im Repo steht keine.

---

## Englisch (Projektsprache — Repo, Doku und Issues sind alle auf Englisch)

**Betreff:** Unofficial iPad client built on the Handoff protocol — okay with you?

Hi,

I've built an iPad client for your Handoff vPilot plugin and wanted to check with you
before pushing it any further.

It's a native SwiftUI app written from scratch against `docs/protocol.md` — none of your
code is in it. I went that route because the protocol doc explicitly says to treat it as
the source of truth for an alternate client and names iOS as an example, so I hope that
was an open invitation. It talks to the plugin exactly as documented: UDP discovery,
TLS with trust-on-first-use pinning, the pairing-code and bearer-token handshake, and the
full controller/chat/radio surface.

The repository is public here:
https://github.com/MANFahrer-GF/vpilot-handoff-ios

Where I'd value your view:

1. **Is this okay with you at all?** If you'd rather not have a third-party client around
   your plugin, say so and I'll take it private or pull it.

2. **The name.** I called it "Handoff" because that's what it is a client for. If that's
   too close for comfort, I'm happy to rename it — just tell me what you'd prefer.

3. **The look.** The interface deliberately follows your Android layout closely, since
   pilots switching between the two shouldn't have to relearn anything. The icon is my
   own. If any of that goes further than you're comfortable with, I'll change it.

4. **Linking.** Would you mind if I link to your project from mine? I already credit the
   plugin, the Android client, and the data sources (VATSpy, VatGlasses, VATSIM, SimBrief,
   vPilot) in the app and the README. And if you ever wanted to mention the iPad client
   from your side, that would be welcome — but only if you actually want to; I'm not
   asking for a favour.

5. **Support.** The README says plainly that this is unofficial, not affiliated with or
   endorsed by you, and that bugs in the iPad app belong in my tracker, not yours. If
   anyone does end up in your issues because of it, point them at me. I don't want to
   create work for you.

On the licence: your project is MIT, mine is MIT as well. Since I wrote the client from
the protocol document rather than from your source, I don't believe I'm distributing any
of your code — but if you see it differently, tell me and I'll fix the attribution or
the licensing.

Thanks for the plugin and, honestly, for the protocol document. It's more carefully
written than most commercial API docs I've worked against, and the notes about decoding
defensively and about full-state resends saved me from two bugs I'd otherwise have
shipped.

Best regards,
Thomas Kant

---

## Deutsch (falls dir das lieber ist — sushi.at ist österreichisch)

**Betreff:** Inoffizieller iPad-Client für Handoff — ist dir das recht?

Hallo,

ich habe einen iPad-Client für dein Handoff-vPilot-Plugin gebaut und wollte mich bei dir
melden, bevor ich damit weitermache.

Es ist eine native SwiftUI-App, die ich komplett anhand von `docs/protocol.md` geschrieben
habe — es steckt kein Code von dir darin. Diesen Weg habe ich gewählt, weil das Protokoll-
Dokument ausdrücklich sagt, es sei die maßgebliche Quelle für einen alternativen Client,
und iOS sogar als Beispiel nennt. Ich hoffe, das war als Einladung gemeint. Die App
spricht genau wie dokumentiert mit dem Plugin: UDP-Discovery, TLS mit Trust-on-First-Use-
Pinning, der Pairing-Code- und Token-Ablauf und die komplette Controller-/Chat-/Funk-Ebene.

Das Repository ist öffentlich:
https://github.com/MANFahrer-GF/vpilot-handoff-ios

Wo mir deine Meinung wichtig wäre:

1. **Ist dir das überhaupt recht?** Wenn du keinen Fremd-Client rund um dein Plugin
   möchtest, sag es — dann stelle ich es auf privat oder nehme es ganz raus.

2. **Der Name.** Ich habe es „Handoff" genannt, weil es genau dafür ein Client ist. Falls
   dir das zu nah ist, benenne ich es gerne um — sag einfach, was dir lieber wäre.

3. **Das Aussehen.** Die Oberfläche orientiert sich bewusst eng an deinem Android-Layout,
   damit Piloten beim Wechseln nichts neu lernen müssen. Das Icon ist meins. Falls dir das
   zu weit geht, ändere ich es.

4. **Verlinkung.** Wäre es dir recht, wenn ich von meinem Projekt auf deins verlinke? Das
   Plugin, die Android-App und die Datenquellen (VATSpy, VatGlasses, VATSIM, SimBrief,
   vPilot) sind in der App und im README bereits genannt. Und falls du den iPad-Client
   irgendwann von deiner Seite erwähnen möchtest, würde ich mich freuen — aber wirklich
   nur, wenn du selbst willst; das ist keine Bitte um einen Gefallen.

5. **Support.** Im README steht klar, dass das inoffiziell ist, nicht mit dir verbunden
   und nicht von dir unterstützt, und dass Fehler der iPad-App in meinen Tracker gehören,
   nicht in deinen. Falls trotzdem jemand deswegen bei dir landet, schick ihn zu mir. Ich
   will dir keine Arbeit machen.

Zur Lizenz: Dein Projekt ist MIT, meins ebenfalls. Da ich den Client anhand des Protokoll-
Dokuments und nicht anhand deines Quellcodes geschrieben habe, gehe ich davon aus, dass
ich keinen Code von dir verbreite — falls du das anders siehst, sag Bescheid, dann
korrigiere ich Zuschreibung oder Lizenz.

Danke für das Plugin und ehrlich gesagt besonders für die Protokoll-Dokumentation. Die ist
sorgfältiger geschrieben als die meisten kommerziellen API-Dokus, mit denen ich zu tun
hatte, und die Hinweise zum defensiven Dekodieren und zu den Full-State-Resends haben mich
vor zwei Fehlern bewahrt, die ich sonst ausgeliefert hätte.

Viele Grüße
Thomas Kant

---

## Wozu ich dir raten würde

**Rechtlich stehst du gut da**, aber „gut" ist nicht dasselbe wie „geklärt":

- **Kein Code übernommen.** Du hast gegen die veröffentlichte Protokoll-Dokumentation
  gebaut, nicht gegen fremden Quellcode. Schnittstellen und Protokolle sind das, was man
  nachimplementieren darf — genau dafür sind sie dokumentiert.
- **Die Doku lädt ausdrücklich ein.** `docs/protocol.md` sagt wörtlich, sie sei die
  maßgebliche Quelle, falls jemand einen alternativen Client baut, „e.g. iOS". Das ist
  näher an einer Einladung als an einer Duldung.
- **MIT auf beiden Seiten.** Selbst wenn Code beteiligt wäre, wäre MIT extrem freizügig.
- **Der Name ist der einzige echte Reibungspunkt.** „Handoff" ist ein Fachbegriff aus der
  Flugsicherung und damit kaum monopolisierbar — aber es ist eben auch *sein* Projektname.
  Deshalb steht die Frage in der Mail: nicht weil du musst, sondern weil Fragen billiger
  ist als Streit. (Nebenbei: „Handoff" ist auch eine Apple-Funktion — falls du je in
  Richtung App Store gehst, wäre ein eigener Name ohnehin die klügere Wahl.)
- **Was du schon richtig gemacht hast:** Der Disclaimer im README, die Credits in der App,
  die eigene Zuschreibung in der Kopfzeile und der Hinweis, wohin Fehlerberichte gehören.
  Das ist genau das, was einen inoffiziellen Client von einer Anmaßung unterscheidet.

**Meine Empfehlung zum Kanal:** Ein GitHub-Issue statt einer privaten Mail. Es ist
öffentlich nachvollziehbar, du dokumentierst damit deinen guten Willen, und andere Piloten
sehen die Antwort auch — was dir Nachfragen erspart.
