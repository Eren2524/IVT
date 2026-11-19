import Foundation
import CoreLocation

// MARK: - Gangart

/// Mehr Stufen braucht es nicht: entweder er geht, oder er steht,
/// oder das iPhone weiss gerade nichts.
enum Gangart: String, Codable {
    case halt, bewegt
    /// Strecke ohne Signal - meist in der Halle
    case luecke

    var anzeige: String {
        switch self {
        case .halt:   return "Gestanden"
        case .bewegt: return "Unterwegs"
        case .luecke: return "Kein Signal"
        }
    }

    var symbol: String {
        switch self {
        case .halt:   return "pause.circle.fill"
        case .bewegt: return "figure.walk"
        case .luecke: return "wifi.slash"
        }
    }
}

// MARK: - Abschnitt

struct Wegabschnitt: Identifiable {
    let id = UUID()
    var von: Date
    var bis: Date
    var koordinaten: [CLLocationCoordinate2D]
    var meter: Double
    var gangart: Gangart

    var dauer: TimeInterval { max(0, bis.timeIntervalSince(von)) }

    var mitte: CLLocationCoordinate2D? {
        guard !koordinaten.isEmpty else { return nil }
        return koordinaten[koordinaten.count / 2]
    }
}

// MARK: - Auffaelligkeit

struct Auffaelligkeit: Identifiable {
    enum Art: String {
        case start, ende, halt, aufenthalt, luecke

        var symbol: String {
            switch self {
            case .start:      return "play.circle.fill"
            case .ende:       return "stop.circle.fill"
            case .halt:       return "pause.circle.fill"
            case .aufenthalt: return "mappin.circle.fill"
            case .luecke:     return "wifi.slash"
            }
        }
    }

    let id = UUID()
    var art: Art
    var zeit: Date
    var dauer: TimeInterval
    var ort: CLLocationCoordinate2D
    var titel: String
    var text: String
}

// MARK: - Gesamtbild

struct Wegbild {
    var abschnitte: [Wegabschnitt] = []
    var auffaelligkeiten: [Auffaelligkeit] = []
    var gesamtMeter: Double = 0
    var gehzeit: TimeInterval = 0
    var standzeit: TimeInterval = 0
    var luecken: TimeInterval = 0

    var von: Date? { abschnitte.first?.von }
    var bis: Date? { abschnitte.last?.bis }

    var istLeer: Bool { abschnitte.isEmpty }

    var alleKoordinaten: [CLLocationCoordinate2D] {
        abschnitte.flatMap(\.koordinaten)
    }

    /// Wo war ich zu diesem Zeitpunkt? Zwischen den Stuetzpunkten
    /// wird linear interpoliert, damit der Regler weich laeuft.
    func position(zu zeit: Date) -> CLLocationCoordinate2D? {
        guard !abschnitte.isEmpty else { return nil }
        if let erster = abschnitte.first, zeit <= erster.von {
            return erster.koordinaten.first
        }
        if let letzter = abschnitte.last, zeit >= letzter.bis {
            return letzter.koordinaten.last
        }
        for a in abschnitte where zeit >= a.von && zeit <= a.bis {
            guard a.koordinaten.count > 1, a.dauer > 0 else {
                return a.koordinaten.first
            }
            let anteil = zeit.timeIntervalSince(a.von) / a.dauer
            let stelle = anteil * Double(a.koordinaten.count - 1)
            let i = min(a.koordinaten.count - 2, max(0, Int(stelle)))
            let rest = stelle - Double(i)
            let p = a.koordinaten[i], q = a.koordinaten[i + 1]
            return CLLocationCoordinate2D(
                latitude: p.latitude + (q.latitude - p.latitude) * rest,
                longitude: p.longitude + (q.longitude - p.longitude) * rest
            )
        }
        // In einer Luecke: letzte bekannte Position davor
        return abschnitte.last(where: { $0.bis <= zeit })?.koordinaten.last
    }

    /// Der Abschnitt, in dem dieser Zeitpunkt liegt.
    func abschnitt(zu zeit: Date) -> Wegabschnitt? {
        abschnitte.first { zeit >= $0.von && zeit <= $0.bis }
    }
}

// MARK: - Auswertung

enum Wegauswertung {

    /// Unter 0,3 m/s steht er herum statt zu gehen.
    static let grenzeHalt: Double = 0.3
    /// Darueber ist es kein Fussweg mehr, sondern ein GPS-Sprung
    static let grenzeUnsinn: Double = 8.0

