import Foundation
import BackgroundTasks
import UserNotifications

/// Eine Meldung aus einem oeffentlichen RSS-Feed.
struct Nachricht: Codable, Identifiable, Hashable {
    var id: String          // Link, sonst Titel
    var titel: String
    var link: String
    var datum: Date?
    var quelle: String
    var text: String
}

struct Nachrichtenquelle: Identifiable, Hashable {
    var name: String
    var adresse: String
    var id: String { adresse }
}

/// Holt Logistik-News aus oeffentlichen Feeds. Es wird nur gelesen,
/// nichts ueber Enrique wird irgendwohin geschickt.
@MainActor
final class Nachrichtendienst: ObservableObject {

    static let shared = Nachrichtendienst()
    nonisolated static let aufgabeID = "de.enriquediaz.ivt.news"

    static let standardQuellen: [Nachrichtenquelle] = [
        .init(name: "eurotransport Logistik", adresse: "https://www.eurotransport.de/rss/logistik"),
        .init(name: "eurotransport Fahrer & Recht", adresse: "https://www.eurotransport.de/rss/fahrer"),
        .init(name: "Logistik Heute", adresse: "https://logistik-heute.de/rss.xml"),
        .init(name: "transport", adresse: "https://transport-online.de/rss.xml"),
        .init(name: "Logistik-Nachrichten", adresse: "https://logistiknachrichten.de/feed")
    ]

    /// Woerter, an denen Recht, Gesetze und Vorschriften erkannt werden
    nonisolated static let rechtsWoerter = [
        "gesetz", "verordnung", "pflicht", "bußgeld", "bussgeld", "maut", "lenkzeit",
        "lenk- und ruhe", "ruhezeit", "fahrverbot", "richtlinie", "novelle", "vorschrift",
        "bundesrat", "bundestag", "ministerium", "eu-kommission", "eu-parlament", "mindestlohn",
        "arbeitsschutz", "dguv", "bg verkehr", "adr", "gefahrgut", "führerschein",
        "berufskraftfahrer", "tachograph", "kabotage", "co2", "ab 2027", "ab januar", "stvo",
        "kontrolle", "balm", "zoll", "steuer", "urteil", "gericht"
    ]

    @Published private(set) var nachrichten: [Nachricht] = []
    @Published private(set) var stand: Date?
    @Published private(set) var laedt = false
    @Published private(set) var fehlerQuellen: [String] = []
    @Published private(set) var gemerkt: Set<String>
    @Published private(set) var gelesen: Set<String>

    private let d = UserDefaults.standard

    private init() {
        gemerkt = Set(d.stringArray(forKey: "newsGemerkt") ?? [])
        gelesen = Set(d.stringArray(forKey: "newsGelesen") ?? [])
        if let daten = try? Data(contentsOf: Self.zwischenspeicher),
           let alt = try? JSONDecoder().decode(Zwischenstand.self, from: daten) {
            nachrichten = alt.nachrichten
            stand = alt.stand
        }
    }

    private struct Zwischenstand: Codable {
        var stand: Date
        var nachrichten: [Nachricht]
    }

