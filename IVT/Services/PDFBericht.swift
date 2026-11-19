import UIKit
import PDFKit

/// Baut die beiden PDFs, die er wirklich aus der Hand gibt:
/// den Schadensbericht fuer die Reklamation und die Quartalsauswertung
/// aus dem Fehlerprotokollbuch.
enum PDFBericht {

    private static let seite = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4 in Punkt
    private static let rand: CGFloat = 48

    // MARK: Schadensbericht

    static func schadensbericht(_ vorgang: Schadensvorgang) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: seite, format: info(
            titel: "Schadensbericht \(vorgang.titel)"
        ))

        return renderer.pdfData { ctx in
            var y = neueSeite(ctx, titel: "Schadensbericht")

            y = ueberschrift(vorgang.titel, y: y)
            y += 6

            var kopf: [(String, String)] = [
                ("Angelegt", vorgang.angelegt.datumUndZeit),
                ("Fotos", "\(vorgang.fotos.count)")
            ]
            if !vorgang.spediteur.isEmpty { kopf.insert(("Spediteur", vorgang.spediteur), at: 1) }
            if !vorgang.lieferschein.isEmpty { kopf.insert(("Lieferschein", vorgang.lieferschein), at: 1) }

            for (k, v) in kopf {
                y = feld(k, v, y: y)
            }

            if !vorgang.notiz.isEmpty {
                y += 10
                y = ueberschrift("Beschreibung", y: y, groesse: 13)
                y = absatz(vorgang.notiz, y: y)
            }

            // Fotos, je Seite eines gross, darunter die Angaben
            let fotos = vorgang.fotos.sorted { $0.aufgenommen < $1.aufgenommen }
            for (i, foto) in fotos.enumerated() {
                var yy = neueSeite(ctx, titel: "Schadensbericht")
                yy = ueberschrift("Foto \(i + 1) von \(fotos.count)", y: yy, groesse: 13)
                yy += 4

                if let bild = UIImage(data: foto.daten) {
                    let maxBreite = seite.width - rand * 2
                    let maxHoehe = seite.height - yy - rand - 90
                    let faktor = min(maxBreite / bild.size.width, maxHoehe / bild.size.height)
                    let groesse = CGSize(width: bild.size.width * faktor,
                                         height: bild.size.height * faktor)
                    let x = (seite.width - groesse.width) / 2
                    bild.draw(in: CGRect(origin: CGPoint(x: x, y: yy), size: groesse))
                    yy += groesse.height + 14
                }

                yy = feld("Aufgenommen", foto.aufgenommen.datumUndZeit, y: yy)
                if !foto.ortText.isEmpty { yy = feld("Ort", foto.ortText, y: yy) }
                if let b = foto.breite, let l = foto.laenge {
                    yy = feld("Koordinaten", String(format: "%.5f, %.5f", b, l), y: yy)
                }
                if !foto.bemerkung.isEmpty { _ = absatz(foto.bemerkung, y: yy + 4) }
            }
        }
    }

    // MARK: Quartalsauswertung Fehlerbuch

    static func quartalsauswertung(quartal: String,
                                   eintraege: [Fehlereintrag]) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: seite, format: info(
            titel: "Fehlerauswertung \(quartal)"
        ))

        // Haeufigkeit je Kategorie, absteigend
        var zaehler: [String: Int] = [:]
        for e in eintraege { zaehler[e.kategorie, default: 0] += 1 }
        let rang = zaehler.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
        let gesamt = max(1, eintraege.count)

        return renderer.pdfData { ctx in
            var y = neueSeite(ctx, titel: "Fehlerprotokollbuch")

            y = ueberschrift("Auswertung \(quartal)", y: y)
            y += 4
            y = feld("Erfasste Fehler", "\(eintraege.count)", y: y)
            if let erster = eintraege.map(\.zeit).min(),
               let letzter = eintraege.map(\.zeit).max() {
                y = feld("Zeitraum", "\(erster.datumKurz) bis \(letzter.datumKurz)", y: y)
            }
            y = feld("Erstellt", Date().datumUndZeit, y: y)

            y += 16
            y = ueberschrift("Häufigkeit nach Kategorie", y: y, groesse: 13)
            y += 6

            // Balken, damit auf einen Blick sichtbar ist, wo es klemmt
            let maxWert = rang.first?.value ?? 1
            for (kategorie, anzahl) in rang {
                if y > seite.height - rand - 40 {
                    y = neueSeite(ctx, titel: "Fehlerprotokollbuch")
                }
                let anteil = Double(anzahl) / Double(gesamt) * 100
                text("\(kategorie)",
                     at: CGPoint(x: rand, y: y),
                     breite: seite.width - rand * 2 - 90,
                     schrift: .systemFont(ofSize: 11, weight: .medium))
                text(String(format: "%d  (%.0f %%)", anzahl, anteil),
                     at: CGPoint(x: seite.width - rand - 80, y: y),
                     breite: 80,
                     schrift: .monospacedDigitSystemFont(ofSize: 11, weight: .regular),
                     ausrichtung: .right)
                y += 15

                let breite = (seite.width - rand * 2) * CGFloat(anzahl) / CGFloat(maxWert)
                let balken = UIBezierPath(roundedRect:
                    CGRect(x: rand, y: y, width: max(2, breite), height: 6), cornerRadius: 3)
                UIColor(white: 0.35, alpha: 1).setFill()
                balken.fill()
                y += 16
            }

            y += 12
            if y > seite.height - rand - 60 {
                y = neueSeite(ctx, titel: "Fehlerprotokollbuch")
            }
            y = ueberschrift("Einzeleinträge", y: y, groesse: 13)
            y += 4

            for e in eintraege.sorted(by: { $0.zeit < $1.zeit }) {
                if y > seite.height - rand - 48 {
                    y = neueSeite(ctx, titel: "Fehlerprotokollbuch")
                }
                text(e.zeit.datumUndZeit,
                     at: CGPoint(x: rand, y: y), breite: 120,
                     schrift: .monospacedDigitSystemFont(ofSize: 9, weight: .regular),
                     farbe: .darkGray)
                text(e.kategorie,
                     at: CGPoint(x: rand + 126, y: y),
                     breite: seite.width - rand * 2 - 126,
                     schrift: .systemFont(ofSize: 10, weight: .semibold))
                y += 13
                if !e.notiz.isEmpty {
                    let h = text(e.notiz,
                                 at: CGPoint(x: rand + 126, y: y),
                                 breite: seite.width - rand * 2 - 126,
                                 schrift: .systemFont(ofSize: 10),
                                 farbe: .darkGray)
                    y += h + 2
                }
                y += 6
            }
        }
    }

    // MARK: Wochenbericht

    static func wochenbericht(_ b: Wochenbericht) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: seite, format: info(
            titel: "Wochenbericht Versand \(b.kurzzeitraum)"
        ))

        return renderer.pdfData { ctx in
            var y = neueSeite(ctx, titel: "Wochenbericht Versand")

            y = ueberschrift(b.zeitraum, y: y)
            y += 4
            y = feld("Erstellt", Date().datumUndZeit, y: y)

            // Zeit
            y += 14
            y = ueberschrift("Zeit", y: y, groesse: 13)
            y += 2
            y = feld("Gearbeitet", b.arbeitszeit.alsStundenMinuten, y: y)
            y = feld("Soll", b.soll.alsStundenMinuten, y: y)
            y = feld("Saldo Woche", b.saldo.alsSaldo, y: y)
            y = feld("Konto gesamt", b.kontoGesamt.alsSaldo, y: y)
            if b.schritte > 0 {
                y = feld("Schritte", "\(b.schritte)", y: y)
            }

            if !b.schichten.isEmpty {
                y += 10
                for s in b.schichten {
                    if y > seite.height - rand - 30 {
                        y = neueSeite(ctx, titel: "Wochenbericht Versand")
                    }
                    let tag = "\(s.start.wochentag), \(s.start.datumKurz)"
                    text(tag, at: CGPoint(x: rand, y: y), breite: 150,
                         schrift: .systemFont(ofSize: 10), farbe: .darkGray)
                    let zeiten = "\(s.start.uhrzeit) – \(s.ende?.uhrzeit ?? "läuft")"
                    text(zeiten, at: CGPoint(x: rand + 156, y: y), breite: 110,
                         schrift: .monospacedDigitSystemFont(ofSize: 10, weight: .regular))
                    let dauer = "\(s.arbeitszeit.alsStundenMinuten)   \(s.ende == nil ? "" : s.saldo.alsSaldo)"
                    text(dauer, at: CGPoint(x: seite.width - rand - 120, y: y), breite: 120,
                         schrift: .monospacedDigitSystemFont(ofSize: 10, weight: .medium),
                         ausrichtung: .right)
                    y += 14
                }
            }

            y = abschnitt(ctx, y: y, titel: "Termine nächste Woche", eintraege:
                b.termine.map { a in
                    let wann = a.faellig.map { "\($0.wochentag), \($0.uhrzeit)" } ?? "ohne Termin"
                    return (a.titel, wann)
                })

            y = abschnitt(ctx, y: y, titel: "Offen", eintraege:
                b.offeneAufgaben.map { a in
                    (a.titel, a.istUeberfaellig ? "überfällig" : (a.faellig?.datumKurz ?? ""))
                })

            y = abschnitt(ctx, y: y, titel: "Notizen dieser Woche", eintraege:
                b.notizenDerWoche.map { ($0.titel, $0.notiz) })

            y = abschnitt(ctx, y: y, titel: "Fehler dieser Woche", eintraege:
                b.fehlerRang.map { ($0.0, "\($0.1)×") })

            y = abschnitt(ctx, y: y, titel: "Schäden dieser Woche", eintraege:
                b.schaeden.map { s in
                    var rechts = "\(s.fotos.count) Foto\(s.fotos.count == 1 ? "" : "s")"
                    if !s.spediteur.isEmpty { rechts = "\(s.spediteur) · " + rechts }
                    return (s.titel, rechts)
                })

            if b.istLeer {
                _ = absatz("In dieser Woche wurde nichts erfasst.", y: y + 10)
            }
        }
    }

    /// Ein Abschnitt mit Liste; ueberspringt sich selbst, wenn leer.
    private static func abschnitt(_ ctx: UIGraphicsPDFRendererContext,
                                  y: CGFloat,
                                  titel: String,
                                  eintraege: [(String, String)]) -> CGFloat {
        guard !eintraege.isEmpty else { return y }
        var yy = y + 14
        if yy > seite.height - rand - 60 {
            yy = neueSeite(ctx, titel: "Wochenbericht Versand")
        }
        yy = ueberschrift("\(titel) (\(eintraege.count))", y: yy, groesse: 13)
        yy += 2

        for (links, rechts) in eintraege {
            if yy > seite.height - rand - 30 {
                yy = neueSeite(ctx, titel: "Wochenbericht Versand")
            }
            let breiteLinks = seite.width - rand * 2 - 130
            let h = text("•  " + links,
                         at: CGPoint(x: rand, y: yy), breite: breiteLinks,
                         schrift: .systemFont(ofSize: 11))
            if !rechts.isEmpty {
                text(rechts,
                     at: CGPoint(x: seite.width - rand - 125, y: yy), breite: 125,
                     schrift: .systemFont(ofSize: 10), farbe: .darkGray,
                     ausrichtung: .right)
            }
            yy += max(h, 14) + 3
        }
        return yy
    }

    // MARK: Bausteine

    private static func info(titel: String) -> UIGraphicsPDFRendererFormat {
        let f = UIGraphicsPDFRendererFormat()
        f.documentInfo = [
            kCGPDFContextTitle as String: titel,
            kCGPDFContextCreator as String: "IVT"
        ]
        return f
    }

    @discardableResult
    private static func neueSeite(_ ctx: UIGraphicsPDFRendererContext, titel: String) -> CGFloat {
        ctx.beginPage()
        text(titel,
             at: CGPoint(x: rand, y: rand - 18),
             breite: seite.width - rand * 2,
             schrift: .systemFont(ofSize: 9, weight: .semibold),
             farbe: .gray)
        let linie = UIBezierPath()
        linie.move(to: CGPoint(x: rand, y: rand - 2))
        linie.addLine(to: CGPoint(x: seite.width - rand, y: rand - 2))
        UIColor(white: 0.85, alpha: 1).setStroke()
        linie.lineWidth = 0.6
        linie.stroke()
        return rand + 10
    }

    @discardableResult
    private static func ueberschrift(_ s: String, y: CGFloat, groesse: CGFloat = 19) -> CGFloat {
        let h = text(s, at: CGPoint(x: rand, y: y),
                     breite: seite.width - rand * 2,
                     schrift: .systemFont(ofSize: groesse, weight: .bold))
        return y + h + 6
    }

    @discardableResult
    private static func feld(_ name: String, _ wert: String, y: CGFloat) -> CGFloat {
        text(name, at: CGPoint(x: rand, y: y), breite: 120,
             schrift: .systemFont(ofSize: 10), farbe: .gray)
        let h = text(wert, at: CGPoint(x: rand + 126, y: y),
                     breite: seite.width - rand * 2 - 126,
                     schrift: .systemFont(ofSize: 11, weight: .medium))
        return y + max(h, 14) + 3
    }

    @discardableResult
    private static func absatz(_ s: String, y: CGFloat) -> CGFloat {
        let h = text(s, at: CGPoint(x: rand, y: y),
                     breite: seite.width - rand * 2,
                     schrift: .systemFont(ofSize: 11))
        return y + h + 8
    }

    @discardableResult
    private static func text(_ s: String,
                             at punkt: CGPoint,
                             breite: CGFloat,
                             schrift: UIFont,
                             farbe: UIColor = .black,
                             ausrichtung: NSTextAlignment = .left) -> CGFloat {
        let stil = NSMutableParagraphStyle()
        stil.alignment = ausrichtung
        stil.lineBreakMode = .byWordWrapping
        let attribute: [NSAttributedString.Key: Any] = [
            .font: schrift, .foregroundColor: farbe, .paragraphStyle: stil
        ]
        let text = NSAttributedString(string: s, attributes: attribute)
        let rahmen = text.boundingRect(
            with: CGSize(width: breite, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        text.draw(with: CGRect(origin: punkt, size: CGSize(width: breite, height: ceil(rahmen.height))),
                  options: [.usesLineFragmentOrigin, .usesFontLeading],
                  context: nil)
        return ceil(rahmen.height)
    }
}