    /// Ab dieser Pause zwischen zwei Punkten gilt die Strecke als Luecke.
    static let lueckeAb: TimeInterval = 5 * 60
    /// Ab so langem Stehen wird ein Infopunkt gesetzt.
    /// Bewusst hoch: bei 3 Minuten wird aus jedem Rampengang ein Hinweis,
    /// und 38 Hinweise sind kein Hinweis mehr, sondern ein Protokoll.
    static let haltAb: TimeInterval = 8 * 60
    /// Erst ab dieser Luecke lohnt ein Infopunkt.
    static let lueckeInfoAb: TimeInterval = 10 * 60
    /// Mehr als das passt weder auf die Karte noch in den Kopf.
    static let maxInfopunkte = 14
    /// So lange muss er weg gewesen sein, damit es als neuer Besuch zaehlt.
    static let besuchPauseAb: TimeInterval = 2 * 60
    /// Kantenlaenge der Raster-Zelle fuer Aufenthaltsorte.
    static let zelleMeter: Double = 30

    static func auswerten(_ rohe: [Wegpunkt]) -> Wegbild {
        let punkte = rohe
            .filter { $0.genauigkeit > 0 && $0.genauigkeit <= 60 }
            .sorted { $0.zeit < $1.zeit }
        guard punkte.count > 1 else { return Wegbild() }

        // 1) Teilstuecke zwischen je zwei Punkten
        struct Stueck {
            var von: Date, bis: Date
            var a: CLLocationCoordinate2D, b: CLLocationCoordinate2D
            var meter: Double, gangart: Gangart
        }
        var stuecke: [Stueck] = []

        for i in 1..<punkte.count {
            let p = punkte[i - 1], q = punkte[i]
            let dt = q.zeit.timeIntervalSince(p.zeit)
            guard dt > 0 else { continue }

            let a = CLLocation(latitude: p.breite, longitude: p.laenge)
            let b = CLLocation(latitude: q.breite, longitude: q.laenge)
            let meter = b.distance(from: a)
            let tempo = meter / dt

            let art: Gangart
            if dt >= lueckeAb || tempo > grenzeUnsinn {
                // Lange nichts gehoert oder ein unmoeglicher Sprung:
                // dazwischen wird nichts behauptet.
                art = .luecke
            } else if tempo < grenzeHalt {
                art = .halt
            } else {
                art = .bewegt
            }

            stuecke.append(Stueck(von: p.zeit, bis: q.zeit,
                                  a: a.coordinate, b: b.coordinate,
                                  meter: art == .luecke ? 0 : meter,
                                  gangart: art))
        }
        guard !stuecke.isEmpty else { return Wegbild() }

        // 2) Gleiche Gangart zusammenfassen
        var abschnitte: [Wegabschnitt] = []
        for s in stuecke {
            if var letzter = abschnitte.last, letzter.gangart == s.gangart {
                letzter.bis = s.bis
                letzter.meter += s.meter
                letzter.koordinaten.append(s.b)
                abschnitte[abschnitte.count - 1] = letzter
            } else {
                abschnitte.append(Wegabschnitt(von: s.von, bis: s.bis,
                                               koordinaten: [s.a, s.b],
                                               meter: s.meter,
                                               gangart: s.gangart))
            }
        }

        // 3) Schnipsel unter 30 Sekunden in den Nachbarn aufgehen lassen,
        //    sonst zerfaellt die Karte in Konfetti.
        abschnitte = glaetten(abschnitte)

        // 4) Zahlen
        var bild = Wegbild(abschnitte: abschnitte)
        for a in abschnitte {
            bild.gesamtMeter += a.meter
            switch a.gangart {
            case .halt:   bild.standzeit += a.dauer
            case .luecke: bild.luecken += a.dauer
            default:      bild.gehzeit += a.dauer
            }
        }

        // 5) Infopunkte
        bild.auffaelligkeiten = infopunkte(abschnitte, punkte: punkte)
        return bild
    }

    // MARK: Glaetten

    private static func glaetten(_ roh: [Wegabschnitt]) -> [Wegabschnitt] {
        guard roh.count > 2 else { return roh }
        var aus: [Wegabschnitt] = []
        for a in roh {
            // Eine Luecke bleibt immer stehen, sie ist eine Aussage fuer sich
            if a.gangart != .luecke, a.dauer < 30, var vorher = aus.last,
               vorher.gangart != .luecke {
                vorher.bis = a.bis
                vorher.meter += a.meter
                vorher.koordinaten.append(contentsOf: a.koordinaten.dropFirst())
                aus[aus.count - 1] = vorher
            } else {
                aus.append(a)
            }
        }
        return aus
    }

    // MARK: Infopunkte

