# FIX_LOG — correzioni dei bug del TEST_REPORT

Backup completo: `~/.config/eww.bak-2026-11-03-1129`
Repository git in `~/.config/eww` (commit iniziale `f5f352c`).
Per tornare a uno stato precedente: `git -C ~/.config/eww log --oneline`, poi
`git -C ~/.config/eww checkout <commit> -- .` e riavvio di eww.

## TODO (Fase 1, in ordine di gravità)
- [x] B1 critico — secondo daemon eww / closer orfano
- [x] B2 alto — aperture concorrenti pesanti bloccano eww
- [x] B3 medio — icona Proton VPN persa dopo riavvio di eww (mitigato)
- [x] B4 medio — eventi musica persi (ritardi 3–9 s)
- [x] B5 medio — RAM di eww cresce con i reload (causa in eww: mitigato)
- [x] B6 basso — apostrofo rompe la copia
- [x] B7 basso — copia di valori multipli (DNS, più IPv4)
- [x] B8 basso — volume.py muore senza pactl
- [x] B9 basso — power.sh accetta azioni sconosciute
- [x] B10 basso — lista Wi-Fi/BT resta espansa
- [x] B11 basso — estetica OSD (alone) e calendario (trasparenza)

## Diario

### B1 — secondo daemon eww / closer orfano (CORRETTO)
- **Riprodotto prima**: istanza isolata (config di prova, 5 `open` pesanti + 1 leggero):
  3 daemon in ascolto. Istanza isolata con la config VERA del backup
  (`tests/b1-busy.sh`, daemon "occupato" simulato con SIGSTOP 3 s mentre
  arrivano 3 click): **2 daemon**, quello che risponde senza finestre.
- **Causa**: in eww 0.5 SOLO `open` e `open-many` avviano un daemon nuovo quando
  non riescono a parlare con quello esistente (verificato comando per comando
  su istanza isolata: update/get/close/active-windows/ping non lo fanno).
  Con il daemon occupato il client va in timeout (`os error 11`), cancella il
  socket e avvia un secondo daemon; il primo resta vivo con le sue finestre.
- **Correzione** (a più livelli):
  1. `scripts/lib.sh` (nuovo): `eww_` = `eww --no-daemonize` con timeout. Con
     `--no-daemonize` un `open` fallito non avvia mai un daemon (verificato).
  2. Lock globale `$XDG_RUNTIME_DIR/eww-ops.lock` per tutte le aperture/chiusure
     (popup.sh, osd.sh, session.py): mai aperture concorrenti.
  3. Prima di aprire: `eww ping`; dopo: verifica che la finestra ci sia davvero
     (con --no-daemonize un open fallito può tornare rc=0) e rollback se no.
  4. Watchdog in `session.py` (`health_loop`): >1 daemon della config per 2
     controlli, oppure daemon che non risponde da 20 s → `scripts/recover.sh`
     (nuovo, lanciato con setsid): chiude TUTTI i daemon della config e ne
     avvia uno solo con la barra. Log in `~/.cache/eww/recover.log`.
- **File**: scripts/lib.sh (nuovo), scripts/recover.sh (nuovo), scripts/popup.sh,
  scripts/osd.sh, scripts/session.py, scripts/power.sh, scripts/bt-connect.sh.
- **Test che lo dimostrano** (tutti su istanza isolata con la config vera):
  `tests/b1-busy.sh` PRIMA: 2 daemon (FAIL) → DOPO: 1 daemon, dashboard aperto (PASS);
  `tests/b1-test.sh` 7 e 10 click simultanei + popup durante reload: 1 daemon (PASS);
  `tests/b1-dup.sh` duplicato creato apposta → ripristinato in 11 s, 1 daemon con
  la barra (PASS); `tests/b1-recover.sh` daemon bloccato (SIGSTOP) → sostituito
  dopo ~30 s (soglia 20 s), 1 daemon con la barra (PASS).

### B2 — aperture concorrenti pesanti (CORRETTO lato config)
- **Riprodotto prima**: `tests/b2-test.sh MODE=old` (istanza isolata, 10 open
  simultanei di una finestra da 3000 widget): **2 daemon**, 1 finestra su 10.
