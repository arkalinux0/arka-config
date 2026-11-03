#!/usr/bin/env bash
# Listener in condizioni ostili: senza rete, senza programmi, programmi bloccati.
cd "$(dirname "$0")/../scripts" || exit 1
T=$(mktemp -d /tmp/eww-hostile.XXXX); M=$T/minbin; mkdir -p $M; res=0
for b in bash sh python3 cat sleep jq awk sed grep cut tr date timeout env ip ls head tail wc base64 mkdir rm seq dirname realpath flock; do
  [ -x /usr/bin/$b ] && ln -sf /usr/bin/$b $M/$b; done
t(){ if eval "$2"; then echo "  PASS $1"; else echo "  FAIL $1 ${3:+[$3]}"; res=1; fi; }
alive(){ timeout "$1" env PATH=$M "${@:2}" >/dev/null 2>&1; [ $? = 124 ]; }   # vivo fino al timeout
# Gio bloccato con un sitecustomize: lo script gira come script vero (__file__ definito)
mkdir -p $T/nogi; echo "import sys; sys.modules['gi'] = None" > $T/nogi/sitecustomize.py
nogi(){ timeout 4 env PYTHONPATH=$T/nogi python3 -u "$1"; }

echo "== programmi mancanti"
t "volume.py senza wpctl/pactl resta vivo (B8)" 'alive 4 python3 -u volume.py'
out=$(timeout 4 env PATH=$M python3 -u media.py | head -1); t "media.py senza playerctl: Stopped" 'echo "$out" | jq -e ".status==\"Stopped\"" >/dev/null'
t "media.py senza playerctl resta vivo" 'alive 4 python3 -u media.py'
out=$(timeout 4 env PATH=$M python3 -u cava.py | head -1); t "cava.py senza playerctl/cava: barre a zero" 'echo "$out" | jq -e ".big|length==24" >/dev/null'
t "cava.py senza playerctl resta vivo" 'alive 4 python3 -u cava.py'
out=$(nogi media.py 2>&1 | head -1); t "media.py senza Gio: ripiego, JSON valido" 'echo "$out" | jq -e .status >/dev/null' "$out"
out=$(nogi cava.py 2>&1 | head -1); t "cava.py senza Gio: ripiego, JSON valido" 'echo "$out" | jq -e .big >/dev/null' "$out"
sleep 0.5; t "nessun playerctl orfano dopo i ripieghi" '[ $(ps -eo ppid,comm | awk "\$2==\"playerctl\" && \$1==1" | wc -l) = 0 ]'
out=$(timeout 4 env PATH=$M bash bluetooth.sh 2>&1); t "bluetooth.sh senza bluetoothctl" 'echo "$out" | jq -e ".powered==false" >/dev/null' "$out"
t "notif.sh senza swaync resta vivo (niente loop a vuoto)" 'alive 5 bash notif.sh'
# frequenza dei tentativi misurata con uno swaync-client finto che registra l'ora di avvio
mkdir -p $T/sw; for b in bash sleep date kill; do ln -sf /usr/bin/$b $T/sw/$b; done
printf '#!/bin/bash\ndate +%%s.%%N >> %s/starts\nexit 1\n' $T > $T/sw/swaync-client; chmod +x $T/sw/swaync-client
timeout 7 env PATH=$T/sw bash notif.sh >/dev/null 2>&1; n=$(wc -l < $T/starts)
t "notif.sh: un tentativo ogni 2 s ($n in 7 s)" '[ "$n" -ge 3 ] && [ "$n" -le 4 ]'
out=$(timeout 4 env PATH=$M python3 -u activewindow.py | head -1); t "activewindow.py senza hyprctl: vuoto" 'echo "$out" | jq -e ".class==\"\"" >/dev/null'
out=$(env PATH=$M bash focused-screen.sh 2>&1); t "focused-screen senza hyprctl -> 0" '[ "$out" = 0 ]' "$out"
out=$(timeout 6 env PATH=$M HYPRLAND_INSTANCE_SIGNATURE= python3 -u hyprland.py | head -1); t "hyprland.py fuori da Hyprland non va in crash" 'alive 4 env HYPRLAND_INSTANCE_SIGNATURE= python3 -u hyprland.py'
t "session.py fuori da Hyprland resta vivo" 'alive 5 env HYPRLAND_INSTANCE_SIGNATURE= XDG_RUNTIME_DIR=$T python3 -u session.py'
t "lib.sh: eww_alive falso senza eww" '! env PATH=$M bash -c "source ./lib.sh; eww_alive"'
t "popup.sh senza daemon raggiungibile: esce senza aprire (rc=1)" 'env PATH=$M XDG_RUNTIME_DIR=$T bash popup.sh dashboard; [ $? = 1 ]'

echo "== programmi bloccati"
printf '#!/bin/bash\nsleep 30\n' > $M/bluetoothctl; chmod +x $M/bluetoothctl
t0=$(date +%s%N); out=$(env PATH=$M bash bluetooth.sh 2>&1); ms=$(( ($(date +%s%N)-t0)/1000000 ))
t "bluetooth.sh con bluetoothctl bloccato risponde (${ms} ms)" 'echo "$out" | jq -e . >/dev/null && [ $ms -lt 5000 ]'
t0=$(date +%s%N); out=$(env PATH=$M bash bt-list.sh 2>&1); ms=$(( ($(date +%s%N)-t0)/1000000 ))
t "bt-list.sh con bluetoothctl bloccato risponde (${ms} ms)" '[ "$out" = "[]" ] && [ $ms -lt 5000 ]'
rm $M/bluetoothctl
printf '#!/bin/bash\nsleep 30\n' > $M/wpctl; chmod +x $M/wpctl
t0=$(date +%s%N); timeout 8 env PATH=$M python3 -u volume.py >/dev/null 2>&1 & sleep 5; t "volume.py con wpctl bloccato resta vivo" 'kill -0 $! 2>/dev/null'; wait
rm $M/wpctl

echo "== senza rete (unshare -rn)"
N="/usr/bin/unshare -rn"
if $N true 2>/dev/null; then
  out=$(timeout 3 $N python3 -u network.py | tail -1); t "network.py senza rete: JSON valido" 'echo "$out" | jq -e ".ifaces|length==0" >/dev/null' "$out"
  out=$(timeout 25 $N python3 -u weather.py | sed -n 2p); t "weather.py offline: Non disponibile" 'echo "$out" | jq -e ".ok==false and .loading==false" >/dev/null' "$out"
  out=$(XDG_RUNTIME_DIR=$T timeout 15 $N bash public-ip.sh); t "public-ip.sh offline" '[ "$out" = "non disponibile" ]'
else
  echo "  (unshare non disponibile: saltato)"
fi
rm -rf $T; exit $res