    private static func infopunkte(_ abschnitte: [Wegabschnitt],
                                   punkte: [Wegpunkt]) -> [Auffaelligkeit] {
        var aus: [Auffaelligkeit] = []

        if let erster = abschnitte.first, let ort = erster.koordinaten.first {
            aus.append(Auffaelligkeit(
                art: .start, zeit: erster.von, dauer: 0, ort: ort,
                titel: "Losgegangen",
                text: "Erster Punkt um \(erster.von.uhrzeit)."))
        }

        for a in abschnitte {
            guard let ort = a.mitte else { continue }

            switch a.gangart {
            case .halt where a.dauer >= haltAb:
                aus.append(Auffaelligkeit(
                    art: .halt, zeit: a.von, dauer: a.dauer, ort: ort,
                    titel: "\(minuten(a.dauer)) gestanden",
                    text: "Von \(a.von.uhrzeit) bis \(a.bis.uhrzeit) kaum bewegt."))

            case .luecke where a.dauer >= lueckeInfoAb:
                aus.append(Auffaelligkeit(
                    art: .luecke, zeit: a.von, dauer: a.dauer, ort: ort,
                    titel: "\(minuten(a.dauer)) kein Signal",
                    text: "Zwischen \(a.von.uhrzeit) und \(a.bis.uhrzeit) kam nichts an — vermutlich in der Halle."))

            default:
                break
            }
        }

        aus.append(contentsOf: aufenthaltsorte(punkte))

        if let letzter = abschnitte.last, let ort = letzter.koordinaten.last {
            aus.append(Auffaelligkeit(
                art: .ende, zeit: letzter.bis, dauer: 0, ort: ort,
                titel: "Letzter Punkt",
                text: "Um \(letzter.bis.uhrzeit) aufgehört aufzuzeichnen."))
        }

        return deckeln(aus).sorted { $0.zeit < $1.zeit }
    }

    /// Start und Ende bleiben immer. Vom Rest ueberlebt das Auffaelligste.
    private static func deckeln(_ alle: [Auffaelligkeit]) -> [Auffaelligkeit] {
        guard alle.count > maxInfopunkte else { return alle }

        let fest = alle.filter { $0.art == .start || $0.art == .ende }
        let rest = alle.filter { $0.art != .start && $0.art != .ende }

        func gewicht(_ a: Auffaelligkeit) -> Double {
            switch a.art {
            case .aufenthalt: return 100_000 + a.dauer   // sagt am meisten ueber den Tag
            case .luecke:     return  50_000 + a.dauer
            case .halt:       return a.dauer             // nur die laengsten
            case .start, .ende: return .greatestFiniteMagnitude
            }
        }

        let behalten = rest
            .sorted { gewicht($0) > gewicht($1) }
            .prefix(max(0, maxInfopunkte - fest.count))

        return fest + behalten
    }

    /// Orte, an die er im Lauf der Schicht immer wieder zurueckkommt.
    private static func aufenthaltsorte(_ punkte: [Wegpunkt]) -> [Auffaelligkeit] {
        guard punkte.count > 3 else { return [] }

        struct Zelle { var zeit: TimeInterval = 0; var besuche = 0
                       var summeB = 0.0; var summeL = 0.0; var n = 0
                       var ersteZeit: Date?; var zuletztGesehen: Date? }
        var zellen: [String: Zelle] = [:]

        let gradProMeterB = 1.0 / 111_320.0

        for i in 1..<punkte.count {
            let p = punkte[i - 1], q = punkte[i]
            let dt = q.zeit.timeIntervalSince(p.zeit)
            guard dt > 0, dt < lueckeAb else { continue }

            let gradProMeterL = gradProMeterB / max(0.2, cos(p.breite * .pi / 180))
            let zb = Int((p.breite / (zelleMeter * gradProMeterB)).rounded(.down))
            let zl = Int((p.laenge / (zelleMeter * gradProMeterL)).rounded(.down))
            let schluessel = "\(zb)|\(zl)"

            var z = zellen[schluessel] ?? Zelle()
            z.zeit += dt
            z.summeB += p.breite; z.summeL += p.laenge; z.n += 1
            if z.ersteZeit == nil { z.ersteZeit = p.zeit }

            // Ein neuer Besuch ist es nur, wenn er lange genug weg war.
            // Sonst zaehlt jedes Zittern an der Zellengrenze als Rueckkehr
            // und aus neun Gaengen werden siebenundneunzig.
            if let zuletzt = z.zuletztGesehen {
                if p.zeit.timeIntervalSince(zuletzt) >= besuchPauseAb { z.besuche += 1 }
            } else {
                z.besuche = 1
            }
            z.zuletztGesehen = p.zeit

            zellen[schluessel] = z
        }

        return zellen.values
            .filter { $0.zeit >= 15 * 60 && $0.besuche >= 3 && $0.n > 0 }
            .sorted { $0.zeit > $1.zeit }
            .prefix(2)
            .map { z in
                Auffaelligkeit(
                    art: .aufenthalt,
                    zeit: z.ersteZeit ?? Date(),
                    dauer: z.zeit,
                    ort: CLLocationCoordinate2D(latitude: z.summeB / Double(z.n),
                                                longitude: z.summeL / Double(z.n)),
                    titel: "Oft hier gewesen",
                    text: "\(z.besuche)× zurückgekommen, zusammen \(minuten(z.zeit)).")
            }
    }

    static func minuten(_ t: TimeInterval) -> String {
        let m = Int((t / 60).rounded())
        if m >= 60 {
            return "\(m / 60):\(String(format: "%02d", m % 60)) h"
        }
        return "\(max(1, m)) min"
    }
}