- **Causa vera** (trovata indagando): il client eww si arrende dopo **~135 ms**
  di attesa (`channel closed` nel log del daemon), mentre il daemon continua a
  costruire la finestra. Con il codice vecchio il client arreso avviava un
  daemon nuovo (= B1); le aperture accavallate si contendevano il daemon.
  Lo "stallo di 3 minuti" del report era in realtà la pipe del test tenuta
  aperta dai daemon duplicati.
- **Correzione**: B1 + lock globale tenuto finché la finestra non è davvero
  aperta (`eww_open_verified` aspetta fino a 3 s; `sync_bars` in session.py
  aspetta ogni barra fino a 5 s prima di aprire la successiva).
- **File**: scripts/lib.sh, scripts/session.py.
- **Test**: `tests/b2-test.sh MODE=new`: 10/10 finestre, 1 daemon, risponde (PASS).
- Nota: il dashboard vero si costruisce in ~300 ms, cioè oltre i 135 ms del
  client: per questo il vecchio codice poteva duplicare il daemon anche con un
  solo click quando il sistema era carico.

### B3 — icona Proton VPN persa dopo un riavvio di eww (MITIGATO)
- **Riprodotto**: dopo i riavvii di eww dei test l'elemento
  `org.kde.StatusNotifierItem-proton.vpn.app.gtk-*` esisteva su D-Bus ma non
  era nella lista `RegisteredStatusNotifierItems` del watcher (4 elementi invece di 5).
