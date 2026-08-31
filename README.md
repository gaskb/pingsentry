# PingSentry

App per la menu bar di macOS che esegue un ping periodico verso un host configurabile e ne mostra lo stato in barra: icona a barre (stile segnale wifi, 4 livelli) più latenza e percentuale di pacchetti persi (es. `10ms (0%)`).

Nata per sostituire un vecchio widget di terze parti non più mantenuto e non più disponibile.

## Come funziona

- Costruita con Swift + SwiftUI (`MenuBarExtra`, richiede macOS 13+).
- Il ping non usa raw ICMP socket (che richiederebbero entitlement particolari in sandbox), ma lancia `/sbin/ping -c 1 -t 2 <host>` come processo esterno e ne parsa l'output.
- La percentuale di pacchetti persi è calcolata su una finestra scorrevole degli ultimi N ping (configurabile).
- Host, intervallo e finestra sono configurabili dal menu dell'app e persistiti in `UserDefaults`.

## Sviluppo

```bash
swift build
swift run
```

`swift run` avvia l'app come processo semplice (comparirà anche un'icona nel Dock, assente invece nel bundle `.app` finale grazie a `LSUIElement`).

## Struttura

- `Sources/PingSentry/PingSentryApp.swift` — entry point e label della menu bar.
- `Sources/PingSentry/PingMonitor.swift` — logica di ping, storico, calcolo qualità/loss.
- `Sources/PingSentry/StatusIconRenderer.swift` — disegno dell'icona a barre.
- `Sources/PingSentry/MenuContentView.swift` — contenuto del menu a tendina (stato + impostazioni).

## Distribuzione

Non ancora impacchettata come `.app` firmata/notarizzata. Piano: build script che genera il bundle `.app`, poi DMG notarizzata (richiede un Apple Developer ID account, da configurare a parte) distribuita via GitLab Releases.
