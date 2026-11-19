# IVT — IEB-Versand-Team

Native iPhone-App für Enriques Arbeit als Versandleiter bei IEB Brilon.
SwiftUI, SwiftData, keine Fremdbibliotheken. **Alle Daten bleiben auf dem
iPhone** — kein Server, keine iCloud, keine Synchronisierung.

## Was drin ist

| Bereich | Was es tut |
|---|---|
| **Dashboard** | Arbeitszeit und Überstundenkonto groß oben, darunter offene Aufgaben, Schritte und die letzten Schadensfotos. Drei Schnellknöpfe: Fehler, Notiz, Schaden. |
| **Zeit** | Geofence um die Firma startet und beendet die Schicht. Feste Pausen werden abgezogen, 15 Minuten Stillstand lösen die Frage „Pause?“ aus. Jede Schicht ist von Hand korrigierbar. |
| **Laden** | Palettenrechner für den DSV-Zug. Eintragen, was raus muss — die App sagt, ob es passt. |
| **Schäden** | Fotos mit Datum, Uhrzeit und Ort **ins Bild gebrannt**, gebündelt zu Vorgängen, Export als PDF für die Reklamation. |
| **Aufgaben** | Schnellnotizen, Erinnerungen, wiederkehrende Rhythmen (jeden Montag, Monatsende, quartalsweise). |
| **Fehlerbuch** | Fehler in Sekunden erfasst, Quartalsauswertung mit Balken und PDF-Export. |
| **Bewegung** | Schritte pro Schicht, Route auf der Karte, „Wo war ich um 14:30?“ |

## Mailversand — warum ein Tipp bleibt

**iOS lässt keine App im Hintergrund Mails verschicken.** Es gibt genau zwei
Wege, und nur einer ist vertretbar:

| Weg | Bewertung |
|---|---|
| `MFMailComposeViewController` | Die App legt die Mail vollständig hin — Empfänger, Betreff, Text, Fotos, PDF. Der Mensch tippt auf Senden. **So ist es gebaut.** |
| Eigenes SMTP in der App | Bräuchte das Firmen-Mail-Passwort im Klartext in der App. Wird von IEB-Mail ohnehin geblockt. Nicht gebaut, und zwar absichtlich. |
| Server als Relais | Widerspricht „alles bleibt lokal". Nicht gebaut. |

Es ist also **ein Tipp statt null** — aber nichts mehr zu tippen oder anzuhängen.

### Schadensmeldung

Nach jedem Foto (Schalter in den Einstellungen) oder per Knopf im Vorgang:

- **Betreff:** `Schadensmeldung: <Titel> (LS <Lieferschein>)`
- **Text:** Vorgang, Spediteur, Lieferschein, Zeitpunkt, Ort, Koordinaten, Beschreibung
- **Anhang:** vollständiger Bericht als PDF plus die ersten sechs Fotos einzeln,
  damit sie ohne PDF-Betrachter sofort sichtbar sind

### Wochenbericht

Voreinstellung **Freitag 13:00** — nach dem kurzen Freitag ist die Woche
komplett. Die Mitteilung öffnet den fertigen Entwurf direkt. Drin steht:

- Zeit: gearbeitet, Soll, Wochensaldo, Überstundenkonto, Schritte,
  dazu jede Schicht einzeln
- Termine der **kommenden** Woche
- alles noch Offene, Überfälliges markiert
- Notizen dieser Woche
- Fehler dieser Woche, nach Häufigkeit sortiert
- Schäden dieser Woche

Im Reiter *Mehr → Wochenbericht* lässt sich jede Woche vorher ansehen,
auch die letzte und vorletzte.

## Arbeitszeiten (Auslieferungszustand)

```
Mo – Do   6:30 – 15:40     Pausen 9:30–9:40 und 12:30–13:00   Soll 8:30
Fr        6:30 – 12:40     Pause  9:30–9:40                   Soll 6:00
                                                        Woche  40:00
```

Steht in `IVT/Logic/Arbeitsplan.swift`.

## Der Zug (Auslieferungszustand)

```
1 Koffer:  18 Bodenplätze + 18 im zweiten Stock  =  36 Stellplätze
LKW + baugleicher Anhänger                       =  72 Stellplätze
                                      davon am Boden  36
```

