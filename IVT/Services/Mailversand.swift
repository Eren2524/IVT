import SwiftUI
import MessageUI

/// Ein fertiger Mailentwurf. Alles ist schon drin, es fehlt nur noch
/// der Druck auf Senden.
///
/// iOS erlaubt keiner App, im Hintergrund Mails zu verschicken. Der
/// einzige Weg ohne eigenen Server und ohne hinterlegtes Passwort ist
/// MFMailComposeViewController: die App legt die Mail vollstaendig hin,
/// der Mensch bestaetigt. Das ist Absicht von Apple und nicht zu umgehen.
struct Mailentwurf: Identifiable {
    let id = UUID()
    var empfaenger: [String]
    var betreff: String
    var text: String
    var anhaenge: [Anhang] = []

    struct Anhang {
        var daten: Data
        var typ: String   // MIME-Typ
        var name: String
    }

    var hatEmpfaenger: Bool {
        empfaenger.contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    /// Ohne hinterlegte Adresse oeffnet Mail mit leerem An-Feld und
    /// setzt den Cursor dorthin. Tippen, senden, fertig.
    var empfaengerSauber: [String] {
        empfaenger
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

/// Der Mailentwurf als SwiftUI-Blatt.
struct Mailfenster: UIViewControllerRepresentable {
    var entwurf: Mailentwurf
    var fertig: ((MFMailComposeResult) -> Void)?
    @Environment(\.dismiss) private var schliessen

    @MainActor
    static var kannMailen: Bool { MFMailComposeViewController.canSendMail() }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let c = MFMailComposeViewController()
        c.mailComposeDelegate = context.coordinator
        c.setToRecipients(entwurf.empfaengerSauber)
        c.setSubject(entwurf.betreff)
        c.setMessageBody(entwurf.text, isHTML: false)
        for a in entwurf.anhaenge {
            c.addAttachmentData(a.daten, mimeType: a.typ, fileName: a.name)
        }
        return c
    }

    func updateUIViewController(_ c: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Koordinator { Koordinator(self) }

    final class Koordinator: NSObject, MFMailComposeViewControllerDelegate {
        let eltern: Mailfenster
        init(_ eltern: Mailfenster) { self.eltern = eltern }

        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult,
                                   error: Error?) {
            eltern.fertig?(result)
            eltern.schliessen()
        }
    }
}

// MARK: - Texte

enum Mailtexte {

    /// Schadensmeldung: Betreff und Text so, dass der Empfaenger
    /// ohne Rueckfrage weiterarbeiten kann.
    static func schadensmeldung(_ vorgang: Schadensvorgang,
                                an empfaenger: String,
                                absender: String) -> Mailentwurf {
        let fotos = vorgang.fotos.sorted { $0.aufgenommen < $1.aufgenommen }

        var betreff = "Schadensmeldung: \(vorgang.titel)"
        if !vorgang.lieferschein.isEmpty {
            betreff += " (LS \(vorgang.lieferschein))"
        }

        var zeilen: [String] = []
        zeilen.append("Schadensmeldung aus dem Versand.")
        zeilen.append("")
        zeilen.append("Vorgang:      \(vorgang.titel)")
        if !vorgang.spediteur.isEmpty    { zeilen.append("Spediteur:    \(vorgang.spediteur)") }
        if !vorgang.lieferschein.isEmpty { zeilen.append("Lieferschein: \(vorgang.lieferschein)") }
        zeilen.append("Erfasst:      \(vorgang.angelegt.datumUndZeit)")
        zeilen.append("Fotos:        \(fotos.count)")

        if let erstes = fotos.first {
            zeilen.append("Aufgenommen:  \(erstes.aufgenommen.datumUndZeit)")
            if !erstes.ortText.isEmpty { zeilen.append("Ort:          \(erstes.ortText)") }
            if let b = erstes.breite, let l = erstes.laenge {
                zeilen.append(String(format: "Koordinaten:  %.5f, %.5f", b, l))
            }
        }

        if !vorgang.notiz.isEmpty {
            zeilen.append("")
            zeilen.append("Beschreibung:")
            zeilen.append(vorgang.notiz)
        }

        zeilen.append("")
        zeilen.append("Datum, Uhrzeit und Ort stehen in jedem Foto selbst.")
        zeilen.append("Der vollständige Bericht liegt als PDF im Anhang.")
        if !absender.isEmpty {
            zeilen.append("")
            zeilen.append(absender)
        }

        var anhaenge: [Mailentwurf.Anhang] = []

        // Bericht als PDF
        let pdf = PDFBericht.schadensbericht(vorgang)
        anhaenge.append(.init(daten: pdf,
                              typ: "application/pdf",
                              name: dateiname("Schadensmeldung \(vorgang.titel).pdf")))

        // Die Fotos zusaetzlich einzeln, damit sie ohne PDF-Betrachter
        // sofort sichtbar sind. Mehr als sechs wuerden die Mail aufblasen.
        for (i, foto) in fotos.prefix(6).enumerated() {
            anhaenge.append(.init(
                daten: foto.daten,
                typ: "image/jpeg",
                name: dateiname("Foto \(i + 1) \(foto.aufgenommen.datumKurz).jpg")
            ))
        }

        return Mailentwurf(empfaenger: [empfaenger],
                           betreff: betreff,
                           text: zeilen.joined(separator: "\n"),
                           anhaenge: anhaenge)
    }

    /// Wochenbericht: Zusammenfassung im Text, Einzelheiten im PDF.
    static func wochenbericht(_ b: Wochenbericht,
                              an empfaenger: String,
                              absender: String) -> Mailentwurf {
        var zeilen: [String] = []
        zeilen.append("Wochenbericht Versand, \(b.zeitraum)")
        zeilen.append("")
        zeilen.append("ZEIT")
        zeilen.append("  Gearbeitet:   \(b.arbeitszeit.alsStundenMinuten)")
        zeilen.append("  Soll:         \(b.soll.alsStundenMinuten)")
        zeilen.append("  Saldo Woche:  \(b.saldo.alsSaldo)")
        zeilen.append("  Konto gesamt: \(b.kontoGesamt.alsSaldo)")
        zeilen.append("  Schritte:     \(b.schritte)")

        if !b.termine.isEmpty {
            zeilen.append("")
            zeilen.append("TERMINE NÄCHSTE WOCHE (\(b.termine.count))")
            for a in b.termine {
                let wann = a.faellig.map { "\($0.wochentag), \($0.uhrzeit)" } ?? "ohne Termin"
                zeilen.append("  • \(a.titel) — \(wann)")
            }
        }

        if !b.offeneAufgaben.isEmpty {
            zeilen.append("")
            zeilen.append("OFFEN (\(b.offeneAufgaben.count))")
            for a in b.offeneAufgaben {
                let ueber = a.istUeberfaellig ? "  [überfällig]" : ""
                zeilen.append("  • \(a.titel)\(ueber)")
            }
        }

        if !b.notizenDerWoche.isEmpty {
            zeilen.append("")
            zeilen.append("NOTIZEN DIESER WOCHE (\(b.notizenDerWoche.count))")
            for a in b.notizenDerWoche {
                zeilen.append("  • \(a.titel)")
                if !a.notiz.isEmpty { zeilen.append("    \(a.notiz)") }
            }
        }

        if !b.fehler.isEmpty {
            zeilen.append("")
            zeilen.append("FEHLER DIESER WOCHE (\(b.fehler.count))")
            for (kategorie, anzahl) in b.fehlerRang {
                zeilen.append("  \(anzahl)×  \(kategorie)")
            }
        }

        if !b.schaeden.isEmpty {
            zeilen.append("")
            zeilen.append("SCHÄDEN DIESER WOCHE (\(b.schaeden.count))")
            for s in b.schaeden {
                var z = "  • \(s.titel)"
                if !s.spediteur.isEmpty { z += " — \(s.spediteur)" }
                z += " (\(s.fotos.count) Foto\(s.fotos.count == 1 ? "" : "s"))"
                zeilen.append(z)
            }
        }

        zeilen.append("")
        zeilen.append("Einzelheiten im PDF im Anhang.")
        if !absender.isEmpty {
            zeilen.append("")
            zeilen.append(absender)
        }

        let pdf = PDFBericht.wochenbericht(b)
        return Mailentwurf(
            empfaenger: [empfaenger],
            betreff: "Wochenbericht Versand \(b.kurzzeitraum)",
            text: zeilen.joined(separator: "\n"),
            anhaenge: [.init(daten: pdf,
                             typ: "application/pdf",
                             name: dateiname("Wochenbericht \(b.kurzzeitraum).pdf"))]
        )
    }

    /// Dateinamen, die Mail-Programme nicht zerlegen.
    private static func dateiname(_ roh: String) -> String {
        roh.replacingOccurrences(of: "/", with: "-")
           .replacingOccurrences(of: ":", with: "-")
           .replacingOccurrences(of: "\"", with: "")
    }
}
