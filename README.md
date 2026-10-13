# Lex – Nachschlagen auf dem Desktop

Lex ist ein kleines Nachschlagewerk für den Mac: Shortcut drücken, etwas eintippen, ENTER – und Lex übersetzt oder erklärt. Wie Spotlight erscheint ein einzeiliges Eingabefeld in der Bildschirmmitte; die Antwort wird direkt darunter eingeblendet, während sie entsteht.

Lex läuft unsichtbar im Hintergrund: kein Dock-Icon, kein Eintrag in der Menüleiste.

```
the dog is barking          → Übersetzung ins Deutsche, mit Anmerkungen zu Wortformen
serendipity                 → Wörterbucheintrag im Webster-Stil
Gewaltenteilung             → kurzer Abriss des Begriffs
tat twam asi                → kurzer Abriss (auch fremdsprachige Begriffe werden erklärt)
gewunken oder gewinkt       → Antwort wie von der Duden-Sprachberatung
wie hoch ist die Zugspitze  → Sachantwort
wer ist aktuell Kanzler     → Sachantwort mit Websuche und Quellen
en: ich gehe nach Hause     → Übersetzung ins Englische
ex: serendipity             → Erklärung erzwingen statt Übersetzung
```

Ist eine Antwort zu knapp, öffnet **⌘↩** die Frage im Browser bei Claude oder ChatGPT – vorformuliert für eine ausführliche Antwort.

## Wie es funktioniert

Lex verteilt die Arbeit auf drei Stufen:

