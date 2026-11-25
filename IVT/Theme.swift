import SwiftUI
import UIKit

/// Apple-Look: Systemfarben, Systemschrift, abgerundete Karten.
/// Keine eigenen Markenfarben, damit sich die App wie iOS anfuehlt.
enum Stil {
    static let eckradius: CGFloat = 12
    static let kachelRadius: CGFloat = 16
    static let abstand: CGFloat = 16

    static let flaeche = Color(.secondarySystemGroupedBackground)
    static let hintergrund = Color(.systemGroupedBackground)
    static let trenner = Color(.separator)
}

/// Karte im Stil der iOS-Einstellungen
struct Karte<Inhalt: View>: View {
    var titel: String?
    var symbol: String?
    @ViewBuilder var inhalt: Inhalt

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let titel {
                HStack(spacing: 6) {
                    if let symbol {
                        Image(systemName: symbol)
                            .font(.footnote.weight(.semibold))
                    }
                    Text(titel)
                        .font(.footnote.weight(.semibold))
                        .textCase(.uppercase)
                        .kerning(0.4)
                }
                .foregroundStyle(.secondary)
            }
            inhalt
        }
        .padding(Stil.abstand)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Stil.flaeche, in: RoundedRectangle(cornerRadius: Stil.kachelRadius, style: .continuous))
    }
}

/// Grosse Zahl mit Beschriftung, fuer das Dashboard
struct Kennzahl: View {
    var wert: String
    var beschriftung: String
    var symbol: String?
    var farbe: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(beschriftung)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(wert)
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .foregroundStyle(farbe)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Zeile mit Symbol links, wie in den iOS-Einstellungen
struct Zeile: View {
    var symbol: String
    var farbe: Color
    var titel: String
    var wert: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(farbe, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            Text(titel)
            Spacer()
            if let wert {
                Text(wert)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }
}

// MARK: - Formatierung

extension TimeInterval {
    /// 8:30 statt 8,5 h
    var alsStundenMinuten: String {
        let gesamt = Int(abs(self).rounded())
        let s = gesamt / 3600
        let m = (gesamt % 3600) / 60
        let vorzeichen = self < -30 ? "-" : ""
        return String(format: "%@%d:%02d", vorzeichen, s, m)
    }

    /// Mit Pluszeichen, fuer Ueberstunden
    var alsSaldo: String {
        let text = alsStundenMinuten
        if self > 30 { return "+" + text }
        return text
    }

    var alsMinuten: String {
        let m = Int(abs(self).rounded()) / 60
        return "\(m) min"
    }
}

extension Date {
    var uhrzeit: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "HH:mm"
        return f.string(from: self)
    }

    var datumKurz: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "dd.MM.yyyy"
        return f.string(from: self)
    }

    var datumUndZeit: String { "\(datumKurz), \(uhrzeit)" }

    var wochentag: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "EEEE"
        return f.string(from: self)
    }
}

// MARK: - Zahlenfeld

/// Zahl zum Antippen: oeffnet den Ziffernblock, alter Wert ist markiert
/// und wird beim Tippen ersetzt. Plus/Minus bleiben daneben.
struct Zahlenfeld: View {
    @Binding var wert: Int
    var bereich: ClosedRange<Int> = 0...200
    @FocusState private var fokus: Bool
    @State private var text = ""

    var body: some View {
        TextField("0", text: $text)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(.system(.title3, design: .rounded, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(wert == 0 && !fokus ? Color.secondary : Color.primary)
            .frame(width: 56, height: 36)
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .focused($fokus)
            .onAppear { text = "\(wert)" }
            .onChange(of: wert) { if !fokus { text = "\(wert)" } }
            .onChange(of: text) {
                let ziffern = text.filter(\.isNumber)
                if ziffern != text { text = ziffern; return }
                let zahl = min(bereich.upperBound, max(bereich.lowerBound, Int(ziffern) ?? 0))
                if zahl != wert { wert = zahl }
            }
            .onChange(of: fokus) {
                if fokus {
                    // Alles markieren, damit die neue Zahl die alte ersetzt
                    DispatchQueue.main.async {
                        UIApplication.shared.sendAction(#selector(UIResponder.selectAll(_:)), to: nil, from: nil, for: nil)
                    }
                } else {
                    text = "\(wert)"
                }
            }
            .accessibilityLabel("Anzahl")
    }
}

extension View {
    /// "Fertig"-Knopf über dem Ziffernblock
    func zifferntastaturFertig() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Fertig") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .fontWeight(.semibold)
            }
        }
    }
}
