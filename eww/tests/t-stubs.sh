#!/usr/bin/env bash
# Script della barra con comandi FINTI: nessuna azione reale (rete, Bluetooth,
# screenshot, avvio app, riavvio rete). HOME e XDG_RUNTIME_DIR finti dove serve.
E=~/.config/eww/scripts
T=$(mktemp -d /tmp/eww-stubs.XXXX); F=$T/bin; LOG=$T/calls.log; H=$T/home; R=$T/run
mkdir -p $F $H $R; res=0
for c in systemctl loginctl hyprlock kitty notify-send copyq xdg-open nm-connection-editor blueman-manager protonvpn-app wireshark waypaper; do
  printf '#!/bin/bash\necho "%s $*" >> %s\n' "$c" "$LOG" > $F/$c; done
printf '#!/bin/bash\n[ "$1" = -f ] && shift\necho "setsid $*" >> %s\n' "$LOG" > $F/setsid
printf '#!/bin/bash\nif [ "$1" = dispatch ]; then echo "hyprctl $*" >> %s; else exec /usr/bin/hyprctl "$@"; fi\n' "$LOG" > $F/hyprctl
printf '#!/bin/bash\necho slurp >> %s\n[ "$FAKE_SLURP_CANCEL" = 1 ] && exit 1\necho "10,10 100x100"\n' "$LOG" > $F/slurp
printf '#!/bin/bash\necho "grim $*" >> %s\nfor a; do :; done; touch "$a"\n' "$LOG" > $F/grim
printf '#!/bin/bash\necho "wl-copy <$(cat)>" >> %s\n' "$LOG" > $F/wl-copy
printf '#!/bin/bash\necho "curl $*" >> %s\ncase "$FAKE_CURL" in ok) echo 1.2.3.4 ;; html) echo "<html>x</html>" ;; *) exit 7 ;; esac\n' "$LOG" > $F/curl
cat > $F/nmcli <<EOF
#!/bin/bash
echo "nmcli \$*" >> $LOG
case "\$*" in
  "-t -f ACTIVE,SSID dev wifi") echo "yes:\$FAKE_ACTIVE"; echo "no:Altra" ;;
  "-t -f NAME con show") printf '%s\n' \$FAKE_SAVED ;;
  "-t -f SSID,SECURITY dev wifi list --rescan no") echo "\$FAKE_NEW:\$FAKE_SEC" ;;
  con\ up*|con\ down*|dev\ wifi\ connect*) sleep \${FAKE_SLOW:-0}; exit \${FAKE_FAIL:-0} ;;
esac
EOF
cat > $F/bluetoothctl <<EOF
#!/bin/bash
echo "bluetoothctl \$*" >> $LOG
case "\$1" in
  info) echo "	Name: Cuffie Test"; echo "	Connected: \$FAKE_BT_CONN"; echo "	Battery Percentage: 0x50 (80)"; echo "	Icon: audio-headset" ;;
  connect) sleep \${FAKE_SLOW:-0}; exit \${FAKE_FAIL:-0} ;;
  disconnect) exit 0 ;;
  show) echo "	Powered: \${FAKE_POWER:-yes}" ;;
  devices) [ "\$2" = Paired ] && { echo "Device AA:BB:CC:DD:EE:FF Cuffie \"Test\" 'X' ☕"; echo "Device 11:22:33:44:55:66 Mouse"; } ;;