1. **Code** erkennt Präfixe (`en:`, `fr:`, `ex:` …) und Befehle (`/help`, `/h` …). Dafür braucht es keine KI.
2. **[Jev](https://docs.typesafe.ai)** von TypeSafe ordnet alle anderen Eingaben ein: Übersetzung ins Deutsche, fremdes Wort, Begriff, Sprachfrage oder Sachfrage – und ob die Antwort aktuelle Informationen braucht. Jev liefert Kategorie und Wahrscheinlichkeit in gut einer halben Sekunde. Ist Jev unsicher, geht die Anfrage an einen Allzweck-Prompt.
3. **Ein Sprachmodell** schreibt die Antwort – mit einem eigenen Prompt und einem eigenen Modell je Kategorie (Standard: Claude Sonnet; Fragen nach aktuellen Infos an Perplexity Sonar mit Websuche).

Alle Aufrufe laufen über [OpenRouter](https://openrouter.ai) – auch Jev. Es wird also **ein einziger API-Key** gebraucht.

## Voraussetzungen

- macOS 15 oder neuer
- Swift 6 – kommt mit Xcode oder den Command Line Tools (`xcode-select --install`). Xcode selbst muss nicht geöffnet werden; Lex wird komplett im Terminal gebaut.
- Ein [OpenRouter-API-Key](https://openrouter.ai/keys) mit etwas Guthaben

## Installation

```bash
git clone https://github.com/ralfw-vibe-coding/lex-universal-desktop-dictionary.git
cd lex-universal-desktop-dictionary
./build.sh install
```

Das Skript baut Lex, legt `Lex.app` nach `/Applications` und startet die App. Beim ersten Start fragt Lex nach dem OpenRouter-API-Key; einfach einfügen und ENTER drücken.

Danach:

- **⌘⇧L** öffnet Lex (änderbar in den Einstellungen).
- Damit Lex nach jedem Login bereitsteht: `/settings` eintippen und **„Beim Login starten“** einschalten. macOS meldet daraufhin, dass ein Hintergrundobjekt hinzugefügt wurde.

Weitere Varianten von `build.sh`:

| Befehl | Wirkung |
|---|---|
| `./build.sh` | nur bauen, nach `build/Lex.app` |
| `./build.sh install` | bauen, nach `/Applications` kopieren, starten; ein vorhandener Login-Start zeigt danach auf die neue Kopie |
| `./build.sh uninstall` | Login-Start entfernen, Lex beenden und löschen (Einstellungen und Historie bleiben) |

Lex wird lokal gebaut und ad-hoc signiert. Gatekeeper-Warnungen gibt es deshalb nicht.

## Bedienung

### Befehle im Eingabefeld

| Befehl | |
|---|---|
| `/help` | Hilfe mit allen Befehlen und Tasten |
| `/h` | Historie öffnen |
| `/settings` | Einstellungen öffnen |
| `/chat claude` · `/chat chatgpt` | wohin „Ausführlich im Chat“ führt |
| `/key` | OpenRouter-API-Key neu setzen |
| `/q` · `/exit` | Lex beenden |

### Tasten

| Taste | |
|---|---|
| **⌘⇧L** | Lex öffnen; holt auch den Fokus zurück, wenn Lex schon offen ist |
| **ENTER** | nachschlagen |
| **ESC** | ausblenden – auch dann, wenn gerade ein anderes Fenster den Fokus hat |
| **⌘↩** | Frage ausführlich in Claude bzw. ChatGPT öffnen |
| **⌘⇧C** | Antwort kopieren |
| **⌘Y** | Historie |
| **⌘,** | Einstellungen |

### Verhalten des Panels

- Das Panel bleibt stehen, wenn du woanders hinklickst – praktisch zum Abschreiben einer Übersetzung.
- Nach ENTER zeigt eine Statuszeile, was gerade passiert: „Jev ordnet ein …“, dann Kategorie, Modell und Jevs Sicherheit, dazu eine laufende Zeitanzeige.
- Öffnest du Lex kurz nach dem Schließen wieder, steht die letzte Frage samt Antwort noch da. Nach einer längeren Pause (Standard: 60 Sekunden) ist das Panel leer.

### Historie

Jede Anfrage landet in der Historie (`/h` oder ⌘Y): durchsuchbar, mit Antwort, Kategorie, Modell, Jevs Sicherheit und Dauer. Von dort lässt sich jede Frage auch nachträglich ausführlich im Chat stellen.

## Einstellungen

`/settings` öffnet ein Fenster für:

- Start beim Login
- Chat-Dienst für ausführliche Antworten (Claude oder ChatGPT)
- Shortcut zum Öffnen, z. B. `cmd+shift+L`, `ctrl+alt+space`
- Zeit, nach der das Panel geleert wird
- OpenRouter-API-Key
- Modell je Anfrageart – mit Auswahl aus der aktuellen OpenRouter-Modellliste; `typesafe/jev-router` lässt Jev das Modell pro Anfrage wählen
- Jev-Schwellen: Mindest-Sicherheit für die Einordnung und ab wann mit Websuche geantwortet wird
- **Prompts bearbeiten …** – legt die eingebauten Prompts als Markdown-Dateien an und öffnet den Ordner

### Dateien

| Datei | Inhalt |
|---|---|
| `~/.config/lex/config.json` | alle Einstellungen |
| `~/.config/lex/prompts/<kategorie>.md` | eigene Prompts; überschreiben die eingebauten, gelten sofort. Datei löschen → eingebauter Prompt gilt wieder. |
| `~/.config/lex/openrouter-key` | API-Key, nur für den eigenen Benutzer lesbar |
| `~/Library/Application Support/Lex/history.json` | Historie |
| `~/Library/LaunchAgents/de.ralfw.lex.plist` | Login-Start (nur wenn eingeschaltet) |

Der API-Key liegt bewusst in einer Datei statt im Schlüsselbund: Lex ist ad-hoc signiert, jeder Neubau hätte eine neue Signatur, und der Schlüsselbund würde jedes Mal nach dem Passwort fragen.

## Datenschutz

Jede Eingabe ohne Befehl wird über OpenRouter an Jev und an das jeweilige Sprachmodell geschickt. „Ausführlich im Chat“ übergibt die Frage als Teil der URL an claude.ai bzw. chatgpt.com. Die Historie bleibt lokal auf dem Mac.

## Entwicklung

```bash
swift build        # bauen
swift test         # Unit-Tests: Eingabe-Parser, Routing-Regeln, Markdown, Leeren nach Pause
./build.sh         # App-Bundle nach build/Lex.app
```

Aufbau:

- `Sources/LexCore` – Logik ohne UI: Eingabe-Parser, Jev-Klassifizierer, OpenRouter-Client mit Streaming, Prompts, Historie, Konfiguration
- `Sources/Lex` – die App: schwebendes Panel, Historie- und Einstellungsfenster, globale Hotkeys
- `Sources/lex-eval` – Kommandozeilen-Werkzeug zum Messen
- `Evals/routing.json` – Testfälle für Jevs Einordnung

`lex-eval` braucht den API-Key in `~/.config/lex/openrouter-key` oder in `OPENROUTER_API_KEY`:

```bash
swift run lex-eval routing                 # wie oft ordnet Jev die Testfälle richtig ein, wie schnell?
swift run lex-eval ask "tat twam asi"      # kompletter Durchlauf im Terminal
```
