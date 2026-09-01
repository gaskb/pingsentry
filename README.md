# PingSentry

*[Italiano sotto / Italian below](#pingsentry-italiano)*

A macOS menu bar app that periodically pings a host of your choice and shows the result right next to the clock: a wifi-style signal bars icon plus latency and packet-loss percentage (e.g. `▂▄▆█ 9ms (0%)`).

Built to replace a ~10-year-old third-party menu bar widget that macOS was about to stop running.

PingSentry is free. If you find it useful, feel free to [buy me a coffee on Ko-fi](https://ko-fi.com/gaskb) — no obligation at all.

## Download

Grab the latest `.dmg` from the [Releases page](https://github.com/gaskb/pingsentry/releases), open it, and drag PingSentry into Applications.

**Not notarized yet:** since this isn't signed with a paid Apple Developer ID, macOS will flag it as being from an unidentified developer on first launch. To open it: right-click (or Control-click) PingSentry.app in Applications → **Open** → confirm in the dialog. You only need to do this once.

## How it works

- Swift + SwiftUI, using `MenuBarExtra` (macOS 14+).
- Ping runs as a single long-lived `ping -i <interval> <host>` process for the whole monitoring session (not one process per ping — that used to inflate every latency reading with a "cold first packet" cost). Output is parsed line by line; packet loss is detected from gaps in `icmp_seq`.
- Menu bar label, notifications, session/lifetime stats (total pings, success/failure count and %, average/fastest/slowest latency), launch-at-login, and an in-app language picker are all configurable from Settings.

## Development

```bash
swift build
swift run
```

`swift run` launches the app as a plain process (you'll also see a Dock icon, which the packaged `.app` hides via `LSUIElement`). Login item and notifications only work from a packaged `.app` with a bundle identifier — `swift run` alone can't exercise those two features.

To build a distributable `.app` bundle (ad-hoc signed, not notarized):

```bash
./Scripts/build_app.sh
```

## Project layout

- `Sources/PingSentry/PingSentryApp.swift` — app entry point, menu bar label, window scenes.
- `Sources/PingSentry/PersistentPinger.swift` — the long-lived ping process and its output parser.
- `Sources/PingSentry/PingMonitor.swift` — ping loop orchestration, rolling packet-loss window, notifications.
- `Sources/PingSentry/PingStats.swift` — session/lifetime counters.
- `Sources/PingSentry/Localization.swift` — in-app language override (independent of the macOS system language).
- `Sources/PingSentry/Resources/*.lproj/` — translated strings.
- `Sources/PingSentry/MenuContentView.swift`, `SettingsView.swift`, `AboutView.swift`, `StatsView.swift` — UI.

## Localization

Supported languages: English, Italian, French, German, Spanish, Portuguese, Polish, Romanian, and Simplified Chinese. The in-app language picker (Settings → Language) defaults to "System Language" (auto-detected from macOS, falling back to English) but can be overridden per-user regardless of the OS setting.

All translations were written by an AI assistant rather than reviewed by a native speaker. Confidence is reasonably high for French, German, Spanish, and Portuguese; **Polish, Romanian, and Simplified Chinese are the least certain and would most benefit from a native speaker's review.** If you speak one of these languages and spot an awkward phrasing or outright mistake, contributions are very welcome — the relevant files are the `.strings` tables under `Sources/PingSentry/Resources/<language-code>.lproj/Localizable.strings`; open a pull request or an issue with the fix.

## Distribution

Not yet notarized. Plan: a notarized DMG published via GitLab/GitHub Releases, which needs an Apple Developer ID account to be set up separately.

## License

[MIT](LICENSE) — do whatever you want with it, just keep the copyright notice.

---

# PingSentry (Italiano)

App per la barra menu di macOS che esegue un ping periodico verso un host a scelta e ne mostra il risultato accanto all'orologio: un'icona a barre stile segnale wifi più latenza e percentuale di pacchetti persi (es. `▂▄▆█ 9ms (0%)`).

Nata per sostituire un vecchio widget di terze parti (~10 anni) che macOS stava per smettere di far funzionare.

PingSentry è gratis. Se ti torna utile, sentiti libero di [offrirmi un caffè su Ko-fi](https://ko-fi.com/gaskb) — nessun obbligo.

## Download

Scarica l'ultima `.dmg` dalla [pagina Releases](https://github.com/gaskb/pingsentry/releases), aprila e trascina PingSentry nella cartella Applicazioni.

**Non ancora notarizzata:** non essendo firmata con un account Apple Developer ID a pagamento, al primo avvio macOS la segnala come proveniente da uno sviluppatore non identificato. Per aprirla: tasto destro (o Control-clic) su PingSentry.app in Applicazioni → **Apri** → conferma nella finestra di dialogo. Serve una volta sola.

## Come funziona

- Swift + SwiftUI, con `MenuBarExtra` (macOS 14+).
- Il ping gira come un unico processo `ping -i <intervallo> <host>` per tutta la sessione di monitoraggio (non un processo per ogni ping — cosa che gonfiava ogni misura di latenza con il costo del "primo pacchetto a freddo"). L'output viene letto riga per riga; i pacchetti persi si rilevano dai buchi nella sequenza `icmp_seq`.
- Etichetta in barra, notifiche, statistiche di sessione/lifetime (ping totali, conteggio e % di successi/fallimenti, latenza media/minima/massima), avvio automatico al login e selettore di lingua sono tutti configurabili dalle Impostazioni.

## Sviluppo

```bash
swift build
swift run
```

`swift run` avvia l'app come processo semplice (comparirà anche un'icona nel Dock, assente invece nel bundle `.app` grazie a `LSUIElement`). Avvio automatico al login e notifiche funzionano solo con un `.app` pacchettizzato con un bundle identifier — `swift run` da solo non basta per queste due funzionalità.

Per costruire un bundle `.app` distribuibile (firmato ad-hoc, non notarizzato):

```bash
./Scripts/build_app.sh
```

## Struttura del progetto

- `Sources/PingSentry/PingSentryApp.swift` — entry point, etichetta in barra, finestre.
- `Sources/PingSentry/PersistentPinger.swift` — il processo ping persistente e il suo parser.
- `Sources/PingSentry/PingMonitor.swift` — orchestrazione del ciclo di ping, finestra di calcolo della perdita, notifiche.
- `Sources/PingSentry/PingStats.swift` — contatori di sessione/lifetime.
- `Sources/PingSentry/Localization.swift` — override della lingua a livello di app (indipendente dalla lingua di sistema di macOS).
- `Sources/PingSentry/Resources/*.lproj/` — stringhe tradotte.
- `Sources/PingSentry/MenuContentView.swift`, `SettingsView.swift`, `AboutView.swift`, `StatsView.swift` — interfaccia.

## Localizzazione

Lingue supportate: italiano, inglese, francese, tedesco, spagnolo, portoghese, polacco, rumeno e cinese semplificato. Il selettore di lingua nell'app (Impostazioni → Language) parte da "System Language" (rilevata automaticamente da macOS, con fallback all'inglese) ma può essere forzato dall'utente indipendentemente dall'impostazione del sistema operativo.

Tutte le traduzioni sono state scritte da un assistente IA, non riviste da un madrelingua. La confidenza è ragionevolmente alta per francese, tedesco, spagnolo e portoghese; **polacco, rumeno e cinese semplificato sono le meno certe e trarrebbero più beneficio da una revisione di un madrelingua.** Se parli una di queste lingue e noti una frase innaturale o un errore, i contributi sono benvenuti — i file interessati sono le tabelle `.strings` sotto `Sources/PingSentry/Resources/<codice-lingua>.lproj/Localizable.strings`; apri una pull request o una issue con la correzione.

## Distribuzione

Non ancora notarizzata. Piano: una DMG notarizzata pubblicata via GitLab/GitHub Releases, che richiede un account Apple Developer ID da configurare a parte.

## Licenza

[MIT](LICENSE) — fanne quello che vuoi, basta mantenere la nota di copyright.