esac
EOF
chmod +x $F/*
run(){ env PATH="$F:$PATH" HOME=$H "$@"; }
t(){ if eval "$2"; then echo "  PASS $1"; else echo "  FAIL $1  [log: $(tr '\n' '|' < $LOG | cut -c1-250)]"; res=1; fi; }
b64(){ printf '%s' "$1" | base64 -w0; }

echo "== wifi-connect.sh"
: > $LOG; run $E/wifi-connect.sh "!!!nonbase64" 2>/dev/null; t "base64 non valido -> niente" '! grep -qE "con up|con down|connect" $LOG'
: > $LOG; run $E/wifi-connect.sh ""; t "argomento vuoto -> niente" '! grep -qE "con up|con down|connect" $LOG'
: > $LOG; FAKE_ACTIVE=Casa run $E/wifi-connect.sh "$(b64 Casa)"; t "rete attiva -> disconnetti" 'grep -q "con down id Casa" $LOG'
: > $LOG; FAKE_ACTIVE=Altra FAKE_SAVED="Casa Ufficio" run $E/wifi-connect.sh "$(b64 Ufficio)"; t "salvata -> con up" 'grep -q "con up id Ufficio" $LOG'
: > $LOG; FAKE_ACTIVE=Altra FAKE_NEW=Bar FAKE_SEC=-- run $E/wifi-connect.sh "$(b64 Bar)"; t "aperta nuova -> connect" 'grep -q "dev wifi connect Bar" $LOG'
: > $LOG; FAKE_ACTIVE=Altra FAKE_NEW=Segreta FAKE_SEC=WPA2 run $E/wifi-connect.sh "$(b64 Segreta)"; t "protetta nuova -> terminale" 'grep -q "^kitty .*nmcli --ask dev wifi connect" $LOG'
: > $LOG; FAKE_ACTIVE=Altra FAKE_SAVED=Casa FAKE_FAIL=1 run $E/wifi-connect.sh "$(b64 Casa)"; t "fallita -> notifica errore" 'grep -q "notify-send.*fallita" $LOG'
for ss in "Rete \"di\" Mario's; rm -rf ~" "Caffè ☕ 5G" "$(printf 'x%.0s' $(seq 1 32))" '$(reboot)' ' spazi '; do
  : > $LOG; FAKE_ACTIVE=Altra FAKE_NEW="$ss" FAKE_SEC=-- run $E/wifi-connect.sh "$(b64 "$ss")"
  t "SSID ostile [$ss] passato intatto, nessun comando extra" 'grep -qF "dev wifi connect $ss" $LOG && ! grep -q "^systemctl" $LOG'
done

echo "== bt-connect.sh / bt-list.sh / bluetooth.sh"
: > $LOG; run $E/bt-connect.sh 'AA:BB:CC:DD:EE:FF; reboot'; t "MAC con comando -> rifiutato" '[ ! -s $LOG ]'
: > $LOG; run $E/bt-connect.sh ''; t "MAC vuoto -> rifiutato" '[ ! -s $LOG ]'
: > $LOG; FAKE_BT_CONN=no run $E/bt-connect.sh AA:BB:CC:DD:EE:FF; t "non connesso -> connect + notifica" 'grep -q "bluetoothctl connect AA" $LOG && grep -q "Connesso: Cuffie Test" $LOG'
: > $LOG; FAKE_BT_CONN=yes run $E/bt-connect.sh AA:BB:CC:DD:EE:FF; t "connesso -> disconnect" 'grep -q "bluetoothctl disconnect AA" $LOG'
: > $LOG; FAKE_BT_CONN=no FAKE_FAIL=1 run $E/bt-connect.sh AA:BB:CC:DD:EE:FF; t "fallita -> notifica" 'grep -q "Connessione fallita" $LOG'
( FAKE_SLOW=2 FAKE_BT_CONN=no run $E/bt-connect.sh AA:BB:CC:DD:EE:FF ) & sleep 1; busy=$(eww --no-daemonize get bt-busy); wait
t "durante la connessione bt-busy = MAC" '[ "$busy" = AA:BB:CC:DD:EE:FF ]'
t "dopo: bt-busy vuoto" '[ -z "$(eww --no-daemonize get bt-busy)" ]'
out=$(run bash $E/bt-list.sh); t "bt-list JSON valido con nomi ostili" 'echo "$out" | jq -e "length==2 and .[0].battery==\"80\"" >/dev/null' "$out"
out=$(FAKE_POWER=no run bash $E/bluetooth.sh); t "bluetooth.sh spento" 'echo "$out" | jq -e ".powered==false" >/dev/null'
out=$(run bash $E/bluetooth.sh); t "bluetooth.sh acceso" 'echo "$out" | jq -e ".powered==true" >/dev/null'
eww --no-daemonize update bt="$(bash $E/bluetooth.sh)" bt-list="[]"

echo "== quick.sh / apps.sh / net-restart.sh"
: > $LOG; FAKE_SLURP_CANCEL=1 run $E/quick.sh area; t "area annullata: niente grim" '! grep -qE "^grim|notify" $LOG'
: > $LOG; run $E/quick.sh area; t "area: grim -g + wl-copy + notifica" 'grep -q "^grim -g 10,10 100x100 $H/Pictures/screenshot-" $LOG && grep -q "^wl-copy" $LOG && grep -q "notify-send -a Screenshot" $LOG'
: > $LOG; run $E/quick.sh screen; t "schermo: fullscreen-*.png" 'grep -q "^grim $H/Pictures/fullscreen-" $LOG'
: > $LOG; run $E/quick.sh clipboard; t "appunti: copyq toggle" 'grep -qx "copyq toggle" $LOG'
: > $LOG; run $E/quick.sh folder; t "cartella: xdg-open" 'grep -qx "xdg-open $H/Pictures" $LOG'
: > $LOG; run $E/quick.sh boh; rc=$?; t "azione sconosciuta: exit 1" '[ $rc = 1 ] && ! grep -qE "grim|copyq|xdg" $LOG'
for a in network:nm-connection-editor bluetooth:blueman-manager proton:protonvpn-app copyq:"copyq show" wireshark:wireshark waypaper:waypaper; do
  : > $LOG; run $E/apps.sh ${a%%:*}; sleep 0.25; t "app ${a%%:*}" "grep -qx \"setsid ${a#*:}\" $LOG"; done
: > $LOG; run $E/apps.sh 'boh;id'; t "app sconosciuta: niente" '! grep -q "^setsid" $LOG'
: > $LOG; env PATH="$F:$PATH" HOME=$H XDG_RUNTIME_DIR=$R $E/net-restart.sh; sleep 0.4
t "riavvio rete: kitty dedicato" 'grep -q "^setsid kitty --class eww-netrestart" $LOG'
t "riavvio rete: comando esatto" 'grep -qF "hostname -i ; nmcli device disconnect enp0s13f0u1; sudo systemctl restart NetworkManager; sleep 10; sleep 10; hostname -i" $LOG'
t "riavvio rete: niente eseguito fuori dal terminale" '! grep -q "^systemctl" $LOG'

echo "== weather-set.sh"
mkdir -p $H/.cache/eww; echo Lugano > $H/.cache/eww/weather-city
env PATH="$F:$PATH" HOME=$H XDG_RUNTIME_DIR=$R $E/weather-set.sh Atlantide; rc=$?; t "città non valida rifiutata" '[ $rc = 1 ] && [ "$(cat $H/.cache/eww/weather-city)" = Lugano ]'
env PATH="$F:$PATH" HOME=$H XDG_RUNTIME_DIR=$R $E/weather-set.sh "Lugano; rm -rf ~"; t "injection rifiutata" '[ "$(cat $H/.cache/eww/weather-city)" = Lugano ]'
env PATH="$F:$PATH" HOME=$H XDG_RUNTIME_DIR=$R $E/weather-set.sh ""; t "città vuota rifiutata" '[ "$(cat $H/.cache/eww/weather-city)" = Lugano ]'
env PATH="$F:$PATH" HOME=$H XDG_RUNTIME_DIR=$R $E/weather-set.sh Locarno; t "città valida salvata" '[ "$(cat $H/.cache/eww/weather-city)" = Locarno ]'

echo "== pid file vecchi (N7)"; mkdir -p $H/.cache/eww
for pair in "weather-set.sh Locarno:eww-weather.pid" "refresh-net.sh:eww-network.pid"; do
  sleep 30 & vit=$!; echo $vit > $R/${pair##*:}
  env PATH="$F:$PATH" HOME=$H XDG_RUNTIME_DIR=$R bash $E/${pair%%:*} >/dev/null 2>&1; sleep 0.8
  t "${pair%%:*}: pid file vecchio non colpisce un processo estraneo" 'kill -0 $vit 2>/dev/null'; kill $vit 2>/dev/null
done
echo "abc" > $R/eww-weather.pid; env PATH="$F:$PATH" HOME=$H XDG_RUNTIME_DIR=$R bash $E/weather-set.sh Lugano; t "pid file non numerico: nessun errore" '[ $? = 0 ]'
echo Lugano > $H/.cache/eww/weather-city

echo "== public-ip.sh"
P(){ env PATH="$F:$PATH" XDG_RUNTIME_DIR=$R FAKE_CURL=$1 bash $E/public-ip.sh; }
rm -f $R/eww-public-ip
: > $LOG; out=$(P fail); t "offline -> non disponibile" '[ "$out" = "non disponibile" ]'
t "prova IPv4 e poi IPv6" 'grep -q "curl -4" $LOG && grep -q "curl -6" $LOG'
out=$(P html); t "pagina di errore rifiutata" '[ "$out" = "non disponibile" ]'
out=$(P ok); t "IP valido mostrato e in cache" '[ "$out" = 1.2.3.4 ] && [ -f $R/eww-public-ip ]'
: > $LOG; out=$(P fail); t "cache valida: nessuna richiesta" '[ "$out" = 1.2.3.4 ] && [ ! -s $LOG ]'
sed -i 's/^[0-9]*/0/' $R/eww-public-ip; : > $LOG; P ok >/dev/null; t "cache scaduta: nuova richiesta" 'grep -q curl $LOG'
awk '{print $1, "dev_altro0", $3}' $R/eww-public-ip > $R/x && mv $R/x $R/eww-public-ip; : > $LOG; P ok >/dev/null; t "cambio interfaccia invalida la cache" 'grep -q curl $LOG'
echo "x y" > $R/eww-public-ip; out=$(P ok); t "cache corrotta gestita" '[ "$out" = 1.2.3.4 ]'

