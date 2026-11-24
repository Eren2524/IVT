import UIKit

/// Druckfertiges A4-PDF aus dem Vorlagentext (einfaches Markdown).
enum DokumentPDF {

    static func erstelle(text: String, titel: String) -> Data {
        let seite = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        let rand: CGFloat = 54
        let breite = seite.width - 2 * rand
        let unten = seite.height - rand - 24

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [kCGPDFContextTitle as String: titel,
                               kCGPDFContextCreator as String: "IVT"]
        let renderer = UIGraphicsPDFRenderer(bounds: seite, format: format)

        return renderer.pdfData { ctx in
            var y: CGFloat = rand
            var nummer = 0

            func neueSeite() {
                ctx.beginPage()
                nummer += 1
                y = rand
                let fuss = NSAttributedString(string: "\(titel) · Seite \(nummer)", attributes: [
                    .font: UIFont.systemFont(ofSize: 8),
                    .foregroundColor: UIColor.gray
                ])
                fuss.draw(at: CGPoint(x: rand, y: seite.height - rand + 6))
            }

            func zeichne(_ a: NSAttributedString, einzug: CGFloat = 0, davor: CGFloat = 0, danach: CGFloat = 4) {
                let w = breite - einzug
                let h = ceil(a.boundingRect(with: CGSize(width: w, height: .greatestFiniteMagnitude),
                                            options: [.usesLineFragmentOrigin, .usesFontLeading],
                                            context: nil).height)
                if y + davor + h > unten { neueSeite() } else { y += davor }
                a.draw(with: CGRect(x: rand + einzug, y: y, width: w, height: h),
                       options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
                y += h + danach
            }

            neueSeite()

            for rohzeile in text.components(separatedBy: "\n") {
                let zeile = rohzeile.trimmingCharacters(in: .whitespaces)
                if zeile.isEmpty { y += 6; continue }

                if zeile.hasPrefix("## ") {
                    zeichne(fett(String(zeile.dropFirst(3)), groesse: 13.5), davor: 10, danach: 5)
                } else if zeile.hasPrefix("# ") {
                    zeichne(fett(String(zeile.dropFirst(2)), groesse: 20), danach: 8)
                } else if zeile.hasPrefix("- ") || zeile.hasPrefix("• ") {
                    zeichne(normal("•  " + String(zeile.dropFirst(2))), einzug: 10, danach: 3)
                } else if zeile.hasPrefix("☐ ") {
                    zeichne(normal("☐  " + String(zeile.dropFirst(2)), groesse: 11.5), einzug: 4, danach: 6)
                } else if let r = zeile.range(of: "^\\d+[.)] ", options: .regularExpression) {
                    let nr = String(zeile[r]).trimmingCharacters(in: .whitespaces)
                    zeichne(normal(nr + "  " + String(zeile[r.upperBound...])), einzug: 4, danach: 4)
                } else if zeile.contains(":"), zeile.count < 70,
                          ["Dokumentart", "Bereich", "Erstellt von", "Stand", "Version"]
                            .contains(where: { zeile.hasPrefix($0 + ":") }) {
                    zeichne(normal(zeile, groesse: 9.5, farbe: .darkGray), danach: 1)
                } else {
                    zeichne(normal(zeile))
                }
            }
        }
    }

    private static func fett(_ s: String, groesse: CGFloat) -> NSAttributedString {
        NSAttributedString(string: ohneSterne(s), attributes: [
            .font: UIFont.systemFont(ofSize: groesse, weight: .bold),
            .foregroundColor: UIColor.black
        ])
    }

    /// Text mit **fett** Stellen
    private static func normal(_ s: String, groesse: CGFloat = 11, farbe: UIColor = .black) -> NSAttributedString {
        let stil = NSMutableParagraphStyle()
        stil.lineSpacing = 2
        let basis: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: groesse), .foregroundColor: farbe, .paragraphStyle: stil
        ]
        let ergebnis = NSMutableAttributedString()
        let teile = s.components(separatedBy: "**")
        for (i, teil) in teile.enumerated() {
            var a = basis
            if i % 2 == 1 { a[.font] = UIFont.systemFont(ofSize: groesse, weight: .semibold) }
            // Luecken farbig hervorheben
            if teil.contains("[ERGÄNZEN") || teil.contains("[PRÜFEN") { a[.foregroundColor] = UIColor.systemRed }
            ergebnis.append(NSAttributedString(string: teil, attributes: a))
        }
        return ergebnis
    }

    private static func ohneSterne(_ s: String) -> String {
        s.replacingOccurrences(of: "**", with: "")
    }
}
