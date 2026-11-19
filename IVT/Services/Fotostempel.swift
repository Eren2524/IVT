import UIKit
import CoreLocation

/// Brennt Datum, Uhrzeit und Ort unten ins Bild.
/// Ein Reklamationsfoto ohne Zeitstempel ist im Streitfall wenig wert,
/// darum steht es im Bild selbst und nicht nur in den Metadaten.
enum Fotostempel {

    struct Angaben {
        var zeit: Date
        var ortText: String
        var koordinate: CLLocationCoordinate2D?
        var zusatz: String?
    }

    static func stempeln(_ bild: UIImage, mit angaben: Angaben) -> UIImage {
        let groesse = bild.size
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = bild.scale
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: groesse, format: format)

        return renderer.image { ctx in
            bild.draw(in: CGRect(origin: .zero, size: groesse))

            var zeilen: [String] = [angaben.zeit.datumUndZeit]
            if !angaben.ortText.isEmpty { zeilen.append(angaben.ortText) }
            if let k = angaben.koordinate {
                zeilen.append(String(format: "%.5f, %.5f", k.latitude, k.longitude))
            }
            if let z = angaben.zusatz, !z.isEmpty { zeilen.append(z) }

            // Schriftgroesse an die Bildbreite koppeln, damit der Stempel
            // auf einem 12-MP-Foto genauso lesbar ist wie auf einem kleinen.
            let schriftgroesse = max(14, groesse.width * 0.028)
            let schrift = UIFont.systemFont(ofSize: schriftgroesse, weight: .semibold)
            let rand = groesse.width * 0.025
            let zeilenhoehe = schriftgroesse * 1.35

            let bloeckeHoehe = zeilenhoehe * CGFloat(zeilen.count) + rand * 1.2

            // Dunkler Balken mit Verlauf, damit helle und dunkle Fotos
            // beide lesbar bleiben
            let balken = CGRect(x: 0,
                                y: groesse.height - bloeckeHoehe,
                                width: groesse.width,
                                height: bloeckeHoehe)
            let c = ctx.cgContext
            c.saveGState()
            c.clip(to: balken)
            if let verlauf = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [UIColor(white: 0, alpha: 0.0).cgColor,
                         UIColor(white: 0, alpha: 0.62).cgColor] as CFArray,
                locations: [0, 1]
            ) {
                c.drawLinearGradient(verlauf,
                                     start: CGPoint(x: 0, y: balken.minY),
                                     end: CGPoint(x: 0, y: balken.maxY),
                                     options: [])
            }
            c.restoreGState()

            let stil = NSMutableParagraphStyle()
            stil.alignment = .left
            stil.lineBreakMode = .byTruncatingTail

            let attribute: [NSAttributedString.Key: Any] = [
                .font: schrift,
                .foregroundColor: UIColor.white,
                .paragraphStyle: stil,
                .shadow: {
                    let s = NSShadow()
                    s.shadowColor = UIColor(white: 0, alpha: 0.85)
                    s.shadowBlurRadius = schriftgroesse * 0.22
                    s.shadowOffset = CGSize(width: 0, height: 1)
                    return s
                }()
            ]

            var y = balken.minY + rand * 0.6
            for zeile in zeilen {
                (zeile as NSString).draw(
                    in: CGRect(x: rand, y: y,
                               width: groesse.width - rand * 2, height: zeilenhoehe),
                    withAttributes: attribute
                )
                y += zeilenhoehe
            }
        }
    }

    /// Fuer die Ablage verkleinern: ein 12-MP-Foto braucht keine
    /// 4 MB in der Datenbank, 2000 px lange Kante reichen fuer Reklamationen.
    static func verkleinern(_ bild: UIImage, maxKante: CGFloat = 2000) -> UIImage {
        let lang = max(bild.size.width, bild.size.height)
        guard lang > maxKante else { return bild }
        let faktor = maxKante / lang
        let neu = CGSize(width: bild.size.width * faktor,
                         height: bild.size.height * faktor)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: neu, format: format).image { _ in
            bild.draw(in: CGRect(origin: .zero, size: neu))
        }
    }

    static func jpeg(_ bild: UIImage, guete: CGFloat = 0.82) -> Data? {
        bild.jpegData(compressionQuality: guete)
    }
}
