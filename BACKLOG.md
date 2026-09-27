# PingSentry — Product & Technical Backlog

Documento generato il **2026-09-27**, basato sulle risultanze di `review.md` (commit `855fa0c`) e sull'analisi architetturale del codice sorgente.

---

## Scala di Stima & Priorità

- **Priorità**:
  - `P0`: Bloccante / Bug critico funzionale o di risorse (da fare subito).
  - `P1`: Alta priorità / Stabilità del core e affidabilità del monitoraggio.
  - `P2`: Media priorità / Robustezza, UX e rifinitura funzionale.
  - `P3`: Bassa priorità / Polish, distribuzione esterna e maintenance.
- **Story Points (SP)**: Scala Fibonacci standard ($1, 2, 3, 5, 8$).
- **Stima Temporale**: Durata prevista di sviluppo e testing locale.

---

## Vista d'Insieme dei Task

| ID | Task | Fonte | Priorità | SP | Stima Tempo | Milestone | Stato |
|:---|:---|:---:|:---:|:---:|:---:|:---:|:---:|
| **PS-01** | Fix richiesta permessi notifiche al primo avvio & stato denied | `review.md` (Punto 1) | **P0** | **2** | ~1h | MS1 (Quick Fixes) | ✅ Completato |
| **PS-02** | Consumo/Drain di `stderr` per evitare freeze da buffer kernel | Proposta tecnica | **P0** | **1** | ~30m | MS1 (Quick Fixes) | ✅ Completato |
| **PS-03** | In-memory cache & debouncing scritture I/O statistiche permanenti | `review.md` (Punto 3) | **P0** | **3** | ~2h | MS1 (Quick Fixes) | ✅ Completato |
| **PS-04** | Disaccoppiamento `PingOutputParser` puro e target `Tests` SPM | `review.md` (Punto 2) | **P1** | **5** | ~3-4h | MS2 (Reliability) | Da fare |
| **PS-05** | Isolamento sessioni asincrone su `restart()` tramite `sessionId` | `review.md` (Sec. 1) | **P1** | **2** | ~1h | MS2 (Reliability) | Da fare |
| **PS-06** | Gestione eventi Sleep & Wake di macOS (prevenzione falsi down) | Proposta tecnica | **P1** | **2** | ~1-2h | MS2 (Reliability) | Da fare |
| **PS-07** | Macchina a stati monitor (`PingState`), retry backoff & loop limit | `review.md` (Punto 4) | **P1** | **3** | ~2-3h | MS3 (Validation) | Da fare |
| **PS-08** | Validazione host e gestione dual-binary `/sbin/ping` vs `ping6` | `review.md` (Punto 5) | **P1** | **3** | ~2h | MS3 (Validation) | Da fare |
| **PS-09** | Azione di reset statistiche (Sessione & Lifetime) in `StatsView` | Proposta tecnica | **P2** | **2** | ~1h | MS3 (Validation) | Da fare |
| **PS-10** | Policy di retention (LRU/Cap) per `lifetimeStatsByHost` | `review.md` (Sec. 2) | **P2** | **2** | ~1h | MS4 (Polish) | Da fare |
| **PS-11** | Accessibilità menu bar (VoiceOver) e export diagnostica rapida | `review.md` (Sec. 3) | **P2** | **3** | ~2h | MS4 (Polish) | Da fare |
| **PS-12** | Pipeline di Notarizzazione & Hardened Runtime (Developer ID) | `review.md` (Sec. 4) | **P3** | **5** | ~3-4h | MS4 (Polish) | Da fare |

---

## Dettaglio dei Singoli Item

### PS-01: Fix richiesta permessi notifiche al primo avvio & stato denied
- **Priorità**: `P0` | **Stima**: 2 SP (~1h)
- **Contesto**: Con l'opzione `notifyOnStateChange` attiva per default a `true`, `NotificationManager.requestAuthorizationIfNeeded()` viene chiamato solo nel toggle `onChange` di `SettingsView`. Una nuova installazione non chiede mai l'autorizzazione di sistema, degradando silenziosamente.
- **Implementazione**:
  1. Invocare `NotificationManager.requestAuthorizationIfNeeded()` all'avvio in `PingSentryApp.init()` o nel `.task` iniziale.
  2. Aggiungere lettura asincrona dello stato autorizzativo (`UNUserNotificationCenter.current().getNotificationSettings`).
  3. In `SettingsView`, se `status == .denied`, mostrare un banner esplicito con pulsante "Apri Impostazioni di Sistema".
- **Criteri di Accettazione**:
  - Al primissimo avvio dell'app senza precedenti impostazioni, macOS mostra il prompt di consenso notifiche.
  - Se l'utente nega i permessi, nelle impostazioni appare un avviso chiaro con link alle preferenze di sistema.

---

### PS-02: Consumo/Drain di `stderr` per evitare freeze da buffer kernel
- **Priorità**: `P0` | **Stima**: 1 SP (~30m)
- **Contesto**: `PersistentPinger.swift` istanzia `process.standardError = Pipe()`, ma nessun handler legge dalla pipe. Quando la rete cade o l'host non risolve, i messaggi di errore di `ping` saturano il buffer kernel (64 KB) e bloccano il processo in una deadlock di I/O.
- **Implementazione**:
  - Reindirizzare `standardError` a `FileHandle.nullDevice` per scartarlo in sicurezza, oppure collegarlo a un handler di diagnostica.