echo "== copy.sh (eww finto con dati ostili)"
cat > $F/eww <<'J'
#!/bin/bash
for a; do last=$a; done
case "$last" in
  net) echo '{"gateway":"192.168.25.1","gw_dev":"wlan0","dns":"10.2.0.1, 2a07:b944::2:1","wifi":{"ssid":"Mario'"'"'s \"Caffè\" ☕","signal":55,"band":"5 GHz","channel":"36","rate":"866 Mb/s"},"ifaces":[{"name":"wlan0","ipv4":"192.168.1.5/24, 10.0.0.2/8","ipv6":"2a07::1","mac":"f2:e2:93:d7:e5:f6","mac_hw":"9c:67:d6:e5:5b:5a"},{"name":"proton0","ipv4":"10.2.0.2/32","ipv6":"","mac":"—","mac_hw":""}]}' ;;
  public-ip) echo "81.62.179.133" ;;
esac
J
chmod +x $F/eww
# solo il blocco "wl-copy <...>" (può essere su più righe); la notifica va ignorata
C(){ : > $LOG; env PATH="$F:$PATH" bash $E/copy.sh "$@" >/dev/null 2>&1; awk '/^wl-copy </{f=1} f{print} f && />$/{exit}' $LOG | tr '\n' '|'; }
t "copia SSID con apostrofo/virgolette/emoji" '[ "$(C wifi)" = "wl-copy <Mario'"'"'s \"Caffè\" ☕>|" ]' "$(C wifi)"
t "copia 2 IPv4 senza prefisso" '[ "$(C ipv4 wlan0)" = "wl-copy <192.168.1.5|10.0.0.2>|" ]' "$(C ipv4 wlan0)"
t "copia 2 DNS" '[ "$(C dns)" = "wl-copy <10.2.0.1|2a07:b944::2:1>|" ]'
t "copia gateway (senza interfaccia)" '[ "$(C gateway)" = "wl-copy <192.168.25.1>|" ]'
t "campo vuoto/—: niente" '[ -z "$(C mac proton0)" ] && [ -z "$(C ipv6 proton0)" ]'
t "campo/interfaccia non validi: niente" '[ -z "$(C rm-rf)" ] && [ -z "$(C ipv4 "wlan0;reboot")" ] && [ -z "$(C ipv4 "\$(id)")" ]'
rm -f $F/eww

rm -rf $T; exit $res
