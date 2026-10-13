import Foundation

/// Bedienungshilfe für `/help`.
public enum Help {
    public static func markdown(config: LexConfig) -> String {
        """
        # Lex – Bedienung

        Tippen, **ENTER** – Lex übersetzt oder schlägt nach. Ohne Präfix entscheidet Jev, was gemeint ist.

        ## Eingaben
        - `the dog is barking` – fremdsprachiger Text → Übersetzung ins Deutsche mit Anmerkungen
        - `serendipity` – fremdes Wort → Wörterbucheintrag
        - `Gewaltenteilung`, `tat twam asi` – Begriff → kurzer Abriss
        - `gewunken oder gewinkt` – Sprachfrage → Antwort mit Regel
        - `wie hoch ist die Zugspitze` – Sachfrage; Aktuelles wird im Web gesucht

        ## Präfixe
        - `en: ich gehe nach Hause` – ins Englische übersetzen (jeder zweibuchstabige Sprachcode: `fr:`, `es:`, `it:` …)
        - `ex: …` – Erklärung erzwingen, wenn sonst nur übersetzt würde

        ## Befehle
        - `/help` – diese Hilfe
        - `/h` – Historie öffnen
        - `/settings` – Einstellungen
        - `/chat claude` · `/chat chatgpt` – wohin „Ausführlich im Chat“ führt (jetzt: \(config.chatService.name))
        - `/key` – OpenRouter-API-Key neu setzen
        - `/q` · `/exit` – Lex beenden

        ## Tasten
        - **\(config.hotkey ?? "cmd+shift+L")** – Lex öffnen (global; holt auch den Fokus zurück)
        - **ESC** – ausblenden (auch wenn ein anderes Fenster den Fokus hat)
        - **⌘↩** – Anfrage ausführlich in \(config.chatService.name) öffnen
        - **⌘⇧C** – Antwort kopieren
        - **⌘Y** – Historie · **⌘,** – Einstellungen
        """
    }
}