- 1 Europalette = 1 Stellplatz
- 2 Halbpaletten = 1 Stellplatz (gepaart wird nur innerhalb derselben Stapelbarkeit)
- **Nicht stapelbar** belegt einen Bodenplatz und blockiert den Platz darüber
- Der Rechner legt stapelbare Ware zuerst auf den Boden, weil nur darauf der
  zweite Stock nutzbar ist

In den Einstellungen änderbar. Logik in `IVT/Logic/Palettenrechner.swift`.

## Bauen

Im Repo liegt nur `project.yml`; die `.xcodeproj` wird erzeugt.

```bash
brew install xcodegen
xcodegen generate
open IVT.xcodeproj
```

### IPA für SideStore

`.github/workflows/ipa.yml` baut bei jedem Push auf `main` eine **unsignierte
IPA** und hängt sie an ein Release — dasselbe Muster wie bei Palverse.
Die IPA landet unter *Releases* und als Artefakt des Laufs.

Von Hand:

```bash
xcodebuild -project IVT.xcodeproj -scheme IVT -configuration Release \
  -sdk iphoneos -derivedDataPath build -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO clean build
mkdir Payload && cp -R build/Build/Products/Release-iphoneos/IVT.app Payload/
zip -qry IVT.ipa Payload && rm -rf Payload
```

## Beim ersten Start

1. **Einstellungen → Firmengelände:** auf dem Hof stehen, „Ich stehe jetzt in
   der Firma“ tippen. Radius 150 m ist ein guter Start.
2. **Standort auf „Immer“ stellen.** Nur dann erkennt die App Kommen und Gehen
   auch bei geschlossener App. iOS fragt zuerst nur nach „Bei Nutzung“ — die
   zweite Frage kommt separat.
3. Mitteilungen erlauben, sonst kommt weder die Pausenfrage noch der
   Wochenbericht durch.
4. **Einstellungen → Arbeitsmail:** Adresse eintragen. Ohne Adresse bleiben
   die Mailknöpfe aus. Dann die beiden Schalter setzen: „Nach jedem
   Schadensfoto" und „Wochenbericht erinnern".

## Was die App nicht kann

- **GPS in der Halle.** Zwischen Stahl und Beton liefert GPS Phantomwerte;
  alles über 60 m Ungenauigkeit wird verworfen. Die Route ist nur draußen
  belastbar, der Schrittzähler läuft drinnen weiter (der kommt aus dem
  Bewegungs-Coprozessor, nicht aus GPS).
- **Geofence ist nicht sekundengenau.** iOS meldet Betreten und Verlassen,
  wenn es ihm passt — meist innerhalb weniger Minuten. Für Kommen und Gehen
  reicht das, und korrigieren kannst du jede Schicht per Hand.
- **Kein Mehrbenutzerbetrieb.** Bewusst: die App ist für einen Menschen,
  die Daten gehören nur ihm.
- **Mail nicht vollautomatisch.** Siehe oben — Apple lässt das nicht zu.
  Ohne eingerichtetes Mail-Konto auf dem iPhone bleibt nur „PDF teilen".

## Struktur

```
IVT/
  IVTApp.swift            App-Einstieg, SwiftData-Container
  Theme.swift             Apple-Stil: Karten, Kennzahlen, Formatierung
  Models/Modelle.swift    Schicht, Pause, Wegpunkt, Aufgabe, Schaden, Fehler
  Logic/
    Arbeitsplan.swift     Arbeitszeiten und Soll-Rechnung
    Palettenrechner.swift Stellplatz-Logik des Zuges
    Routenhilfe.swift     Streckenlänge
    Wochenbericht.swift   Wochendaten zusammentragen
  Services/
    Einstellungen.swift   Vorgaben in UserDefaults
    Standortdienst.swift  Geofence und Route (CoreLocation)
    Bewegungsdienst.swift Schritte und Stillstand (CoreMotion)
    Zeitdienst.swift      hält die Zeiterfassung zusammen
    Meldungen.swift       lokale Mitteilungen, Wochentermin
    Mailversand.swift     fertige Mailentwürfe (MFMailCompose)
    Wegweiser.swift       Sprung aus der Mitteilung in den Bericht
    Fotostempel.swift     Datum/Zeit/Ort ins Bild brennen
    PDFBericht.swift      Schadensbericht, Quartals- und Wochenauswertung
  Views/                  Dashboard, Zeit, Laden, Schäden, Aufgaben,
                          Fehlerbuch, Bewegung, Wochenbericht, Einstellungen
```
