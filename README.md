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
3. Mitteilungen erlauben, sonst kommt die Pausenfrage nicht durch.

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
  Services/
    Einstellungen.swift   Vorgaben in UserDefaults
    Standortdienst.swift  Geofence und Route (CoreLocation)
    Bewegungsdienst.swift Schritte und Stillstand (CoreMotion)
    Zeitdienst.swift      hält die Zeiterfassung zusammen
    Meldungen.swift       lokale Mitteilungen
    Fotostempel.swift     Datum/Zeit/Ort ins Bild brennen
    PDFBericht.swift      Schadensbericht und Quartalsauswertung
  Views/                  Dashboard, Zeit, Laden, Schäden, Aufgaben,
                          Fehlerbuch, Bewegung, Einstellungen
```
