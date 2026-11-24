import Foundation
import Security

/// API-Schluessel sicher im Schluesselbund, nur auf diesem iPhone.
enum Schluesselbund {
    private static let dienst = "de.enriquediaz.ivt.claude"
    private static let konto = "api"

    static func lies() -> String? {
        let frage: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: dienst,
            kSecAttrAccount as String: konto,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var ergebnis: AnyObject?
        guard SecItemCopyMatching(frage as CFDictionary, &ergebnis) == errSecSuccess,
              let daten = ergebnis as? Data else { return nil }
        return String(data: daten, encoding: .utf8)
    }

    @discardableResult
    static func speichere(_ schluessel: String) -> Bool {
        loesche()
        let eintrag: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: dienst,
            kSecAttrAccount as String: konto,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: Data(schluessel.utf8)
        ]
        return SecItemAdd(eintrag as CFDictionary, nil) == errSecSuccess
    }

    static func loesche() {
        let frage: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: dienst,
            kSecAttrAccount as String: konto
        ]
        SecItemDelete(frage as CFDictionary)
    }

    static var vorhanden: Bool { lies() != nil }
}

enum Claudefehler: LocalizedError {
    case keinSchluessel
    case abgelehnt(Int, String)
    case leer
    case netz(String)

    var errorDescription: String? {
        switch self {
        case .keinSchluessel:
            return "Kein API-Schlüssel hinterlegt. In Einstellungen > Vorlagen eintragen."
        case .abgelehnt(let code, let text):
            switch code {
            case 401: return "API-Schlüssel ungültig (401)."
            case 402, 403: return "Kein Zugriff oder kein Guthaben (\(code)). Guthaben in der Claude-Konsole prüfen."
            case 429: return "Zu viele Anfragen (429). Kurz warten und nochmal."
            case 529, 503: return "Claude ist gerade überlastet (\(code)). Gleich nochmal versuchen."
            default: return "Fehler \(code): \(text.prefix(200))"
            }
        case .leer: return "Claude hat keinen Text zurückgegeben."
        case .netz(let t): return "Keine Verbindung: \(t)"
        }
    }
}

/// Schickt das Diktat an die Claude-API (Messages) und bekommt das Dokument zurueck.
/// Passiert nur, wenn Enrique ausdruecklich auf "Mit Claude umschreiben" tippt.
enum Claudedienst {

    private static let adresse = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let versionen = ["2026-10-21", "2023-06-01"]

    private struct Anfrage: Encodable {
        struct Botschaft: Encodable {
            var role: String
            var content: String
        }
        var model: String
        var max_tokens: Int
        var system: String
        var messages: [Botschaft]
    }

    private struct Antwort: Decodable {
        struct Block: Decodable {
            var type: String
            var text: String?
        }
        var content: [Block]
    }

    static func schreibe(system: String, nutzer: String, modell: String,
                         maxTokens: Int = 6000) async throws -> String {
        guard let schluessel = Schluesselbund.lies(), !schluessel.isEmpty else {
            throw Claudefehler.keinSchluessel
        }
        let koerper = try JSONEncoder().encode(Anfrage(
            model: modell, max_tokens: maxTokens, system: system,
            messages: [.init(role: "user", content: nutzer)]))

        var letzterFehler: Error = Claudefehler.leer
        for version in versionen {
            var r = URLRequest(url: adresse, timeoutInterval: 180)
            r.httpMethod = "POST"
            r.setValue(schluessel, forHTTPHeaderField: "x-api-key")
            r.setValue(version, forHTTPHeaderField: "anthropic-version")
            r.setValue("application/json", forHTTPHeaderField: "content-type")
            r.httpBody = koerper

            let daten: Data
            let antwort: URLResponse
            do {
                (daten, antwort) = try await URLSession.shared.data(for: r)
            } catch {
                throw Claudefehler.netz(error.localizedDescription)
            }
            let code = (antwort as? HTTPURLResponse)?.statusCode ?? 0
            if code == 200 {
                let a = try JSONDecoder().decode(Antwort.self, from: daten)
                let text = a.content.filter { $0.type == "text" }.compactMap(\.text).joined()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { throw Claudefehler.leer }
                return text
            }
            let roh = String(data: daten, encoding: .utf8) ?? ""
            letzterFehler = Claudefehler.abgelehnt(code, roh)
            // Nur bei einem Versionsproblem die naechste Version probieren
            guard code == 400, roh.contains("anthropic-version") else { break }
        }
        throw letzterFehler
    }
}
