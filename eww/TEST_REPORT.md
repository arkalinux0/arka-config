# Resoconto test — barra eww

Data: 2026-11-03 · eww 0.5.0 · Hyprland (config Lua) · 1 monitor eDP-1 1920x1200 @1.2

Solo test, **nessuna correzione applicata**. Le azioni pericolose (riavvio,
spegnimento, logout, rete, Wi-Fi, Bluetooth, screenshot, avvio app) sono state
provate con **comandi finti** (stub nel PATH) che registrano la chiamata senza
eseguirla. HOME e XDG_RUNTIME_DIR finti dove serviva, per non toccare
~/Pictures e le cache vere.

## Riepilogo

| Area | Superati | Falliti | Note |
|---|---|---|---|
| Controlli statici (sintassi, riferimenti, colori matugen) | 7 | 0 | |
| Test unitari Python (rete, Wi-Fi, finestra attiva, meteo, sessione, watchdog) | 34 | 0 | |
| Filtro eventi Hyprland (chiusura popup) | 6 | 0 | |
| power.sh (conferma spegnimento) | 9 | 0 | |
| wifi-connect.sh / bt-connect.sh / bt-list.sh | 18 | 0 | |
| quick.sh / apps.sh / net-restart.sh / copy.sh / weather-set.sh / public-ip.sh | 36 | 1 | apostrofo (B6) |
| Robustezza (offline, programmi mancanti, bluetoothctl bloccato) | 12 | 0 | 1 nota (B8) |
| Variabili dal vivo + coerenza con il sistema | 38 | 0 | |
| Macchina a stati dei popup + watchdog | 13 | 5 | tutti causati da B1 |
| Media + cava | 14 | 0 | ritardi (B4) |
| OSD | 7 | 0 | |
| Multi-monitor (monitor virtuali) | 5 | 2 | causati da B1 |
| Avvisi batteria | 1 (sequenza di 15 passi) | 0 | |
| Meteo dal vivo, Hyprland, autostart | 8 | 0 | |

## Bug trovati (dal più grave)

### B1 — CRITICO: secondo daemon eww, "closer" orfano che blocca click e scroll
**Riprodotto 2 volte** sulla barra vera.
- Quando il daemon è occupato (costruisce il dashboard, apre una barra per un
  nuovo monitor, fa un reload) un `eww open` può andare in timeout
  (`Error while forwarding command to server … os error 11`).
- eww 0.5 in quel caso **avvia un secondo daemon** e gli passa il socket.
- Il primo daemon resta vivo con le sue finestre: se aveva il `closer` aperto,
  quello rimane sopra tutte le app, invisibile, e **nessuno può più chiuderlo**
  (né i click né il watchdog, che ormai parlano con il daemon nuovo).
- Riprodotto con: 7 click rapidi sul dashboard; aprire il dashboard subito dopo
  aver collegato un monitor.
- Molto probabilmente è la vera causa del "non riesco a cliccare/scrollare su
  Zen e terminale" segnalato prima.
- Rimedio provvisorio se succede: `pkill -x eww; eww open bar --id bar-0 --arg monitor=0`
- Possibili correzioni (non applicate): in `popup.sh` e `session.py` fare
  `eww ping` prima di `eww open` e non aprire se il daemon non risponde; nel
  watchdog rilevare più di un processo `eww` e tenerne uno solo.

### B2 — ALTO: aperture simultanee di una finestra pesante bloccano eww
In un'istanza eww isolata (config di prova, socket diverso) 3–10 `eww open`
simultanei di una finestra con 3000 widget hanno bloccato il daemon per più di
3 minuti (test interrotto). Con finestre leggere 40 comandi simultanei: nessun
problema. È un limite di eww 0.5, legato a B1.

### B3 — MEDIO: dopo un riavvio di eww l'icona di Proton VPN sparisce dal systray
Il watcher del systray è ospitato da eww. Dopo il riavvio nm-applet, blueman,
copyq e vicinae si ri-registrano, **protonvpn-app no**: il suo elemento esiste
su D-Bus ma non compare nella lista del watcher. Torna solo riavviando
protonvpn-app. (Durante i test eww è stato riavviato 3 volte.)

### B4 — MEDIO: la musica a volte viene rilevata in ritardo
`playerctl` vede il player in ~170 ms; eww ci mette ~3,4 s all'avvio
(2 prove su 3). La chiusura del player: 0,1 s in una prova, **9 s** in
un'altra. Pausa/ripresa: immediate (47 ms). Gli eventi di
`playerctl --follow` a volte si perdono; la risincronizzazione ogni 10 s
recupera sempre lo stato giusto.

### B5 — MEDIO: la RAM di eww cresce con i reload
73 MB all'avvio → 89 MB dopo 5 reload → ~167 MB dopo altri 10, poi stabile.
I reload avvengono a ogni cambio wallpaper (matugen riscrive `colors.scss`).
Interno a eww; in uso normale pochi reload al giorno.

### B6 — BASSO: un apostrofo in un valore rompe la copia negli appunti
I campi della card Rete generano `copy.sh '<valore>' '<nome>'`. Con un valore
tipo `Mario's (55%)` (SSID con apostrofo) il comando ha un errore di sintassi
e la copia non avviene. Verificato simulando il comando generato.

### B7 — BASSO: copia di valori multipli
- DNS: viene copiata tutta la riga (`10.2.0.1, 2a07:…`), non un indirizzo.
- Più IPv4 sulla stessa interfaccia: `copy.sh` taglia al primo `/`, quindi
  copia solo il primo indirizzo.