- **Causa**: il watcher del systray è ospitato dal daemon eww. Quando eww si
  riavvia nasce un watcher nuovo: nm-applet, blueman, copyq e vicinae si
  ri-registrano, protonvpn-app no (comportamento dell'app, non della config).
- **Mitigazione**: `tray_resync()` in session.py (4 s dopo l'avvio e poi ogni
  30 s) registra gli elementi presenti su D-Bus ma assenti dal watcher, con il
  metodo standard `RegisterStatusNotifierItem`. Salta quelli il cui processo è
  già registrato (niente doppioni; verificato idempotente).
- **Test**: registrazione manuale → icona tornata (screenshot); riavvio vero
  della barra con `recover.sh` → Proton ri-registrato in automatico in 14 s,
  5 elementi su 5, icona visibile (screenshot).
- **Non risolvibile del tutto lato config**: se protonvpn-app ricrea il suo
  elemento con un nome nuovo, comparirà entro 30 s; la causa resta nell'app.
- **File**: scripts/session.py.

### B4 — eventi musica persi, ritardi 3–9 s (CORRETTO)
- **Riprodotto prima**: `tests/b4-media.sh` (4 avvii/chiusure di vlc muto):
  ritardi fino a **9011 ms** (5377, 8396 all'avvio; 7373, 8971, 9011 alla chiusura).
- **Causa**: `playerctl --follow` segue un player alla volta e non sempre vede
  quelli che compaiono/spariscono; si recuperava solo con la risincronizzazione
  ogni 10 s.
- **Correzione**: `scripts/mpris_watch.py` (nuovo) ascolta direttamente i segnali
  D-Bus `NameOwnerChanged` (org.mpris.MediaPlayer2.*) e `PropertiesChanged`
  (/org/mpris/MediaPlayer2), raggruppati ogni 100 ms. Usato da media.py e
  cava.py (cava.py ora ha anche la risincronizzazione ogni 10 s). Se Gio non
  è disponibile si torna a `playerctl --follow` (verificato).
- **File**: scripts/mpris_watch.py (nuovo), scripts/media.py, scripts/cava.py.
- **Test**: `tests/b4-media.sh` DOPO: avvio ~100 ms, chiusura ~190 ms, peggiore
  190 ms (PASS); `tests/media-regr.sh` 13/13 (pausa, ripresa, scorrimento, cava).
  Bonus: nessun processo `playerctl --follow` sempre attivo (prima 2).

### B5 — RAM di eww cresce con i reload (NON RISOLVIBILE lato config: mitigato)
- **Riprodotto e isolato** (`tests/b5-mem.sh`, istanza isolata con la config vera,
  30 reload): **senza systray** 59 → 63 MB (stabile, nessuna perdita);
  **con systray** 106 → 290 MB (~6 MB per reload, non si ferma).
- **Causa**: il widget `systray` di eww 0.5 perde memoria a ogni ricostruzione
  (reload). I reload avvengono quando cambiano i file della config, cioè a ogni
  cambio wallpaper (matugen riscrive colors.scss). Non si può evitare dalla
  config senza togliere il systray (decisione dell'utente, vedi lista finale).
- **Mitigazione**: limite di memoria nel watchdog di session.py: se il daemon
  supera 400 MB (controllo ogni 60 s) e nessun popup è aperto → riavvio pulito
  con recover.sh (la barra sparisce ~2 s; Proton si ri-registra da solo, B3).
  Con ~6 MB per cambio wallpaper servono decine di cambi prima che scatti.
- **File**: scripts/session.py (limite regolabile con EWW_MEM_LIMIT_MB /
  EWW_MEM_EVERY, usati solo dai test).
- **Test**: `tests/b5-guard.sh` (limite 130 MB): daemon gonfiato sostituito,
  nuovo daemon 72 MB, 1 daemon, barra presente (PASS).

### B6 + B7 — copia negli appunti (CORRETTI)
- **Riprodotti prima** (template onclick vero di widgets.yuck eseguito con sh,
  wl-copy finto): `Mario's (55%)` → **niente copiato** (errore di sintassi);
  `192.168.1.5/24, 10.0.0.2/8` → copiato **solo** `192.168.1.5`.
- **Causa**: il valore veniva inserito nella riga di comando tra apici singoli;
  `copy.sh` tagliava tutto dopo il primo `/`.
- **Correzione**: il click passa solo il nome del campo e dell'interfaccia
  (`copy.sh ipv4 wlan0`), validati con regex; `copy.sh` legge il valore da
  `eww get net` / `public-ip` con jq. Valori multipli: tutti, uno per riga,
  senza `/NN`. Gateway → solo l'indirizzo; Wi-Fi → solo l'SSID.
- **File**: scripts/copy.sh (riscritto), widgets.yuck (net-field + 9 chiamate).
- **Test** (eww finto con dati ostili): 16/16 PASS — SSID con apostrofo,
  virgolette e emoji copiato intatto; 2 IPv4 → entrambi; DNS → entrambi;
  campi vuoti/`—`/interfaccia inesistente → niente; `rm-rf`, `wlan0;reboot`,
  `$(id)` → rifiutati (rc=2). Dashboard si apre dopo la modifica.

### B8 — volume.py muore senza pactl (CORRETTO)
- **Prima**: PATH senza pactl → `FileNotFoundError`, rc=1 (listener morto).
- **Correzione**: se pactl manca si rilegge il volume ogni 2 s invece di
  terminare; wpctl con timeout 3 s.
- **Test**: senza pactl/wpctl → resta vivo (rc=124 da timeout); con wpctl e
  senza pactl → valore corretto; normale → invariato. **File**: scripts/volume.py.

### B9 — power.sh accetta azioni sconosciute (CORRETTO)
- **Prima** (comandi finti): `power.sh "rm -rf"` → power-confirm='rm -rf'.
- **Correzione**: solo lock|logout|reboot|poweroff, altrimenti exit 2.
- **Test**: `tests/power-test.sh` 14/14 (7 casi originali + 6 azioni non valide
  + stato finale), sempre con systemctl/hyprlock/hyprctl finti. **File**: scripts/power.sh.

### B10 — lista Wi-Fi/BT resta espansa (CORRETTO)
- **Correzione**: chiusura del popup (popup.sh e watchdog di session.py) azzera
  expand-wifi/expand-bt. **Test**: 5/5 (chiusura, passaggio al calendario,
  per wifi e bt; chiusura da watchdog). **File**: scripts/popup.sh, scripts/session.py.

### B11 — estetica OSD e calendario (CORRETTO, causa vera trovata)
- **Riprodotto**: screenshot dell'OSD con una seconda capsula scura attorno;
  calendario con il testo della finestra sotto leggibile.
- **Causa vera OSD**: eww dà a ogni finestra una classe CSS col suo nome; la
  finestra si chiama `osd` e il riquadro usava la classe `.osd` → lo stile
  della capsula (sfondo, bordo, raggio, margine) veniva applicato anche alla
  finestra. Cambiare solo l'ombra non bastava (verificato con screenshot).
- **Correzione**: classe rinominata `.osd-box`; ombra più corta; calendario con
  sfondo al 98,5%. Controllati gli altri nomi di finestra: `.bar` coincide ma
  la regola ha solo padding e non viene applicata alla finestra (altezza
  misurata 61 px = 42+2+17); `.closer` è voluto.
- **Test**: screenshot dopo: una sola capsula (finestra da 108 a 84 px),
  calendario senza testo sotto; `tests/osd-test.sh` 11/11.
- **File**: widgets.yuck, eww.scss.

## Fase 2 — Ciclo 1

### N1 — swaync-client orfano se notif.sh viene terminato (NUOVO, CORRETTO)
- **Trovato da**: `tests/t-perf.sh` (processo `swaync-client -swb` con ppid=1).
- **Riprodotto**: `notif.sh` avviato da solo e terminato con TERM → il figlio
  `swaync-client` resta vivo con ppid=1. Sulla barra vera eww chiude l'intero
  gruppo di processi, ma qualunque terminazione del solo script lasciava l'orfano
  (nel test veniva dalla pulizia dell'istanza isolata).
- **Correzione**: swaync-client in background + `wait`, trap su TERM/INT/HUP che
  chiude il figlio. **File**: scripts/notif.sh. Anche `tests/iso-real.sh` ora
  chiude l'intero albero di processi dell'istanza di prova.
- **Test**: avviato come lo avvia eww (processo figlio di python), segnali
  TERM/INT/HUP → script e figlio terminati (3/3); output invariato;
  `tests/t-perf.sh`: nessun orfano.
- Falso positivo scartato: con `bash notif.sh &` da shell, INT sembrava non
  funzionare: un job in background di una shell non interattiva IGNORA SIGINT
  (regola di bash), quindi il trap non può scattare. Non riguarda eww.

### N2 — testi con TAB / a capo rompono la barra (NUOVO)
- **Trovato da**: test nuovo con player MPRIS FINTO (`tests/fake-mpris.py`).
- **Riprodotto** (media.py con player finto): artista con TAB → `status=Stopped`
  (la musica sparisce dalla barra mentre suona); titolo con a capo → titolo su
  2 righe nella variabile (l'isola della musica diventerebbe alta il doppio).
  Unicode, emoji, virgolette e apici: già corretti.
- **Causa**: media.py separava i campi di `playerctl --format` con TAB; nessuna
  normalizzazione degli spazi.
- **Correzione**: separatore `\x1f` (ASCII unit separator) e `clean()` che
  trasforma TAB/a capo in spazi. Stessa normalizzazione, per prudenza, per il
  titolo della finestra attiva (activewindow.py), l'SSID (network.py,
  wifi-list.py: la connessione usa sempre il base64 dell'SSID originale) e i
  nomi Bluetooth (bt-list.sh).
- **File**: scripts/media.py, activewindow.py, network.py, wifi-list.py, bt-list.sh.
- **Test**: `tests/t-media-hostile.sh` 7/7 (TAB → spazio e resta Playing; a capo →
  una riga; artista vuoto; unicode/emoji/apici; 300 caratteri; separatore
  dentro l'artista).

### N3 — letture fallite trattate come "vuoto" (NUOVO, CORRETTO)
- **Trovato da**: `tests/t-multimon.sh` instabile (FAIL intermittenti).
- **Indagine**: con il daemon occupato (es. costruisce la barra di un monitor
  nuovo, ~1.5–2 s) i comandi eww falliscono con rc=1 **oppure** — scoperto
  registrando ogni lettura — escono con **rc=0 e output VUOTO** (risposta
  persa). Un `update` mandato in quel momento va perso.
- **Riprodotto**: a livello unitario (eww finto: active-windows risponde,
  `get popup` fallisce): PRIMA → dashboard aperto e visibile considerato
  orfano (`['closer','dashboard']`), DOPO → nessuno. Dal vivo: dashboard aperto
  subito dopo aver collegato un monitor chiuso dal watchdog (4 prove su 4
  prima della correzione con il codice intermedio).
- **Correzione**: `eww()` in session.py ritenta e ritorna None se fallisce;
  `active-windows` vuoto = fallito (c'è sempre la barra); il watchdog legge
  tutte le variabili con UN `eww state --all` (mai vuoto se valido) invece di
  tanti `get`; nessuna decisione su letture fallite; `sync_bars_retry`
  riprova se eww non risponde. In lib.sh `eww_q` (ritenta letture/update/close)
  e `eww_windows` (vuoto = fallito); popup.sh, osd.sh, power.sh,
  bt-connect.sh usano `eww_q`.
- **Test**: t-unit 49/49 (2 casi nuovi di risposta persa); `tests/n3-test.sh`
  (daemon sospeso con dashboard aperto / close chiesto a daemon occupato) PASS;
  multi-monitor 5/5 a 10/10.

### N4 — il watchdog chiudeva finestre a metà apertura (NUOVO, CORRETTO)
- **Trovato da**: nuovo registro delle azioni `~/.cache/eww/actions.log`
  (aggiunto per indagare): "watchdog: chiudo orfani ['closer']" durante
  aperture lente.
- **Riprodotto** (`tests/n4-test.sh`, istanza isolata): lock tenuto 8 s con
  stato "a metà apertura" → PRIMA il closer viene chiuso a ~5.5 s col lock
  ancora preso (FAIL).
- **Causa**: `window_lock` procedeva comunque dopo 3 s senza lock.
- **Correzione**: senza lock il watchdog salta il giro (e `sync_bars`
  riprova); si chiude solo dopo che l'apertura è finita.
- **Test**: n4-test DOPO: closer intatto con il lock preso, chiuso dopo il
  rilascio (PASS). **File**: scripts/session.py.

### Registro azioni (nuovo)
`~/.cache/eww/actions.log`: ogni chiusura fatta da watchdog/pulizia/eventi e
ogni rollback di popup.sh, con il motivo. **File**: lib.sh, popup.sh, session.py.

### Falsi positivi scartati nel ciclo 1
- `t-static` "script eseguibili": lib.sh e mpris_watch.py sono librerie
  (incluse/importate), non devono essere eseguibili.
- `t-stubs` copia (4 + 2 FAIL): notify-send finto scriveva nello stesso log, e
  con valori su più righe la notifica andava a capo → il test ora estrae solo
  il blocco `wl-copy <…>`.
- `t-hostile` cava.py senza Gio: il test usava `exec` senza `__file__`; ora
  Gio si blocca con un sitecustomize e lo script gira come script vero.
- `t-hostile` lib.sh/popup.sh: passavano per il motivo sbagliato (mancava
  `dirname` nell'ambiente minimo) → aggiunti dirname/realpath/flock.
- `t-hostile` notif.sh "4 tentativi in 5 s": conteggio delle righe di traccia
  `bash -x`; misurato davvero: 1 tentativo ogni 2.01 s → test sostituito.
- `t-multimon` "dashboard ancora aperto": collegando il 2° monitor Hyprland
  sposta il focus (workspacev2) e il popup si chiude per la regola "chiudi al
  cambio di workspace" (registrato in actions.log) → comportamento voluto, il
  test ora richiede solo uno stato coerente. Da valutare con l'utente.
- `t-multimon` letture subito dopo `bar-1`: il TEST leggeva mentre il daemon
  era occupato (stessa causa di N3) → letture del test con ritentativi.
- `t-perf` printf: formato non valido nel test.

### Riepilogo ciclo 1
- Test eseguiti: suite completa (20 gruppi, 241 controlli) + nuovi (titoli
  ostili, recover, N3, N4, eventi monitor tracciati).
- Bug nuovi reali: **N1** (orfano swaync-client), **N2** (TAB/a capo nei
  titoli), **N3** (letture fallite = vuoto), **N4** (watchdog vs lock). Tutti corretti.
- Falsi positivi scartati: 8 (vedi sopra).
- Corretto qualcosa → si riparte con il ciclo 2.
- **Fine ciclo 1, controllo di stato**: meteo trovato su **Bellinzona**
  (file cambiato alle 12:41:23, mentre `t-multimon.sh` teneva aperto il
  dashboard sullo schermo). Nessuno script di test scrive quel file (tutti
  usano HOME finta); probabile click sul dashboard aperto dal test.
  Ripristinato a Lugano. Da qui in poi i test che aprono il dashboard sulla
  barra vera lo tengono aperto il meno possibile.

## Fase 2 — Ciclo 2

### Risultato suite
24 gruppi, 256 controlli: 23 gruppi PASS, 1 FAIL ("B5 limite memoria", senza
riga FAIL: lo script è uscito con rc=1).

### Falso positivo: B5 limite memoria
Il daemon di prova è partito da 71 MB ed è arrivato a 81 MB dopo 12 reload,
sotto la soglia di prova di 130 MB (nel ciclo 1 partiva da 105 MB e cresceva
di più): il test dipendeva dalla velocità della perdita. Riscritto
deterministico: limite 40 MB (sotto qualunque daemon) e controllo che il
riavvio avvenga UNA volta sola.

### N6 — possibili riavvii per memoria a ripetizione (NUOVO, CORRETTO)
- **Analisi**: se la RAM di base di un daemon appena avviato superasse il
  limite, ogni daemon nuovo verrebbe subito riavviato di nuovo.
- **Correzione**: dopo un riavvio per memoria, il successivo solo dopo
  10 minuti (`EWW_MEM_COOLDOWN`, timbro `~/.cache/eww/mem-restart.stamp`,
  percorso regolabile con `EWW_MEM_STAMP` per i test). Le decisioni vanno in
  actions.log ("…ultimo riavvio N s fa: salto").
- **Test**: `tests/b5-guard.sh` (limite 40 MB): 1° daemon sostituito, il nuovo
  non viene riavviato nei 25 s successivi; actions.log mostra i "salto" (PASS).
- Nota onesta: con il codice precedente il riavvio a ripetizione NON si
  vedeva, ma per un altro bug (N5) che bloccava i ripristini successivi.

### N5 — dopo il primo ripristino, recover.sh non funzionava più (NUOVO, CRITICO, CORRETTO)
- **Trovato da**: indagando perché il vecchio codice non riavviava una seconda
  volta in b5-guard.
- **Riprodotto**: sulla barra VERA il daemon (avviato da recover.sh alle
  11:47) teneva aperto `eww-recover.lock` sul descrittore 8;
  `recover.sh --dry-run` usciva subito senza fare nulla. `tests/n5-test.sh`
  PRIMA: 1° ripristino ok, il nuovo daemon tiene il lock, 2° ripristino non
  fa nulla (FAIL). Quindi il watchdog dei duplicati/bloccati (B1) e il limite
  di memoria (B5) funzionavano UNA sola volta.
- **Causa**: il daemon avviato da recover.sh ereditava il descrittore del
  lock (flock resta preso finché un processo lo tiene aperto).
- **Correzione**: `setsid -f eww … 8>&- 9>&-` (descrittori dei lock chiusi
  per il daemon). Controllati gli altri punti: chi tiene lock sono solo
  processi brevi; i lock di session.py sono file Python non ereditabili.
- **Test**: n5-test DOPO: due ripristini di fila sostituiscono il daemon,
  il nuovo daemon non tiene il lock (PASS). Barra vera riavviata a mano
  (il lock bloccato impediva a recover.sh di farlo); poi due ripristini
  reali di fila da Hyprland: 474155 → 474416 → 474654 (OK).
- **File**: scripts/recover.sh.

### Riepilogo ciclo 2
- Test eseguiti: suite completa (24 gruppi) + indagine B5 + n5-test.
- Bug nuovi reali: **N5** (critico), **N6**. Corretti.
- Falsi positivi: 1 (B5 dipendente dalla velocità della perdita).
- Corretto qualcosa → ciclo 3.

## Fase 2 — Ciclo 3 (non concluso: sessione chiusa dall'utente)

### Risultato suite
25 gruppi, 256 controlli: 24 gruppi PASS, 1 FAIL ("N3 daemon occupato",
rc=1, senza riga FAIL) — da indagare (vedi last-run.log).

### N7 — pid file vecchi: segnale a un processo estraneo (NUOVO, CORRETTO)
- **Riprodotto**: pid file `eww-weather.pid` / `eww-network.pid` che puntano a
  un `sleep` estraneo → `weather-set.sh` e `refresh-net.sh` lo terminano con
  USR1 (azione predefinita = termina).
- **Correzione**: il segnale parte solo se `/proc/PID/cmdline` è davvero
  `scripts/weather.py` / `scripts/network.py`.
- **Test**: dopo la correzione il processo estraneo resta vivo; con lo script
  vero il meteo si aggiorna ancora (13:55 → 13:57). Casi aggiunti a t-stubs.sh.
- **File**: scripts/weather-set.sh, scripts/refresh-net.sh.

### FAIL di N3 nel ciclo 3: falso positivo (isolamento incompleto dei test)
- Rilanciato da solo: PASS, nessuna azione nel registro.
- Nel ciclo 3, alle 14:04:30 il registro mostra "chiudo il popup: cambio
  workspace workspacev2>>3,3": l'utente ha cambiato workspace mentre girava la
  suite, e l'istanza di prova (che riceve gli eventi dell'Hyprland vero) ha
  chiuso il proprio dashboard di prova per la regola "chiudi al cambio di
  workspace". Verificato anche sulla barra vera: dashboard aperto 8 s, nessuna
  chiusura.
- Miglioramenti ai test (la barra vera non cambia comportamento):
  `EWW_NO_EVENT_CLOSE=1` solo per le istanze di prova; ogni riga di
  actions.log indica la config che l'ha scritta; run-all.sh annota l'ora di
  inizio di ogni gruppo.

### Riepilogo ciclo 3
- Suite completa: 24/25 gruppi, 256 controlli PASS, 1 gruppo FAIL (falso positivo).
- Bug nuovi reali: **N7** (corretto).
- Corretto qualcosa → ciclo 4 (ultimo concordato con l'utente).

## Fase 2 — Ciclo 4 (ultimo, come concordato)
- Barra vera riavviata con recover.sh prima della suite (codice più recente).
- Suite completa: **25/25 gruppi, 259 controlli PASS, 0 FAIL**.
- Bug nuovi corretti: nessuno. **Trovato ma NON corretto** (era l'ultimo
  ciclo; correggerlo avrebbe richiesto un ciclo 5):
  - **R1**: alle 14:19:30, durante t-multimon, il watchdog della barra vera ha
    chiuso `['closer','dashboard']` come orfani. Il dashboard era stato aperto
    mentre il daemon costruiva la barra del monitor nuovo: l'`update
    reveal-dashboard=true` è andato perso pur con rc=0 (come visto in N3),
    quindi il dashboard era aperto ma invisibile e il watchdog lo ha chiuso
    correttamente (niente vetro invisibile). Effetto per l'utente: un click
    sul dashboard proprio mentre si collega un monitor può non aprirlo.
    Correzione proposta: in popup.sh rileggere la variabile dopo l'update e
    ripeterlo se non ha effetto.
- Pulizia: rimossi socket eww di istanze non più attive e file runtime con i
  nomi vecchi (eww-new-*, eww-popup.lock), solo se nessun processo li usava.
- Stato finale: 1 daemon, solo bar-0, meteo Lugano, Proton nel systray.

## Autostart di Hyprland
- `~/.config/hypr/autostart.lua` (backup: `~/.config/eww-old/autostart.lua.bak2`):
  `eww open bar --id bar-0 --arg monitor=0` → `REASON=autostart ~/.config/eww/scripts/recover.sh`.
- Perché: chiude eventuali daemon rimasti da una sessione precedente (crash di
  Hyprland), avvia il daemon senza ereditare i lock (N5), registra l'avvio in
  recover.log.
- Test (stesso comando lanciato da Hyprland, stesso ambiente dell'autostart):
  dopo `kill -9` del daemon con socket vecchio rimasto → barra in 3 s; con
  daemon già attivo → sostituito da uno pulito. In entrambi: 1 daemon, bar-0,
  meteo Lugano, Proton nel systray.
