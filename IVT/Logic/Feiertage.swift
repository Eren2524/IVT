import Foundation

/// Gesetzliche Feiertage in Nordrhein-Westfalen.
/// An diesen Tagen gibt es kein Soll; wer trotzdem arbeitet, sammelt Plus.
enum Feiertage {

    struct Feiertag: Identifiable {
        var name: String
        var datum: Date
        var id: Date { datum }
    }

    /// Ostersonntag nach der Gaussschen Osterformel (gregorianisch).
    static func ostersonntag(_ jahr: Int, kalender: Calendar = .current) -> Date? {
        let a = jahr % 19
        let b = jahr / 100
        let c = jahr % 100
        let d = b / 4
        let e = b % 4
        let f = (b + 8) / 25
        let g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4
        let k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let monat = (h + l - 7 * m + 114) / 31
        let tag = ((h + l - 7 * m + 114) % 31) + 1
        return kalender.date(from: DateComponents(year: jahr, month: monat, day: tag))
    }

    static func liste(_ jahr: Int, kalender: Calendar = .current) -> [Feiertag] {
        var l: [Feiertag] = []
        func fest(_ name: String, _ monat: Int, _ tag: Int) {
            if let d = kalender.date(from: DateComponents(year: jahr, month: monat, day: tag)) {
                l.append(Feiertag(name: name, datum: d))
            }
        }
        fest("Neujahr", 1, 1)
        fest("Tag der Arbeit", 5, 1)
        fest("Tag der Deutschen Einheit", 10, 3)
        fest("Allerheiligen", 11, 1)
        fest("1. Weihnachtstag", 12, 25)
        fest("2. Weihnachtstag", 12, 26)

        if let ostern = ostersonntag(jahr, kalender: kalender) {
            let beweglich: [(String, Int)] = [
                ("Karfreitag", -2), ("Ostermontag", 1), ("Christi Himmelfahrt", 39),
                ("Pfingstmontag", 50), ("Fronleichnam", 60)
            ]
            for (name, abstand) in beweglich {
                if let d = kalender.date(byAdding: .day, value: abstand, to: ostern) {
                    l.append(Feiertag(name: name, datum: d))
                }
            }
        }
        return l.sorted { $0.datum < $1.datum }
    }

    /// Name des Feiertags an diesem Tag, sonst nil.
    static func name(am datum: Date, kalender: Calendar = .current) -> String? {
        let jahr = kalender.component(.year, from: datum)
        return liste(jahr, kalender: kalender)
            .first { kalender.isDate($0.datum, inSameDayAs: datum) }?.name
    }

    static func istFeiertag(_ datum: Date, kalender: Calendar = .current) -> Bool {
        name(am: datum, kalender: kalender) != nil
    }

    /// Naechster Feiertag ab heute (einschliesslich).
    static func naechster(ab datum: Date = Date(), kalender: Calendar = .current) -> Feiertag? {
        let heute = kalender.startOfDay(for: datum)
        let jahr = kalender.component(.year, from: datum)
        return (liste(jahr, kalender: kalender) + liste(jahr + 1, kalender: kalender))
            .first { $0.datum >= heute }
    }
}