### B8 — BASSO: volume.py termina se manca `pactl`
`FileNotFoundError` non gestito → il listener del volume muore e il valore
resta fermo. Sul tuo sistema `pactl` c'è, quindi oggi non succede.

### B9 — BASSO: power.sh accetta qualunque nome di azione
Un'azione sconosciuta (es. `rm -rf`) viene messa in `power-confirm` al primo
click. **Non esegue nulla** (test: nessun comando lanciato), ma il valore non
viene validato.

### B10 — BASSO (UX): la lista Wi-Fi/Bluetooth resta aperta
Chiudendo il dashboard con la lista Wi-Fi o Bluetooth espansa, alla prossima
apertura è ancora espansa (e il relativo poll riparte).

### B11 — BASSO (estetica)
- OSD: l'alone nero è molto marcato, sembra una seconda "pillola" scura
  attorno a quella vera.
- Calendario: lo sfondo è abbastanza trasparente da far leggere il testo
  della finestra sotto.

## Informazioni (non bug)

- Avvisi `Gtk-CRITICAL … accel_group` dal systray quando si aprono barre
  nuove (menu dbusmenu): innocui, ma il systray è anche la causa dei crash di
  eww del 26 e 30 ottobre (core dump in `libdbusmenu`).
- Avvisi GVFS "Permesso negato": generati solo dal daemon duplicato partito
  dentro la shell isolata dei test, non dal tuo sistema.
- Il log `~/.cache/eww/eww_fca669fecd206a08.log` (75 MB) è della barra
  vecchia e non viene più scritto: si può cancellare.
- Il MAC di Bluetooth viene accettato solo maiuscolo (bluetoothctl lo dà
  sempre maiuscolo: va bene).
- `~/.config`, `~/.cache`, `~/.local/share` sono scrivibili da tutti, ma la
  home è `drwx--x---`, quindi gli altri utenti non ci arrivano.
- Il meteo offline mostra "Non disponibile" e riprova ogni 30 s.
- I 6 binari e le 6 icone della griglia app esistono.

## Misure

| Cosa | Valore |
|---|---|
| CPU a riposo (eww + tutti gli script) | ~1,6% di un core (eww 1,3%, rete 0,2%, sessione 0,1%) |
| CPU con musica (audio muto) | ~0% eww, ~0% cava |
| RAM eww | 73 MB all'avvio, ~167 MB dopo 15 reload |
| Apertura dashboard | ~330 ms |
| Cambio popup | ~470 ms |
| Watchdog: closer/popup orfano chiuso in | 1,75–2,0 s |
| Nuova barra su monitor collegato | ~1,9 s |
| Cambio città meteo | 0,6–5,8 s (rete) |
| bluetoothctl bloccato: risposta script | 2,0 s (bluetooth.sh), 3,0 s (bt-list.sh) |
| Processi dopo 15 reload | 1 copia per script, nessun accumulo |

## Non testato

- Esecuzione reale di: riavvio rete, connessione Wi-Fi/Bluetooth, screenshot,
  avvio app, blocco/logout/riavvio/spegnimento (solo con comandi finti).
- Pressione fisica dei tasti (Super+D, volume, luminosità): testati solo i
  comandi che lanciano.
- Chiusura del popup al cambio di workspace dal vivo (testata con eventi
  finti, per non spostarti di workspace).
- Monitor esterno reale (solo monitor virtuali `headless`).
- Sospensione/ripresa, schermo intero, riavvio di swaync.

## Stato a fine test

Un solo daemon eww, solo `bar-0` aperta, nessun popup, città meteo tornata
a Lugano. Durante i test il daemon è stato riavviato 3 volte per rimediare
a B1 (da qui l'icona Proton mancante, B3).

## Dopo le correzioni (2026-11-03)

Dettagli, riproduzioni e test: `FIX_LOG.md`. Backup completo:
`~/.config/eww.bak-2026-11-03-1129`; repository git in `~/.config/eww`.
Suite ripetibile: `bash ~/.config/eww/tests/run-all.sh` (~10 min).

| Bug | Stato | Come |
|---|---|---|
| B1 secondo daemon / vetro invisibile | CORRETTO | `--no-daemonize`, lock globale, verifica aperture, watchdog duplicati/bloccati + `recover.sh` |
| B2 aperture concorrenti | CORRETTO | aperture serializzate fino a finestra pronta |
| B3 icona Proton persa | MITIGATO | ri-registrazione automatica nel systray (causa nell'app) |
| B4 ritardi musica 3–9 s | CORRETTO | segnali D-Bus MPRIS (0,1–0,2 s) |
| B5 RAM con i reload | MITIGATO | perdita del systray di eww 0.5; riavvio pulito oltre 400 MB, max 1 ogni 10 min |
| B6/B7 copia | CORRETTI | copia per nome del campo, valori multipli completi |
| B8–B11 | CORRETTI | volume senza pactl, validazione power.sh, liste chiuse, classe `.osd` |
| N1–N7 (nuovi) | CORRETTI | orfano swaync-client, TAB/a capo, letture fallite, watchdog vs lock, lock di recover ereditato, riavvii a ripetizione, pid file vecchi |
| R1 (nuovo, ciclo 4) | APERTO | update perso con daemon occupato → dashboard chiuso dal watchdog mentre si collega un monitor |

Cicli: 1 (4 bug nuovi), 2 (2), 3 (1), 4 (0 corretti, 1 trovato e lasciato aperto).
Ultima suite: 25/25 gruppi, 259 controlli PASS.
