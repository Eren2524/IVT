import Foundation

/// Enriques feste Arbeitszeiten bei IEB.
///
///   Mo-Do  6:30 - 15:40   =  9:10 anwesend
///          Pausen 9:30-9:40 (10 min) und 12:30-13:00 (30 min)
///          Soll  8:30
///
///   Fr     6:30 - 12:40   =  6:10 anwesend
///          Pause 9:30-9:40 (10 min)
///          Soll  6:00
///
///   Woche  4 x 8:30 + 6:00 = 40:00
///
/// Alle Werte sind in den Einstellungen ueberschreibbar; das hier ist der
/// Auslieferungszustand.
struct Arbeitsplan {

    struct Zeitfenster {
        var startStunde: Int
        var startMinute: Int
        var endeStunde: Int
        var endeMinute: Int

        var startMinuten: Int { startStunde * 60 + startMinute }
        var endeMinuten: Int { endeStunde * 60 + endeMinute }
        var dauerMinuten: Int { endeMinuten - startMinuten }
    }

    struct Tagesplan {
        var arbeit: Zeitfenster
        var pausen: [(art: PausenArt, fenster: Zeitfenster)]

        var pausenMinuten: Int {
            pausen.reduce(0) { $0 + $1.fenster.dauerMinuten }
        }

        /// Bezahlte Soll-Zeit in Minuten
        var sollMinuten: Int {
            max(0, arbeit.dauerMinuten - pausenMinuten)
        }
    }

    static let fruehstueck = Zeitfenster(startStunde: 9, startMinute: 30,
                                        endeStunde: 9, endeMinute: 40)
    static let mittag = Zeitfenster(startStunde: 12, startMinute: 30,
                                    endeStunde: 13, endeMinute: 0)

    /// Montag bis Donnerstag
    static let langerTag = Tagesplan(
        arbeit: Zeitfenster(startStunde: 6, startMinute: 30,
                            endeStunde: 15, endeMinute: 40),
        pausen: [(.fruehstueck, fruehstueck), (.mittag, mittag)]
    )

    /// Freitag
    static let freitag = Tagesplan(
        arbeit: Zeitfenster(startStunde: 6, startMinute: 30,
                            endeStunde: 12, endeMinute: 40),
        pausen: [(.fruehstueck, fruehstueck)]
    )

    /// Plan fuer ein Datum, nil am Wochenende und an NRW-Feiertagen.
    static func plan(am datum: Date, kalender: Calendar = .current) -> Tagesplan? {
        // Gesetzlicher Feiertag in NRW: frei, kein Soll
        if Feiertage.istFeiertag(datum, kalender: kalender) { return nil }
        // Calendar: 1 = Sonntag, 2 = Montag ... 6 = Freitag, 7 = Samstag
        switch kalender.component(.weekday, from: datum) {
        case 2, 3, 4, 5: return langerTag
        case 6:          return freitag
        default:         return nil
        }
    }

    /// Soll-Arbeitszeit als TimeInterval, 0 am Wochenende.
    static func soll(am datum: Date, kalender: Calendar = .current) -> TimeInterval {
        guard let p = plan(am: datum, kalender: kalender) else { return 0 }
        return TimeInterval(p.sollMinuten * 60)
    }

    /// Soll der ganzen Woche, in der das Datum liegt.
    static func sollWoche(um datum: Date, kalender: Calendar = .current) -> TimeInterval {
        guard let woche = kalender.dateInterval(of: .weekOfYear, for: datum) else { return 0 }
        var summe: TimeInterval = 0
        var tag = woche.start
        while tag < woche.end {
            summe += soll(am: tag, kalender: kalender)
            tag = kalender.date(byAdding: .day, value: 1, to: tag) ?? woche.end
        }
        return summe
    }

    /// Die konkreten Pausenzeitpunkte fuer ein Datum.
    static func pausenZeiten(am datum: Date,
                             kalender: Calendar = .current) -> [(art: PausenArt, von: Date, bis: Date)] {
        guard let p = plan(am: datum, kalender: kalender) else { return [] }
        let tag = kalender.startOfDay(for: datum)
        return p.pausen.compactMap { eintrag in
            guard let von = kalender.date(byAdding: .minute,
                                          value: eintrag.fenster.startMinuten, to: tag),
                  let bis = kalender.date(byAdding: .minute,
                                          value: eintrag.fenster.endeMinuten, to: tag)
            else { return nil }
            return (eintrag.art, von, bis)
        }
    }

    /// Planmaessiger Feierabend fuer ein Datum.
    static func feierabend(am datum: Date, kalender: Calendar = .current) -> Date? {
        guard let p = plan(am: datum, kalender: kalender) else { return nil }
        return kalender.date(byAdding: .minute,
                             value: p.arbeit.endeMinuten,
                             to: kalender.startOfDay(for: datum))
    }

    /// Planmaessiger Arbeitsbeginn fuer ein Datum.
    static func arbeitsbeginn(am datum: Date, kalender: Calendar = .current) -> Date? {
        guard let p = plan(am: datum, kalender: kalender) else { return nil }
        return kalender.date(byAdding: .minute,
                             value: p.arbeit.startMinuten,
                             to: kalender.startOfDay(for: datum))
    }

    static var istArbeitstagHeute: Bool { plan(am: Date()) != nil }
}