- **Criteri di Accettazione**:
  - Nessun rischio di saturazione buffer pipe kernel anche dopo ore di disconnessione o generazione di errori continui su `stderr`.

---

### PS-03: In-memory cache & debouncing scritture I/O statistiche permanenti
- **Priorità**: `P0` | **Stima**: 3 SP (~2h)
- **Contesto**: In `PingMonitor.record`, `LifetimeStatsStore.save` esegue decode JSON, update, encode JSON e `UserDefaults.set` a ogni singolo ping sul Main Thread (fino a 86.400 volte al giorno).
- **Implementazione**:
  1. Mantenere le statistiche correnti in memoria con flag `isDirty`.
  2. Implementare un timer periodico di flush (es. ogni 30 o 60 secondi).
  3. Eseguire il flush immediato solo su cambio host (`changeHost`), azzeramento o terminazione applicazione (`applicationWillTerminate`).
- **Criteri di Accettazione**:
  - Scritture su `UserDefaults` ridotte da ~1/s a 1-2 al minuto.
  - Nessuna perdita di dati al cambio host o all'uscita pulita dell'applicazione.

---

### PS-04: Disaccoppiamento `PingOutputParser` puro e target `Tests` SPM
- **Priorità**: `P1` | **Stima**: 5 SP (~3-4h)
- **Contesto**: Il core dell'app non ha alcun test automatico. Il parsing di `stdout` di `/sbin/ping` e la logica di calcolo pacchetti persi sono accoppiati alla classe `PersistentPinger`.
- **Implementazione**:
  1. Estrarre una struct pura `PingOutputParser`:
     - Parsing riga risposta valida: `icmp_seq=X ttl=Y time=Z ms` $\rightarrow$ latenza.
     - Parsing timeout: `Request timeout for icmp_seq X` $\rightarrow$ fallimento con sequence number.
     - Gestione chunk parziali / righe spezzate (`\n`).
     - Gestione salti di sequenza (`missingCount` limitato a max 50).
  2. Aggiungere il target `.testTarget(name: "PingSentryTests")` in `Package.swift`.
  3. Test unitari per: riga valida, timeout, chunk spezzati, salti `icmp_seq`, righe spazzatura.
- **Criteri di Accettazione**:
  - `swift test` eseguibile da riga di comando con 100% test passati e copertura completa del parser.

---

### PS-05: Isolamento sessioni asincrone su `restart()` tramite `sessionId`
- **Priorità**: `P1` | **Stima**: 2 SP (~1h)
- **Contesto**: In `PersistentPinger`, i chunk di output vengono letti in un `readabilityHandler` che spawna `Task { @MainActor in consume(chunk) }`. Su `restart()`, vecchi chunk in coda possono essere eseguiti dopo l'avvio del nuovo processo, contaminando `buffer` e `lastSeq`.
- **Implementazione**:
  - Assegnare a ogni avvio di processo un `currentSessionId: UUID`.
  - Passare il `sessionId` al task e scartare l'output se non corrisponde alla sessione corrente.
- **Criteri di Accettazione**:
  - I cambi rapidi di host o intervallo non mescolano i sequence number tra la vecchia e la nuova sessione.

---

### PS-06: Gestione eventi Sleep & Wake di macOS (prevenzione falsi down)
- **Priorità**: `P1` | **Stima**: 2 SP (~1-2h)
- **Contesto**: Quando il Mac va in stop (chiusura coperchio), il processo `ping` viene sospeso dal sistema. Al risveglio, i timeout accumulati generano falsi allarmi "Host Down".
- **Implementazione**:
  - Sottoscriversi a `NSWorkspace.willSleepNotification`: sospendere o fermare il monitoraggio e resettare `consecutiveFailures`.
  - Sottoscriversi a `NSWorkspace.didWakeNotification`: riavviare `PersistentPinger` dopo un breve grace period (es. 2-3 secondi per consentire il riaggancio del Wi-Fi).
- **Criteri di Accettazione**:
  - Nessuna notifica di host down generata immediatamente dopo il risveglio dallo stop del Mac.

---

### PS-07: Macchina a stati monitor (`PingState`), retry backoff & loop limit
- **Priorità**: `P1` | **Stima**: 3 SP (~2-3h)
- **Contesto**: Se `ping` esce per errore (es. host non risolvibile, exit code 68), il processo riparte all'infinito ogni 2s senza esporre lo stato d'errore all'utente nella UI, che vede solo un timeout generico.
- **Implementazione**:
  1. Definire `enum PingState`: `.idle`, `.running`, `.retrying(attempt: Int, error: String)`, `.failed(error: String)`.
  2. Implementare backoff esponenziale (es. 2s, 4s, 8s fino a max 30s) e arresto con stato `.failed` dopo $N$ tentativi consecutivi di crash immediato.
  3. Riflettere lo stato nel menu della Menu Bar con descrizione dell'errore e opzione per ritentare manualmente.