    private static var zwischenspeicher: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("news.json")
    }

    // MARK: Quellen

    func aktiveQuellen(_ e: Einstellungen) -> [Nachrichtenquelle] {
        let eigene = e.newsEigeneQuellen.map { adresse in
            Nachrichtenquelle(name: URL(string: adresse)?.host ?? adresse, adresse: adresse)
        }
        return (Self.standardQuellen + eigene).filter { !e.newsQuellenAus.contains($0.adresse) }
    }

    // MARK: Laden

    /// Alle aktiven Feeds parallel holen. Gibt neue Stichwort-Treffer zurueck.
    @discardableResult
    func aktualisieren(_ e: Einstellungen, melden: Bool = true) async -> Int {
        guard !laedt else { return 0 }
        laedt = true
        defer { laedt = false }

        let quellen = aktiveQuellen(e)
        var alle: [Nachricht] = []
        var kaputt: [String] = []

        await withTaskGroup(of: (String, [Nachricht]?).self) { gruppe in
            for q in quellen {
                gruppe.addTask { (q.name, await Self.hole(q)) }
            }
            for await (name, liste) in gruppe {
                if let liste { alle += liste } else { kaputt.append(name) }
            }
        }

        fehlerQuellen = kaputt.sorted()
        guard !alle.isEmpty else { return 0 }

        // Doppelte raus (gleicher Link oder gleicher Titel)
        var gesehen = Set<String>()
        var sauber: [Nachricht] = []
        for n in alle.sorted(by: { ($0.datum ?? .distantPast) > ($1.datum ?? .distantPast) }) {
            let schluessel = n.titel.lowercased()
            if gesehen.contains(n.id) || gesehen.contains(schluessel) { continue }
            gesehen.insert(n.id); gesehen.insert(schluessel)
            sauber.append(n)
        }
        // Zwei Wochen reichen
        let grenze = Date().addingTimeInterval(-14 * 86_400)
        nachrichten = Array(sauber.filter { ($0.datum ?? Date()) >= grenze }.prefix(300))
        stand = Date()

        if let daten = try? JSONEncoder().encode(Zwischenstand(stand: Date(), nachrichten: nachrichten)) {
            try? daten.write(to: Self.zwischenspeicher, options: .atomic)
        }

        let neu = melden && e.newsAlarmAktiv ? meldeTreffer(e.newsStichworte) : 0
        return neu
    }

    nonisolated private static func hole(_ q: Nachrichtenquelle) async -> [Nachricht]? {
        guard let url = URL(string: q.adresse) else { return nil }
        var anfrage = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        anfrage.setValue("IVT/1.0 (iPhone; persoenlicher Feedleser)", forHTTPHeaderField: "User-Agent")
        do {
            let (daten, antwort) = try await URLSession.shared.data(for: anfrage)
            if let h = antwort as? HTTPURLResponse, !(200..<300).contains(h.statusCode) { return nil }
            let liste = Feedleser.lies(daten, quelle: q.name)
            return liste.isEmpty ? nil : liste
        } catch {
            return nil
        }
    }

    // MARK: Stichworte

    nonisolated static func treffer(_ n: Nachricht, _ stichworte: [String]) -> [String] {
        let inhalt = (n.titel + " " + n.text)
        return stichworte.filter { w in
            let wort = w.trimmingCharacters(in: .whitespaces)
            return !wort.isEmpty && inhalt.range(of: wort, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    nonisolated static func istRecht(_ n: Nachricht) -> Bool {
        let inhalt = (n.titel + " " + n.text).lowercased()
        return rechtsWoerter.contains { inhalt.contains($0) }
    }

    /// Mitteilung fuer Treffer, die noch nie gemeldet wurden
    private func meldeTreffer(_ stichworte: [String]) -> Int {
        var gemeldet = Set(d.stringArray(forKey: "newsGemeldet") ?? [])
        let erstesMal = gemeldet.isEmpty
        let neu = nachrichten.filter { !gemeldet.contains($0.id) && !Self.treffer($0, stichworte).isEmpty }
        for n in nachrichten { gemeldet.insert(n.id) }
        // Liste klein halten
        d.set(Array(gemeldet.suffix(1500)), forKey: "newsGemeldet")
        // Beim allerersten Laden nicht mit alten Meldungen zuschuetten
        guard !erstesMal, !neu.isEmpty else { return 0 }

        let inhalt = UNMutableNotificationContent()
        if neu.count == 1, let n = neu.first {
            inhalt.title = "News: " + Self.treffer(n, stichworte).joined(separator: ", ")
            inhalt.body = n.titel
        } else {
            let woerter = Set(neu.flatMap { Self.treffer($0, stichworte) }).sorted().prefix(4)
            inhalt.title = "\(neu.count) neue Meldungen zu \(woerter.joined(separator: ", "))"
            inhalt.body = neu.prefix(3).map(\.titel).joined(separator: "\n")
        }
        inhalt.sound = .default
        inhalt.userInfo = ["ziel": "news"]
        let anfrage = UNNotificationRequest(identifier: "news-\(Int(Date().timeIntervalSince1970))",
                                            content: inhalt, trigger: nil)
        UNUserNotificationCenter.current().add(anfrage)
        return neu.count
    }

    // MARK: Merken / gelesen

    func merken(_ n: Nachricht) {
        if gemerkt.contains(n.id) { gemerkt.remove(n.id) } else { gemerkt.insert(n.id) }
        d.set(Array(gemerkt), forKey: "newsGemerkt")
    }

    func gelesen(_ n: Nachricht) {
        gelesen.insert(n.id)
        d.set(Array(gelesen.suffix(2000)), forKey: "newsGelesen")
    }

    // MARK: Hintergrund

    /// Naechsten Hintergrundabruf anmelden. iOS entscheidet, wann genau.
    nonisolated static func hintergrundPlanen() {
        let r = BGAppRefreshTaskRequest(identifier: aufgabeID)
        r.earliestBeginDate = Date(timeIntervalSinceNow: 2 * 3600)
        try? BGTaskScheduler.shared.submit(r)
    }

    static func hintergrundAbruf() async {
        hintergrundPlanen()
        await shared.aktualisieren(Einstellungen.shared)
    }
}

// MARK: - RSS / Atom lesen

final class Feedleser: NSObject, XMLParserDelegate {

    private var quelle = ""
    private var liste: [Nachricht] = []
    private var imEintrag = false
    private var feld = ""
    private var puffer = ""
    private var titel = "", link = "", datumText = "", text = ""

    static func lies(_ daten: Data, quelle: String) -> [Nachricht] {
        let leser = Feedleser()
        leser.quelle = quelle
        let p = XMLParser(data: daten)
        p.delegate = leser
        p.shouldResolveExternalEntities = false
        p.parse()
        return leser.liste
    }

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attr: [String: String] = [:]) {
        let n = name.lowercased()
        if n == "item" || n == "entry" {
            imEintrag = true
            titel = ""; link = ""; datumText = ""; text = ""
            return
        }
        guard imEintrag else { return }
        // Atom: <link href="..."/>
        if n == "link", let href = attr["href"], link.isEmpty,
           attr["rel"] == nil || attr["rel"] == "alternate" {
            link = href
        }
        feld = n
        puffer = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if imEintrag { puffer += string }
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if imEintrag, let s = String(data: CDATABlock, encoding: .utf8) { puffer += s }
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?,
                qualifiedName qName: String?) {
        let n = name.lowercased()
        if n == "item" || n == "entry" {
            imEintrag = false
            let t = Self.sauber(titel)
            guard !t.isEmpty else { return }
            let l = link.trimmingCharacters(in: .whitespacesAndNewlines)
            liste.append(Nachricht(id: l.isEmpty ? t : l, titel: t, link: l,
                                   datum: Self.datum(datumText), quelle: quelle,
                                   text: String(Self.sauber(text).prefix(400))))
            return
        }
        guard imEintrag else { return }
        let wert = puffer
        switch n {
        case "title": titel = wert
        case "link": if link.isEmpty { link = wert }
        case "pubdate", "dc:date", "published", "updated", "date":
            if datumText.isEmpty { datumText = wert }
        case "description", "summary", "content":
            if text.isEmpty { text = wert }
        default: break
        }
        puffer = ""
    }

    // HTML-Reste und Entities entfernen
    static func sauber(_ s: String) -> String {
        var t = s.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        let ersatz = ["&amp;": "&", "&quot;": "\"", "&#39;": "'", "&apos;": "'", "&lt;": "<",
                      "&gt;": ">", "&nbsp;": " ", "&#8211;": "–", "&#8222;": "„", "&#8220;": "“",
                      "&#8217;": "’", "&#8230;": "…", "&hellip;": "…", "&ndash;": "–"]
        for (a, b) in ersatz { t = t.replacingOccurrences(of: a, with: b) }
        t = t.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func datum(_ s: String) -> Date? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        if let d = iso.date(from: t) { return d }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        for muster in ["EEE, dd MMM yyyy HH:mm:ss Z", "EEE, dd MMM yyyy HH:mm:ss zzz",
                       "EEE, d MMM yyyy HH:mm:ss Z", "dd MMM yyyy HH:mm:ss Z",
                       "EEE, dd MMM yy HH:mm:ss Z", "yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd"] {
            f.dateFormat = muster
            if let d = f.date(from: t) { return d }
        }
        return nil
    }
}