- **Criteri di Accettazione**:
  - Se l'host non esiste, l'app cessa i riavvii continui a vuoto e visualizza "Errore di risoluzione host".

---

### PS-08: Validazione host e gestione dual-binary `/sbin/ping` vs `ping6`
- **Priorità**: `P1` | **Stima**: 3 SP (~2h)
- **Contesto**: macOS non supporta IPv6 tramite `/sbin/ping` (che fallisce con `Unknown host`); per IPv6 richiede `/sbin/ping6`. Inoltre parametri che iniziano con `-` o caratteri non validi sporcano gli argomenti CLI.
- **Implementazione**:
  1. Validazione preventiva in `SettingsView` / `applyHost`: rigettare stringhe vuote, prefissi `-` e caratteri illegali.
  2. Riconoscimento del formato IP (IPv4 vs IPv6):
     - Se IPv6: eseguire `/sbin/ping6`.
     - Se IPv4 o Hostname standard: eseguire `/sbin/ping`.
  3. Messaggio di validazione in linea nella UI localizzato.
- **Criteri di Accettazione**:
  - Sia `1.1.1.1` che `::1` o `2001:4860:4860::8888` funzionano correttamente senza errori di comando.
  - Parametri invalidi come `-c 5` vengono respinti con feedback visivo.

---

### PS-09: Azione di reset statistiche (Sessione & Lifetime) in `StatsView`
- **Priorità**: `P2` | **Stima**: 2 SP (~1h)
- **Contesto**: Attualmente non c'è modo per l'utente di azzerare le statistiche accumulate se desidera avviare una nuova sessione di misurazione pulita.
- **Implementazione**:
  - Aggiungere pulsanti dedicati o menu di contesto in `StatsView` per "Azzera sessione corrente" e "Azzera storico host".
  - Aggiornamento reattivo della vista e sincronizzazione con `LifetimeStatsStore`.
- **Criteri di Accettazione**:
  - L'utente può resettare a zero le metriche con conferma o azione diretta.

---

### PS-10: Policy di retention (LRU/Cap) per `lifetimeStatsByHost`
- **Priorità**: `P2` | **Stima**: 2 SP (~1h)
- **Contesto**: Testando molti host, il dizionario salvato in `UserDefaults` cresce indefinitamente.
- **Implementazione**:
  - Aggiungere timestamp di ultimo utilizzo per ciascun host registrato.
  - Fissare un limite massimo (es. 30 o 50 host più recenti). Quando si supera il cap, rimuovere le voci meno recenti prima del salvataggio.
- **Criteri di Accettazione**:
  - Il payload salvato in `UserDefaults` non supera mai la soglia massima stabilita di host storici.

---

### PS-11: Accessibilità menu bar (VoiceOver) e export diagnostica rapida
- **Priorità**: `P2` | **Stima**: 3 SP (~2h)
- **Contesto**: L'icona nella barra dei menu necessita di etichette per gli screen reader. Inoltre, per il debug degli utenti, è utile poter copiare lo stato corrente.
- **Implementazione**:
  - Aggiungere `.accessibilityLabel` con lettura esplicita di qualità segnale, latenza e perdita pacchetti.
  - Aggiungere voce di menu "Copia informazioni di diagnostica" (host, latenza attuale, pacchetti trasmessi/persi, stato del processo).
- **Criteri di Accettazione**:
  - VoiceOver legge correttamente i dati dello stato nella menu bar.
  - L'utente può incollare in un click un sommario diagnostico per segnalare problemi.

---

### PS-12: Pipeline di Notarizzazione & Hardened Runtime (Developer ID)
- **Priorità**: `P3` | **Stima**: 5 SP (~3-4h)
- **Contesto**: Attualmente il README indica che l'app non è firmata con Developer ID, richiedendo agli utenti di bypassare Gatekeeper manualmente.
- **Implementazione**:
  - Script di build per signing con Hardened Runtime (`codesign --options runtime`).
  - Integrazione di `xcrun notarytool submit` nello script di release (`Scripts/build_dmg.sh` o workflow dedicato).
  - `xcrun stapler staple` sul DMG finale.
- **Criteri di Accettazione**:
  - Il DMG generato si apre su macOS senza warning di Gatekeeper / sviluppatore non identificato.

---

## Piano di Esecuzione per Milestone

```mermaid
flowchart LR
    M1["Milestone 1 (Sprint 1)\nQuick Wins & Stabilità\n(6 SP ~3.5h)"] --> M2["Milestone 2 (Sprint 2)\nTest Suite & Affidabilità Core\n(9 SP ~6-7h)"]
    M2 --> M3["Milestone 3 (Sprint 3)\nError Handling & Input\n(8 SP ~5-6h)"]
    M3 --> M4["Milestone 4 (Sprint 4)\nPolish & Distribuzione\n(10 SP ~6-7h)"]
```

### Totale Complessivo
- **Totale Task**: 12
- **Totale Story Points**: **33 SP**
- **Tempo Stimato Totale**: **~22 - 25 ore uomo**
